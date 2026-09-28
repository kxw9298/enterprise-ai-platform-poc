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
