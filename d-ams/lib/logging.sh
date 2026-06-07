#!/bin/bash
#===============================================================================
# Logging Utilities - D-AMS Agent Manager
#===============================================================================

SESSION_DIR="${SESSION_DIR:-./sessions}"
LOG_FILE=""

log_init() {
    local session_name="${1:-default}"
    local timestamp
    timestamp=$(date '+%Y%m%d_%H%M%S')
    mkdir -p "$SESSION_DIR"
    LOG_FILE="$SESSION_DIR/${session_name}_${timestamp}.log"
    log_write "SESSION" "Started" "Session initialized: $session_name"
}

log_write() {
    local level="$1"
    local tag="$2"
    local message="$3"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] [$tag] $message" | tee -a "$LOG_FILE"
}

log_agent_start() {
    local agent="$1"
    local task="$2"
    log_write "EXEC" "AGENT:${agent}" "Started task: ${task}"
}

log_agent_end() {
    local agent="$1"
    local task="$2"
    local status="$3"
    log_write "EXEC" "AGENT:${agent}" "Completed task: ${task} -> ${status}"
}

log_info()  { log_write "INFO"  "$1" "$2"; }
log_warn()  { log_write "WARN"  "$1" "$2"; }
log_error() { log_write "ERROR" "$1" "$2"; }
log_ok()    { log_write "OK"    "$1" "$2"; }

log_phase() {
    local phase="$1"
    local desc="$2"
    log_write "PHASE" "WORKFLOW" "=== Phase ${phase}: ${desc} ==="
}

log_session_summary() {
    log_write "SUMMARY" "SESSION" "Session log written to: $LOG_FILE"
}
