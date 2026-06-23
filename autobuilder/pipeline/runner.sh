#!/usr/bin/env bash
# AutoBuilder Pipeline Runner — orchestrates all stages in sequence
# Supports resume: skips stages already marked done in pipeline memory

set -euo pipefail

run_pipeline() {
    local requirements="$1"
    local workspace="$2"
    local project_id="$3"
    local resume_from="${4:-01}"  # Stage to start from (default: 01 = beginning)

    local meta_dir
    meta_dir="$(get_meta_dir "$workspace")"

    # Save requirements to .meta
    echo "$requirements" > "${meta_dir}/requirements.txt"
    log "Requirements saved to ${meta_dir}/requirements.txt"

    # Initialize pipeline memory (idempotent — safe to call on resume too)
    pipeline_memory_init "$workspace"

    # If resume_from is "01", check memory for actual resume point
    if [ "$resume_from" = "01" ]; then
        local mem_stage
        mem_stage=$(pipeline_memory_get_resume_stage "$workspace")
        if [ "$mem_stage" = "done" ]; then
            log "All pipeline stages already complete — nothing to run"
            local project_dir; project_dir="$(get_project_dir "$workspace")"
            ui_success "$project_dir"
            return 0
        fi
        resume_from="${mem_stage}"
    fi

    [ "$resume_from" != "01" ] && log "Resuming pipeline from stage ${resume_from}"

    # Define pipeline stages: "NN:script:display_name"
    local stages=(
        "01:01-analyze.sh:Analyzing requirements"
        "02:02-architect.sh:Designing architecture"
        "03:03-plan.sh:Creating build plan"
        "04:04-build.sh:Building application"
        "05:05-review.sh:Reviewing & fixing code"
        "06:06-qa.sh:QA validation"
    )

    local total=${#stages[@]}
    local num=1
    local pipeline_start
    pipeline_start=$(date +%s)

    for stage_info in "${stages[@]}"; do
        local stage_num="${stage_info%%:*}"
        local rest="${stage_info#*:}"
        local script="${rest%%:*}"
        local name="${rest##*:}"
        local stage_start
        stage_start=$(date +%s)

        # Skip stages that are already done (resume mode)
        if [[ "$stage_num" < "$resume_from" ]]; then
            ui_stage "$num" "$total" "$name"
            printf ' \033[2m[skipped — already done]\033[0m\n'
            log "Stage ${stage_num} skipped (already completed)"
            (( num++ ))
            continue
        fi

        ui_stage "$num" "$total" "$name"

        # Source the stage script (defines run_stage function)
        # shellcheck source=/dev/null
        if ! source "${PIPELINE_DIR}/stages/${script}"; then
            ui_stage_fail "$name"
            log_error "Failed to load stage script: ${script}"
            pipeline_memory_stage_failed "$workspace" "$stage_num" "script load error"
            return 1
        fi

        # Run the stage
        if run_stage "$workspace"; then
            local stage_end
            stage_end=$(date +%s)
            local stage_duration=$(( stage_end - stage_start ))
            ui_stage_done
            log "Stage ${script} completed in ${stage_duration}s"
            pipeline_memory_stage_done "$workspace" "$stage_num"
        else
            ui_stage_fail "$name"
            log_error "Stage ${script} failed after $(( $(date +%s) - stage_start ))s"
            pipeline_memory_stage_failed "$workspace" "$stage_num" "run_stage returned non-zero"
            echo ""
            ui_error "Pipeline failed at: ${name}"
            ui_info "Logs: $(get_log_file)"
            ui_info "Workspace: ${workspace}"
            ui_info "Resume with: ./build.sh --resume"
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
