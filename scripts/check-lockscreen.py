#!/usr/bin/env python3
"""Preview Hyprlock in a disposable nested compositor, leaving the real session unlocked.

Launch through the running compositor to inherit its local fingerprint permissions:
hyprctl dispatch 'hl.dsp.exec_cmd("python3 SNAPSHOT/scripts/check-lockscreen.py")'
"""
import argparse
import json
import os
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--errors', action='store_true', help='Preview an inline authentication error without a failed authentication attempt')
    args = parser.parse_args()
    env = os.environ.copy()
    out = Path(env['XDG_RUNTIME_DIR']) / 'dots-lockscreen-check'
    out.mkdir(exist_ok=True, mode=0o700)
    suffix = '-errors' if args.errors else ''
    (out / ('result' + suffix)).unlink(missing_ok=True)
    lock_config = ROOT / '.config/hypr/hyprlock.conf'
    if args.errors:
        text = lock_config.read_text()
        # Use the same markup as the real failure placeholder, without submitting
        # credentials or increasing the system's failed-authentication counter.
        failure = next(line.split('=', 1)[1].strip() for line in text.splitlines() if line.strip().startswith('fail_text ='))
        failure = failure.replace('$FAIL', 'Fingerprint did not match')
        text = text.replace('placeholder_text = Password  ↵', 'placeholder_text = ' + failure)
        text = text.replace('outer_color = rgba(67ffeb88)', 'outer_color = rgb(ff6685)')
        lock_config = out / 'errors.conf'
        lock_config.write_text(text)
    config = out / 'nested.lua'
    config.write_text('''hl.monitor({output="",mode="1280x800",position="auto",scale=1})
hl.config({misc={disable_hyprland_logo=true,disable_splash_rendering=true},
           ecosystem={no_update_news=true,no_donation_nag=true}})
''')
    def query(name, query_env=env):
        return json.loads(subprocess.check_output(['hyprctl', '-j', name], env=query_env))
    original = query('activewindow').get('address')
    nested_env = env.copy()
    nested_env.pop('HYPRLAND_INSTANCE_SIGNATURE', None)
    nested_env.pop('NOTIFY_SOCKET', None)
    nested = locker = None
    try:
        with (out / 'nested.log').open('w') as log:
            nested = subprocess.Popen(['Hyprland', '-c', str(config)], env=nested_env, stdout=log, stderr=log)
        deadline = time.monotonic() + 15
        instance = None
        while time.monotonic() < deadline:
            instance = next((i for i in query('instances') if i['pid'] == nested.pid), None)
            if instance and (Path(env['XDG_RUNTIME_DIR']) / instance['wl_socket']).exists():
                break
            if nested.poll() is not None:
                raise RuntimeError('Nested compositor failed; see nested.log')
            time.sleep(.2)
        if not instance:
            raise RuntimeError('No nested compositor instance')
        nested_env.update(WAYLAND_DISPLAY=instance['wl_socket'], HYPRLAND_INSTANCE_SIGNATURE=instance['instance'])
        time.sleep(1)
        with (out / 'hyprlock.log').open('w') as log:
            locker = subprocess.Popen(['hyprlock', '-v', '-c', str(lock_config)],
                                      env=nested_env, stdout=log, stderr=log)
        time.sleep(4)
        if locker.poll() is not None:
            raise RuntimeError('Preview lock failed; see hyprlock.log')
        window = next((w for w in query('clients') if w['pid'] == nested.pid), None)
        if not window:
            raise RuntimeError('Nested preview window missing')
        subprocess.run(['hyprctl', 'dispatch', 'hl.dsp.focus({window=' + json.dumps('address:' + window['address']) + '})'], env=env, check=True)
        time.sleep(.5)
        window = next(w for w in query('clients') if w['pid'] == nested.pid)
        x, y = window['at']; w, h = window['size']
        subprocess.run(['grim', '-g', f'{x},{y} {w}x{h}', str(out / ('preview' + suffix + '.png'))], env=env, check=True)
        log = (out / 'hyprlock.log').read_text()
        assert 'Config error' not in log and 'Config threw' not in log, log
        assert 'fprint: started verifying' in log, 'Fingerprint did not become ready; see hyprlock.log'
        (out / ('result' + suffix)).write_text('PASS: rendered lock screen; fingerprint verification started without typing.\n')
    except Exception as error:
        (out / ('result' + suffix)).write_text('FAIL: ' + str(error) + '\n')
        raise
    finally:
        # Only the disposable compositor and its own locker are terminated.
        for process in (locker, nested):
            if process and process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=4)
                except subprocess.TimeoutExpired:
                    process.kill(); process.wait()
        if original:
            subprocess.run(['hyprctl', 'dispatch', 'hl.dsp.focus({window=' + json.dumps('address:' + original) + '})'], env=env)

if __name__ == '__main__':
    main()
