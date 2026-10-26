"""The temporary repair gate admits only the approved scope transition."""
import copy
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
PREFIX = 'module.platform[0].module.foundry[0].'


def fixture():
    changes = []
    for client in ('a', 'b'):
        before = dict(resource_group_name='rg-ai-platform-poc',
                      api_management_name='apim-test', subscription_id=f'model-client-{client}',
                      api_id='/test/apis/model;rev=1', state='active', allow_tracing=False)
        after = dict(before, api_id='/test/apis/model')
        changes.append(dict(address=PREFIX + f'azurerm_api_management_subscription.client["client-{client}"]',
                            type='azurerm_api_management_subscription', mode='managed',
                            change=dict(actions=['delete', 'create'], before=before, after=after)))
    changes.append(dict(address=PREFIX + 'azurerm_api_management_api_policy.model', mode='managed',
                        change=dict(actions=['update'])))
    return dict(format_version='1.2', resource_changes=changes)


class RepairGate(unittest.TestCase):
    def allowed(self, data):
        with tempfile.NamedTemporaryFile(mode='w', suffix='.json') as f:
            json.dump(data, f)
            f.flush()
            return subprocess.run(['bash', str(ROOT / 'scripts/ci/check-model-subscription-repair.sh'), f.name],
                                  capture_output=True).returncode == 0

    def test_approved_repair(self):
        self.assertTrue(self.allowed(fixture()))

    def test_reject_other_changes(self):
        for field, value in [('api_id', '/test/apis/other'), ('resource_group_name', 'other'),
                             ('state', 'suspended'), ('subscription_id', 'master'), ('allow_tracing', True)]:
            data = fixture()
            data['resource_changes'][0]['change']['after'][field] = value
            self.assertFalse(self.allowed(data), field)

    def test_reject_additional_resource(self):
        data = fixture()
        data['resource_changes'].append(copy.deepcopy(data['resource_changes'][0]))
        self.assertFalse(self.allowed(data))

    def test_reject_policy_delete(self):
        data = fixture()
        data['resource_changes'][2]['change']['actions'] = ['delete']
        self.assertFalse(self.allowed(data))


if __name__ == '__main__':
    unittest.main()
