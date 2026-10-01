#!/usr/bin/env bash
# Read-only apply readiness checks. Never registers providers or changes roles.
set -euo pipefail
subscription=${TF_VAR_subscription_id:-${ARM_SUBSCRIPTION_ID:-}}
[[ -n "$subscription" ]] || { echo 'Set TF_VAR_subscription_id.' >&2; exit 1; }
failures=0
# Terraform creates the workload group, so on a clean-slate apply it does not exist yet.
# Group-scoped reads below must degrade instead of aborting under set -euo pipefail.
workload_group=rg-ai-platform-poc
# `group exists` returns a scalar boolean, not an object with a `value` field.
group_exists=$(az group exists --subscription "$subscription" --name "$workload_group" -o tsv)
case "$group_exists" in
  true|false) ;;
  *) echo 'NOT READY: could not determine whether the workload group exists.' >&2; exit 1 ;;
esac
providers=(Microsoft.Network Microsoft.Compute Microsoft.ApiManagement Microsoft.OperationalInsights Microsoft.Insights Microsoft.ManagedIdentity Microsoft.PowerPlatform)
[[ "${TF_VAR_enable_foundry:-false}" != true ]] || providers+=(Microsoft.CognitiveServices)
[[ "${TF_VAR_enable_mcp_runtime:-false}" != true ]] || providers+=(Microsoft.ContainerService Microsoft.ContainerRegistry)
[[ "${TF_VAR_enable_container_apps:-true}" != true ]] || providers+=(Microsoft.App Microsoft.ContainerRegistry)
for provider in "${providers[@]}"; do
  state=$(az provider show --subscription "$subscription" --namespace "$provider" --query registrationState -o tsv)
  if [[ "$state" != Registered ]]; then
    printf 'NOT READY: provider %s is %s. Register before apply.\n' "$provider" "$state"
    failures=$((failures + 1))
  fi
done
# Container Apps environment quota is separate from VM quota. An existing environment
# already consumes its slot, so repeat applies must not require an extra slot.
if [[ "${OPERATION:-apply}" == apply && "${TF_VAR_enable_container_apps:-true}" == true ]]; then
  container_usage=$(az rest --method get --url "https://management.azure.com/subscriptions/$subscription/providers/Microsoft.App/locations/eastus/usages?api-version=2025-07-01" -o json)
  suffix=$(python3 -c 'import hashlib,sys; print(hashlib.sha256(sys.argv[1].encode()).hexdigest()[:8])' "$subscription")
  # No group yet means no existing environment, which is the repeat-apply-safe case.
  existing='[]'
  if [[ "$group_exists" == true ]]; then
    existing=$(az resource list --subscription "$subscription" --resource-group "$workload_group" --resource-type Microsoft.App/managedEnvironments --query "[?name=='cae-aipoc-$suffix'].id" -o json)
  fi
  if [[ "$(jq length <<< "$existing")" == 0 ]] && ! jq -e 'any(.value[]; .name.value == "ManagedEnvironmentCount" and ((.limit | tonumber) - (.currentValue | tonumber)) >= 1)' <<< "$container_usage" >/dev/null; then
    echo 'NOT READY: no available Container Apps environment slot in East US.'
    failures=$((failures + 1))
  fi
  echo 'Container Apps: verify environment consumption-core quota after environment creation; regional slot availability does not prove compute capacity.'
fi
# The current AKS defaults require 8 cores plus 4 for one surge node.
# Check total limits so existing nodes do not make repeat applies fail. Other workloads
# can consume this quota; review available capacity separately before apply.
# This is read-only and intentionally fails closed if subscription usage is unavailable.
if [[ "${OPERATION:-apply}" == apply && "${TF_VAR_enable_mcp_runtime:-false}" == true ]]; then
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
# Without the group there is no group-scoped delegation to evaluate, so fall back
# to the subscription scope, which is strictly broader and therefore conservative.
if [[ "$group_exists" == true ]]; then
  permissions=$(az rest --method get --url "https://management.azure.com/subscriptions/$subscription/resourceGroups/$workload_group/providers/Microsoft.Authorization/permissions?api-version=2022-04-01" -o json)
else
  permissions=$(az rest --method get --url "https://management.azure.com/subscriptions/$subscription/providers/Microsoft.Authorization/permissions?api-version=2022-04-01" -o json)
fi
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
echo 'Coarse provider and RBAC action checks passed. Role-assignment conditions are NOT evaluated.'
if [[ "${TF_VAR_enable_container_apps:-true}" == true ]]; then
  echo 'Container Apps requires AcrPull assignment delegation for its image-pull identity; image publishing separately requires registry-scoped AcrPush.'
fi
if [[ "${TF_VAR_enable_mcp_runtime:-false}" == true ]]; then
  echo 'Phase 2: existing gateway-only delegation is insufficient for AKS. Review Network Contributor, Managed Identity Operator, AcrPull and optional AKS admin delegation.'
fi
echo 'Recheck runtime eligibility, available quota, capacity, prices and Copilot authentication before apply.'
