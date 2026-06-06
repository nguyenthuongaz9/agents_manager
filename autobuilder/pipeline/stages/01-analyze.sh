#!/usr/bin/env bash
# Pipeline Stage 01 — Analyze Requirements
# Reads: .meta/requirements.txt
# Writes: .meta/analysis.md

set -euo pipefail

run_stage() {
    local workspace="$1"
    local meta_dir
    meta_dir="$(get_meta_dir "$workspace")"
    local requirements_file="${meta_dir}/requirements.txt"
    local output_file="${meta_dir}/analysis.md"
    local task_file="${meta_dir}/_task_01_analyze.md"

    log_stage_start "01" "Analyze Requirements"

    if [[ ! -f "$requirements_file" ]]; then
        log_error "Stage 01: requirements.txt not found at ${requirements_file}"
        return 1
    fi

    local requirements
    requirements="$(cat "$requirements_file")"

    local system_prompt
    system_prompt="$(cat "${AGENTS_DIR}/prompts/analyst.txt")"

    # Build the full task prompt
    cat > "$task_file" <<TASK_EOF
${system_prompt}

---

## PROJECT REQUIREMENTS TO ANALYZE:

${requirements}

---

Now analyze the above requirements and produce the structured analysis in Markdown format as described.
TASK_EOF

    log "Stage 01: Running analyst agent..."
    run_agent_output "analyst" "$task_file" "$output_file"

    if [[ ! -f "$output_file" ]] || [[ ! -s "$output_file" ]]; then
        log_error "Stage 01: analyst produced no output"
        return 1
    fi

    log_stage_end "01" "Analyze Requirements"
    log "Stage 01: Analysis saved to ${output_file}"
    return 0
}
