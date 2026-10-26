#!/usr/bin/env bash
# One-time, explicitly approved repair: logical-API scope for two test subscriptions.
# Generic platform replacement protection remains unchanged.
set -euo pipefail
[[ $# == 1 ]] || exit 1
jq -e '
  .format_version == "1.2" and
  ([.resource_changes[] | select(.mode != "data" and .change.actions != ["no-op"]) ] as $changes |
   ($changes | length) == 3 and
   all($changes[];
     if .address == "module.platform[0].module.foundry[0].azurerm_api_management_api_policy.model" then
       .change.actions == ["update"]
     else
       (.address == "module.platform[0].module.foundry[0].azurerm_api_management_subscription.client[\"client-a\"]" or
        .address == "module.platform[0].module.foundry[0].azurerm_api_management_subscription.client[\"client-b\"]") and
       .type == "azurerm_api_management_subscription" and
       .change.actions == ["delete", "create"] and
       (.change.before as $b | .change.after as $a |
        $b.resource_group_name == "rg-ai-platform-poc" and $a.resource_group_name == $b.resource_group_name and
        $a.api_management_name == $b.api_management_name and
        $a.subscription_id == $b.subscription_id and
        ($a.subscription_id == "model-client-a" or $a.subscription_id == "model-client-b") and
        $a.state == "active" and $a.allow_tracing == false and
        ($b.api_id | endswith("/apis/model;rev=1")) and
        $a.api_id == ($b.api_id | sub(";rev=1$"; "")))
     end))
' "$1" >/dev/null
