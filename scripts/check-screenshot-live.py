#!/usr/bin/env python3
"""Check real selector cancellation and real capture/editor with a fixed test region."""
import json
import os
from pathlib import Path
import signal
import subprocess
import tempfile
import time


def query(name):
    return json.loads(subprocess.check_output(['hyprctl', name, '-j']))


def wait_for(check):
    for _ in range(100):
        value = check()
        if value:
            return value
        time.sleep(.05)
    raise AssertionError('Desktop operation timed out')


def child_pid(parent, command):
    result = subprocess.run(['pgrep', '-P', str(parent), '-x', command], capture_output=True, text=True)
    return int(result.stdout.strip()) if result.returncode == 0 else None


script = Path.home() / '.config/hypr/screenshot.sh'
focus = query('activewindow').get('address')
process = None
editor = None
try:
    process = subprocess.Popen(['bash', str(script)])
    selector = wait_for(lambda: child_pid(process.pid, 'slurp'))
    wait_for(lambda: any(layer['pid'] == selector for monitor in query('layers').values()
                         for level in monitor['levels'].values() for layer in level))
    subprocess.run(['hyprctl', 'dispatch', 'hl.dsp.send_shortcut({mods="",key="Escape"})'], check=True)
    assert process.wait(timeout=5) == 0
    print('PASS: real region selector cancellation', flush=True)
    with tempfile.TemporaryDirectory(prefix='dots-capture-live.') as folder:
        stub = Path(folder) / 'slurp'
        # Only selection is simulated; grim, pw-play and Swappy are real.
        monitor = query('monitors')[0]
        stub.write_text(f'#!/bin/sh\nprintf "%s\\n" "{monitor["x"]+30},{monitor["y"]+40} 120x80"\n')
        stub.chmod(0o755)
        env = dict(os.environ, PATH=f'{folder}:{os.environ["PATH"]}')
        process = subprocess.Popen(['bash', str(script)], env=env)
        editor = wait_for(lambda: child_pid(process.pid, 'swappy'))
        wait_for(lambda: any(window.get('pid') == editor and window.get('mapped')
                             for window in query('clients')))
        os.kill(editor, signal.SIGTERM)
        editor = None
        process.wait(timeout=5)
        print('PASS: real screenshot capture and mapped Swappy editor (fixed selection)', flush=True)
finally:
    if editor:
        os.kill(editor, signal.SIGTERM)
    if process and process.poll() is None:
        process.terminate()
        process.wait(timeout=5)
    if focus:
        subprocess.run(['hyprctl', 'dispatch', f'hl.dsp.focus({{window="address:{focus}"}})'], check=False)
