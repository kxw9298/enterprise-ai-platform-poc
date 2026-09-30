"""Ensure prerequisite review refuses unexpected scopes and role delegation."""
import contextlib
import importlib.util
import io
import pathlib
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('prepare_mcp', pathlib.Path(__file__).parents[2] / 'scripts/bootstrap/prepare-mcp.py')
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


class ReviewTests(unittest.TestCase):
    def setUp(self):
        self.sub = '/subscriptions/test-sub'
        self.scope = self.sub + '/resourceGroups/rg-ai-platform-poc'
        self.ids = [f'role-{i}' for i in range(5)]
        self.delegation = {'roleName': 'AI POC Gateway Role Delegation', 'id': 'delegation', 'assignableScopes': [self.scope]}
        self.purge = {'roleName': 'AI POC Deleted Service Purge', 'assignableScopes': [self.sub], 'permissions': [{'actions': [
            'Microsoft.ApiManagement/deletedservices/read',
            'Microsoft.ApiManagement/locations/deletedservices/delete',
            'Microsoft.CognitiveServices/locations/resourceGroups/deletedAccounts/read',
            'Microsoft.CognitiveServices/locations/resourceGroups/deletedAccounts/delete',
        ]}]}
        self.assignment = {'principalId': 'pipeline', 'principalType': 'ServicePrincipal', 'scope': self.scope,
                           'roleDefinitionId': 'delegation', 'conditionVersion': '2.0', 'condition': m.condition(self.ids[:2])}

    def az(self, *args):
        self.assertFalse(any(x in args for x in ['register', 'update', 'create', 'delete']))
        if args[:3] == ('role', 'assignment', 'list'):
            return [self.assignment]
        if '--custom-role-only' in args:
            return [self.delegation, self.purge]
        name = args[args.index('--name') + 1]
        return [{'name': self.ids[m.ROLES.index(name)]}]

    def review(self):
        with patch.object(m, 'az', self.az), patch('sys.argv', ['prepare-mcp.py', '--subscription', 'test-sub', '--pipeline-object-id', 'pipeline']), contextlib.redirect_stdout(io.StringIO()):
            m.main()

    def test_review_is_read_only(self):
        self.review()

    def test_reject_subscription_wide_delegation(self):
        self.delegation['assignableScopes'] = [self.sub]
        with self.assertRaises(AssertionError):
            self.review()

    def test_reject_unknown_condition(self):
        self.assignment['condition'] = None
        with self.assertRaises(AssertionError):
            self.review()

    def test_reject_extra_purge_permission(self):
        self.purge['permissions'][0]['actions'].append('*')
        with self.assertRaises(AssertionError):
            self.review()

    def test_both_write_and_delete_constrain_service_principals(self):
        expression = m.condition(self.ids)
        for source in ['Request', 'Resource']:
            self.assertIn(f'@{source}[Microsoft.Authorization/roleAssignments:PrincipalType]', expression)
        self.assertEqual(expression.count("StringEqualsIgnoreCase 'ServicePrincipal'"), 2)
        self.assertNotIn('Owner', m.ROLES)


if __name__ == '__main__':
    unittest.main()
