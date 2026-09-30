# Bootstrap and cleanup

These scripts prepare the Azure resources that Terraform depends on. They are **not managed by Terraform**. Preparing these scripts does not deploy resources or configure GitHub Actions.

**Execution status (2026-09-28):** bootstrap provisioning completed in the configured subscription. Verified storage provisioning, TLS 1.2, disabled shared keys/anonymous blob access, versioning, seven-day soft deletion, operator container access, secretless application, branch-bound OIDC trust, and the pipeline's two scoped role assignments. [GitHub Actions OIDC login and read access passed](github-actions.md). Terraform has created `rg-ai-platform-poc`, and the pipeline now has Contributor scoped to that group. See [pipeline deployment evidence](terraform-pipeline.md). Live cleanup remains untested.

## Ownership

| Owner | Resources |
| --- | --- |
| Bootstrap scripts | `rg-ai-platform-bootstrap`, state storage account/container, Entra application/service principal/federated credential, custom role, initial RBAC assignments |
| Terraform | `rg-ai-platform-poc` and platform resources inside it |
| Separate GitHub configuration | OIDC-check and Terraform deployment workflows, and repository variables |

The bootstrap does not create the POC group, a client secret, AKS, GPUs, or models. Storage is Standard LRS with HTTPS/TLS 1.2, shared-key authentication disabled, anonymous blob access disabled, blob versioning, and seven-day blob soft deletion. Storage and retained versions incur usage charges.

**Private container does not mean private network endpoint.** The backend initially has a public network endpoint requiring Entra authentication. This allows a laptop and GitHub-hosted runners to reach it. A private endpoint needs a runner/network design and is a later change. Versioning and soft deletion do not protect against deleting the entire storage account.

## Prerequisites

- Bash 3.2+, Azure CLI, `jq`, and OpenSSL. The scripts run Azure CLI commands directly; `jq` parses JSON and OpenSSL derives stable resource IDs. No Python is required. On macOS, Bash and OpenSSL are available by default; install missing tools with `brew install azure-cli jq`.
- An interactive Azure login in the intended tenant/subscription.
- Azure permissions to create the bootstrap resource group/storage, custom roles, and role assignments. Subscription Owner is sufficient for the Azure side; Entra app creation is a separate tenant permission and may be restricted.
- Use the same operator for bootstrap retries; their Entra object ID is recorded and receives state-container access.
- Review [config.json](../../scripts/bootstrap/config.json). Subscription/tenant IDs are identifiers, not secrets. The defaults target this POC's subscription and `main` branch.

```bash
az login --tenant eb241c67-e72d-4862-ae41-7686706624c4
az account set --subscription a48d0557-360a-4849-8b56-a73b28f66aa6
```

For a new subscription, register the Storage resource provider before running setup:

```bash
az provider register --namespace Microsoft.Storage \
  --subscription a48d0557-360a-4849-8b56-a73b28f66aa6 --wait
```

Without registration, initial storage creation can fail with `SubscriptionNotFound` even when the subscription is enabled. Provider registration is subscription-wide and is not removed during bootstrap cleanup.

All commands below run from the repository root. Run only one bootstrap/cleanup process at a time.

The implementation is split into readable Bash files:

- [setup.sh](../../scripts/bootstrap/setup.sh): resource group/storage, app/service principal, OIDC federation, permissions, and local outputs.
- [grant-workload.sh](../../scripts/bootstrap/grant-workload.sh): scoped Contributor assignment after Terraform creates the POC group.
- [cleanup.sh](../../scripts/bootstrap/cleanup.sh): pre-deletion checks followed by explicit Azure CLI deletion commands.
- [common.sh](../../scripts/bootstrap/common.sh): configuration, manifest updates, account/ownership checks, and stable IDs.

Read and run each script as a whole: shared configuration and guards must execute before its Azure commands. Values are quoted and JSON is parsed with `jq`; configuration files are never sourced as shell code.

## 1. Preview

```bash
bash scripts/bootstrap/setup.sh
```

The default is an **offline preview**: it prints configuration and deterministic resource names without calling Azure or writing files. It does not check permissions or name availability.

## 2. Provision bootstrap resources

When ready to create the reviewed resources and permissions:

```bash
bash scripts/bootstrap/setup.sh --execute
```

The command validates the active tenant/subscription, creates resources, and saves:

- `.local/bootstrap/manifest.json`: ownership token, IDs, configuration, and assignment inventory used for retries and cleanup.
- `.local/bootstrap/backend.hcl`: backend configuration for the Terraform root.
- `.local/bootstrap/github-variables.json`: non-secret values to configure in GitHub later.

These files are ignored by Git. Keep a secure backup of the manifest until teardown. Do not delete it after a failed run: rerun the same command with the same configuration. Scripts refuse to adopt resources without matching ownership markers. Partial setup is recoverable because names are deterministic and Azure IDs/role-assignment intentions are journaled. If an Azure write succeeds but its response is lost, rerunning discovers the owned resource.

The Bash version preserves the prior Python implementation's resource names, UUID derivation, and version-1 manifest format. Existing local manifests remain usable. `BOOTSTRAP_LOCAL_DIR` can override the local record directory (used by tests); normally leave it unset. Keep any overridden directory outside Git too.

Azure may generate the custom role's GUID regardless of the requested `Id`. Setup records the returned GUID as `custom_role_id` and cleanup discovers the owned role by its unique name. App creation uses `az rest` against Microsoft Graph so its ownership description is set in the same request; `az ad app create` does not expose that field.

If Graph/Entra or RBAC propagation causes a transient failure, wait a few minutes and rerun. Other permission/name conflicts must be resolved first. If the manifest is lost, stop and recover it or manually inventory resources; do not generate a fresh manifest to claim existing resources.

## 3. Identity and permission design

OIDC trust is restricted to:

```text
Issuer:   https://token.actions.githubusercontent.com
Subject:  repo:kxw9298@17515296/enterprise-ai-platform-poc@1391446926:ref:refs/heads/main
Audience: api://AzureADTokenExchange
```

No PR subject or GitHub Environment subject is trusted. A future workflow must run on `main`, request `id-token: write`, and use the generated client/tenant/subscription IDs. Adding `environment:` changes the OIDC subject and will require a reviewed federation change. Protect write access to `main` since workflows on that branch can use this identity.

This new repository uses GitHub's immutable OIDC subject format. The numeric owner/repository IDs in `config.json` are non-secret and were verified using GitHub's repository and OIDC APIs. If both IDs are omitted, the script supports the legacy format for older repositories; do not omit them for this POC. Changing an existing trust rule requires an explicit Azure credential update and a matching local manifest configuration update; setup intentionally refuses silent trust changes.

| Permission | Scope | Purpose |
| --- | --- | --- |
| Custom Resource Group Writer | Subscription | Read/create/update resource groups, read subscription metadata, and read Container Apps regional quota (`Microsoft.App/locations/usages/read`) |
| Storage Blob Data Contributor, pipeline identity | State container only | Terraform state and locking |
| Storage Blob Data Contributor, bootstrap operator | State container only | Local Terraform and cleanup state checks |
| Contributor, added in step 4 | POC group only | Deploy/destroy platform resources and the POC group |

The custom role **can create/update any resource group in this subscription**; it is not name-restricted. It cannot delete groups or deploy services by itself, and does not grant RBAC administration. Use a dedicated POC subscription. The design intentionally avoids subscription-wide Contributor.

## 4. Terraform foundation and workload access

The [Terraform pipeline](terraform-pipeline.md) manages the foundation in `infra/poc`. It initially defines **only** the POC resource group, with these tags:

```hcl
resource "azurerm_resource_group" "poc" {
  name     = "rg-ai-platform-poc"
  location = "eastus"
  tags = {
    project      = "enterprise-ai-platform-poc"
    environment  = "poc"
    "managed-by" = "terraform"
  }
}
```

Follow the [Terraform pipeline runbook](terraform-pipeline.md) for remote state initialization, local authentication, and manual GitHub plan/apply operations. The provider uses explicit subscription configuration and disables automatic provider registration for the limited pipeline identity. An administrator must register providers needed by future services. Authentication uses OIDC in GitHub and the Azure CLI session locally, with no client secrets or storage keys.

Once Terraform has created the group, run as the bootstrap administrator:

```bash
bash scripts/bootstrap/grant-workload.sh
bash scripts/bootstrap/grant-workload.sh --execute
```

This grants Contributor **only on `rg-ai-platform-poc`**. It is kept in the bootstrap manifest so cleanup can remove it. Terraform can then deploy resources and eventually delete the group. Contributor cannot create workload RBAC assignments: implement narrowly scoped, preferably conditioned role-assignment delegation as a separate reviewed step before Terraform starts managing those assignments. The bootstrap does not grant Owner or User Access Administrator to the pipeline.

## 5. Teardown in the correct order

1. Stop or disable deployment workflows and ensure no Terraform operation is running. Do not rerun them during cleanup.
2. With state storage and pipeline permissions still present, run the platform's Terraform destroy. Inspect its plan and confirm destruction. If `infra/poc` has not been implemented/applied, skip Terraform.
3. Confirm the POC group is gone and the current state contains no managed resource instances. Save any needed state backup outside the repository. Treat backups as secrets.
4. Preview bootstrap cleanup, then execute it explicitly.

```bash
# Once a Terraform root exists and has been initialized:
terraform -chdir=infra/poc plan -destroy
terraform -chdir=infra/poc destroy

# Offline preview (no changes):
bash scripts/bootstrap/cleanup.sh

# Destructive: deletes bootstrap storage INCLUDING state history and versions.
bash scripts/bootstrap/cleanup.sh --execute \
  --confirm-state-deletion a48d0557-360a-4849-8b56-a73b28f66aa6
```

Cleanup validates account/ownership, refuses while the POC group exists, checks current state for managed instances and locks, and refuses unexpected blobs/containers/resources. API errors are failures, not evidence that resources are absent. Old state versions may describe destroyed resources; explicit state-deletion confirmation acknowledges their loss.

It removes journaled subscription/workload role assignments, the custom role, service principal, application (including federation), then the bootstrap group/storage. Container-scoped assignments disappear with the group; the operator retains state-read access until that deletion completes so a retry can check state again. Resource locks or policy may block deletion; resolve them explicitly and rerun cleanup. The manifest is retained and retries tolerate already-removed resources.

The guard covers the configured POC group and this backend; it cannot prove there are no orphan resources from manual operations or other state files. Review your subscription inventory first. Keep this storage account/container dedicated to this one Terraform root; additional workspaces require extending the cleanup inventory.

## 6. Items outside both Terraform and this Azure cleanup

- Remove any GitHub variables later configured from `github-variables.json`, and disable/remove deployment workflows. The scripts do not change GitHub settings.
- Power Platform environments/licensing, Copilot Studio, budget alerts, and manually created resources need their own teardown if added later.
- Azure subscription, Entra tenant, user accounts, and Azure CLI login remain intact.
- Local backend files, manifest, Terraform cache, and any backups remain. Archive/delete them deliberately after verifying teardown. Do not commit state or backups.
- Do not unregister shared Azure resource providers merely to clean up this POC.

## Local verification

```bash
bash tests/bootstrap/run.sh
for script in scripts/bootstrap/*.sh tests/bootstrap/*.sh; do bash -n "$script"; done
```

The shell tests put a fake `az` executable first on PATH, use isolated temporary records, and exercise setup, retries, workload access, and cleanup guards without cloud access. They are not live Azure integration tests. Live provisioning, operator access, and GitHub OIDC authentication/read access have now been verified as noted above. Terraform backend initialization, state writes, and resource-group deployment have also passed through GitHub Actions. Live teardown remains untested.

## References

- [Microsoft: federated application credentials](https://learn.microsoft.com/en-us/cli/azure/ad/app/federated-credential)
- [GitHub: OIDC with Azure](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-azure)
- [HashiCorp: AzureRM backend and Entra/OIDC authentication](https://developer.hashicorp.com/terraform/language/backend/azurerm)
- [Microsoft: custom Azure roles](https://learn.microsoft.com/en-us/azure/role-based-access-control/custom-roles)


### Existing-role migration for Container Apps quota reads

The source-controlled bootstrap role now includes `Microsoft.App/locations/usages/read`. This does not update the existing Azure role automatically. After explicit approval, an administrator must append that one action to the existing owned role definition, preserving its ID, scope, other actions and assignments. Allow RBAC propagation and verify with the pipeline identity. Subsequent setup runs then match the expected definition. Until that live update, setup rejects the legacy role as permission drift; it does not silently broaden permissions. Extra actions remain rejected too. The user approved this migration and it was applied on 2026-09-30. Read-back verified exactly the additional quota-read action and unchanged ID/scope; the existing pipeline assignment was retained. Effective access still needs a fresh pipeline login.
