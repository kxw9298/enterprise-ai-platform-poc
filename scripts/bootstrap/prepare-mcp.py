#!/usr/bin/env python3
"""Review or apply existing POC pipeline prerequisite updates; never deploy workloads."""
import argparse
import json
import pathlib
import subprocess

ROLES = [
    'Cognitive Services OpenAI User', 'Monitoring Metrics Publisher',
    'Network Contributor', 'Managed Identity Operator', 'AcrPull',
]
PROVIDERS = ['Microsoft.ContainerService', 'Microsoft.ContainerRegistry', 'Microsoft.PowerPlatform']
PURGE_ACTION = 'Microsoft.ApiManagement/locations/deletedServices/read'


def az(*args):
    return json.loads(subprocess.check_output(['az', *args, '-o', 'json'], text=True) or 'null')


def only(items, label):
    if len(items) != 1:
        raise SystemExit(f'Expected exactly one {label}; found {len(items)}. Review manually.')
    return items[0]


def condition(ids):
    values = ', '.join(ids)
    def clause(action, source):
        return (f"((!(ActionMatches{{'Microsoft.Authorization/roleAssignments/{action}'}})) OR "
                f"(@{source}[Microsoft.Authorization/roleAssignments:RoleDefinitionId] "
                f"ForAnyOfAnyValues:GuidEquals {{{values}}} AND "
                f"@{source}[Microsoft.Authorization/roleAssignments:PrincipalType] "
                "StringEqualsIgnoreCase 'ServicePrincipal'))")
    return clause('write', 'Request') + ' AND ' + clause('delete', 'Resource')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--subscription', required=True)
    parser.add_argument('--pipeline-object-id', required=True)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    sub = '/subscriptions/' + args.subscription
    scope = sub + '/resourceGroups/rg-ai-platform-poc'
    common = ['--subscription', args.subscription]
    definitions = az('role', 'definition', 'list', '--custom-role-only', 'true', *common)
    delegation = only([r for r in definitions if r['roleName'] == 'AI POC Gateway Role Delegation'], 'delegation role')
    purge = only([r for r in definitions if r['roleName'] == 'AI POC Deleted Service Purge'], 'purge role')
    assert delegation['assignableScopes'] == [scope], 'Unexpected delegation scope'
    assert purge['assignableScopes'] == [sub], 'Unexpected purge scope'
    assignments = az('role', 'assignment', 'list', '--all', *common)
    assignment = only([r for r in assignments if r['principalId'] == args.pipeline_object_id
                       and r['scope'].lower() == scope.lower()
                       and r['roleDefinitionId'].lower() == delegation['id'].lower()], 'pipeline delegation assignment')
    assert assignment['principalType'] == 'ServicePrincipal', 'Unexpected pipeline principal type'
    ids = [only(az('role', 'definition', 'list', '--name', name, *common), name)['name'] for name in ROLES]
    old_condition = condition(ids[:2])
    new_condition = condition(ids)
    assert assignment['conditionVersion'] == '2.0' and assignment['condition'] in (old_condition, new_condition), 'Unexpected existing delegation condition'
    permissions = purge['permissions']
    assert len(permissions) == 1, 'Unexpected purge permission blocks'
    permission = permissions[0]
    expected_actions = {
        'microsoft.apimanagement/deletedservices/read',
        'microsoft.apimanagement/locations/deletedservices/delete',
        'microsoft.cognitiveservices/locations/resourcegroups/deletedaccounts/read',
        'microsoft.cognitiveservices/locations/resourcegroups/deletedaccounts/delete',
    }
    actual_actions = {a.lower() for a in permission['actions']}
    assert actual_actions in (expected_actions, expected_actions | {PURGE_ACTION.lower()}), 'Unexpected purge actions'
    assert not any(permission.get(k) for k in ['notActions', 'dataActions', 'notDataActions', 'condition']), 'Unexpected purge exclusions or data actions'
    print('Provider registrations:', ', '.join(PROVIDERS))
    print('Pipeline delegation scope:', scope)
    print('Allowed roles for service principals only:', ', '.join(ROLES))
    print('Purge role: add only', PURGE_ACTION, '(existing subscription scope)')
    print('No billing upgrade, quota request, environment association or workload deployment.')
    if not args.apply:
        print('Review only; pass --apply to execute.')
        return
    records = pathlib.Path('.local/deployment-prerequisites/mcp-update')
    records.mkdir(parents=True, exist_ok=True)
    for name, value in [('delegation-before', assignment), ('purge-before', purge)]:
        path = records / (name + '.json')
        if not path.exists():
            path.write_text(json.dumps(value, indent=2) + '\n')
    for provider in PROVIDERS:
        state = az('provider', 'show', '--namespace', provider, *common)['registrationState']
        if state != 'Registered':
            az('provider', 'register', '--namespace', provider, *common)
    if PURGE_ACTION.lower() not in actual_actions:
        permission['actions'].append(PURGE_ACTION)
        payload = {'Name': purge['roleName'], 'Id': purge['name'], 'IsCustom': True,
                   'Description': purge['description'], 'Actions': permission['actions'],
                   'NotActions': [], 'DataActions': [], 'NotDataActions': [], 'AssignableScopes': [sub]}
        az('role', 'definition', 'update', '--role-definition', json.dumps(payload), *common)
    if assignment['condition'] != new_condition:
        assignment['condition'] = new_condition
        az('role', 'assignment', 'update', '--role-assignment', json.dumps(assignment), *common)
    fresh = az('role', 'assignment', 'list', '--all', *common)
    verified = only([r for r in fresh if r['id'] == assignment['id']], 'updated assignment')
    assert verified['condition'] == new_condition
    updated_purge = only(az('role', 'definition', 'list', '--name', purge['name'], *common), 'updated purge role')
    assert PURGE_ACTION.lower() in {a.lower() for a in updated_purge['permissions'][0]['actions']}
    for name, value in [('delegation-after', verified), ('purge-after', updated_purge)]:
        (records / (name + '.json')).write_text(json.dumps(value, indent=2) + '\n')
    print('Role updates verified. Provider registration may still be completing; recheck before apply.')


if __name__ == '__main__':
    main()
