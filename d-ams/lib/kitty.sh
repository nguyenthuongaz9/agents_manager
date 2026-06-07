#!/bin/bash
#===============================================================================
# Kitty Terminal Integration - D-AMS Agent Manager
# Launch agents in Kitty tabs/windows with auto token-retry and state tracking
#===============================================================================

# Check if running inside Kitty
kitty_detect() {
    if [ -n "$KITTY_WINDOW_ID" ] || [ -n "$KITTY_PID" ]; then
        return 0
    fi
    return 1
}

# Detect active Kitty socket
_KITTY_SOCK=""
_kitty_find_sock() {
    [ -n "$_KITTY_SOCK" ] && return 0
    local sock
    for sock in /tmp/kitty-remote /tmp/kitty-remote-*; do
        [ -S "$sock" ] || continue
        if timeout 2 kitty @ --to "unix:$sock" ls &>/dev/null; then
            _KITTY_SOCK="$sock"
            return 0
        fi
    done
    return 1
}

kitty_remote_ok() { _kitty_find_sock; }

_kitty_at() {
    if _kitty_find_sock; then
        kitty @ --to "unix:${_KITTY_SOCK}" "$@"
    else
        kitty @ "$@"
    fi
}

#-------------------------------------------------------------------------------
# Write a self-contained launcher script for one agent.
# The script includes:
#   - Display brief / role context
#   - First-run command (from msg file)
#   - Auto-retry loop when token/rate limit detected
#   - State file updates (running / paused_token / completed)
#   - On resume: read checkpoint file and continue from there
#-------------------------------------------------------------------------------
_kitty_write_launcher() {
    local agent_key="$1"
    local agent_name="$2"
    local agent_cmd="$3"
    local workspace="${4:-}"

    local launcher="/tmp/d-ams-launcher-${agent_key}.sh"
    local brief_file="/tmp/d-ams-${agent_key}.brief"
    local msg_file="/tmp/d-ams-${agent_key}.msg"
    local state_file=""
    local checkpoint_file=""
    [ -n "$workspace" ] && state_file="$workspace/project-state.conf"
    [ -n "$workspace" ] && checkpoint_file="$workspace/checkpoint-${agent_key}.md"
    local retry_wait="${TOKEN_RETRY_WAIT:-3600}"

    # Part 1: header variables (compile-time values embedded literally)
    {
        printf '#!/bin/bash\n'
        printf '# D-AMS auto-launcher — %s\n' "$agent_name"
        printf 'export PATH="$HOME/.local/bin:$PATH"\n\n'
        printf 'AGENT_KEY="%s"\n'          "$agent_key"
        printf 'AGENT_NAME="%s"\n'         "$agent_name"
        printf 'WORKSPACE="%s"\n'          "$workspace"
        printf 'STATE_FILE="%s"\n'         "$state_file"
        printf 'CHECKPOINT_FILE="%s"\n'    "$checkpoint_file"
        printf 'MSG_FILE="%s"\n'           "$msg_file"
        printf 'BRIEF_FILE="%s"\n'         "$brief_file"
        printf 'TOKEN_RETRY_WAIT="%s"\n'   "$retry_wait"
        printf 'MAX_RETRIES=24\n\n'

        # Part 2: agent-specific _run_first function
        printf '_run_first() {\n'
        case "$agent_key" in
            CLAUDE)
                printf '    local msg; msg=$(cat "$MSG_FILE" 2>/dev/null)\n'
                printf '    if [ -n "$msg" ]; then\n'
                printf '        %s --dangerously-skip-permissions "$msg"\n' "$agent_cmd"
                printf '    else\n'
                printf '        %s --dangerously-skip-permissions\n' "$agent_cmd"
                printf '    fi\n'
                ;;
            GEMINI)
                printf '    local msg; msg=$(cat "$MSG_FILE" 2>/dev/null)\n'
                printf '    if [ -n "$msg" ]; then\n'
                printf '        %s --yolo --skip-trust -i "$msg"\n' "$agent_cmd"
                printf '    else\n'
                printf '        %s --yolo --skip-trust\n' "$agent_cmd"
                printf '    fi\n'
                ;;
            OPENCODE)
                printf '    local msg; msg=$(cat "$MSG_FILE" 2>/dev/null)\n'
                printf '    if [ -n "$msg" ]; then\n'
                printf '        %s run "$msg"\n' "$agent_cmd"
                printf '    else\n'
                printf '        %s\n' "$agent_cmd"
                printf '    fi\n'
                ;;
            *)
                printf '    %s\n' "$agent_cmd"
                ;;
        esac
        printf '}\n\n'

        # Part 3: agent-specific _run_continue function (reads checkpoint or msg)
        printf '_run_continue() {\n'
        printf '    local prev; prev=$(cat "$CHECKPOINT_FILE" 2>/dev/null)\n'
        printf '    local base; base=$(cat "$MSG_FILE" 2>/dev/null)\n'
        printf '    local CMSG\n'
        printf '    if [ -n "$prev" ]; then\n'
        printf '        CMSG="RESUME: Continue work on %s project. Previous checkpoint: ${prev}. Continue all remaining tasks without repeating completed work."\n' "$agent_name"
        printf '    else\n'
        printf '        CMSG="${base} [RESUMED after interruption — scan existing workspace files first, then continue from where work stopped]"\n'
        printf '    fi\n'
        case "$agent_key" in
            CLAUDE)
                printf '    %s --dangerously-skip-permissions "$CMSG"\n' "$agent_cmd"
                ;;
            GEMINI)
                printf '    %s --yolo --skip-trust -i "$CMSG"\n' "$agent_cmd"
                ;;
            OPENCODE)
                printf '    %s run "$CMSG"\n' "$agent_cmd"
                ;;
            *)
                printf '    %s\n' "$agent_cmd"
                ;;
        esac
        printf '}\n\n'
    } > "$launcher"

    # Part 4: common runtime body — quoted heredoc so no compile-time expansion
    cat >> "$launcher" <<'RUNTIME_BODY'
# Display header
clear
printf '\033[1;36m=== %s ===\033[0m\n\n' "$AGENT_NAME"
[ -f "$BRIEF_FILE" ] && { printf '\033[2m'; cat "$BRIEF_FILE"; printf '\033[0m\n\n'; sleep 2; }

# Update this agent's status in the project state file
_state_set() {
    local s="$1"
    [ -f "$STATE_FILE" ] || return
    local now; now=$(date +%Y-%m-%dT%H:%M:%S)
    sed -i "s|^AGENT_${AGENT_KEY}_STATUS=.*|AGENT_${AGENT_KEY}_STATUS=${s}|" "$STATE_FILE" 2>/dev/null
    sed -i "s|^AGENT_${AGENT_KEY}_LAST_UPDATED=.*|AGENT_${AGENT_KEY}_LAST_UPDATED=${now}|" "$STATE_FILE" 2>/dev/null
    sed -i "s|^UPDATED_AT=.*|UPDATED_AT=${now}|" "$STATE_FILE" 2>/dev/null
}

# Detect token / rate-limit exit
# Returns 0 (true) if the exit looks like a token problem, 1 (false) otherwise
_is_token_limit() {
    local exit_code="$1" elapsed="$2"

    # Clean exit = completed normally
    [ "$exit_code" -eq 0 ] && return 1

    # For Claude Code: check recent project JSONL files for API error entries
    if [ "$AGENT_KEY" = "CLAUDE" ]; then
        if find "$HOME/.claude/projects" -name "*.jsonl" -mmin -2 2>/dev/null \
               | xargs -I{} tail -15 {} 2>/dev/null \
               | grep -qi 'rate_limit\|overloaded\|usage_limit'; then
            return 0
        fi
    fi

    # Heuristic: non-zero exit AND the agent barely ran (<30s) = likely API/token error
    [ "$elapsed" -lt 30 ] && return 0

    return 1
}

_state_set "running"
retry=0
first_run=1

while [ "$retry" -lt "$MAX_RETRIES" ]; do
    start=$SECONDS

    if [ "$first_run" -eq 1 ]; then
        first_run=0
        _run_first
    else
        _run_continue
    fi

    exit_code=$?
    elapsed=$((SECONDS - start))

    if _is_token_limit "$exit_code" "$elapsed"; then
        _state_set "paused_token"
        printf '\n\033[33m⏸  Token/rate limit — auto-pausing %d min\033[0m\n' "$((TOKEN_RETRY_WAIT / 60))"
        printf '   Retry %d/%d  |  Ctrl+C to cancel auto-retry\n' "$((retry + 1))" "$MAX_RETRIES"

        i=$TOKEN_RETRY_WAIT
        while [ "$i" -gt 0 ]; do
            printf '\r   Resuming in \033[1m%02d:%02d\033[0m...' "$((i / 60))" "$((i % 60))"
            sleep 1
            i=$((i - 1))
        done
        printf '\n'

        retry=$((retry + 1))
        _state_set "running"
    else
        _state_set "completed"
        break
    fi
done

printf '\n\033[33m[%s exited — tab stays open]\033[0m\n' "$AGENT_NAME"
exec bash
RUNTIME_BODY

    chmod +x "$launcher"
    echo "$launcher"
}

# Return the bash command string to run in a Kitty tab
# Writes a launcher script and returns "bash <path>"
_kitty_launch_cmd() {
    local agent_key="$1"
    local agent_name="$2"
    local agent_cmd="$3"
    local workspace="${4:-}"

    local launcher
    launcher=$(_kitty_write_launcher "$agent_key" "$agent_name" "$agent_cmd" "$workspace")
    printf 'bash %s' "$launcher"
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

    local launch_cmd
    launch_cmd=$(_kitty_launch_cmd "$agent_key" "$agent_name" "$agent_cmd" "$working_dir")

    if kitty_detect && kitty_remote_ok; then
        local _wid
        _wid=$(kitty @ --to "unix:${_KITTY_SOCK}" launch --type window --title "$window_title" \
            --cwd "$working_dir" --keep-focus \
            bash -c "$launch_cmd" 2>/dev/null)
        if [ -n "$_wid" ]; then
            echo "Launched ${agent_name} in new Kitty window (id: ${_wid})"
            return 0
        fi
        echo "WARNING: Kitty launch failed, starting ${agent_cmd} in background..."
    elif command -v kitty &>/dev/null && [ -n "$DISPLAY" ]; then
        kitty --title "$window_title" --directory "$working_dir" \
            bash -c "$launch_cmd" &
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

    local launch_cmd
    launch_cmd=$(_kitty_launch_cmd "$agent_key" "$agent_name" "$agent_cmd" "$working_dir")

    if kitty_detect && kitty_remote_ok; then
        local _wid
        _wid=$(kitty @ --to "unix:${_KITTY_SOCK}" launch --type tab --title "$tab_title" \
            --cwd "$working_dir" --keep-focus \
            bash -c "$launch_cmd" 2>/dev/null)
        if [ -n "$_wid" ]; then
            echo "Launched ${agent_name} in new Kitty tab (id: ${_wid})"
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

    if kitty_remote_ok; then
        local wid
        wid=$(kitty @ --to "unix:${_KITTY_SOCK}" ls 2>/dev/null | python3 -c "
import json,sys
data=json.load(sys.stdin)
for w in data:
    t=w.get('title','')
    if '$title' in t:
        print(w['id'])
        break
" 2>/dev/null)
        if [ -n "$wid" ]; then
            kitty @ --to "unix:${_KITTY_SOCK}" send-text --match id:"$wid" "$text"
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

    local launch_cmd
    launch_cmd=$(_kitty_launch_cmd "$agent_key" "$agent_name" "$agent_cmd" "$working_dir")

    if kitty_detect && kitty_remote_ok; then
        local _wid
        _wid=$(kitty @ --to "unix:${_KITTY_SOCK}" launch --type os-window --cwd "$working_dir" \
            bash -c "$launch_cmd" 2>/dev/null)
        if [ -n "$_wid" ]; then
            echo "Launched ${agent_name} in new OS window"
            return 0
        fi
        echo "WARNING: Kitty split launch failed, starting ${agent_cmd} in background..."
    elif command -v kitty &>/dev/null && [ -n "$DISPLAY" ]; then
        kitty --directory "$working_dir" \
            bash -c "$launch_cmd" &
        echo "Launched ${agent_name} in new OS window (background)"
        return 0
    fi

    echo "Starting ${agent_cmd} in background..."
    (cd "$working_dir" && nohup "$agent_cmd" </dev/null &>/dev/null &)
    echo "Launched ${agent_name} in background"
    return 1
}

# Build the initial task message for each agent role
# Includes checkpoint instruction so agents self-document progress
kitty_build_send_msg() {
    local agent_key="$1"
    local project_name="$2"
    local project_type="$3"

    case "$agent_key" in
        CLAUDE)
            printf '@requirements.md You are the Backend Developer for the %s project (%s). Build the server, REST API, database schema, and business logic based on the requirements. When you complete significant milestones, write a brief progress summary to checkpoint-CLAUDE.md (what is done, what remains). Start immediately.' \
                "$project_name" "$project_type"
            ;;
        GEMINI)
            printf 'You are the Tech Lead for the %s project (%s). Read requirements.md, design the architecture, assign backend tasks to Claude Code and frontend+QA tasks to OpenCode, then guide the team. Write key decisions to checkpoint-GEMINI.md. Start now.' \
                "$project_name" "$project_type"
            ;;
        OPENCODE)
            printf '@requirements.md You are the Frontend and QA Developer for the %s project (%s). Build UI components, frontend logic, and write tests. When you complete milestones, write a progress summary to checkpoint-OPENCODE.md. Start immediately.' \
                "$project_name" "$project_type"
            ;;
        *)
            printf 'Start working on the %s project (%s). Read requirements.md for full details.' \
                "$project_name" "$project_type"
            ;;
    esac
}

# Build the role brief shown at agent startup (banner text, not the prompt)
kitty_build_prompt() {
    local agent_key="$1"
    local project_name="$2"
    local project_type="$3"

    case "$agent_key" in
        CLAUDE)
            printf 'ROLE: Backend Developer | Project: %s | Type: %s\nTASK: Build server, REST API endpoints, database schema, business logic.\nCHECKPOINT: Write progress to checkpoint-CLAUDE.md after each milestone.' \
                "$project_name" "$project_type"
            ;;
        GEMINI)
            printf 'ROLE: Tech Lead | Project: %s | Type: %s\nTASK: Analyze requirements, design architecture, guide backend (Claude) and frontend+QA (OpenCode) teams.\nCHECKPOINT: Write decisions to checkpoint-GEMINI.md.' \
                "$project_name" "$project_type"
            ;;
        OPENCODE)
            printf 'ROLE: Frontend & QA Developer | Project: %s | Type: %s\nTASK: Build UI components, frontend logic, write tests, ensure quality.\nCHECKPOINT: Write progress to checkpoint-OPENCODE.md after each milestone.' \
                "$project_name" "$project_type"
            ;;
        *)
            printf 'ROLE: Developer | Project: %s | Type: %s\nTASK: Read requirements.md and implement assigned components.' \
                "$project_name" "$project_type"
            ;;
    esac
}

# Build a "continue" prompt for a resumed agent
# Uses existing checkpoint file content if available
kitty_build_continue_prompt() {
    local agent_key="$1"
    local project_name="$2"
    local project_type="$3"
    local task="${4:-}"
    local checkpoint="${5:-}"
    local workspace="${6:-}"

    local role_context
    case "$agent_key" in
        CLAUDE)   role_context="Backend Developer" ;;
        GEMINI)   role_context="Tech Lead" ;;
        OPENCODE) role_context="Frontend & QA Developer" ;;
        *)        role_context="Developer" ;;
    esac

    local base="RESUME: You are the ${role_context} for the ${project_name} project (${project_type})."

    if [ -n "$checkpoint" ]; then
        printf '%s Previous checkpoint: %s. Scan the workspace files to confirm current state, then continue all remaining tasks without repeating completed work.' \
            "$base" "$checkpoint"
    elif [ -n "$task" ]; then
        printf '%s Your task: %s. Scan existing workspace files to see what is already done, then continue from where work stopped.' \
            "$base" "$task"
    else
        printf '%s Read requirements.md and scan existing workspace files to understand what has been built. Continue with any remaining work.' \
            "$base"
    fi
}

# Send initial task via send-text (fallback for agents without CLI prompt args)
kitty_send_agent_prompt() {
    local agent_key="$1"
    local msg="$2"
    local delay="${3:-12}"

    [ -z "$msg" ] && return 0

    local name_var="AGENT_${agent_key}_NAME"
    local agent_name="${!name_var}"

    sleep "$delay"

    local safe_msg="${msg//$'\n'/ }"
    if kitty_remote_ok; then
        kitty @ --to "unix:${_KITTY_SOCK}" send-text --match "title:${agent_name}" "${safe_msg}"$'\r' &>/dev/null
    fi
}

# Launch all agents in separate Kitty tabs (Team Assembly)
kitty_assemble_team() {
    local project_dir="$1"
    local project_name="${2:-}"
    local project_type="${3:-}"
    local requirements="${4:-}"
    local workspace="${5:-$project_dir}"

    local total=${#AGENTS_LIST[@]}
    local success=0
    local failed=0

    echo "=== Assembling Agent Team ==="
    echo "  Agents to launch: ${total}"
    echo ""

    # Write brief and message files before launching tabs
    if [ -n "$project_name" ]; then
        for key in "${AGENTS_LIST[@]}"; do
            kitty_build_prompt    "$key" "$project_name" "$project_type" > "/tmp/d-ams-${key}.brief"
            kitty_build_send_msg  "$key" "$project_name" "$project_type" > "/tmp/d-ams-${key}.msg"
        done
    fi

    for key in "${AGENTS_LIST[@]}"; do
        local name_var="AGENT_${key}_NAME"
        local icon_var="AGENT_${key}_ICON"
        local name="${!name_var}"
        local icon="${!icon_var}"

        echo -ne "  ${icon} ${name}... "
        if kitty_launch_agent_tab "$key" "$workspace" >/dev/null 2>&1; then
            echo -e "${GREEN}✓${NC}"
            ((success++))
        else
            echo -e "${YELLOW}⚠${NC}"
            ((failed++))
        fi
    done

    echo ""
    echo "=== Team assembled (${success} launched, ${failed} failed) ==="
}
