#!/usr/bin/env bash
# Test scope guards without Terraform credentials or Azure access.
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
TEMP_DIR=$(mktemp -d)
trap 'rm -rf -- "$TEMP_DIR"' EXIT
base='{"format_version":"1.2","resource_changes":[{"address":"azurerm_resource_group.poc","mode":"managed","type":"azurerm_resource_group","change":{"actions":["create"],"before":null,"after":{"name":"rg-ai-platform-poc","location":"eastus"}}}]}'
printf '%s' "$base" > "$TEMP_DIR/plan.json"
bash "$ROOT/scripts/ci/check-foundation-plan.sh" "$TEMP_DIR/plan.json" apply
for change in \
  '.resource_changes[0].address="azurerm_kubernetes_cluster.cluster"' \
  '.resource_changes[0].change.actions=["delete","create"]' \
  '.resource_changes[0].change.after.name="rg-other"' \
  '.resource_changes[0].change.after.location="westus"'; do
  jq "$change" <<< "$base" > "$TEMP_DIR/plan.json"
  if bash "$ROOT/scripts/ci/check-foundation-plan.sh" "$TEMP_DIR/plan.json" apply 2>/dev/null; then
    echo 'Guard accepted unexpected resources or replacement' >&2; exit 1
  fi
done
jq '.resource_changes[0].change |= (.before=.after | .after=null | .actions=["delete"])' <<< "$base" > "$TEMP_DIR/plan.json"
bash "$ROOT/scripts/ci/check-foundation-plan.sh" "$TEMP_DIR/plan.json" destroy-plan
if bash "$ROOT/scripts/ci/check-foundation-plan.sh" "$TEMP_DIR/plan.json" apply 2>/dev/null; then exit 1; fi
jq '.resource_changes=[]' <<< "$base" > "$TEMP_DIR/plan.json"
bash "$ROOT/scripts/ci/check-foundation-plan.sh" "$TEMP_DIR/plan.json" plan
printf 'Foundation scope checks passed (create/no-op/destroy allowed; replacement and other resources blocked).\n'
# Platform lifecycle: down permits platform deletes but never group deletion.
jq '.resource_changes[0].address="module.platform[0].azurerm_api_management.poc" | .resource_changes[0].type="azurerm_api_management" | .resource_changes[0].change.after={name:"vnet-poc",resource_group_name:"rg-ai-platform-poc",location:"eastus"}' <<< "$base" > "$TEMP_DIR/up.json"
bash "$ROOT/scripts/ci/check-foundation-plan.sh" "$TEMP_DIR/up.json" plan
jq '.resource_changes[0].change |= (.before=.after | .after=null | .actions=["delete"])' "$TEMP_DIR/up.json" > "$TEMP_DIR/down.json"
bash "$ROOT/scripts/ci/check-foundation-plan.sh" "$TEMP_DIR/down.json" down-plan
if bash "$ROOT/scripts/ci/check-foundation-plan.sh" "$TEMP_DIR/down.json" apply 2>/dev/null; then exit 1; fi
jq '.resource_changes[0].change.after.resource_group_name="rg-ai-platform-bootstrap"' "$TEMP_DIR/up.json" > "$TEMP_DIR/bad.json"
if bash "$ROOT/scripts/ci/check-foundation-plan.sh" "$TEMP_DIR/bad.json" plan 2>/dev/null; then exit 1; fi
jq '.resource_changes[0].change |= (.before=.after | .after=null | .actions=["delete"])' <<< "$base" > "$TEMP_DIR/group-delete.json"
if bash "$ROOT/scripts/ci/check-foundation-plan.sh" "$TEMP_DIR/group-delete.json" down-plan 2>/dev/null; then exit 1; fi
printf 'Platform checks passed: scoped create, down/delete boundaries and bootstrap protection.\n'

# Persistent networking must never be deleted by routine down.
jq '.resource_changes[0].address="module.network.azurerm_virtual_network.poc" | .resource_changes[0].type="azurerm_virtual_network"' "$TEMP_DIR/down.json" > "$TEMP_DIR/network-delete.json"
if bash "$ROOT/scripts/ci/check-foundation-plan.sh" "$TEMP_DIR/network-delete.json" down-plan 2>/dev/null; then exit 1; fi
# West US is only permitted for the explicitly reviewed integration VNet.
jq '.resource_changes[0].address="module.network.azurerm_virtual_network.integration[\"westus\"]" | .resource_changes[0].type="azurerm_virtual_network" | .resource_changes[0].change.after.location="westus"' "$TEMP_DIR/up.json" > "$TEMP_DIR/west.json"
bash "$ROOT/scripts/ci/check-foundation-plan.sh" "$TEMP_DIR/west.json" plan
jq '.resource_changes[0].change.after.location="westus"' "$TEMP_DIR/up.json" > "$TEMP_DIR/wrong-region.json"
if bash "$ROOT/scripts/ci/check-foundation-plan.sh" "$TEMP_DIR/wrong-region.json" plan 2>/dev/null; then exit 1; fi
printf 'Persistent network deletion and workload region guards passed.\n'
