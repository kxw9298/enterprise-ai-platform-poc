# Phase 1: Copilot Studio private connectivity to Azure

This scope supersedes the earlier AKS-first milestone. The immediate success criterion is a real tool call from the Standard Copilot Studio agent's test panel to an Azure endpoint through private networking. AKS is not required for that proof.

## Target path

Copilot Studio → Power Platform delegated subnet (East US or West US) → peering → internal APIM in the East US hub → small private MCP endpoint.

Keep one Terraform root/state. Both Power Platform regional networks remain necessary for the United States environment. Keep Entra caller authentication and private DNS. No Foundry/model call, RAG, API-key cost reporting, Bastion, dedicated NAT or AKS is needed for this milestone. APIM and any runtime/telemetry still have costs; stop workloads after testing.

## Private DNS and container networking decisions

Use Azure-provided DNS on the Power Platform delegated VNets. After environment association, supported Copilot tool/connector calls execute through the delegated network and use that network's DNS configuration. This does not place the entire Copilot Studio service or the user's browser in our VNet.

| Caller | Name to resolve | Private DNS zone links required |
| --- | --- | --- |
| Power Platform runtime in either regional spoke | APIM gateway hostname → APIM private IP | Both East US and West US Power Platform VNets |
| APIM in the hub | Container App hostname → internal environment IP | Hub VNet; also workload VNet for local resolution |

The existing `infra/modules/platform/dns.tf` already creates an exact APIM-hostname zone, an apex A record and resolution-only links to hub, workload and both Power Platform VNets. Do not create a broad `azure-api.net` zone that shadows other gateways. These are prepared Terraform resources, not evidence of deployed or tested DNS.

VNet peering provides packet connectivity; private DNS zone links provide name resolution. Peering alone does not share private zones. No paid Azure DNS Private Resolver or custom DNS server is needed for this Azure-only design with Azure-provided DNS. The prepared Container Apps module now creates its environment zone/records and hub/workload links; they have not been deployed. Resolve endpoints by hostname so HTTPS certificate validation continues to work.

For the selected internal Container Apps workload-profiles environment, Azure requires a VNet and a dedicated subnet, minimum `/27`, delegated to `Microsoft.App/environments`. Reuse the workload spoke with a separate subnet; do not share the APIM, reserved AKS or Power Platform delegated subnets. Multiple apps can share one Container Apps environment. Serverless compute does not remove these networking requirements.

A container image registry is required, but ACR specifically is optional. The prepared implementation uses ACR Basic in a shared local module, independent of AKS, with managed-identity pulls and no registry passwords. This is code preparation; the registry and Container Apps have not been deployed.

References: [Power Platform VNet/DNS behavior](https://learn.microsoft.com/en-us/power-platform/admin/vnet-support-overview), [Azure Private DNS](https://learn.microsoft.com/en-us/azure/dns/private-dns-overview), [Container Apps subnet requirements](https://learn.microsoft.com/en-us/azure/container-apps/custom-virtual-networks), [supported image registries](https://learn.microsoft.com/en-us/azure/container-apps/containers).

## Current implementation boundary

- Terraform and GitHub Actions now default `enable_mcp_runtime=false`. That switch controls the preserved AKS/ACR module, not Container Apps. Explicitly opt in only for phase 2 after quota and permission review.
- Existing persistent networking still includes the unoccupied workload spoke/reserved AKS subnet. Keeping that VNet does not provision AKS or VM nodes. It can host a separate delegated Container Apps subnet later.
- Container Apps Consumption is the preferred small runtime. On 2026-09-30, explicitly approved Microsoft.App registration completed (Registered); East US managed-environment quota now reports limit 1, used 0. The earlier zero was observed before registration. Per-environment consumption-core quota and deployment capacity remain unverified. Container Instances has not been registered or rechecked.
- The APIM MCP API now selects the private Container Apps HTTPS backend for phase one. Empty `mcp_image_digest` creates the foundation only and leaves a 503 backend-not-deployed response behind caller authentication. Supplying a tested image digest enables the app. The AKS backend remains reserved for phase two.
- The caller allowlist defaults empty and denies all callers. Select the Copilot connection's Entra identity and audience before testing. Do not weaken authentication to bypass setup.
- Only Microsoft.App provider registration has been performed, with explicit approval. No RBAC changes, Power Platform association, workload provisioning or connectivity tests have occurred in this scope revision.

## Next work in order

1. Completed: register only `Microsoft.App` and recheck East US environment quota (1 allowed, 0 used). Do not apply the old AKS-specific role-delegation expansion. Verify environment compute quota and actual capacity during the subsequent deployment work.
2. Prepared: private Consumption Terraform, shared ACR, stateless MCP `get_status`, private DNS and image build/test/publish workflow. Follow the [two-stage deployment runbook](container-apps-deployment.md); the first apply does not create an app before its image exists.
3. Review a fresh complete plan and the remaining scoped permissions/provider prerequisites. Provision the phase-one stack within explicit deployment authorization.
4. Verify licensing and environment support, then associate the Power Platform environment with the enterprise network policy after reviewing the environment-wide effect and public dependencies.
5. Configure the agent's MCP connection and Entra authentication. Test from Copilot Studio itself; a call from a VM or browser alone does not prove the desired path.

## Acceptance evidence

- Copilot Studio discovers and invokes `get_status` successfully; APIM records the correlated authenticated request and the MCP service records its execution.
- Private DNS resolves the APIM and backend hostnames correctly within the applicable VNets; the gateway/backend have no public ingress path for this test.
- Missing/invalid tokens are rejected and a trusted caller succeeds. A disabled or detached private path fails as expected when it is safe to perform that test.
- Record resource IDs, request/correlation IDs, outcomes and limitations without tokens or keys. Do not label MCP discovery alone as successful tool execution.
- Review routine `down` and confirm billable workloads are removed while the environment's persistent networks/policy remain. Full destroy still requires detaching the environment first.

## Phase 2

Enable AKS when needed for agents, MCP orchestration or future self-hosted models. Review VM quota, scoped roles and private Kubernetes deployment access then. Foundry/model gateway safety and API-key token/cost attribution remain separately deferred requirements, not acceptance criteria for phase one.
