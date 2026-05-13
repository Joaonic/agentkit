#!/bin/sh
# deploy/scripts/load-secrets.sh
# Generic Docker secrets loader. Source this file before starting the application.
# Reads /run/secrets/* into UPPER_CASE env vars and constructs composite URLs.
#
# Convention: secret file name → env var name
#   postgres_password → POSTGRES_PASSWORD
#   database_url      → DATABASE_URL
#
# Composite URL construction:
#   Set SECRETS_DATABASE_NAME=langfuse in the service environment to override
#   the database name used when constructing DATABASE_URL (default: POSTGRES_DB
#   or whatsapp_sales_agent).

# --- Phase 1: load all /run/secrets/* as UPPER_CASE env vars ----------------
if [ -d /run/secrets ]; then
  for _f in /run/secrets/*; do
    [ -f "$_f" ] || continue
    _name="$(basename "$_f" | tr '[:lower:]' '[:upper:]')"
    _value="$(tr -d '\n' < "$_f")"
    export "$_name"="$_value"
  done
  unset _f _name _value
fi

# --- Phase 2: construct composite / derived env vars ------------------------

# DATABASE_URL (used by Prisma in API and by Langfuse services)
if [ -f /run/secrets/postgres_password ]; then
  _db="${SECRETS_DATABASE_NAME:-${POSTGRES_DB:-whatsapp_sales_agent}}"
  export DATABASE_URL="postgresql://${POSTGRES_USER:-postgres}:${POSTGRES_PASSWORD}@${POSTGRES_HOST:-postgres}:${POSTGRES_PORT:-5432}/${_db}"
  unset _db
fi

# REDIS_URL / REDIS_CONNECTION_STRING
if [ -f /run/secrets/redis_password ]; then
  _rh="${REDIS_HOST:-redis}"
  _rp="${REDIS_PORT:-6379}"
  export REDIS_URL="redis://:${REDIS_PASSWORD}@${_rh}:${_rp}"
  export REDIS_CONNECTION_STRING="redis://:${REDIS_PASSWORD}@${_rh}:${_rp}"
  unset _rh _rp
fi

# --- Phase 3: name mappings for third-party services -------------------------

# Langfuse expects SALT / ENCRYPTION_KEY / NEXTAUTH_SECRET (without prefix)
if [ -f /run/secrets/langfuse_salt ]; then
  export SALT="${LANGFUSE_SALT}"
fi
if [ -f /run/secrets/langfuse_encryption_key ]; then
  export ENCRYPTION_KEY="${LANGFUSE_ENCRYPTION_KEY}"
fi
if [ -f /run/secrets/langfuse_nextauth_secret ]; then
  export NEXTAUTH_SECRET="${LANGFUSE_NEXTAUTH_SECRET}"
fi

# ClickHouse (Langfuse)
if [ -f /run/secrets/langfuse_clickhouse_password ]; then
  _ch_user="${CLICKHOUSE_USER:-clickhouse}"
  export CLICKHOUSE_MIGRATION_URL="clickhouse://${_ch_user}:${LANGFUSE_CLICKHOUSE_PASSWORD}@${CLICKHOUSE_HOST:-langfuse-clickhouse}:9000"
  export CLICKHOUSE_PASSWORD="${LANGFUSE_CLICKHOUSE_PASSWORD}"
  unset _ch_user
fi

# MinIO (Langfuse)
if [ -f /run/secrets/langfuse_minio_password ]; then
  export MINIO_ROOT_PASSWORD="${LANGFUSE_MINIO_PASSWORD}"
  export LANGFUSE_S3_EVENT_UPLOAD_SECRET_ACCESS_KEY="${LANGFUSE_MINIO_PASSWORD}"
  export LANGFUSE_S3_MEDIA_UPLOAD_SECRET_ACCESS_KEY="${LANGFUSE_MINIO_PASSWORD}"
fi

# Grafana
if [ -f /run/secrets/grafana_admin_password ]; then
  export GF_SECURITY_ADMIN_PASSWORD="${GRAFANA_ADMIN_PASSWORD}"
fi

# Important: sourcing this script must not fail when optional secrets are absent.
true
