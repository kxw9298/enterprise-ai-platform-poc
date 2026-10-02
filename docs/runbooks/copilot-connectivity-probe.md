# Copilot Studio private connectivity probe

This probe validates only the network path:

`Copilot Studio → Power Platform private networking → internal APIM → static response`

It does not require Container Apps, AKS, ACR, Foundry or an MCP server. The APIM
API is subscription-key protected and returns a static `200` response from an
inbound policy, so a successful call proves that the Copilot Studio connection
can resolve and reach the internal APIM gateway.

## Deploy

Run the normal Terraform `plan` and `apply` workflow with
`enable_container_apps=false`, `enable_mcp_runtime=false` and
`enable_foundry=false`. APIM remains enabled. Review the plan before applying.

The endpoint is:

```text
https://apim-aipoc-<suffix>.azure-api.net/connectivity/
```

The APIM subscription key is required. Create a narrowly scoped APIM product or
subscription for the test client; do not put the key in GitHub or this repo.

## Configure Copilot Studio

In the Power Platform environment that is associated with the enterprise
network policy, create a custom connector by importing
[copilot-connectivity-openapi.yaml](../connectors/copilot-connectivity-openapi.yaml).
The file contains this endpoint and response:

```yaml
openapi: 3.0.1
info:
  title: AI POC connectivity probe
  version: 1.0.0
servers:
  - url: https://apim-aipoc-<suffix>.azure-api.net
paths:
  /connectivity:
    get:
      operationId: getConnectivity
      responses:
        '200':
          description: Private APIM connectivity confirmed
          content:
            application/json:
              schema:
                type: object
                properties:
                  status: { type: string }
                  source: { type: string }
                  network: { type: string }
```

Configure API-key authentication as a header named `Ocp-Apim-Subscription-Key`.
Add the connector as an agent action and ask the agent to call
`getConnectivity`. The expected response is:

```json
{"status":"ok","source":"internal-apim","network":"private"}
```

If the call fails, test DNS and APIM separately from a permitted Azure VNet
client. A successful call from a public workstation does not prove the private
Power Platform path.

## Teardown

Use the regular Terraform `down` operation after testing. This removes APIM and
telemetry while retaining the network and bootstrap state. The APIM Developer
tier and monitoring resources are billable while present.
