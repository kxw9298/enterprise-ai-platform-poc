# Infrastructure as code

Azure resource definitions and reusable modules belong here. Terraform is selected for the platform; Azure CLI handles the separate bootstrap foundation, as recorded in [ADR 0002](../docs/decisions/0002-iac-bootstrap-and-lifecycle.md).

The [POC root](poc/README.md) starts with the resource group only. Use the [Terraform pipeline runbook](../docs/runbooks/terraform-pipeline.md) for manual plan/apply/destroy operations.

Keep environment values separate from reusable modules. Use remote state where applicable; never commit state, credentials, or real secret values. Document provisioning costs and teardown.
