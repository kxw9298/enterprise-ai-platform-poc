# Single-region POC cost review

**Current first milestone:** [Foundry + internal APIM model gateway](../runbooks/model-gateway-first.md), with two secretless test-client IDs, content filtering, request/token limits and per-client cost reporting. AKS/ACR/MCP are removed from the active Terraform root and deferred. Earlier AKS inventory and plan evidence below are historical; this milestone supersedes that sequence.

User direction: preserve enterprise-style internal APIM access, use non-premium tiers where possible, and keep one region. This review prepares configuration; it is not a price quote or proof of available VM capacity.

| Component | Default | Cost decision |
| --- | --- | --- |
| Region | East US only | No multi-region deployments, replicas or cross-region network services |
| APIM | Developer, one unit, Internal mode | Supports the required internal VNet topology without Premium; still bills while idle |
| Bastion | Basic | Lowest dedicated tier for this region; browser SSH is enough, so Standard/Premium tunneling features are unnecessary |
| Jump VM | One Linux VM, Standard LRS OS disk | No Windows licensing or premium OS disk. Independent size variable; D2s_v7 retained because earlier inventory showed no restriction. Smaller burstable SKU availability remains unverified |
| Admin Internet egress | Disabled by default | Avoid NAT gateway and its public IP; enable only for online updates, package installs or OAuth tooling |
| Model | One small GlobalStandard deployment | Usage-based model calls; no provisioned throughput; global processing is not a single-region residency guarantee |
| Monitoring | 30-day workspace retention, capped ingestion | Preserve token accounting; no paid container-insights add-on. Caps can drop evidence and are not spending caps |
| Deferred | AKS, ACR, MCP, RAG, GPU, Copilot VNet, firewall, VPN, multi-region | No resources for these phases now |

Bastion Developer is free and shared, but Microsoft's supported-region list reviewed on 2026-09-28 includes East US 2, not East US. Moving the entire stack merely to use free Bastion requires rechecking model quota, VM capacity and all service availability. Keep East US/Basic for now; the region distinction is not a reason to add a second region.

The jump VM cannot reach Internet package repositories with NAT off. This is a short-test default, not a permanently unpatched enterprise server design. Enable explicit egress when online maintenance is required or destroy/recreate for a fresh test window. Do not assign a public IP to the VM to bypass Bastion.

Use `down` after tests: stopping the jump VM alone does not remove APIM, Bastion, IP, disk, DNS or monitoring charges. Export desired usage evidence first. The persistent bootstrap remains outside the platform and retains small storage costs.

## Validation status and next actions

- Terraform validation and three mocked lifecycle tests passed. See the current milestone runbook for plan evidence.
- Before apply: verify compute quota and a smaller jump SKU if available, required provider registrations, scoped deployment RBAC/purge permissions, the API audience registration, and a dated regional price estimate.
- No Azure resources have been deployed by this revision.

## Sources

- [APIM internal mode: Developer and Premium support, DNS requirements](https://learn.microsoft.com/en-us/azure/api-management/api-management-using-with-internal-vnet)
- [Bastion tiers and Developer regional availability](https://learn.microsoft.com/en-us/azure/bastion/bastion-sku-comparison)
- [Bastion deployment and idle billing](https://learn.microsoft.com/en-us/azure/bastion/quickstart-host-portal)
