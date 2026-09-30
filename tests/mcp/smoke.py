"""Real HTTP protocol checks; point MCP_TEST_URL at a local/containerized server."""
import json
import os
import unittest
import urllib.error
import urllib.request
import uuid

BASE = os.getenv('MCP_TEST_URL', 'http://127.0.0.1:8080').rstrip('/')


def rpc(method, params=None, request_id=1, headers=None):
    payload = {'jsonrpc': '2.0', 'id': request_id, 'method': method}
    if params is not None:
        payload['params'] = params
    req = urllib.request.Request(BASE + '/mcp', data=json.dumps(payload).encode(), headers={
        'Content-Type': 'application/json', 'Accept': 'application/json, text/event-stream',
        'MCP-Protocol-Version': '2025-03-26', **(headers or {}),
    })
    with urllib.request.urlopen(req, timeout=15) as r:
        return json.load(r), r.headers


class ProtocolTests(unittest.TestCase):
    def test_initialization(self):
        response, _ = rpc('initialize', {'protocolVersion': '2025-03-26', 'capabilities': {},
                                       'clientInfo': {'name': 'poc-smoke', 'version': '1.0'}})
        self.assertEqual(response['result']['protocolVersion'], '2025-03-26')
        self.assertIn('tools', response['result']['capabilities'])

    def test_tool_discovery_and_execution(self):
        response, _ = rpc('tools/list', {})
        self.assertEqual([x['name'] for x in response['result']['tools']], ['get_status'])
        correlation = str(uuid.uuid4())
        response, headers = rpc('tools/call', {'name': 'get_status', 'arguments': {}}, headers={'x-request-id': correlation})
        result = response['result']
        self.assertFalse(result.get('isError', False))
        body = result.get('structuredContent') or json.loads(result['content'][0]['text'])
        self.assertEqual(body['status'], 'ok')
        self.assertEqual(body['request_id'], correlation)
        self.assertEqual(headers['x-request-id'], correlation)

    def test_unknown_tool_is_not_executed(self):
        response, _ = rpc('tools/call', {'name': 'run_shell', 'arguments': {'command': 'anything'}})
        self.assertTrue('error' in response or response.get('result', {}).get('isError'))

    def test_untrusted_host_is_rejected(self):
        with self.assertRaises(urllib.error.HTTPError) as caught:
            rpc('tools/list', {}, headers={'Host': 'untrusted.example'})
        self.assertEqual(caught.exception.code, 421)
        caught.exception.close()

    def test_health(self):
        with urllib.request.urlopen(BASE + '/healthz', timeout=10) as r:
            self.assertEqual(json.load(r), {'status': 'ok'})


if __name__ == '__main__':
    unittest.main()
