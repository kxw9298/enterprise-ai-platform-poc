# Private MCP connectivity probe

A stateless Streamable HTTP server using the official MCP Python SDK, pinned with transitive dependencies in `requirements.txt`. It exposes only `get_status`: status, build digest, UTC timestamp and a correlation ID. It does not read enterprise data, execute commands or call an LLM. Logs contain diagnostic fields only; access/body/header logging is disabled.

- MCP endpoint: `/mcp`, port 8080.
- Probe: `/healthz`.
- Container: non-root UID 10001; tested with a read-only root filesystem.
- `MCP_ALLOWED_HOST`: exact Container Apps hostname; localhost hosts are also allowed for tests. Transport rejects untrusted Host headers and browser origins.
- `MCP_BUILD`: immutable image digest in Azure, `local` otherwise.
- APIM validates the caller's Entra token and overwrites `x-request-id`. The app's ingress accepts only the APIM subnet. This server relies on that boundary and is not a public authenticated service; do not expose it directly or relax the ingress restriction.

## Local test

```bash
python3 -m venv .venv
.venv/bin/pip install -r services/mcp/connectivity/requirements.txt
.venv/bin/python services/mcp/connectivity/server.py
# In another terminal:
python3 tests/mcp/smoke.py
```

Or build/run the image:

```bash
docker build -t mcp-connectivity:test services/mcp/connectivity
docker run --rm --read-only --tmpfs /tmp -p 127.0.0.1:8080:8080 mcp-connectivity:test
```

Do not use this localhost test as evidence of Copilot-to-Azure private connectivity. The test verifies initialization, tool discovery/execution, correlation, health and unknown-tool/Host rejection. Live Copilot authentication, ingress source-IP behavior and cold starts remain deployment checks.
