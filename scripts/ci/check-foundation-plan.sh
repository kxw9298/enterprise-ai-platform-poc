#!/usr/bin/env bash
# Exact resource-address allowlist, POC scope, and destructive-operation guard.
set -euo pipefail
[[ $# == 2 ]] || { echo 'Usage: check-foundation-plan.sh PLAN_JSON OPERATION' >&2; exit 1; }
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
case "$2" in plan|apply|probe-plan|probe|down-plan|down|destroy-plan|destroy) ;; *) exit 1;; esac
jq -e --arg operation "$2" --slurpfile allowed "$ROOT/platform-resources.json" '
  .format_version == "1.2" and
  all((.resource_changes // [])[];
    if .mode == "data" then .address == "data.azurerm_client_config.current"
    else
      ($allowed[0][.address] == .type) and
      ((.change.after // .change.before) as $v |
        (($v.resource_group_name // "rg-ai-platform-poc") == "rg-ai-platform-poc") and
        (($v.location // "eastus") ==
          (if .address == "module.network.azurerm_virtual_network.integration[\"westus\"]" then "westus"
           elif .address == "module.network.azapi_resource.network_policy" then "unitedstates" else "eastus" end)) and
        (if .type == "azapi_resource" then
          $v.type == "Microsoft.PowerPlatform/enterprisePolicies@2020-10-30-preview" and
          (if $v.parent_id == null then true else ($v.parent_id | ascii_downcase | endswith("/resourcegroups/rg-ai-platform-poc")) end)
         else true end) and
        (if .type == "azurerm_resource_group" then $v.name == "rg-ai-platform-poc" else true end) and
        (if .type == "azurerm_role_assignment" then
          (["Network Contributor", "Managed Identity Operator", "AcrPull", "Azure Kubernetes Service RBAC Cluster Admin", "Cognitive Services OpenAI User", "Monitoring Metrics Publisher"] | index($v.role_definition_name)) != null and
          (if $v.scope == null then true else ($v.scope | ascii_downcase | contains("/resourcegroups/rg-ai-platform-poc/")) end)
         else true end)) and
      (if ($operation == "destroy" or $operation == "destroy-plan") then
          (.change.actions == ["delete"] or .change.actions == ["no-op"])
       elif ($operation == "down" or $operation == "down-plan") then
          (if (.address == "azurerm_resource_group.poc" or (.address | startswith("module.network."))) then .change.actions == ["no-op"]
           else (.change.actions == ["delete"] or .change.actions == ["no-op"]) end)
       else (.change.actions == ["create"] or .change.actions == ["update"] or .change.actions == ["no-op"]) end)
    end
  )
' "$1" >/dev/null || {
  echo 'Plan exceeds the reviewed POC resources, scope, role permissions, or permitted actions. Replacements require explicit review.' >&2
  exit 1
}
