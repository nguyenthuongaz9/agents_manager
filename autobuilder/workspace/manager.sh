#!/usr/bin/env bash
# AutoBuilder Workspace Manager — create and manage workspace directories

set -euo pipefail

# create_workspace: Create a new workspace for a project run.
#
# Usage: create_workspace <project_id>
# Returns: workspace path (printed to stdout)
#
create_workspace() {
    local project_id="$1"
    local workspace="${OUTPUT_BASE_DIR}/${project_id}"

    mkdir -p "${workspace}/.meta"
    mkdir -p "${workspace}/project"

    # Write a manifest
    {
        echo "project_id=${project_id}"
        echo "created_at=$(date '+%Y-%m-%d %H:%M:%S')"
        echo "workspace=${workspace}"
    } > "${workspace}/.meta/manifest.env"

    echo "$workspace"
}

# get_meta_dir: Return the .meta directory for a workspace.
get_meta_dir() {
    echo "${1}/.meta"
}

# get_project_dir: Return the project output directory for a workspace.
get_project_dir() {
    echo "${1}/project"
}

# workspace_exists: Check if a workspace already exists.
workspace_exists() {
    local project_id="$1"
    [[ -d "${OUTPUT_BASE_DIR}/${project_id}" ]]
}

# list_workspaces: List all existing workspaces with their timestamps.
list_workspaces() {
    if [[ -d "$OUTPUT_BASE_DIR" ]]; then
        find "$OUTPUT_BASE_DIR" -maxdepth 1 -mindepth 1 -type d \
            | sort -r \
            | while read -r ws; do
                local id
                id=$(basename "$ws")
                local created=""
                if [[ -f "${ws}/.meta/manifest.env" ]]; then
                    created=$(grep "created_at=" "${ws}/.meta/manifest.env" | cut -d= -f2-)
                fi
                printf "  %-40s %s\n" "$id" "${created}"
            done
    fi
}

# save_stage_output: Helper to write a stage output file.
save_stage_output() {
    local meta_dir="$1"
    local filename="$2"
    local content="$3"
    echo "$content" > "${meta_dir}/${filename}"
}

# get_stage_output: Read a stage output file.
get_stage_output() {
    local meta_dir="$1"
    local filename="$2"
    local filepath="${meta_dir}/${filename}"
    if [[ -f "$filepath" ]]; then
        cat "$filepath"
    else
        echo ""
    fi
}

# list_project_files: List all files in the project directory.
list_project_files() {
    local project_dir="$1"
    if [[ -d "$project_dir" ]]; then
        find "$project_dir" -type f | sort | while read -r f; do
            echo "${f#${project_dir}/}"
        done
    fi
}
