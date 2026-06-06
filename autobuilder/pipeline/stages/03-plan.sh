#!/usr/bin/env bash
# Pipeline Stage 03 — Create Build Plan
# Reads: .meta/requirements.txt, .meta/analysis.md, .meta/architecture.md
# Writes: .meta/build-plan.md

set -euo pipefail

run_stage() {
    local workspace="$1"
    local meta_dir
    meta_dir="$(get_meta_dir "$workspace")"
    local requirements_file="${meta_dir}/requirements.txt"
    local analysis_file="${meta_dir}/analysis.md"
    local architecture_file="${meta_dir}/architecture.md"
    local output_file="${meta_dir}/build-plan.md"
    local task_file="${meta_dir}/_task_03_plan.md"

    log_stage_start "03" "Create Build Plan"

    for f in "$requirements_file" "$analysis_file" "$architecture_file"; do
        if [[ ! -f "$f" ]]; then
            log_error "Stage 03: Required file not found: $f"
            return 1
        fi
    done

    local requirements
    requirements="$(cat "$requirements_file")"
    local analysis
    analysis="$(cat "$analysis_file")"
    local architecture
    architecture="$(cat "$architecture_file")"

    # Build the full task prompt
    cat > "$task_file" <<TASK_EOF
You are a senior software project planner. Your task is to create a detailed, ordered build plan
for a development team (in this case, a single automated builder agent).

You will receive the project requirements, analysis, and architecture. Produce a build-plan.md that:

## Build Plan Format

### Phase 1: Project Setup
- Step 1.1: Initialize project structure
  - Files to create: [list]
  - Commands to run: [list]
  - Notes: [any important notes]

### Phase 2: Core Infrastructure
- Step 2.1: [name]
  ...

### Phase 3: Feature Implementation
(one sub-section per major feature)

### Phase 4: Integration & Configuration
### Phase 5: Documentation & Testing

For each step include:
- Files to create or modify
- Key implementation details
- Dependencies that must be installed
- Order constraints (what must be done first)

The plan must be exhaustive — cover every file in the architecture.

---

## PROJECT REQUIREMENTS

${requirements}

---

## ANALYSIS

${analysis}

---

## ARCHITECTURE

${architecture}

---

Now produce the detailed build plan.
TASK_EOF

    log "Stage 03: Running planner agent..."
    run_agent_output "planner" "$task_file" "$output_file"

    if [[ ! -f "$output_file" ]] || [[ ! -s "$output_file" ]]; then
        log_error "Stage 03: planner produced no output"
        return 1
    fi

    log_stage_end "03" "Create Build Plan"
    log "Stage 03: Build plan saved to ${output_file}"
    return 0
}
