#!/bin/bash
#===============================================================================
# D-AMS Agent Manager
# Dynamic Agent Management System - Terminal Orchestrator
# Manages: Claude Code | Gemini | OpenCode
# Platform: Linux (Kitty Terminal)
#===============================================================================

VERSION="1.0.0"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="$PROJECT_DIR/config"
LIB_DIR="$PROJECT_DIR/lib"
SESSION_DIR="$PROJECT_DIR/sessions"
CURRENT_PHASE=1

# Load config
source "$CONFIG_DIR/agents.conf"

# Load libraries
source "$LIB_DIR/logging.sh"
source "$LIB_DIR/ui.sh"
source "$LIB_DIR/kitty.sh"

# ---- Globals ----
CURRENT_SESSION=""
LEADER="$DEFAULT_LEADER"
PROJECT_NAME=""
PROJECT_TYPE=""

# ---- Helper: resolve agent key from number ----
agent_key_from_num() {
    local idx=$(( $1 - 1 ))
    if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#AGENTS_LIST[@]}" ]; then
        echo "${AGENTS_LIST[$idx]}"
    else
        echo ""
    fi
}

# ---- Main Menu ----
main_menu() {
    while true; do
        ui_clear
        ui_header "Main Menu" "${PROJECT_NAME:+"Project: ${PROJECT_NAME} | Leader: $(eval echo \$AGENT_${LEADER}_NAME)"}"

        echo -e "${BOLD}Available Agents:${NC}"
        for i in "${!AGENTS_LIST[@]}"; do
            local key="${AGENTS_LIST[$i]}"
            local name_var="AGENT_${key}_NAME"
            local icon_var="AGENT_${key}_ICON"
            local role_var="AGENT_${key}_ROLE"
            echo -e "  ${!icon_var} ${BOLD}${!name_var}${NC} ${DIM}(${!role_var})${NC}"
        done
        echo ""

        local options=(
            "Start New Project & Assemble Team"
            "Launch Agent (Kitty tab)"
            "Assign Task to Agent"
            "View Session Log"
            "Workflow Status"
            "Configure Settings"
            "Help / About"
        )

        ui_menu "Select Action:" "${options[@]}"
        ui_ask "Choice"
        read -r choice

        case "$choice" in
            1) cmd_new_project ;;
            2) cmd_launch_agent ;;
            3) cmd_assign_task ;;
            4) cmd_view_log ;;
            5) cmd_workflow ;;
            6) cmd_settings ;;
            7) cmd_help ;;
            0) cmd_exit ;;
            *) echo -e "${RED}Invalid choice${NC}"; sleep 1 ;;
        esac
    done
}

# ---- Command: New Project ----
cmd_new_project() {
    ui_clear
    ui_header "New Project" "Phase 1: Intake & Analysis"

    ui_read PROJECT_NAME "Enter project name" "my-project"
    ui_read PROJECT_TYPE "Enter project type (web/mobile/cli/ai)" "cli"

    # Map project type to team template
    local team_desc=""
    case "$PROJECT_TYPE" in
        web)    team_desc="Web App Team: Backend Dev + Frontend Dev + DBA" ;;
        mobile) team_desc="Mobile Team: Mobile Dev + UI/UX + Backend API" ;;
        cli)    team_desc="CLI Tool Team: Systems Programmer + Tech Writer" ;;
        ai)     team_desc="AI Team: ML Engineer + Data Scientist + DBA" ;;
        *)      team_desc="Custom assembly based on requirements" ;;
    esac

    echo ""
    echo -e "${BOLD}Project:${NC} ${PROJECT_NAME}"
    echo -e "${BOLD}Type:${NC}    ${PROJECT_TYPE}"
    echo -e "${BOLD}Team:${NC}    ${team_desc}"
    echo -e "${BOLD}Leader:${NC}  $(eval echo \$AGENT_${LEADER}_NAME)"
    echo ""
    ui_confirm "Start project and assemble team?"

    if [ $? -eq 0 ]; then
        # Initialize session
        log_init "$PROJECT_NAME"
        CURRENT_SESSION="$LOG_FILE"
        log_phase 1 "Intake & Analysis"
        log_info "PROJECT" "Created project: ${PROJECT_NAME} (${PROJECT_TYPE})"
        log_info "LEADER" "Leader: $(eval echo \$AGENT_${LEADER}_NAME)"
        CURRENT_PHASE=2
        log_phase 2 "Team Assembly"

        echo ""
        echo -e "${GREEN}Team Assembly Phase${NC}"
        echo -e "Launching agents in Kitty tabs..."
        kitty_assemble_team "$PROJECT_DIR"

        log_info "TEAM" "Team assembled for ${PROJECT_NAME}"
        CURRENT_PHASE=3

        echo ""
        echo -e "${GREEN}✓ Project ${PROJECT_NAME} initialized${NC}"
        echo -e "  ${DIM}Session log:${NC} $LOG_FILE"
        ui_pause
    fi
}

# ---- Command: Launch Agent ----
cmd_launch_agent() {
    ui_clear
    ui_header "Launch Agent" "Start an agent in Kitty terminal"

    local options=()
    for key in "${AGENTS_LIST[@]}"; do
        local name_var="AGENT_${key}_NAME"
        local icon_var="AGENT_${key}_ICON"
        options+=("${!icon_var} ${!name_var}")
    done

    ui_menu "Select Agent to Launch:" "${options[@]}"
    ui_ask "Choice"
    read -r choice

    if [ "$choice" -ge 1 ] && [ "$choice" -le "${#AGENTS_LIST[@]}" ]; then
        local key
        key=$(agent_key_from_num "$choice")
        local name_var="AGENT_${key}_NAME"
        local name="${!name_var}"

        echo ""
        ui_confirm "Launch ${name} in a new Kitty window?"

        if [ $? -eq 0 ]; then
            kitty_launch_agent_tab "$key"
            log_info "LAUNCH" "Launched ${name}"
        fi
    fi
    ui_pause
}

# ---- Command: Assign Task ----
cmd_assign_task() {
    ui_clear
    ui_header "Assign Task" "Phase 4: Execution"

    while true; do
        local options=()
        for key in "${AGENTS_LIST[@]}"; do
            local name_var="AGENT_${key}_NAME"
            local icon_var="AGENT_${key}_ICON"
            local role_var="AGENT_${key}_ROLE"
            options+=("${!icon_var} ${!name_var} ${DIM}(${!role_var})${NC}")
        done
        options+=("Cancel")

        ui_menu "Assign task to which agent?" "${options[@]}"
        ui_ask "Choice"
        read -r choice

        if [ "$choice" -eq 0 ] || [ "$choice" -eq "$((${#AGENTS_LIST[@]} + 1))" ]; then
            return
        fi

        if [ "$choice" -ge 1 ] && [ "$choice" -le "${#AGENTS_LIST[@]}" ]; then
            local key
            key=$(agent_key_from_num "$choice")
            local name_var="AGENT_${key}_NAME"
            local name="${!name_var}"
            local icon_var="AGENT_${key}_ICON"
            local icon="${!icon_var}"

            ui_read task_desc "Describe the task for ${name}" ""

            if [ -n "$task_desc" ]; then
                # Log task
                log_agent_start "$name" "$task_desc"

                echo ""
                echo -e "${icon} Assigning to ${BOLD}${name}${NC}..."
                echo -e "  ${DIM}Task:${NC} ${task_desc}"
                echo ""

                # Launch agent with task context
                kitty_launch_agent_tab "$key" "$PROJECT_DIR" "${name}: ${task_desc:0:40}"

                log_info "TASK" "Assigned '${task_desc}' to ${name}"
                echo -e "${GREEN}✓ Task assigned${NC}"
                echo -e "  ${DIM}Logged to:${NC} ${LOG_FILE}"
            fi
            ui_pause
            break
        fi
    done
}

# ---- Command: View Log ----
cmd_view_log() {
    ui_clear
    ui_header "Session Logs"

    local logs
    logs=("$SESSION_DIR"/*.log)
    if [ ${#logs[@]} -eq 0 ] || [ "${logs[0]}" = "$SESSION_DIR/*.log" ]; then
        echo -e "${YELLOW}No session logs found.${NC}"
        ui_pause
        return
    fi

    echo -e "${BOLD}Recent sessions:${NC}"
    local i=1
    local sorted_logs=()
    while IFS= read -r f; do
        sorted_logs+=("$f")
    done < <(find "$SESSION_DIR" -name "*.log" -printf '%T@ %p\0' 2>/dev/null | sort -rnz | while IFS= read -r -d '' line; do printf '%s\n' "${line#* }"; done)

    if [ ${#sorted_logs[@]} -eq 0 ]; then
        for f in "$SESSION_DIR"/*.log; do
            [ -f "$f" ] && sorted_logs+=("$f")
        done
    fi

    for f in "${sorted_logs[@]}"; do
        local name
        name=$(basename "$f")
        echo -e "  ${CYAN}${i})${NC} ${name}"
        ((i++))
    done
    echo ""
    ui_ask "View which log? (0 to cancel)"
    read -r lchoice

    if [ "$lchoice" -ge 1 ] && [ "$lchoice" -le "${#sorted_logs[@]}" ]; then
        local idx=$((lchoice - 1))
        less "${sorted_logs[$idx]}"
    fi
}

# ---- Command: Workflow ----
cmd_workflow() {
    ui_clear
    ui_header "Workflow Status" "${PROJECT_NAME:+"Project: ${PROJECT_NAME}"}"
    ui_phase_progress "$CURRENT_PHASE"

    echo -e "${BOLD}Current Phase Actions:${NC}"
    case $CURRENT_PHASE in
        1) echo "  → Define project scope & requirements" ;;
        2) echo "  → Assign team roles & launch agents" ;;
        3) echo "  → Create task breakdown & architecture" ;;
        4) echo "  → Agents execute assigned tasks" ;;
        5) echo "  → Quality assurance & testing" ;;
        6) echo "  → Package & deliver final product" ;;
    esac
    echo ""

    if [ "$CURRENT_PHASE" -lt 6 ]; then
        ui_confirm "Advance to next phase?"
        if [ $? -eq 0 ]; then
            ((CURRENT_PHASE++))
            log_phase "$CURRENT_PHASE" "${PHASES[$((CURRENT_PHASE-1))]#*: }"
            echo -e "${GREEN}→ Advanced to Phase ${CURRENT_PHASE}${NC}"
        fi
    fi
    ui_pause
}

# ---- Command: Settings ----
cmd_settings() {
    ui_clear
    ui_header "Settings"

    local current_leader_name_var="AGENT_${LEADER}_NAME"
    echo -e "${BOLD}Current Leader:${NC} ${!current_leader_name_var}"

    echo ""
    echo -e "${BOLD}Set Leader Agent:${NC}"
    local i=1
    for key in "${AGENTS_LIST[@]}"; do
        local name_var="AGENT_${key}_NAME"
        local icon_var="AGENT_${key}_ICON"
        echo -e "  ${CYAN}${i})${NC} ${!icon_var} ${!name_var}"
        ((i++))
    done
    echo ""
    ui_ask "Choose Leader" "1"
    read -r lchoice

    if [ "$lchoice" -ge 1 ] && [ "$lchoice" -le "${#AGENTS_LIST[@]}" ]; then
        LEADER=$(agent_key_from_num "$lchoice")
        local new_name_var="AGENT_${LEADER}_NAME"
        echo -e "${GREEN}✓ Leader set to ${!new_name_var}${NC}"
        log_info "SETTINGS" "Leader changed to ${!new_name_var}"
    fi
    ui_pause
}

# ---- Command: Help ----
cmd_help() {
    ui_clear
    ui_header "Help" "D-AMS v${VERSION}"

    echo -e "${BOLD}OVERVIEW${NC}"
    echo "  D-AMS (Dynamic Agent Management System) orchestrates"
    echo "  your terminal AI agents to work as a coordinated team."
    echo ""
    echo -e "${BOLD}MANAGED AGENTS${NC}"
    for key in "${AGENTS_LIST[@]}"; do
        ui_agent_card "$key"
    done
    echo ""
    echo -e "${BOLD}WORKFLOW${NC}"
    echo "  The system follows 6 phases:"
    for phase in "${PHASES[@]}"; do
        echo "    ${phase}"
    done
    echo ""
    echo -e "${BOLD}KITTY INTEGRATION${NC}"
    echo "  Each agent is launched in its own Kitty tab/window."
    echo "  Start a project → Assemble team → Assign tasks → Deliver"
    echo ""
    echo -e "${BOLD}CONFIGURATION${NC}"
    echo "  Edit: config/agents.conf"
    echo "  Logs:  sessions/"
    echo ""
    ui_pause
}

# ---- Command: Exit ----
cmd_exit() {
    echo ""
    echo -e "${CYAN}Thank you for using D-AMS Agent Manager${NC}"
    echo -e "${DIM}Logs saved to: ${SESSION_DIR}${NC}"
    echo ""
    exit 0
}

# ---- Entry Point ----
main() {
    # Parse CLI args
    case "${1:-}" in
        --help|-h)
            cmd_help
            exit 0
            ;;
        --version|-v)
            echo "D-AMS Agent Manager v${VERSION}"
            exit 0
            ;;
        --launch)
            # Direct launch: agent-manager.sh --launch CLAUDE
            local target_key="$2"
            if [ -n "$target_key" ]; then
                local name_var="AGENT_${target_key}_NAME"
                local name="${!name_var}"
                if [ -n "$name" ]; then
                    kitty_launch_agent_tab "$target_key"
                else
                    echo "Unknown agent: $target_key"
                    echo "Available: ${AGENTS_LIST[*]}"
                fi
            fi
            exit 0
            ;;
        --assemble)
            log_init "quick-assembly"
            kitty_assemble_team "$PROJECT_DIR"
            exit 0
            ;;
        --log)
            # Show recent logs
            local logs
            logs=("$SESSION_DIR"/*.log)
            if [ ${#logs[@]} -gt 0 ] && [ "${logs[0]}" != "$SESSION_DIR/*.log" ]; then
                tail -50 "${logs[-1]}"
            else
                echo "No logs found."
            fi
            exit 0
            ;;
    esac

    # Interactive mode
    log_init "manager-session"
    main_menu
}

# Check deps
for cmd in read printf echo timeout nohup; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "WARNING: '$cmd' not found (some features may fall back)"
    fi
done

main "$@"

