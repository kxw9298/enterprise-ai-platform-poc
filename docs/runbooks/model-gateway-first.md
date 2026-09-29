# First milestone: Foundry model through internal APIM

This is the active first milestone. AKS, ACR, MCP, RAG, Copilot networking and self-hosted inference are deferred. The AKS/ACR resources, MCP gateway, subnet and related inputs/outputs are retained as commented-out Terraform for later reuse; they do not participate in the active plan. Restore them together and update the CI resource allowlist, provider preflight and client authorization before enabling that milestone. The longer-term Copilot → internal MCP objective remains, but it is not a prerequisite for testing model governance.

## What Terraform prepares

- East US, one VNet; internal APIM Developer and exact private gateway DNS.
- Foundry resource, project, `gpt-4.1-mini` model and blocking input/output content filters.
- APIM model API, managed-identity backend authentication, Application Insights and Log Analytics.
- Two user-assigned test identities, `client-a` and `client-b`, attached to a private Linux jump VM reached through Bastion Basic. No client secrets or API keys are generated.
- Per authenticated client: 10 requests/minute, 1,000 tokens/minute and 10,000 tokens/day by default. Terraform variables permit tuning these limits.
- Token usage traces and the existing per-client estimated-cost KQL query.

No AKS nodes, ACR, MCP APIs, workload federation, GPU or RAG resources are created. Bastion and the jump VM remain because APIM is internal. The optional jump NAT gateway is off by default. IMDS managed-identity token acquisition and internal APIM calls do not require the VM to have general Internet egress.

## Client ID and API audience

A **client ID identifies the caller**; the **API audience identifies the service the token was issued for**. The two managed identities are the clients. Their IDs are created by Terraform and output as `platform.test_client_ids`. APIM validates these IDs from Entra-issued tokens and overwrites caller attribution headers.

An Entra API app registration is still needed to define the token resource. This is outside the AzureRM root, just as the GitHub pipeline's Entra app is outside it. Configure it as a one-time administrator step before functional testing; do not create client secrets:

```bash
# Run only when ready to configure the API identity, not as part of terraform plan.
mkdir -p .local/model-api
umask 077
az ad app create --display-name enterprise-ai-poc-model-api \
  --sign-in-audience AzureADMyOrg > .local/model-api/application.json
model_app_id=$(jq -r .appId .local/model-api/application.json)
model_object_id=$(jq -r .id .local/model-api/application.json)
jq -n --arg uri "api://$model_app_id" \
  '{identifierUris:[$uri],api:{requestedAccessTokenVersion:2}}' > .local/model-api/update.json
az rest --method PATCH --url "https://graph.microsoft.com/v1.0/applications/$model_object_id" \
  --body @.local/model-api/update.json
az ad sp create --id "$model_app_id" --query id -o tsv
```

Run this once and retain the local record; reuse the existing app on later platform recreations. If interrupted, inspect the recorded app before retrying; do not blindly create duplicates. The app has no credential. Its service principal must permit token issuance to these managed identities; APIM remains the explicit client allowlist. A future production design can add application roles/assignment requirements.

Set `TF_VAR_api_audience` (locally) and `MODEL_API_AUDIENCE` (GitHub variable) to the **application UUID** for these v2 tokens. The token request resource is **`api://APPLICATION_UUID`**. Do not confuse these two values. The placeholder Terraform audience is only for infrastructure planning and will not enable working authentication.

The test identities receive no direct Foundry permission. APIM alone receives the model-invocation role. Both identities are attached to the same trusted test VM for convenience; this demonstrates attribution, not isolation between untrusted tenants or individual users.

## Test sequence after apply

1. Complete provider registration, scoped role/purge permissions and compute quota checks. Apply a reviewed Terraform plan. Configure the API audience as above and replan before applying that configuration change.
2. Connect through Bastion to the jump VM. Confirm the APIM hostname resolves to its private IP. A request without a valid token must fail.
3. Copy the small [test script](../../scripts/model-gateway/test-endpoint.py) to the VM through the trusted admin session. Run it with each client identity:

```bash
python3 test-endpoint.py --gateway https://APIM_NAME.azure-api.net \
  --client-id CLIENT_A_UUID --resource api://API_APPLICATION_UUID
python3 test-endpoint.py --gateway https://APIM_NAME.azure-api.net \
  --client-id CLIENT_B_UUID --resource api://API_APPLICATION_UUID
```

4. Verify two separate client IDs in usage traces. Fill in dated input/output/cached-input prices in [the cost query](../../queries/model-cost-by-client.kql). Missing prices yield null estimated cost, not zero.
5. Exercise request throttling with `--requests 12` for client A, then check client B still has its own allowance. Separately lower test token limits to a small reviewed value to verify token-rate/quota enforcement. Request/token rate limits should return 429; exhausted token quota returns 403. Record actual outcomes rather than assume policy deployment proves enforcement.
6. Use a small approved synthetic safety evaluation set: benign input succeeds; disallowed input is filtered; verify completion-side filtering as well. Foundry's model policy supplies the initial safety layer. A separate Content Safety resource is not needed for this first test.
7. Verify an unauthorized identity fails and spoofing `x-client-id` does not change attribution. Reconcile token usage with gateway/model telemetry and account for missing/error traces.
8. Export evidence, run `down-plan`, then `down` to remove paid resources. The one-time Entra API registration persists for reuse; on final retirement delete only its recorded app object with `az ad app delete --id APP_OBJECT_UUID` and verify the associated enterprise application is removed.

The initial model API rejects streaming to keep token accounting explicit. Limits use actual token counts after responses (`estimate-prompt-tokens=false`); a current/in-flight request may cross the configured token threshold before subsequent requests are blocked. These policies are not an exact dollar spending cap. Model availability, quotas, APIM policy execution and safety behavior require live tests after deployment.

## Current verification

Terraform schema validation and three mocked lifecycle tests passed locally. Model policy template rendering checks verify authentication, token telemetry and both rate-limit policies. No API registration, model deployment or authenticated endpoint call has been executed for this milestone yet. The local Azure-backed plan on 2026-09-28 passed the scope guard: **31 to add, 0 to change, 0 to destroy**, with the existing resource group unchanged. Saved plans remain local and ignored. The older 37-resource AKS plan is historical.

## References

- [APIM request rate limiting](https://learn.microsoft.com/en-us/azure/api-management/rate-limit-by-key-policy)
- [APIM LLM token limits](https://learn.microsoft.com/en-us/azure/api-management/llm-token-limit-policy)
