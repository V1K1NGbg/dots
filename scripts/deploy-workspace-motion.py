#!/usr/bin/env python3
"""Back up and apply direct vertical workspace switching and the three-layout cycle."""
import importlib.util
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('desktop_deploy', ROOT / 'scripts/deploy-desktop.py')
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)


def main():
    env = helper.session_env()
    verify = env.copy()
    verify.pop('HYPRLAND_INSTANCE_SIGNATURE', None)
    subprocess.run(['lua', 'scripts/check-desktop.lua'], cwd=ROOT, env=verify, check=True)
    directory = Path.home() / '.config/hypr'
    desktop = (directory / 'desktop.lua').read_text()
    source = (ROOT / '.config/hypr/desktop.lua').read_text()
    anchor = '-- Each hop'
    start = desktop.index(anchor if anchor in desktop else 'function M.view(number)')
    end = desktop.index('\nfunction M.move(number)', start)
    desktop = desktop[:start] + source[source.index('function M.view(number)'):source.index('\nfunction M.move(number)')] + desktop[end:]
    anchor = '-- Migrate saved Floating-layout workspaces'
    start = desktop.index(anchor if anchor in desktop else 'function M.cycle_layout()')
    end = desktop.index('\nfunction M.swap', start)
    desktop = desktop[:start] + source[source.index(anchor):source.index('\nfunction M.swap')] + desktop[end:]
    anchor = 'function M.reconcile()\n    if reconciling then return end'
    if anchor + '\n    M.retire_floating_layout()' not in desktop:
        if anchor not in desktop:
            raise RuntimeError('Cannot locate layout migration anchor')
        desktop = desktop.replace(anchor, anchor + '\n    M.retire_floating_layout()', 1)
    desktop = desktop.replace('        if ws and state.modes[ws.id] == "floating" and not window.floating then\n            meta(window).layout_float = true\n            float(window, true)\n        end\n', '')
    config = (directory / 'hyprland.lua').read_text()
    config = config.replace('Cycle Dwindle, Tile, Fair, and Floating layouts', 'Cycle Dwindle, Tile, and Fair layouts')
    leaves = ('workspaces', 'workspacesIn', 'workspacesOut')
    lines = config.splitlines(keepends=True)
    indices = [i for i, line in enumerate(lines) if 'leaf = "workspaces"' in line]
    if len(indices) != 1:
        raise RuntimeError('Expected one workspace animation definition')
    definitions = [line for line in (ROOT / '.config/hypr/hyprland.lua').read_text().splitlines(keepends=True)
                   if any('leaf = "' + leaf + '"' in line for leaf in leaves)]
    updated = []
    for line in lines:
        if 'leaf = "workspaces"' in line:
            updated.extend(definitions)
        elif line.startswith('hl.curve("workspace_travel"') or any('leaf = "' + leaf + '"' in line for leaf in leaves[1:]):
            continue
        else:
            updated.append(line)
    lines = updated
    updates = {'desktop.lua': desktop, 'hyprland.lua': ''.join(lines)}
    backup = Path(tempfile.mkdtemp(prefix='workspace-backup.', dir=Path.home() / 'dots-dev'))
    for name in updates:
        shutil.copy2(directory / name, backup / name)
    print('Backup:', backup, flush=True)
    try:
        for name, text in updates.items():
            (directory / name).write_text(text)
        subprocess.run(['Hyprland', '--verify-config', '-c', str(directory / 'hyprland.lua')], env=verify, check=True)
        subprocess.run(['hyprctl', 'reload'], env=env, check=True)
        time.sleep(1)
        errors = subprocess.check_output(['hyprctl', 'configerrors'], env=env, text=True).strip()
        if errors:
            raise RuntimeError(errors)
    except Exception:
        for name in updates:
            shutil.copy2(backup / name, directory / name)
        subprocess.run(['hyprctl', 'reload'], env=env, check=False)
        raise
    print('Applied direct vertical workspace switching; installed checkout unchanged.')


if __name__ == '__main__':
    main()
