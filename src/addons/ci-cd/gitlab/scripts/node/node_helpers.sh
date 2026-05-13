#!/bin/bash
set -e

# Node.js version helpers for npm-based projects
# Reads and increments version from package.json

get_package_version() {
    local version
    version=$(npm pkg get version | tr -d '"')
    if [ $? -ne 0 ]; then
        echo "Error: npm command failed."
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

    echo "$major.$minor.$patch"
}

increment_version() {
    local part_to_increment=$1
    local version=$(get_package_version)
    echo "Current version: $version"

    local new_version=$(get_new_version "$part_to_increment")
    echo "New version: $new_version"

    npm version "$new_version" --no-git-tag-version
    if [ $? -ne 0 ]; then
        echo "Error: Failed to update package.json version."
        exit 1
    fi

    echo "Version updated to $new_version in package.json"
}
