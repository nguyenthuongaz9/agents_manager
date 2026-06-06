#!/usr/bin/env bash
# Pipeline Stage 05 — Code Review & Fix
# Reads: .meta/requirements.txt, .meta/architecture.md, lists project/ files
# Writes: project/REVIEW_REPORT.md (via claude in project dir)

set -euo pipefail

run_stage() {
    local workspace="$1"
    local meta_dir
    meta_dir="$(get_meta_dir "$workspace")"
    local project_dir
    project_dir="$(get_project_dir "$workspace")"
    local task_file="${meta_dir}/_task_05_review.md"
    local output_file="${meta_dir}/review-output.txt"

    log_stage_start "05" "Code Review"

    local requirements_file="${meta_dir}/requirements.txt"
    local architecture_file="${meta_dir}/architecture.md"

    for f in "$requirements_file" "$architecture_file"; do
        if [[ ! -f "$f" ]]; then
            log_error "Stage 05: Required file not found: $f"
            return 1
        fi
    done

    local requirements
    requirements="$(cat "$requirements_file")"
    local architecture
    architecture="$(cat "$architecture_file")"

    # Build file listing for the reviewer
    local file_listing
    file_listing="$(list_project_files "$project_dir")"

    if [[ -z "$file_listing" ]]; then
        log_error "Stage 05: No files found in project directory: ${project_dir}"
        return 1
    fi

    local reviewer_prompt
    reviewer_prompt="$(cat "${AGENTS_DIR}/prompts/reviewer.txt")"

    # Build the full review task prompt
    cat > "$task_file" <<TASK_EOF
${reviewer_prompt}

---

## SECTION 1: ORIGINAL REQUIREMENTS

${requirements}

---

## SECTION 2: ARCHITECTURE PLAN

${architecture}

---

## SECTION 3: FILES THAT WERE BUILT

The following files exist in the project directory (your current working directory):

${file_listing}

---

## YOUR TASK

You are running inside the project directory. Review all the files listed above.
Read each one, identify issues, and fix them in-place.

After reviewing and fixing everything, create a REVIEW_REPORT.md at the project root summarizing:
- Issues found and fixed
- Any remaining concerns
- Final status: PASS or NEEDS_ATTENTION

Begin the review now.
TASK_EOF

    log "Stage 05: Running reviewer agent in project directory: ${project_dir}"
    run_agent_review "$task_file" "$project_dir" "$output_file"

    log_stage_end "05" "Code Review"
    log "Stage 05: Review completed"
    return 0
}
