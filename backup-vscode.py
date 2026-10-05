#!/usr/bin/env python3
"""Export VS Code preferences into config/; --install restores installed Code state.

Run the export after Settings Sync finishes. No editor is launched during export.
Python 3.9+, standard library only.
"""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import shutil
import sqlite3
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parent
EDITOR = Path('.config/Code - OSS')
FILES = ('settings.json', 'keybindings.json', 'tasks.json', 'mcp.json', 'chatLanguageModels.json')
DIRECTORIES = ('snippets', 'prompts', 'agent-plugins')
TARGETS = '__$__targetStorageMarker'


def read_json(path, default=None):
    if not path.exists():
        return default
    text = path.read_text(encoding='utf-8-sig')
    # Preserve strings containing URLs, comment-like text or ",}".
    text = re.sub(r'"(?:\\.|[^"\\])*"|/\*.*?\*/|//[^\r\n]*',
                  lambda m: m[0] if m[0].startswith('"') else ' ', text, flags=re.S)
    text = re.sub(r'"(?:\\.|[^"\\])*"|,\s*(?=[}\]])',
                  lambda m: m[0] if m[0].startswith('"') else '', text)
    return json.loads(text)


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + '.tmp')
    temporary.write_text(json.dumps(value, indent=2, ensure_ascii=False, sort_keys=True) + '\n', encoding='utf-8')
    temporary.replace(path)


def profile_location(value, user):
    if isinstance(value, dict):  # Older VS Code releases stored an absolute URI.
        value = str(Path(value['path']).relative_to(user / 'profiles'))
    path = Path(value)
    if not path.parts or path.is_absolute() or '..' in path.parts:
        raise ValueError(f'Invalid profile location: {value!r}')
    return path.as_posix()


def extension_list(index, extensions):
    entries = read_json(index)
    if entries is None:
        if index != extensions / 'extensions.json':
            return []
        entries = []
        for path in extensions.glob('*/package.json'):
            package = read_json(path)
            entries.append({'identifier': {'id': package['publisher'] + '.' + package['name']},
                            'version': package['version']})
    selected = {}
    for entry in entries:
        identifier, version = entry['identifier']['id'].lower(), entry['version']
        if not re.fullmatch(r'[a-z0-9_-]+\.[a-z0-9_.-]+', identifier):
            raise ValueError(f'Invalid extension ID: {identifier!r}')
        if not re.fullmatch(r'\d+\.\d+\.\d+(?:-[\w.-]+)?(?:\+[\w.-]+)?', version):
            raise ValueError(f'Invalid extension version: {version!r}')
        order = (tuple(map(int, version.split('-')[0].split('+')[0].split('.'))), '-' not in version, version)
        if identifier not in selected or order > selected[identifier][0]:
            selected[identifier] = (order, version)
    return [identifier + '@' + selected[identifier][1] for identifier in sorted(selected)]


def preference_state(profile):
    database = profile / 'globalStorage/state.vscdb'
    if not database.exists():
        return {}
    with sqlite3.connect(database.as_uri() + '?mode=ro', uri=True) as connection:
        rows = dict(connection.execute('SELECT key, value FROM ItemTable'))
    targets = json.loads(rows.get(TARGETS, '{}'))
    extra_ui = {'views.customizations', 'remote.explorerType', 'terminal.hidden',
                'tabs-list-width-horizontal'}
    result = {}
    for key, value in rows.items():
        if (targets.get(key) == 0 and (key.startswith('workbench.') or key in extra_ui)
                and not key.startswith('workbench.welcome')
                or key in ('extensionsIdentifiers/disabled', 'extensionsIdentifiers/enabled')):
            result[key] = {'value': value, 'target': targets.get(key, 1)}
        elif key.startswith('extensionKeys/'):
            # Extensions declare which global-state fields are portable via setKeysForSync.
            identifier = key[len('extensionKeys/'):].rsplit('@', 1)[0].lower()
            state = json.loads(rows.get(identifier, '{}'))
            keys = json.loads(value)
            synced = {name: state[name] for name in keys if name in state}
            result[key] = {'value': value, 'target': 1}
            if synced:
                previous = json.loads(result.get(identifier, {}).get('value', '{}'))
                result[identifier] = {'value': json.dumps({**previous, **synced}), 'target': 1, 'merge': True}
    return result


def export(user_data, extensions, config):
    user = user_data / 'User'
    if not user.is_dir():
        raise ValueError(f'VS Code User directory is missing: {user}')
    if config.resolve() == user_data.resolve() or user_data.resolve() in config.resolve().parents:
        raise ValueError('Export destination must be outside the source user-data directory')
    registrations = read_json(user / 'globalStorage/storage.json', {}).get('userDataProfiles', [])
    profiles = [{'name': None, 'location': ''}]
    for registration in registrations:
        if registration.get('isTransient'):
            continue
        location = profile_location(registration['location'], user)
        profiles.append({**{key: registration[key] for key in ('name', 'icon', 'useDefaultFlags')
                            if key in registration}, 'location': location})
    config.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='.vscode-export-', dir=config) as temporary:
        stage = Path(temporary)
        bundle = stage / EDITOR
        for profile in profiles:
            relative = Path('User/profiles') / profile['location'] if profile['location'] else Path('User')
            source = user_data / relative
            destination = bundle / relative
            destination.mkdir(parents=True, exist_ok=True)
            for name in FILES:
                if (source / name).exists():
                    read_json(source / name)  # Validate before replacing any previous export.
                    shutil.copy2(source / name, destination / name)
            for name in DIRECTORIES:
                if (source / name).is_dir():
                    shutil.copytree(source / name, destination / name)
            write_json(destination / 'globalStorage/dots-state.json', preference_state(source))
            inherited = profile.get('useDefaultFlags', {}).get('extensions')
            index = source / 'extensions.json' if profile['location'] else extensions / 'extensions.json'
            profile['extensions'] = [] if inherited else extension_list(index, extensions)
        if not (bundle / 'User/settings.json').exists():
            write_json(bundle / 'User/settings.json', {})
        write_json(bundle / 'dots-profiles.json', profiles)
        argv = read_json(extensions.parent / 'argv.json', {})
        argv.pop('crash-reporter-id', None)
        write_json(stage / '.vscode-oss/argv.json', argv)
        # Keep the previous generated configuration recoverable when refreshing it.
        stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S.%fZ')
        recovery = config.parent / 'backups' / ('vscode-config-' + stamp)
        for relative in (EDITOR, Path('.vscode-oss')):
            target = config / relative
            if target.is_symlink():
                raise ValueError(f'Refusing a symlinked export destination: {target}')
        for relative in (EDITOR, Path('.vscode-oss')):
            target = config / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            if target.exists():
                saved = recovery / relative
                saved.parent.mkdir(parents=True, exist_ok=True)
                target.rename(saved)
            (stage / relative).rename(target)
    count = len({extension for profile in profiles for extension in profile['extensions']})
    print(f'Exported {len(profiles)} profiles and {count} extension versions to {config}')
    if recovery.exists():
        print(f'Previous export: {recovery}')


def install(config):
    bundle = config / EDITOR
    profiles = read_json(bundle / 'dots-profiles.json')
    if not profiles:
        raise ValueError('Copy dotfiles first: Code profile configuration is missing')
    if config.resolve() == (ROOT / 'config').resolve():
        raise ValueError('--install needs --config-dir pointing to the installed home, not the repository')
    # Code caches its state in memory; writing while it runs would be lost on exit.
    running = subprocess.run(['pgrep', '-u', str(os.getuid()), '-f',
                              r'(^|/)(code|code-oss)( |$)|/usr/lib/code/(code\.mjs|out/cli\.js)'],
                             capture_output=True)
    if running.returncode == 0:
        raise ValueError('Close Code before installing its saved state')
    if running.returncode != 1:
        raise ValueError('Could not check whether Code is running')
    if not shutil.which('code'):
        raise ValueError('Install the Arch code package first')
    user = bundle / 'User'
    # Preserve existing workspace/session information while registering saved profiles.
    storage_file = user / 'globalStorage/storage.json'
    storage = read_json(storage_file, {})
    stored = {profile['location']: profile for profile in storage.get('userDataProfiles', [])}
    for profile in profiles:
        if profile['location']:
            location = profile_location(profile['location'], user)
            (user / 'profiles' / location).mkdir(parents=True, exist_ok=True)
            stored[location] = {key: value for key, value in profile.items() if key != 'extensions'}
    storage['userDataProfiles'] = list(stored.values())
    write_json(storage_file, storage)
    failures = []
    for profile in profiles:
        command = ['code', '--user-data-dir', str(bundle), '--extensions-dir',
                   str(config / '.vscode-oss/extensions')]
        if profile['name'] is not None:
            command += ['--profile', profile['name']]
        for extension in profile['extensions']:
            source = str(bundle / extension) if extension.endswith('.vsix') else extension
            result = subprocess.run(command + ['--install-extension', source, '--force'])
            if result.returncode:
                failures.append(extension)
        relative = Path('profiles') / profile['location'] if profile['location'] else Path()
        directory = user / relative / 'globalStorage'
        state = read_json(directory / 'dots-state.json', {})
        directory.mkdir(parents=True, exist_ok=True)
        with sqlite3.connect(directory / 'state.vscdb') as connection:
            connection.execute('CREATE TABLE IF NOT EXISTS ItemTable (key TEXT UNIQUE ON CONFLICT REPLACE, value BLOB)')
            rows = dict(connection.execute('SELECT key, value FROM ItemTable'))
            targets = json.loads(rows.get(TARGETS, '{}'))
            for key, entry in state.items():
                value = entry['value']
                if entry.get('merge'):
                    value = json.dumps({**json.loads(rows.get(key, '{}')), **json.loads(value)})
                connection.execute('INSERT OR REPLACE INTO ItemTable VALUES (?, ?)', (key, value))
                targets[key] = entry['target']
            connection.execute('INSERT OR REPLACE INTO ItemTable VALUES (?, ?)', (TARGETS, json.dumps(targets)))
    if failures:
        raise ValueError('Extensions could not be installed: ' + ', '.join(failures) +
                         '. Provide compatible VSIX files or adjust dots-profiles.json, then retry.')
    print('Code profiles, extensions, enablement and UI preferences installed')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config-dir', type=Path, default=ROOT / 'config',
                        help='export destination; with --install, the installed home directory')
    parser.add_argument('--user-data-dir', type=Path, help='source directory containing User/')
    parser.add_argument('--extensions-dir', type=Path, help='source installed extensions directory')
    parser.add_argument('--install', action='store_true', help='installer mode: restore exported state and extensions')
    args = parser.parse_args()
    try:
        config = args.config_dir.expanduser().absolute()
        if args.install:
            install(config)
        else:
            home = Path.home()
            if sys.platform == 'darwin':
                data = home / 'Library/Application Support/Code'
            elif os.name == 'nt':
                data = Path(os.environ.get('APPDATA', home / 'AppData/Roaming')) / 'Code'
            else:
                data = Path(os.environ.get('XDG_CONFIG_HOME', home / '.config')) / 'Code'
            export((args.user_data_dir or data).expanduser().absolute(),
                   (args.extensions_dir or home / '.vscode/extensions').expanduser().absolute(), config)
        return 0
    except (OSError, ValueError, KeyError, TypeError, sqlite3.Error, RecursionError) as error:
        print(f'VS Code configuration failed: {error}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
