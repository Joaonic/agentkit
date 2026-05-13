#!/bin/bash
set -e

# Git helper functions for CI/CD pipelines
# Works with both GitLab CI and GitHub Actions

# Configure remote for pushing (GitLab CI)
configure_remote_gitlab() {
    echo "Configuring remote with CI token..."
    git remote rm origin 2>/dev/null || true
    git remote add origin "https://oauth2:${GITLAB_TOKEN}@${CI_SERVER_HOST}/$CI_PROJECT_PATH.git"
    git pull origin HEAD:"$CI_COMMIT_REF_NAME"
    echo "Remote configured: $(git remote get-url origin)"
}

# Configure remote for pushing (GitHub Actions)
configure_remote_github() {
    echo "Configuring remote with GitHub token..."
    git remote set-url origin "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"
}

# Auto-detect and configure remote
configure_remote() {
    if [[ -n "${CI_SERVER_HOST:-}" ]]; then
        configure_remote_gitlab
    elif [[ -n "${GITHUB_REPOSITORY:-}" ]]; then
        configure_remote_github
    else
        echo "Warning: No CI environment detected. Using existing remote."
    fi
}

# Get the last tag
get_last_tag() {
    git describe --tags --abbrev=0 2>/dev/null || echo ""
}

# Check if a tag exists
tag_exists() {
    local tag=$1
    git rev-parse "$tag" >/dev/null 2>&1
}

# Create an annotated tag with message and push
create_tag_with_message() {
    local version=$1
    local message=$2
    git tag -a "$version" -m "$message"
    git push origin "$version"
}

# Add files, commit, and push
add_commit_and_push() {
    local files=$1
    local message=$2
    configure_remote
    echo "Adding $files..."
    git add $files
    echo "Committing: $message"
    git commit -m "$message"

    # Push to correct branch based on CI provider
    if [[ -n "${CI_COMMIT_REF_NAME:-}" ]]; then
        git push origin HEAD:"$CI_COMMIT_REF_NAME"
    elif [[ -n "${GITHUB_REF_NAME:-}" ]]; then
        git push origin HEAD:"$GITHUB_REF_NAME"
    else
        git push
    fi
}
