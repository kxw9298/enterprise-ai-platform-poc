const pages = {
  connectivity: {
    title: 'Copilot Studio private connectivity to Azure APIM',
    kicker: 'Validated architecture · 02 October 2026',
    lead: 'A practical proof of concept for calling an internal Azure API Management gateway from a Copilot Studio agent through Power Platform VNet support.',
    body: `
      <div class="callout"><strong>Validated result</strong><br>Copilot Studio tool <code>Check-private-connectivity</code> returned <code>{"network":"private","source":"internal-apim","status":"ok"}</code>.</div>
      <h2>Architecture</h2>
      <div class="architect-diagram" role="img" aria-label="Architectural topology showing Copilot Studio, Power Platform VNet injection, private DNS and internal APIM in an Azure VNet">
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

function render() {
  const key = location.hash.includes('connectivity') ? 'connectivity' : 'connectivity';
  const page = pages[key];
  document.querySelector('#nav').innerHTML = `<a class="active" href="#/doc/copilot-studio-private-connectivity">Private connectivity</a><a href="https://github.com/kxw9298/enterprise-ai-platform-poc/tree/main/docs">Repository docs</a>`;
  document.querySelector('#content').innerHTML = `<div class="kicker">${page.kicker}</div><h1>${page.title}</h1><p class="lead">${page.lead}</p>${page.body}`;
  document.title = page.title;
}
window.addEventListener('hashchange', render); render();
