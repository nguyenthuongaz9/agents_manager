#!/usr/bin/env bash
# Pipeline Stage 04 — Build Application
# Reads: .meta/requirements.txt, .meta/analysis.md, .meta/architecture.md, .meta/build-plan.md
# Writes: workspace/project/ (actual application files)

set -euo pipefail

run_stage() {
    local workspace="$1"
    local meta_dir
    meta_dir="$(get_meta_dir "$workspace")"
    local project_dir
    project_dir="$(get_project_dir "$workspace")"
    local task_file="${meta_dir}/_task_04_build.md"

    log_stage_start "04" "Build Application"

    local requirements_file="${meta_dir}/requirements.txt"
    local analysis_file="${meta_dir}/analysis.md"
    local architecture_file="${meta_dir}/architecture.md"
    local build_plan_file="${meta_dir}/build-plan.md"

    for f in "$requirements_file" "$analysis_file" "$architecture_file" "$build_plan_file"; do
        if [[ ! -f "$f" ]]; then
            log_error "Stage 04: Required file not found: $f"
            return 1
        fi
    done

    local requirements
    requirements="$(cat "$requirements_file")"
    local analysis
    analysis="$(cat "$analysis_file")"
    local architecture
    architecture="$(cat "$architecture_file")"
    local build_plan
    build_plan="$(cat "$build_plan_file")"

    local builder_prompt
    builder_prompt="$(cat "${AGENTS_DIR}/prompts/builder.txt")"

    # Build the full build task prompt
    cat > "$task_file" <<TASK_EOF
${builder_prompt}

---

## SECTION 1: ORIGINAL REQUIREMENTS

${requirements}

---

## SECTION 2: SYSTEM ANALYSIS

${analysis}

---

## SECTION 3: ARCHITECTURE PLAN

${architecture}

---

## SECTION 4: BUILD PLAN

${build_plan}

---

## YOUR TASK

You are now running inside the project directory ('./' is your project root).
Create ALL the files described in the architecture and build plan above.

MANDATORY RULES:
- Use ONLY relative paths — './src/index.js', './package.json', etc.
- NEVER write to any absolute path ('/home/', '/tmp/', etc.)
- NEVER create files outside './'
- Write complete, working code for every file — no stubs, no TODOs
- Include all dependencies in package.json / requirements.txt / go.mod / etc.
- Add a README.md with setup and run instructions
- Add .env.example if the app needs environment variables
- Every file must be production-ready

Start by creating all directories, then implement every file completely. Do not stop until ALL files are created.
TASK_EOF

    log "Stage 04: Running builder agent in project directory: ${project_dir}"
    run_agent_build "$task_file" "$project_dir"

    # Check that some files were actually created
    local file_count
    file_count=$(find "$project_dir" -type f | wc -l)
    if [[ "$file_count" -eq 0 ]]; then
        log_error "Stage 04: builder created no files in ${project_dir}"
        return 1
    fi

    log_stage_end "04" "Build Application"
    log "Stage 04: Builder created ${file_count} files in ${project_dir}"
    return 0
}
