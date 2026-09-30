# Phase-one Container Apps deployment sequence

Prepared code only: no infrastructure apply, permission changes or image publication is performed by preparing these files. Use `infra/poc` and its existing state. AKS remains preserved in its local module and defaults off.

## Prepared resources

| Component | Configuration |
| --- | --- |
| Persistent workload subnet | `10.45.0.64/27`, delegated to Microsoft.App/environments; separate from reserved AKS subnet |
| Shared registry | ACR Basic, admin login disabled, public registry endpoint with Entra authorization; usable independently of AKS |
| Container Apps environment | Internal load balancer, public network access disabled, Consumption workload profile only, East US |
| Managed infrastructure group | `rg-aipoc-<suffix>-container-managed`, created/owned by the Azure service; do not manage/delete its children manually |
| Image pull | User-assigned managed identity and registry-scoped AcrPull |
| DNS | Environment default-domain zone, apex/wildcard private-IP records, resolution links to hub and workload VNet |
| App (after image supplied) | 0.25 vCPU / 0.5 GiB, scale 0–1, single revision, HTTPS ingress restricted to APIM subnet |
| APIM | Existing internal gateway and Entra allowlist; HTTPS Container Apps backend, rewritten `/mcp`, request correlation header |

App ingress is `external_enabled=true` to allow APIM outside the Container Apps environment, but the environment itself is internal-only. No private endpoint is created, and no customer NAT, Bastion or AKS node is enabled. Platform-managed networking, ACR Basic, APIM and telemetry can incur charges even when the app scales to zero. Scaling/revision overlap is not an exact spending cap.

## Prerequisites

**Resolved 2026-09-30.** `Microsoft.App`, `Microsoft.ContainerRegistry` and `Microsoft.PowerPlatform` are all Registered. The `AI POC Deleted Service Purge` role carries the location-scoped `Microsoft.ApiManagement/locations/deletedServices/read` at its unchanged subscription scope, and the existing conditioned RG delegation now allows **AcrPull for ServicePrincipal recipients only** alongside the two pre-existing roles, still constraining both write and delete. `scripts/bootstrap/prepare-mcp.py --apply` performed these; review mode makes no changes, and unexpected scopes or conditions fail closed. The old AKS expansion requires explicit `--runtime aks`. `preflight.sh` now passes for `plan`, `down`, `destroy` and `apply`. See the deployment checkpoint for records and for two script bugs this surfaced.

East US environment count is 1 allowed / 0 used at the last check. Consumption-core quota is per environment and must be inspected after it exists (including headroom for revision overlap). Registration does not prove actual regional capacity.

The pipeline also needs subscription-scoped **Microsoft.App/locations/usages/read** to run the regional quota preflight. Its original bootstrap subscription-reader actions do not include this provider-specific action. Review a narrowly scoped read grant before apply; RG Contributor alone does not cover this subscription-level query.

After ACR exists, image publication requires registry-scoped **AcrPush** for the existing GitHub OIDC service principal (or a separately reviewed build identity). Contributor does not grant this registry data access. Assigning that role is a separately reviewed bootstrap operation and must be recorded for cleanup; do not embed registry credentials or enable ACR admin access. Terraform does not grant its own pipeline additional permissions.

## Two-stage execution

1. Run **Terraform POC → plan** with `enable_container_apps=true`, `enable_mcp_runtime=false`, `enable_foundry=false`, and empty `mcp_image_digest`. Review the exact SHA and scope. The first apply creates the registry/environment/identity/DNS, but **no container app**. APIM keeps authentication fail-closed; with a trusted caller it returns 503 while the backend is absent (an empty allowlist still returns 403).
2. Apply the reviewed foundation plan only after prerequisite approval/resolution. Confirm the environment is internal and query its consumption quota, for example `az containerapp env list-usages --resource-group rg-ai-platform-poc --name cae-aipoc-<suffix>`. Do not continue if there is insufficient quota/capacity.
3. Run **MCP image** with `publish=false` to build Linux/amd64 and execute real HTTP MCP tests inside the container. This mode needs no Azure login or registry. `publish=true` repeats tests, then pushes the tested image using OIDC and registry-scoped AcrPush. It outputs the immutable `sha256:...` digest; it does not apply Terraform. Image tags include source SHA, workflow run and attempt; deployment uses the digest, not the tag.
4. Run **Terraform POC → plan** again with that exact `mcp_image_digest`. Review, then apply at the reviewed SHA with the same inputs. Terraform creates the app and enables the APIM backend route. No `az containerapp update` is used, so Terraform owns the deployed image version.
5. Pass the same digest on later normal plan/apply runs to retain the app. Omitting it after deployment proposes removing the app; the normal scope guard rejects that deletion. It is not an implicit rolling-back operation.
6. Configure the real Entra MCP caller allowlist (`MCP_ALLOWED_CLIENT_IDS`, JSON list) and audience. Associate the Power Platform environment when authorized, then verify tool discovery and `get_status` execution from Copilot Studio itself. Correlate APIM RequestId with the app's returned/logged request_id. Runtime auth, actual APIM source IP, DNS and Copilot compatibility are not proven by local tests.

## Teardown and rebuild

Use the existing reviewed `down-plan`/`down` operations to delete all workloads, including ACR/images, the app/environment and backend DNS; retain network/policy. Container Apps owns its managed infrastructure group's cleanup. Verify it and billable resources actually disappear. Retain build logs/source and record image digests if needed; ACR content is deleted with the registry.

After down, recreate foundation with an empty image digest, rebuild/push the image, then deploy its new digest. An old digest cannot be pulled from a newly empty ACR. Do not delete bootstrap state storage. Full destroy still requires the Power Platform environment to be detached first. AKS is a separate phase-two choice (`enable_container_apps=false`, `enable_mcp_runtime=true`) and switching a live runtime requires explicit migration review; normal plans reject destructive changes.

## References

- [Azure Container Apps networking](https://learn.microsoft.com/en-us/azure/container-apps/custom-virtual-networks)
- [Container Apps quotas](https://learn.microsoft.com/en-us/azure/container-apps/quotas)
- [Managed-identity registry pulls](https://learn.microsoft.com/en-us/azure/container-apps/managed-identity-image-pull)
- [Official MCP Python SDK](https://github.com/modelcontextprotocol/python-sdk)

## Validation checkpoint

Nine mocked Terraform lifecycle tests, five real HTTP MCP tests, five prerequisite-script tests and policy/scope checks passed. Azure-backed plans against the existing state passed: foundation 40 additions / 1 update / 0 destroys; app-enabled 41 additions / 1 update / 0 destroys using a synthetic digest only. The update preserves and contracts the existing hub address space as previously reviewed. Neither plan was applied.

GitHub [build-only run 36719934403](https://github.com/kxw9298/enterprise-ai-platform-poc/actions/runs/36719934403) passed at `4cf697d`, building the Linux image and exercising HTTP MCP inside the container. Publish was false, so this run neither signed into Azure nor pushed an image. No actual ACR digest is available for deployment until the publish stage runs against the provisioned registry.
