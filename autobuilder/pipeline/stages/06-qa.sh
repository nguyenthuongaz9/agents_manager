#!/usr/bin/env bash
# Pipeline Stage 06 — QA & Validation
# Reads: .meta/requirements.txt, lists project/ files
# Writes: project/QA_REPORT.md and project/test.sh (via claude in project dir)

set -euo pipefail

run_stage() {
    local workspace="$1"
    local meta_dir
    meta_dir="$(get_meta_dir "$workspace")"
    local project_dir
    project_dir="$(get_project_dir "$workspace")"
    local task_file="${meta_dir}/_task_06_qa.md"
    local output_file="${meta_dir}/qa-output.txt"

    log_stage_start "06" "QA & Validation"

    local requirements_file="${meta_dir}/requirements.txt"

    if [[ ! -f "$requirements_file" ]]; then
        log_error "Stage 06: requirements.txt not found"
        return 1
    fi

    local requirements
    requirements="$(cat "$requirements_file")"

    # Build file listing for the QA agent
    local file_listing
    file_listing="$(list_project_files "$project_dir")"

    if [[ -z "$file_listing" ]]; then
        log_error "Stage 06: No files found in project directory: ${project_dir}"
        return 1
    fi

    # Include review report if it was generated
    local review_summary=""
    if [[ -f "${project_dir}/REVIEW_REPORT.md" ]]; then
        review_summary="$(cat "${project_dir}/REVIEW_REPORT.md")"
    fi

    local qa_prompt
    qa_prompt="$(cat "${AGENTS_DIR}/prompts/qa.txt")"

    # Build the full QA task prompt
    cat > "$task_file" <<TASK_EOF
${qa_prompt}

---

## SECTION 1: ORIGINAL REQUIREMENTS

${requirements}

---

## SECTION 2: BUILT PROJECT FILES

The following files exist in the project directory (your current working directory):

${file_listing}

---

$(if [[ -n "$review_summary" ]]; then
echo "## SECTION 3: CODE REVIEW REPORT"
echo ""
echo "${review_summary}"
echo ""
echo "---"
echo ""
fi)
## YOUR TASK

You are running inside the project directory ('./') is the project root).
Your goal is to ensure the project is COMPLETE and READY — implement anything missing, fix anything broken.

MANDATORY RULES:
- Use ONLY relative paths — './test.sh', './QA_REPORT.md', etc.
- NEVER write to any absolute path
- NEVER create files outside './'

PROCESS — follow this exactly:
1. Read every file listed above
2. For each requirement in SECTION 1 — verify it is implemented
   - If NOT implemented → implement it now by writing/editing files under './'
3. Fix any bugs, broken imports, or missing dependencies you find
4. Create './test.sh' — a script that tests the application works (make it executable)
5. Create './QA_REPORT.md' with:
   - Requirements coverage (check/cross for each requirement)
   - What was fixed or implemented during QA
   - Security checklist
   - Final verdict: READY | NEEDS_FIXES

The project MUST be fully working and complete when you finish. Do not stop until it is READY.
TASK_EOF

    log "Stage 06: Running QA agent in project directory: ${project_dir}"
    run_agent_review "$task_file" "$project_dir" "$output_file"

    # Detect silent failures (e.g. session limit): agent must create QA_REPORT.md
    if [[ ! -f "${project_dir}/QA_REPORT.md" ]]; then
        log_error "Stage 06: QA_REPORT.md not created — QA agent may have failed silently"
        if [[ -f "$output_file" ]]; then
            log_error "Agent output: $(tail -5 "$output_file")"
        fi
        return 1
    fi

    # Mark completion
    {
        echo "pipeline_complete=true"
        echo "completed_at=$(date '+%Y-%m-%d %H:%M:%S')"
        echo "project_dir=${project_dir}"
    } >> "${meta_dir}/manifest.env"

    log_stage_end "06" "QA & Validation"
    log "Stage 06: QA completed. Project ready at: ${project_dir}"
    return 0
}
