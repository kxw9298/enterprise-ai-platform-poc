#!/usr/bin/env bash
# Integration-style shell tests with a fake Azure CLI. No cloud access.
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_DIR=$(mktemp -d)
trap 'rm -rf -- "$TEST_DIR"' EXIT
mkdir -p "$TEST_DIR/bin" "$TEST_DIR/cloud"
cp "$ROOT/tests/bootstrap/mock-az.sh" "$TEST_DIR/bin/az"
chmod +x "$TEST_DIR/bin/az"
export PATH="$TEST_DIR/bin:$PATH"
export MOCK_DIR="$TEST_DIR/cloud" BOOTSTRAP_LOCAL_DIR="$TEST_DIR/local"
export SUB_ID=a48d0557-360a-4849-8b56-a73b28f66aa6 TENANT=eb241c67-e72d-4862-ae41-7686706624c4
export STORAGE_RESOURCE_ID="/subscriptions/$SUB_ID/resourceGroups/rg-ai-platform-bootstrap/providers/Microsoft.Storage/storageAccounts/staipocc38dc8cb9cf7"
SCRIPT="$ROOT/scripts/bootstrap"
passed=0
pass() { passed=$((passed + 1)); printf 'PASS %s\n' "$*"; }
expect_block() {
  local expected=$1; shift
  : > "$MOCK_DIR/calls.log"
  if bash "$@" > "$TEST_DIR/output" 2>&1; then cat "$TEST_DIR/output"; printf 'Expected failure\n' >&2; exit 1; fi
  grep -q "$expected" "$TEST_DIR/output" || { cat "$TEST_DIR/output"; exit 1; }
  if grep -Eq '^(group delete|role (assignment|definition) delete|ad (app|sp) delete)' "$MOCK_DIR/calls.log"; then
    printf 'Deletion occurred before guard failed\n' >&2; exit 1
  fi
}
for name in setup cleanup grant-workload; do bash "$SCRIPT/$name.sh" > "$TEST_DIR/output"; done
[[ ! -e "$MOCK_DIR/calls.log" && ! -e "$BOOTSTRAP_LOCAL_DIR" ]]
pass 'previews never call Azure or write local state'
expect_block 'exact subscription' "$SCRIPT/cleanup.sh" --execute
[[ ! -s "$MOCK_DIR/calls.log" ]]
pass 'cleanup needs exact confirmation before Azure calls'
export MOCK_TENANT=wrong
expect_block 'Wrong active subscription' "$SCRIPT/setup.sh" --execute
unset MOCK_TENANT
pass 'wrong tenant rejected'
export MOCK_SCENARIO=assignment-error
if bash "$SCRIPT/setup.sh" --execute > "$TEST_DIR/output" 2>&1; then exit 1; fi
jq -e '(.assignments | length) == 1 and .principal_id != null and .provisioned != true' "$BOOTSTRAP_LOCAL_DIR/manifest.json" >/dev/null
unset MOCK_SCENARIO
pass 'interrupted setup journals assignment before failed Azure write'
bash "$SCRIPT/setup.sh" --execute > "$TEST_DIR/output"
jq -e '.provisioned == true and (.assignments | length) == 3' "$BOOTSTRAP_LOCAL_DIR/manifest.json" >/dev/null
[[ -s "$BOOTSTRAP_LOCAL_DIR/backend.hcl" && -s "$BOOTSTRAP_LOCAL_DIR/github-variables.json" ]]
grep -q staipocc38dc8cb9cf7 "$TEST_DIR/output"
jq -e '.custom_role_id == "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee"' "$BOOTSTRAP_LOCAL_DIR/manifest.json" >/dev/null
jq -e '.[0].subject == "repo:kxw9298@17515296/enterprise-ai-platform-poc@1391446926:ref:refs/heads/main"' "$MOCK_DIR/credentials.json" >/dev/null
cp "$BOOTSTRAP_LOCAL_DIR/manifest.json" "$TEST_DIR/first-manifest.json"
pass 'setup preserves resource names and records the actual Azure role ID'
: > "$MOCK_DIR/calls.log"
bash "$SCRIPT/setup.sh" --execute > "$TEST_DIR/output"
cmp "$BOOTSTRAP_LOCAL_DIR/manifest.json" "$TEST_DIR/first-manifest.json"
! grep -Eq '^(group create|storage account create|rest --method POST|ad sp create|role definition create)' "$MOCK_DIR/calls.log"
pass 'repeat setup reuses owned resources without duplicate IDs'
# Workload grant rejects missing ownership tags, then succeeds with Terraform tags.
printf '{"tags":{}}' > "$MOCK_DIR/rg-ai-platform-poc.json"
expect_block 'Workload group must carry' "$SCRIPT/grant-workload.sh" --execute
! grep -q '^role assignment create' "$MOCK_DIR/calls.log"
pass 'grant requires Terraform-owned workload group'
printf '{"tags":{"project":"enterprise-ai-platform-poc","managed-by":"terraform"}}' > "$MOCK_DIR/rg-ai-platform-poc.json"
bash "$SCRIPT/grant-workload.sh" --execute > "$TEST_DIR/output"
jq -e '(.assignments | length) == 4' "$BOOTSTRAP_LOCAL_DIR/manifest.json" >/dev/null
pass 'workload grant recorded separately'
expect_block 'Workload resource group still exists' "$SCRIPT/cleanup.sh" --execute --confirm-state-deletion "$SUB_ID"
pass 'workload group blocks cleanup'
rm "$MOCK_DIR/rg-ai-platform-poc.json"
# Ownership mismatch and API failure must not be interpreted as absent resources.
cp "$MOCK_DIR/rg-ai-platform-bootstrap.json" "$TEST_DIR/group.json"
printf '{"tags":{}}' > "$MOCK_DIR/rg-ai-platform-bootstrap.json"
expect_block 'Ownership tag mismatch' "$SCRIPT/cleanup.sh" --execute --confirm-state-deletion "$SUB_ID"
cp "$TEST_DIR/group.json" "$MOCK_DIR/rg-ai-platform-bootstrap.json"
pass 'unowned group blocks cleanup'
export MOCK_SCENARIO=api-error
: > "$MOCK_DIR/calls.log"
if bash "$SCRIPT/cleanup.sh" --execute --confirm-state-deletion "$SUB_ID" > "$TEST_DIR/output" 2>&1; then exit 1; fi
! grep -Eq '^.* delete ' "$MOCK_DIR/calls.log"
pass 'API failure stops cleanup'
unset MOCK_SCENARIO
cp "$MOCK_DIR/app.json" "$TEST_DIR/app.json"
jq '.[0].description="someone-else"' "$TEST_DIR/app.json" > "$MOCK_DIR/app.json"
expect_block 'Application ownership' "$SCRIPT/cleanup.sh" --execute --confirm-state-deletion "$SUB_ID"
cp "$TEST_DIR/app.json" "$MOCK_DIR/app.json"
pass 'unowned application blocks deletion'
cp "$MOCK_DIR/assignments.json" "$TEST_DIR/assignments.json"
jq '. + [{id:"/untracked/assignment",roleDefinitionId:"/roles/eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee"}]' \
  "$TEST_DIR/assignments.json" > "$MOCK_DIR/assignments.json"
expect_block 'untracked assignments' "$SCRIPT/cleanup.sh" --execute --confirm-state-deletion "$SUB_ID"
cp "$TEST_DIR/assignments.json" "$MOCK_DIR/assignments.json"
pass 'untracked custom-role use blocks deletion'
for scenario in extra-resource extra-container extra-blob locked managed bad-state; do
  export MOCK_SCENARIO=$scenario
  case "$scenario" in
    extra-resource) message='Unexpected resources' ;;
    extra-container) message='Unexpected storage containers' ;;
    extra-blob) message='Unexpected state/blob' ;;
    locked) message='state is locked' ;;
    managed) message='still contains managed' ;;
    bad-state) message='Unrecognized Terraform state' ;;
  esac
  expect_block "$message" "$SCRIPT/cleanup.sh" --execute --confirm-state-deletion "$SUB_ID"
  [[ -z "$(find "$BOOTSTRAP_LOCAL_DIR" -name 'state-check.*' -print)" ]]
  pass "$scenario blocks deletion; temporary state removed"
done
unset MOCK_SCENARIO
: > "$MOCK_DIR/calls.log"
bash "$SCRIPT/cleanup.sh" --execute --confirm-state-deletion "$SUB_ID" > "$TEST_DIR/output"
jq -e '.cleaned_up == true' "$BOOTSTRAP_LOCAL_DIR/manifest.json" >/dev/null
! grep '^role assignment delete' "$MOCK_DIR/calls.log" | grep -q '/containers/tfstate/'
grep -E '^(role (assignment|definition) delete|ad (sp|app) delete|group delete)' "$MOCK_DIR/calls.log" | tail -1 | grep -q '^group delete'
pass 'cleanup removes identity before storage and retains container access until group deletion'
bash "$SCRIPT/cleanup.sh" --execute --confirm-state-deletion "$SUB_ID" > "$TEST_DIR/output"
pass 'cleanup retry tolerates already-deleted resources'
printf '\n%s tests passed; all Azure calls were mocked.\n' "$passed"
