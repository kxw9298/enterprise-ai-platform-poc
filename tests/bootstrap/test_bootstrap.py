"""Safety tests: all Azure calls are mocked; no credentials or cloud writes."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('bootstrap', ROOT / 'scripts/bootstrap/bootstrap.py')
b = importlib.util.module_from_spec(spec)
spec.loader.exec_module(b)


class BootstrapTests(unittest.TestCase):
    def setUp(self):
        self.config = b.configuration(ROOT / 'scripts/bootstrap/config.json')
        self.ctx = b.context(self.config)
        self.manifest = dict(config=self.config, ownership_token='owned', operator_id='operator', assignments=[])

    def test_preview_never_calls_azure(self):
        for operation in ('provision', 'cleanup', 'grant-workload'):
            with patch.object(b, 'az') as cli, patch('sys.argv', ['bootstrap.py', operation]), patch('builtins.print'):
                b.main()
                cli.assert_not_called()

    def test_cleanup_needs_exact_confirmation_before_azure(self):
        with patch.object(b, 'az') as cli, patch('sys.argv', ['bootstrap.py', 'cleanup', '--execute']), patch('builtins.print'):
            with self.assertRaisesRegex(RuntimeError, 'exact subscription'):
                b.main()
            cli.assert_not_called()

    def test_wrong_tenant_rejected(self):
        with patch.object(b, 'az', return_value=dict(id=self.config['subscription_id'], tenantId='wrong', state='Enabled')):
            with self.assertRaisesRegex(RuntimeError, 'Wrong active'):
                b.check_account(self.config)

    def test_workload_blocks_cleanup_before_deletion(self):
        with patch.object(b, 'az', return_value=True) as cli:
            with self.assertRaisesRegex(RuntimeError, 'Terraform destroy'):
                b.cleanup(self.config, self.manifest)
            self.assertEqual(cli.call_count, 1)

    def test_unowned_group_rejected(self):
        with patch.object(b, 'az', side_effect=[False, True, {'tags': {}}]) as cli:
            with self.assertRaisesRegex(RuntimeError, 'Ownership'):
                b.cleanup(self.config, self.manifest)
            self.assertFalse(any('delete' in call.args for call in cli.call_args_list))

    def test_extra_resource_rejected(self):
        with patch.object(b, 'az', side_effect=[False, True, {'tags': {'bootstrap-id': 'owned'}}, [{'id': 'unexpected'}]]) as cli:
            with self.assertRaisesRegex(RuntimeError, 'Unexpected resources'):
                b.cleanup(self.config, self.manifest)
            self.assertFalse(any('delete' in call.args for call in cli.call_args_list))

    def test_api_errors_do_not_mean_absent(self):
        with patch.object(b, 'az', side_effect=RuntimeError('Forbidden')) as cli:
            with self.assertRaisesRegex(RuntimeError, 'Forbidden'):
                b.cleanup(self.config, self.manifest)
            self.assertEqual(cli.call_count, 1)

    def test_locked_or_other_workspace_state_rejected(self):
        for blob in ({'name': 'other.tfstate'}, {'name': self.config['state_key'], 'properties': {'lease': {'status': 'locked'}}}):
            with patch.object(b, 'az', side_effect=[[{'name': self.config['state_container']}], [blob]]):
                with self.assertRaises(RuntimeError):
                    b.check_state(self.config, self.ctx)

    def test_managed_state_rejected_empty_state_allowed(self):
        for resources in ([{'mode': 'managed', 'instances': [{}]}], []):
            def cli(*args):
                if args[:3] == ('storage', 'container-rm', 'list'):
                    return [{'name': self.config['state_container']}]
                if args[:3] == ('storage', 'blob', 'list'):
                    return [{'name': self.config['state_key']}]
                Path(args[args.index('--file') + 1]).write_text(json.dumps({'version': 4, 'resources': resources}))
            with tempfile.TemporaryDirectory() as directory, patch.object(b, 'LOCAL', Path(directory)), patch.object(b, 'az', side_effect=cli):
                if resources:
                    with self.assertRaisesRegex(RuntimeError, 'managed resources'):
                        b.check_state(self.config, self.ctx)
                else:
                    b.check_state(self.config, self.ctx)

    def test_assignment_journaled_before_azure_call(self):
        events = []
        with patch.object(b, 'save', side_effect=lambda m: events.append('saved')), patch.object(b, 'az', side_effect=lambda *a: events.append('azure')):
            b.assignment(self.manifest, self.config, 'principal', b.BLOB_ROLE, self.ctx['container_id'])
            b.assignment(self.manifest, self.config, 'principal', b.BLOB_ROLE, self.ctx['container_id'])
        self.assertEqual(events, ['saved', 'azure', 'azure'])
        self.assertEqual(len(self.manifest['assignments']), 1)

    def test_cleanup_retry_when_already_absent(self):
        with patch.object(b, 'az', side_effect=[False, False, [], [], []]), patch.object(b, 'save'), patch('builtins.print'):
            b.cleanup(self.config, self.manifest)
        self.assertTrue(self.manifest['cleaned_up'])

    def test_grant_refuses_unmanaged_group(self):
        self.manifest['provisioned'] = True
        with patch.object(b, 'az', return_value={'tags': {}}), patch.object(b, 'assignment') as assign:
            with self.assertRaisesRegex(RuntimeError, 'must carry'):
                b.grant_workload(self.config, self.manifest)
            assign.assert_not_called()

    def test_cleanup_deletes_identity_then_group_and_keeps_state_access_until_end(self):
        sub_assignment = self.ctx['subscription_scope'] + '/providers/Microsoft.Authorization/roleAssignments/sub'
        state_assignment = self.ctx['container_id'] + '/providers/Microsoft.Authorization/roleAssignments/state'
        self.manifest['assignments'] = [sub_assignment, state_assignment]
        calls = []

        def cli(*args):
            calls.append(args)
            if args[:2] == ('group', 'exists'):
                return args[args.index('-n') + 1] == self.config['bootstrap_resource_group']
            if args[:2] == ('group', 'show') or args[:3] == ('storage', 'account', 'show'):
                return {'tags': {'bootstrap-id': 'owned'}}
            if args[:2] == ('resource', 'list'):
                return [{'id': self.ctx['storage_id']}]
            if args[:3] == ('ad', 'app', 'list'):
                return [{'id': 'app', 'appId': 'client', 'description': 'owned', 'displayName': self.ctx['app_name']}]
            if args[:3] == ('role', 'definition', 'list'):
                return [{'description': 'owned'}]
            if args[:3] == ('role', 'assignment', 'list'):
                return [{'id': sub_assignment, 'roleDefinitionId': '/roles/' + self.ctx['role_id']},
                        {'id': state_assignment, 'roleDefinitionId': '/roles/' + b.BLOB_ROLE}]
            if args[:3] == ('ad', 'sp', 'list'):
                return [{'id': 'sp'}]

        with patch.object(b, 'az', side_effect=cli), patch.object(b, 'check_state') as check, patch.object(b, 'save'), patch('builtins.print'):
            b.cleanup(self.config, self.manifest)
            check.assert_called_once()
        deletes = [x for x in calls if 'delete' in x]
        self.assertEqual([x[:3] for x in deletes], [('role', 'assignment', 'delete'),
                         ('role', 'definition', 'delete'), ('ad', 'sp', 'delete'),
                         ('ad', 'app', 'delete'), ('group', 'delete', '-n')])
        self.assertFalse(any(state_assignment in x for x in deletes))


if __name__ == '__main__':
    unittest.main()
