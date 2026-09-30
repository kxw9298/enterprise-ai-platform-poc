# Disposable POC platform

**Latest scope:** [Phase 1: Copilot Studio private connectivity](../../docs/runbooks/phase-one-private-connectivity.md). AKS/ACR is preserved for phase 2 and disabled by default; the Container Apps alternative is not yet implemented or deployed.

**Current code:** [Private MCP hub-and-spoke](../../docs/runbooks/mcp-private-network.md). One root/state; network persists during down; Foundry and Bastion default off. Earlier inventories below are historical.

**Current first milestone:** [Foundry + internal APIM model gateway](../../docs/runbooks/model-gateway-first.md), with two secretless test-client IDs, content filtering, request/token limits and per-client cost reporting. AKS/ACR/MCP are removed from the active Terraform root and deferred. Earlier AKS inventory and plan evidence below are historical; this milestone supersedes that sequence.

This root owns `rg-ai-platform-poc` and the optional platform module: AKS networking/runtime, ACR, APIM, Foundry/model/filter/project, identities/RBAC, Application Insights and Log Analytics. Bootstrap storage and pipeline identity remain outside Terraform ownership.

`enable_platform=true` plans the platform. `enable_platform=false` removes the module while retaining the group and its bootstrap-managed Contributor assignment, allowing later recreation. Full `terraform destroy` also removes the group and is intended for final retirement.

- Terraform `1.16.4`; AzureRM `5.7.0`; existing Azure Blob backend and OIDC/CLI authentication.
- Required environment variables: `TF_VAR_subscription_id`, `TF_VAR_publisher_email`, `TF_VAR_api_audience`, `TF_VAR_jump_ssh_public_key` (public key only). `TF_VAR_aks_admin_object_id` is commented out in `variables.tf` and is **not** required.
- Default `aks_node_size=Standard_D2s_v7`; inactive while AKS is deferred. Check quota/capacity before re-enabling that milestone.
- `allowed_client_ids=[]` denies all external MCP callers. Configure a real Entra API registration matching `api_audience` during application integration.
- No automatic provider registration, permission escalation or application deployment.
- No secret outputs. The remote state can contain sensitive provider-generated values; never commit it or saved plans.

Read the [platform lifecycle runbook](../../docs/runbooks/platform-lifecycle.md) for inventory, access design, limits, costs, apply prerequisites and teardown. The [pipeline runbook](../../docs/runbooks/terraform-pipeline.md) describes reviewed-commit operations.

Internal APIM/Bastion revision applied 2026-09-29T01:18:19Z (Actions run `36504873891`, 31 added, 0 changed, 0 destroyed) and the model endpoint was runtime-tested from the Bastion jump VM on 2026-09-28. Bastion Basic and a private Linux jump VM are removed with `down`. `enable_jump_egress=false` avoids a paid NAT gateway by default. `jump_vm_size` is separate from `aks_node_size`.
