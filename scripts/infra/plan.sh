#!/usr/bin/env bash
# Local plan only; saved files stay in ignored .local. No apply command here.
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
TF=${TERRAFORM_BIN:-$ROOT/.local/tools/terraform/1.16.4/terraform}
[[ -x "$TF" ]] || TF=$(command -v terraform)
operation=${1:-plan}
case "$operation" in
  plan) flags=(-var=enable_platform=true);;
  down-plan) flags=(-var=enable_platform=false);;
  destroy-plan) flags=(-destroy);;
  *) echo 'Usage: plan.sh [plan|down-plan|destroy-plan]' >&2; exit 1;;
esac
: "${TF_VAR_publisher_email:?Set publisher email}"
: "${TF_VAR_aks_admin_object_id:?Set operator Entra object ID}"
export TF_VAR_subscription_id="$(jq -r .AZURE_SUBSCRIPTION_ID "$ROOT/.local/bootstrap/github-variables.json")"
export ARM_SUBSCRIPTION_ID="$TF_VAR_subscription_id"
export ARM_TENANT_ID="$(jq -r .AZURE_TENANT_ID "$ROOT/.local/bootstrap/github-variables.json")"
export ARM_USE_CLI=true ARM_USE_OIDC=false
unset ARM_CLIENT_ID ARM_CLIENT_SECRET ARM_OIDC_TOKEN
mkdir -p "$ROOT/.local/plans"
umask 077
"$TF" -chdir="$ROOT/infra/poc" init -input=false -lockfile=readonly -backend-config="$ROOT/.local/bootstrap/backend.hcl"
"$TF" -chdir="$ROOT/infra/poc" validate
"$TF" -chdir="$ROOT/infra/poc" plan -input=false -lock-timeout=5m "${flags[@]}" -out="$ROOT/.local/plans/$operation.tfplan"
"$TF" -chdir="$ROOT/infra/poc" show -json "$ROOT/.local/plans/$operation.tfplan" > "$ROOT/.local/plans/$operation.tfplan.json"
bash "$ROOT/scripts/ci/check-foundation-plan.sh" "$ROOT/.local/plans/$operation.tfplan.json" "$operation"
