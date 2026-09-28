# ADR 0002: IaC bootstrap and lifecycle

- **Date:** 2026-09-27
- **Status:** Accepted; bootstrap provisioning and pipeline OIDC/read access verified; Terraform foundation deployed; live cleanup validation pending

## Context

The user selected Azure CLI for resources needed by the IaC pipeline and Terraform for the platform itself. The state backend and deployment identity must exist before the pipeline can initialize Terraform. The user also requested cleanup for resources outside Terraform ownership.

## Options considered

1. One Terraform root owns its own backend: introduces a bootstrap dependency and risks deleting state during platform teardown.
2. A separate Terraform bootstrap root using local state: workable, but creates another state lifecycle to secure and retain.
3. Azure CLI bootstrap plus Terraform platform root: selected for a small, explicit one-time foundation.

## Decision

- Keep bootstrap resources in `rg-ai-platform-bootstrap`, outside Terraform ownership.
- Use scripts invoking Azure CLI to create state storage, Entra app/service principal, GitHub branch-bound OIDC federation, and initial RBAC. Do not create client secrets.
- Implement these scripts in Bash with direct Azure CLI commands and `jq` for JSON, per the user's preference for readable, familiar shell operations. Use shared helpers for safety checks and OpenSSL for stable IDs; retain the existing manifest format. Python was used initially but is no longer required for implementation or tests.
- Terraform owns `rg-ai-platform-poc` and future platform resources. The foundation root is in `infra/poc`, with manual plan/apply/destroy operations in `.github/workflows/terraform-poc.yml`.
- Store state in a dedicated Entra-authenticated blob container. Initially allow authenticated access over the public storage endpoint so GitHub-hosted runners and the developer machine can reach it.
- Give the pipeline only resource-group read/write operations at subscription scope initially. After Terraform creates the POC group, an administrator grants Contributor scoped to that group. Keep RBAC delegation a separate decision.
- Record ownership and assignment IDs in an ignored local manifest. Both setup and cleanup preview without making Azure calls unless execution is explicitly requested.
- Destroy Terraform resources before deleting the backend or identity. Cleanup checks ownership, workload-group absence, current state, and unexpected resources, then requires explicit acknowledgment of state-history deletion.

## Consequences

The pipeline can create/update groups throughout this dedicated subscription, but cannot initially delete groups, deploy services, or grant roles. Subsequent Contributor access is limited to the POC group. Future workload role assignments need deliberate additional authorization.

The state container is access-controlled but is not network-isolated. A future private endpoint requires reachable runners and a separate design change. Backend storage/version retention carries usage costs.

Keep the recovery manifest until cleanup. The cleanup script cannot discover all manually created orphan resources, Power Platform subscriptions/environments, or GitHub settings; the runbook lists these separate responsibilities. Stop pipeline activity before teardown to avoid races.

## Verification evidence

Local shell tests use a fake Azure CLI and isolated temporary files to exercise preview behavior, account checks, setup and retries, scoped workload access, ownership checks, cleanup guards, and state checks. Bootstrap provisioning completed on 2026-09-28. Azure checks verified storage protection settings, operator container access, secretless application, branch-specific OIDC federation, and pipeline role assignments. Live execution also led to corrections for Storage provider registration, application creation through Graph, and Azure-generated custom-role IDs.

On 2026-09-28, [GitHub Actions run 36426019554, attempt 2](https://github.com/kxw9298/enterprise-ai-platform-poc/actions/runs/36426019554/attempts/2) verified OIDC login and read access. This repository uses immutable GitHub subject claims containing owner/repository IDs; bootstrap and Entra trust now use that exact subject. The [Terraform apply](https://github.com/kxw9298/enterprise-ai-platform-poc/actions/runs/36427782884) subsequently created the POC resource group using OIDC and remote state. An administrator granted Contributor scoped to that group. No live deletion has been performed.

See the [bootstrap and cleanup runbook](../runbooks/bootstrap.md).
