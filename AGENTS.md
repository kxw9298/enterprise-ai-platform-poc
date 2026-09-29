# Agent instructions and handoff

This file is the entry point for any coding agent continuing this POC, including after a rate limit or session reset. Read it before changing infrastructure. It is a handoff, not authorization to deploy or destroy resources. The user's latest instructions take precedence.

## Goal and working preferences

The eventual goal is Copilot Studio → APIM → internal MCP hosted on AKS, with APIM also serving as an AI model gateway and attributing tokens and estimated costs per client. Keep a simplified enterprise-style landing zone that can be spun up and torn down to save money.

**Current first milestone:** enable a Foundry LLM, access it through internal APIM with authenticated client IDs, and validate content safety, per-client token/cost tracking, request throttling and token quotas. AKS is not needed for this milestone.

- Keep one region (East US), avoid Premium tiers where practical, and explain idle costs.
- Keep APIM internal; test from a private jump VM through Bastion.
- Preserve deferred AKS/ACR/MCP Terraform as commented-out code with explanatory notes. Do not delete it or enable it incidentally.
- Explain steps plainly; the user wants to understand the resources and identity flow.
- Python is acceptable. Do not rewrite working scripts just to change language.
- Never commit secrets, tokens, private SSH keys, Terraform state, saved plans or local configuration. Tenant/subscription/client IDs are identifiers, not credentials.
- Commit and push completed requested work when authorized; respect unrelated working-tree changes. Do not infer authorization to apply, grant access or destroy from a request to prepare or commit code.

## Read next

1. [Current milestone and test sequence](docs/runbooks/model-gateway-first.md) — authoritative current scope.
2. [Cost decisions](docs/architecture/cost-review.md).
3. [Terraform pipeline](docs/runbooks/terraform-pipeline.md) and [bootstrap/cleanup](docs/runbooks/bootstrap.md).
4. [Architecture](docs/architecture/README.md) and [decisions](docs/decisions/) for longer-term intent.

Older AKS inventories and 37-resource plan results are historical, not the current plan. Follow the current milestone when older documents differ.

## Checkpoint: 2026-09-28

Repository: https://github.com/kxw9298/enterprise-ai-platform-poc (private), working branch at checkpoint: `main`.

Completed and pushed:
- `2989ebe`: Foundry/internal-APIM first milestone, client identities, limits, test script and documentation.
- `b6fccb5`: restored deferred AKS/ACR/MCP resources and related inputs/outputs as comments.

Prepared Terraform creates:
- One VNet, internal APIM Developer (one unit), private gateway DNS.
- Foundry AIServices resource, project and `gpt-4.1-mini` version `2025-04-14`, GlobalStandard capacity 1.
- Blocking prompt/completion content filters; managed-identity APIM → Foundry authentication.
- Application Insights and Log Analytics; per-client usage traces and estimated-cost query.
- Bastion Basic, private Linux jump VM and two user-assigned test identities attached to it.
- Default per-client limits: 10 requests/minute, 1,000 tokens/minute, 10,000 tokens/day. Streaming is rejected for the initial accounting test.

No active AKS, ACR, MCP API, RAG or Copilot networking. Optional jump-VM NAT egress is disabled. GlobalStandard does not guarantee single-region inference processing. Both test identities share the trusted VM; this is attribution testing, not tenant isolation.

Last known deployed state: bootstrap resource group/storage/container/OIDC app and role assignments, plus empty `rg-ai-platform-poc`. Terraform state tracks the workload resource group only. **The prepared Foundry/APIM platform has not been applied and no live model endpoint test has run.** Recheck Azure/state before acting; this snapshot can become stale.

Validation completed:
- Azure-backed local plan: **31 to add, 0 to change, 0 to destroy**, existing group unchanged; CI scope guard passed.
- Terraform schema validation, three mocked lifecycle tests, rendered policy checks and plan-guard tests passed.
- After restoring comments, Terraform validation passed again; comments do not activate resources.
- GitHub Actions plan [36504225341](https://github.com/kxw9298/enterprise-ai-platform-poc/actions/runs/36504225341) passed at `ac64c66`. Apply has not been dispatched.
- A successful plan does not prove APIM policy runtime behavior, safety filtering, quota/capacity or live token accounting.

## Latest provisioning attempt

The user authorized provisioning through GitHub Actions. Provider registration was requested and the plan passed. Automatic approval review blocked the Entra API registration and persistent RBAC prerequisite changes pending explicit approval of their scopes. No rejected security operation ran. Read [deployment checkpoint](docs/runbooks/deployment-checkpoint.md) for the exact approval needed; do not bypass the rejection.

## Next work, in order

1. Inspect `git status`, recent commits and the latest user request. Confirm actual Azure state and GitHub configuration without printing credentials.
2. Configure the one-time Entra API app registration when authorized, following the milestone runbook. Check for an existing app first to avoid duplicates. No client secret is needed. It is separate from the GitHub OIDC application and persists outside Terraform; cleanup is documented.
3. Set the real API audience: for the documented v2 configuration, `TF_VAR_api_audience` / GitHub `MODEL_API_AUDIENCE` is the app UUID; the managed-identity token request resource is `api://APP_UUID`. The current placeholder is for planning only and cannot enable working authentication.
4. Resolve deployment prerequisites: provider registration, scoped pipeline role-assignment permissions, subscription deleted-service purge permissions, compute quota/capacity and current regional costs. `scripts/infra/preflight.sh` is read-only. The pipeline currently lacks required workload role-assignment and purge rights; do not silently grant broad Owner access.
5. Run/review a fresh plan, preferably also through GitHub OIDC. Apply only within the user's authorization and the workflow's reviewed-commit controls.
6. From the Bastion jump VM, test both client IDs with `scripts/model-gateway/test-endpoint.py`; verify missing/unauthorized tokens fail, identity-header spoofing cannot change attribution, safety filters work and rate/token limits enforce expected responses.
7. Query per-client usage with `queries/model-cost-by-client.kql`, insert dated model prices, and compare with available backend telemetry. Estimates are not invoices; rate/token limits are not exact dollar caps. Record actual evidence, including failures and accounting gaps.
8. Export needed evidence before authorized teardown. `down` removes platform resources but retains the foundation; `destroy` also removes the Terraform-managed workload group. Bootstrap and the API registration require separate cleanup. Stopping a VM does not stop APIM/Bastion billing.

## Files and validation commands

- Active root: `infra/poc`; module: `infra/modules/platform`.
- Workflow: `.github/workflows/terraform-poc.yml` (manual dispatch on main).
- Deferred code: commented `aks.tf`, MCP blocks in `gateway.tf`, subnet, variables, inputs and outputs. Re-enable together, then revise `scripts/ci/platform-resources.json`, provider preflight, authorization and documentation.
- Local tools at checkpoint: `.local/tools/terraform/1.16.4/terraform`; AzureRM lockfile pins 5.7.0. Use the pinned version, not an older system Terraform.

From the repository root (after installing/initializing dependencies when on a new machine):

```bash
export TERRAFORM_BIN="$PWD/.local/tools/terraform/1.16.4/terraform"
"$TERRAFORM_BIN" fmt -check -recursive infra
"$TERRAFORM_BIN" -chdir=infra/poc validate
"$TERRAFORM_BIN" -chdir=infra/poc test
python3 tests/terraform/policy-render.py
bash tests/terraform/check-plan.sh
# Requires cached Azure CLI authentication and ignored bootstrap config:
# export TF_VAR_publisher_email=... (and real TF_VAR_api_audience for deployment)
bash scripts/infra/plan.sh plan
```

Local plan helper uses cached `az login` authentication; GitHub uses OIDC. Backend state uses Entra access rather than storage keys. Do not switch authentication models casually.

Ignored machine-local files (not available to an agent on a fresh checkout):
- `.local/bootstrap/backend.hcl` and `github-variables.json`: backend/configuration records.
- `.local/ssh/poc-jump`: private SSH key; never print, commit or upload it. Public companion `.pub` is configured as GitHub `JUMP_SSH_PUBLIC_KEY`.
- `.local/plans/` and local logs: never commit/upload saved plans or state.
- `.local/model-api/`: intended record of API registration setup; its presence is not proof setup succeeded.

GitHub configuration at checkpoint includes bootstrap variables, publisher email and jump public key. The real `MODEL_API_AUDIENCE` has not been configured. An obsolete AKS admin variable may still exist but is unused. Discover IDs through authorized local configuration/GitHub variables rather than requiring secrets in this file.

## Handoff discipline

Before ending a session, update this checkpoint when scope or state changes. Record completed commits, validation results, pending prerequisites and the exact next action. Clearly separate prepared code, planned resources, deployed resources and runtime-tested behavior. Never fabricate success when a tool is blocked by rate limits or permissions; leave a precise continuation note. An agent on another machine needs its own authorized login and local setup—this file transfers context, not credentials or execution state.
