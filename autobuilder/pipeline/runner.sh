#!/usr/bin/env bash
# AutoBuilder Pipeline Runner — orchestrates all stages in sequence

set -euo pipefail

run_pipeline() {
    local requirements="$1"
    local workspace="$2"
    local project_id="$3"

    local meta_dir
    meta_dir="$(get_meta_dir "$workspace")"

    # Save requirements to .meta
    echo "$requirements" > "${meta_dir}/requirements.txt"
    log "Requirements saved to ${meta_dir}/requirements.txt"

    # Define pipeline stages: "script:display_name"
    local stages=(
        "01-analyze.sh:Analyzing requirements"
        "02-architect.sh:Designing architecture"
        "03-plan.sh:Creating build plan"
        "04-build.sh:Building application"
        "05-review.sh:Reviewing & fixing code"
        "06-qa.sh:QA validation"
    )

    local total=${#stages[@]}
    local num=1
    local pipeline_start
    pipeline_start=$(date +%s)

    for stage_info in "${stages[@]}"; do
        local script="${stage_info%%:*}"
        local name="${stage_info##*:}"
        local stage_start
        stage_start=$(date +%s)

        ui_stage "$num" "$total" "$name"

        # Source the stage script (defines run_stage function)
        # shellcheck source=/dev/null
        if ! source "${PIPELINE_DIR}/stages/${script}"; then
            ui_stage_fail "$name"
            log_error "Failed to load stage script: ${script}"
            return 1
        fi

        # Run the stage
        if run_stage "$workspace"; then
            local stage_end
            stage_end=$(date +%s)
            local stage_duration=$(( stage_end - stage_start ))
            ui_stage_done
            log "Stage ${script} completed in ${stage_duration}s"
        else
            ui_stage_fail "$name"
            log_error "Stage ${script} failed after $(( $(date +%s) - stage_start ))s"
            echo ""
            ui_error "Pipeline failed at: ${name}"
            ui_info "Logs: $(get_log_file)"
            ui_info "Workspace: ${workspace}"
            return 1
        fi

        (( num++ ))
    done

    local pipeline_end
    pipeline_end=$(date +%s)
    local total_duration=$(( pipeline_end - pipeline_start ))
    log "Pipeline completed in ${total_duration}s"

    local project_dir
    project_dir="$(get_project_dir "$workspace")"
    ui_success "$project_dir"
}
