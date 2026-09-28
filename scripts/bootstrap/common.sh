#!/usr/bin/env bash
# Shared configuration, JSON handling, and safety checks. Bash 3.2+ compatible.
set -euo pipefail
umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
LOCAL_DIR="${BOOTSTRAP_LOCAL_DIR:-$ROOT_DIR/.local/bootstrap}"
MANIFEST="$LOCAL_DIR/manifest.json"
BLOB_ROLE=ba92f5b4-2d11-453d-a403-e96b0029c9fe
CONTRIBUTOR=b24988ac-6180-42a0-ab88-20f7382dd24c
STATE_DOWNLOAD=''
MANIFEST_TEMP=''

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
azj() { command az "$@" --only-show-errors --output json; }
# JSON values are passed as arguments, never evaluated or sourced as shell code.
manifest_update() {
  MANIFEST_TEMP=$(mktemp "$LOCAL_DIR/manifest.XXXXXX")
  jq "$@" "$MANIFEST" > "$MANIFEST_TEMP"
  mv -- "$MANIFEST_TEMP" "$MANIFEST"
  MANIFEST_TEMP=''
}
remove_temporary_files() {
  [[ -z "$STATE_DOWNLOAD" ]] || rm -f -- "$STATE_DOWNLOAD"
  [[ -z "$MANIFEST_TEMP" ]] || rm -f -- "$MANIFEST_TEMP"
}
trap remove_temporary_files EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# UUID v5 with the standard URL namespace, matching the previous manifest IDs.
uuid5() {
  local digest variant
  digest=$({ printf '\x6b\xa7\xb8\x11\x9d\xad\x11\xd1\x80\xb4\x00\xc0\x4f\xd4\x30\xc8'; printf '%s' "$1"; } | openssl dgst -sha1)
  digest=${digest##* }
  variant=$(( (16#${digest:16:1} & 3) | 8 ))
  printf '%s-%s-5%s-%x%s-%s\n' "${digest:0:8}" "${digest:8:4}" "${digest:13:3}" "$variant" "${digest:17:3}" "${digest:20:12}"
}

initialize() {
  OPERATION=$1
  shift
  CONFIG_FILE="$SCRIPT_DIR/config.json"
  EXECUTE=false
  CONFIRM=''
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --execute) EXECUTE=true; shift ;;
      --config) [[ $# -ge 2 ]] || fail '--config needs a file'; CONFIG_FILE=$2; shift 2 ;;
      --confirm-state-deletion) [[ $# -ge 2 ]] || fail '--confirm-state-deletion needs the subscription ID'; CONFIRM=$2; shift 2 ;;
      --help|-h)
        printf 'Usage: %s [--config FILE] [--execute] [--confirm-state-deletion SUBSCRIPTION_ID]\nDefault: offline preview. See docs/runbooks/bootstrap.md.\n' "$0"
        exit 0 ;;
      *) fail "Unknown argument: $1" ;;
    esac
  done
  command -v jq >/dev/null || fail 'Install jq first'
  command -v openssl >/dev/null || fail 'Install openssl first'
  CONFIG=$(jq -ce '
    .subscription_id |= ascii_downcase | .tenant_id |= ascii_downcase |
    select((.subscription_id | test("^[a-f0-9]{8}(-[a-f0-9]{4}){3}-[a-f0-9]{12}$")) and
           (.tenant_id | test("^[a-f0-9]{8}(-[a-f0-9]{4}){3}-[a-f0-9]{12}$")) and
           (.bootstrap_resource_group | test("^[A-Za-z0-9_-]{1,90}$")) and
           (.workload_resource_group | test("^[A-Za-z0-9_-]{1,90}$")) and
           (.bootstrap_resource_group != .workload_resource_group) and
           (.github_repository | test("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$")) and
           ((.github_owner_id == null and .github_repository_id == null) or
            ((.github_owner_id | type == "string" and test("^[0-9]+$")) and
             (.github_repository_id | type == "string" and test("^[0-9]+$")))) and
           (.state_container | test("^[a-z0-9]+(-[a-z0-9]+)*$") and length >= 3 and length <= 63) and
           (.github_branch | type == "string" and length > 0) and
           (.state_key | type == "string" and length > 0) and
           (.location | type == "string" and length > 0))' "$CONFIG_FILE") || fail 'Invalid configuration'
  SUBSCRIPTION_ID=$(jq -r .subscription_id <<< "$CONFIG")
  TENANT_ID=$(jq -r .tenant_id <<< "$CONFIG")
  LOCATION=$(jq -r .location <<< "$CONFIG")
  BOOTSTRAP_RG=$(jq -r .bootstrap_resource_group <<< "$CONFIG")
  WORKLOAD_RG=$(jq -r .workload_resource_group <<< "$CONFIG")
  REPOSITORY=$(jq -r .github_repository <<< "$CONFIG")
  BRANCH=$(jq -r .github_branch <<< "$CONFIG")
  CONTAINER=$(jq -r .state_container <<< "$CONFIG")
  STATE_KEY=$(jq -r .state_key <<< "$CONFIG")
  SUB_SCOPE="/subscriptions/$SUBSCRIPTION_ID"
  SUFFIX=$(printf '%s' "$SUB_SCOPE/$REPOSITORY" | openssl dgst -sha256)
  SUFFIX=${SUFFIX##* }; SUFFIX=${SUFFIX:0:12}
  STORAGE_NAME="staipoc$SUFFIX"
  STORAGE_ID="$SUB_SCOPE/resourceGroups/$BOOTSTRAP_RG/providers/Microsoft.Storage/storageAccounts/$STORAGE_NAME"
  CONTAINER_ID="$STORAGE_ID/blobServices/default/containers/$CONTAINER"
  WORKLOAD_ID="$SUB_SCOPE/resourceGroups/$WORKLOAD_RG"
  APP_NAME="github-ai-platform-poc-$SUFFIX"
  ROLE_ID=$(uuid5 "$SUB_SCOPE/ai-poc-rg-writer/$SUFFIX")
  ROLE_NAME="AI POC Resource Group Writer $SUFFIX"
  SUBJECT="repo:$REPOSITORY:ref:refs/heads/$BRANCH"
  if jq -e '.github_owner_id != null' <<< "$CONFIG" >/dev/null; then
    OWNER_ID=$(jq -r .github_owner_id <<< "$CONFIG")
    REPO_ID=$(jq -r .github_repository_id <<< "$CONFIG")
    SUBJECT="repo:${REPOSITORY%%/*}@$OWNER_ID/${REPOSITORY#*/}@$REPO_ID:ref:refs/heads/$BRANCH"
  fi
  SUB_ARGS=(--subscription "$SUBSCRIPTION_ID")
  printf '%s\n' "Operation: $OPERATION" "Subscription: $SUBSCRIPTION_ID" "Tenant: $TENANT_ID" \
    "Bootstrap group: $BOOTSTRAP_RG ($LOCATION)" "Storage: $STORAGE_NAME / $CONTAINER / $STATE_KEY" \
    "Pipeline application: $APP_NAME" "OIDC subject: $SUBJECT" "Custom role: $ROLE_NAME (actual Azure ID saved during setup)" \
    "Workload group (Terraform-owned): $WORKLOAD_RG" "Local records: $LOCAL_DIR"
  if [[ "$EXECUTE" == false ]]; then
    printf 'PREVIEW ONLY. No Azure calls or local changes. Add --execute when ready.\n'
    return
  fi
  if [[ "$OPERATION" == cleanup && "$CONFIRM" != "$SUBSCRIPTION_ID" ]]; then
    fail 'Cleanup requires --confirm-state-deletion with the exact subscription ID'
  fi
  command -v az >/dev/null || fail 'Install Azure CLI first'
  local account operator token
  account=$(azj account show)
  jq -e --arg sub "$SUBSCRIPTION_ID" --arg tenant "$TENANT_ID" \
    '(.id | ascii_downcase) == $sub and (.tenantId | ascii_downcase) == $tenant and .state == "Enabled"' \
    <<< "$account" >/dev/null || fail 'Wrong active subscription/tenant or subscription not enabled'
  if [[ -f "$MANIFEST" ]]; then
    jq -e --argjson config "$CONFIG" '.version == 1 and .config == $config and (.assignments | type == "array") and (.ownership_token | type == "string" and length > 0)' "$MANIFEST" >/dev/null \
      || fail 'Manifest/config mismatch; restore the original configuration and manifest'
    if [[ "$OPERATION" != cleanup ]] && jq -e '.cleaned_up == true' "$MANIFEST" >/dev/null; then
      fail 'Previous bootstrap was cleaned up. Archive the local directory before starting fresh'
    fi
  elif [[ "$OPERATION" == provision ]]; then
    operator=$(azj ad signed-in-user show)
    operator=$(jq -er '.id | select(type == "string" and length > 0)' <<< "$operator")
    token=$(openssl rand -hex 16)
    mkdir -p -- "$LOCAL_DIR"
    jq -n --argjson config "$CONFIG" --arg token "$token" --arg operator "$operator" \
      '{version:1, config:$config, ownership_token:$token, operator_id:$operator, assignments:[]}' > "$MANIFEST"
  else
    fail 'Missing manifest.json; restore it before continuing'
  fi
  TOKEN=$(jq -er .ownership_token "$MANIFEST")
  OPERATOR_ID=$(jq -er .operator_id "$MANIFEST")
}

assert_owned() {
  jq -e --arg token "$TOKEN" '.tags["bootstrap-id"] == $token' <<< "$1" >/dev/null \
    || fail 'Ownership tag mismatch; refusing to adopt or delete resource'
}

# Journal the deterministic ID BEFORE the Azure write, so retries are safe.
assign_role() {
  local principal=$1 role=$2 scope=$3 type=$4 name assignment_id
  name=$(uuid5 "$principal$role$scope")
  assignment_id="$scope/providers/Microsoft.Authorization/roleAssignments/$name"
  manifest_update --arg id "$assignment_id" '.assignments |= (. + [$id] | unique)'
  azj role assignment create --name "$name" --assignee-object-id "$principal" \
    --assignee-principal-type "$type" --role "$role" --scope "$scope" "${SUB_ARGS[@]}" >/dev/null
}
