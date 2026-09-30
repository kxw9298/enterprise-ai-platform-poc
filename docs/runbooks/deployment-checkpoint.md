# Deployment checkpoint: 2026-09-28

The user requested provisioning through GitHub Actions. The [plan run](https://github.com/kxw9298/enterprise-ai-platform-poc/actions/runs/36504225341) succeeded at commit `ac64c66`. That initial run was plan-only; see the current deployment status below.

Registration was requested for Microsoft.Network, Microsoft.Compute, Microsoft.ApiManagement, Microsoft.OperationalInsights, Microsoft.Insights and Microsoft.ManagedIdentity. CognitiveServices was already registered. Recheck completion before apply.

## Approved prerequisite setup

The user explicitly approved the following changes after the initial automatic approval rejection. They are now configured:

1. Create a single-tenant, secretless Entra API registration and its service principal named `enterprise-ai-poc-model-api`; set its `api://APP_UUID` identifier and v2 token format. Save the non-secret UUID in GitHub `MODEL_API_AUDIENCE`.
2. Create a custom role and grant it to the existing GitHub OIDC service principal **only at `rg-ai-platform-poc`**. It permits role-assignment read/write/delete and role-definition read. Enforce a condition on both write and delete limiting assignments to service principals and these two roles: Cognitive Services OpenAI User (`5e0bd9bd-7b93-4f28-af87-19fc36ad61bd`) and Monitoring Metrics Publisher (`3913510d-42f4-4e42-8a64-420c390055eb`). This is persistent delegation to assign those roles within the group, not Owner access and not restricted to a single future APIM principal.
3. Create a separate custom role and subscription-level assignment for the pipeline, granting read/delete of soft-deleted APIM services and Cognitive Services accounts. These APIs require subscription-level access for repeatable teardown/name reuse. **This allows permanent purging of matching deleted services throughout the subscription**, not just this POC. No purge is performed during setup; the permission persists until removed.

Record all created app, custom-role and assignment IDs under ignored local records and document their cleanup. These additional custom roles and the model API app are not automatically covered by the existing bootstrap cleanup script. Before final bootstrap retirement, remove the recorded extra assignments, then extra role definitions and API app after checking dependencies. Preserve backend/state until workload teardown finishes. Provider registrations remain subscription-wide.

After approval: configure prerequisites, confirm quota/capacity, run a new plan using the real API audience, review it, then dispatch apply with the exact reviewed commit SHA. Record the workflow URL and actual outcome. Live endpoint tests remain pending until resources exist.

Condition syntax reference: [Microsoft conditional role delegation examples](https://learn.microsoft.com/en-us/azure/role-based-access-control/delegate-role-assignments-examples).

## Approval execution

All seven required providers are registered. East US regional and StandardDsv7Family quotas each report four available vCPUs; the jump VM requests two. The secretless API registration and GitHub audience variable are configured, as are the conditioned RG delegation and subscription purge assignments. Azure rejected the old APIM action name; the supported permission is `Microsoft.ApiManagement/locations/deletedservices/delete`, now corrected in preflight.

**Defect found 2026-09-29 during teardown; fixed 2026-09-30.** The custom role `AI POC Deleted Service Purge` granted `Microsoft.ApiManagement/deletedservices/read`, the old subscription-scoped name, but Terraform's purge step calls `Microsoft.ApiManagement/locations/deletedServices/read`. The `down` run therefore destroyed the APIM service and then failed with `403 AuthorizationFailed` on the purge. `preflight.sh` did not catch it because it checked only the two `delete` actions and never the `read` actions. The correction, applied through `scripts/bootstrap/prepare-mcp.py --apply`:

1. `Microsoft.ApiManagement/locations/deletedServices/read` was appended to the role definition; the Cognitive Services `deletedAccounts/read` was already location-scoped and is unchanged.
2. The role assignment was left in place. Azure custom role *definition* updates take effect immediately for every assignment referencing that role, so no re-assignment was required; only RBAC propagation and a fresh pipeline login were.
3. The role now carries five actions at the unchanged subscription scope, with empty `notActions` and `dataActions`. `preflight.sh` passes for `plan`, `down`, `destroy` and `apply`.

Two bugs in `prepare-mcp.py` surfaced only on the first real `--apply`, because review mode never builds the mutation payloads:

- The purge payload used `Name`/`Id`/`IsCustom`. The Azure CLI lowercases first letters to `name`/`id`, but the update path requires **`roleName`** when an `id` is supplied, so it raised `KeyError: 'roleName'` before calling ARM. The payload now uses the SDK's own casing and dropped the unused `IsCustom` (the CLI hardcodes `type='CustomRole'`).
- Verification read back immediately and asserted once, which fails against ARM's eventual consistency. It now polls, and also confirms provider registration converges instead of only advising a recheck.

Both are covered by `tests/bootstrap/test_mcp_prerequisites.py` (`ApplyPayloadTests`), which asserts the payload schema, the ServicePrincipal-only condition, that only unregistered named providers are registered, and that a converged state issues no further writes.

Records are in ignored `.local/deployment-prerequisites/`: `model-api.json`, `model-api-sp.json`, `delegation-definition.json`, `delegation-assignment.json`, `purge-definition.json`, and `purge-assignment.json`. On final retirement, after workload teardown and workflow shutdown, an authorized administrator can remove these exact assignments with `az role assignment delete --ids RECORDED_ID`, then the custom roles with `az role definition delete --name RECORDED_NAME_UUID`, then the API app with `az ad app delete --id RECORDED_APP_OBJECT_ID`. Verify each recorded identity and dependencies first. These records contain no client secret. Do not run cleanup while deployment is active.

## Current deployment status

The final audience-configured [plan 36504720981](https://github.com/kxw9298/enterprise-ai-platform-poc/actions/runs/36504720981) passed at `d1cab08fb74c3ea0dfee4e476c63faa4bf18bb47`: 31 additions, no changes or deletions. User-authorized [apply 36504873891](https://github.com/kxw9298/enterprise-ai-platform-poc/actions/runs/36504873891) passed OIDC login, validation, permission preflight and scope checks and **completed 2026-09-29T01:18:19Z: 31 added, 0 changed, 0 destroyed.** All 31 resources were verified live and the model endpoint passed its first authenticated call on 2026-09-28. **Provisioning is complete; no Terraform operation is currently running.** Do not dispatch another Terraform operation against the same state while a run is active.
