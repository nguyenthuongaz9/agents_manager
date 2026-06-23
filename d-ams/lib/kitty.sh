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

    # Compute prerequisite checkpoint files that must exist before this agent starts.
    # ACTIVE_TEAM_KEYS (global) holds the space-separated keys for the current project,
    # which lets QA and late-stage agents wait only for agents actually in the team.
    local prereqs=""
    if [ -n "$workspace" ]; then
        case "$agent_key" in
            # Tier 1 — wait for LEADER architecture
            BACKEND|DBA|MOBILE|ML|DATA)
                prereqs="${workspace}/checkpoint-LEADER.md" ;;
            # Tier 2 — wait for BACKEND (need API / code to build on)
            FRONTEND|DEVOPS|SECURITY)
                prereqs="${workspace}/checkpoint-BACKEND.md" ;;
            # QA — wait for every non-LEADER/non-QA agent actually in the team
            QA)
                local _active="${ACTIVE_TEAM_KEYS:-}"
                for _tk in $_active; do
                    [[ "$_tk" == "LEADER" || "$_tk" == "QA" ]] && continue
                    prereqs+=" ${workspace}/checkpoint-${_tk}.md"
                done
                prereqs="${prereqs# }"
                ;;
        esac
    fi

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
        printf 'MAX_RETRIES=24\n'
        printf 'PREREQ_FILES="%s"\n\n'     "$prereqs"

        # Part 2: _run_first — loads memory resume checkpoint if available from prior quota hit
        printf '_run_first() {\n'
        printf '    local msg; msg=$(cat "$MSG_FILE" 2>/dev/null)\n'
        printf '    local _res_f="${WORKSPACE}/.memory/resume/${AGENT_KEY}-resume.md"\n'
        printf '    local _idx_f="${WORKSPACE}/.memory/INDEX.md"\n'
        printf '    if [ -f "$_res_f" ]; then\n'
        printf '        local _res; _res=$(cat "$_res_f")\n'
        printf '        local _idx=""; [ -f "$_idx_f" ] && _idx=$(cat "$_idx_f")\n'
        printf '        msg="=== MEMORY: PROJECT INDEX ===\n${_idx}\n\n=== MEMORY: RESUME CHECKPOINT ===\n${_res}\n\n=== ORIGINAL TASK ===\n${msg}"\n'
        printf '    fi\n'
        printf '    if [ -n "$msg" ]; then\n'
        printf '        %s --dangerously-skip-permissions -p "$msg"\n' "$agent_cmd"
        printf '    else\n'
        printf '        %s --dangerously-skip-permissions\n' "$agent_cmd"
        printf '    fi\n'
        printf '}\n\n'

        # Part 3: _run_continue — loads full memory context for smart, token-efficient resumption
        printf '_run_continue() {\n'
        printf '    local _idx_f="${WORKSPACE}/.memory/INDEX.md"\n'
        printf '    local _snap_f="${WORKSPACE}/.memory/hot/${AGENT_KEY}-snapshot.md"\n'
        printf '    local _res_f="${WORKSPACE}/.memory/resume/${AGENT_KEY}-resume.md"\n'
        printf '    local _ctx=""\n'
        printf '    [ -f "$_idx_f" ]  && _ctx+="=== MEMORY: PROJECT INDEX ===\n$(cat "$_idx_f")\n\n"\n'
        printf '    [ -f "$_snap_f" ] && _ctx+="=== MEMORY: YOUR LAST SNAPSHOT ===\n$(cat "$_snap_f")\n\n"\n'
        printf '    [ -f "$_res_f" ]  && _ctx+="=== MEMORY: RESUME CHECKPOINT ===\n$(cat "$_res_f")\n\n"\n'
        printf '    local _cp; _cp=$(cat "$CHECKPOINT_FILE" 2>/dev/null)\n'
        printf '    [ -n "$_cp" ] && _ctx+="=== CHECKPOINT FILE ===\n${_cp}\n\n"\n'
        printf '    local CMSG\n'
        printf '    if [ -n "$_ctx" ]; then\n'
        printf '        CMSG="${_ctx}---\nRESUME: Run find . -type f | head -60 to see current workspace state.\nContinue ALL remaining tasks without repeating completed work. Update .memory/hot/${AGENT_KEY}-snapshot.md after each milestone."\n'
        printf '    else\n'
        printf '        CMSG="RESUME on %s project: scan workspace with find . -type f | head -60 then continue from where work stopped."\n' "$agent_name"
        printf '    fi\n'
        printf '    %s --dangerously-skip-permissions -p "$CMSG"\n' "$agent_cmd"
        printf '}\n\n'
    } > "$launcher"

    # Part 4: common runtime body — quoted heredoc so no compile-time expansion
    cat >> "$launcher" <<'RUNTIME_BODY'
# Display header
clear
printf '\033[1;36m=== %s ===\033[0m\n\n' "$AGENT_NAME"
[ -f "$BRIEF_FILE" ] && { printf '\033[2m'; cat "$BRIEF_FILE"; printf '\033[0m\n\n'; sleep 2; }

# Wait for prerequisite checkpoint files before starting
if [ -n "$PREREQ_FILES" ]; then
    _any_missing=0
    for _prereq in $PREREQ_FILES; do
        [ ! -f "$_prereq" ] && _any_missing=1 && break
    done
    if [ "$_any_missing" -eq 1 ]; then
        printf '\033[33m⏳  Waiting for prerequisite agents to finish...\033[0m\n'
        _all_ready=0
        while [ "$_all_ready" -eq 0 ]; do
            _all_ready=1
            for _prereq in $PREREQ_FILES; do
                if [ ! -f "$_prereq" ]; then
                    _all_ready=0
                    printf '\r   \033[2mWaiting for: %s\033[0m   ' "$(basename "$_prereq")"
                    sleep 10
                    break
                fi
            done
        done
        printf '\r\033[32m✓  All prerequisites ready — starting %s\033[0m\n\n' "$AGENT_NAME"
        sleep 1
    fi
fi

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

    # Check recent Claude project JSONL files for API error entries
    if find "$HOME/.claude/projects" -name "*.jsonl" -mmin -2 2>/dev/null \
           | xargs -I{} tail -15 {} 2>/dev/null \
           | grep -qi 'rate_limit\|overloaded\|usage_limit'; then
        return 0
    fi

    # Heuristic: non-zero exit AND the agent barely ran (<30s) = likely API/token error
    [ "$elapsed" -lt 30 ] && return 0

    return 1
}

# Save resume checkpoint to .memory/resume/ when quota/token limit is hit
# Agents can read this on restart to continue exactly where they left off
_memory_save_pause() {
    local _mem="${WORKSPACE}/.memory"
    [ -d "$_mem" ] || return 0
    local _now; _now=$(date +%Y-%m-%dT%H:%M:%S)
    local _snap="$_mem/hot/${AGENT_KEY}-snapshot.md"
    local _res="$_mem/resume/${AGENT_KEY}-resume.md"
    mkdir -p "$_mem/resume"
    local _snap_ctx="No snapshot saved yet — agent had not written .memory/hot/${AGENT_KEY}-snapshot.md"
    [ -f "$_snap" ] && _snap_ctx=$(cat "$_snap")
    local _cp_ctx="No checkpoint saved yet"
    [ -f "$CHECKPOINT_FILE" ] && _cp_ctx=$(cat "$CHECKPOINT_FILE")
    {
        printf '# RESUME CHECKPOINT — %s\n' "$AGENT_KEY"
        printf 'Saved: %s\n' "$_now"
        printf 'Reason: quota/rate-limit auto-pause\n\n'
        printf '## How to Resume\n'
        printf '1. Read this file carefully\n'
        printf '2. Run: find . -type f | head -60  (see current workspace)\n'
        printf '3. Continue ONLY remaining work -- do NOT redo completed tasks\n'
        printf '4. Update .memory/hot/%s-snapshot.md after each milestone\n\n' "$AGENT_KEY"
        printf '## Last Snapshot (your state before pause)\n%s\n\n' "$_snap_ctx"
        printf '## Checkpoint File (detailed progress)\n%s\n' "$_cp_ctx"
    } > "$_res"
    local _idx="$_mem/INDEX.md"
    if [ -f "$_idx" ]; then
        local _hits; _hits=$(grep "Quota hits:" "$_idx" | grep -o '[0-9]*' | head -1)
        _hits=$(( ${_hits:-0} + 1 ))
        sed -i "s/- Quota hits: [0-9]*/- Quota hits: $_hits/" "$_idx" 2>/dev/null
    fi
    printf '  \033[2m[memory: resume checkpoint saved → %s]\033[0m\n' "$_res"
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
        _memory_save_pause
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
# $4 = workspace (absolute path) — prepended as WORKING DIRECTORY context
kitty_build_send_msg() {
    local agent_key="$1"
    local project_name="$2"
    local project_type="$3"
    local workspace="${4:-}"

    local wd_header=""
    if [ -n "$workspace" ]; then
        wd_header="WORKING DIRECTORY: ${workspace}
You MUST only create or edit files inside this directory.
ALWAYS use relative paths: ./src/index.js, ./package.json, etc.
NEVER use absolute paths like /home/... or /tmp/...
Every Write/Edit tool call must target a path starting with ./ or a bare filename.

"
    fi

    case "$agent_key" in
        LEADER)
            printf '%sYou are the Tech Lead for the "%s" project (%s).\n\nRead @requirements.md, then use the Write tool to create these files NOW:\n\n1. ARCHITECTURE.md — chosen tech stack, directory structure, API endpoint list (method + path + request/response), database schema (tables, columns, types), deployment notes\n2. checkpoint-LEADER.md — task list for Backend Dev and Frontend Dev with exact file paths they should create\n\nDo NOT describe what you will do — use the Write tool to create the actual files immediately.\nAfter writing both files, print: LEADER DONE.' \
                "$wd_header" "$project_name" "$project_type"
            ;;
        BACKEND)
            printf '%s@requirements.md\n\nYou are the Backend Developer for the "%s" project (%s).\n\nCRITICAL: Use Write, Edit and Bash tools to CREATE ACTUAL CODE FILES — do NOT print summaries or code blocks in chat.\n\nSteps (execute each with tools):\n1. Read @requirements.md and @checkpoint-LEADER.md (if exists) for architecture\n2. Create project structure: Write package.json (or equivalent) with all dependencies\n3. Write ALL source files: server entry, routes, controllers, services, DB schema/migrations\n4. Install dependencies: run "npm install" (or equivalent) via Bash\n5. Run tests via Bash — fix any errors before continuing\n6. Write @checkpoint-BACKEND.md listing every file created and its purpose\n\nStart by creating package.json NOW with the Write tool.' \
                "$wd_header" "$project_name" "$project_type"
            ;;
        FRONTEND)
            printf '%s@requirements.md\n\nYou are the Frontend Developer for the "%s" project (%s).\n\nCRITICAL: Use Write, Edit and Bash tools to CREATE ACTUAL CODE FILES — do NOT print summaries or code blocks in chat.\n\nSteps (execute each with tools):\n1. Read @requirements.md and @checkpoint-BACKEND.md (if exists) for API endpoints\n2. Create project entry file and directory structure\n3. Write ALL UI components, pages, and styles\n4. Wire up all API calls to backend endpoints\n5. Run build/lint via Bash — fix any errors\n6. Write @checkpoint-FRONTEND.md listing every file created and its purpose\n\nStart by creating the main entry file NOW with the Write tool.' \
                "$wd_header" "$project_name" "$project_type"
            ;;
        QA)
            printf '%s@requirements.md\n\nYou are the QA Engineer for the "%s" project (%s).\n\nCRITICAL: Use Write, Edit and Bash tools to CREATE ACTUAL TEST FILES AND RUN THEM — do NOT print summaries.\n\nSteps (execute each with tools):\n1. Read @requirements.md — list every requirement that must be verified\n2. Run "ls -la" and "find . -type f -name '"'"'*.ts'"'"' -o -name '"'"'*.js'"'"'" via Bash to see what was built\n3. Write test files for all features (unit + integration + e2e)\n4. Run tests via Bash: capture full output\n5. For every failing test: edit the source file to fix the bug, re-run until green\n6. Write @checkpoint-QA.md: tests written, pass/fail counts, bugs found and fixed\n\nStart by scanning files with Bash NOW.' \
                "$wd_header" "$project_name" "$project_type"
            ;;
        DBA)
            printf '%s@requirements.md\n\nYou are the Database Administrator for the "%s" project (%s).\n\nCRITICAL: Use Write, Edit and Bash tools to CREATE ACTUAL FILES — do NOT print summaries or SQL blocks in chat.\n\nSteps (execute each with tools):\n1. Read @requirements.md and @ARCHITECTURE.md (if exists) for the data model\n2. Write ALL migration files: CREATE TABLE statements, indexes, foreign keys, seed data\n3. If an ORM is used (Prisma/Drizzle/SQLAlchemy), write the schema/model files\n4. Run migrations via Bash — fix any errors\n5. Write @checkpoint-DBA.md listing every migration/schema file and its purpose\n\nStart by writing the first migration file NOW with the Write tool.' \
                "$wd_header" "$project_name" "$project_type"
            ;;
        MOBILE)
            printf '%s@requirements.md\n\nYou are the Mobile Developer for the "%s" project (%s).\n\nCRITICAL: Use Write, Edit and Bash tools to CREATE ACTUAL CODE FILES — do NOT print summaries or code blocks in chat.\n\nSteps (execute each with tools):\n1. Read @requirements.md and @checkpoint-LEADER.md for architecture\n2. Create project structure and config files (package.json / pubspec.yaml / etc.)\n3. Write ALL screens, components, navigation, and state management\n4. Integrate with backend API endpoints from @checkpoint-BACKEND.md (if exists)\n5. Run build/lint via Bash — fix errors\n6. Write @checkpoint-MOBILE.md listing every file created and its purpose\n\nStart by creating the project entry file NOW with the Write tool.' \
                "$wd_header" "$project_name" "$project_type"
            ;;
        ML)
            printf '%s@requirements.md\n\nYou are the Machine Learning Engineer for the "%s" project (%s).\n\nCRITICAL: Use Write, Edit and Bash tools to CREATE ACTUAL CODE FILES — do NOT describe or print code blocks in chat.\n\nSteps (execute each with tools):\n1. Read @requirements.md and @ARCHITECTURE.md for ML objectives\n2. Write data loading/preprocessing scripts\n3. Write model definition and training pipeline\n4. Write inference/serving code (API endpoint or script)\n5. Run training or tests via Bash — fix errors\n6. Write @checkpoint-ML.md listing every file, model metrics, and next steps\n\nStart by creating the data preprocessing script NOW with the Write tool.' \
                "$wd_header" "$project_name" "$project_type"
            ;;
        DATA)
            printf '%s@requirements.md\n\nYou are the Data Scientist for the "%s" project (%s).\n\nCRITICAL: Use Write, Edit and Bash tools to CREATE ACTUAL FILES — notebooks, scripts, charts — do NOT print summaries in chat.\n\nSteps (execute each with tools):\n1. Read @requirements.md for analytical goals\n2. Write data loading and cleaning scripts\n3. Perform analysis: aggregations, statistics, visualisations\n4. Export results: charts as PNG, summary as Markdown or CSV\n5. Run analysis scripts via Bash — fix any errors\n6. Write @checkpoint-DATA.md: analysis performed, files created, key findings\n\nStart by creating the data loading script NOW with the Write tool.' \
                "$wd_header" "$project_name" "$project_type"
            ;;
        DEVOPS)
            printf '%s@requirements.md\n\nYou are the DevOps Engineer for the "%s" project (%s).\n\nCRITICAL: Use Write, Edit and Bash tools to CREATE ACTUAL CONFIG FILES — do NOT print summaries in chat.\n\nSteps (execute each with tools):\n1. Read @requirements.md and @checkpoint-BACKEND.md for what needs to be deployed\n2. Write Dockerfile and docker-compose.yml (or equivalent)\n3. Write CI/CD pipeline config (.github/workflows/, .gitlab-ci.yml, etc.)\n4. Write any infra-as-code files (Terraform, Helm charts, etc.)\n5. Validate configs via Bash (docker build, yaml lint, etc.) — fix errors\n6. Write @checkpoint-DEVOPS.md listing every config file and its purpose\n\nStart by creating the Dockerfile NOW with the Write tool.' \
                "$wd_header" "$project_name" "$project_type"
            ;;
        SECURITY)
            printf '%s@requirements.md\n\nYou are the Security Engineer for the "%s" project (%s).\n\nCRITICAL: Use Write, Edit and Bash tools to IMPLEMENT security measures in actual code files — do NOT just list issues.\n\nSteps (execute each with tools):\n1. Read @requirements.md and @checkpoint-BACKEND.md to understand the codebase\n2. Run: find . -type f -name "*.ts" -o -name "*.js" -o -name "*.py" | head -30 via Bash\n3. Check for: hardcoded secrets, plaintext passwords, missing input validation, open CORS, weak auth\n4. Edit source files to fix all security issues found\n5. Write auth middleware / input validators if missing\n6. Write @checkpoint-SECURITY.md: vulnerabilities found, fixes applied, remaining risks\n\nStart by scanning files with Bash NOW.' \
                "$wd_header" "$project_name" "$project_type"
            ;;
        *)
            printf '%sStart working on the "%s" project (%s). Read @requirements.md, then use Write and Bash tools to create all required files. Do NOT just describe — create actual files.' \
                "$wd_header" "$project_name" "$project_type"
            ;;
    esac

    # Memory protocol appended to ALL agent prompts — critical for large project efficiency
    printf '\n\nMEMORY PROTOCOL (mandatory — prevents wasting context re-reading the project):\n1. On start: run "cat .memory/INDEX.md 2>/dev/null" to check project overview\n2. After completing each file/task — Write .memory/hot/%s-snapshot.md:\n   Status: running\n   Last action: [what you just completed]\n   Next: [what to do next]\n   Files created: [relative paths]\n3. When you find a bug or blocker — append to .memory/semantic/issues.md:\n   [OPEN] description — by %s at TIMESTAMP\n4. When fully done — Update .memory/hot/%s-snapshot.md:\n   Status: COMPLETED\n   Summary: [all files created and their purpose]' \
        "$agent_key" "$agent_key" "$agent_key"
}

# Build the role brief shown at agent startup (banner text, not the prompt)
kitty_build_prompt() {
    local agent_key="$1"
    local project_name="$2"
    local project_type="$3"

    case "$agent_key" in
        LEADER)
            printf 'ROLE: Tech Lead / Architect | Project: %s | Type: %s\nTASK: Design architecture, define tech stack, break down tasks, guide team.\nCHECKPOINT: Write decisions to checkpoint-LEADER.md.' \
                "$project_name" "$project_type"
            ;;
        BACKEND)
            printf 'ROLE: Backend Developer | Project: %s | Type: %s\nTASK: Build server, REST API endpoints, database schema, business logic.\nCHECKPOINT: Write progress to checkpoint-BACKEND.md after each milestone.' \
                "$project_name" "$project_type"
            ;;
        FRONTEND)
            printf 'ROLE: Frontend Developer | Project: %s | Type: %s\nTASK: Build UI components, pages, styles, client-side logic, connect to API.\nCHECKPOINT: Write progress to checkpoint-FRONTEND.md after each milestone.' \
                "$project_name" "$project_type"
            ;;
        DBA)
            printf 'ROLE: Database Administrator | Project: %s | Type: %s\nTASK: Design schema, write migrations, set up indexes and seed data.\nCHECKPOINT: Write progress to checkpoint-DBA.md after each milestone.' \
                "$project_name" "$project_type"
            ;;
        MOBILE)
            printf 'ROLE: Mobile Developer | Project: %s | Type: %s\nTASK: Build all screens, navigation, state management, and API integration.\nCHECKPOINT: Write progress to checkpoint-MOBILE.md after each milestone.' \
                "$project_name" "$project_type"
            ;;
        ML)
            printf 'ROLE: Machine Learning Engineer | Project: %s | Type: %s\nTASK: Build data pipeline, model definition, training and inference code.\nCHECKPOINT: Write progress to checkpoint-ML.md after each milestone.' \
                "$project_name" "$project_type"
            ;;
        DATA)
            printf 'ROLE: Data Scientist | Project: %s | Type: %s\nTASK: Write data loading, analysis, visualisation scripts and export results.\nCHECKPOINT: Write progress to checkpoint-DATA.md after each milestone.' \
                "$project_name" "$project_type"
            ;;
        DEVOPS)
            printf 'ROLE: DevOps Engineer | Project: %s | Type: %s\nTASK: Write Dockerfile, CI/CD pipeline, and infrastructure-as-code configs.\nCHECKPOINT: Write progress to checkpoint-DEVOPS.md after each milestone.' \
                "$project_name" "$project_type"
            ;;
        SECURITY)
            printf 'ROLE: Security Engineer | Project: %s | Type: %s\nTASK: Audit codebase, fix vulnerabilities, implement auth and input validation.\nCHECKPOINT: Write findings and fixes to checkpoint-SECURITY.md.' \
                "$project_name" "$project_type"
            ;;
        QA)
            printf 'ROLE: QA/QC Engineer | Project: %s | Type: %s\nTASK: Write tests, validate requirements, discover and document bugs.\nCHECKPOINT: Write QA report to checkpoint-QA.md.' \
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
        LEADER)   role_context="Tech Lead / Architect" ;;
        BACKEND)  role_context="Backend Developer" ;;
        FRONTEND) role_context="Frontend Developer" ;;
        QA)       role_context="QA/QC Engineer" ;;
        *)        role_context="Developer" ;;
    esac

    local wd_line=""
    [ -n "$workspace" ] && wd_line="WORKING DIRECTORY: ${workspace} — use relative paths (./filename) for all file operations.
"

    local base="${wd_line}RESUME: You are the ${role_context} for the ${project_name} project (${project_type}).
CRITICAL: Use Write, Edit and Bash tools to CREATE and EDIT actual files — do NOT print summaries or code blocks in chat."

    if [ -n "$checkpoint" ]; then
        printf '%s\n\nPrevious checkpoint:\n%s\n\nRun "find . -type f | head -40" via Bash to see current workspace state, then continue ALL remaining tasks without repeating completed work. Fix any incomplete or broken files.' \
            "$base" "$checkpoint"
    elif [ -n "$task" ]; then
        printf '%s\n\nYour task: %s\n\nRun "find . -type f | head -40" via Bash to see what is already done, then continue from where work stopped.' \
            "$base" "$task"
    else
        printf '%s\n\nRun "find . -type f | head -40" via Bash to understand what has been built, then continue all remaining work using Write/Edit/Bash tools.' \
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
# $6 = space-separated active team keys (optional — falls back to AGENTS_LIST)
kitty_assemble_team() {
    local project_dir="$1"
    local project_name="${2:-}"
    local project_type="${3:-}"
    local requirements="${4:-}"
    local workspace="${5:-$project_dir}"
    local team_override="${6:-}"

    # Build the list of agents to launch
    local -a team_to_launch=()
    if [ -n "$team_override" ]; then
        read -ra team_to_launch <<< "$team_override"
    else
        team_to_launch=("${AGENTS_LIST[@]}")
    fi

    # Export active team so _kitty_write_launcher can compute QA prereqs correctly
    export ACTIVE_TEAM_KEYS="${team_to_launch[*]}"

    local total=${#team_to_launch[@]}
    local success=0
    local failed=0

    echo "=== Assembling Agent Team ==="
    echo "  Agents to launch: ${total}"
    echo ""

    # Write brief and message files before launching tabs
    if [ -n "$project_name" ]; then
        for key in "${team_to_launch[@]}"; do
            kitty_build_prompt    "$key" "$project_name" "$project_type" > "/tmp/d-ams-${key}.brief"
            kitty_build_send_msg  "$key" "$project_name" "$project_type" "$workspace" > "/tmp/d-ams-${key}.msg"
        done
    fi

    for key in "${team_to_launch[@]}"; do
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
