#!/usr/bin/env python3
"""Run from a laptop snapshot to back up and apply only display configuration."""
from datetime import datetime
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('deploy_desktop', ROOT / 'scripts/deploy-desktop.py')
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)

def main():
    env = helper.session_env()
    verify = env.copy()
    verify.pop('HYPRLAND_INSTANCE_SIGNATURE', None)
    subprocess.run(['lua', 'scripts/check-desktop.lua'], cwd=ROOT, env=verify, check=True)
    subprocess.run(['python3', '-B', 'scripts/check-monitors.py'], cwd=ROOT, check=True)
    home = Path.home()
    relative = '.config/hypr/'
    active = home / relative / 'hyprland.lua'
    text = active.read_text()
    text = text.replace('python3 ~/.config/hypr/monitors.py', 'bash ~/.config/hypr/monitors.sh')
    source = (ROOT / relative / 'hyprland.lua').read_text()
    start = source.index('local function configure_displays(')
    end = source.index('\nhl.on("hyprland.start", function()\n    hl.exec_cmd', start)
    if 'local function configure_displays(' not in text:
        text = text.replace('dots.setup()\n', 'dots.setup()\n\n' + source[start:end], 1)
    binding = next(line for line in source.splitlines() if '"Choose display layout"' in line)
    if '"Choose display layout"' not in text:
        anchor = '-- Monitor focus and client movement.'
        text = text.replace(anchor, binding + '\n\n' + anchor, 1)
    else:
        text = '\n'.join(binding if '"Choose display layout"' in line else line
                         for line in text.split('\n'))
    if 'local function configure_displays(' not in text or binding not in text:
        raise RuntimeError('Cannot locate display configuration anchors')
    names = ['.config/rofi/modi/monitors.sh'] + [relative + name for name in
             ['monitors.sh', 'monitors.json', 'desktop.lua', 'hyprland.lua']]
    retired = ['.config/hypr/monitors.py']
    backup = home / 'dots-dev/backups' / datetime.now().strftime('monitors-%Y%m%d-%H%M%S')
    backup.mkdir(parents=True, mode=0o700)
    present = {}
    for name in names + retired:
        path = home / name
        present[name] = path.exists()
        if path.exists():
            (backup / name).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, backup / name)
    (backup / 'manifest.json').write_text(json.dumps(present))
    print('Backup:', backup, flush=True)
    try:
        for name in names[:-1]:
            (home / name).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / name, home / name)
        staged = active.with_suffix('.staged.lua')
        staged.write_text(text)
        subprocess.run(['Hyprland', '--verify-config', '-c', str(staged)], env=verify, check=True)
        staged.replace(active)
        for name in retired:
            (home / name).unlink(missing_ok=True)
        subprocess.run(['hyprctl', 'reload'], env=env, check=True)
        time.sleep(2)
        errors = subprocess.check_output(['hyprctl', 'configerrors'], env=env, text=True).strip()
        if errors:
            raise RuntimeError(errors)
        subprocess.run(['bash', str(home / relative / 'monitors.sh'), '--auto', '--reload'], env=env, check=True)
    except Exception:
        for name in names + retired:
            target = home / name
            if present[name]:
                shutil.copy2(backup / name, target)
            elif target.exists():
                target.unlink()
        subprocess.run(['hyprctl', 'reload'], env=env, check=False)
        raise
    print('Applied display configuration; ~/dots unchanged.')

if __name__ == '__main__':
    main()
