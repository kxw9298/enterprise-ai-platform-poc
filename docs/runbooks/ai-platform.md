# AI platform phase: model gateway

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
  disabled. Subscription keys are not currently required.
- Current request/token limits and telemetry use Entra client IDs. API-key
  attribution is a subsequent increment, not a capability of this profile.
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

1. Add one APIM subscription per reporting client; retain Entra validation and
   attribute usage to the validated subscription ID, never the raw key. Update
   subscription resources, rate/token counters, telemetry, KQL and tests together.
   Decide and test client-to-subscription authorization before deployment.
2. Test clients A/B, missing/invalid credentials, key rotation, spoofed headers,
   request and token limits, blocked content, missing usage and non-streaming
   accounting. Reconcile model usage against backend telemetry.
3. Populate dated model prices for estimated costs. Shared infrastructure costs
   and invoices remain separate; missing usage/prices must not appear as $0.
4. Review a fresh plan and private test access before requesting provisioning.
   Teardown afterward using the existing down-plan/down runbook. Bootstrap and
   persistent networking survive down; no automatic deployment is authorized here.
