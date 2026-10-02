const pages = {
  connectivity: {
    title: 'Copilot Studio private connectivity to Azure APIM',
    kicker: 'Validated architecture · 02 October 2026',
    lead: 'A practical proof of concept for calling an internal Azure API Management gateway from a Copilot Studio agent through Power Platform VNet support.',
    body: `
      <div class="callout"><strong>Validated result</strong><br>Copilot Studio tool <code>Check-private-connectivity</code> returned <code>{"network":"private","source":"internal-apim","status":"ok"}</code>.</div>
      <h2>Architecture</h2>
      <div class="topology" role="img" aria-label="Network topology showing Copilot Studio through Power Platform VNet injection to an Azure virtual network, private DNS and internal API Management">
        <div class="topology-client resource-card"><div class="resource-icon copilot">✦</div><div><strong>Copilot Studio</strong><small>Agent + connector tool</small></div></div>
        <div class="topology-arrow"><span>HTTPS</span><b>→</b></div>
        <div class="cloud-boundary"><div class="boundary-label">Microsoft Power Platform</div><div class="resource-card injected"><div class="resource-icon power">⇄</div><div><strong>VNet-injected runtime</strong><small>Managed connector containers</small></div></div><div class="subnet-chip">Delegated subnet · private route</div></div>
        <div class="topology-arrow"><span>VNet peering</span><b>→</b></div>
        <div class="azure-boundary"><div class="boundary-label azure-label">Azure VNet · East US</div><div class="azure-grid"><div class="resource-card dns"><div class="resource-icon dns-icon">⌁</div><div><strong>Private DNS</strong><small>APIM hostname → 10.42.4.4</small></div></div><div class="resource-card apim"><div class="resource-icon apim-icon">◇</div><div><strong>Internal APIM</strong><small>Developer tier · private IP</small></div></div></div><div class="subnet-chip">Private endpoint subnet · 10.42.4.0/24</div></div>
      </div>
      <div class="legend"><span><i class="legend-dot blue"></i>Managed service path</span><span><i class="legend-dot purple"></i>Private network boundary</span><span><i class="legend-dot green"></i>Validated response</span></div>
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
