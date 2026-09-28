# Enterprise AI Platform POC

A secure, Azure-centered enterprise AI platform proof of concept. This monorepo brings together architecture documentation, application code, infrastructure as code, deployment configuration, and operational scripts.

## Intended architecture

- **Experience:** Copilot Studio and application/API clients.
- **Gateway:** Azure API Management for agent, MCP, and model access; evaluate LiteLLM for per-client usage, budgets, and cost attribution.
- **Runtime:** AKS-hosted agents and MCP servers; optional vLLM-hosted models in a later phase.
- **AI and data:** Microsoft Foundry for managed models, Azure AI Search for retrieval, and Azure databases/storage for sample enterprise data.
- **Security:** Entra ID, AKS Workload Identity, private connectivity, Key Vault, and explicit tool/data authorization.
- **Operations:** distributed tracing, evaluations, infrastructure automation, and eventual CI/CD/GitOps.

This is the target design, not a deployed platform. Product capabilities, licensing, networking support, and prices must be validated before selecting deployment SKUs.

## Repository layout

```text
docs/                  Architecture, decisions, roadmap, and runbooks
apps/                  User-facing applications and integration adapters
services/agents/       Custom agent services
services/mcp/          MCP servers and tool integrations
services/model-gateway/ Model routing and usage/cost integration
packages/              Shared libraries and contracts
infra/                 Azure infrastructure as code
deploy/                Kubernetes and GitOps configuration
scripts/               Setup, validation, operations, and teardown scripts
tests/                 Cross-service integration and end-to-end tests
evals/                 Agent, retrieval, and safety evaluation cases
data/samples/          Synthetic, non-sensitive test data
.github/               Contribution templates and future automation
```

## Start here

1. Read the [POC roadmap](docs/roadmap.md).
2. Review the [architecture outline](docs/architecture/README.md).
3. Record implementation choices as [architecture decisions](docs/decisions/README.md).
4. Follow the [bootstrap and cleanup runbook](docs/runbooks/bootstrap.md) to prepare the IaC backend and pipeline identity.

The initial milestone is establishing one Entra tenant, an Azure subscription, and a Power Platform/Copilot Studio environment. No cloud resources are provisioned by this scaffold.

## Working conventions

- Keep service-specific tests alongside service code; use `tests/` for cross-service validation.
- Choose languages, frameworks, and an IaC tool through an architecture decision before adding tooling.
- Use synthetic data; never commit credentials, tokens, private keys, or real corporate documents.
- Prefer workload identity and narrowly scoped permissions where supported.
- Document resource costs and teardown instructions before provisioning. Budget alerts are notifications, not hard spending caps.
- Keep infrastructure state and environment-specific secrets outside Git.

See [contribution guidance](CONTRIBUTING.md).
