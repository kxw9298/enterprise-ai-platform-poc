#!/usr/bin/env python3
"""One-time Azure foundation, using Azure CLI and a local recovery manifest.

No mutation without --execute. No secrets or tokens are written by this script.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import uuid

ROOT = Path(__file__).resolve().parents[2]
LOCAL = ROOT / '.local' / 'bootstrap'
MANIFEST = LOCAL / 'manifest.json'
BLOB_ROLE = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
CONTRIBUTOR = 'b24988ac-6180-42a0-ab88-20f7382dd24c'


def az(*args):
    result = subprocess.run(['az', *args, '--only-show-errors', '-o', 'json'],
                            text=True, capture_output=True, check=False)
    if result.returncode:
        raise RuntimeError(f"az {' '.join(args[:3])} failed:\n{result.stderr.strip()}")
    return json.loads(result.stdout) if result.stdout.strip() else None


def save(manifest):
    LOCAL.mkdir(parents=True, exist_ok=True)
    temporary = MANIFEST.with_suffix('.tmp')
    temporary.write_text(json.dumps(manifest, indent=2) + '\n')
    temporary.chmod(0o600)
    temporary.replace(MANIFEST)


def configuration(path):
    config = json.loads(Path(path).read_text())
    for key in ('subscription_id', 'tenant_id'):
        config[key] = str(uuid.UUID(config[key]))
    for key in ('bootstrap_resource_group', 'workload_resource_group'):
        if not re.fullmatch(r'[a-zA-Z0-9_-]{1,90}', config[key]):
            raise ValueError(f'Invalid {key}')
    if config['bootstrap_resource_group'] == config['workload_resource_group']:
        raise ValueError('Bootstrap and workload resource groups must differ')
    if not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', config['github_repository']):
        raise ValueError('Expected GitHub owner/repository')
    if not re.fullmatch(r'[a-z0-9]+(?:-[a-z0-9]+)*', config['state_container']) or not 3 <= len(config['state_container']) <= 63:
        raise ValueError('Invalid state container name')
    if not config['github_branch'] or not config['state_key']:
        raise ValueError('Branch and state key are required')
    return config


def context(config):
    sub = '/subscriptions/' + config['subscription_id']
    suffix = hashlib.sha256((sub + '/' + config['github_repository']).encode()).hexdigest()[:12]
    rg = sub + '/resourceGroups/' + config['bootstrap_resource_group']
    storage = 'staipoc' + suffix
    storage_id = rg + '/providers/Microsoft.Storage/storageAccounts/' + storage
    return dict(subscription_scope=sub, bootstrap_id=rg, storage_name=storage,
                storage_id=storage_id,
                container_id=storage_id + '/blobServices/default/containers/' + config['state_container'],
                workload_id=sub + '/resourceGroups/' + config['workload_resource_group'],
                app_name='github-ai-platform-poc-' + suffix,
                role_id=str(uuid.uuid5(uuid.NAMESPACE_URL, sub + '/ai-poc-rg-writer/' + suffix)),
                role_name='AI POC Resource Group Writer ' + suffix,
                subject=f"repo:{config['github_repository']}:ref:refs/heads/{config['github_branch']}")


def check_account(config):
    account = az('account', 'show')
    if account['id'].lower() != config['subscription_id'] or account['tenantId'].lower() != config['tenant_id']:
        raise RuntimeError('Wrong active subscription/tenant. Run az login and az account set as documented.')
    if account['state'] != 'Enabled':
        raise RuntimeError('Subscription is not enabled')


def owned(resource, token):
    if resource.get('tags', {}).get('bootstrap-id') != token:
        raise RuntimeError('Ownership tag mismatch; refusing to adopt or delete resource')


def check_state(config, c):
    containers = az('storage', 'container-rm', 'list', '--storage-account', c['storage_name'],
                    '-g', config['bootstrap_resource_group'], '--subscription', config['subscription_id'])
    if any(item['name'] != config['state_container'] for item in containers):
        raise RuntimeError('Unexpected storage containers; refusing state storage deletion')
    if not containers:
        return
    blobs = az('storage', 'blob', 'list', '--account-name', c['storage_name'],
               '--container-name', config['state_container'], '--auth-mode', 'login')
    for blob in blobs:
        if blob['name'] != config['state_key']:
            raise RuntimeError('Unexpected state/blob found; inspect other workspaces before cleanup')
        if blob.get('properties', {}).get('lease', {}).get('status') == 'locked':
            raise RuntimeError('Terraform state is locked; stop the active operation before cleanup')
        # State can contain secrets: use a private temporary file and never print its contents.
        with tempfile.TemporaryDirectory(dir=LOCAL) as directory:
            state_file = Path(directory) / 'state.json'
            az('storage', 'blob', 'download', '--account-name', c['storage_name'],
               '--container-name', config['state_container'], '--name', blob['name'],
               '--auth-mode', 'login', '--file', str(state_file), '--no-progress')
            state = json.loads(state_file.read_text())
        if not isinstance(state, dict) or state.get('version') != 4 or not isinstance(state.get('resources'), list):
            raise RuntimeError('Unrecognized Terraform state format; inspect it manually')
        if any(r.get('mode') == 'managed' and r.get('instances') for r in state['resources']):
            raise RuntimeError('State still contains managed resources; run Terraform destroy first')


def assignment(manifest, config, principal, role, scope):
    name = str(uuid.uuid5(uuid.NAMESPACE_URL, principal + role + scope))
    resource_id = scope + '/providers/Microsoft.Authorization/roleAssignments/' + name
    # Journal BEFORE mutation, so interruptions can be retried or cleaned up.
    if resource_id not in manifest['assignments']:
        manifest['assignments'].append(resource_id)
        save(manifest)
    az('role', 'assignment', 'create', '--name', name,
       '--assignee-object-id', principal, '--assignee-principal-type',
       'User' if principal == manifest['operator_id'] else 'ServicePrincipal',
       '--role', role, '--scope', scope, '--subscription', config['subscription_id'])


def provision(config, manifest):
    c = context(config)
    token = manifest['ownership_token']
    tag = 'bootstrap-id=' + token
    subargs = ['--subscription', config['subscription_id']]
    rg = config['bootstrap_resource_group']
    if az('group', 'exists', '-n', rg, *subargs):
        owned(az('group', 'show', '-n', rg, *subargs), token)
    else:
        az('group', 'create', '-n', rg, '-l', config['location'], '--tags',
           tag, 'project=enterprise-ai-platform-poc', 'managed-by=bootstrap-cli', *subargs)
    accounts = az('storage', 'account', 'list', '-g', rg, *subargs)
    existing = next((a for a in accounts if a['name'] == c['storage_name']), None)
    if existing:
        owned(existing, token)
        if existing.get('allowSharedKeyAccess') is not False or existing.get('allowBlobPublicAccess') is not False:
            raise RuntimeError('Storage authentication settings drifted; review before rerunning')
    else:
        az('storage', 'account', 'create', '-g', rg, '-n', c['storage_name'],
           '-l', config['location'], '--sku', 'Standard_LRS', '--kind', 'StorageV2',
           '--https-only', 'true', '--min-tls-version', 'TLS1_2',
           '--allow-blob-public-access', 'false', '--allow-shared-key-access', 'false',
           '--public-network-access', 'Enabled', '--tags', tag,
           'project=enterprise-ai-platform-poc', 'managed-by=bootstrap-cli', *subargs)
    az('storage', 'account', 'blob-service-properties', 'update', '-g', rg,
       '--account-name', c['storage_name'], '--enable-versioning', 'true',
       '--enable-delete-retention', 'true', '--delete-retention-days', '7', *subargs)
    az('storage', 'container-rm', 'create', '-g', rg, '--storage-account', c['storage_name'],
       '-n', config['state_container'], '--public-access', 'off', *subargs)

    apps = az('ad', 'app', 'list', '--display-name', c['app_name'])
    apps = [a for a in apps if a['displayName'] == c['app_name']]
    if len(apps) > 1:
        raise RuntimeError('Multiple applications match; resolve manually')
    if apps:
        app = apps[0]
        if app.get('description') != token:
            raise RuntimeError('Application ownership mismatch; refusing to adopt')
    else:
        app = az('ad', 'app', 'create', '--display-name', c['app_name'],
                 '--description', token, '--sign-in-audience', 'AzureADMyOrg')
    manifest['application_id'] = app['id']
    manifest['client_id'] = app['appId']
    save(manifest)
    principals = az('ad', 'sp', 'list', '--filter', f"appId eq '{app['appId']}'")
    principal = principals[0] if principals else az('ad', 'sp', 'create', '--id', app['appId'])
    manifest['principal_id'] = principal['id']
    save(manifest)
    credential = dict(name='github-main', issuer='https://token.actions.githubusercontent.com',
                      subject=c['subject'], audiences=['api://AzureADTokenExchange'])
    credentials = az('ad', 'app', 'federated-credential', 'list', '--id', app['id'])
    existing = next((x for x in credentials if x['name'] == credential['name']), None)
    if existing:
        if any(existing.get(k) != v for k, v in credential.items()):
            raise RuntimeError('Existing federation differs; review it manually')
    else:
        az('ad', 'app', 'federated-credential', 'create', '--id', app['id'],
           '--parameters', json.dumps(credential))

    role = dict(Name=c['role_name'], Id=c['role_id'], IsCustom=True,
                Description=token,
                Actions=['Microsoft.Resources/subscriptions/resourceGroups/read',
                         'Microsoft.Resources/subscriptions/resourceGroups/write',
                         'Microsoft.Resources/subscriptions/read',
                         'Microsoft.Resources/subscriptions/providers/read',
                         'Microsoft.Resources/subscriptions/locations/read'],
                NotActions=[], DataActions=[], NotDataActions=[],
                AssignableScopes=[c['subscription_scope']])
    roles = az('role', 'definition', 'list', '--name', c['role_id'], *subargs)
    if roles:
        if roles[0]['description'] != token:
            raise RuntimeError('Role ownership mismatch')
        expected_permissions = [dict(actions=role['Actions'], notActions=[], dataActions=[], notDataActions=[])]
        if roles[0]['permissions'] != expected_permissions or roles[0]['assignableScopes'] != role['AssignableScopes']:
            raise RuntimeError('Custom role permissions drifted; review before rerunning')
    else:
        az('role', 'definition', 'create', '--role-definition', json.dumps(role), *subargs)
    assignment(manifest, config, principal['id'], c['role_id'], c['subscription_scope'])
    for identity in (principal['id'], manifest['operator_id']):
        assignment(manifest, config, identity, BLOB_ROLE, c['container_id'])
    manifest['provisioned'] = True
    save(manifest)
    backend = dict(storage_account_name=c['storage_name'], container_name=config['state_container'],
                   key=config['state_key'], tenant_id=config['tenant_id'], use_azuread_auth=True)
    (LOCAL / 'backend.hcl').write_text(''.join(f'{k} = {json.dumps(v)}\n' for k, v in backend.items()))
    variables = dict(AZURE_CLIENT_ID=app['appId'], AZURE_TENANT_ID=config['tenant_id'],
                     AZURE_SUBSCRIPTION_ID=config['subscription_id'], TF_STATE_STORAGE_ACCOUNT=c['storage_name'],
                     TF_STATE_CONTAINER=config['state_container'], TF_STATE_KEY=config['state_key'])
    (LOCAL / 'github-variables.json').write_text(json.dumps(variables, indent=2) + '\n')
    print('Bootstrap complete. Backend config and GitHub variable values are in .local/bootstrap/.')
    print('No GitHub settings changed. RBAC propagation may take several minutes.')


def grant_workload(config, manifest):
    if not manifest.get('provisioned'):
        raise RuntimeError('Finish bootstrap before granting workload access')
    c = context(config)
    group = az('group', 'show', '-n', config['workload_resource_group'], '--subscription', config['subscription_id'])
    if group.get('tags', {}).get('project') != 'enterprise-ai-platform-poc' or group.get('tags', {}).get('managed-by') != 'terraform':
        raise RuntimeError('Workload group must carry project=enterprise-ai-platform-poc and managed-by=terraform tags')
    assignment(manifest, config, manifest['principal_id'], CONTRIBUTOR, c['workload_id'])
    print('Contributor assigned to the workload group only. Role-assignment administration is not granted.')


def cleanup(config, manifest):
    c = context(config)
    subargs = ['--subscription', config['subscription_id']]
    # Check ALL guards before any destructive call. Do not treat API errors as absence.
    if az('group', 'exists', '-n', config['workload_resource_group'], *subargs):
        raise RuntimeError('Workload resource group still exists. Run Terraform destroy first.')
    exists = az('group', 'exists', '-n', config['bootstrap_resource_group'], *subargs)
    if exists:
        owned(az('group', 'show', '-n', config['bootstrap_resource_group'], *subargs), manifest['ownership_token'])
        resources = az('resource', 'list', '-g', config['bootstrap_resource_group'], *subargs)
        unexpected = [r['id'] for r in resources if r['id'].lower() != c['storage_id'].lower()]
        if unexpected:
            raise RuntimeError('Unexpected resources in bootstrap group; refusing deletion: ' + str(unexpected))
        if resources:
            owned(az('storage', 'account', 'show', '-g', config['bootstrap_resource_group'],
                     '-n', c['storage_name'], *subargs), manifest['ownership_token'])
            check_state(config, c)
    apps = az('ad', 'app', 'list', '--display-name', c['app_name'])
    apps = [a for a in apps if a['displayName'] == c['app_name']]
    if len(apps) > 1 or any(a.get('description') != manifest['ownership_token'] for a in apps):
        raise RuntimeError('Application ownership mismatch')
    if apps and manifest.get('application_id') and apps[0]['id'] != manifest['application_id']:
        raise RuntimeError('Application ID changed')
    roles = az('role', 'definition', 'list', '--name', c['role_id'], *subargs)
    if roles and roles[0]['description'] != manifest['ownership_token']:
        raise RuntimeError('Custom role ownership mismatch')
    assignments = az('role', 'assignment', 'list', '--all', *subargs)
    role_assignments = [a for a in assignments if a['roleDefinitionId'].lower().endswith('/' + c['role_id'])]
    if any(a['id'].lower() not in {x.lower() for x in manifest['assignments']} for a in role_assignments):
        raise RuntimeError('Custom role is used by untracked assignments; review manually')
    for item in assignments:
        if item['id'].lower() in {x.lower() for x in manifest['assignments']}:
            # Container assignments disappear with the group. Retain the operator's
            # state-read access until then so a failed group deletion is retryable.
            if not item['id'].lower().startswith(c['container_id'].lower() + '/'):
                az('role', 'assignment', 'delete', '--ids', item['id'], *subargs)
    if roles:
        az('role', 'definition', 'delete', '--name', c['role_id'], *subargs)
    if apps:
        principals = az('ad', 'sp', 'list', '--filter', f"appId eq '{apps[0]['appId']}'")
        for principal in principals:
            az('ad', 'sp', 'delete', '--id', principal['id'])
        az('ad', 'app', 'delete', '--id', apps[0]['id'])
    if exists:
        az('group', 'delete', '-n', config['bootstrap_resource_group'], '--yes', *subargs)
    manifest['cleaned_up'] = True
    save(manifest)
    print('Bootstrap deleted. Local records retained. Remove any GitHub variables/workflows separately as documented.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('operation', choices=['provision', 'grant-workload', 'cleanup'])
    parser.add_argument('--config', default=str(Path(__file__).with_name('config.json')))
    parser.add_argument('--execute', action='store_true', help='Actually change Azure; otherwise print an offline preview')
    parser.add_argument('--confirm-state-deletion', help='For cleanup: exact subscription ID, acknowledging destruction of state and versions')
    args = parser.parse_args()
    config = configuration(args.config)
    print(json.dumps(dict(operation=args.operation, config=config, derived=context(config)), indent=2))
    if not args.execute:
        print('PREVIEW ONLY. No Azure calls or local changes. See docs/runbooks/bootstrap.md for permissions and cleanup order.')
        return
    if args.operation == 'cleanup' and args.confirm_state_deletion != config['subscription_id']:
        raise RuntimeError('Cleanup requires --confirm-state-deletion with the exact subscription ID')
    check_account(config)
    if MANIFEST.exists():
        manifest = json.loads(MANIFEST.read_text())
        if manifest['config'] != config:
            raise RuntimeError('Config differs from saved manifest; restore original config before continuing')
        if manifest.get('cleaned_up') and args.operation != 'cleanup':
            raise RuntimeError('Previous bootstrap was cleaned up. Archive .local/bootstrap before a fresh bootstrap.')
    elif args.operation == 'provision':
        operator = az('ad', 'signed-in-user', 'show')
        manifest = dict(version=1, config=config, ownership_token=str(uuid.uuid4()),
                        operator_id=operator['id'], assignments=[])
        save(manifest)
    else:
        raise RuntimeError('Missing .local/bootstrap/manifest.json; restore it before continuing')
    {'provision': provision, 'grant-workload': grant_workload, 'cleanup': cleanup}[args.operation](config, manifest)


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, ValueError, KeyError, OSError) as error:
        print(f'ERROR: {error}', file=sys.stderr)
        sys.exit(1)
