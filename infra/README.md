# Infrastructure as code

Azure resource definitions and reusable modules belong here. Terraform is selected for the platform; Azure CLI handles the separate bootstrap foundation, as recorded in [ADR 0002](../docs/decisions/0002-iac-bootstrap-and-lifecycle.md).

The [POC root](poc/README.md) owns `rg-ai-platform-poc` plus the active platform module: internal APIM, the Foundry account/project/model/content filters, test identities and RBAC, Application Insights, Log Analytics, Bastion Basic and the private jump VM. AKS/ACR/MCP are retained as commented-out Terraform and do not participate in the active plan. Use the [Terraform pipeline runbook](../docs/runbooks/terraform-pipeline.md) for manual plan/apply/destroy operations.

Keep environment values separate from reusable modules. Use remote state where applicable; never commit state, credentials, or real secret values. Document provisioning costs and teardown.
