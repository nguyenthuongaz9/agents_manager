#!/bin/bash
#===============================================================================
# Kitty Terminal Integration - D-AMS Agent Manager
# Launch agents in Kitty tabs/windows
#===============================================================================

# Check if running inside Kitty
kitty_detect() {
    if [ -n "$KITTY_WINDOW_ID" ] || [ -n "$KITTY_PID" ]; then
        return 0
    fi
    return 1
}

# Launch an agent in a new Kitty window
kitty_launch_agent() {
    local agent_key="$1"
    local working_dir="${2:-$(pwd)}"
    local title="$3"

    local name_var="AGENT_${agent_key}_NAME"
    local cmd_var="AGENT_${agent_key}_COMMAND"
    local agent_name="${!name_var}"
    local agent_cmd="${!cmd_var}"
    local window_title="${title:-${agent_name}}"

    if ! command -v "$agent_cmd" &>/dev/null; then
        echo "WARNING: '$agent_cmd' not found in PATH"
        return 1
    fi

    if command -v kitty &>/dev/null; then
        kitty @ launch --type window --title "$window_title" \
            --cwd "$working_dir" --keep-focus \
            bash -c "echo '=== ${agent_name} ==='; echo 'Ready.'; exec ${agent_cmd}"
        echo "Launched ${agent_name} in new Kitty window"
    else
        echo "Kitty not detected. Starting ${agent_cmd} in current terminal..."
        echo "=== ${agent_name} ==="
        echo "Run: ${agent_cmd}"
    fi
}

# Launch agent in a new Kitty tab
kitty_launch_agent_tab() {
    local agent_key="$1"
    local working_dir="${2:-$(pwd)}"
    local title="$3"

    local name_var="AGENT_${agent_key}_NAME"
    local cmd_var="AGENT_${agent_key}_COMMAND"
    local agent_name="${!name_var}"
    local agent_cmd="${!cmd_var}"
    local tab_title="${title:-${agent_name}}"

    if ! command -v "$agent_cmd" &>/dev/null; then
        echo "WARNING: '$agent_cmd' not found in PATH"
        return 1
    fi

    if command -v kitty &>/dev/null; then
        kitty @ launch --type tab --title "$tab_title" \
            --cwd "$working_dir" --keep-focus \
            bash -c "echo '=== ${agent_name} ==='; echo 'Ready.'; exec ${agent_cmd}"
        echo "Launched ${agent_name} in new Kitty tab"
    else
        kitty_launch_agent "$agent_key" "$working_dir" "$title"
    fi
}

# Send text to a Kitty window by title
kitty_send_text() {
    local title="$1"
    local text="$2"

    if command -v kitty &>/dev/null; then
        local wid
        wid=$(kitty @ ls | python3 -c "
import json,sys
data=json.load(sys.stdin)
for w in data:
    t=w.get('title','')
    if '$title' in t:
        print(w['id'])
        break
" 2>/dev/null)
        if [ -n "$wid" ]; then
            kitty @ send-text --match id:"$wid" "$text"
            return 0
        fi
        return 1
    fi
    return 1
}

# Open a split window with an agent
kitty_launch_split() {
    local agent_key="$1"
    local working_dir="${2:-$(pwd)}"

    local name_var="AGENT_${agent_key}_NAME"
    local cmd_var="AGENT_${agent_key}_COMMAND"
    local agent_name="${!name_var}"
    local agent_cmd="${!cmd_var}"

    if ! command -v "$agent_cmd" &>/dev/null; then
        echo "WARNING: '$agent_cmd' not found in PATH"
        return 1
    fi

    if command -v kitty &>/dev/null; then
        kitty @ launch --type os-window --cwd "$working_dir" \
            bash -c "echo '=== ${agent_name} ==='; exec ${agent_cmd}"
        echo "Launched ${agent_name} in new OS window"
    fi
}

# Launch all 3 agents in separate Kitty tabs (Team Assembly)
kitty_assemble_team() {
    local project_dir="$1"

    echo "=== Assembling Agent Team ==="
    for key in "${AGENTS_LIST[@]}"; do
        kitty_launch_agent_tab "$key" "$project_dir"
        sleep 0.5
    done
    echo "=== Team assembled ==="
}
