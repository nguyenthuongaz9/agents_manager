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

You are running inside the project directory ('./') is the project root).
Your goal is to produce a WORKING, BUG-FREE application by fixing all issues in the files listed above.

MANDATORY RULES:
- Use ONLY relative paths — './src/index.js', './package.json', etc.
- NEVER write to any absolute path
- NEVER create files outside './'

PROCESS — follow this exactly:
1. Read each file listed above one by one
2. For EVERY issue found → immediately fix it with the Edit tool (do NOT defer fixes)
3. If a file is missing that is needed → create it with the Write tool under './'
4. After all files are reviewed and fixed → create './REVIEW_REPORT.md'

The REVIEW_REPORT.md must include:
- Issues found and fixed (per file)
- Any remaining concerns
- Final status: PASS or NEEDS_ATTENTION

Do NOT exit until every bug is fixed and the project is in a working state.
TASK_EOF

    log "Stage 05: Running reviewer agent in project directory: ${project_dir}"
    run_agent_review "$task_file" "$project_dir" "$output_file"

    # Detect silent failures (e.g. session limit): agent must create REVIEW_REPORT.md
    if [[ ! -f "${project_dir}/REVIEW_REPORT.md" ]]; then
        log_error "Stage 05: REVIEW_REPORT.md not created — reviewer agent may have failed silently"
        if [[ -f "$output_file" ]]; then
            log_error "Agent output: $(tail -5 "$output_file")"
        fi
        return 1
    fi

    log_stage_end "05" "Code Review"
    log "Stage 05: Review completed"
    return 0
}
