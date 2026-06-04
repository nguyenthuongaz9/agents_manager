#!/bin/bash
#===============================================================================
# Terminal UI Helpers - D-AMS Agent Manager
#===============================================================================

# Colors
RESET="\033[0m"
BOLD="\033[1m"
DIM="\033[2m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
MAGENTA="\033[35m"
CYAN="\033[36m"
WHITE="\033[37m"

NC="$RESET"

ui_header() {
    local title="$1"
    local subtitle="$2"
    echo ""
    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║  ${WHITE}${BOLD}D-AMS: Dynamic Agent Management System${NC}                ${CYAN}${BOLD}║${NC}"
    echo -e "${CYAN}${BOLD}╠══════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}${BOLD}║  ${WHITE}${title}${NC}${CYAN}${BOLD}${NC}"
    if [ -n "$subtitle" ]; then
        printf "${CYAN}${BOLD}║  ${NC}${DIM}%s${NC}${CYAN}${BOLD}%s${NC}\n" "$subtitle"
    fi
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

ui_menu() {
    local title="$1"
    shift
    local options=("$@")
    local i=1

    echo -e "${BOLD}${title}${NC}"
    echo ""
    for opt in "${options[@]}"; do
        echo -e "  ${CYAN}${i})${NC} ${opt}"
        ((i++))
    done
    echo ""
    echo -e "  ${DIM}0) Quit / Back${NC}"
    echo ""
}

ui_ask() {
    local prompt="$1"
    local default="$2"
    if [ -n "$default" ]; then
        echo -ne "${YELLOW}${prompt}${NC} ${DIM}[${default}]${NC}: "
    else
        echo -ne "${YELLOW}${prompt}${NC}: "
    fi
}

ui_status() {
    local icon="$1"
    local text="$2"
    echo -e "  ${icon} ${text}"
}

ui_separator() {
    echo -e "${DIM}────────────────────────────────────────────────────────${NC}"
}

ui_agent_card() {
    local key="$1"
    local name_var="AGENT_${key}_NAME"
    local icon_var="AGENT_${key}_ICON"
    local role_var="AGENT_${key}_ROLE"
    local desc_var="AGENT_${key}_DESC"
    local cmd_var="AGENT_${key}_COMMAND"

    local name="${!name_var}"
    local icon="${!icon_var}"
    local role="${!role_var}"
    local desc="${!desc_var}"
    local cmd="${!cmd_var}"

    echo ""
    echo -e "  ${icon} ${BOLD}${name}${NC}"
    echo -e "    ${DIM}Role:${NC}    ${role}"
    echo -e "    ${DIM}Command:${NC} ${cmd}"
    echo -e "    ${DIM}About:${NC}   ${desc}"
}

ui_phase_progress() {
    local current_phase="$1"
    echo ""
    echo -e "${BOLD}Workflow Progress:${NC}"
    for i in "${!PHASES[@]}"; do
        local phase_num=$((i + 1))
        local phase_label="${PHASES[$i]}"
        if [ "$phase_num" -lt "$current_phase" ]; then
            echo -e "  ${GREEN}✓${NC} ${DIM}${phase_label}${NC}"
        elif [ "$phase_num" -eq "$current_phase" ]; then
            echo -e "  ${CYAN}▶${NC} ${BOLD}${phase_label}${NC} ${CYAN}<-- current${NC}"
        else
            echo -e "  ${DIM}○ ${phase_label}${NC}"
        fi
    done
    echo ""
}

ui_clear() {
    printf "\033[2J\033[H"
}

ui_read() {
    local var_name="$1"
    local prompt="$2"
    local default="$3"

    if [ -n "$default" ]; then
        echo -ne "${YELLOW}${prompt}${NC} ${DIM}[${default}]${NC}: "
    else
        echo -ne "${YELLOW}${prompt}${NC}: "
    fi
    read -r input
    if [ -z "$input" ] && [ -n "$default" ]; then
        printf -v "$var_name" '%s' "$default"
    else
        printf -v "$var_name" '%s' "$input"
    fi
}

ui_confirm() {
    local prompt="$1"
    echo -ne "${YELLOW}${prompt}${NC} ${DIM}[y/N]${NC}: "
    read -r resp
    case "$resp" in
        y|Y|yes|Yes) return 0 ;;
        *) return 1 ;;
    esac
}

ui_pause() {
    echo ""
    echo -ne "${DIM}Press Enter to continue...${NC}"
    read -r
}
