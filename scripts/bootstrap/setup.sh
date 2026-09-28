#!/usr/bin/env bash
# Bootstrap the state backend and GitHub identity, outside Terraform ownership.
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/common.sh"
initialize provision "$@"
[[ "$EXECUTE" == true ]] || exit 0

# 1. Dedicated bootstrap resource group and Entra-only state storage.
exists=$(azj group exists -n "$BOOTSTRAP_RG" "${SUB_ARGS[@]}")
case "$exists" in
  true) group=$(azj group show -n "$BOOTSTRAP_RG" "${SUB_ARGS[@]}"); assert_owned "$group" ;;
  false) azj group create -n "$BOOTSTRAP_RG" -l "$LOCATION" --tags "bootstrap-id=$TOKEN" \
    project=enterprise-ai-platform-poc managed-by=bootstrap-cli "${SUB_ARGS[@]}" >/dev/null ;;
  *) fail 'Invalid group existence response' ;;
esac
accounts=$(azj storage account list -g "$BOOTSTRAP_RG" "${SUB_ARGS[@]}")
account=$(jq -c --arg name "$STORAGE_NAME" '.[] | select(.name == $name)' <<< "$accounts")
if [[ -n "$account" ]]; then
  assert_owned "$account"
  jq -e '.allowSharedKeyAccess == false and .allowBlobPublicAccess == false' <<< "$account" >/dev/null \
    || fail 'Storage authentication settings drifted; review before rerunning'
else
  azj storage account create -g "$BOOTSTRAP_RG" -n "$STORAGE_NAME" -l "$LOCATION" \
    --sku Standard_LRS --kind StorageV2 --https-only true --min-tls-version TLS1_2 \
    --allow-blob-public-access false --allow-shared-key-access false --public-network-access Enabled \
    --tags "bootstrap-id=$TOKEN" project=enterprise-ai-platform-poc managed-by=bootstrap-cli "${SUB_ARGS[@]}" >/dev/null
fi
azj storage account blob-service-properties update -g "$BOOTSTRAP_RG" --account-name "$STORAGE_NAME" \
  --enable-versioning true --enable-delete-retention true --delete-retention-days 7 "${SUB_ARGS[@]}" >/dev/null
azj storage container-rm create -g "$BOOTSTRAP_RG" --storage-account "$STORAGE_NAME" \
  -n "$CONTAINER" --public-access off "${SUB_ARGS[@]}" >/dev/null

# 2. App registration and service principal; no client secret is generated.
apps=$(azj ad app list --display-name "$APP_NAME")
apps=$(jq -c --arg name "$APP_NAME" '[.[] | select(.displayName == $name)]' <<< "$apps")
case "$(jq length <<< "$apps")" in
  0) app=$(azj ad app create --display-name "$APP_NAME" --description "$TOKEN" --sign-in-audience AzureADMyOrg) ;;
  1) app=$(jq -c '.[0]' <<< "$apps")
     jq -e --arg token "$TOKEN" '.description == $token' <<< "$app" >/dev/null || fail 'Application ownership mismatch' ;;
  *) fail 'Multiple applications match; resolve manually' ;;
esac
APP_ID=$(jq -er .id <<< "$app")
CLIENT_ID=$(jq -er .appId <<< "$app")
manifest_update --arg app "$APP_ID" --arg client "$CLIENT_ID" '.application_id=$app | .client_id=$client'
principals=$(azj ad sp list --filter "appId eq '$CLIENT_ID'")
case "$(jq length <<< "$principals")" in
  0) principal=$(azj ad sp create --id "$CLIENT_ID") ;;
  1) principal=$(jq -c '.[0]' <<< "$principals") ;;
  *) fail 'Multiple service principals match; resolve manually' ;;
esac
PRINCIPAL_ID=$(jq -er .id <<< "$principal")
manifest_update --arg principal "$PRINCIPAL_ID" '.principal_id=$principal'

# 3. OIDC trust for this repository's main branch only.
credential=$(jq -nc --arg subject "$SUBJECT" '{name:"github-main", issuer:"https://token.actions.githubusercontent.com",
  subject:$subject, audiences:["api://AzureADTokenExchange"]}')
credentials=$(azj ad app federated-credential list --id "$APP_ID")
existing=$(jq -c '.[] | select(.name == "github-main")' <<< "$credentials")
if [[ -n "$existing" ]]; then
  jq -e --argjson wanted "$credential" '{name,issuer,subject,audiences} == $wanted' <<< "$existing" >/dev/null \
    || fail 'Existing federation differs; review manually'
else
  azj ad app federated-credential create --id "$APP_ID" --parameters "$credential" >/dev/null
fi

# 4. Minimal subscription permissions to create the Terraform-owned POC group.
role=$(jq -nc --arg name "$ROLE_NAME" --arg id "$ROLE_ID" --arg token "$TOKEN" --arg scope "$SUB_SCOPE" \
  '{Name:$name, Id:$id, IsCustom:true, Description:$token,
    Actions:["Microsoft.Resources/subscriptions/resourceGroups/read", "Microsoft.Resources/subscriptions/resourceGroups/write",
      "Microsoft.Resources/subscriptions/read", "Microsoft.Resources/subscriptions/providers/read", "Microsoft.Resources/subscriptions/locations/read"],
    NotActions:[], DataActions:[], NotDataActions:[], AssignableScopes:[$scope]}')
roles=$(azj role definition list --name "$ROLE_ID" "${SUB_ARGS[@]}")
if [[ "$(jq length <<< "$roles")" == 0 ]]; then
  azj role definition create --role-definition "$role" "${SUB_ARGS[@]}" >/dev/null
else
  jq -e --argjson wanted "$role" 'length == 1 and .[0].description == $wanted.Description and
    .[0].assignableScopes == $wanted.AssignableScopes and
    .[0].permissions == [{actions:$wanted.Actions, notActions:[], dataActions:[], notDataActions:[]}]' <<< "$roles" >/dev/null \
    || fail 'Custom role ownership or permissions drifted; review manually'
fi
assign_role "$PRINCIPAL_ID" "$ROLE_ID" "$SUB_SCOPE" ServicePrincipal
assign_role "$PRINCIPAL_ID" "$BLOB_ROLE" "$CONTAINER_ID" ServicePrincipal
assign_role "$OPERATOR_ID" "$BLOB_ROLE" "$CONTAINER_ID" User

# 5. Local non-secret outputs for Terraform and the future GitHub workflow.
jq -n --arg storage "$STORAGE_NAME" --arg container "$CONTAINER" --arg key "$STATE_KEY" --arg tenant "$TENANT_ID" \
  '{storage_account_name:$storage, container_name:$container, key:$key, tenant_id:$tenant, use_azuread_auth:true}' |
  jq -r 'to_entries[] | "\(.key) = \(.value | tojson)"' > "$LOCAL_DIR/backend.hcl"
jq -n --arg client "$CLIENT_ID" --arg tenant "$TENANT_ID" --arg sub "$SUBSCRIPTION_ID" \
  --arg storage "$STORAGE_NAME" --arg container "$CONTAINER" --arg key "$STATE_KEY" \
  '{AZURE_CLIENT_ID:$client, AZURE_TENANT_ID:$tenant, AZURE_SUBSCRIPTION_ID:$sub,
    TF_STATE_STORAGE_ACCOUNT:$storage, TF_STATE_CONTAINER:$container, TF_STATE_KEY:$key}' > "$LOCAL_DIR/github-variables.json"
manifest_update '.provisioned=true'
printf 'Bootstrap complete. Outputs: %s\nNo GitHub settings changed. RBAC propagation may take several minutes.\n' "$LOCAL_DIR"
