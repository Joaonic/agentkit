#!/bin/bash
set -e

# Automatic version tagging with AI-generated release notes
# Creates annotated git tag with release notes from git diff
#
# Usage: ./tag_version.sh <OPENAI_API_KEY> <version>
# Example: ./tag_version.sh sk-XXXXX 1.2.3

SCRIPTS_DIR="${SCRIPTS_DIR:-$(cd "$(dirname "$0")" && pwd)}"
CHAT_MODEL="${CHAT_MODEL:-gpt-4o-mini}"
TEMP_DIFF_FILE="${TEMP_DIFF_FILE:-diff_output.txt}"

source "$SCRIPTS_DIR/git_helpers.sh"
source "$SCRIPTS_DIR/change_helpers.sh"

usage() {
    echo "Usage: $0 <OPENAI_API_KEY> <version>"
    echo "Example: $0 sk-XXXXXXX 1.2.3"
    exit 1
}

if [ $# -lt 2 ]; then
    usage
fi

CHATGPT_API_KEY="$1"
VERSION="$2"

# Check if tag already exists
if tag_exists "$VERSION"; then
    echo "Error: Tag $VERSION already exists."
    exit 1
fi

last_tag=$(get_last_tag)
echo "Last tag: ${last_tag:-None}"

changes=$(get_changes_between_tags "$last_tag")
echo "Changes collected."

# Generate release notes
release_notes="Release $VERSION"
if [[ -n "$CHATGPT_API_KEY" && "$CHATGPT_API_KEY" != "skip" && -f "$SCRIPTS_DIR/gpt_helpers.sh" ]]; then
    source "$SCRIPTS_DIR/gpt_helpers.sh"

    release_notes_system_message="You are a helpful assistant that generates release notes based on code changes. Follow these guidelines:
- Release notes should be clear and concise.
- Highlight the most important changes and improvements.
- Use appropriate headings and bullet points.
- Avoid unnecessary technical jargon."

    release_notes_prompt="Generate release notes for version $VERSION based on the following code changes:\n$changes"

    echo "Generating release notes via AI..."
    set +e
    ai_notes=$(generate_text_via_gpt "$release_notes_system_message" "$release_notes_prompt" "$CHATGPT_API_KEY" "$TEMP_DIFF_FILE" "$CHAT_MODEL")
    [[ $? -eq 0 && -n "$ai_notes" ]] && release_notes="$ai_notes"
    set -e
fi

configure_remote
echo "Creating tag $VERSION..."
create_tag_with_message "$VERSION" "$release_notes"
echo "Tag $VERSION created with release notes!"

rm -f "$TEMP_DIFF_FILE"
