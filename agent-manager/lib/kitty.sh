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

    if kitty_detect && command -v timeout &>/dev/null; then
        timeout 15 kitty @ launch --type window --title "$window_title" \
            --cwd "$working_dir" --keep-focus \
            bash -c "echo '=== ${agent_name} ==='; echo 'Ready.'; exec ${agent_cmd}" &>/dev/null
        if [ $? -eq 0 ]; then
            echo "Launched ${agent_name} in new Kitty window"
            return 0
        fi
        echo "WARNING: Kitty launch failed, starting ${agent_cmd} in background..."
    elif command -v kitty &>/dev/null && [ -n "$DISPLAY" ]; then
        kitty --title "$window_title" --directory "$working_dir" \
            bash -c "echo '=== ${agent_name} ==='; echo 'Ready.'; exec ${agent_cmd}" &>/dev/null &
        echo "Launched ${agent_name} in new Kitty window (background)"
        return 0
    fi

    echo "Starting ${agent_cmd} in background..."
    (cd "$working_dir" && nohup "$agent_cmd" </dev/null &>/dev/null &)
    echo "Launched ${agent_name} in background"
    return 1
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

    if kitty_detect && command -v timeout &>/dev/null; then
        timeout 15 kitty @ launch --type tab --title "$tab_title" \
            --cwd "$working_dir" --keep-focus \
            bash -c "echo '=== ${agent_name} ==='; echo 'Ready.'; exec ${agent_cmd}" &>/dev/null
        if [ $? -eq 0 ]; then
            echo "Launched ${agent_name} in new Kitty tab"
            return 0
        fi
        echo "WARNING: Kitty tab launch failed, starting ${agent_cmd} in background..."
    elif command -v kitty &>/dev/null && [ -n "$DISPLAY" ]; then
        kitty_launch_agent "$agent_key" "$working_dir" "$title"
        return $?
    fi

    echo "Starting ${agent_cmd} in background..."
    (cd "$working_dir" && nohup "$agent_cmd" </dev/null &>/dev/null &)
    echo "Launched ${agent_name} in background"
    return 1
}

# Send text to a Kitty window by title
kitty_send_text() {
    local title="$1"
    local text="$2"

    if ! kitty_detect; then
        return 1
    fi

    if command -v kitty &>/dev/null; then
        local wid
        wid=$(kitty @ ls 2>/dev/null | python3 -c "
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

    if kitty_detect && command -v timeout &>/dev/null; then
        timeout 15 kitty @ launch --type os-window --cwd "$working_dir" \
            bash -c "echo '=== ${agent_name} ==='; exec ${agent_cmd}" &>/dev/null
        if [ $? -eq 0 ]; then
            echo "Launched ${agent_name} in new OS window"
            return 0
        fi
        echo "WARNING: Kitty split launch failed, starting ${agent_cmd} in background..."
    elif command -v kitty &>/dev/null && [ -n "$DISPLAY" ]; then
        kitty --directory "$working_dir" \
            bash -c "echo '=== ${agent_name} ==='; exec ${agent_cmd}" &>/dev/null &
        echo "Launched ${agent_name} in new OS window (background)"
        return 0
    fi

    echo "Starting ${agent_cmd} in background..."
    (cd "$working_dir" && nohup "$agent_cmd" </dev/null &>/dev/null &)
    echo "Launched ${agent_name} in background"
    return 1
}

# Launch all agents in separate Kitty tabs (Team Assembly)
kitty_assemble_team() {
    local project_dir="$1"

    local total=${#AGENTS_LIST[@]}
    local success=0
    local failed=0

    echo "=== Assembling Agent Team ==="
    echo "  Agents to launch: ${total}"
    echo ""

    local pids=()
    local icons=()
    local names=()

    for key in "${AGENTS_LIST[@]}"; do
        local name_var="AGENT_${key}_NAME"
        local icon_var="AGENT_${key}_ICON"
        local name="${!name_var}"
        local icon="${!icon_var}"

        echo -ne "  ${icon} ${name}... "
        (kitty_launch_agent_tab "$key" "$project_dir") &
        pids+=($!)
        icons+=("$icon")
        names+=("$name")
    done

    local i=0
    for pid in "${pids[@]}"; do
        wait "$pid" 2>/dev/null
        if [ $? -eq 0 ]; then
            echo -e "\r  ${icons[$i]} ${names[$i]}... ${GREEN}✓${NC} \033[K"
            ((success++))
        else
            echo -e "\r  ${icons[$i]} ${names[$i]}... ${YELLOW}⚠${NC} \033[K"
            ((failed++))
        fi
        ((i++))
    done

    echo ""
    echo "=== Team assembled (${success} launched, ${failed} failed) ==="
}
