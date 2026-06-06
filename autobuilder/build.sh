#!/usr/bin/env bash
# AutoBuilder — Autonomous Agent Pipeline
# Usage:
#   ./build.sh "React todo app with authentication and dark mode"
#   ./build.sh --file requirements.pdf
#   ./build.sh --file specs.docx
#   ./build.sh --file description.txt

set -euo pipefail

# ────────────────────────────────────────────────────────────
# Resolve paths relative to this script (works from any cwd)
# ────────────────────────────────────────────────────────────
AUTOBUILDER_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="${AUTOBUILDER_ROOT}/agents"
PIPELINE_DIR="${AUTOBUILDER_ROOT}/pipeline"
LIB_DIR="${AUTOBUILDER_ROOT}/lib"
INPUT_DIR="${AUTOBUILDER_ROOT}/input"
WORKSPACE_DIR="${AUTOBUILDER_ROOT}/workspace"

export AUTOBUILDER_ROOT AGENTS_DIR PIPELINE_DIR LIB_DIR INPUT_DIR WORKSPACE_DIR

# ────────────────────────────────────────────────────────────
# Source config and libraries
# ────────────────────────────────────────────────────────────
# shellcheck source=config/settings.conf
source "${AUTOBUILDER_ROOT}/config/settings.conf"
# shellcheck source=lib/ui.sh
source "${LIB_DIR}/ui.sh"
# shellcheck source=lib/logging.sh
source "${LIB_DIR}/logging.sh"
# shellcheck source=input/parser.sh
source "${INPUT_DIR}/parser.sh"
# shellcheck source=workspace/manager.sh
source "${WORKSPACE_DIR}/manager.sh"
# shellcheck source=agents/run.sh
source "${AGENTS_DIR}/run.sh"
# shellcheck source=pipeline/runner.sh
source "${PIPELINE_DIR}/runner.sh"

# ────────────────────────────────────────────────────────────
# Helper: create a URL/filesystem-safe slug from a string
# ────────────────────────────────────────────────────────────
make_slug() {
    local text="$1"
    # lowercase, replace spaces/special chars with dashes, trim, max 40 chars
    echo "$text" \
        | tr '[:upper:]' '[:lower:]' \
        | tr -cs 'a-z0-9' '-' \
        | sed 's/^-*//;s/-*$//' \
        | cut -c1-40
}

# ────────────────────────────────────────────────────────────
# Helper: validate claude CLI is available
# ────────────────────────────────────────────────────────────
check_dependencies() {
    if ! command -v "${CLAUDE_CMD}" &>/dev/null; then
        ui_error "Claude CLI not found: '${CLAUDE_CMD}'"
        echo "  Install Claude Code CLI and ensure '${CLAUDE_CMD}' is in your PATH." >&2
        echo "  See: https://docs.anthropic.com/claude-code" >&2
        exit 1
    fi
}

# ────────────────────────────────────────────────────────────
# Helper: print usage
# ────────────────────────────────────────────────────────────
usage() {
    cat <<EOF

  ${BOLD}AutoBuilder${RESET} — Autonomous Agent Pipeline

  ${BOLD}USAGE${RESET}
    $(basename "$0") <description>
    $(basename "$0") --file <path>
    $(basename "$0") [--verbose] [--help]

  ${BOLD}EXAMPLES${RESET}
    $(basename "$0") "React todo app with authentication and dark mode"
    $(basename "$0") --file requirements.pdf
    $(basename "$0") --file specs.docx
    $(basename "$0") --file description.txt

  ${BOLD}SUPPORTED FILE TYPES${RESET}
    .txt  .md  .pdf  .docx

  ${BOLD}OPTIONS${RESET}
    --file <path>   Use a file as requirements input
    --verbose       Show detailed agent output
    --help          Show this help message

  ${BOLD}OUTPUT${RESET}
    Complete application written to:
    ${OUTPUT_BASE_DIR}/<timestamp>_<slug>/project/

EOF
}

# ────────────────────────────────────────────────────────────
# Parse arguments
# ────────────────────────────────────────────────────────────
INPUT_TEXT=""
INPUT_FILE=""
VERBOSE=0

if [[ $# -eq 0 ]]; then
    usage
    exit 1
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            usage
            exit 0
            ;;
        --verbose|-v)
            VERBOSE=1
            export VERBOSE
            shift
            ;;
        --file|-f)
            if [[ -z "${2:-}" ]]; then
                ui_error "--file requires a path argument"
                exit 1
            fi
            INPUT_FILE="$2"
            shift 2
            ;;
        --*)
            ui_error "Unknown option: $1"
            usage
            exit 1
            ;;
        *)
            # Positional argument = text description
            INPUT_TEXT="$*"
            break
            ;;
    esac
done

# ────────────────────────────────────────────────────────────
# Validate input
# ────────────────────────────────────────────────────────────
if [[ -z "$INPUT_TEXT" ]] && [[ -z "$INPUT_FILE" ]]; then
    ui_error "No input provided. Provide a description or use --file <path>."
    usage
    exit 1
fi

if [[ -n "$INPUT_FILE" ]] && [[ -n "$INPUT_TEXT" ]]; then
    ui_error "Provide either a description OR --file, not both."
    usage
    exit 1
fi

# ────────────────────────────────────────────────────────────
# Start
# ────────────────────────────────────────────────────────────
ui_banner

check_dependencies

# ────────────────────────────────────────────────────────────
# Read requirements
# ────────────────────────────────────────────────────────────
REQUIREMENTS=""

if [[ -n "$INPUT_FILE" ]]; then
    ui_info "Reading input file: ${INPUT_FILE}"
    if ! validate_input_file "$INPUT_FILE"; then
        exit 1
    fi
    REQUIREMENTS="$(parse_input_file "$INPUT_FILE")"
    if [[ -z "$REQUIREMENTS" ]]; then
        ui_error "Input file is empty or could not be parsed: ${INPUT_FILE}"
        exit 1
    fi
    # Use filename (without extension) as the description slug base
    local_filename="$(basename "$INPUT_FILE")"
    local_basename="${local_filename%.*}"
    DESCRIPTION_FOR_SLUG="$local_basename"
else
    REQUIREMENTS="$INPUT_TEXT"
    DESCRIPTION_FOR_SLUG="$INPUT_TEXT"
fi

# ────────────────────────────────────────────────────────────
# Generate project ID
# ────────────────────────────────────────────────────────────
TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"
SLUG="$(make_slug "$DESCRIPTION_FOR_SLUG")"
PROJECT_ID="${TIMESTAMP}_${SLUG}"

# ────────────────────────────────────────────────────────────
# Init logging
# ────────────────────────────────────────────────────────────
LOG_FILE="$(log_init "$PROJECT_ID")"

# ────────────────────────────────────────────────────────────
# Create workspace
# ────────────────────────────────────────────────────────────
WORKSPACE="$(create_workspace "$PROJECT_ID")"

# ────────────────────────────────────────────────────────────
# Show summary before running
# ────────────────────────────────────────────────────────────
ui_separator
ui_item "Project ID"   "$PROJECT_ID"
ui_item "Workspace"    "$WORKSPACE"
ui_item "Log"          "$LOG_FILE"
ui_item "Claude CLI"   "$CLAUDE_CMD"
ui_separator
echo ""

log "Build started: project_id=${PROJECT_ID}"
log "Requirements length: ${#REQUIREMENTS} characters"

# ────────────────────────────────────────────────────────────
# Run the pipeline
# ────────────────────────────────────────────────────────────
if run_pipeline "$REQUIREMENTS" "$WORKSPACE" "$PROJECT_ID"; then
    log "Build finished successfully"
    exit 0
else
    log_error "Build failed"
    echo ""
    ui_error "Build failed. Check the log for details:"
    echo "  ${LOG_FILE}" >&2
    exit 1
fi
