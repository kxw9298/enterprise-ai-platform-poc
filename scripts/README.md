# Operational scripts

The [bootstrap scripts](bootstrap/) create and clean up the Azure foundation outside Terraform. Both default to offline preview. See the [runbook](../docs/runbooks/bootstrap.md) for permissions, execution, retries, and teardown order.

Add repeatable bootstrap, validation, deployment, cost review, and teardown commands here as implemented. Document prerequisites and inputs. Scripts should fail clearly, avoid printing secrets, and identify the target subscription/environment before changes.
