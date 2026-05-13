#!/bin/sh
set -e
# docker-entrypoint.sh — API image entrypoint.
# Loads Docker secrets from /run/secrets/ into env vars, then execs the CMD.
# If no secrets are mounted (local dev), env vars from .env / environment are
# used as-is — zero impact on the existing workflow.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# load-secrets.sh is baked into the image at the same path
if [ -f "${SCRIPT_DIR}/load-secrets.sh" ]; then
  . "${SCRIPT_DIR}/load-secrets.sh"
elif [ -f /usr/local/bin/load-secrets.sh ]; then
  . /usr/local/bin/load-secrets.sh
fi

exec "$@"
