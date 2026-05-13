#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
deploy_dir="$(cd "${script_dir}/.." && pwd)"
repo_root="$(cd "${deploy_dir}/.." && pwd)"

if [[ ! -f "${deploy_dir}/.env" ]]; then
  echo ".env nao encontrado no diretorio deploy/."
  exit 1
fi

echo "[security-review] validando ambiente de deploy"
(
  cd "${deploy_dir}"
  ./scripts/validate-env.sh
)

echo "[security-review] validando alinhamento de scopes Shopify (oauth constants x shopify.app.toml)"
toml_scopes_csv="$(sed -nE 's/^scopes = "(.*)"/\1/p' "${repo_root}/shopify.app.toml" | head -n 1)"
if [[ -z "${toml_scopes_csv}" ]]; then
  echo "[security-review] nao foi possivel ler scopes em shopify.app.toml"
  exit 1
fi

declare -A toml_scope_map=()
IFS=',' read -ra toml_scopes <<< "${toml_scopes_csv}"
for scope in "${toml_scopes[@]}"; do
  normalized="$(printf '%s' "${scope}" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
  if [[ -n "${normalized}" ]]; then
    toml_scope_map["${normalized}"]=1
  fi
done

oauth_scopes="$(awk '/SHOPIFY_SCOPES = \[/,/\] as const;/' "${repo_root}/apps/api/src/infrastructure/out/ecommerce/shopify/shopify-oauth.constants.ts" | sed -nE "s/^[[:space:]]*'([^']+)'.*$/\1/p")"
if [[ -z "${oauth_scopes}" ]]; then
  echo "[security-review] nao foi possivel ler SHOPIFY_SCOPES em shopify-oauth.constants.ts"
  exit 1
fi

missing_scopes=()
while IFS= read -r scope; do
  if [[ -z "${scope}" ]]; then
    continue
  fi
  if [[ -z "${toml_scope_map["${scope}"]+x}" ]]; then
    missing_scopes+=("${scope}")
  fi
done <<< "${oauth_scopes}"

if (( ${#missing_scopes[@]} > 0 )); then
  echo "[security-review] scopes usados no OAuth e ausentes no shopify.app.toml:"
  for scope in "${missing_scopes[@]}"; do
    echo " - ${scope}"
  done
  exit 1
fi

declare -A oauth_scope_map=()
while IFS= read -r scope; do
  if [[ -z "${scope}" ]]; then
    continue
  fi
  oauth_scope_map["${scope}"]=1
done <<< "${oauth_scopes}"

toml_not_in_oauth=()
for scope in "${toml_scopes[@]}"; do
  normalized="$(printf '%s' "${scope}" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
  if [[ -z "${normalized}" ]]; then
    continue
  fi
  if [[ -z "${oauth_scope_map["${normalized}"]+x}" ]]; then
    toml_not_in_oauth+=("${normalized}")
  fi
done

if (( ${#toml_not_in_oauth[@]} > 0 )); then
  echo "[security-review] scopes no shopify.app.toml e ausentes em SHOPIFY_SCOPES (OAuth):"
  for scope in "${toml_not_in_oauth[@]}"; do
    echo " - ${scope}"
  done
  exit 1
fi

echo "[security-review] scan de assinaturas conhecidas de secret em arquivos versionados"
set +e
secret_hits="$(cd "${repo_root}" && git grep -nE "(AKIA[0-9A-Z]{16}|-----BEGIN (RSA|EC|OPENSSH|DSA) PRIVATE KEY-----|xox[baprs]-[A-Za-z0-9-]{10,}|gh[pousr]_[A-Za-z0-9]{36,}|sk_live_[A-Za-z0-9]+)" -- .)"
grep_status=$?
set -e

if [[ ${grep_status} -ne 0 && ${grep_status} -ne 1 ]]; then
  echo "[security-review] falha ao executar scan de secrets"
  exit 1
fi

if [[ -n "${secret_hits}" ]]; then
  echo "[security-review] encontrados possiveis secrets versionados:"
  echo "${secret_hits}"
  exit 1
fi

echo "[security-review] checks automatizados OK"
echo "[security-review] proximo passo manual: registrar evidencias em docs/operations/runbooks/launch-signoff.md"
