# Agent instructions and handoff

This file is the entry point for any coding agent continuing this POC, including after a rate limit or session reset. Read it before changing infrastructure. It is a handoff, not authorization to deploy or destroy resources. The user's latest instructions take precedence.

## Goal and working preferences

The eventual goal is Copilot Studio → APIM → internal MCP hosted on AKS, with APIM also serving as an AI model gateway and attributing tokens and estimated costs per client. Keep a simplified enterprise-style landing zone that can be spun up and torn down to save money.

**Current milestone — phase 1:** validate Standard Copilot Studio private connectivity to Azure through the delegated Power Platform networks and internal APIM. The Container Apps foundation is partially provisioned; the sample MCP app is not deployed. Follow [the two-stage deployment runbook](docs/runbooks/container-apps-deployment.md). AKS is phase 2: code is preserved but `enable_mcp_runtime=false` by default in Terraform and GitHub Actions. Foundry, Bastion and API-key cost reporting remain deferred. Read [phase-one scope](docs/runbooks/phase-one-private-connectivity.md) first.

**Status 2026-09-30 (2026-10-01 UTC): foundation apply partially failed.** Fresh GitHub plan [36793607370](https://github.com/kxw9298/enterprise-ai-platform-poc/actions/runs/36793607370) at `ce5c0d9` passed (40 add, 1 update, 0 destroy). Authorized apply [36793776199](https://github.com/kxw9298/enterprise-ai-platform-poc/actions/runs/36793776199) passed OIDC, effective quota-read preflight and scope guard, then failed: Container Apps reported `ManagedEnvironmentCapacityHeavyUsageError` in East US, and APIM creation found the old soft-deleted name while automatic recovery is disabled. This is regional capacity, not an AKS deployment or the SandboxCores quota. No retry or region migration has been performed. See the latest checkpoint below.

- Keep paid workloads in East US; the required West US Power Platform spoke is the regional exception. Avoid Premium tiers where practical and explain idle costs.
- Keep APIM internal. Optional Bastion/jump access is disabled by default; private AKS deployment requires an in-VNet runner or equivalent access.
- Preserve optional/deferred Terraform code with explanatory notes. AKS/ACR is now phase 2 and disabled by default; Foundry remains optional and API-key attribution remains deferred.
- Explain steps plainly; the user wants to understand the resources and identity flow.
- Python is acceptable. Do not rewrite working scripts just to change language.
- Never commit secrets, tokens, private SSH keys, Terraform state, saved plans or local configuration. Tenant/subscription/client IDs are identifiers, not credentials.
- Commit and push completed requested work when authorized; respect unrelated working-tree changes. Do not infer authorization to apply, grant access or destroy from a request to prepare or commit code.

## Latest preference: API-key usage and cost attribution (deferred)

The user wants usage and estimated cost tracked by **API key**, using a separate APIM subscription for each client/reporting unit. Attribute telemetry to the validated APIM subscription ID rather than logging raw subscription keys. Primary and secondary keys on the same subscription share attribution, preserving reporting through key rotation; separate reporting requires separate subscriptions.

**Do not implement this change yet.** This is a recorded future requirement only. The current Terraform policies and tests use Entra client IDs; do not claim API-key attribution is already implemented or verified. When the user requests implementation, update subscription configuration, usage telemetry, estimated-cost queries and relevant per-client limits/tests together. Decide how subscription keys coexist with Entra authentication at that time; this preference alone does not authorize removing token validation.

This preference supersedes older documents describing Entra client ID as the final reporting identifier. Cost remains an estimate derived from token usage and dated model prices, not an invoice split or an exact spending cap.

## Read next

1. [Phase-one scope and acceptance checks](docs/runbooks/phase-one-private-connectivity.md) — authoritative current scope.
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

Last known deployed state: bootstrap resource group/storage/container/OIDC app and role assignments, plus `rg-ai-platform-poc` and the 31 platform resources. Terraform state tracks the workload resource group only. **Apply [36504873891](https://github.com/kxw9298/enterprise-ai-platform-poc/actions/runs/36504873891) completed 2026-09-29T01:18:19Z: 31 added, 0 changed, 0 destroyed.** All 31 resources were verified live and the endpoint passed its first authenticated call. No competing Terraform operation is in flight. Recheck Azure/state before acting; this snapshot can become stale.

**Since superseded:** the platform was torn down on 2026-09-29 to stop billing. See [Teardown](#teardown-2026-09-29) below for what remains and what failed.

Validation completed:
- Azure-backed local plan: **31 to add, 0 to change, 0 to destroy**, existing group unchanged; CI scope guard passed.
- Terraform schema validation, three mocked lifecycle tests, rendered policy checks and plan-guard tests passed.
- After restoring comments, Terraform validation passed again; comments do not activate resources.
- GitHub Actions plan [36504225341](https://github.com/kxw9298/enterprise-ai-platform-poc/actions/runs/36504225341) passed at `ac64c66`. The apply that followed completed successfully; see the provisioning attempt below.
- A successful plan does not prove APIM policy runtime behavior, safety filtering, quota/capacity or live token accounting.

## Latest provisioning attempt (completed)

The user authorized provisioning through GitHub Actions. Provider registration was requested and the plan passed. The user explicitly approved the previously blocked security changes. The secretless API registration, audience variable, conditioned RG delegation and subscription purge rights are now configured. Read [deployment checkpoint](docs/runbooks/deployment-checkpoint.md) for records and cleanup. All required providers are registered and regional/VM-family quota is sufficient for the two-vCPU jump VM. The final plan passed with 31 additions at `d1cab08`. Apply [36504873891](https://github.com/kxw9298/enterprise-ai-platform-poc/actions/runs/36504873891) passed preflight and **completed 2026-09-29T01:18:19Z: 31 added, 0 changed, 0 destroyed.** That run is finished; do not start a competing Terraform operation against the same state.

## Live endpoint verification (2026-09-28)

Run from the Bastion jump VM as `pocadmin`. All values below are identifiers, not secrets.

| Check | Result |
| --- | --- |
| Private DNS resolution | `apim-aipoc-247fda1b.azure-api.net` → `10.42.4.4` |
| Request without a token | `401`, `AppRequests.Success` false |
| `AppExceptions` entry | `TokenNotPresent at validate-azure-ad-token` — that deliberate 401 test, not a fault |
| Authenticated call, client A | `200` twice, 2463 ms then 851 ms |
| Response | content `hello`, model `gpt-4.1-mini-2025-04-14` |
| Content safety | hate/self-harm/sexual/violence all `safe`; `prompt_filter_results` and `content_filter_results` both present |
| Per-client attribution | `client_id` = client A on every `Model usage` trace |
| Token accounting | 2 requests, 31 input / 25 output tokens, `MissingUsageRequests` 0 |
| Cost query | `queries/model-cost-by-client.kql` returns that row from the live workspace |

**Not yet verified:** client B, throttling (`429`), per-client limit isolation, token quota (`403`), `x-client-id` spoofing, streaming rejection, and a blocked-prompt safety case. The stack was torn down before these ran, so each needs a recreated environment; do not report them as passing.

## Accessing the platform and testing the endpoint

Bastion is Basic, so access is a browser session and there is no native client path.

- `az network bastion tunnel` fails by design with `Bastion Host SKU must be Standard or Premium and Native Client must be enabled`. There is no `scp` either. Use the VM's **Connect → Bastion** page, **SSH**, auth type **Private Key** (not password, not Entra ID), user `pocadmin`.
- The key is `.local/ssh/poc-jump`. The browser file picker hides dotfiles, so copy it somewhere visible first (for example `~/Downloads/`), paste that path, and delete the copy afterwards. It is a real private key; never print or commit it.
- The jump VM has no Internet egress (`enable_jump_egress=false`, no NAT gateway) and no `curl`, so the test script cannot be downloaded there. IMDS *is* reachable over the VNet, so mint the token inline. `scripts/model-gateway/test-endpoint.py` stays the canonical reference; its `--requests 12` is how throttling should be exercised once it can be transferred.

Verified smoke test — substitute the client-B UUID for the second identity:

```bash
APPID=5c73597b-43b3-4742-bc3a-fc237089733e
AUD=api://105fe078-6b68-4bd9-844c-aa4c2a0f80b8
HOST=https://apim-aipoc-247fda1b.azure-api.net
python3 - "$APPID" "$AUD" "$HOST" <<'PY'
import json, sys, urllib.request, urllib.error
appid, aud, host = sys.argv[1:4]
tok = json.load(urllib.request.urlopen(urllib.request.Request(
    "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=" + aud,
    headers={"Metadata": "true"})))["access_token"]
body = json.dumps({"messages": [{"role": "user", "content": "Reply with the word hello."}],
                   "max_tokens": 16, "stream": False}).encode()
req = urllib.request.Request(host + "/models/chat/completions", data=body, headers={
    "Authorization": "Bearer " + tok, "Content-Type": "application/json",
    "x-client-id": "spoofed-value"})
try:
    r = urllib.request.urlopen(req)
    print("HTTP", r.status); print(r.read().decode())
except urllib.error.HTTPError as e:
    print("HTTP", e.code); print(e.read().decode())
PY
```

The `x-client-id` value is deliberately wrong. The model policy uses `exists-action="override"`, so APIM must replace it and the trace must still show the real client UUID.

Reading telemetry (from a machine with `az` signed in, not from the jump VM):

- **Allow 2 to 6 minutes for ingestion.** A zero-row check at 190 seconds is not evidence of failure; retry before investigating.
- Expect one `401` plus the successful `200`s in `AppRequests`, and one `Model usage` row per successful call in `AppTraces`.
- `queries/model-cost-by-client.kql` uses the Log Analytics schema (`AppTraces`, `TimeGenerated`, `parse_json(Properties)`). The Application Insights portal Logs blade presents the same data as `traces`/`customDimensions` and needs that form instead.

Two findings that should **not** be "fixed":

- `buffer-response="false"` in `infra/modules/platform/policies/model.xml.tftpl` is correct and working. The worry that `context.Response.Body` fails on an unbuffered response is disproven: token usage arrived fully populated on every live call (14 and 42 total tokens). Do not change it without a failing test.
- Telemetry shows `model_version` as `2025-04-14T00:00:00.0000000Z`, not the `2025-04-14` literal in the policy. APIM normalises it from the backend; that is expected, not drift.

Working-copy hazard: `~/Workspace/enterprise-ai-platform-poc` is a second clone with no `.local/` and no pinned toolchain. Both roots derive identical resource names from `sha256(subscription_id)`, so running Terraform from the wrong copy targets the same Azure resources. Work in `~/Documents/ChatGPT/AI Platform POC`.

## Teardown: 2026-09-29

The user asked for teardown to stop costs, so the platform was removed with `down` (`enable_platform=false`), which retains the resource group and the bootstrap foundation. A `down-plan` was reviewed first: `0 to add, 0 to change, 31 to destroy`.

**All billable resources are gone.** Verified after the fact: the Cognitive Services account list is empty, the APIM service is deleted, and Bastion, the jump VM, private DNS and the test identities are removed. The Foundry deployment and content filter were deleted too, so nothing is still accruing inference cost.

`down` needed three runs, all of which failed the apply step on a transient or permission problem rather than on a plan error. Worth knowing, because each one looks alarming in the logs:

1. `36511427631` — `deleting Api "model": 412 PreconditionFailed`. The API delete raced the concurrent logger/diagnostic deletes.
2. `36512343080` — `deleting Service: 409 ServiceLocked ... transitioning at this time`, immediately after the API was deleted. Waiting for `provisioningState` to return to `Succeeded` cleared it.
3. `36512593045` — the APIM service itself was deleted (about 13.5 minutes), then the **purge** step failed: `403 AuthorizationFailed` on `Microsoft.ApiManagement/locations/deletedServices/read`. This is a real role defect, not a transient one. The custom purge role grants the old subscription-scoped `Microsoft.ApiManagement/deletedservices/read`, and `preflight.sh` checked only the two `delete` actions. Both are now documented and `preflight.sh` checks all four read and delete actions. The role itself still needs an authorized administrator to correct; see [deployment checkpoint](docs/runbooks/deployment-checkpoint.md).

A follow-up `down-plan` confirms **Terraform state is clean** for APIM and Foundry, so a later apply will not try to reconcile deleted resources.

Still in `rg-ai-platform-poc`, all at **$0**: the VNet, the APIM network security group, the APIM subnet and its NSG association, plus an orphaned `Application Insights Smart Detection` action group left behind by the destroyed Application Insights component. They are cheap to keep and make the next apply faster, but `destroy` would remove the group itself. Deleting the API app registration, the custom roles and the bootstrap foundation are separate manual steps, documented in [bootstrap cleanup](docs/runbooks/bootstrap.md), and were not performed.

Pending local cleanup: `~/Downloads/poc-jump.pem` is a browsable copy of the Bastion private key. The server-side key was removed with the VM; delete this file.

## Historical model-first next steps (superseded by current revision)

1. Inspect `git status`, recent commits and the latest user request. Confirm actual Azure state and GitHub configuration without printing credentials.
2. Configure the one-time Entra API app registration when authorized, following the milestone runbook. Check for an existing app first to avoid duplicates. No client secret is needed. It is separate from the GitHub OIDC application and persists outside Terraform; cleanup is documented.
3. Set the real API audience: for the documented v2 configuration, `TF_VAR_api_audience` / GitHub `MODEL_API_AUDIENCE` is the app UUID; the managed-identity token request resource is `api://APP_UUID`. The current placeholder is for planning only and cannot enable working authentication.
4. Resolve deployment prerequisites: provider registration, scoped pipeline role-assignment permissions, subscription deleted-service purge permissions, compute quota/capacity and current regional costs. `scripts/infra/preflight.sh` is read-only. The approved conditioned workload role-assignment delegation and subscription purge rights are now configured; do not grant broad Owner access.
5. Run/review a fresh plan, preferably also through GitHub OIDC. Apply only within the user's authorization and the workflow's reviewed-commit controls.
6. Client A is proven end to end. Still untested against a live stack: client B, `x-client-id` spoofing, rate/token limit enforcement and a blocked-prompt safety case. Run them from the Bastion jump VM as described above.
7. `queries/model-cost-by-client.kql` now returns verified rows from the live workspace. Insert dated model prices to produce a cost estimate, and compare with backend telemetry. Estimates are not invoices; rate/token limits are not exact dollar caps. Record actual evidence, including failures and accounting gaps.
8. Teardown is complete for billable resources (see [Teardown](#teardown-2026-09-29)). If the milestone is resumed, `apply` recreates the platform; `destroy` would additionally remove the Terraform-managed workload group. The Entra API registration, the custom roles and the bootstrap foundation require separate cleanup. Stopping a VM does not stop APIM/Bastion billing.

## Files and validation commands

- Active root: `infra/poc`; local modules: network, platform, mcp-runtime, foundry and admin-access.
- Workflow: `.github/workflows/terraform-poc.yml` (manual dispatch on main).
- Active MCP infrastructure is in `mcp-runtime` and `platform`; historical AKS comments remain for reference. Foundry and admin access are optional modules, disabled by default.
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

GitHub configuration at checkpoint includes bootstrap variables, publisher email and jump public key. The real `MODEL_API_AUDIENCE` is now configured. An obsolete AKS admin variable may still exist but is unused. Discover IDs through authorized local configuration/GitHub variables rather than requiring secrets in this file.

## Handoff discipline

Before ending a session, update this checkpoint when scope or state changes. Record completed commits, validation results, pending prerequisites and the exact next action. Clearly separate prepared code, planned resources, deployed resources and runtime-tested behavior. Never fabricate success when a tool is blocked by rate limits or permissions; leave a precise continuation note. An agent on another machine needs its own authorized login and local setup—this file transfers context, not credentials or execution state.

## Power Platform next milestone (2026-09-29)

User confirmed environment `Default-eb241c67-e72d-4862-ae41-7686706624c4`, United States, Default type, and Managed Environments enabled after adding Dataverse/trial signup. Uses Standard agent `MCP Test Agent`; account has Power Automate Free and Copilot Studio Viral Trial. Publishing is unavailable; target is test-panel private MCP connectivity.

Prepared `infra/power-platform` as a separate persistent network foundation: two regional VNets/subnets and an enterprise policy, separate `power-platform.tfstate`. Nothing deployed or linked. Read its README for scope, permissions and teardown. Workload peering/private DNS, dedicated workflow and environment association remain to be implemented before a live test. This integration requires East US and West US; the one-region preference continues to apply to paid workload services. Do not re-enable AKS/MCP or implement API-key reporting incidentally.

## Current code revision: private MCP hub-and-spoke

The user requested code changes first, minimal cost, one root/state, hub APIM with AKS and two Power Platform spokes. `infra/poc` is now the sole active root. `module.network` persists through down; optional `platform.foundry` defaults false and optional `admin_access` defaults false. AKS/ACR code is active in `mcp_runtime`, controlled by enable_mcp_runtime and enable_platform; older comments are retained as reference. This supersedes the separate-root preparation and the old AKS-deferred scope. API-key reporting is still deferred.

Read [current MCP networking runbook](docs/runbooks/mcp-private-network.md) before proceeding. No apply, registration, environment linking or permission changes are authorized by this code-only turn. New role delegation, missing APIM purge read permission, private AKS deployment-runner access, quota/surge and the MCP image/application pipeline remain prerequisites. Do not claim this code deploys an MCP application or proves Copilot connectivity.

Refactor validation (2026-09-29): Azure-backed plan passed scope guard with 37 additions, 1 in-place hub address-space update and 0 destroys. Four old hub addresses map to module.network via moved blocks. Inventory verified four VNets, six peering directions, four APIM DNS links, private AKS API, two D4s_v7 nodes, and no default Foundry/Bastion/jump VM/NAT. This is a NEW 37-resource plan, not the historical external-APIM plan. Five mocked lifecycle tests, schema validation, rendered-policy and plan-guard tests passed. No apply performed.

## Latest prerequisite check (2026-09-29)

Current subscription remains FreeTrial with spending limit On. East US regional and StandardDsv7Family limits both 4, used 0; planned AKS needs 8 base/12 with surge. User must decide on pay-as-you-go upgrade before a quota increase; never silently upgrade billing. Three new providers remain NotRegistered. Prepared `scripts/bootstrap/prepare-mcp.py`; live review mode passed. Apply was rejected by automatic approval review, requiring explicit approval for provider registration, adding Network Contributor/Managed Identity Operator/AcrPull to existing RG-scoped SP-only role delegation, and the missing subscription purge read permission. No Azure mutations occurred. Do not retry or work around the rejection without approval. The new script/documentation is the reviewable result. It does not provision workloads or link Power Platform. See current networking runbook for exact command and scope.

Read-only GitHub OIDC plan [36652580935](https://github.com/kxw9298/enterprise-ai-platform-poc/actions/runs/36652580935) completed successfully at infrastructure commit `62b2767f05c1b1b6c40d3aad77b796fad41e9098`. Prerequisite script passed five local tests (read-only review, scope/condition/action rejection and write/delete SP constraints). Provider/RBAC apply remains unexecuted; quota remains insufficient.

## Container-service alternative requested

User asked to try Azure container services because AKS exceeds Free Trial VM quota. Read [runtime alternative](docs/architecture/container-runtime-alternative.md). Read-only East US checks found Container Apps managed-environment limit 0 with Microsoft.App NotRegistered; Container Instances Standard Cores 0 with its provider NotRegistered. Prefer small Consumption Container Apps with private VNet ingress, but recheck after explicitly approved Microsoft.App registration before claiming eligibility. No Terraform runtime changes or cloud mutations occurred. Do not execute the previously prepared AKS permission expansion for this alternative. Earlier automatic review rejected provider/RBAC mutations; obtain explicit approval for the narrowed registration, without working around that rejection.

## Phase split confirmed

The user explicitly moved AKS to phase 2 and made Copilot Studio private connectivity the phase-one goal. `enable_mcp_runtime` now defaults false in Terraform and workflow inputs; preflight no longer demands AKS providers/VM quota under that default. AKS/ACR code and explicit opt-in remain. Read `docs/runbooks/phase-one-private-connectivity.md`. The workload spoke remains reserved; no Container Apps implementation or real MCP endpoint exists yet. The APIM backend still needs to be changed from its reserved AKS address when the phase-one runtime is added. No cloud mutation or apply in this revision.
Validation of phase split: six mocked lifecycle tests passed (including explicit phase-two AKS opt-in), scope-guard/policy checks passed, and an Azure-backed plan passed with 30 additions, 1 update and 0 destroys. Confirmed no module.mcp_runtime resources in plan. This is infrastructure scaffolding, not a complete runnable phase-one MCP deployment. A transient provider file-read timeout on the first test attempt cleared on retry.


## DNS and registry handoff (2026-09-30)

Recorded the latest discussion in the phase-one runbook: use Azure-provided DNS and link the APIM private zone to BOTH Power Platform regional VNets. Existing Terraform already links that exact-hostname zone to all four VNets. VNet peering alone does not provide private DNS visibility. APIM will separately resolve the Container Apps backend using an environment zone linked to the hub; that backend DNS/runtime is not implemented yet. No DNS Private Resolver is planned. Environment association and actual Copilot tool-path verification remain required; no working connectivity is claimed.

Internal Container Apps will reuse the workload VNet with its own delegated `/27` or larger subnet, not an AKS/APIM/Power Platform subnet. ACR is optional; if selected, move its ownership out of the disabled AKS module into a shared module before enabling it for phase one. Do not turn on AKS just to obtain a registry. AKS code remains preserved and disabled for phase two. This documentation update does not authorize pending provider/RBAC changes or provisioning.


## Microsoft.App registration completed (2026-09-30)

User explicitly approved registering only Microsoft.App and rechecking quota. Registration is now verified Registered. East US ManagedEnvironmentCount reports limit 1, currentValue 0, superseding the earlier pre-registration zero. No quota-increase request, billing upgrade, role change, other provider registration, environment association or workload deployment occurred. The earlier approval block for this narrow registration is resolved; it does not authorize the old AKS RBAC expansion. Next: prepare the private Container Apps runtime and sample MCP image pipeline, preserving disabled AKS. Per-environment consumption-core quota/capacity and runtime behavior remain unverified until deployment checks.


## Container Apps implementation prepared (2026-09-30)

This supersedes older notes saying Container Apps/DNS are not implemented. New local `container-apps` and shared `registry` modules prepare the internal Consumption environment, delegated workload subnet 10.45.0.64/27, private DNS, ACR Basic and a pull identity with AcrPull. AKS remains disabled and preserved, now consuming the shared registry. A moved block preserves ACR ownership if an older runtime state exists.

The first apply uses empty `mcp_image_digest`: foundation only, no fake MCP image/app; authenticated APIM calls get 503 until ready (empty caller allowlist stays 403). The manual MCP image workflow builds/tests a non-root Linux image; publish=false needs no Azure access, publish=true uses OIDC/AcrPush and reports a digest. Pass that exact digest to both Terraform plan and apply; no out-of-band app update. Repeat digest on later normal runs. Down deletes ACR/images too, so rebuilding requires foundation-only → image build/push → app apply again.

Sample service at services/mcp/connectivity uses official MCP SDK 2.2.0, locked transitive dependencies, stateless Streamable HTTP and only get_status. APIM authenticates and overwrites correlation ID; app ingress allows only APIM subnet, environment has public access disabled. Runtime Copilot authentication, actual ingress source IP and cold starts still require live validation.

Read docs/runbooks/container-apps-deployment.md before applying. **Superseded 2026-09-30:** ContainerRegistry/PowerPlatform registration, the narrowed AcrPull delegation and the APIM purge read correction were all applied — see [Approvals executed](#approvals-executed-2026-09-30). Still pending: pipeline subscription-scoped Container Apps quota-read permission, and later registry-scoped AcrPush for image publication. prepare-mcp.py defaults to container-apps (only AcrPull added); `--runtime aks` is explicit phase two. During this implementation turn specifically, no grants, registrations, apply, image publication or environment association were made.

Local validation: nine Terraform lifecycle tests, five real HTTP MCP tests, five prerequisite-script tests, rendered APIM policy and plan guards passed. Azure-backed plans: foundation 40 additions / 1 hub update / 0 destroys; app-enabled plan uses a synthetic digest for validation only (not an existing image). Docker CLI on this host failed before building; GitHub build-only validation is the intended container test.


Container build verification: GitHub Actions [36719934403](https://github.com/kxw9298/enterprise-ai-platform-poc/actions/runs/36719934403) succeeded at `4cf697d` with `publish=false`: Linux image build and in-container MCP smoke tests passed; no Azure login/push/apply. The initial dispatch exposed an unsupported runner context in job-level env; this was corrected by setting DOCKER_CONFIG after runner initialization. Foundation/app-enabled Azure plans were 40/41 additions respectively, 1 hub update, 0 destroys. The app-enabled plan used a synthetic test digest only; no deployable ACR image has been published yet. Local test server was stopped.

## Approvals executed (2026-09-30)

The user explicitly approved the ContainerRegistry/PowerPlatform registrations, the narrowed AcrPull delegation and the APIM purge read correction, and authorized execution. All three were applied with `scripts/bootstrap/prepare-mcp.py --apply` from the `~/Workspace/enterprise-ai-platform-poc` clone at `dbd5759`. Verified independently of the script's own checks:

- `Microsoft.App`, `Microsoft.ContainerRegistry`, `Microsoft.PowerPlatform` all report Registered.
- `AI POC Deleted Service Purge` carries five actions at the unchanged subscription scope, adding `Microsoft.ApiManagement/locations/deletedServices/read`. `notActions` and `dataActions` remain empty. The existing subscription-scope assignment was **not** recreated.
- `AI POC Gateway Role Delegation` at `rg-ai-platform-poc` remains principalType ServicePrincipal and conditionVersion 2.0, now listing three role GUIDs: Monitoring Metrics Publisher, Cognitive Services OpenAI User and AcrPull. Both the write and delete clauses still constrain to ServicePrincipal.
- `preflight.sh` exits 0 for `plan`, `down`, `destroy` and `apply`.

No workload, ACR, environment or Power Platform resource was created. Still no billable resource in `rg-ai-platform-poc`.

### Working-copy hazard, restated

The canonical `~/Documents/ChatGPT/AI Platform POC` checkout became unreadable on this host (macOS TCC returns `Operation not permitted` for directory and file reads; metadata still resolves). All of the above was therefore done from `~/Workspace/enterprise-ai-platform-poc`, fast-forwarded to `origin/main` at `dbd5759` first. That clone has no `.local/`, so it has no pinned Terraform 1.16.4 and no `backend.hcl`; Terraform plan and apply were not run from it. Prefer the canonical path once access is restored. Both roots derive identical resource names from `sha256(subscription_id)`, so never run Terraform against the wrong copy.

### `prepare-mcp.py` bugs found on first real apply

Review mode passed and exited 0, but it never constructs the mutation payloads, so two defects only appeared under `--apply`:

1. The purge role payload used `Name`/`Id`/`IsCustom`. `az role definition update` lowercases first letters, then requires **`roleName`** when an `id` is present, raising `KeyError: 'roleName'` before any ARM call. Fixed to the SDK's own casing; `IsCustom` was dropped because the CLI hardcodes `type='CustomRole'`.
2. Verification read back once and asserted, which fails against ARM eventual consistency — the update had already landed. It now polls, and additionally confirms provider registration converges rather than only advising a recheck. `Microsoft.PowerPlatform` registration in particular took several minutes.

Both are covered by new `ApplyPayloadTests` in `tests/bootstrap/test_mcp_prerequisites.py`, raising the suite from five tests to nine: payload schema, ServicePrincipal-only condition, only-unregistered-providers registration, and no further writes on an already-converged state.

### Ingress decision (supersedes the private-endpoint discussion)

The user asked to replace the Container Apps ingress with an Azure Private Endpoint. That was based on an incorrect premise in an earlier agent message, and the user then chose to **keep the existing internal-LB ingress**.

`external_enabled = true` on an app inside an environment with `internal_load_balancer_enabled = true` and `public_network_access = "Disabled"` does **not** expose the app publicly. Per Microsoft's ingress documentation, that combination makes the app reachable from the virtual network through the environment's internal load balancer, and the environment has no public endpoint. The `10.42.4.0/27` ingress restriction is defence in depth, not the primary control. The DNS zone named after `default_domain` with a wildcard `*` A record to `static_ip_address` is also the documented pattern for a non-custom-domain internal environment.

Do not add a `azurerm_private_endpoint` or switch the environment to external accessibility without a fresh decision. Environment accessibility cannot be changed after creation, so that remains the one genuine reason to revisit it later. If a private endpoint is ever added, the correct zone is `privatelink.{region}.azurecontainerapps.io` and the subresource is `managedEnvironment`; note the delegated workload subnet is `10.45.0.64/27`, the documented minimum, so a PE would want its own subnet rather than sharing it.

### Next action

**Historical blocker, resolved by the approved quota-read role update below.** Effective access still needs verification with a fresh pipeline login.

`preflight.sh` branches on operation. With `OPERATION=apply` and `enable_container_apps=true` it additionally calls:

```
az rest --method get --url ".../subscriptions/<sub>/providers/Microsoft.App/locations/eastus/usages?api-version=2025-07-01"
```

That is `Microsoft.App/locations/usages/read` at **subscription** scope. The GitHub OIDC principal holds only `AI POC Resource Group Writer` and `AI POC Deleted Service Purge` at subscription scope, and between them it has **zero** `Microsoft.App/*` actions — the only location-ish action is `Microsoft.Resources/subscriptions/locations/read`, a different provider. Under `set -euo pipefail` a 403 on that call aborts preflight before the quota check evaluates, so the apply fails at preflight. A successful **plan does not prove this**, because the plan path never enters this branch; run `preflight.sh` with `OPERATION=apply` if you want to see it fail.

The quota check itself would pass: `ManagedEnvironmentCount limit=1 current=0`.

Recommended fix: after explicit permission approval, append `Microsoft.App/locations/usages/read` to the existing `AI POC Resource Group Writer` role definition. The bootstrap definition in `scripts/bootstrap/setup.sh` now includes this action, so the approved live definition and future bootstrap runs can agree. Same definition-update mechanism already used for the purge role, no new role and no new assignment, and existing assignments reference the updated definition after RBAC propagation. This is still an RBAC change and needs the user's explicit approval; it was raised but not approved. Do not work around it by weakening `preflight.sh` — that check is what stands between the user and a silent capacity failure.

### Quota observations (corrected after review, 2026-09-30)

`az rest` against the Container Apps usage API for East US reports:

| Quota | Limit | Current |
| --- | --- | --- |
| ManagedEnvironmentCount | 1 | 0 |
| SandboxCores | **1** | 0 |
| ExpressEnvironmentCount | 450 | 0 |

`SandboxCores` is a separate Sandboxes quota, not the managed environment's Consumption-core allowance. The subscription-level response above therefore does not establish our app's compute ceiling. Read **Managed Environment Consumption Cores** after the environment exists with `az containerapp env list-usages --resource-group rg-ai-platform-poc --name cae-aipoc-<suffix>`. Two single-replica revisions at the configured 0.25 vCPU total 0.5 vCPU; the earlier assertion that they exceed one core was incorrect. Review total active replicas across the environment and actual available quota before rollout, without claiming overlap is prohibited.

### Remaining sequence to phase-one connectivity

The app cannot be in the first apply: deploying it needs an image, pushing an image needs a registry, and the registry is created by the foundation apply.

1. Completed after explicit approval: add `Microsoft.App/locations/usages/read` to the existing subscription-scoped role. Verify effective access on the next fresh pipeline login.
2. Foundation-only apply with an empty `mcp_image_digest`. Creates ACR, the internal Container Apps environment, the delegated workload subnet, private DNS zones and links, internal APIM with the MCP API and policy, App Insights and Log Analytics — but **no MCP app**. **This is the first billable step**; ACR Basic and telemetry bill.
3. Verify the environment is internal-only and read its consumption quota.
4. Build and publish a real image digest. Needs registry-scoped `AcrPush` — **still a separate approval**, distinct from the AcrPull already delegated.
5. Re-run apply with that exact digest; this is what adds the app. Never set the app out of band.
6. Live-test through APIM, then link the Power Platform environment and test Copilot Studio.

Between steps 2 and 5 the private wildcard DNS record resolves the backend hostname to the environment IP, but the MCP app does not exist. The explicit APIM backend-not-deployed policy returns `503` to trusted callers; an empty caller allowlist still returns `403`. That is the intended intermediate state, not a fault; do not "fix" it.

Note that `down` deletes the ACR and its images, so any later rebuild repeats steps 2, 4 and 5.


## Review corrections (2026-09-30)

Corrected the SandboxCores/Consumption quota mix-up and revision CPU arithmetic. The actual environment Consumption quota is still unknown. Updated the source-controlled bootstrap subscription role to include Microsoft.App/locations/usages/read and kept exact permission validation: extra permissions and the legacy definition missing this action fail closed. This is a code change only, not an Azure grant. An administrator must apply the explicitly approved live role update before rerunning setup against the existing role; setup does not migrate it automatically. Canonical Documents checkout is readable again and was fast-forwarded to 077907e before these fixes. No Azure mutations or Terraform apply in this review-fix turn.

Review-fix validation: 25 mocked bootstrap integration checks and 9 prerequisite-script tests passed; shell syntax and diff whitespace checks passed. No cloud access was needed for these tests.


## Approved quota-read permission applied (2026-09-30)

User explicitly approved the single quota-read action. Updated existing role `AI POC Resource Group Writer c38dc8cb9cf7` (ID `7c56d0d5-de45-43c9-a720-1928b428f78d`) in place, adding only `Microsoft.App/locations/usages/read`. Independently reread and compared: role ID, subscription scope, description, previous actions, exclusions and data permissions are unchanged. Pipeline principal `124dede3-5033-431e-b267-9ef7e8eaeddf` retains its existing assignment `bf438a24-1c86-5b48-8567-8b9014ca3a4f`; no new assignment was created. Before/update/after records are ignored under `.local/deployment-prerequisites/quota-reader-*.json`.

The live definition now matches the bootstrap source. This resolves the outstanding grant approval, but a fresh GitHub OIDC login must still prove effective permissions after propagation; that test has not been run in this turn. No workload apply, image publication, AcrPush grant or environment association occurred. Next: fresh foundation plan and preflight before authorized deployment; AcrPush remains a separate prerequisite after ACR exists.


## Partial foundation apply checkpoint (2026-09-30 / 2026-10-01 UTC)

Run 36793776199 completed with failure; no apply is running. Live inventory verified after failure: four VNets, APIM NSG, Power Platform enterprise policy, ACR `craipoc247fda1b`, image-pull identity, Log Analytics and Application Insights exist. Container Apps environment `cae-aipoc-247fda1b` exists with provisioningState `Failed` and the regional capacity error. APIM is not active; its old soft-deleted name remains reserved. The action group from the earlier deployment also remains. ACR and telemetry may incur charges; do not describe this as nothing deployed.

No MCP app/image, AKS, Foundry, AcrPush grant or Power Platform environment association was created. Actual environment Consumption quota remains unverified because environment provisioning failed.

Recovery must account for Terraform's partial state and the failed environment: inspect a refreshed plan before retrying, including any required replacement/import cleanup. Do not bypass destructive-plan guards or manually delete the failed environment without checking state. East US is the current documented region preference; an alternate-region design requires a decision and a reviewed migration plan, not a blind global location change. APIM needs deliberate recovery or purge of the previous soft-deleted instance before creation can succeed. No purge or recovery was performed in this attempt. If pausing, use a reviewed down-plan/down to stop workload costs; verify cleanup of the failed environment and its managed resource group.
