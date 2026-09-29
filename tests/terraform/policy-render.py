"""Render real Terraform templates with fixture IDs; verify XML and fail-closed behavior."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[2]
tf = os.environ.get("TERRAFORM_BIN", str(root / ".local/tools/terraform/1.16.4/terraform"))
base = {
    "tenant_id": "11111111-1111-1111-1111-111111111111",
    "audience": "api://enterprise-ai-platform-poc",
    "client_ids": [],
    "deployment": "poc-chat",
    "requests_per_minute": 10,
    "tokens_per_minute": 1000,
    "daily_token_quota": 10000,
}
with tempfile.TemporaryDirectory() as work:
    def render(name, clients):
        values = dict(base, client_ids=clients)
        path = str(root / f"infra/modules/platform/policies/{name}.xml.tftpl")
        expr = f"jsonencode(templatefile({json.dumps(path)}, {json.dumps(values)}))\n"
        result = subprocess.run([tf, "console"], input=expr, text=True, cwd=work, capture_output=True, check=True)
        return ET.fromstring(json.loads(json.loads(result.stdout)))

    blocked = render("mcp", [])
    assert blocked.find("inbound/return-response/set-status").attrib["code"] == "403"
    trusted = ["22222222-2222-2222-2222-222222222222"]
    mcp = render("mcp", trusted)
    assert mcp.find("inbound/validate-azure-ad-token/client-application-ids/application-id").text == trusted[0]
    assert mcp.find("inbound/rewrite-uri").attrib["template"] == "/mcp"
    assert mcp.find("backend/forward-request").attrib["buffer-response"] == "false"
    model = render("model", trusted)
    assert model.find("inbound/rate-limit-by-key").attrib["calls"] == "10"
    assert model.find("inbound/llm-token-limit").attrib["token-quota"] == "10000"
    assert model.find("inbound/authentication-managed-identity") is not None
    assert model.find("inbound/llm-emit-token-metric/dimension").attrib["name"] == "ClientId"
    assert model.find("outbound/choose/when/trace/metadata[@name='usage']") is not None
    assert model.find("inbound/choose/when/return-response/set-status").attrib["code"] == "400"
print("Policy templates render as XML; empty trust denies MCP; model authentication/accounting and streaming boundary verified.")
