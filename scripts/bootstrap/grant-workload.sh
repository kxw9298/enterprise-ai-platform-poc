#!/usr/bin/env bash
# Run as an administrator AFTER Terraform creates the POC resource group.
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/common.sh"
initialize grant-workload "$@"
[[ "$EXECUTE" == true ]] || exit 0
jq -e '.provisioned == true' "$MANIFEST" >/dev/null || fail 'Finish bootstrap first'
group=$(azj group show -n "$WORKLOAD_RG" "${SUB_ARGS[@]}")
jq -e '.tags.project == "enterprise-ai-platform-poc" and .tags["managed-by"] == "terraform"' <<< "$group" >/dev/null \
  || fail 'Workload group must carry project=enterprise-ai-platform-poc and managed-by=terraform tags'
PRINCIPAL_ID=$(jq -er .principal_id "$MANIFEST")
assign_role "$PRINCIPAL_ID" "$CONTRIBUTOR" "$WORKLOAD_ID" ServicePrincipal
printf 'Contributor assigned to the POC group only. Role-assignment administration is not granted.\n'
