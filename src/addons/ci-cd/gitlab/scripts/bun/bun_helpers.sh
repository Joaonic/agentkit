#!/bin/bash
set -e

# Bun version helpers for Bun-based projects
# Reads and increments version from package.json

PACKAGE_JSON_PATH=${PACKAGE_JSON_PATH:-"package.json"}

get_package_version() {
    if [ ! -f "$PACKAGE_JSON_PATH" ]; then
        echo "Error: $PACKAGE_JSON_PATH not found."
        exit 1
    fi
    local version
    version=$(grep -m1 '"version"' "$PACKAGE_JSON_PATH" | sed -E 's/.*"version":\s*"([^"]+)".*/\1/')
    if [ -z "$version" ]; then
        echo "Error: Could not extract version from $PACKAGE_JSON_PATH."
        exit 1
    fi
    echo "$version"
}

get_new_version() {
    local part_to_increment=$1
    local version=$(get_package_version)
    IFS='.' read -r major minor patch <<< "$version"

    case $part_to_increment in
        major) major=$((major + 1)); minor=0; patch=0 ;;
        minor) minor=$((minor + 1)); patch=0 ;;
        patch) patch=$((patch + 1)) ;;
        *) echo "Error: must be 'major', 'minor', or 'patch'."; exit 1 ;;
    esac

    echo "${major}.${minor}.${patch}"
}

increment_version() {
    local part_to_increment=$1
    local current_version=$(get_package_version)
    echo "Current version: $current_version"

    local new_version=$(get_new_version "$part_to_increment")
    echo "New version: $new_version"

    bun -e "const fs = require('fs'); const path = '$PACKAGE_JSON_PATH'; const pkg = JSON.parse(fs.readFileSync(path, 'utf-8')); pkg.version = '$new_version'; fs.writeFileSync(path, JSON.stringify(pkg, null, 2) + '\n');"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to update $PACKAGE_JSON_PATH version."
        exit 1
    fi

    echo "Version updated to $new_version in $PACKAGE_JSON_PATH"
}
