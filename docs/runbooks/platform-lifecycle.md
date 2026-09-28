# Spin up and tear down the simplified AI platform

## Scope

Terraform prepares the infrastructure for Copilot Studio → APIM → internal MCP on AKS → APIM → Foundry, with per-client model usage reporting. It does not deploy application containers, register the Copilot agent, or prove end-to-end connectivity. No platform apply has been performed for this change. Local full plan passed with **37 to add, 0 to change, 0 to destroy** against the existing remote state. Two mocked lifecycle tests, scope/destruction guard tests and real Terraform policy-template XML rendering tests passed. None substitutes for a live apply/integration test.

| Planned infrastructure | Initial configuration |
| --- | --- |
| Network | One VNet `10.42.0.0/16`; AKS subnet `10.42.0.0/22`; APIM subnet `10.42.4.0/27`; APIM NSG and service endpoints |
| AKS | Free control-plane tier, one CPU `Standard_D2s_v7` node, Azure CNI overlay/Cilium, managed disk, managed outbound IP, Entra RBAC, local admin credentials disabled, OIDC/workload identity |
| AKS API access | Public authenticated control-plane endpoint for simple CLI/CI access; application backend is separate and internal; no node public IPs |
| Images | ACR Basic with admin credentials disabled |
| APIM | Developer tier, external VNet mode: public HTTPS ingress, private routing to MCP; no custom domain, private runner or additional VNet |
| Foundry | AIServices resource and one current project; `gpt-4.1-mini` version `2025-04-14`, GlobalStandard capacity 1; explicit blocking content filters |
| Model network access | Foundry public service endpoint restricted to the APIM subnet via service endpoint ACL, local API-key auth disabled; APIM identity gets scoped model access |
| Monitoring | Application Insights and Log Analytics; 30-day workspace retention, 1 GB/day caps, API bodies/authorization headers not logged |
| Runtime identity | Cluster/kubelet identities and two separate MCP workload identities for a two-client accounting test; scoped RBAC and service-account federation |
| APIs | MCP GET/POST/DELETE proxy, chat-completion model API, Entra validation, model token metric policy and per-request usage traces |

The first plan has 37 additions, including child API resources, role assignments and associations. AKS also creates its managed node resource group, VM scale set, disks, load balancer and outbound public IP as service-managed dependencies; they do not each appear as separate Terraform resources. No RAG, embeddings, GPU, Copilot VNet, Cosmos DB, Key Vault or enterprise hub services are included.

GlobalStandard processing is not restricted to East US. This is a synthetic-data POC choice, not a regional residency guarantee. APIM Developer and a single-node AKS cluster are POC configurations without production availability guarantees. API Management deployment/deletion can take tens of minutes; the workflow permits up to 180 minutes.

## Plan validation versus deployment readiness

Terraform planning validates provider schemas, references, current managed state and the proposed resource changes. It cannot guarantee allocation capacity, every ARM validation, policy compilation, role propagation, model eligibility or end-to-end service behavior.

Read-only checks on 2026-09-28 found:

- `gpt-4o-mini` GlobalStandard quota was zero; the selected `gpt-4.1-mini` had 200 quota units available in East US and version `2025-04-14` appeared in the model catalog. Recheck before applying.
- The initially considered `Standard_D2s_v5` was restricted. `Standard_D2s_v7` appeared without SKU restrictions. The compute usage query returned no quota rows, so sufficient regional/family core quota is **not yet verified**. Allow capacity for an upgrade surge node as well as the initial node.
- Multiple required resource providers were unregistered. None was registered by this planning task.
- The GitHub identity has Contributor on the POC group, which cannot manage the new workload role assignments or subscription-scoped deleted-service purges. No additional privileges have been granted.

Run `scripts/infra/preflight.sh` using the intended apply identity. It checks registrations and effective permission actions without changing anything. Conditional RBAC constraints, quota and name availability still need independent verification. Required providers are Network, Compute, ContainerService, ContainerRegistry, ApiManagement, CognitiveServices, OperationalInsights, Insights and ManagedIdentity.

Before apply, an administrator must register missing providers and either run Terraform locally with sufficient permissions or explicitly design scoped RBAC/purge delegation for GitHub. The workflow runs preflight before apply/down/destroy and fails before deployment if these basic prerequisites are missing. Do not grant subscription Owner to the pipeline merely to bypass the check.

## Plan locally

Use your cached `az login` session and the initialized subscription. Populate non-secret operator configuration:

```bash
export TF_VAR_publisher_email="$(az account show --query user.name -o tsv)"
export TF_VAR_aks_admin_object_id="$(az ad signed-in-user show --query id -o tsv)"
bash scripts/infra/plan.sh plan
bash scripts/infra/plan.sh down-plan
```

For a non-user CLI identity, supply the actual publisher email and intended administrator object ID explicitly. Plans are saved under ignored `.local/plans/`. The helper never applies. Inspect the plan, including any new or destructive changes, before an apply. Plan JSON contains sensitive values and must not be uploaded as an artifact or committed.

## GitHub lifecycle

The Terraform POC workflow uses two additional non-secret repository variables: `APIM_PUBLISHER_EMAIL` and `AKS_ADMIN_OBJECT_ID`.

| Operation | Effect |
| --- | --- |
| `plan` | Plan all platform resources (`enable_platform=true`) |
| `apply` | Replan and apply the reviewed commit; prerequisites must pass |
| `down-plan` | Plan removing the platform while keeping the POC group and bootstrap |
| `down` | Apply that removal after reviewed SHA and `rg-ai-platform-poc` confirmation |
| `destroy-plan` / `destroy` | Final retirement, including the POC group; confirmation required for destroy |

Use `down` between experiments and `apply` to recreate. Apply/down/destroy require the exact reviewed full commit SHA. The workflow saves/reviews/applies one plan per run rather than reusing a prior run's artifact. Replacements are rejected in normal apply; deliberately tear down and recreate for an infrastructure change that requires replacement. The allowlist names every planned resource; adding unrelated infrastructure requires a reviewed guard update.

Equivalent local apply after reviewing the helper's saved plan:

```bash
export TF_VAR_subscription_id="$(jq -r .AZURE_SUBSCRIPTION_ID .local/bootstrap/github-variables.json)"
bash scripts/infra/preflight.sh
# Run only when ready to create paid resources:
.local/tools/terraform/1.16.4/terraform -chdir=infra/poc apply ../../.local/plans/plan.tfplan
# After reviewing a newly generated down-plan:
.local/tools/terraform/1.16.4/terraform -chdir=infra/poc apply ../../.local/plans/down-plan.tfplan
```

The provider purges APIM/Foundry soft-deleted reservations and permanently deletes the Log Analytics workspace on teardown, so names can be reused. Export desired test evidence first. Purge permissions are additional to RG Contributor. If deletion partially fails, resolve the reported permission/dependency issue and rerun a fresh down plan; do not remove resources from state to conceal leftovers.

Full destroy removes the bootstrap-managed POC Contributor assignment indirectly when Azure deletes its group. Before another full spin-up, restore that group assignment using the bootstrap grant script once the group exists. Prefer `down`, which avoids this issue. Bootstrap cleanup is a separate final step and is never part of routine down.

## Application and client integration after infrastructure apply

- Build/push the MCP image and deploy it with an **internal** LoadBalancer Service at `10.42.0.10:8080` in subnet `snet-aks`; no public application service. Limit load-balancer source ranges to the APIM subnet. A Kubernetes manifest example is included in `infra/kubernetes/mcp-service.yaml`.
- The initial APIM→MCP hop is HTTP inside the VNet for synthetic tests. TLS termination at APIM does not encrypt this backend hop. Add backend TLS before using sensitive payloads. Keep the signed caller token and validate it again at the service; do not trust arbitrary `x-client-id` values arriving directly.
- Register/configure the Entra API audience (default planned URI `api://enterprise-ai-platform-poc`) and the Copilot OAuth client/consent. This app registration is an application integration prerequisite, not created by this AzureRM module. Until trusted `allowed_client_ids` are supplied, the MCP API returns 403 for everyone.
- Use Streamable HTTP MCP with Copilot Studio. This generic HTTP proxy still requires live discovery, session-header and streaming tests; Terraform planning cannot prove them. No Copilot VNet is deployed in this phase.
- Federated service accounts are `poc/mcp-client-a` and `poc/mcp-client-b`. Their corresponding managed identities can call the model gateway after the API audience is configured. They have no direct Foundry role.
- Map each authenticated application client to its intended workload route/identity. Do not switch to client A or B based on an unverified header. Two workload identities alone do not prove per-Copilot-agent attribution. Copilot clients sharing one connection identity need a separately validated distinction.

## Usage and costs

The model gateway accepts only the two workload application IDs, uses the validated token's client ID for attribution, and uses its own managed identity downstream. It emits token metrics and traces containing only usage metadata (no prompts/responses). Metrics with dimensions may require enabling the corresponding Application Insights setting; per-request traces provide the initial cost-query source independently.

The first model test intentionally rejects streaming chat requests to make accounting explicit. MCP Streamable HTTP is a separate transport and remains supported by the proxy configuration. Streaming model usage, retries and incomplete usage require a later accounting extension.

Run [model-cost-by-client.kql](../../queries/model-cost-by-client.kql) in Application Insights Logs after real test calls. Supply dated input/cached-input/output prices for the actual model/deployment; absent prices yield null estimated cost. The query counts successful usage traces, deduplicates telemetry by request ID and flags missing usage. Retried billable model calls must each retain their own gateway request ID. Reconcile failed calls, lost/capped telemetry and aggregate service usage separately.

This is estimated gateway-routed model cost. Copilot Studio credits/licenses and shared AKS/APIM/network/registry/monitoring costs are separate. Daily logging caps are not spending caps and can truncate accounting evidence. Check [Azure pricing](https://azure.microsoft.com/en-us/pricing/calculator/) for the chosen region/SKUs before apply.

## Verify teardown

After down, Terraform should retain only the POC group. Confirm its resource inventory is empty, the AKS managed node group is absent, and APIM/Foundry deleted-name reservations are purged. Check the subscription for leftover disks, public IPs or manually created resources; export usage evidence before deleting monitoring. The backend storage and pipeline identity remain and may have small residual storage costs. Down is not a promise of zero Azure bill, and stopping AKS alone would leave APIM/ACR/monitoring charges.

## Sources

- [APIM external VNet deployment](https://learn.microsoft.com/en-us/azure/api-management/api-management-using-with-vnet)
- [APIM network requirements](https://learn.microsoft.com/en-us/azure/api-management/virtual-network-reference)
- [Token metrics policy](https://learn.microsoft.com/en-us/azure/api-management/llm-emit-token-metric-policy)
- [Copilot Studio MCP connection](https://learn.microsoft.com/en-us/microsoft-copilot-studio/mcp-add-existing-server-to-agent)

## Verification evidence

- [GitHub OIDC full plan](https://github.com/kxw9298/enterprise-ai-platform-poc/actions/runs/36472208637) passed at commit `a5dfa26`: 37 additions, no changes/deletions.
- Local `down-plan` passed with no changes against the current resource-group-only state. This validates configuration and guard behavior, not deletion of a deployed stack. Live teardown remains untested.
- Read-only administrator preflight identified eight unregistered providers; effective administrator role/purge permission checks passed. GitHub remains scoped Contributor and requires a separate permission design before apply.
