#!/usr/bin/env bash
# Test double only. Never delegates to the installed Azure CLI.
set -euo pipefail
printf '%s\n' "$*" >> "$MOCK_DIR/calls.log"
option() {
  local key=$1; shift
  while [[ $# -gt 0 ]]; do
    if [[ "$1" == "$key" ]]; then printf '%s' "$2"; return; fi
    shift
  done
  return 1
}
read_array() { if [[ -f "$MOCK_DIR/$1" ]]; then cat "$MOCK_DIR/$1"; else printf '[]\n'; fi; }
if [[ "${MOCK_SCENARIO:-}" == api-error && "$1 $2" == 'group exists' ]]; then exit 42; fi
if [[ "${MOCK_SCENARIO:-}" == assignment-error && "$1 $2 ${3:-}" == 'role assignment create' ]]; then exit 42; fi
case "$1 $2 ${3:-}" in
  'account show '*)
    jq -n --arg sub "$SUB_ID" --arg tenant "${MOCK_TENANT:-$TENANT}" '{id:$sub,tenantId:$tenant,state:"Enabled"}' ;;
  'ad signed-in-user show') printf '{"id":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"}\n' ;;
  'group exists '*)
    name=$(option -n "$@")
    if [[ -f "$MOCK_DIR/$name.json" ]]; then printf 'true\n'; else printf 'false\n'; fi ;;
  'group show '*) cat "$MOCK_DIR/$(option -n "$@").json" ;;
  'group create '*)
    token=''
    for arg in "$@"; do case "$arg" in bootstrap-id=*) token=${arg#*=};; esac; done
    jq -n --arg token "$token" '{tags:{"bootstrap-id":$token}}' > "$MOCK_DIR/$(option -n "$@").json"
    printf '{}\n' ;;
  'group delete '*) rm -f "$MOCK_DIR/$(option -n "$@").json"; printf '{}\n' ;;
  'storage account list') read_array storage.json ;;
  'storage account show') jq '.[0]' "$MOCK_DIR/storage.json" ;;
  'storage account create')
    token=''
    for arg in "$@"; do case "$arg" in bootstrap-id=*) token=${arg#*=};; esac; done
    jq -n --arg token "$token" --arg name "$(option -n "$@")" \
      '[{name:$name,tags:{"bootstrap-id":$token},allowSharedKeyAccess:false,allowBlobPublicAccess:false}]' > "$MOCK_DIR/storage.json"
    printf '{}\n' ;;
  'storage account blob-service-properties') printf '{}\n' ;;
  'storage container-rm create') printf '{}\n' ;;
  'storage container-rm list')
    if [[ "${MOCK_SCENARIO:-}" == extra-container ]]; then printf '[{"name":"other"}]\n'; else printf '[{"name":"tfstate"}]\n'; fi ;;
  'storage blob list')
    case "${MOCK_SCENARIO:-}" in
      extra-blob) printf '[{"name":"other.tfstate"}]\n' ;;
      locked) printf '[{"name":"poc.tfstate","properties":{"lease":{"status":"locked"}}}]\n' ;;
      *) printf '[{"name":"poc.tfstate"}]\n' ;;
    esac ;;
  'storage blob download')
    case "${MOCK_SCENARIO:-}" in
      managed) printf '{"version":4,"resources":[{"mode":"managed","instances":[{}]}]}' ;;
      bad-state) printf 'not valid json' ;;
      *) printf '{"version":4,"resources":[]}' ;;
    esac > "$(option --file "$@")"
    printf '{}\n' ;;
  'resource list '*)
    if [[ "${MOCK_SCENARIO:-}" == extra-resource ]]; then
      printf '[{"id":"unexpected"}]\n'
    else
      jq -n --arg id "$STORAGE_RESOURCE_ID" '[{id:$id}]'
    fi ;;
  'ad app list') read_array app.json ;;
  'rest --method POST')
    [[ "$(option --url "$@")" == https://graph.microsoft.com/v1.0/applications ]] || exit 90
    jq -n --argjson body "$(option --body "$@")" \
      '[$body + {id:"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",appId:"cccccccc-cccc-cccc-cccc-cccccccccccc"}]' > "$MOCK_DIR/app.json"
    jq '.[0]' "$MOCK_DIR/app.json" ;;
  'ad app delete') printf '[]\n' > "$MOCK_DIR/app.json"; printf '{}\n' ;;
  'ad app federated-credential')
    case "$4" in
      list) read_array credentials.json ;;
      create) jq -n --argjson value "$(option --parameters "$@")" '[$value]' > "$MOCK_DIR/credentials.json"; printf '{}\n' ;;
      *) exit 90 ;;
    esac ;;
  'ad sp list') read_array principal.json ;;
  'ad sp create') printf '[{"id":"dddddddd-dddd-dddd-dddd-dddddddddddd"}]' > "$MOCK_DIR/principal.json"; jq '.[0]' "$MOCK_DIR/principal.json" ;;
  'ad sp delete') printf '[]\n' > "$MOCK_DIR/principal.json"; printf '{}\n' ;;
  'role definition list') read_array role.json ;;
  'role definition create')
    jq -n --argjson role "$(option --role-definition "$@")" \
      '[$role | {name:"eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee",description:.Description, assignableScopes:.AssignableScopes,
      permissions:[{actions:.Actions,notActions:[],dataActions:[],notDataActions:[],condition:null,conditionVersion:null}]}]' > "$MOCK_DIR/role.json"
    jq '.[0]' "$MOCK_DIR/role.json" ;;
  'role definition delete') printf '[]\n' > "$MOCK_DIR/role.json"; printf '{}\n' ;;
  'role assignment list') read_array assignments.json ;;
  'role assignment create')
    id="$(option --scope "$@")/providers/Microsoft.Authorization/roleAssignments/$(option --name "$@")"
    role=$(option --role "$@")
    read_array assignments.json | jq --arg id "$id" --arg role "$role" \
      '. + [{id:$id,roleDefinitionId:("/roles/"+$role)}] | unique_by(.id)' > "$MOCK_DIR/assignments.tmp"
    mv "$MOCK_DIR/assignments.tmp" "$MOCK_DIR/assignments.json"
    printf '{}\n' ;;
  'role assignment delete')
    jq --arg id "$(option --ids "$@")" 'map(select(.id != $id))' "$MOCK_DIR/assignments.json" > "$MOCK_DIR/assignments.tmp"
    mv "$MOCK_DIR/assignments.tmp" "$MOCK_DIR/assignments.json"; printf '{}\n' ;;
  *) printf 'Unhandled mock command: %s\n' "$*" >&2; exit 99 ;;
esac
