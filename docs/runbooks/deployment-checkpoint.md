# Deployment checkpoint: 2026-09-28

The user requested provisioning through GitHub Actions. The [plan run](https://github.com/kxw9298/enterprise-ai-platform-poc/actions/runs/36504225341) succeeded at commit `ac64c66`. Apply has not been dispatched. No paid platform resources have been created by this attempt.

Registration was requested for Microsoft.Network, Microsoft.Compute, Microsoft.ApiManagement, Microsoft.OperationalInsights, Microsoft.Insights and Microsoft.ManagedIdentity. CognitiveServices was already registered. Recheck completion before apply.

## Required approval before continuing

Automatic approval review rejected the following combined security prerequisite setup; none of those rejected operations executed. Do not retry it indirectly or dispatch an apply that bypasses prerequisites. Obtain explicit approval for:

1. Create a single-tenant, secretless Entra API registration and its service principal named `enterprise-ai-poc-model-api`; set its `api://APP_UUID` identifier and v2 token format. Save the non-secret UUID in GitHub `MODEL_API_AUDIENCE`.
2. Create a custom role and grant it to the existing GitHub OIDC service principal **only at `rg-ai-platform-poc`**. It permits role-assignment read/write/delete and role-definition read. Enforce a condition on both write and delete limiting assignments to service principals and these two roles: Cognitive Services OpenAI User (`5e0bd9bd-7b93-4f28-af87-19fc36ad61bd`) and Monitoring Metrics Publisher (`3913510d-42f4-4e42-8a64-420c390055eb`). This is persistent delegation to assign those roles within the group, not Owner access and not restricted to a single future APIM principal.
3. Create a separate custom role and subscription-level assignment for the pipeline, granting read/delete of soft-deleted APIM services and Cognitive Services accounts. These APIs require subscription-level access for repeatable teardown/name reuse. **This allows permanent purging of matching deleted services throughout the subscription**, not just this POC. No purge is performed during setup; the permission persists until removed.

Record all created app, custom-role and assignment IDs under ignored local records and document their cleanup. These additional custom roles and the model API app are not automatically covered by the existing bootstrap cleanup script. Before final bootstrap retirement, remove the recorded extra assignments, then extra role definitions and API app after checking dependencies. Preserve backend/state until workload teardown finishes. Provider registrations remain subscription-wide.

After approval: configure prerequisites, confirm quota/capacity, run a new plan using the real API audience, review it, then dispatch apply with the exact reviewed commit SHA. Record the workflow URL and actual outcome. Live endpoint tests remain pending until resources exist.

Condition syntax reference: [Microsoft conditional role delegation examples](https://learn.microsoft.com/en-us/azure/role-based-access-control/delegate-role-assignments-examples).
