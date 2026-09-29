# Power Platform network foundation

Prepared configuration only: separate state and resource group from the disposable platform. User confirmed Managed Environments enabled and environment ID `Default-eb241c67-e72d-4862-ae41-7686706624c4` (United States), using the Standard agent and a Copilot Studio Viral Trial. Licensing and live private connectivity have not been verified by an integration test.

Creates six Terraform resources: one resource group, two VNets, two dedicated /24 delegated subnets and one Network Injection enterprise policy. East US and West US are required for the United States geography, including nonproduction. APIM/AKS remain single-region. Review address overlap before deploying.

## Current boundary

This root prepares the integration foundation only. It does NOT link the Power Platform environment, create APIM/AKS, or yet establish routes/DNS to the workload VNet. Do not associate the environment until those connections and any necessary public egress are ready: enabling integration affects supported environment workloads, not just this agent.

Next networking change: manage both directions of peering from each integration VNet to the workload VNet, and link the APIM private DNS zone to both integration VNets (or provide equivalent DNS forwarding). Own these disposable workload dependencies in the workload stack, not this persistent root, so routine down removes them before deleting its VNet/DNS. Review NSG access from both delegated subnets. No transit routing via the first integration VNet. Internet egress/NAT is not provisioned here; evaluate connector dependencies before linking.

## Plan separately

Register Microsoft.PowerPlatform and Microsoft.Network before applying. An authorized administrator needs access to this new resource group and backend container; the existing pipeline's POC-group Contributor does not cover it. No new role grants or provider registrations were executed while preparing this root. A dedicated workflow remains to be added before GitHub deployment; the current terraform-poc.yml does not manage this root.

Use the pinned Terraform binary and cached Azure CLI login:

```bash
export TF_VAR_subscription_id="$(az account show --query id -o tsv)"
export ARM_SUBSCRIPTION_ID="$TF_VAR_subscription_id"
export ARM_USE_CLI=true ARM_USE_OIDC=false
# Supply only storage/container from existing bootstrap config; do not pass its poc.tfstate key.
terraform -chdir=infra/power-platform init \
  -backend-config="storage_account_name=staipocc38dc8cb9cf7" \
  -backend-config="container_name=tfstate"
terraform -chdir=infra/power-platform plan
```

The committed backend key is `power-platform.tfstate`. Never initialize against `poc.tfstate`. An apply is a separate reviewed step, not part of these instructions.

## Environment linking and retirement

After networking, licensing and endpoint readiness are confirmed, a Power Platform administrator with read access to the enterprise policy links it through Security → Data and privacy → Azure Virtual Network policies, or Microsoft's PowerShell `Enable-SubnetInjection` command. The Terraform environment ID output is a handoff value; it does not create an association.

Keep this foundation during ordinary workload down. On final retirement, first use Microsoft's `Disable-SubnetInjection -EnvironmentId "Default-eb241c67-e72d-4862-ae41-7686706624c4"`, verify disassociation completes, remove workload peering/DNS dependencies, then review this root's `terraform plan -destroy` before applying that destroy plan. Never delete delegated subnets while still associated with an environment. No destroy or environment change was executed.

References:
- [Microsoft setup, regional requirements and association](https://learn.microsoft.com/en-us/power-platform/admin/vnet-support-setup-configure)
- [Enterprise policy Terraform resource schema](https://learn.microsoft.com/en-us/azure/templates/microsoft.powerplatform/enterprisepolicies)
