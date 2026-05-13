#!/bin/bash
set -e

# GPT helper functions for AI-powered changelog/release notes generation
# Requires: python3 (auto-installed), OPENAI_API_KEY

SCRIPTS_DIR="${SCRIPTS_DIR:-$(dirname "$0")}"

# Auto-install python3 if missing
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

ensure_python() {
    if command_exists python3; then return 0; fi

    if command_exists apt-get; then
        apt-get update -q && apt-get install -y python3 python3-venv
    elif command_exists apk; then
        apk update && apk add --no-cache python3 python3-venv
    elif command_exists brew; then
        brew install python3
    else
        echo "Error: python3 not found and no supported package manager available."
        exit 1
    fi
}

setup_venv() {
    if [[ ! -d ".venv" ]]; then
        python3 -m venv .venv
    fi
    source .venv/bin/activate
    pip install -q tiktoken 2>/dev/null || true
}

# Generate text via OpenAI API
# $1: System message
# $2: User prompt
# $3: API key
# $4: Content file path
# $5: Model (optional, default: gpt-4o-mini)
generate_text_via_gpt() {
    local system_message="$1"
    local user_prompt="$2"
    local api_key="$3"
    local content_file="${4}"
    local model="${5:-gpt-4o-mini}"

    ensure_python
    setup_venv

    local text_response
    text_response=$(python3 "$SCRIPTS_DIR/gpt_generator.py" "$system_message" "$user_prompt" "$api_key" "$model" --content "$content_file")

    echo -e "$text_response"
}
