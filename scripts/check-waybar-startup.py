#!/usr/bin/env python3
"""Start a disposable hidden Waybar and check taskbar membership before any reload."""
from collections import Counter
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import time

root = Path(__file__).resolve().parents[1]
env = os.environ.copy()
env['XDG_RUNTIME_DIR'] = f'/run/user/{os.getuid()}'
instance, = json.loads(subprocess.check_output(['hyprctl', 'instances', '-j'], env=env))
env.update(HYPRLAND_INSTANCE_SIGNATURE=instance['instance'], WAYLAND_DISPLAY=instance['wl_socket'])
workspaces = json.loads(subprocess.check_output(['hyprctl', '-j', 'workspaces'], env=env))
expected = {w['name'] for w in workspaces if w['id'] > 0 and w['id'] % 10 in range(1, 10)}
assert expected, 'Need at least one logical workspace'
config = json.loads('\n'.join((root / '.config/waybar/config.jsonc').read_text().splitlines()[1:]))
config.update(start_hidden=True, **{'modules-center': [], 'modules-right': []})
with tempfile.TemporaryDirectory(prefix='dots-waybar-check.') as folder:
    folder = Path(folder)
    path = folder / 'config.json'; path.write_text(json.dumps(config))
    with (folder / 'waybar.log').open('w+') as log:
        process = subprocess.Popen(['waybar', '-l', 'debug', '-c', str(path), '-s', str(root / '.config/waybar/style.css')], env=env, stdout=log, stderr=log)
        try:
            time.sleep(4)
            assert process.poll() is None, 'Test Waybar exited'
            log.seek(0); text = log.read()
            counts = Counter(re.findall(r'\[debug\] Creating workspace (\S+)', text))
            assert set(counts) == expected, (counts, expected)
            assert all(count == 1 for count in counts.values()), counts
            print('PASS: fresh Waybar creates each logical workspace in exactly one taskbar group:', dict(counts))
        finally:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill(); process.wait()
