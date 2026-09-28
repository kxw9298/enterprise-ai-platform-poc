# Runbooks

- [Bootstrap and cleanup](bootstrap.md): Azure CLI state storage, GitHub OIDC identity, initial RBAC, and teardown outside Terraform.
- [GitHub Actions authentication](github-actions.md): repository variables and the manual Azure OIDC check.
- [Platform lifecycle](platform-lifecycle.md): resource inventory, prerequisites, spin-up/down, token accounting and remaining integration work.
- [Terraform POC pipeline](terraform-pipeline.md): plan, apply, scoped access, and eventual destroy of the platform foundation.

Add procedures for tenant/subscription setup, deployment, access verification, troubleshooting, cost review, and teardown as each milestone is implemented. Include prerequisites, commands, expected results, and recovery steps.
