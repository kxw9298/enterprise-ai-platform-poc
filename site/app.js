const pages = {
  connectivity: {
    title: 'Copilot Studio private connectivity to Azure APIM',
    kicker: 'Validated architecture · 02 October 2026',
    lead: 'A practical proof of concept for calling an internal Azure API Management gateway from a Copilot Studio agent through Power Platform VNet support.',
    body: `
      <div class="callout"><strong>Validated result</strong><br>Copilot Studio tool <code>Check-private-connectivity</code> returned <code>{"network":"private","source":"internal-apim","status":"ok"}</code>.</div>
      <h2>Azure landing zone topology</h2>
      <p class="diagram-caption">The diagram uses an Azure architecture view: platform boundary on the left, Azure landing zone on the right, and separate data-plane and DNS flows.</p>
      <div class="architect-diagram approved-architecture" role="img" aria-label="Hub and spoke topology showing Copilot Studio, Power Platform VNet injection, private DNS and internal APIM">
        <img class="architecture-image" src="assets/copilot-studio-hub-spoke.png" alt="Azure hub and spoke architecture with a central hub VNet, two Power Platform delegation spokes, and an APIM spoke" />
        <svg viewBox="0 0 980 430" xmlns="http://www.w3.org/2000/svg" aria-labelledby="diagram-title diagram-desc">
          <title id="diagram-title">Copilot Studio to internal Azure APIM topology</title><desc id="diagram-desc">A private HTTPS request crosses Power Platform VNet injection and peering into an Azure virtual network. Private DNS resolves the APIM hostname to a private address.</desc>
          <defs><marker id="arrow" markerWidth="9" markerHeight="9" refX="7" refY="3" orient="auto"><path d="M0,0 L0,6 L8,3 z" fill="#1769aa"/></marker><filter id="shadow" x="-10%" y="-10%" width="120%" height="130%"><feDropShadow dx="0" dy="3" stdDeviation="4" flood-color="#17324d" flood-opacity=".12"/></filter></defs>
          <rect x="18" y="18" width="944" height="394" rx="18" fill="#f8fbff" stroke="#d5e3ef"/>
          <text x="42" y="49" class="svg-kicker">REFERENCE TOPOLOGY · VALIDATED PRIVATE CONNECTIVITY</text>
          <rect x="42" y="78" width="176" height="282" rx="14" fill="#fff" stroke="#c7d8e7" filter="url(#shadow)"/><text x="62" y="107" class="svg-boundary">COPILOT STUDIO</text>
          <rect x="63" y="140" width="134" height="78" rx="10" fill="#eaf4ff" stroke="#8cbbe0"/><circle cx="86" cy="169" r="16" fill="#0078d4"/><text x="86" y="175" text-anchor="middle" class="svg-icon">✦</text><text x="111" y="166" class="svg-title">Agent</text><text x="111" y="184" class="svg-small">Connector tool</text>
          <text x="62" y="255" class="svg-small">User prompt</text><text x="62" y="274" class="svg-small">→ Check-private-connectivity</text><text x="62" y="311" class="svg-small">Managed by Microsoft</text><text x="62" y="328" class="svg-small">No customer container</text>
          <rect x="270" y="78" width="290" height="282" rx="14" fill="#fbf8fd" stroke="#c7acd3" filter="url(#shadow)"/><text x="290" y="101" class="svg-boundary purple-text">POWER PLATFORM CLOUD</text><text x="290" y="116" class="svg-small">Control plane · network policy</text>
          <rect x="293" y="132" width="244" height="92" rx="10" fill="#fff" stroke="#c9b1d5"/><circle cx="319" cy="165" r="16" fill="#742774"/><text x="319" y="171" text-anchor="middle" class="svg-icon">⇄</text><text x="346" y="162" class="svg-title">Managed connector runtime</text><text x="346" y="181" class="svg-small">Microsoft-hosted containers</text><text x="346" y="198" class="svg-small">delegated into customer subnet</text>
          <rect x="293" y="250" width="244" height="74" rx="10" fill="#f7effa" stroke="#d8bce3"/><text x="313" y="274" class="svg-title">Network policy + VNet injection</text><text x="313" y="293" class="svg-small">ep-ai-poc-network · Succeeded</text><text x="313" y="311" class="svg-small">Delegated subnet · private route</text>
          <rect x="612" y="78" width="326" height="282" rx="14" fill="#f4faff" stroke="#8fbddd" filter="url(#shadow)"/><text x="632" y="101" class="svg-boundary blue-text">AZURE LANDING ZONE</text><text x="632" y="116" class="svg-small">Data plane · East US VNet</text>
          <rect x="634" y="131" width="132" height="74" rx="10" fill="#fff" stroke="#a8cbe3"/><circle cx="658" cy="158" r="15" fill="#1683a8"/><text x="658" y="164" text-anchor="middle" class="svg-icon">⌁</text><text x="681" y="157" class="svg-title">Private DNS</text><text x="681" y="176" class="svg-small">name → 10.42.4.4</text>
          <rect x="784" y="131" width="132" height="74" rx="10" fill="#eaf4ff" stroke="#8cbbe0"/><circle cx="808" cy="158" r="15" fill="#0078d4"/><text x="808" y="164" text-anchor="middle" class="svg-icon">◇</text><text x="831" y="157" class="svg-title">Internal APIM</text><text x="831" y="176" class="svg-small">Developer tier</text>
          <rect x="634" y="232" width="282" height="91" rx="10" fill="#fff" stroke="#a8cbe3"/><text x="655" y="259" class="svg-title">APIM private subnet</text><text x="655" y="280" class="svg-small">10.42.4.0/24 · no public gateway</text><text x="655" y="300" class="svg-small">GET /connectivity → HTTP 200</text>
          <path d="M218 180 H270" stroke="#1769aa" stroke-width="3" marker-end="url(#arrow)"/><path d="M560 180 H612" stroke="#1769aa" stroke-width="3" marker-end="url(#arrow)"/><path d="M700 205 V232" stroke="#1683a8" stroke-width="2" stroke-dasharray="5 4" marker-end="url(#arrow)"/><path d="M766 168 H784" stroke="#1683a8" stroke-width="2" stroke-dasharray="5 4" marker-end="url(#arrow)"/>
          <g class="svg-step"><circle cx="244" cy="170" r="13"/><text x="244" y="175" text-anchor="middle">1</text><text x="230" y="207">HTTPS traffic</text></g><g class="svg-step"><circle cx="586" cy="170" r="13"/><text x="586" y="175" text-anchor="middle">2</text><text x="563" y="207">private peering</text></g><text x="795" y="222" class="svg-small">DNS flow</text>
          <rect x="42" y="377" width="874" height="20" rx="10" fill="#e7f5ed"/><text x="479" y="391" text-anchor="middle" class="svg-result">VALIDATED · network=private · source=internal-apim · status=ok</text>
        </svg>
      </div>
      <p>Power Platform injects Microsoft-managed runtime containers into the delegated subnet. Azure owns the network, DNS and APIM gateway; no customer-managed connector container is created in Azure.</p>
      <h2>Azure configuration</h2>
      <table><thead><tr><th>Resource</th><th>Purpose</th><th>Result</th></tr></thead><tbody>
        <tr><td><code>ep-ai-poc-network</code></td><td>Network injection enterprise policy</td><td>Succeeded</td></tr>
        <tr><td>Power Platform VNets</td><td>East US and West US delegated subnets</td><td>Peered to hub</td></tr>
        <tr><td><code>apim-aipoc-247fda1b</code></td><td>Internal API gateway</td><td>Developer, Internal</td></tr>
        <tr><td>Private DNS zone</td><td>Maps APIM hostname to <code>10.42.4.4</code></td><td>Four VNet links</td></tr>
        <tr><td><code>GET /connectivity</code></td><td>Static APIM response, no backend</td><td>HTTP 200</td></tr>
      </tbody></table>
      <h2>Power Platform configuration</h2>
      <ol><li>Use a Dataverse-backed Managed Environment.</li><li>In Power Platform admin center, open <strong>Security → Data and privacy → Azure Virtual Network policies</strong>.</li><li>Assign <code>ep-ai-poc-network</code> and wait for history to show <strong>Succeeded</strong>.</li><li>In Power Apps, import the <a href="https://github.com/kxw9298/enterprise-ai-platform-poc/blob/main/docs/connectors/copilot-connectivity-openapi.yaml">OpenAPI connector definition</a>.</li><li>Use HTTPS and no authentication for this isolated probe.</li><li>In Copilot Studio, add the connector as a tool and invoke <code>getConnectivity</code>.</li></ol>
      <h2>What this proves</h2><p>The result proves the path from Copilot Studio through the Power Platform delegated subnet, private DNS and VNet peering to internal APIM. It does not yet validate MCP, A2A, Container Apps, AKS or Foundry model inference.</p>
      <h2>Next milestones</h2><ol><li>Replace the static policy with a private HTTP backend.</li><li>Deploy a real MCP server behind APIM.</li><li>Test MCP tool discovery and execution from Copilot Studio.</li><li>Add token, client and cost attribution after the network path is stable.</li></ol>
      <p class="meta">Source documentation: <a href="https://github.com/kxw9298/enterprise-ai-platform-poc">GitHub repository</a> · milestone tag <code>v0.1.0-private-connectivity</code></p>`
  }
};

pages.ai = {
  title: 'Private AI model gateway on Azure',
  kicker: 'AI platform · Validated 25 October 2026',
  lead: 'Internal API Management fronts a Foundry GPT-4.1-mini deployment, with Entra authentication and separate API subscriptions for client controls and token attribution.',
  body: `<div class="callout"><strong>Verified live</strong><br>Both test clients call the model privately. A client over its APIM request limit gets 429 while the other client continues to receive 200.</div>
    <h2>Request and identity flow</h2>
    <pre>Private test VM + client managed identity
  → internal APIM (10.42.4.4)
  → validate Entra token + API subscription key
  → enforce client/subscription binding and limits
  → APIM managed identity → Foundry → model response
  → token traces → Application Insights / Log Analytics</pre>
    <p>Foundry uses a subnet-restricted service endpoint; it is not a Foundry private endpoint. No Container Apps, ACR or AKS runtime is enabled. Bastion Basic and the private VM provide temporary test access.</p>
    <h2>Verified security and controls</h2>
    <table><thead><tr><th>Test</th><th>Observed result</th></tr></thead><tbody>
    <tr><td>Client A / B, matching identity and key</td><td>200 / 200</td></tr>
    <tr><td>Missing or invalid key; missing token</td><td>401</td></tr>
    <tr><td>Client A identity + client B key</td><td>403</td></tr>
    <tr><td>Streaming request</td><td>400</td></tr>
    <tr><td>Isolation at temporary 1 request/minute</td><td>A first: 200; A second: 429; B: 200</td></tr>
    <tr><td>Temporary 1-token daily quota</td><td>Subsequent calls: 403</td></tr>
    <tr><td>Primary and secondary key attribution</td><td>Same subscription ID</td></tr>
    <tr><td>Primary-key regeneration after propagation</td><td>Old key: 401; new key: 200</td></tr>
    <tr><td>Synthetic blocked-content test</td><td>400, content_filter</td></tr>
    <tr><td>Spoofed attribution headers</td><td>Overridden with validated IDs</td></tr>
    </tbody></table>
    <p>With prompt estimation disabled, the token policy can admit a request before its usage is known; it rejects subsequent requests once the quota is reached. It is not an exact spending cap. Initial burst tests also hit shared Foundry capacity; lowering the APIM test limit made client isolation independently observable.</p>
    <h2>Usage and estimated cost</h2>
    <p>One APIM subscription represents each reporting client. Its primary and secondary keys share counters and attribution. Raw keys are removed before forwarding and are not logged as telemetry dimensions.</p>
    <table><thead><tr><th>GlobalStandard retail USD / million tokens</th><th>Rate</th></tr></thead><tbody><tr><td>Input</td><td>$0.40</td></tr><tr><td>Cached input</td><td>$0.10</td></tr><tr><td>Output</td><td>$1.60</td></tr></tbody></table>
    <p>Rates verified against the Azure Retail Prices API on 25 October 2026. The snapshot records source meter IDs and effective dates. The query only prices the matching model/version and observed day; other usage stays unpriced. Estimates exclude infrastructure, taxes and negotiated discounts.</p>
    <h2>Reproducible configuration</h2><ol><li>Review the explicit AI Terraform profile, with Foundry enabled and container runtimes disabled.</li><li>Enable temporary admin access for the private VM and Bastion test path.</li><li>Review a fresh plan and matching workflow commit before apply.</li><li>Obtain keys securely. Test both clients, mismatched keys, limits and usage from the private VM.</li><li>Run a reviewed down-plan/down to remove paid workloads while retaining the network foundation.</li></ol>
    <p>The subscription scope must reference the logical <code>/apis/model</code> API. Revision-qualified <code>/apis/model;rev=1</code> scope caused valid keys to be rejected in the first deployment and was corrected.</p>
    <p><a href="https://github.com/kxw9298/enterprise-ai-platform-poc/blob/main/docs/runbooks/ai-platform-validation.md">Detailed validation record and remaining checks</a> · <a href="https://github.com/kxw9298/enterprise-ai-platform-poc/blob/main/docs/runbooks/ai-platform.md">Deployment runbook</a> · <a href="https://github.com/kxw9298/enterprise-ai-platform-poc/blob/main/pricing/gpt-4.1-mini-global-2026-10-25.json">Dated price snapshot</a></p>`
};

function render() {
  const key = location.hash.includes('ai-platform') ? 'ai' : 'connectivity';
  const page = pages[key];
  document.querySelector('#nav').innerHTML = `<a class="${key === 'connectivity' ? 'active' : ''}" href="#/doc/copilot-studio-private-connectivity">Private connectivity</a><a class="${key === 'ai' ? 'active' : ''}" href="#/doc/ai-platform">AI model gateway</a><a href="https://github.com/kxw9298/enterprise-ai-platform-poc/tree/main/docs">Repository docs</a>`;
  document.querySelector('#content').innerHTML = `<div class="kicker">${page.kicker}</div><h1>${page.title}</h1><p class="lead">${page.lead}</p>${page.body}`;
  document.title = page.title;
}
window.addEventListener('hashchange', render); render();
