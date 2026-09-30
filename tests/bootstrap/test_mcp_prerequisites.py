"""Ensure prerequisite review refuses unexpected scopes and role delegation."""
import contextlib
import importlib.util
import io
import json
import os
import pathlib
import tempfile
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


class ApplyPayloadTests(unittest.TestCase):
    """The apply path must emit payloads the Azure CLI accepts and stay scoped."""

    def setUp(self):
        self.sub = '/subscriptions/test-sub'
        self.scope = self.sub + '/resourceGroups/rg-ai-platform-poc'
        self.ids = [f'role-{i}' for i in range(3)]
        self.delegation = {'roleName': 'AI POC Gateway Role Delegation', 'id': 'delegation',
                           'assignableScopes': [self.scope]}
        self.purge = {'roleName': 'AI POC Deleted Service Purge', 'name': 'purge-guid',
                      'description': 'test role', 'assignableScopes': [self.sub],
                      'permissions': [{'actions': [
                          'Microsoft.ApiManagement/deletedservices/read',
                          'Microsoft.ApiManagement/locations/deletedservices/delete',
                          'Microsoft.CognitiveServices/locations/resourceGroups/deletedAccounts/read',
                          'Microsoft.CognitiveServices/locations/resourceGroups/deletedAccounts/delete',
                      ], 'notActions': [], 'dataActions': [], 'notDataActions': []}]}
        self.assignment = {'id': 'assignment-id', 'name': 'assignment-guid', 'principalId': 'pipeline',
                           'principalType': 'ServicePrincipal', 'scope': self.scope,
                           'roleDefinitionId': 'delegation', 'conditionVersion': '2.0',
                           'condition': m.condition(self.ids[:2])}
        self.role_payloads = []
        self.assignment_payloads = []
        self.provider_states = {p: 'Registered' for p in m.PROVIDERS}
        self.registered = []

    def az(self, *args):
        if args[:3] == ('role', 'definition', 'update'):
            payload = json.loads(args[args.index('--role-definition') + 1])
            self.role_payloads.append(payload)
            self.purge['permissions'][0]['actions'] = payload['actions']
            return {}
        if args[:3] == ('role', 'assignment', 'update'):
            payload = json.loads(args[args.index('--role-assignment') + 1])
            self.assignment_payloads.append(payload)
            self.assignment['condition'] = payload['condition']
            return {}
        if args[:2] == ('provider', 'register'):
            provider = args[args.index('--namespace') + 1]
            self.registered.append(provider)
            self.provider_states[provider] = 'Registered'
            return {}
        if args[:2] == ('provider', 'show'):
            return {'registrationState': self.provider_states[args[args.index('--namespace') + 1]]}
        if args[:3] == ('role', 'assignment', 'list'):
            return [self.assignment]
        if '--custom-role-only' in args:
            return [self.delegation, self.purge]
        name = args[args.index('--name') + 1]
        if name == self.purge['name']:
            return [self.purge]
        return [{'name': self.ids[m.ROLES.index(name)]}]

    def apply(self):
        argv = ['prepare-mcp.py', '--subscription', 'test-sub', '--pipeline-object-id', 'pipeline', '--apply']
        with tempfile.TemporaryDirectory() as tmp:
            previous = os.getcwd()
            os.chdir(tmp)
            try:
                with patch.object(m, 'az', self.az), patch('sys.argv', argv), contextlib.redirect_stdout(io.StringIO()):
                    m.main()
            finally:
                os.chdir(previous)

    def test_role_update_payload_matches_azure_cli_schema(self):
        self.apply()
        payload = self.role_payloads[0]
        self.assertIn('roleName', payload)
        self.assertIn('id', payload)
        self.assertNotIn('Name', payload)
        self.assertNotIn('IsCustom', payload)
        self.assertEqual(payload['assignableScopes'], [self.sub])
        self.assertIn(m.PURGE_ACTION, payload['actions'])
        self.assertEqual(payload['notActions'], [])
        self.assertEqual(payload['dataActions'], [])

    def test_delegation_condition_stays_service_principal_only(self):
        self.apply()
        condition = self.assignment_payloads[0]['condition']
        self.assertEqual(condition.count("StringEqualsIgnoreCase 'ServicePrincipal'"), 2)
        self.assertIn('delete', condition)
        self.assertNotIn('Owner', condition)

    def test_apply_registers_only_unregistered_named_providers(self):
        self.provider_states['Microsoft.ContainerRegistry'] = 'NotRegistered'
        self.apply()
        self.assertEqual(self.registered, ['Microsoft.ContainerRegistry'])
        self.assertLessEqual(set(self.registered), set(m.PROVIDERS))

    def test_apply_is_idempotent_when_already_converged(self):
        self.apply()
        first_roles, first_conditions = list(self.role_payloads), list(self.assignment_payloads)
        self.role_payloads.clear()
        self.assignment_payloads.clear()
        self.apply()
        self.assertEqual(self.role_payloads, [])
        self.assertEqual(self.assignment_payloads, [])
        self.assertTrue(first_roles and first_conditions)


if __name__ == '__main__':
    unittest.main()