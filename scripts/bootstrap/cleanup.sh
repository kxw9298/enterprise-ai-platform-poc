#!/usr/bin/env bash
# Destroy Terraform workloads first. This deletes bootstrap resources and state history.
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/common.sh"
initialize cleanup "$@"
[[ "$EXECUTE" == true ]] || exit 0

# 1. Check ALL guards before the first deletion. API errors never mean absence.
exists=$(azj group exists -n "$WORKLOAD_RG" "${SUB_ARGS[@]}")
[[ "$exists" == false ]] || fail 'Workload resource group still exists or could not be checked. Run Terraform destroy first'
bootstrap_exists=$(azj group exists -n "$BOOTSTRAP_RG" "${SUB_ARGS[@]}")
[[ "$bootstrap_exists" == true || "$bootstrap_exists" == false ]] || fail 'Invalid group existence response'
if [[ "$bootstrap_exists" == true ]]; then
  group=$(azj group show -n "$BOOTSTRAP_RG" "${SUB_ARGS[@]}")
  assert_owned "$group"
  resources=$(azj resource list -g "$BOOTSTRAP_RG" "${SUB_ARGS[@]}")
  jq -e --arg id "$STORAGE_ID" 'all(.[]; (.id | ascii_downcase) == ($id | ascii_downcase))' <<< "$resources" >/dev/null \
    || fail 'Unexpected resources in bootstrap group; refusing deletion'
  if [[ "$(jq length <<< "$resources")" != 0 ]]; then
    account=$(azj storage account show -g "$BOOTSTRAP_RG" -n "$STORAGE_NAME" "${SUB_ARGS[@]}")
    assert_owned "$account"
    containers=$(azj storage container-rm list --storage-account "$STORAGE_NAME" -g "$BOOTSTRAP_RG" "${SUB_ARGS[@]}")
    jq -e --arg name "$CONTAINER" 'all(.[]; .name == $name)' <<< "$containers" >/dev/null \
      || fail 'Unexpected storage containers; refusing deletion'
    if [[ "$(jq length <<< "$containers")" != 0 ]]; then
      blobs=$(azj storage blob list --account-name "$STORAGE_NAME" --container-name "$CONTAINER" --auth-mode login)
      jq -e --arg name "$STATE_KEY" 'all(.[]; .name == $name)' <<< "$blobs" >/dev/null \
        || fail 'Unexpected state/blob; inspect other workspaces before cleanup'
      jq -e 'all(.[]; .properties.lease.status != "locked")' <<< "$blobs" >/dev/null \
        || fail 'Terraform state is locked; stop the active operation first'
      if [[ "$(jq length <<< "$blobs")" != 0 ]]; then
        STATE_DOWNLOAD=$(mktemp "$LOCAL_DIR/state-check.XXXXXX")
        azj storage blob download --account-name "$STORAGE_NAME" --container-name "$CONTAINER" \
          --name "$STATE_KEY" --auth-mode login --file "$STATE_DOWNLOAD" --overwrite true --no-progress >/dev/null
        jq -e 'type == "object" and .version == 4 and (.resources | type == "array")' "$STATE_DOWNLOAD" >/dev/null \
          || fail 'Unrecognized Terraform state format; inspect manually'
        jq -e 'all(.resources[]; .mode != "managed" or (.instances | length) == 0)' "$STATE_DOWNLOAD" >/dev/null \
          || fail 'State still contains managed resources; run Terraform destroy first'
        rm -f -- "$STATE_DOWNLOAD"
        STATE_DOWNLOAD=''
      fi
    fi
  fi
fi
apps=$(azj ad app list --display-name "$APP_NAME")
apps=$(jq -c --arg name "$APP_NAME" '[.[] | select(.displayName == $name)]' <<< "$apps")
jq -e --arg token "$TOKEN" --slurpfile manifest "$MANIFEST" 'length <= 1 and all(.[];
  .description == $token and ($manifest[0].application_id == null or .id == $manifest[0].application_id))' <<< "$apps" >/dev/null \
  || fail 'Application ownership or ID mismatch'
roles=$(azj role definition list --name "$ROLE_NAME" "${SUB_ARGS[@]}")
jq -e --arg token "$TOKEN" 'length <= 1 and all(.[]; .description == $token)' <<< "$roles" >/dev/null \
  || fail 'Custom role ownership mismatch'
if [[ "$(jq length <<< "$roles")" == 1 ]]; then
  ROLE_ID=$(jq -er '.[0].name' <<< "$roles")
fi
assignments=$(azj role assignment list --all "${SUB_ARGS[@]}")
jq -e --arg role "/$ROLE_ID" --slurpfile manifest "$MANIFEST" \
  '($manifest[0].assignments | map(ascii_downcase)) as $known |
   all(.[] | select(.roleDefinitionId | ascii_downcase | endswith($role)); (.id | ascii_downcase) as $id | $known | index($id) != null)' \
  <<< "$assignments" >/dev/null || fail 'Custom role has untracked assignments; review manually'
# Read SP inventory before deleting anything, so Graph failures cannot cause partial cleanup.
principals='[]'
if [[ "$(jq length <<< "$apps")" == 1 ]]; then
  CLIENT_ID=$(jq -er '.[0].appId' <<< "$apps")
  principals=$(azj ad sp list --filter "appId eq '$CLIENT_ID'")
fi

# 2. Remove recorded assignments, except container access retained until storage deletion.
ids=$(jq -r --arg container "$CONTAINER_ID/" --slurpfile manifest "$MANIFEST" \
  '($manifest[0].assignments | map(ascii_downcase)) as $known |
   .[] | .id as $id | select(($known | index($id | ascii_downcase)) != null) |
   select(($id | ascii_downcase | startswith($container | ascii_downcase)) | not) | $id' <<< "$assignments")
while IFS= read -r id; do
  [[ -n "$id" ]] || continue
  azj role assignment delete --ids "$id" "${SUB_ARGS[@]}" >/dev/null
done <<< "$ids"
if [[ "$(jq length <<< "$roles")" != 0 ]]; then
  azj role definition delete --name "$ROLE_ID" "${SUB_ARGS[@]}" >/dev/null
fi

# 3. Remove service principal, application (including OIDC trust), then state storage.
ids=$(jq -r '.[].id' <<< "$principals")
while IFS= read -r id; do
  [[ -n "$id" ]] || continue
  azj ad sp delete --id "$id" >/dev/null
done <<< "$ids"
if [[ "$(jq length <<< "$apps")" == 1 ]]; then
  APP_ID=$(jq -er '.[0].id' <<< "$apps")
  azj ad app delete --id "$APP_ID" >/dev/null
fi
if [[ "$bootstrap_exists" == true ]]; then
  azj group delete -n "$BOOTSTRAP_RG" --yes "${SUB_ARGS[@]}" >/dev/null
fi
manifest_update '.cleaned_up=true'
printf 'Bootstrap deleted. Local records retained. Remove GitHub variables/workflows separately as documented.\n'
