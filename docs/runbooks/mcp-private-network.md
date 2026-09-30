# Private MCP connectivity: current Terraform design

**Latest scope:** [Phase 1: Copilot Studio private connectivity](phase-one-private-connectivity.md). AKS/ACR is preserved for phase 2 and disabled by default; the Container Apps alternative is not yet implemented or deployed.

This supersedes the separate Power Platform root and the older model-first topology. Code preparation only; do not equate validation with deployment or a working MCP application.

## One root, one state

Run `infra/poc` using the existing `poc.tfstate` backend and default Terraform workspace. The retired `infra/power-platform` root is retained as comments, not a second owner of resources. No standalone integration state was applied during its preparation; verify this is still true before deployment.

| Local module | Default | Routine down |
| --- | --- | --- |
| `network` | On: hub, three spokes, six peering directions, enterprise policy | Retained |
| `platform` | On: internal APIM Developer, MCP API, private DNS, telemetry | Removed |
| `mcp_runtime` | Off: retained two-node AKS Free tier, ACR Basic, identities/RBAC for phase 2 | Removed if enabled |
| `platform.foundry` | Off (`enable_foundry=false`): original Foundry/model/filter/API code retained | Removed if enabled |
| `admin_access` | Off (`enable_admin_access=false`): original Bastion/jump VM code retained | Removed if enabled |

`enable_platform=false` overrides all workload switches. Do not enable optional features during teardown. API-key reporting remains a deferred user requirement; the MCP policy currently validates Entra tokens and denies all callers until `allowed_client_ids` is configured. The model module is also retained with its original token-based attribution.

## Topology and sizes

| VNet | Region | Address range | Subnet |
| --- | --- | --- | --- |
| Hub (existing name preserved) | East US | `10.42.0.0/21` | APIM `10.42.4.0/27` |
| AKS spoke | East US | `10.45.0.0/24` | Nodes/internal MCP LB `10.45.0.0/26` |
| Power Platform spoke | East US | `10.43.0.0/26` | Delegated `10.43.0.0/26` |
| Power Platform spoke | West US | `10.44.0.0/26` | Delegated `10.44.0.0/26` |

Hub /21 preserves the existing APIM subnet and optional admin addresses without renumbering: optional admin `10.42.5.0/27`, Bastion `10.42.6.0/26`. CIDR size itself does not incur an address reservation charge. Each Power Platform /26 has 59 usable addresses: enough for Microsoft's typical 25–30-container environment guidance without the old /16 VNet allocation. Review actual capacity and overlap before association; delegated ranges cannot be changed while in use.

Each spoke peers bidirectionally with the hub; West US uses global peering. No spoke-to-spoke transit or network appliance is configured. Copilot connects to APIM in the hub; APIM creates a separate backend connection to the AKS internal load balancer at `10.45.0.10:8080`. APIM HTTPS DNS is linked to all four VNets with autoregistration off. No paid DNS Resolver, Firewall, VPN, ExpressRoute or NAT gateway is enabled by default. Power Platform connector public-endpoint dependencies still require review before association.

AKS uses two `Standard_D4s_v7` system nodes (4 vCPUs each), following the current system-pool minimum of two nodes, 32-GB managed OS disk, max 30 pods, CNI Overlay pod range `10.244.0.0/22` and service range `10.250.0.0/24`. This is a non-HA POC, not a production recommendation. Recheck regional availability and cost; no claim this SKU is universally cheapest. Its managed OS disk can incur premium-storage charges. Default AKS upgrade surge of one needs another four vCPUs; the last observed four-core subscription quota is insufficient for the eight-core baseline or twelve-core surge total. Resolve before deployment/upgrade rather than suppressing maintenance. Public Standard LB outbound SNAT handles image/platform egress; MCP ingress stays internal.

The Kubernetes API is private. Terraform creates Azure resources through ARM and does not install Kubernetes objects. A later application deployment job needs private connectivity and AKS RBAC (for example an ephemeral in-VNet runner). Ordinary GitHub-hosted runners cannot directly access that private API. The canonical service example is `infra/kubernetes/mcp-service.yaml`; an application Deployment/image/build workflow is still needed. ACR is Basic with Entra authentication, not private-link registry networking.

## Foundry cost and enablement

The existing unfine-tuned `gpt-4.1-mini` GlobalStandard deployment is pay-per-token, not idle provisioned-throughput billing. This does not make all Foundry-associated services free; telemetry, compute and other resource types have independent charges. No model calls are necessary for a `get_status` MCP connectivity test, so the whole local module defaults off. Its original code is retained, not deleted/commented piecemeal.

To include it later, pass `-var=enable_foundry=true` or select `enable_foundry` in the workflow. Replan before applying. Moving live older Foundry/admin resources into these new modules would require additional state moves: this revision assumes the documented completed workload teardown. The normal guard rejects accidental deletions/replacements; do not bypass it if actual state differs.

## Migration and readiness

Root `moved.tf` maps the four surviving hub resources from `module.platform[0]` into `module.network`, preserving state ownership without manual state edits. The hub address space contracts from /16 to /21; verify no untracked subnets, addresses or peerings depend on removed space. Inspect the first plan, including any moved addresses and updates. Do not reuse an old saved plan.

The persistent network has new resources, so the FIRST reviewed normal apply must establish it. A down plan immediately against pre-migration state can show network additions and will intentionally fail the teardown guard. After migration, routine down permits only workload deletes/no-ops and requires network no-op.

Before deployment:
- Register Microsoft.PowerPlatform, ContainerService and ContainerRegistry in addition to the earlier providers. No registrations or new grants were performed in this code-only revision.
- Correct the existing APIM purge role's missing `Microsoft.ApiManagement/locations/deletedServices/read` from the last teardown.
- Extend the pipeline's conditioned role delegation deliberately for AKS Network Contributor, Managed Identity Operator and AcrPull; optional operator access uses AKS RBAC Cluster Admin. Existing gateway-only delegation is insufficient. The generic preflight action check cannot prove a condition permits each new role. Review effective permissions before any apply; do not grant Owner to bypass this.
- Check node-family, regional CPU and surge quota, model quota only if enabled, and provider/SKU availability.
- Configure the appropriate Entra caller allowlist and token audience for Copilot's chosen MCP connection. Runtime auth and protocol compatibility remain unverified.

## Environment association and teardown

Environment: `Default-eb241c67-e72d-4862-ae41-7686706624c4`, United States, Default type. The user reports Dataverse and Managed Environments enabled. A trial license is distinct from a Trial environment: Microsoft lists Default as VNet-supported but Trial environment type as unsupported. Validate trial entitlement separately.

The enterprise policy does NOT itself associate the Power Platform environment. After network/auth/application readiness, link it in the admin center or with Microsoft's `Enable-SubnetInjection`. It affects supported workloads across the environment; review public dependencies first. No association is performed by Terraform or this change.

- **Routine cost stop:** review `down-plan`, run `down` with exact reviewed SHA and resource-group confirmation. Networking/policy stay; APIM/AKS/ACR/monitoring and optional Foundry/admin resources are removed. Remove/export any desired application data and telemetry first.
- **Full retirement:** first `Disable-SubnetInjection -EnvironmentId "Default-eb241c67-e72d-4862-ae41-7686706624c4"` and verify completion. Review `destroy-plan`, then `destroy` with `power_platform_detached=true`, reviewed SHA and confirmation. The boolean is an operator attestation, not an automated disassociation or verification. Local Terraform users must perform this same check manually.
- Bootstrap, Entra API registration and prerequisite custom roles remain outside Terraform and need separately documented cleanup. Do not delete state storage before teardown succeeds. Check for the previously noted orphan monitoring action group before full group deletion.

## Sources

- [Power Platform regions, subnet sizing and environment support](https://learn.microsoft.com/en-us/power-platform/admin/vnet-support-overview)
- [Environment association and disassociation](https://learn.microsoft.com/en-us/power-platform/admin/vnet-support-setup-configure)
- [AKS system pool sizing](https://learn.microsoft.com/en-us/azure/aks/use-system-pools)
- [Foundry deployment billing models](https://learn.microsoft.com/en-us/azure/ai-foundry/foundry-models/concepts/deployment-types)

## Verification of this revision

On 2026-09-29, Terraform schema validation and five mocked lifecycle tests passed, including default Foundry-off, optional Foundry-on and workload-down behavior. Rendered policy and scope-guard tests passed. A fresh Azure-backed plan against the existing state passed the scope guard: **37 additions, 1 update, 0 destroys**. The update contracts the existing hub address space in place; moved blocks preserve its four existing Terraform resource identities. The plan confirms four VNets, six peering directions, four private DNS links, two 4-vCPU AKS nodes, no optional paid admin/NAT and no Foundry. Saved plans/logs remain ignored locally. No apply or Power Platform association occurred. This count is unrelated to the older 37-resource AKS plan from the model-first design.

## Prerequisite check: 2026-09-29

Live checks found FreeTrial_2014-09-01 with spending limit On, East US total regional vCPUs 0/4 and StandardDsv7Family 0/4. AKS requires 8 base / 12 including surge. No quota request or billing upgrade was made. Free Trial subscriptions cannot request quota increases: the account owner must decide whether to upgrade to pay-as-you-go, then request both East US limits at least 12. Upgrading changes billing exposure; review remaining credit and spending behavior in the portal. See [Microsoft subscription limits](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/azure-subscription-service-limits) and [upgrade instructions](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/upgrade-azure-subscription).

The three new providers were NotRegistered. Existing role delegation still permits only the two model-gateway roles, and the APIM purge read action is still missing. `scripts/bootstrap/prepare-mcp.py` reviews a narrow update to those existing resources:

```bash
python3 scripts/bootstrap/prepare-mcp.py \
  --subscription a48d0557-360a-4849-8b56-a73b28f66aa6 \
  --pipeline-object-id 124dede3-5033-431e-b267-9ef7e8eaeddf
# After explicit approval of the changes, repeat with --apply.
```

The update registers ContainerService, ContainerRegistry and PowerPlatform; extends the existing delegation to Network Contributor, Managed Identity Operator and AcrPull for ServicePrincipal recipients only within `rg-ai-platform-poc`; and adds the missing location-scoped APIM read action to the existing subscription purge role. It does not add AKS administrator delegation, billing changes, quota changes, environment association or workload resources. The scope permits these roles for any service principal in the workload group, not just one future AKS identity.

Automatic approval review blocked execution pending explicit approval of these persistent account/security changes. Only review mode has run successfully. No provider or RBAC mutations occurred. The script checks existing scopes and conditions, retains assignment IDs, and saves before/after records under ignored `.local/deployment-prerequisites/mcp-update/` on execution. Existing role assignments automatically reference an updated custom role definition; allow propagation rather than deleting/recreating them. Cleanup still follows the recorded exact assignment IDs and definitions in the deployment checkpoint. Provider registration is subscription-wide and is not automatically undone, because other workloads may use it.

GitHub OIDC [plan 36652580935](https://github.com/kxw9298/enterprise-ai-platform-poc/actions/runs/36652580935) passed at infrastructure commit `62b2767`. This verifies planning with the pipeline identity, not permission to create the new role assignments or available compute quota. Five prerequisite-script tests passed locally; run `python3 tests/bootstrap/test_mcp_prerequisites.py` to repeat them.
