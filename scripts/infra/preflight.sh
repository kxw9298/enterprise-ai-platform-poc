#!/usr/bin/env bash
# Read-only apply readiness checks. Never registers providers or changes roles.
set -euo pipefail
subscription=${TF_VAR_subscription_id:-${ARM_SUBSCRIPTION_ID:-}}
[[ -n "$subscription" ]] || { echo 'Set TF_VAR_subscription_id.' >&2; exit 1; }
failures=0
for provider in Microsoft.Network Microsoft.Compute Microsoft.ApiManagement Microsoft.CognitiveServices Microsoft.OperationalInsights Microsoft.Insights Microsoft.ManagedIdentity Microsoft.ContainerService Microsoft.ContainerRegistry Microsoft.PowerPlatform; do
  state=$(az provider show --subscription "$subscription" --namespace "$provider" --query registrationState -o tsv)
  if [[ "$state" != Registered ]]; then
    printf 'NOT READY: provider %s is %s. Register before apply.\n' "$provider" "$state"
    failures=$((failures + 1))
  fi
done
# The current AKS defaults require 8 cores plus 4 for one surge node.
# Check total limits so existing nodes do not make repeat applies fail. Other workloads
# can consume this quota; review available capacity separately before apply.
# This is read-only and intentionally fails closed if subscription usage is unavailable.
if [[ "${OPERATION:-apply}" == apply && "${TF_VAR_enable_mcp_runtime:-true}" == true ]]; then
  usage=$(az vm list-usage --subscription "$subscription" --location eastus -o json)
  if ! jq -e '
    def quota($name): [.[] | select((.name.value | ascii_downcase) == $name) | (.limit | tonumber)] | if length == 1 then .[0] else -1 end;
    quota("cores") >= 12 and quota("standarddsv7family") >= 12
  ' <<< "$usage" >/dev/null; then
    echo 'NOT READY: default AKS pool needs 8 vCPUs plus 4 surge cores in East US and StandardDsv7Family. Verify quota before apply.'
    failures=$((failures + 1))
  fi
fi
# Contributor deliberately excludes role assignment writes. Check the current
# operator's effective permissions, including notActions, before a paid apply.
permissions=$(az rest --method get --url "https://management.azure.com/subscriptions/$subscription/resourceGroups/rg-ai-platform-poc/providers/Microsoft.Authorization/permissions?api-version=2022-04-01" -o json)
if ! jq -e '
  def matches($action): ascii_downcase as $p | $action | test("^" + ($p | split("*") | map(gsub("[.]"; "\\.")) | join(".*")) + "$");
  any(.value[];
    any(.actions[]; matches("microsoft.authorization/roleassignments/write")) and
    (any(.notActions[]?; matches("microsoft.authorization/roleassignments/write")) | not)
  )' <<< "$permissions" >/dev/null; then
  echo 'NOT READY: current identity cannot create workload role assignments. Use an authorized administrator or explicitly configure scoped delegation.'
  failures=$((failures + 1))
fi
# Purge is configured for repeatable name reuse and is outside RG-level grants.
# Terraform's purge step needs both read and delete on the soft-deleted resources.
# Checking delete alone is not enough: a role granting only delete, or granting
# read at the old subscription-scoped name, passes this check and then fails the
# apply with 403 on '<resource>/locations/<resource>/read'.
subscription_permissions=$(az rest --method get --url "https://management.azure.com/subscriptions/$subscription/providers/Microsoft.Authorization/permissions?api-version=2022-04-01" -o json)
for action in microsoft.apimanagement/locations/deletedservices/read microsoft.apimanagement/locations/deletedservices/delete microsoft.cognitiveservices/locations/resourcegroups/deletedaccounts/read microsoft.cognitiveservices/locations/resourcegroups/deletedaccounts/delete; do
  if ! jq -e --arg action "$action" '
    def matches($action): ascii_downcase as $p | $action | test("^" + ($p | split("*") | map(gsub("[.]"; "\\.")) | join(".*")) + "$");
    any(.value[]; any(.actions[]; matches($action)) and (any(.notActions[]?; matches($action)) | not))
  ' <<< "$subscription_permissions" >/dev/null; then
    echo "NOT READY: missing purge permission $action."
    failures=$((failures + 1))
  fi
done
if (( failures > 0 )); then
  echo "$failures prerequisite(s) missing; no changes made."
  exit 1
fi
echo 'Coarse provider and RBAC action checks passed. Conditions are NOT evaluated: the old gateway-only delegation is insufficient for AKS.'
echo 'Review Network Contributor, Managed Identity Operator, AcrPull and optional AKS admin delegation; recheck available quota, capacity, prices and Copilot app registration before apply.'
