# Terraform POC pipeline

**Current code:** [Private MCP hub-and-spoke](mcp-private-network.md). One root/state; network persists during down; Foundry and Bastion default off. Earlier inventories below are historical.

The [Terraform POC workflow](../../.github/workflows/terraform-poc.yml) manages the [foundation root](../../infra/poc/README.md). The root now includes the optional Foundry/internal-APIM platform. See [model gateway milestone](model-gateway-first.md) for the current resource inventory, prerequisites, and down/recreate procedure. The historical resource-group-only deployment evidence below predates this expansion.

## Prerequisites

- [Bootstrap completed](bootstrap.md), including the backend and pipeline identity.
- The six bootstrap variables plus `APIM_PUBLISHER_EMAIL`, `JUMP_SSH_PUBLIC_KEY`, and `MODEL_API_AUDIENCE` (required for working model authentication; a placeholder is sufficient for planning) configured; [GitHub OIDC check](github-actions.md) passing.
- Access to manually run Actions on `main`.

## Plan, review, and apply

1. Open **Actions → Terraform POC → Run workflow** on GitHub.
2. Choose branch **main**, operation **plan**, and leave other inputs blank.
3. Review the log and job summary. Review every planned platform resource. Copy the full commit SHA shown in the summary.
4. Run the workflow again with operation **apply**, providing that SHA as `reviewed_commit`.
5. Verify the apply succeeds and the group appears in Azure.

CLI equivalent:

```bash
gh workflow run terraform-poc.yml --ref main \
  --repo kxw9298/enterprise-ai-platform-poc -f operation=plan
# Review the resulting run and copy its full commit SHA, then:
gh workflow run terraform-poc.yml --ref main \
  --repo kxw9298/enterprise-ai-platform-poc \
  -f operation=apply -f reviewed_commit=REVIEWED_FULL_COMMIT_SHA
```

Apply requires the reviewed commit to equal the run's commit. It generates a fresh plan on that same code, checks its scope, and applies the saved plan in the same job. It does not reuse a plan artifact from the earlier run. Azure drift can change the fresh plan; review the apply log as well. The guard permits only the exact resource addresses in `scripts/ci/platform-resources.json` and rejects replacements/deletes during normal apply. `down-plan`/`down` permit platform deletion while preserving the group; full destroy may remove the group too. Extending the platform requires a deliberate guard update.

The `reviewed_commit` input is an explicit operator acknowledgment, not an enforced independent reviewer approval. No paid GitHub Environment approval feature is required, and no Environment is attached because that would change the OIDC subject.

## Grant access after the group exists

The pipeline's initial custom subscription role can create/update groups, but does not allow service deployment or group deletion. As the bootstrap administrator, run:

```bash
bash scripts/bootstrap/grant-workload.sh
bash scripts/bootstrap/grant-workload.sh --execute
```

This records and grants Contributor only on `rg-ai-platform-poc`. It does not grant subscription-wide Contributor or permission to administer role assignments. Workload identity role assignments need a separate authorization design before adding them to Terraform.

Rerun **plan** after the initial apply; it should report no infrastructure changes.

## State, credentials, and concurrency

- State lives in the existing `tfstate` container under `poc.tfstate`; it is not in Git.
- Terraform uses OIDC and Entra authentication for both the Azure provider and backend. It does not retrieve storage account keys.
- GitHub workflow permissions are `contents: read` and `id-token: write`. Actions are pinned to specific release commits; checkout does not persist its Git credential.
- The provider checksum lock file is committed for Linux runners and the developer's ARM Mac.
- All operations share one GitHub concurrency group and use backend locking with a five-minute lock timeout. Do not run local apply/destroy concurrently with Actions.
- Binary and JSON plan files exist only in the runner's temporary directory, are removed at job end, and are never uploaded as artifacts. The plan log includes infrastructure settings; sensitive provider values remain redacted by Terraform. Future resources must mark sensitive values appropriately and must not print credentials.
- `.local/`, `.terraform/`, state, environment files, keys, and Terraform plan files are ignored. Repository variables contain identifiers, not credentials.

## Local validation and optional local operation

For the expanded root, use [scripts/infra/plan.sh](../../scripts/infra/plan.sh) and set the required publisher/admin variables described in the lifecycle runbook. The local commands below are supplementary.

Use Terraform 1.16.4. The project-local validated binary is in `.local/tools/terraform/1.16.4/terraform` on the current Mac; other machines should install the pinned version from HashiCorp. The older system Terraform is not used by this workflow.

```bash
terraform -chdir=infra/poc fmt -check
terraform -chdir=infra/poc init -backend=false
terraform -chdir=infra/poc validate
bash tests/terraform/check-plan.sh
```

For intentional local Azure operations, authenticate with Azure CLI, export the subscription/tenant from the ignored bootstrap output, then initialize the real backend:

```bash
export ARM_SUBSCRIPTION_ID="$(jq -r .AZURE_SUBSCRIPTION_ID .local/bootstrap/github-variables.json)"
export ARM_TENANT_ID="$(jq -r .AZURE_TENANT_ID .local/bootstrap/github-variables.json)"
export TF_VAR_subscription_id="$ARM_SUBSCRIPTION_ID"
export ARM_USE_CLI=true
export ARM_USE_OIDC=false
unset ARM_CLIENT_ID ARM_CLIENT_SECRET ARM_OIDC_TOKEN
terraform -chdir=infra/poc init -reconfigure -backend-config=../../.local/bootstrap/backend.hcl
terraform -chdir=infra/poc plan
```

The pipeline uses `ARM_USE_CLI=false` and OIDC instead. Never copy GitHub tokens into local files.

## Routine shutdown

Use **down-plan**, review it, then **down** with the reviewed SHA and `rg-ai-platform-poc` confirmation. This removes paid platform resources and retains the group/bootstrap for recreation. Run **plan** then **apply** to recreate. The expanded platform requires workload RBAC and purge permissions; current pipeline Contributor alone is insufficient, and preflight blocks an unready apply.

## Eventual teardown

**Do not destroy merely to test this setup.** When retiring the POC:

1. Run operation **destroy-plan** and review the affected resources and commit.
2. Run operation **destroy**, set `reviewed_commit` to that SHA, and type `rg-ai-platform-poc` in `confirm_destroy`.
3. Verify Terraform's destroy succeeds while the backend and pipeline identity still exist.
4. Follow [bootstrap cleanup](bootstrap.md) to remove resources outside Terraform ownership.

The Contributor assignment from `grant-workload.sh` must exist before group deletion. The AzureRM provider blocks deletion of a nonempty group; do not disable that guard to remove manually created resources without review. The workflow does not run bootstrap cleanup. Live destructive teardown is not exercised during initial setup.

## References

- [HashiCorp: AzureRM backend, OIDC, and state locking](https://developer.hashicorp.com/terraform/language/backend/azurerm)
- [AzureRM provider configuration](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)

## Deployment evidence (2026-09-28)

- [Initial plan](https://github.com/kxw9298/enterprise-ai-platform-poc/actions/runs/36427491795): one resource group to add, no changes or deletions.
- [Apply](https://github.com/kxw9298/enterprise-ai-platform-poc/actions/runs/36427782884): succeeded at commit `54c91a1699b926d55386e0aacb34364d39959e4b`.
- Azure verification: `rg-ai-platform-poc` provisioned successfully in `eastus` with the expected tags; pipeline Contributor assignment scoped only to that group; `poc.tfstate` exists in the backend and its lease is released.
- [Post-apply plan](https://github.com/kxw9298/enterprise-ai-platform-poc/actions/runs/36427963407): succeeded and reported **No changes. Your infrastructure matches the configuration.**
- Destroy operations are implemented but have not been executed.

### Read-only apply readiness check

Run `Terraform POC` with `operation=preflight` to exercise apply's provider,
regional quota and effective permission checks using the GitHub OIDC identity.
It initializes and validates Terraform but does not plan or apply resources.
Use the same runtime flags as the intended apply. A pass proves coarse readiness,
not regional provisioning capacity or role-assignment condition correctness.

`az group exists` returns a scalar boolean. Querying a nonexistent `value` field
returns empty output and incorrectly selects subscription-level permission checks,
ignoring valid resource-group delegation. Preflight now validates the boolean
explicitly. After full destroy, recreate the foundation group and restore its
scoped grants through the documented bootstrap sequence; this check never grants
subscription-wide role administration to work around missing delegation.
