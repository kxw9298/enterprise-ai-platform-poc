# Disposable POC platform

This root owns `rg-ai-platform-poc` and the optional platform module: AKS networking/runtime, ACR, APIM, Foundry/model/filter/project, identities/RBAC, Application Insights and Log Analytics. Bootstrap storage and pipeline identity remain outside Terraform ownership.

`enable_platform=true` plans the platform. `enable_platform=false` removes the module while retaining the group and its bootstrap-managed Contributor assignment, allowing later recreation. Full `terraform destroy` also removes the group and is intended for final retirement.

- Terraform `1.16.4`; AzureRM `5.7.0`; existing Azure Blob backend and OIDC/CLI authentication.
- Required environment variables: `TF_VAR_subscription_id`, `TF_VAR_publisher_email`, `TF_VAR_aks_admin_object_id`.
- Default `aks_node_size=Standard_D2s_v7`; check quota/capacity before apply.
- `allowed_client_ids=[]` denies all external MCP callers. Configure a real Entra API registration matching `api_audience` during application integration.
- No automatic provider registration, permission escalation or application deployment.
- No secret outputs. The remote state can contain sensitive provider-generated values; never commit it or saved plans.

Read the [platform lifecycle runbook](../../docs/runbooks/platform-lifecycle.md) for inventory, access design, limits, costs, apply prerequisites and teardown. The [pipeline runbook](../../docs/runbooks/terraform-pipeline.md) describes reviewed-commit operations.
