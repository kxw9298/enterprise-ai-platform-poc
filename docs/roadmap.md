# POC roadmap

All milestones are initially pending. Keep resources short-lived and validate each layer before expanding scope.

This plan implements [ADR 0001: Enterprise AI platform architecture](decisions/0001-enterprise-ai-platform-architecture.md). Security requirements apply throughout; milestone 7 validates the integrated controls rather than introducing security for the first time.

| Milestone | Scope | Exit criteria |
| --- | --- | --- |
| 1. Account foundation | Entra tenant, Azure subscription, Power Platform environment, Copilot Studio entitlement, budget alerts | Tenant IDs and permissions verified; basic Copilot agent works; licensing constraints recorded |
| 2. Design decisions | Region, network ranges, IaC tool, APIM tier, model gateway, cost estimate | Required private connectivity is supported by selected tiers; decisions recorded |
| 3. Network and identity | VNet/subnets, DNS, workload identities, Key Vault design | Required paths resolve correctly; minimum required access documented |
| 4. AKS runtime | Small CPU cluster, agent service, MCP service | Agent invokes a sample MCP tool; workload identity validated |
| 5. Managed models and gateway | Foundry model, APIM, optional LiteLLM | Model call succeeds through gateway; client usage and cost attribution demonstrated |
| 6. Data and RAG | Synthetic documents, storage, AI Search | Grounded responses cite source documents and respect access boundaries |
| 7. Security and operations | Tool authorization, safety controls, tracing, evaluations, CI/CD | Unauthorized calls are rejected; requests can be traced; deployment is repeatable |
| 8. Private Copilot integration | Supported connector/tool path, Power Platform enterprise policy, private endpoints | Copilot reaches internal agent/MCP services through the verified private path |
| 9. Optional extensions | GPU/vLLM, additional clients, Azure–GCP connectivity | One extension validated with measured cost and documented teardown |

## Cost and cleanup

Before provisioning, estimate costs for the actual SKUs, regions, licensing, and intended runtime. Pay particular attention to APIM networking tiers, managed Power Platform environments, AI Search, AKS nodes, private endpoints, and optional GPU/VPN/DNS resolver resources.

Budget alerts do not stop spending. Inventory resources and document deletion or shutdown behavior, including residual disk, IP, storage, and logging charges. Verify the resource inventory after teardown.
