# POC foundation

This Terraform root initially owns **only `rg-ai-platform-poc` in East US**. It does not own bootstrap storage, the Entra pipeline identity, or their role assignments.

- Terraform: `1.16.4`, recorded in `.terraform-version` and the workflow.
- AzureRM provider: `5.7.0`, pinned with `.terraform.lock.hcl` (commit the lock file).
- Backend: Azure Blob Storage, configured at init from GitHub variables or the ignored local bootstrap backend file.
- Authentication: GitHub OIDC in CI; your Azure CLI login for local use.
- The provider does not auto-register Azure resource providers and refuses to delete a resource group containing resources.

Follow the [Terraform pipeline runbook](../../docs/runbooks/terraform-pipeline.md) for plan, apply, access setup, and eventual teardown. Do not commit state or binary/JSON plan files. No secrets belong in this root.
