#!/bin/bash
set -e

# AI-Powered Changelog Generator
# Generates CHANGELOG.md from git diffs using OpenAI API
# Falls back to conventional commit parsing if API unavailable
#
# Usage: ./generate_changelog.sh <OPENAI_API_KEY> <version>
# Example: ./generate_changelog.sh sk-XXXXX 1.2.3

SCRIPTS_DIR="${SCRIPTS_DIR:-$(cd "$(dirname "$0")" && pwd)}"
REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel)}"
CHANGELOG_FILE="${CHANGELOG_FILE:-CHANGELOG.md}"
TEMP_DIFF_FILE="${TEMP_DIFF_FILE:-diff_output.txt}"
CHAT_MODEL="${CHAT_MODEL:-gpt-4o-mini}"
MAX_DIFF_BYTES="${MAX_DIFF_BYTES:-180000}"

source "$SCRIPTS_DIR/git_helpers.sh"
source "$SCRIPTS_DIR/change_helpers.sh"

usage() {
    echo "Usage: $0 <OPENAI_API_KEY> <version>"
    echo "Example: $0 sk-XXXXXXX 1.2.3"
    echo ""
    echo "Environment variables:"
    echo "  CHAT_MODEL         OpenAI model (default: gpt-4o-mini)"
    echo "  CHANGELOG_FILE     Output file (default: CHANGELOG.md)"
    echo "  MAX_DIFF_BYTES     Max diff size before using commit-based context (default: 180000)"
    exit 1
}

add_changelog_to_file() {
    local changelog=$1
    local date=$(date +'%Y-%m-%d')
    local version=$2
    local header="## [$version] - $date"

    if [[ -f "$CHANGELOG_FILE" ]]; then
        local rest
        rest=$(grep -v '^# Changelog' "$CHANGELOG_FILE" 2>/dev/null || true)
        printf '# Changelog\n\n%s\n\n%s\n\n%s\n' "$header" "$changelog" "$rest" > "$CHANGELOG_FILE"
    else
        printf '# Changelog\n\n%s\n\n%s\n' "$header" "$changelog" > "$CHANGELOG_FILE"
    fi
}

# Fallback: generate changelog from conventional commits (no AI needed)
generate_fallback_changelog() {
    local range="${1:-HEAD~60..HEAD}"
    local added="" changed="" fixed="" security="" removed="" deprecated=""

    while IFS='|' read -r subject short_hash; do
        [[ -z "${subject}" ]] && continue
        local entry="${subject} (${short_hash})"
        local normalized
        normalized="$(echo "${subject}" | tr '[:upper:]' '[:lower:]')"

        if [[ "${normalized}" =~ ^(feat|add|new)[:\ ] ]]; then
            added="${added}\n- ${entry}"
        elif [[ "${normalized}" =~ (fix|bug|hotfix|patch) ]]; then
            fixed="${fixed}\n- ${entry}"
        elif [[ "${normalized}" =~ (security|cve|vuln) ]]; then
            security="${security}\n- ${entry}"
        elif [[ "${normalized}" =~ (deprecat) ]]; then
            deprecated="${deprecated}\n- ${entry}"
        elif [[ "${normalized}" =~ (remove|drop|delete) ]]; then
            removed="${removed}\n- ${entry}"
        else
            changed="${changed}\n- ${entry}"
        fi
    done < <(git log --no-merges --pretty=format:'%s|%h' "$range")

    local out=""
    [[ -n "$added" ]] && out="${out}### Added${added}\n\n"
    [[ -n "$changed" ]] && out="${out}### Changed${changed}\n\n"
    [[ -n "$deprecated" ]] && out="${out}### Deprecated${deprecated}\n\n"
    [[ -n "$removed" ]] && out="${out}### Removed${removed}\n\n"
    [[ -n "$fixed" ]] && out="${out}### Fixed${fixed}\n\n"
    [[ -n "$security" ]] && out="${out}### Security${security}\n\n"

    if [[ -z "$out" ]]; then
        out="### Changed\n- Internal maintenance and pipeline adjustments."
    fi
    printf '%b' "$out"
}

# --- Main ---

if [ $# -lt 2 ]; then
    usage
fi

CHATGPT_API_KEY="$1"
VERSION="$2"

cd "$REPO_ROOT"

last_tag=$(get_last_tag)
echo "Last tag: ${last_tag:-None}"

changes=$(get_changes_between_tags "$last_tag")
echo "Changes collected."

# Check if diff is too large
diff_size=$(wc -c < "$TEMP_DIFF_FILE" 2>/dev/null || echo 0)
if [[ "$diff_size" -gt "$MAX_DIFF_BYTES" ]]; then
    echo "Diff too large (${diff_size} bytes). Using commit-based context..."
    git log --no-merges --name-status --date=short \
        --pretty=format:'commit %h%nDate: %ad%nSubject: %s%n' HEAD~60..HEAD > "$TEMP_DIFF_FILE"
fi

# Try AI generation first, fall back to conventional commits
changelog=""
if [[ -n "$CHATGPT_API_KEY" && "$CHATGPT_API_KEY" != "skip" ]]; then
    if [[ -f "$SCRIPTS_DIR/gpt_helpers.sh" ]]; then
        source "$SCRIPTS_DIR/gpt_helpers.sh"

        changelog_system_message="You are a helpful assistant that generates Changelogs based on code changes. Follow these guidelines:
- Changelogs are for humans, not machines.
- Group the same types of changes together.
- Precede each group with ### and a corresponding heading.
- Use the following categories: Added, Changed, Deprecated, Removed, Fixed, Security.
- Do not include unnecessary information or treat this as the full document."

        changelog_prompt="Generate a changelog WITHOUT markdown code fences for version $VERSION based on the following code changes:\n"

        echo "Generating changelog via AI ($CHAT_MODEL)..."
        set +e
        changelog=$(generate_text_via_gpt "$changelog_system_message" "$changelog_prompt" "$CHATGPT_API_KEY" "$TEMP_DIFF_FILE" "$CHAT_MODEL")
        status=$?
        set -e

        if [[ $status -ne 0 || -z "$changelog" ]]; then
            echo "AI generation failed. Using fallback..."
            changelog=""
        fi
    fi
fi

if [[ -z "$changelog" ]]; then
    echo "Using conventional commit fallback..."
    changelog="$(generate_fallback_changelog)"
fi

echo "Updating $CHANGELOG_FILE..."
add_changelog_to_file "$changelog" "$VERSION"

# Commit if in CI
if [[ -n "${CI:-}" || -n "${GITHUB_ACTIONS:-}" ]]; then
    add_commit_and_push "$CHANGELOG_FILE" "doc: [$VERSION] Automatic changelog generated [skip ci]"
fi

rm -f "$TEMP_DIFF_FILE"

echo "Changelog updated for version $VERSION!"
