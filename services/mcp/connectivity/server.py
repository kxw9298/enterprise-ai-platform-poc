"""Private, stateless MCP connectivity probe; APIM owns caller authentication."""
import contextvars
import json
import logging
import os
import uuid
from datetime import datetime, timezone

import uvicorn
from mcp.server import MCPServer
from mcp.server.transport_security import TransportSecuritySettings
from starlette.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware

request_id = contextvars.ContextVar('request_id', default='unknown')
build = os.getenv('MCP_BUILD', 'local')
log = logging.getLogger('mcp.connectivity')
server = MCPServer('Private Connectivity Probe', version='1.0.0')


@server.tool()
def get_status() -> dict:
    """Return connectivity status without reading data or calling an LLM."""
    result = {'status': 'ok', 'service': 'mcp-connectivity', 'build': build,
              'request_id': request_id.get(), 'time_utc': datetime.now(timezone.utc).isoformat()}
    log.info(json.dumps({'event': 'get_status', **result}))
    return result


hosts = ['127.0.0.1:*', 'localhost:*']
if os.getenv('MCP_ALLOWED_HOST'):
    hosts.append(os.environ['MCP_ALLOWED_HOST'])
app = server.streamable_http_app(
    stateless_http=True, json_response=True,
    transport_security=TransportSecuritySettings(
        enable_dns_rebinding_protection=True, allowed_hosts=hosts, allowed_origins=[]),
)


async def health(request):
    return JSONResponse({'status': 'ok'})


async def correlation(request, call_next):
    # Treat input as untrusted; never log credentials, arbitrary headers or bodies.
    try:
        value = str(uuid.UUID(request.headers.get('x-request-id', '')))
    except ValueError:
        value = str(uuid.uuid4())
    token = request_id.set(value)
    try:
        response = await call_next(request)
        response.headers['x-request-id'] = value
        return response
    finally:
        request_id.reset(token)


app.add_route('/healthz', health, methods=['GET'])
app.add_middleware(BaseHTTPMiddleware, dispatch=correlation)


if __name__ == '__main__':
    logging.basicConfig(level=logging.INFO)
    uvicorn.run(app, host='0.0.0.0', port=8080, access_log=False)
