#!/usr/bin/env bash
# AutoBuilder Agent Runner — wrapper around the `claude` CLI

set -euo pipefail

# run_agent_output: Run a claude agent and capture its output to a file.
#
# Usage: run_agent_output <role> <task_file> <output_file>
#   role        - agent role label (for logging)
#   task_file   - file containing the full task prompt
#   output_file - where to save the agent's response
#
run_agent_output() {
    local role="$1"
    local task_file="$2"
    local output_file="$3"

    if [[ ! -f "$task_file" ]]; then
        echo "ERROR: Task file not found: $task_file" >&2
        return 1
    fi

    log_debug "Running agent [${role}] with task: ${task_file}"

    local prompt
    prompt="$(cat "$task_file")"

    local start_ts
    start_ts=$(date +%s)

    if ! "${CLAUDE_CMD}" -p "$prompt" > "$output_file" 2>&1; then
        log_error "Agent [${role}] failed. See: ${output_file}"
        return 1
    fi

    local end_ts
    end_ts=$(date +%s)
    local duration=$(( end_ts - start_ts ))
    log "Agent [${role}] completed in ${duration}s" "AGENT"
    log_agent_output "$role" "$output_file"
}

# run_agent_build: Run claude inside a project directory to create files.
#
# Usage: run_agent_build <task_file> <workspace_dir>
#   task_file     - file containing the full build task prompt
#   workspace_dir - directory where claude should create files
#
run_agent_build() {
    local task_file="$1"
    local workspace_dir="$2"

    if [[ ! -f "$task_file" ]]; then
        echo "ERROR: Task file not found: $task_file" >&2
        return 1
    fi

    mkdir -p "$workspace_dir"

    log_debug "Running build agent in: ${workspace_dir}"

    local prompt
    prompt="$(cat "$task_file")"

    local start_ts
    start_ts=$(date +%s)

    if ! (cd "$workspace_dir" && "${CLAUDE_CMD}" --dangerously-skip-permissions -p "$prompt" 2>&1); then
        log_error "Build agent failed in ${workspace_dir}"
        return 1
    fi

    local end_ts
    end_ts=$(date +%s)
    local duration=$(( end_ts - start_ts ))
    log "Build agent completed in ${duration}s" "AGENT"
}

# run_agent_review: Run claude inside a project directory for review/QA.
#
# Usage: run_agent_review <task_file> <workspace_dir> [output_file]
#   task_file     - file containing the review task prompt
#   workspace_dir - directory where claude operates
#   output_file   - (optional) capture output here as well
#
run_agent_review() {
    local task_file="$1"
    local workspace_dir="$2"
    local output_file="${3:-}"

    if [[ ! -f "$task_file" ]]; then
        echo "ERROR: Task file not found: $task_file" >&2
        return 1
    fi

    mkdir -p "$workspace_dir"

    log_debug "Running review agent in: ${workspace_dir}"

    local prompt
    prompt="$(cat "$task_file")"

    local start_ts
    start_ts=$(date +%s)

    if [[ -n "$output_file" ]]; then
        if ! (cd "$workspace_dir" && "${CLAUDE_CMD}" --dangerously-skip-permissions -p "$prompt" 2>&1) \
             | tee "$output_file"; then
            log_error "Review agent failed in ${workspace_dir}"
            return 1
        fi
    else
        if ! (cd "$workspace_dir" && "${CLAUDE_CMD}" --dangerously-skip-permissions -p "$prompt" 2>&1); then
            log_error "Review agent failed in ${workspace_dir}"
            return 1
        fi
    fi

    local end_ts
    end_ts=$(date +%s)
    local duration=$(( end_ts - start_ts ))
    log "Review agent completed in ${duration}s" "AGENT"
}
