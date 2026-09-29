# Deployment checkpoint: 2026-09-28

The user requested provisioning through GitHub Actions. The [plan run](https://github.com/kxw9298/enterprise-ai-platform-poc/actions/runs/36504225341) succeeded at commit `ac64c66`. Apply has not been dispatched. No paid platform resources have been created by this attempt.

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

Records are in ignored `.local/deployment-prerequisites/`: `model-api.json`, `model-api-sp.json`, `delegation-definition.json`, `delegation-assignment.json`, `purge-definition.json`, and `purge-assignment.json`. On final retirement, after workload teardown and workflow shutdown, an authorized administrator can remove these exact assignments with `az role assignment delete --ids RECORDED_ID`, then the custom roles with `az role definition delete --name RECORDED_NAME_UUID`, then the API app with `az ad app delete --id RECORDED_APP_OBJECT_ID`. Verify each recorded identity and dependencies first. These records contain no client secret. Do not run cleanup while deployment is active.
