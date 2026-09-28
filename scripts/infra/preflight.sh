#!/usr/bin/env bash
# Read-only apply readiness checks. Never registers providers or changes roles.
set -euo pipefail
subscription=${TF_VAR_subscription_id:-${ARM_SUBSCRIPTION_ID:-}}
[[ -n "$subscription" ]] || { echo 'Set TF_VAR_subscription_id.' >&2; exit 1; }
failures=0
for provider in Microsoft.Network Microsoft.Compute Microsoft.ContainerService Microsoft.ContainerRegistry Microsoft.ApiManagement Microsoft.CognitiveServices Microsoft.OperationalInsights Microsoft.Insights Microsoft.ManagedIdentity; do
  state=$(az provider show --subscription "$subscription" --namespace "$provider" --query registrationState -o tsv)
  if [[ "$state" != Registered ]]; then
    printf 'NOT READY: provider %s is %s. Register before apply.\n' "$provider" "$state"
    failures=$((failures + 1))
  fi
done
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
subscription_permissions=$(az rest --method get --url "https://management.azure.com/subscriptions/$subscription/providers/Microsoft.Authorization/permissions?api-version=2022-04-01" -o json)
for action in microsoft.apimanagement/deletedservices/delete microsoft.cognitiveservices/locations/resourcegroups/deletedaccounts/delete; do
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
echo 'Provider and RBAC checks passed. Recheck quota, capacity, prices and Copilot app registration before apply.'
