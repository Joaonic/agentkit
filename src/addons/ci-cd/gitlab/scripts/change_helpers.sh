#!/bin/bash
set -e

# Change detection helpers for CI/CD pipelines
# Extracts diffs between tags for changelog generation

export_code_script="${SCRIPTS_DIR:-$(dirname "$0")}/export_code.sh"
temp_diff_file="${TEMP_DIFF_FILE:-diff_output.txt}"

# Get changes between the last tag and HEAD
# Falls back to full code export if no tags exist
get_changes_between_tags() {
    local base_tag=$1
    if [ -z "$base_tag" ]; then
        echo "No tags found. Getting all changes up to HEAD..."
        if [[ -f "$export_code_script" ]]; then
            bash "$export_code_script"
            mv repository_code.txt "$temp_diff_file"
        else
            git log --oneline > "$temp_diff_file"
        fi
    else
        echo "Getting changes between tag $base_tag and HEAD..."
        git diff "$base_tag"..HEAD > "$temp_diff_file"
    fi
    cat "$temp_diff_file"
}
