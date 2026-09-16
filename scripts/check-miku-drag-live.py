#!/usr/bin/env python3
"""Exercise real pointer grabs on Hyprland; briefly moves the pointer and opens a test window."""
import argparse
import json
import os
from pathlib import Path
import runpy
import shutil
import signal
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--data', type=Path, default=Path.home() / '.local/share/dots-miku')
parser.add_argument('--renderer', type=Path, help='Renderer to test (default: DATA/bin/shimeji-overlayd)')
args = parser.parse_args()
os.environ.setdefault('XDG_RUNTIME_DIR', f'/run/user/{os.getuid()}')
instance, = json.loads(subprocess.check_output(['hyprctl', 'instances', '-j']))
os.environ.update(HYPRLAND_INSTANCE_SIGNATURE=instance['instance'], WAYLAND_DISPLAY=instance['wl_socket'],
                  XDG_CURRENT_DESKTOP='Hyprland')

def hypr(*args):
    return subprocess.check_output(['hyprctl', *args], text=True)

monitors = json.loads(hypr('monitors', '-j'))
assert len(monitors) == 2 and all(m['scale'] == 1 and m['y'] == 0 for m in monitors), 'Test needs two horizontally arranged scale-1 displays'
left, right = sorted(monitors, key=lambda m: m['x'])
assert left['x'] == 0 and right['x'] == left['width'], 'Test needs adjacent displays'
width = right['x'] + right['width']
height = max(m['height'] for m in monitors)
original_pointer = json.loads(hypr('cursorpos', '-j'))
original_window = json.loads(hypr('activewindow', '-j')).get('address')
focused = next(m for m in monitors if m['focused'])
original_workspace = left['activeWorkspace']['id']
occupied = {w['id'] for w in json.loads(hypr('workspaces', '-j')) if w['windows']}
base = original_workspace - original_workspace % 10
test_workspace = next((base + n for n in range(9, 0, -1) if base + n not in occupied and base + n != original_workspace), None)
assert test_workspace, 'No empty workspace available on the left display'
def focus(workspace):
    result = hypr('dispatch', f'hl.dsp.focus({{workspace={workspace}}})').strip()
    assert result == 'ok', result

def deadline(*_):
    raise TimeoutError('Miku drag test exceeded 45 seconds')

signal.signal(signal.SIGALRM, deadline)
engine = runpy.run_path(shutil.which('shimejictl'), run_name='miku_drag_test')
# This pinned CLI reads the server's one-byte variable count as uint16.
read_values = engine['MascotInfo'].read_values
engine['MascotInfo'].read_values = lambda self, fmt: read_values(self, 'B' if fmt == 'H' else fmt)

with tempfile.TemporaryDirectory(prefix='miku-drag-') as scratch:
    scratch = Path(scratch)
    subprocess.run(['cc', str(ROOT / 'scripts/miku-test-pointer.c'), '-lwayland-client', '-o', str(scratch / 'pointer')], check=True)
    (scratch / 'shimeji-overlayd').symlink_to((args.renderer or args.data / 'bin/shimeji-overlayd').resolve())
    os.environ['PATH'] = str(scratch) + ':' + os.environ['PATH']
    config = scratch / 'overlay.conf'
    config.write_text((ROOT / '.config/hypr/miku/overlay.conf').read_text().replace('breeding=true', 'breeding=false'))
    address = str(scratch / 'overlay.sock')
    pointer = client = window = None
    log = open(scratch / 'renderer.log', 'w+')
    try:
        focus(test_workspace)
        time.sleep(.7)
        launcher = engine['Client'](address, {'start': True, 'cmdline': [
            '-s', address, '-cd', str(args.data), '-pr', str(args.data / 'prototypes'),
            '-c', str(config), '--no-plugins']})
        client = engine['Client'](address, {'start': False})
        launcher.socket.close()
        pointer = subprocess.Popen([str(scratch / 'pointer')], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
        signal.alarm(45)
        infos = []
        client.register_callback(engine['MascotInfo'], lambda c, p: infos.append(p))
        def info(mid):
            infos.clear()
            client.queue_packet(engine['MascotGetInfo'](mid))
            client.dispatch_events(until=lambda: bool(infos))
            return infos[0]
        def send(command, pause=.035):
            pointer.stdin.write(command + '\n')
            pointer.stdin.flush()
            assert pointer.stdout.readline().strip() == 'ok', 'Pointer tool failed'
            time.sleep(pause)
        def move(x, y):
            send(f'm {x} {y} {width} {height}')
        def remove(mid):
            client.queue_packet(engine['ApplyBehavior'](mid, 'RemoveMiku'))
            time.sleep(.05)
        envs = sorted(engine['environments'].values(), key=lambda env: env.x)
        def spawn():
            before = set(engine['mascots'])
            client.queue_packet(engine['Spawn'](next(iter(engine['prototypes'])), envs[0].id, 1000, 0, 'StandUp'))
            client.dispatch_events(until=lambda: bool(set(engine['mascots']) - before))
            mid = (set(engine['mascots']) - before).pop()
            time.sleep(.08)
            client.queue_packet(engine['ApplyBehavior'](mid, 'StandUp'))
            info(mid)
            time.sleep(.08)
            return mid
        for backdrop in ('empty workspace', 'application window'):
            if backdrop == 'application window':
                window = subprocess.Popen(['alacritty', '--class', 'dots-miku-drag-test', '-e', 'sleep', '40'], stdout=log, stderr=log)
                for _ in range(50):
                    clients = json.loads(hypr('clients', '-j'))
                    match = next((c for c in clients if c['pid'] == window.pid), None)
                    if match:
                        break
                    time.sleep(.05)
                assert match, 'Test window did not open'
                time.sleep(.25)
            mid = spawn()
            move(1000, left['height'] - 60)
            send('b 1')
            p = info(mid)
            assert p.current_behavior_name == b'Dragged', (backdrop, 'press', p.current_behavior_name)
            assert abs(p.variables[1].value) <= 3, 'Press teleported floor mascot'
            for rise in range(20, 601, 20):
                move(1000, left['height'] - 60 - rise)
                p = info(mid)
                assert p.current_behavior_name == b'Dragged', (backdrop, rise, 'lost grab')
                assert abs(p.variables[1].value - rise) <= 3, (backdrop, rise, p.variables[1].value)
            for x in (left['width']-40, left['width']+40, left['width']+400, left['width']-100):
                move(x, 700)
                p = info(mid)
                env = next(env for env in envs if env.id == p.environment_id)
                assert p.current_behavior_name == b'Dragged', (backdrop, x, 'lost grab between displays')
                assert abs(p.variables[0].value + env.x - x) <= 3, 'Wrong horizontal display coordinates'
                assert abs(p.variables[1].value - (env.height - (700 - (left['height']-envs[0].height)) - 60)) <= 3, 'Wrong vertical display coordinates'
            send('b 0')
            assert info(mid).current_behavior_name != b'Dragged', 'Release left mascot grabbed'
            remove(mid)
            print(f'PASS: fast upward drag, both display crossings and release over {backdrop}', flush=True)
        for edge, click_x, release_x in [('left', 1050, 0), ('right', 950, width-1)]:
            mid = spawn()
            move(click_x, left['height'] - 60)
            send('b 1')
            assert info(mid).current_behavior_name == b'Dragged', (edge, 'missed initial grab')
            move(1000, 700)
            move(release_x, 700)
            before = info(mid)
            expected_env = envs[0] if edge == 'left' else envs[-1]
            assert before.environment_id == expected_env.id
            assert (before.variables[0].value < 0 if edge == 'left' else before.variables[0].value > expected_env.width), (edge, before.variables[0].value, before.current_behavior_name)
            send('b 0', .15)
            after = info(mid)
            expected_x = 0 if edge == 'left' else expected_env.width
            assert after.environment_id == expected_env.id, (edge, 'changed display on outer-edge release')
            assert abs(after.variables[0].value - expected_x) <= 24, (edge, 'teleported horizontally', after.variables[0].value)
            assert abs(after.variables[1].value - before.variables[1].value) <= 80, (edge, 'teleported vertically', before.variables[1].value, after.variables[1].value)
            assert after.current_behavior_name != b'Dragged', 'Outer-edge release left mascot grabbed'
            remove(mid)
        print('PASS: throws beyond both outer display edges stay near the release point', flush=True)
        for _ in range(8):
            mid = spawn()
            move(1000, left['height'] - 60)
            send('b 1')
            send('b 0')
            p = info(mid)
            assert -3 <= p.variables[1].value <= 10, ('Click teleported mascot', p.variables[1].value)
            assert p.current_behavior_name != b'Dragged', 'Click left mascot grabbed'
            remove(mid)
        print('PASS: eight floor clicks without teleporting', flush=True)
    finally:
        signal.alarm(0)
        if pointer:
            try:
                send('b 0', 0)
                move(original_pointer['x'], original_pointer['y'])
            finally:
                pointer.stdin.close()
                pointer.wait(timeout=3)
        if client:
            client.queue_packet(engine['Stop']())
            client.socket.settimeout(3)
            while client.socket.recv(4096):
                pass
            client.socket.close()
        if window:
            window.terminate()
            window.wait(timeout=3)
        log.close()
        focus(original_workspace)
        focus(focused['activeWorkspace']['id'])
        if original_window:
            hypr('dispatch', 'hl.dsp.focus({window=' + json.dumps('address:' + original_window) + '})')
        hypr('dispatch', f'hl.dsp.cursor.move({{x={original_pointer["x"]},y={original_pointer["y"]}}})')
