# Infrastructure as code

Azure resource definitions and reusable modules belong here. Select Terraform, Bicep, or another tool through an architecture decision before adding scaffolding specific to it.

Keep environment values separate from reusable modules. Use remote state where applicable; never commit state, credentials, or real secret values. Document provisioning costs and teardown.
