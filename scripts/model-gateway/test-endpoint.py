#!/usr/bin/env python3
"""Run on the jump VM. Obtain a managed-identity token and call internal APIM.

Only synthetic test input is used. Tokens are kept in memory and never printed.
Run separately for client-a and client-b using Terraform output client IDs.
"""
import argparse
import json
import urllib.error
import urllib.parse
import urllib.request


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--gateway', required=True, help='https://APIM_NAME.azure-api.net')
    parser.add_argument('--client-id', required=True, help='User-assigned managed identity client ID')
    parser.add_argument('--resource', required=True, help='api://APPLICATION_ID from the API app registration')
    parser.add_argument('--requests', type=int, default=1, help='Use 12 to exercise the default 10 requests/minute limit')
    args = parser.parse_args()
    if not args.gateway.startswith('https://') or not 1 <= args.requests <= 20:
        parser.error('Use HTTPS and 1–20 requests')
    query = urllib.parse.urlencode({'api-version': '2018-02-01', 'resource': args.resource, 'client_id': args.client_id})
    imds = urllib.request.Request('http://169.254.169.254/metadata/identity/oauth2/token?' + query, headers={'Metadata': 'true'})
    # IMDS must never be sent through a proxy.
    try:
        with urllib.request.build_opener(urllib.request.ProxyHandler({})).open(imds, timeout=10) as result:
            token = json.load(result)['access_token']
    except (urllib.error.URLError, KeyError):
        raise SystemExit('Managed-identity token acquisition failed; check the attached identity and API resource registration.')
    body = json.dumps({'messages': [{'role': 'user', 'content': 'Reply with the word hello.'}], 'max_tokens': 16, 'stream': False}).encode()
    for index in range(args.requests):
        request = urllib.request.Request(args.gateway.rstrip('/') + '/models/chat/completions', data=body,
                                         headers={'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json'})
        try:
            with urllib.request.urlopen(request, timeout=60) as result:
                payload = json.load(result)
                print(json.dumps({'request': index+1, 'status': result.status, 'usage': payload.get('usage')}))
        except urllib.error.HTTPError as error:
            print(json.dumps({'request': index+1, 'status': error.code, 'retry_after': error.headers.get('Retry-After')}))
        except urllib.error.URLError:
            raise SystemExit('Gateway connection failed; check private DNS, routes and TLS.')


if __name__ == '__main__':
    main()
