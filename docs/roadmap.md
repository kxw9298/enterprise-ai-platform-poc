# POC roadmap

Azure subscription, Entra pipeline identity, remote state, and the initial Terraform resource-group deployment are complete. Power Platform/Copilot Studio setup and platform services remain pending. Keep resources short-lived and validate each layer before expanding scope.

This plan implements [ADR 0001: Enterprise AI platform architecture](decisions/0001-enterprise-ai-platform-architecture.md). Security requirements apply throughout; milestone 7 validates the integrated controls rather than introducing security for the first time.

| Phase | Scope | Exit criteria |
| --- | --- | --- |
| 0. Minimal design | AKS IP/CNI/access choices, model quota, APIM tier, costs and budget alerts | Current deployment path documented; no Copilot or RAG prerequisites |
| 1. AKS network | One VNet and required AKS subnet(s) | Reviewed Terraform network plan; room for future non-overlapping networks |
| 2. Managed models and gateway | Foundry resource/project, one model, filters, APIM | Authenticated model call; usage attribution and safety tests |
| 3. AKS runtime | CPU cluster, registry, agents, sample MCP tool, workload identity | Agent calls model and authorized tool; deployment and tracing work |
| Later: RAG | Documents, AI Search, embeddings, ingestion | Grounded responses and document access controls |
| Later: Copilot | Power Platform setup and separate connection VNet | Supported topology/licensing validated; agent connection works |
| Later: self-hosted LLM | Dedicated GPU user pool, vLLM, gateway and moderation | Model invocation, safety, measured cost and cleanup verified |

[ADR 0003](decisions/0003-adapt-ai-landing-zone-for-aks.md) records the revised scope. AKS remains the runtime for agents, MCP and future self-hosted models. Later extensions can be scheduled independently. Security and observability are included in each implemented phase. Multi-cloud connectivity remains an optional future extension.

## Cost and cleanup

Before provisioning, estimate costs for the actual SKUs, regions, licensing, and intended runtime. Pay particular attention to APIM networking tiers, managed Power Platform environments, AI Search, AKS nodes, private endpoints, and optional GPU/VPN/DNS resolver resources.

Budget alerts do not stop spending. Inventory resources and document deletion or shutdown behavior, including residual disk, IP, storage, and logging charges. Verify the resource inventory after teardown.
