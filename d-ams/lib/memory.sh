#!/bin/bash
#===============================================================================
# Smart Agent Memory System — D-AMS
#
# Kiến trúc phân cấp mô phỏng bộ nhớ con người + database index/cache:
#
#   Hot Memory (Working):   agent snapshots — trạng thái hiện tại (~80 lines)
#   Semantic Memory (LTM):  facts dài hạn — architecture, completed, issues
#   Episodic Memory (Log):  archive session — tự động compress khi snapshot > 80 lines
#   Resume Memory:          điểm tiếp tục chính xác khi bị ngắt bởi quota
#
# Cấu trúc thư mục: <workspace>/.memory/
#   INDEX.md                — always-loaded master index (< 50 lines)
#   hot/AGENT-snapshot.md   — working memory per agent
#   semantic/               — architecture.md, completed.md, issues.md
#   episodic/               — archived session logs (auto-compressed)
#   resume/AGENT-resume.md  — quota/interruption resume checkpoints
#===============================================================================

_MEM_DIR=".memory"
_MEM_MAX_LINES=80   # Auto-compress hot snapshot when it exceeds this

#-------------------------------------------------------------------------------
# memory_init — Khởi tạo cấu trúc memory cho workspace
#-------------------------------------------------------------------------------
memory_init() {
    local workspace="$1"
    local project_name="${2:-unknown}"

    local mem="$workspace/$_MEM_DIR"
    mkdir -p "$mem/hot" "$mem/semantic" "$mem/episodic" "$mem/resume"

    [ -f "$mem/INDEX.md" ] && return 0  # Already initialized

    local now; now=$(date +%Y-%m-%dT%H:%M:%S)
    cat > "$mem/INDEX.md" <<EOF
# Memory Index — ${project_name}
Updated: ${now}

## Agent Status
(no agents started yet)

## Project Progress
- Completed tasks: 0
- Open issues: 0
- Quota hits: 0

## Memory Files
- hot/AGENT-snapshot.md   — agent working memory (load at start/resume)
- semantic/architecture.md — tech stack and design decisions
- semantic/completed.md   — append-only completed task log
- semantic/issues.md      — known bugs and blockers
- resume/AGENT-resume.md  — exact resume point after quota hit
EOF

    cat > "$mem/semantic/architecture.md" <<EOF
# Architecture Memory
Status: pending — LEADER agent will populate this
EOF

    cat > "$mem/semantic/completed.md" <<EOF
# Completed Tasks Log
(append-only — format: [TIMESTAMP] AGENT: task description)
EOF

    cat > "$mem/semantic/issues.md" <<EOF
# Known Issues
(format: [OPEN/FIXED] description — by AGENT at TIMESTAMP)
EOF
}

#-------------------------------------------------------------------------------
# memory_get_context — Trả về minimal context string để inject vào agent prompt
# Load: INDEX.md + agent snapshot + (tùy chọn) resume checkpoint
#-------------------------------------------------------------------------------
memory_get_context() {
    local workspace="$1"
    local agent_key="$2"
    local include_resume="${3:-0}"

    local mem="$workspace/$_MEM_DIR"
    [ -d "$mem" ] || return 0

    local ctx=""
    [ -f "$mem/INDEX.md" ] && ctx+="=== MEMORY: PROJECT INDEX ===
$(cat "$mem/INDEX.md")

"
    local snap="$mem/hot/${agent_key}-snapshot.md"
    [ -f "$snap" ] && ctx+="=== MEMORY: ${agent_key} LAST STATE ===
$(cat "$snap")

"
    if [ "$include_resume" = "1" ]; then
        local rf="$mem/resume/${agent_key}-resume.md"
        [ -f "$rf" ] && ctx+="=== MEMORY: RESUME CHECKPOINT ===
$(cat "$rf")

"
    fi

    printf '%s' "$ctx"
}

#-------------------------------------------------------------------------------
# memory_update_index — Rebuild INDEX.md từ trạng thái snapshot hiện tại
#-------------------------------------------------------------------------------
memory_update_index() {
    local workspace="$1"
    local mem="$workspace/$_MEM_DIR"
    local idx="$mem/INDEX.md"
    [ -f "$idx" ] || return 0

    local now; now=$(date +%Y-%m-%dT%H:%M:%S)
    local project_name; project_name=$(grep "^# Memory Index" "$idx" | sed 's/# Memory Index — //')

    local agent_section=""
    local found=0
    for snap in "$mem/hot/"*-snapshot.md; do
        [ -f "$snap" ] || continue
        found=1
        local key; key=$(basename "$snap" -snapshot.md)
        local status; status=$(grep "^Status:" "$snap" 2>/dev/null | head -1 | cut -d: -f2- | xargs)
        local lines; lines=$(wc -l < "$snap")
        agent_section+="- ${key}: ${status:-running} (${lines}L)
"
    done
    [ "$found" -eq 0 ] && agent_section="(no agents started yet)
"

    local ctasks; ctasks=$(grep -c '^\[2' "$mem/semantic/completed.md" 2>/dev/null; true)
    ctasks="${ctasks:-0}"
    local oissues; oissues=$(grep -c '\[OPEN\]' "$mem/semantic/issues.md" 2>/dev/null; true)
    oissues="${oissues:-0}"
    local qhits; qhits=$(grep "Quota hits:" "$idx" 2>/dev/null | grep -o '[0-9]*' | head -1)
    qhits="${qhits:-0}"

    cat > "$idx" <<EOF
# Memory Index — ${project_name}
Updated: ${now}

## Agent Status
${agent_section}
## Project Progress
- Completed tasks: ${ctasks}
- Open issues: ${oissues}
- Quota hits: ${qhits}

## Memory Files
- hot/AGENT-snapshot.md   — agent working memory (load at start/resume)
- semantic/architecture.md — tech stack and design decisions
- semantic/completed.md   — append-only completed task log
- semantic/issues.md      — known bugs and blockers
- resume/AGENT-resume.md  — exact resume point after quota hit
EOF
}

#-------------------------------------------------------------------------------
# memory_snapshot_write — Upsert agent's hot memory snapshot (từ bash orchestrator)
#-------------------------------------------------------------------------------
memory_snapshot_write() {
    local workspace="$1"
    local agent_key="$2"
    local status="$3"   # running | completed | paused
    local content="$4"

    local mem="$workspace/$_MEM_DIR"
    [ -d "$mem" ] || return 0

    local snap="$mem/hot/${agent_key}-snapshot.md"
    local now; now=$(date +%Y-%m-%dT%H:%M:%S)

    cat > "$snap" <<EOF
# ${agent_key} Snapshot
Updated: ${now}
Status: ${status}

${content}
EOF

    memory_update_index "$workspace"
}

#-------------------------------------------------------------------------------
# memory_save_resume — Lưu resume checkpoint khi quota/interruption xảy ra
# Được gọi bởi launcher script khi phát hiện token limit
#-------------------------------------------------------------------------------
memory_save_resume() {
    local workspace="$1"
    local agent_key="$2"

    local mem="$workspace/$_MEM_DIR"
    [ -d "$mem" ] || return 0

    local now; now=$(date +%Y-%m-%dT%H:%M:%S)
    local snap="$mem/hot/${agent_key}-snapshot.md"
    local cp_file="$workspace/checkpoint-${agent_key}.md"
    local resume_file="$mem/resume/${agent_key}-resume.md"

    local snap_content="No snapshot saved yet"
    [ -f "$snap" ] && snap_content=$(cat "$snap")
    local cp_content="No checkpoint saved yet"
    [ -f "$cp_file" ] && cp_content=$(cat "$cp_file")

    mkdir -p "$mem/resume"
    cat > "$resume_file" <<EOF
# RESUME CHECKPOINT — ${agent_key}
Saved: ${now}
Reason: quota or rate-limit pause

## How to Resume
1. Read this file completely
2. Run: find . -type f | head -60  (see what exists in workspace)
3. Continue ONLY remaining work — skip already completed tasks
4. After each milestone: write to .memory/hot/${agent_key}-snapshot.md
5. When done: set Status: COMPLETED in your snapshot file

## Last Snapshot (your working state before pause)
${snap_content}

## Checkpoint File (detailed progress)
${cp_content}
EOF

    local idx="$mem/INDEX.md"
    if [ -f "$idx" ]; then
        local hits; hits=$(grep "Quota hits:" "$idx" | grep -o '[0-9]*' | head -1)
        hits=$(( ${hits:-0} + 1 ))
        sed -i "s/- Quota hits: [0-9]*/- Quota hits: $hits/" "$idx" 2>/dev/null
    fi
}

#-------------------------------------------------------------------------------
# memory_mark_complete — Log agent completion vào semantic memory
#-------------------------------------------------------------------------------
memory_mark_complete() {
    local workspace="$1"
    local agent_key="$2"
    local summary="$3"

    local mem="$workspace/$_MEM_DIR"
    [ -d "$mem" ] || return 0

    local now; now=$(date +%Y-%m-%dT%H:%M:%S)
    printf '[%s] %s: %s\n' "$now" "$agent_key" "$summary" >> "$mem/semantic/completed.md"

    local snap="$mem/hot/${agent_key}-snapshot.md"
    if [ -f "$snap" ]; then
        sed -i "s/^Status: .*/Status: COMPLETED (${now})/" "$snap" 2>/dev/null
    else
        memory_snapshot_write "$workspace" "$agent_key" "COMPLETED" "$summary"
    fi

    rm -f "$mem/resume/${agent_key}-resume.md" 2>/dev/null
    memory_update_index "$workspace"
}

#-------------------------------------------------------------------------------
# memory_compress — Archive hot snapshot khi vượt quá _MEM_MAX_LINES
# Giống như brain consolidating short-term → long-term memory during sleep
#-------------------------------------------------------------------------------
memory_compress() {
    local workspace="$1"
    local agent_key="$2"

    local mem="$workspace/$_MEM_DIR"
    local snap="$mem/hot/${agent_key}-snapshot.md"
    [ -f "$snap" ] || return 0

    local lines; lines=$(wc -l < "$snap")
    [ "$lines" -le "$_MEM_MAX_LINES" ] && return 0

    local now; now=$(date +%Y-%m-%dT%H:%M:%S)
    local num; num=$(ls "$mem/episodic/" 2>/dev/null | wc -l)
    num=$(( num + 1 ))
    local archive="$mem/episodic/$(printf '%03d' $num)-${agent_key}-$(date +%Y%m%d%H%M).md"

    cp "$snap" "$archive"

    local header; header=$(head -6 "$snap")
    local recent; recent=$(tail -20 "$snap")

    cat > "$snap" <<EOF
${header}
[Compressed at ${now} — archive: $(basename "$archive")]

## Recent Actions (last 20 lines)
${recent}
EOF
    memory_update_index "$workspace"
}

#-------------------------------------------------------------------------------
# memory_stats — Hiển thị thống kê memory system
#-------------------------------------------------------------------------------
memory_stats() {
    local workspace="$1"
    local mem="$workspace/$_MEM_DIR"

    if [ ! -d "$mem" ]; then
        echo "  Memory not initialized for this workspace."
        return
    fi

    local idx_lines=0
    [ -f "$mem/INDEX.md" ] && idx_lines=$(wc -l < "$mem/INDEX.md")

    echo ""
    echo "  Memory dir: ${mem}"
    echo ""
    printf '  %-22s %d lines\n' "INDEX.md:" "$idx_lines"
    echo ""
    echo "  Hot Snapshots (working memory):"
    local found=0
    for snap in "$mem/hot/"*-snapshot.md; do
        [ -f "$snap" ] || continue
        found=1
        local key; key=$(basename "$snap" -snapshot.md)
        local lines; lines=$(wc -l < "$snap")
        local status; status=$(grep "^Status:" "$snap" 2>/dev/null | head -1 | cut -d: -f2- | xargs)
        printf '    %-14s %3d lines  [%s]\n' "$key" "$lines" "${status:-unknown}"
    done
    [ "$found" -eq 0 ] && echo "    (none yet)"

    local ctasks; ctasks=$(grep -c '^\[2' "$mem/semantic/completed.md" 2>/dev/null; true)
    ctasks="${ctasks:-0}"
    local oissues; oissues=$(grep -c '\[OPEN\]' "$mem/semantic/issues.md" 2>/dev/null; true)
    oissues="${oissues:-0}"
    local episodic_count; episodic_count=$(ls "$mem/episodic/" 2>/dev/null | wc -l)
    local resume_count; resume_count=$(ls "$mem/resume/" 2>/dev/null | wc -l)

    echo ""
    echo "  Semantic Memory (long-term):"
    printf '    Completed tasks: %s\n' "$ctasks"
    printf '    Open issues:     %s\n' "$oissues"
    printf '    Episodic files:  %s\n' "$episodic_count"
    printf '    Resume points:   %s\n' "$resume_count"

    local sz; sz=$(du -sh "$mem" 2>/dev/null | cut -f1)
    echo ""
    printf '  Total memory size: %s\n' "${sz:-?}"
    echo ""
}

#-------------------------------------------------------------------------------
# memory_view_index — Hiển thị INDEX.md
#-------------------------------------------------------------------------------
memory_view_index() {
    local workspace="$1"
    local idx="$workspace/$_MEM_DIR/INDEX.md"
    if [ -f "$idx" ]; then
        cat "$idx"
    else
        echo "  No memory initialized for this workspace."
    fi
}

#-------------------------------------------------------------------------------
# memory_view_agent — Hiển thị snapshot của một agent cụ thể
#-------------------------------------------------------------------------------
memory_view_agent() {
    local workspace="$1"
    local agent_key="$2"
    local snap="$workspace/$_MEM_DIR/hot/${agent_key}-snapshot.md"
    if [ -f "$snap" ]; then
        cat "$snap"
    else
        echo "  No snapshot for agent: ${agent_key}"
    fi
}
