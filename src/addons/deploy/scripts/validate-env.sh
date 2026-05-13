#!/usr/bin/env bash
set -euo pipefail

if [[ ! -f .env ]]; then
  echo ".env não encontrado no diretório deploy/."
  exit 1
fi

ENV_FILE=".env"
SECRETS_DIR="${SECRETS_DIR:-/home/ubuntu/wp/your-app/secrets}"

read_env_var() {
  local key="$1"
  local line
  line=$(grep -E "^${key}=" "${ENV_FILE}" | tail -n 1 || true)
  if [[ -z "${line}" ]]; then
    echo ""
    return
  fi
  echo "${line#*=}"
}

# Read a secret value: first try secret file, then fall back to .env.
read_secret() {
  local key="$1"
  local secret_name
  secret_name="$(echo "${key}" | tr '[:upper:]' '[:lower:]')"
  if [[ -f "${SECRETS_DIR}/${secret_name}" ]]; then
    tr -d '\n' < "${SECRETS_DIR}/${secret_name}"
    return
  fi
  read_env_var "${key}"
}

# Check if a secret is available (either in file or .env).
has_secret() {
  local key="$1"
  local value
  value="$(read_secret "${key}")"
  [[ -n "${value}" ]]
}

is_truthy() {
  local value
  value="$(echo "${1:-}" | tr '[:upper:]' '[:lower:]')"
  [[ "${value}" == "1" || "${value}" == "true" || "${value}" == "yes" ]]
}

# Detect if Docker secrets mode is active (secret files directory exists).
secrets_mode=false
if [[ -d "${SECRETS_DIR}" ]] && ls "${SECRETS_DIR}"/* >/dev/null 2>&1; then
  secrets_mode=true
fi

required_vars=(
  STACK_NAME
  API_DOMAIN
  GRAFANA_DOMAIN
  PGA_DOMAIN
  RI_DOMAIN
  API_IMAGE
  API_IMAGE_TAG
  PGVECTOR_IMAGE
  API_PORT
  API_WORKER_COMMAND
  POSTGRES_DB
  POSTGRES_USER
  DATABASE_URL
  REDIS_URL
  PORT
  NODE_ENV
  CORS_ORIGIN
  GRAFANA_ADMIN_USER
  PGADMIN_DEFAULT_EMAIL
  META_GRAPH_API_URL
  SHOPIFY_API_KEY
  SHOPIFY_APP_URL
  SHOPIFY_API_URL
)

# Secrets that must be present (either in .env or as secret files).
required_secrets=(
  POSTGRES_PASSWORD
  REDIS_PASSWORD
  GRAFANA_ADMIN_PASSWORD
  PGADMIN_DEFAULT_PASSWORD
  META_VERIFY_TOKEN
  META_APP_SECRET
  META_ACCESS_TOKEN
  SHOPIFY_API_SECRET
  OPENAI_API_KEY
)

require_non_empty() {
  local key="$1"
  local value
  value="$(read_env_var "${key}")"
  if [[ -z "${value}" ]]; then
    echo "Variável obrigatória ausente: ${key}"
    exit 1
  fi
}

for key in "${required_vars[@]}"; do
  require_non_empty "$key"
done

# In secrets mode, secrets are in files — skip .env checks for them.
# In legacy mode, secrets must be in .env.
if [[ "${secrets_mode}" == "true" ]]; then
  echo "[validate-env] Docker secrets mode: checking secret files in ${SECRETS_DIR}"
  for key in "${required_secrets[@]}"; do
    if ! has_secret "${key}"; then
      echo "Secret obrigatório ausente: ${key} (nem em ${SECRETS_DIR} nem em .env)"
      exit 1
    fi
  done
else
  # Legacy mode: secrets in .env
  for key in "${required_secrets[@]}"; do
    require_non_empty "${key}"
  done
  # Also check DATABASE_URL and REDIS_URL contain passwords
  require_non_empty "DATABASE_URL"
  require_non_empty "REDIS_URL"
fi

NGINX_ENABLED_VALUE="$(read_env_var NGINX_ENABLED)"
if is_truthy "${NGINX_ENABLED_VALUE}"; then
  echo "NGINX_ENABLED=true não é suportado: reverse proxy é gerido pelo host. Defina NGINX_ENABLED=false (ou remova a variável)."
  exit 1
fi

NODE_ENV_VALUE="$(read_env_var NODE_ENV)"
DATABASE_URL_VALUE="$(read_env_var DATABASE_URL)"
POSTGRES_DB_VALUE="$(read_env_var POSTGRES_DB)"
REDIS_URL_VALUE="$(read_env_var REDIS_URL)"
CORS_ORIGIN_VALUE="$(read_env_var CORS_ORIGIN)"
META_GRAPH_API_URL_VALUE="$(read_env_var META_GRAPH_API_URL)"
SHOPIFY_APP_URL_VALUE="$(read_env_var SHOPIFY_APP_URL)"
SHOPIFY_API_URL_VALUE="$(read_env_var SHOPIFY_API_URL)"
PGADMIN_DEFAULT_EMAIL_VALUE="$(read_env_var PGADMIN_DEFAULT_EMAIL)"
API_DOMAIN_VALUE="$(read_env_var API_DOMAIN)"
GRAFANA_DOMAIN_VALUE="$(read_env_var GRAFANA_DOMAIN)"
PGA_DOMAIN_VALUE="$(read_env_var PGA_DOMAIN)"
RI_DOMAIN_VALUE="$(read_env_var RI_DOMAIN)"
MAIL_ENABLED_VALUE="$(read_env_var MAIL_ENABLED)"
LANGFUSE_DOMAIN_VALUE="$(read_env_var LANGFUSE_DOMAIN)"

if [[ "${NODE_ENV_VALUE}" != "production" ]]; then
  echo "NODE_ENV deve ser production em deploy."
  exit 1
fi

# In secrets mode, DATABASE_URL and REDIS_URL are constructed at container start
# by the entrypoint wrapper. Skip format validation for them.
if [[ "${secrets_mode}" != "true" ]]; then
  if [[ ! "${DATABASE_URL_VALUE}" =~ ^postgres(ql)?:// ]]; then
    echo "DATABASE_URL deve usar postgres:// ou postgresql://"
    exit 1
  fi

  if [[ "${DATABASE_URL_VALUE}" =~ /langfuse([/?#]|$) ]]; then
    echo "DATABASE_URL da API não pode apontar para o database 'langfuse'. Use o database da aplicação (ex.: whatsapp_sales_agent)."
    exit 1
  fi

  DATABASE_NAME_FROM_URL="$(printf '%s' "${DATABASE_URL_VALUE}" | sed -E 's|^[^:]+://[^/]+/([^/?#]+).*$|\1|')"
  if [[ -z "${DATABASE_NAME_FROM_URL}" ]]; then
    echo "Não foi possível extrair o nome do database em DATABASE_URL."
    exit 1
  fi

  if [[ "${DATABASE_NAME_FROM_URL}" != "${POSTGRES_DB_VALUE}" ]]; then
    echo "DATABASE_URL e POSTGRES_DB estão divergentes: DATABASE_URL usa '${DATABASE_NAME_FROM_URL}' e POSTGRES_DB usa '${POSTGRES_DB_VALUE}'."
    exit 1
  fi

  if [[ ! "${REDIS_URL_VALUE}" =~ ^redis(s)?:// ]]; then
    echo "REDIS_URL deve usar redis:// ou rediss://"
    exit 1
  fi
fi

if [[ "${PGADMIN_DEFAULT_EMAIL_VALUE}" != *"@"* ]]; then
  echo "PGADMIN_DEFAULT_EMAIL deve ser um email válido."
  exit 1
fi

for url_value in \
  "${CORS_ORIGIN_VALUE}" \
  "${META_GRAPH_API_URL_VALUE}" \
  "${SHOPIFY_APP_URL_VALUE}" \
  "${SHOPIFY_API_URL_VALUE}"; do
  if [[ ! "${url_value}" =~ ^https?:// ]]; then
    echo "CORS_ORIGIN, META_GRAPH_API_URL, SHOPIFY_APP_URL e SHOPIFY_API_URL devem usar http:// ou https://"
    exit 1
  fi
done

for domain_value in \
  "${API_DOMAIN_VALUE}" \
  "${GRAFANA_DOMAIN_VALUE}" \
  "${PGA_DOMAIN_VALUE}" \
  "${RI_DOMAIN_VALUE}"; do
  if [[ "${domain_value}" == http*://* ]]; then
    echo "API_DOMAIN, GRAFANA_DOMAIN, PGA_DOMAIN e RI_DOMAIN devem conter apenas host/subdomínio, sem protocolo."
    exit 1
  fi
done

for secret_key in POSTGRES_PASSWORD REDIS_PASSWORD GRAFANA_ADMIN_PASSWORD PGADMIN_DEFAULT_PASSWORD META_VERIFY_TOKEN META_APP_SECRET META_ACCESS_TOKEN SHOPIFY_API_KEY SHOPIFY_API_SECRET OPENAI_API_KEY; do
  secret_value="$(read_secret "${secret_key}")"
  if [[ "${secret_value}" == "change-me" ]]; then
    echo "Variável ${secret_key} ainda está com placeholder 'change-me'."
    exit 1
  fi
done

if [[ -n "${LANGFUSE_DOMAIN_VALUE}" ]]; then
  require_non_empty LANGFUSE_NEXTAUTH_URL
  # Langfuse secrets: check via has_secret (supports file or .env)
  for lf_secret in LANGFUSE_SALT LANGFUSE_NEXTAUTH_SECRET LANGFUSE_ENCRYPTION_KEY LANGFUSE_CLICKHOUSE_PASSWORD LANGFUSE_MINIO_PASSWORD; do
    if ! has_secret "${lf_secret}"; then
      echo "Langfuse secret obrigatório ausente: ${lf_secret}"
      exit 1
    fi
  done
  require_non_empty LANGFUSE_AUTH_DISABLE_SIGNUP
  require_non_empty LANGFUSE_INIT_ORG_ID
  require_non_empty LANGFUSE_INIT_ORG_NAME
  require_non_empty LANGFUSE_INIT_PROJECT_ID
  require_non_empty LANGFUSE_INIT_PROJECT_NAME
  require_non_empty LANGFUSE_INIT_USER_EMAIL
  require_non_empty LANGFUSE_INIT_USER_NAME
  require_non_empty LANGFUSE_INIT_USER_PASSWORD

  LANGFUSE_AUTH_DISABLE_SIGNUP_VALUE="$(read_env_var LANGFUSE_AUTH_DISABLE_SIGNUP)"
  LANGFUSE_NEXTAUTH_URL_VALUE="$(read_env_var LANGFUSE_NEXTAUTH_URL)"
  LANGFUSE_INIT_USER_EMAIL_VALUE="$(read_env_var LANGFUSE_INIT_USER_EMAIL)"
  LANGFUSE_INIT_USER_PASSWORD_VALUE="$(read_env_var LANGFUSE_INIT_USER_PASSWORD)"

  if ! is_truthy "${LANGFUSE_AUTH_DISABLE_SIGNUP_VALUE}"; then
    echo "Com LANGFUSE_DOMAIN definido, LANGFUSE_AUTH_DISABLE_SIGNUP deve ser true."
    exit 1
  fi

  if [[ ! "${LANGFUSE_NEXTAUTH_URL_VALUE}" =~ ^https:// ]]; then
    echo "Com LANGFUSE_DOMAIN definido, LANGFUSE_NEXTAUTH_URL deve usar https://"
    exit 1
  fi

  if [[ "${LANGFUSE_INIT_USER_EMAIL_VALUE}" != *"@"* ]]; then
    echo "LANGFUSE_INIT_USER_EMAIL deve ser um email válido."
    exit 1
  fi

  if [[ "${LANGFUSE_INIT_USER_PASSWORD_VALUE}" == "change-me" ]]; then
    echo "LANGFUSE_INIT_USER_PASSWORD ainda está com placeholder 'change-me'."
    exit 1
  fi
fi

if is_truthy "${MAIL_ENABLED_VALUE}"; then
  require_non_empty MAIL_SERVER_HOST
  require_non_empty MAIL_DOMAIN
  require_non_empty MAIL_POSTMASTER
  require_non_empty MAIL_AUTH_USER
  if ! has_secret MAIL_AUTH_PASS; then
    echo "Secret obrigatório ausente: MAIL_AUTH_PASS"
    exit 1
  fi
  require_non_empty MAIL_FROM
  require_non_empty WEBMAIL_DOMAIN
  require_non_empty MAIL_DATA_DIR
  require_non_empty MAIL_CERTS_DIR

  MAIL_SERVER_HOST_VALUE="$(read_env_var MAIL_SERVER_HOST)"
  MAIL_DOMAIN_VALUE="$(read_env_var MAIL_DOMAIN)"
  MAIL_POSTMASTER_VALUE="$(read_env_var MAIL_POSTMASTER)"
  MAIL_AUTH_USER_VALUE="$(read_env_var MAIL_AUTH_USER)"
  MAIL_AUTH_PASS_VALUE="$(read_secret MAIL_AUTH_PASS)"
  MAIL_FROM_VALUE="$(read_env_var MAIL_FROM)"
  WEBMAIL_DOMAIN_VALUE="$(read_env_var WEBMAIL_DOMAIN)"
  MAIL_DATA_DIR_VALUE="$(read_env_var MAIL_DATA_DIR)"
  MAIL_CERTS_DIR_VALUE="$(read_env_var MAIL_CERTS_DIR)"
  SMTP_HOST_VALUE="$(read_env_var SMTP_HOST)"
  SMTP_PORT_VALUE="$(read_env_var SMTP_PORT)"
  SMTP_USER_VALUE="$(read_env_var SMTP_USER)"
  SMTP_PASS_VALUE="$(read_secret SMTP_PASS)"
  SMTP_FROM_VALUE="$(read_env_var SMTP_FROM)"

  for host_value in "${MAIL_SERVER_HOST_VALUE}" "${MAIL_DOMAIN_VALUE}" "${WEBMAIL_DOMAIN_VALUE}"; do
    if [[ "${host_value}" == http*://* ]]; then
      echo "MAIL_SERVER_HOST, MAIL_DOMAIN e WEBMAIL_DOMAIN devem conter apenas host/subdomínio, sem protocolo."
      exit 1
    fi
  done

  for email_value in "${MAIL_POSTMASTER_VALUE}" "${MAIL_AUTH_USER_VALUE}" "${MAIL_FROM_VALUE}"; do
    if [[ "${email_value}" != *"@"* ]]; then
      echo "MAIL_POSTMASTER, MAIL_AUTH_USER e MAIL_FROM devem ser emails válidos."
      exit 1
    fi
  done

  if [[ "${MAIL_AUTH_PASS_VALUE}" == "change-me" ]]; then
    echo "MAIL_AUTH_PASS ainda está com placeholder 'change-me'."
    exit 1
  fi

  if [[ "${SMTP_HOST_VALUE}" != "${MAIL_SERVER_HOST_VALUE}" ]]; then
    echo "Com MAIL_ENABLED ativo, SMTP_HOST deve ser igual a MAIL_SERVER_HOST."
    exit 1
  fi

  if [[ "${SMTP_PORT_VALUE}" != "587" ]]; then
    echo "Com MAIL_ENABLED ativo, SMTP_PORT deve ser 587."
    exit 1
  fi

  if [[ "${SMTP_USER_VALUE}" != "${MAIL_AUTH_USER_VALUE}" ]]; then
    echo "Com MAIL_ENABLED ativo, SMTP_USER deve ser igual a MAIL_AUTH_USER."
    exit 1
  fi

  if [[ "${SMTP_PASS_VALUE}" != "${MAIL_AUTH_PASS_VALUE}" ]]; then
    echo "Com MAIL_ENABLED ativo, SMTP_PASS deve ser igual a MAIL_AUTH_PASS."
    exit 1
  fi

  if [[ "${SMTP_FROM_VALUE}" != "${MAIL_FROM_VALUE}" ]]; then
    echo "Com MAIL_ENABLED ativo, SMTP_FROM deve ser igual a MAIL_FROM."
    exit 1
  fi

  if [[ "${MAIL_DATA_DIR_VALUE}" != /* ]]; then
    echo "MAIL_DATA_DIR deve ser caminho absoluto."
    exit 1
  fi

  if [[ "${MAIL_CERTS_DIR_VALUE}" != /* ]]; then
    echo "MAIL_CERTS_DIR deve ser caminho absoluto."
    exit 1
  fi

  if [[ ! -f "${MAIL_CERTS_DIR_VALUE}/fullchain.pem" || ! -f "${MAIL_CERTS_DIR_VALUE}/privkey.pem" ]]; then
    echo "MAIL_CERTS_DIR deve conter fullchain.pem e privkey.pem."
    exit 1
  fi
fi

echo ".env validado com sucesso."
