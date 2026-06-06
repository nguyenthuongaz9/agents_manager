#!/usr/bin/env bash
# AutoBuilder Logging — timestamped entries, stage events, errors

_LOG_FILE=""

log_init() {
    local project_id="${1:-unknown}"
    mkdir -p "${LOG_DIR}"
    _LOG_FILE="${LOG_DIR}/${project_id}.log"
    {
        echo "============================================================"
        echo "AutoBuilder Log — $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Project ID: ${project_id}"
        echo "============================================================"
    } >> "$_LOG_FILE"
    echo "$_LOG_FILE"
}

log() {
    local msg="$1"
    local level="${2:-INFO}"
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    if [[ -n "$_LOG_FILE" ]]; then
        echo "[${ts}] [${level}] ${msg}" >> "$_LOG_FILE"
    fi
    if [[ "${VERBOSE:-0}" == "1" ]]; then
        echo -e "  ${DIM}[${ts}] ${msg}${RESET}" >&2
    fi
}

log_stage_start() {
    local stage_num="$1"
    local stage_name="$2"
    log "---- Stage ${stage_num}: ${stage_name} START ----" "STAGE"
}

log_stage_end() {
    local stage_num="$1"
    local stage_name="$2"
    local duration="${3:-?}"
    log "---- Stage ${stage_num}: ${stage_name} END (${duration}s) ----" "STAGE"
}

log_error() {
    local msg="$1"
    log "$msg" "ERROR"
}

log_debug() {
    local msg="$1"
    if [[ "${VERBOSE:-0}" == "1" ]]; then
        log "$msg" "DEBUG"
    fi
}

log_agent_output() {
    local stage="$1"
    local output_file="$2"
    if [[ -f "$output_file" ]]; then
        local lines
        lines=$(wc -l < "$output_file")
        log "Stage ${stage}: agent output saved to ${output_file} (${lines} lines)" "OUTPUT"
    fi
}

get_log_file() {
    echo "$_LOG_FILE"
}
