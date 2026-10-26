# AI platform phase: model gateway

Latest live validation: the model gateway has been provisioned and tested. See
[runtime validation](ai-platform-validation.md) for successful authentication,
client-limit isolation, quota enforcement, rotation, token attribution and dated
cost estimates. Earlier preparation-only statements below describe the original
profile boundary, not the latest deployment status.

Copilot Studio private HTTP connectivity was validated on 2026-10-02. Further
Copilot, MCP, Container Apps and AKS work is paused while the model gateway is
prepared. Preserve their code and existing network configuration.

## First increment: review and plan

Use the explicit profile `infra/profiles/ai-platform.tfvars`: internal APIM,
Foundry account/project/model, blocking content filters, APIM managed identity,
Log Analytics and Application Insights. Container Apps, ACR, AKS, Bastion and
the jump VM are disabled. Persistent network resources remain in the same state.

```bash
export TF_VAR_publisher_email='<publisher email>'
export TF_VAR_api_audience='<existing model API application UUID>'
bash scripts/infra/plan.sh ai-plan
```

Plans and state stay ignored in `.local`; the command never applies. Inspect
deletions carefully if a previous runtime is still deployed. GitHub's equivalent
plan uses `enable_foundry=true`, `enable_container_apps=false`, and
`enable_mcp_runtime=false`. Apply must use the same inputs and reviewed commit.

## Existing implementation and gaps

- Model API still requires Entra tokens from the two managed test identities.
  APIM authenticates to Foundry with its managed identity; local account keys are
  disabled. Model calls also require an active API-scoped APIM subscription key.
- Prepared subscriptions `model-client-a` and `model-client-b` are each bound in
  policy to the corresponding managed identity. A valid key with the other
  client's Entra token is rejected. Request/token limits and cost aggregation use
  the validated subscription ID. Primary/secondary keys share attribution.
- Foundry uses a public service endpoint restricted to the APIM subnet through
  a Cognitive Services service endpoint and deny-by-default network ACLs. This
  is not a Foundry private endpoint.
- The retained model is `gpt-4.1-mini`, version `2025-04-14`, GlobalStandard,
  capacity 1. Recheck availability, model lifecycle and quota before apply.
  GlobalStandard does not guarantee single-region processing.
- APIM is internal. No test VM is enabled by this profile: select an authorized
  in-VNet execution path before provisioning for runtime testing.
- Existing successful model calls are historical evidence, not validation of
  this new deployment. A plan does not prove capacity or runtime policy behavior.

## Next increments and acceptance

1. Review the prepared API subscriptions, Entra-to-subscription bindings and
   subscription-based counters/telemetry/query before deploying. These changes
   have not been runtime-tested. Generated keys are sensitive and held in remote
   Terraform state; never export state, plans or key values to Git or CI logs.
2. Test clients A/B, missing/invalid credentials, key rotation, spoofed headers,
   request and token limits, blocked content, missing usage and non-streaming
   accounting. Reconcile model usage against backend telemetry.
3. Populate dated model prices for estimated costs. Shared infrastructure costs
   and invoices remain separate; missing usage/prices must not appear as $0.
4. Review a fresh plan and private test access before requesting provisioning.
   Teardown afterward using the existing down-plan/down runbook. Bootstrap and
   persistent networking survive down; no automatic deployment is authorized here.

## Private test access and key handling

The approved profile keeps Bastion/VMs off. Before apply, select an existing
authorized VNet host or review a separate plan enabling the retained admin-access
module. That module attaches the two model test identities to a private VM and
creates billable Bastion access. Hosted GitHub runners cannot call internal APIM.
No access resources or extra grants are created by this preparation.

For the explicit temporary access plan, run `bash scripts/infra/plan.sh ai-access-plan`.
This enables Bastion Basic plus a two-vCPU private VM and attaches both model
test identities, without NAT or public VM IP. Bastion, its public IP and the VM
remain billable while provisioned; VM deallocation does not stop Bastion billing.
GitHub plan/apply inputs: `enable_admin_access=true`, `enable_foundry=true`,
`enable_container_apps=false`, `enable_mcp_runtime=false`. Keep those inputs
identical between reviewed plan and apply.

After provisioning, an authorized administrator retrieves each subscription key
from APIM's Subscriptions blade and transfers it securely to the test host. Read
it without echo and use the existing script; never put the key in shell history:

```bash
read -r -s -p 'Model subscription key: ' MODEL_SUBSCRIPTION_KEY
export MODEL_SUBSCRIPTION_KEY
python3 scripts/model-gateway/test-endpoint.py \
  --gateway https://APIM_NAME.azure-api.net \
  --client-id CLIENT_A_MANAGED_IDENTITY_UUID --resource api://API_APP_UUID
unset MODEL_SUBSCRIPTION_KEY
```

Run A with A's key and B with B's key; swapping keys must return 403. Missing or
invalid keys must fail authentication. Rotate keys in APIM and confirm the same
subscription ID remains in usage reporting. Use header keys, not query-string
keys (request URLs may be logged). Model policy removes subscription credentials
before forwarding. Diagnostics do not collect bodies or subscription headers.
Cost query excludes legacy rows without a subscription ID; never mix historical
Entra-only totals with new subscription totals without explicit migration.

References: [APIM subscriptions](https://learn.microsoft.com/en-us/azure/api-management/api-management-howto-create-subscriptions)
and [Terraform API subscriptions](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/api_management_subscription).
