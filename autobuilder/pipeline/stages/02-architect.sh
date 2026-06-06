#!/usr/bin/env bash
# Pipeline Stage 02 — Design Architecture
# Reads: .meta/requirements.txt, .meta/analysis.md
# Writes: .meta/architecture.md

set -euo pipefail

run_stage() {
    local workspace="$1"
    local meta_dir
    meta_dir="$(get_meta_dir "$workspace")"
    local requirements_file="${meta_dir}/requirements.txt"
    local analysis_file="${meta_dir}/analysis.md"
    local output_file="${meta_dir}/architecture.md"
    local task_file="${meta_dir}/_task_02_architect.md"

    log_stage_start "02" "Design Architecture"

    if [[ ! -f "$requirements_file" ]]; then
        log_error "Stage 02: requirements.txt not found"
        return 1
    fi

    if [[ ! -f "$analysis_file" ]]; then
        log_error "Stage 02: analysis.md not found — run stage 01 first"
        return 1
    fi

    local requirements
    requirements="$(cat "$requirements_file")"
    local analysis
    analysis="$(cat "$analysis_file")"

    local system_prompt
    system_prompt="$(cat "${AGENTS_DIR}/prompts/architect.txt")"

    # Build the full task prompt
    cat > "$task_file" <<TASK_EOF
${system_prompt}

---

## SECTION 1: PROJECT REQUIREMENTS

${requirements}

---

## SECTION 2: ANALYST'S ANALYSIS

${analysis}

---

Now design the complete technical architecture as described. Be extremely specific about every file
that needs to be created and what it should contain. The builder will use this to generate the
full application.
TASK_EOF

    log "Stage 02: Running architect agent..."
    run_agent_output "architect" "$task_file" "$output_file"

    if [[ ! -f "$output_file" ]] || [[ ! -s "$output_file" ]]; then
        log_error "Stage 02: architect produced no output"
        return 1
    fi

    log_stage_end "02" "Design Architecture"
    log "Stage 02: Architecture saved to ${output_file}"
    return 0
}
