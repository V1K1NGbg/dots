#!/usr/bin/env python3
"""Test Bash-controlled arrangements and the picker, then restore the MSI right profile."""
import fcntl
import json
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
CONTROLLER = ROOT / '.config/hypr/monitors.sh'


def command(function, *args):
    return ['bash', '-e', '-o', 'pipefail', '-c', 'source "$1"; shift; "$@"',
            'monitor-live', str(CONTROLLER), function, *args]


def call(function, *args):
    return subprocess.check_output(command(function, *args), text=True).strip()


def main():
    os.environ['XDG_RUNTIME_DIR'] = f'/run/user/{os.getuid()}'
    instance, = json.loads(subprocess.check_output(['hyprctl', 'instances', '-j']))
    os.environ.update(HYPRLAND_INSTANCE_SIGNATURE=instance['instance'], WAYLAND_DISPLAY=instance['wl_socket'])
    monitors = {x['name']: x for x in json.loads(call('monitor_query'))}
    internal, external = json.dumps(monitors['eDP-1']), json.dumps(monitors['DP-4'])
    def layers():
        data = json.loads(subprocess.check_output(['hyprctl', 'layers', '-j']))
        return [layer for mon in data.values() for level in mon['levels'].values()
                for layer in level if layer['namespace'] == 'rofi']
    assert not layers(), 'Close the existing Rofi menu before testing'
    runtime = Path(os.environ['XDG_RUNTIME_DIR']) / ('dots-monitors-' + instance['instance'])
    if '--picker-only' not in sys.argv:
        with Path(str(runtime) + '.lock').open('w') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            try:
                for layout in ('right', 'left', 'top', 'bottom', 'duplicate'):
                    call('monitor_apply', internal, external, layout, 'false')
                    live = {x['name']: x for x in json.loads(call('monitor_query'))}
                    if layout == 'duplicate':
                        assert live['eDP-1']['mirrorOf'] in ('DP-4', str(live['DP-4']['id'])), live
                    else:
                        expected = json.loads(call('monitor_positions', layout, internal, external))
                        assert [live['eDP-1']['x'], live['eDP-1']['y'], live['DP-4']['x'], live['DP-4']['y']] == expected
                        assert live['eDP-1']['mirrorOf'] == 'none'
                    print(layout, 'passed', flush=True)
            finally:
                call('monitor_apply', internal, external, 'right', 'false')
    # Run the actual picker, without persisting a different profile.
    picker = subprocess.Popen(command('monitor_choose', 'External display position',
        'Right', 'Left', 'Top', 'Bottom', 'Duplicate'), stdout=subprocess.PIPE, text=True)
    try:
        deadline = time.monotonic() + 5
        while not layers() and time.monotonic() < deadline:
            time.sleep(.1)
        assert layers(), 'Picker did not appear'
        time.sleep(.3)
        layer = layers()[0]
        subprocess.run(['grim', '-g', f'{layer["x"]},{layer["y"]} {layer["w"]}x{layer["h"]}', '/tmp/dots-monitor-picker.png'], check=True)
        for key in ['Down', 'Return']:
            subprocess.run(['hyprctl', 'dispatch', 'hl.dsp.send_shortcut({mods="",key="' + key + '"})'], check=True)
            time.sleep(.1)
        output, _ = picker.communicate(timeout=5)
        assert picker.returncode == 0 and output.strip() == '1', output
    finally:
        if picker.poll() is None:
            subprocess.run(['hyprctl', 'dispatch', 'hl.dsp.send_shortcut({mods="",key="Escape"})'], check=False)
            try:
                picker.wait(timeout=3)
            except subprocess.TimeoutExpired:
                picker.terminate(); picker.wait(timeout=3)
    print('Rofi selection passed; screenshot /tmp/dots-monitor-picker.png', flush=True)


if __name__ == '__main__':
    main()
