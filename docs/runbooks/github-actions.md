# GitHub Actions: Azure authentication

The [Azure OIDC check workflow](../../.github/workflows/azure-oidc-check.yml) verifies the bootstrap identity from a real GitHub-hosted runner. It does not deploy resources or modify Terraform state.

**Verified 2026-09-28:** [run 36426019554, attempt 2](https://github.com/kxw9298/enterprise-ai-platform-poc/actions/runs/36426019554/attempts/2) passed variable checks, OIDC login, expected identity/subscription checks, resource-group listing, and state-container listing. The initial attempt exposed a legacy-versus-immutable subject mismatch; Entra and bootstrap configuration now match GitHub's authoritative immutable subject prefix.

## Repository configuration

In GitHub, open **Settings → Secrets and variables → Actions → Variables**. The following repository variables are identifiers/configuration, not passwords:

| Variable | Source |
| --- | --- |
| `AZURE_CLIENT_ID` | Bootstrap app registration's application/client ID |
| `AZURE_TENANT_ID` | Entra tenant ID |
| `AZURE_SUBSCRIPTION_ID` | POC subscription ID |
| `TF_STATE_STORAGE_ACCOUNT` | Bootstrap storage account name |
| `TF_STATE_CONTAINER` | `tfstate` |
| `TF_STATE_KEY` | `poc.tfstate` |

Values are generated locally in `.local/bootstrap/github-variables.json`. This file stays ignored by Git. No client secret, `AZURE_CREDENTIALS`, storage account key, personal Azure token, or GitHub PAT is required by this workflow.

To populate the variables using your existing GitHub CLI login, from the repository root:

```bash
for name in AZURE_CLIENT_ID AZURE_TENANT_ID AZURE_SUBSCRIPTION_ID TF_STATE_STORAGE_ACCOUNT TF_STATE_CONTAINER TF_STATE_KEY; do
  jq -er --arg name "$name" '.[$name]' .local/bootstrap/github-variables.json |
    gh variable set "$name" --repo kxw9298/enterprise-ai-platform-poc
done
```

The variable names are an explicit allowlist: do not replace this with uploading all environment variables or credential files. Do not save tokens in workflow YAML or print them in logs.

## Run the check

**Actions → Azure OIDC check → Run workflow → Branch: main → Run workflow.**

Or use GitHub CLI:

```bash
gh workflow run azure-oidc-check.yml --ref main --repo kxw9298/enterprise-ai-platform-poc
gh run list --workflow azure-oidc-check.yml --repo kxw9298/enterprise-ai-platform-poc
```

The workflow is manual-only and its job runs only on `main`. It requests `id-token: write` for OIDC and no repository-write permission. It uses a commit-pinned official Azure Login action and does not check out repository contents or publish artifacts. Azure CLI output is suppressed except for selected metadata needed by the checks.

The Azure federated credential trusts this exact subject:

```text
repo:kxw9298@17515296/enterprise-ai-platform-poc@1391446926:ref:refs/heads/main
```

This repository uses GitHub's immutable subject format, which includes owner/repository IDs. Verify the prefix with `gh api repos/kxw9298/enterprise-ai-platform-poc/actions/oidc/customization/sub`; a legacy name-only subject will fail authentication. The IDs are non-secret configuration in bootstrap's `config.json`.

Do not add a GitHub `environment:` to this job without changing and reviewing the Entra trust rule: it changes the OIDC subject. Do not broaden trust to pull requests. Anyone who can change/run trusted code on `main` can exercise the pipeline's assigned Azure permissions, so keep repository access limited to intended maintainers.

## Expected result and limits

A successful run proves GitHub can obtain an Azure token for the expected service principal, select the correct subscription/tenant, list resource groups, and list blobs in the Terraform state container with Entra authentication. It does not read or display blob contents.

It does not prove Terraform apply/destroy, state write access, or state locking yet. Those will be validated with the Terraform foundation. The workflow deliberately does not create the POC group or grant new permissions.

## Troubleshooting

- **Missing variable:** populate the six entries above; they belong in the Variables tab.
- **No matching federated identity:** verify repository, `main` branch, issuer, audience, and absence of a GitHub Environment in the job.
- **Storage authorization failure:** confirm the pipeline service principal has container-scoped Storage Blob Data Contributor and allow time for RBAC propagation. Do not enable shared keys as a workaround.
- **Job skipped:** dispatch from `main`.
- **Actions unavailable:** check repository Actions permissions and account runner/billing availability; repository variables do not enable a disabled Actions service.

## Cleanup

Stop/disable deployment workflows before Terraform destroy and bootstrap cleanup. Repository variables persist after Azure resources are deleted. Remove these six variables through GitHub Settings when retiring the POC; they are not Azure resources and are not removed by the bootstrap cleanup script.

## References

- [GitHub: OpenID Connect with Azure](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-azure)
- [Azure Login action](https://github.com/Azure/login)
