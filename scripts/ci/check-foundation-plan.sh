#!/usr/bin/env bash
# First-milestone guard: only the expected POC resource group may change.
set -euo pipefail
[[ $# == 2 ]] || { echo 'Usage: check-foundation-plan.sh PLAN_JSON plan|apply|destroy-plan|destroy' >&2; exit 1; }
plan_file=$1
operation=$2
case "$operation" in plan|apply) destructive=false;; destroy-plan|destroy) destructive=true;; *) exit 1;; esac
jq -e --argjson destructive "$destructive" '
  .format_version == "1.2" and
  all((.resource_changes // [])[];
    .address == "azurerm_resource_group.poc" and .mode == "managed" and .type == "azurerm_resource_group" and
    ((.change.after // .change.before).name == "rg-ai-platform-poc") and
    ((.change.after // .change.before).location == "eastus") and
    (if $destructive then (.change.actions == ["delete"] or .change.actions == ["no-op"])
     else (.change.actions == ["create"] or .change.actions == ["update"] or .change.actions == ["no-op"]) end)
  )
' "$plan_file" >/dev/null || {
  echo 'Plan exceeds the first foundation milestone. Review the resource changes and guard before proceeding.' >&2
  exit 1
}
