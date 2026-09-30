# Container Apps alternative to AKS

**Latest scope:** [Phase 1: Copilot Studio private connectivity](../runbooks/phase-one-private-connectivity.md). AKS/ACR is preserved for phase 2 and disabled by default; the Container Apps alternative is not yet implemented or deployed.

Status: proposed after the user requested a container-service alternative to the Free Trial AKS quota blocker. No runtime switch, provider registration or deployment has occurred. Keep the existing AKS Terraform module for future use; do not apply its current default while evaluating this alternative.

## Read-only subscription check (2026-09-29 local date)

East US, subscription `a48d0557-360a-4849-8b56-a73b28f66aa6`:

| Service | Reported limit | Provider |
| --- | --- | --- |
| AKS node VMs | 4 regional vCPUs; 4 StandardDsv7Family vCPUs | ContainerService NotRegistered at prior check |
| Container Apps | 0 managed environments | Microsoft.App NotRegistered |
| Container Instances | 100 container groups, but 0 Standard Cores | Microsoft.ContainerInstance NotRegistered |

These are observations before provider registration, not proof of final post-registration entitlement. Neither container service is currently confirmed deployable. Do not claim Container Apps automatically bypasses all Free Trial restrictions. It has its own regional environment and per-environment consumption-core quotas, separate from the AKS VM quota checked earlier.

## Preferred design, subject to quota

Use Azure Container Apps with a workload-profiles environment containing only the Consumption profile. Start with 0.25 vCPU / 0.5 GiB per replica, min 0 and max 1; expect cold starts and briefly overlapping replicas during revisions. The initial MCP should be stateless and expose Streamable HTTP on `/mcp` with a small diagnostic tool, not call an LLM.

Keep Copilot Studio → internal APIM → private MCP. Place the Container Apps environment in the existing planned workload spoke, with a dedicated `10.45.0.64/27` subnet delegated to `Microsoft.App/environments`; retain the reserved AKS subnet separately for future use. Use an internal environment load balancer and private environment DNS linked to the hub. APIM calls the app's HTTPS hostname; its existing caller authentication remains mandatory. App ingress must permit connections from outside the Container Apps *environment* so APIM can reach it, while the internal environment keeps that ingress private. Limit app ingress to the APIM subnet where supported and verify the actual source-IP behavior during testing.

No dedicated Container Apps nodes, public application endpoint, private endpoint, customer NAT gateway or DNS Resolver is proposed. Keep Foundry and admin compute disabled. APIM, monitoring and platform-managed networking can still incur charges; Consumption free grants do not make the full design free. The image source/build pipeline and immutable image selection remain to be prepared after eligibility is confirmed. Never silently substitute a generic HTTP image and describe it as a working MCP server.

Container Instances is a fallback, but its Standard Cores quota currently reports zero and its supported VNet outbound connectivity requires a NAT gateway, adding fixed cost. Container Apps is preferable for this small HTTP MCP if the subscription permits an environment.

## Next exact action

Request explicit approval to register only `Microsoft.App`, then recheck East US quota:

```bash
az provider register --subscription a48d0557-360a-4849-8b56-a73b28f66aa6 --namespace Microsoft.App
az provider show --subscription a48d0557-360a-4849-8b56-a73b28f66aa6 --namespace Microsoft.App --query registrationState -o tsv
az rest --method get --url 'https://management.azure.com/subscriptions/a48d0557-360a-4849-8b56-a73b28f66aa6/providers/Microsoft.App/locations/eastus/usages?api-version=2025-07-01'
```

The earlier automatic approval rejection covered persistent provider/RBAC mutations. This narrower registration has not been attempted as a workaround. Registration is subscription-wide but does not itself deploy a paid workload or upgrade billing. If the environment quota remains zero after registration, inspect the portal/eligibility response before rewriting and provisioning the runtime. No AKS role-delegation expansion is needed merely to register or evaluate Container Apps. Existing Power Platform registration and APIM purge prerequisites are separate and remain pending.

## References

- [Container Apps quotas](https://learn.microsoft.com/en-us/azure/container-apps/quotas)
- [VNet and delegated subnet requirements](https://learn.microsoft.com/en-us/azure/container-apps/custom-virtual-networks)
- [Consumption billing and free grants](https://learn.microsoft.com/en-us/azure/container-apps/billing)
- [Container Instances VNet egress requirement](https://learn.microsoft.com/en-us/azure/container-instances/container-instances-nat-gateway)
