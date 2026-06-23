#!/usr/bin/env bash
#===============================================================================
# AutoBuilder Pipeline Memory — Stage-Level Resume System
#
# Track which pipeline stages completed. Enables --resume to continue from
# the last successful stage instead of restarting from scratch.
#
# Memory file: <workspace>/.meta/pipeline-memory.conf
#===============================================================================

_PIPELINE_MEM_FILE=".meta/pipeline-memory.conf"
_PIPELINE_MEM_LOG=".meta/pipeline-memory.log"

#-------------------------------------------------------------------------------
# pipeline_memory_init — Khởi tạo pipeline memory (idempotent)
#-------------------------------------------------------------------------------
pipeline_memory_init() {
    local workspace="$1"
    local mem_file="$workspace/$_PIPELINE_MEM_FILE"

    [ -f "$mem_file" ] && return 0  # Already initialized

    local now; now=$(date +%Y-%m-%dT%H:%M:%S)
    cat > "$mem_file" <<EOF
# AutoBuilder Pipeline Memory
CREATED_AT=${now}
PIPELINE_STATUS=running

STAGE_01_STATUS=pending
STAGE_01_OUTPUT=
STAGE_02_STATUS=pending
STAGE_02_OUTPUT=
STAGE_03_STATUS=pending
STAGE_03_OUTPUT=
STAGE_04_STATUS=pending
STAGE_04_OUTPUT=
STAGE_05_STATUS=pending
STAGE_05_OUTPUT=
STAGE_06_STATUS=pending
STAGE_06_OUTPUT=
EOF

    printf '[%s] Pipeline memory initialized\n' "$now" > "$workspace/$_PIPELINE_MEM_LOG"
}

#-------------------------------------------------------------------------------
# pipeline_memory_stage_done — Đánh dấu stage đã hoàn thành
#-------------------------------------------------------------------------------
pipeline_memory_stage_done() {
    local workspace="$1"
    local stage_num="$2"   # 01-06
    local output_file="${3:-}"
    local mem_file="$workspace/$_PIPELINE_MEM_FILE"

    [ -f "$mem_file" ] || return 0
    local now; now=$(date +%Y-%m-%dT%H:%M:%S)

    sed -i "s|^STAGE_${stage_num}_STATUS=.*|STAGE_${stage_num}_STATUS=done|" "$mem_file"
    [ -n "$output_file" ] && \
        sed -i "s|^STAGE_${stage_num}_OUTPUT=.*|STAGE_${stage_num}_OUTPUT=${output_file}|" "$mem_file"

    printf '[%s] Stage %s: DONE\n' "$now" "$stage_num" >> "$workspace/$_PIPELINE_MEM_LOG"
}

#-------------------------------------------------------------------------------
# pipeline_memory_stage_failed — Đánh dấu stage thất bại
#-------------------------------------------------------------------------------
pipeline_memory_stage_failed() {
    local workspace="$1"
    local stage_num="$2"
    local reason="${3:-unknown}"
    local mem_file="$workspace/$_PIPELINE_MEM_FILE"

    [ -f "$mem_file" ] || return 0
    local now; now=$(date +%Y-%m-%dT%H:%M:%S)

    sed -i "s|^STAGE_${stage_num}_STATUS=.*|STAGE_${stage_num}_STATUS=failed|" "$mem_file"
    sed -i "s|^PIPELINE_STATUS=.*|PIPELINE_STATUS=failed_at_${stage_num}|" "$mem_file"

    printf '[%s] Stage %s: FAILED — %s\n' "$now" "$stage_num" "$reason" \
        >> "$workspace/$_PIPELINE_MEM_LOG"
}

#-------------------------------------------------------------------------------
# pipeline_memory_get_resume_stage — Tìm stage đầu tiên cần chạy lại
# Returns: "01"-"06" nếu cần resume, "done" nếu đã xong hết, "" nếu lỗi
#-------------------------------------------------------------------------------
pipeline_memory_get_resume_stage() {
    local workspace="$1"
    local mem_file="$workspace/$_PIPELINE_MEM_FILE"

    [ -f "$mem_file" ] || { echo "01"; return; }

    for n in 01 02 03 04 05 06; do
        local status; status=$(grep "^STAGE_${n}_STATUS=" "$mem_file" | cut -d= -f2-)
        if [ "$status" != "done" ]; then
            echo "$n"
            return 0
        fi
    done

    echo "done"
}

#-------------------------------------------------------------------------------
# pipeline_memory_status — In trạng thái các stages
#-------------------------------------------------------------------------------
pipeline_memory_status() {
    local workspace="$1"
    local mem_file="$workspace/$_PIPELINE_MEM_FILE"

    if [ ! -f "$mem_file" ]; then
        echo "  No pipeline memory found."
        return
    fi

    local stage_names=("" "Analyze requirements" "Design architecture" "Create build plan" "Build application" "Review & fix code" "QA validation")

    echo ""
    echo "  Pipeline Stage Progress:"
    for n in 01 02 03 04 05 06; do
        local status; status=$(grep "^STAGE_${n}_STATUS=" "$mem_file" | cut -d= -f2-)
        local name="${stage_names[$((10#$n))]}"
        case "$status" in
            done)    printf '    [✓] Stage %s — %s\n' "$n" "$name" ;;
            failed)  printf '    [✗] Stage %s — %s  (FAILED)\n' "$n" "$name" ;;
            *)       printf '    [ ] Stage %s — %s\n' "$n" "$name" ;;
        esac
    done
    echo ""

    local overall; overall=$(grep "^PIPELINE_STATUS=" "$mem_file" | cut -d= -f2-)
    echo "  Overall status: ${overall:-unknown}"
    echo ""
}

#-------------------------------------------------------------------------------
# pipeline_memory_find_latest — Tìm workspace gần nhất có pipeline memory
#-------------------------------------------------------------------------------
pipeline_memory_find_latest() {
    local output_dir="${1:-}"
    [ -z "$output_dir" ] && return

    find "$output_dir" -name "pipeline-memory.conf" -path "*/.meta/*" 2>/dev/null \
        | xargs ls -t 2>/dev/null \
        | head -1 \
        | xargs -I{} dirname {} 2>/dev/null \
        | xargs -I{} dirname {} 2>/dev/null
}
