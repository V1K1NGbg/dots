#!/usr/bin/env python3
"""Check direct workspace switching, then restore the original desktop focus."""
import json
import os
from pathlib import Path
import socket
import subprocess
import time


def main():
    env = os.environ.copy()
    runtime = f'/run/user/{os.getuid()}'
    instance, = json.loads(subprocess.check_output(['hyprctl', 'instances', '-j']))
    env.update(XDG_RUNTIME_DIR=runtime, HYPRLAND_INSTANCE_SIGNATURE=instance['instance'])

    def query(name):
        return json.loads(subprocess.check_output(['hyprctl', '-j', name], env=env))

    def action(code):
        result = subprocess.check_output(['hyprctl', 'dispatch', 'function() ' + code + ' end'], env=env, text=True).strip()
        assert result == 'ok', result

    original = query('activeworkspace')['id']
    window = query('activewindow').get('address')
    monitors = query('monitors')
    stream = socket.socket(socket.AF_UNIX)
    stream.connect(str(Path(runtime) / 'hypr' / instance['instance'] / '.socket2.sock'))
    stream.settimeout(.05)

    def collect(duration):
        data = b''
        deadline = time.monotonic() + duration
        while time.monotonic() < deadline:
            try:
                data += stream.recv(65536)
            except socket.timeout:
                pass
        return [int(line.split('>>', 1)[1].split(',')[0]) for line in data.decode().splitlines() if line.startswith('workspacev2>>')]

    try:
        for monitor in monitors:
            start = monitor['activeWorkspace']['id']
            base = start - start % 10
            action(f'hl.dispatch(hl.dsp.focus({{workspace={base + 1}}}))')
            collect(.3)
            for code, expected in [
                ('dots.view(6)', [base + 6]),
                ('dots.view(1)', [base + 1]),
                ('dots.view(6); dots.view(1)', [base + 6, base + 1]),
                ('dots.browse(-1)', [base + 9]),
                ('dots.browse(1)', [base + 1]),
            ]:
                action(code)
                observed = collect(1.15)
                assert observed == expected, (monitor['name'], code, observed, expected)
                print(monitor['name'], code, observed, 'passed', flush=True)
        assert not subprocess.check_output(['hyprctl', 'configerrors'], env=env, text=True).strip()
    finally:
        for monitor in monitors:
            action(f'hl.dispatch(hl.dsp.focus({{workspace={monitor["activeWorkspace"]["id"]}}}))')
        action(f'hl.dispatch(hl.dsp.focus({{workspace={original}}}))')
        if window:
            action('hl.dispatch(hl.dsp.focus({window=' + json.dumps('address:' + window) + '}))')
        stream.close()


if __name__ == '__main__':
    main()
