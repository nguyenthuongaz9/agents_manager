#!/usr/bin/env bash
# AutoBuilder Terminal UI — colors, progress, banners

# Color constants (use $'...' so they are actual ESC bytes, not literal strings)
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
CYAN=$'\033[0;36m'
MAGENTA=$'\033[0;35m'
WHITE=$'\033[1;37m'
BOLD=$'\033[1m'
DIM=$'\033[2m'
ITALIC=$'\033[3m'
UNDERLINE=$'\033[4m'
RESET=$'\033[0m'

# Symbols
CHECKMARK="${GREEN}✓${RESET}"
CROSSMARK="${RED}✗${RESET}"
ARROW="${CYAN}→${RESET}"
BULLET="${DIM}•${RESET}"

# Spinner state
_SPINNER_PID=""
_SPINNER_CHARS='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'

ui_banner() {
    echo ""
    echo -e "${CYAN}${BOLD}"
    echo "  ╔═══════════════════════════════════════╗"
    echo "  ║                                       ║"
    echo "  ║   ██████╗ ██╗   ██╗██╗██╗     ██████╗ ║"
    echo "  ║  ██╔══██╗██║   ██║██║██║     ██╔══██╗║"
    echo "  ║  ██████╔╝██║   ██║██║██║     ██║  ██║║"
    echo "  ║  ██╔══██╗██║   ██║██║██║     ██║  ██║║"
    echo "  ║  ██████╔╝╚██████╔╝██║███████╗██████╔╝║"
    echo "  ║  ╚═════╝  ╚═════╝ ╚═╝╚══════╝╚═════╝ ║"
    echo "  ║                                       ║"
    echo "  ║      Autonomous Agent Pipeline        ║"
    echo "  ╚═══════════════════════════════════════╝"
    echo -e "${RESET}"
}

ui_separator() {
    local char="${1:-─}"
    local width="${2:-60}"
    printf "${DIM}"
    printf '%*s' "$width" | tr ' ' "${char}"
    printf "${RESET}\n"
}

ui_stage() {
    local num="$1"
    local total="$2"
    local name="$3"
    printf "\n  ${BOLD}[${num}/${total}]${RESET} ${CYAN}${name}${RESET} "
    _spinner_start
}

ui_stage_done() {
    _spinner_stop
    echo -e " ${CHECKMARK}"
}

ui_stage_fail() {
    local name="${1:-stage}"
    _spinner_stop
    echo -e " ${CROSSMARK} ${RED}${name} failed${RESET}"
}

ui_info() {
    local msg="$1"
    echo -e "  ${DIM}${ARROW} ${msg}${RESET}"
}

ui_error() {
    local msg="$1"
    echo -e "\n  ${RED}${BOLD}ERROR:${RESET} ${RED}${msg}${RESET}" >&2
}

ui_warn() {
    local msg="$1"
    echo -e "  ${YELLOW}⚠ ${msg}${RESET}"
}

ui_success() {
    local output_path="$1"
    echo ""
    ui_separator "═" 60
    echo -e "  ${GREEN}${BOLD}Pipeline complete!${RESET}"
    echo ""
    echo -e "  ${BULLET} Output: ${BOLD}${output_path}${RESET}"
    echo -e "  ${BULLET} Ready to use"
    ui_separator "═" 60
    echo ""
}

ui_header() {
    local title="$1"
    echo -e "\n  ${BOLD}${UNDERLINE}${title}${RESET}\n"
}

ui_item() {
    local label="$1"
    local value="$2"
    printf "  ${DIM}%-20s${RESET} %s\n" "${label}:" "${value}"
}

_spinner_start() {
    if [[ -t 1 ]]; then
        (
            local i=0
            local chars='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
            local len=${#chars}
            while true; do
                printf "\r  ${BOLD}[${CYAN}${chars:$((i % len)):1}${RESET}${BOLD}]${RESET} "
                ((i++))
                sleep 0.1
            done
        ) &
        _SPINNER_PID=$!
        disown "$_SPINNER_PID" 2>/dev/null || true
    fi
}

_spinner_stop() {
    if [[ -n "$_SPINNER_PID" ]]; then
        kill "$_SPINNER_PID" 2>/dev/null || true
        wait "$_SPINNER_PID" 2>/dev/null || true
        _SPINNER_PID=""
        printf "\r"
    fi
}

# Cleanup spinner on exit
trap '_spinner_stop' EXIT INT TERM
