# ADR 0001: Enterprise AI platform architecture

- **Date:** 2026-09-27
- **Status:** Accepted architectural direction; implementation and product compatibility validation pending
- **Scope:** Enterprise AI platform POC
- **Context source:** [Original planning conversation](https://chatgpt.com/share/6ab991da-b7e8-83ea-853a-5d046a733fc3)

## Context

The POC should demonstrate a secure enterprise AI platform with internal agents, MCP tools, managed frontier models, self-hosted models, enterprise retrieval, and private access from Copilot Studio. It should also demonstrate per-client model usage and cost attribution. Run resources for short testing periods and keep expenses controlled.

This record captures the user's stated platform direction from the planning conversation. It does not approve particular paid SKUs, assert that integrations have been tested, or treat prior cost estimates as verified pricing.

## Options considered

1. Host custom agents and MCP services on AKS, using Foundry for managed AI capabilities.
2. Center the runtime on Foundry Agent Service instead of operating custom agents on AKS.
3. Implement a smaller managed-model chatbot without the internal runtime and gateway layers.

The first option matches the POC's intended learning and validation scope. The other options may reduce operational work but do not exercise the selected AKS-based platform design to the same extent.

## Decision

| Area | Architectural direction |
| --- | --- |
| Repository | One monorepo for docs, services, shared packages, IaC, deployment configuration, scripts, tests, and evaluations |
| Tenant foundation | Use one Entra tenant for the Azure subscription and Power Platform environment |
| Experience | Use Copilot Studio as a client of internal platform services; allow other API/application clients |
| Custom runtime | Host custom agents and MCP servers on AKS |
| Managed models | Use Foundry for managed frontier-model access; integrate safety, evaluation, and observability capabilities where supported |
| Self-hosted models | Demonstrate an open-source model on AKS using a runtime such as vLLM in a later, time-limited GPU phase |
| Gateway | Use APIM as the planned enterprise API/MCP ingress and policy boundary; evaluate its model gateway role against usage and cost requirements |
| Model metering | Require attribution by client/key; decide APIM alone versus APIM plus LiteLLM after validating metering, budgets, and routing |
| Data and retrieval | Use Azure databases/storage for synthetic enterprise data and Azure AI Search for retrieval; keep retrieval authorization in scope |
| Identity | Prefer Entra authentication, managed identity, and AKS Workload Identity; explicitly decide user delegation versus workload permissions for each flow |
| Network | Target private connectivity for internal services, using supported Power Platform networking, Azure VNets, private endpoints, and DNS |
| Authorization | Enforce tool and data permissions separately from network reachability and authentication |
| Operations | Include distributed tracing, evaluation cases, repeatable deployment, cost review, and teardown |

APIM's exact tier and topology remain open. Fine-grained policy enforcement is required, but choosing OPA as its implementation remains open. Likewise, GitOps is a delivery direction; Argo CD has not been selected.

## Reference architecture refinement

The user reaffirmed AKS for agents, MCP servers and future self-hosted LLMs on 2026-09-28. [ADR 0003](0003-adapt-ai-landing-zone-for-aks.md) proposes gateway boundaries, Foundry organization, private access design and phased delivery based on the Azure AI Landing Zones reference. Its detailed design remains proposed.

## Delivery sequence

Follow the [POC roadmap](../roadmap.md): account foundation, design validation, network/identity, AKS runtime, managed models/gateway, data/RAG, security/operations verification, private Copilot integration, then extensions.

Security requirements apply from the foundation phase; the later security milestone validates the end-to-end controls. Start with CPU workloads and managed models. Add GPU inference after the basic path works. Azure–GCP connectivity is a separate optional extension.

## Consequences

- AKS provides a common runtime for agents, tools, and eventual self-hosted inference, with additional cluster and deployment operations to manage.
- Shared gateway and identity controls provide common entry points, while services retain responsibility for tool/data authorization.
- APIM plus LiteLLM may satisfy more detailed metering requirements, but adds operational complexity; add it only if the comparison justifies it.
- Private connectivity depends on product tiers, licensing, region support, DNS, and supported connector/tool behavior. Validate these before provisioning.
- Foundry integration does not automatically instrument or secure custom AKS workloads; those integrations require explicit implementation and tests.
- Short-lived deployments still incur charges; budget alerts do not cap spending. Include cleanup and residual-resource checks in runbooks.

## Open decisions

- Azure regions, resource naming, address ranges, and Power Platform environment/licensing.
- APIM tier, private ingress/egress topology, and Copilot connector/MCP path.
- APIM-only versus APIM plus LiteLLM, and the approach to cost calculation and client budgets.
- Application language/framework and GitOps tooling. Terraform with GitHub Actions OIDC is implemented for the foundation; see ADR 0002.
- OAuth delegation/OBO requirements, policy engine, and retrieval access filtering.
- Model deployments, quotas, GPU SKU, and measured cost envelope.

Record these as subsequent ADRs when evaluated rather than silently treating examples as final choices.

## Verification evidence

The repository, Azure bootstrap, and Terraform POC resource group are deployed; see the [pipeline runbook](../runbooks/terraform-pipeline.md) for verification. AI runtime and model integrations remain unimplemented. The planning conversation supplies requirements, not independently verified product capabilities or prices. Capture vendor documentation, selected SKUs, test results, traces, and cost evidence as implementation proceeds.
