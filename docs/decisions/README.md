# Architecture decision records

Create numbered records when a significant choice is made.

| Record | Status | Scope |
| --- | --- | --- |
| [0001: Enterprise AI platform architecture](0001-enterprise-ai-platform-architecture.md) | Accepted direction; implementation validation pending | Component responsibilities, security boundaries, phased delivery, and open decisions |
| [0002: IaC bootstrap and lifecycle](0002-iac-bootstrap-and-lifecycle.md) | Accepted direction; live validation pending | Azure CLI bootstrap, Terraform ownership, OIDC, and safe teardown |
| [0003: Adapt the AI landing zone for an AKS runtime](0003-adapt-ai-landing-zone-for-aks.md) | Revised per user direction; endpoint details remain proposed | One AKS VNet, Bastion-based admin testing, non-premium cost tier, deferred Copilot networking and RAG |

Each record should contain: title, date, status (proposed/accepted/superseded), context, considered options, decision, consequences, and verification evidence. Do not mark a proposal accepted before the choice is made.
