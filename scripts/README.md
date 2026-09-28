# Operational scripts

The [bootstrap scripts](bootstrap/) create and clean up the Azure foundation outside Terraform. Both default to offline preview. See the [runbook](../docs/runbooks/bootstrap.md) for permissions, execution, retries, and teardown order.

They use Bash, Azure CLI, and `jq`, with OpenSSL for stable IDs. Run `bash scripts/bootstrap/setup.sh`, `bash scripts/bootstrap/grant-workload.sh`, or `bash scripts/bootstrap/cleanup.sh` to preview the corresponding operation. Add `--execute` only when ready to apply it; cleanup also requires the explicit state-deletion acknowledgment documented in the runbook.

Add repeatable bootstrap, validation, deployment, cost review, and teardown commands here as implemented. Document prerequisites and inputs. Scripts should fail clearly, avoid printing secrets, and identify the target subscription/environment before changes.
