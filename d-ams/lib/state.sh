#!/bin/bash
#===============================================================================
# Project State Management - D-AMS Agent Manager
# Persists project and agent progress to workspace/project-state.conf
#===============================================================================

_STATE_FILE="project-state.conf"

# Initialize a new project state file in workspace
state_init() {
    local workspace="$1"
    local project_name="$2"
    local project_type="$3"
    local phase="${4:-1}"
    local state_file="$workspace/$_STATE_FILE"
    local now
    now=$(date +%Y-%m-%dT%H:%M:%S)

    mkdir -p "$workspace"
    {
        printf 'PROJECT_NAME=%s\n' "$project_name"
        printf 'PROJECT_TYPE=%s\n' "$project_type"
        printf 'PHASE=%s\n' "$phase"
        printf 'CREATED_AT=%s\n' "$now"
        printf 'UPDATED_AT=%s\n' "$now"
    } > "$state_file"

    for key in "${AGENTS_LIST[@]}"; do
        printf 'AGENT_%s_STATUS=pending\n' "$key"    >> "$state_file"
        printf 'AGENT_%s_TASK=\n' "$key"             >> "$state_file"
        printf 'AGENT_%s_CHECKPOINT=\n' "$key"       >> "$state_file"
        printf 'AGENT_%s_RETRY_COUNT=0\n' "$key"     >> "$state_file"
        printf 'AGENT_%s_LAST_UPDATED=%s\n' "$key" "$now" >> "$state_file"
    done

    echo "$state_file"
}

# Read a single key from state file
state_get() {
    local workspace="$1"
    local key="$2"
    grep "^${key}=" "$workspace/$_STATE_FILE" 2>/dev/null | head -1 | cut -d= -f2-
}

# Load common project variables into caller's scope
state_load() {
    local workspace="$1"
    local state_file="$workspace/$_STATE_FILE"
    [ -f "$state_file" ] || return 1

    PROJECT_NAME=$(state_get "$workspace" "PROJECT_NAME")
    PROJECT_TYPE=$(state_get "$workspace" "PROJECT_TYPE")
    PHASE=$(state_get        "$workspace" "PHASE")
    CURRENT_PHASE="${PHASE:-1}"
    PROJECT_REQUIREMENTS=$(cat "$workspace/requirements.md" 2>/dev/null)
    [ -n "$PROJECT_NAME" ]
}

# Update the current phase
state_update_phase() {
    local workspace="$1"
    local phase="$2"
    local state_file="$workspace/$_STATE_FILE"
    [ -f "$state_file" ] || return 1
    local now; now=$(date +%Y-%m-%dT%H:%M:%S)
    sed -i "s/^PHASE=.*/PHASE=$phase/" "$state_file"
    sed -i "s/^UPDATED_AT=.*/UPDATED_AT=$now/" "$state_file"
}

# Internal: set or update a key=value in state file
_state_set_field() {
    local state_file="$1"
    local key="$2"
    local value="$3"
    if grep -q "^${key}=" "$state_file" 2>/dev/null; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$state_file"
    else
        printf '%s=%s\n' "$key" "$value" >> "$state_file"
    fi
}

# Update an agent's state (status, task, checkpoint)
# status: pending | running | paused_token | completed | failed
state_update_agent() {
    local workspace="$1"
    local agent_key="$2"
    local status="$3"
    local task="${4:-}"
    local checkpoint="${5:-}"
    local state_file="$workspace/$_STATE_FILE"
    [ -f "$state_file" ] || return 1
    local now; now=$(date +%Y-%m-%dT%H:%M:%S)

    _state_set_field "$state_file" "AGENT_${agent_key}_STATUS"       "$status"
    [ -n "$task" ]       && _state_set_field "$state_file" "AGENT_${agent_key}_TASK"       "$task"
    [ -n "$checkpoint" ] && _state_set_field "$state_file" "AGENT_${agent_key}_CHECKPOINT" "$checkpoint"
    _state_set_field "$state_file" "AGENT_${agent_key}_LAST_UPDATED" "$now"
    _state_set_field "$state_file" "UPDATED_AT"                      "$now"

    if [ "$status" = "paused_token" ]; then
        local cur; cur=$(state_get "$workspace" "AGENT_${agent_key}_RETRY_COUNT")
        _state_set_field "$state_file" "AGENT_${agent_key}_RETRY_COUNT" "$((${cur:-0} + 1))"
    fi
}

# List all projects that have a state file under sessions_dir
# Output: workspace|name|phase|updated_at
state_list_projects() {
    local sessions_dir="$1"
    find "$sessions_dir" -maxdepth 2 -name "$_STATE_FILE" 2>/dev/null | while read -r sf; do
        local ws; ws=$(dirname "$sf")
        local name phase updated
        name=$(grep    "^PROJECT_NAME=" "$sf" | cut -d= -f2-)
        phase=$(grep   "^PHASE="        "$sf" | cut -d= -f2-)
        updated=$(grep "^UPDATED_AT="   "$sf" | cut -d= -f2-)
        printf '%s|%s|%s|%s\n' "$ws" "${name:-unknown}" "${phase:-0}" "${updated:-?}"
    done
}
