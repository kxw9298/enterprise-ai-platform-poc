"""Exercise preflight against scalar Azure CLI results and scoped permissions."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
MOCK = r'''#!/usr/bin/env python3
import json, os, sys
args = sys.argv[1:]
with open(os.environ['CALLS'], 'a') as f:
    f.write(json.dumps(args) + '\n')
if args[:2] == ['group', 'exists']:
    # JMESPath `.value` on a scalar yields null (empty TSV), as the real CLI does.
    print('' if '--query' in args else os.environ['GROUP_EXISTS'])
elif args[:2] == ['provider', 'show']:
    print('Registered')
elif args[:2] == ['resource', 'list']:
    print('["existing-environment"]')
elif args[0] == 'rest':
    url = args[args.index('--url') + 1]
    if '/usages?' in url:
        print(json.dumps({'value': [{'name': {'value': 'ManagedEnvironmentCount'}, 'limit': 1, 'currentValue': int(os.environ['QUOTA_USED'])}]}))
    else:
        actions = ['Microsoft.ApiManagement/locations/deletedServices/*', 'Microsoft.CognitiveServices/locations/resourceGroups/deletedAccounts/*']
        if '/resourceGroups/' in url and os.environ['DELEGATED'] == 'true':
            actions.append('Microsoft.Authorization/roleAssignments/write')
        print(json.dumps({'value': [{'actions': actions, 'notActions': []}]}))
else:
    sys.exit('Unexpected Azure call: ' + repr(args))
'''


class PreflightTests(unittest.TestCase):
    def run_preflight(self, group='true', delegated='true', quota_used='1'):
        with tempfile.TemporaryDirectory() as tmp:
            az = Path(tmp) / 'az'
            az.write_text(MOCK)
            az.chmod(0o755)
            calls = Path(tmp) / 'calls'
            env = dict(os.environ, PATH=tmp + os.pathsep + os.environ['PATH'],
                       CALLS=str(calls), GROUP_EXISTS=group, DELEGATED=delegated,
                       QUOTA_USED=quota_used, TF_VAR_subscription_id='test-sub',
                       OPERATION='apply', TF_VAR_enable_container_apps='true',
                       TF_VAR_enable_mcp_runtime='false', TF_VAR_enable_foundry='false')
            result = subprocess.run(['bash', str(ROOT / 'scripts/infra/preflight.sh')],
                                    env=env, text=True, capture_output=True)
            return result, [json.loads(line) for line in calls.read_text().splitlines()]

    def test_existing_group_uses_scoped_delegation_and_existing_quota_slot(self):
        result, calls = self.run_preflight()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(any('/resourceGroups/rg-ai-platform-poc/providers/Microsoft.Authorization/permissions' in ' '.join(c) for c in calls))

    def test_existing_group_without_delegation_fails_closed(self):
        result, _ = self.run_preflight(delegated='false')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('cannot create workload role assignments', result.stdout)

    def test_absent_group_does_not_read_group_resources_or_invent_delegation(self):
        result, calls = self.run_preflight(group='false', quota_used='0')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('cannot create workload role assignments', result.stdout)
        self.assertFalse(any(c[:2] == ['resource', 'list'] for c in calls))
        self.assertFalse(any('/resourceGroups/rg-ai-platform-poc/' in ' '.join(c) for c in calls))

    def test_empty_boolean_response_is_an_error(self):
        result, calls = self.run_preflight(group='')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('could not determine', result.stderr)
        self.assertEqual(len(calls), 1)


if __name__ == '__main__':
    unittest.main()
