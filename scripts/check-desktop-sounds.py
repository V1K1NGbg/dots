#!/usr/bin/env python3
"""Offline checks with fake battery, capture, notification and playback commands."""
import os
from pathlib import Path
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parent.parent


def main():
    with tempfile.TemporaryDirectory() as temp:
        scratch = Path(temp)
        bins = scratch / 'bin'
        bins.mkdir()
        log = scratch / 'events'
        log.touch()
        commands = {
            'pw-play': 'echo "sound $*" >> "$EVENT_LOG"\nexit "${PLAY_FAIL:-0}"',
            'notify-send': 'echo "notify $*" >> "$EVENT_LOG"',
            'slurp': '[[ ${CANCEL:-0} == 0 ]] || exit 1\necho "0,0 10x10"',
            'grim': '[[ ${CAPTURE_FAIL:-0} == 0 ]] || exit 1\nprintf image > "$3"',
            'swappy': '[[ -s $2 ]] || exit 1\necho editor >> "$EVENT_LOG"',
        }
        for name, body in commands.items():
            path = bins / name
            path.write_text('#!/bin/bash\n' + body + '\n')
            path.chmod(0o755)
        supply = scratch / 'supply'
        battery = supply / 'BAT0'
        battery.mkdir(parents=True)
        (battery / 'type').write_text('Battery\n')
        env = dict(os.environ, PATH=f'{bins}:{os.environ["PATH"]}',
                   XDG_RUNTIME_DIR=temp, EVENT_LOG=str(log),
                   DOTS_POWER_SUPPLY_ROOT=str(supply))

        def run(script, *args, **overrides):
            return subprocess.run(['bash', str(ROOT / '.config/hypr' / script), *args],
                                  env=dict(env, **overrides), capture_output=True)

        def tick(capacity, status='Discharging'):
            (battery / 'capacity').write_text(f'{capacity}\n')
            (battery / 'status').write_text(status + '\n')
            result = run('battery.sh')
            assert result.returncode == 0, result.stderr

        for capacity in (50, 20, 20, 21, 20, 10, 10, 11, 10):
            tick(capacity)
        sounds = [line for line in log.read_text().splitlines() if line.startswith('sound')]
        assert len(sounds) == 2, sounds
        assert 'villager-deny1.ogg' in sounds[0]
        assert 'villager-hurt1.ogg' in sounds[1]
        tick(9, 'Charging')
        assert log.read_text().count('sound ') == 2
        tick(50, 'Charging')
        tick(8)  # Starting below critical emits only the critical alert.
        assert log.read_text().count('sound ') == 3
        assert log.read_text().splitlines()[-1].endswith('villager-hurt1.ogg')
        (battery / 'scope').write_text('Device\n')
        tick(50)
        tick(5)
        assert log.read_text().count('sound ') == 3

        for options in ({'CANCEL': '1'}, {'CAPTURE_FAIL': '1'}):
            log.write_text('')
            run('screenshot.sh', **options)
            assert log.read_text() == ''
            assert not list(scratch.glob('dots-screenshot.*'))
        for fail in ('0', '1'):
            log.write_text('')
            result = run('screenshot.sh', PLAY_FAIL=fail)
            assert result.returncode == 0, result.stderr
            for _ in range(100):
                if 'sound ' in log.read_text():
                    break
                time.sleep(.01)
            events = log.read_text()
            assert 'editor' in events and 'villager-accept1.ogg' in events, events
            assert not list(scratch.glob('dots-screenshot.*'))
        log.write_text('')
        assert run('sound.sh', 'timer').returncode == 0
        assert '--volume 1.0' in log.read_text()
        assert log.read_text().strip().endswith(str(ROOT / '.config/hypr/sounds/villager-idle1.ogg'))
        log.write_text('')
        assert run('sound.sh', 'timer', '/custom sound.ogg').returncode == 0
        assert log.read_text().strip().endswith('/custom sound.ogg')
        for asset in (ROOT / '.config/hypr/sounds').glob('*.ogg'):
            assert asset.read_bytes().startswith(b'OggS'), asset
    print('PASS: battery thresholds, repeat suppression, charging, peripheral exclusion; '
          'capture success/cancellation/failure, playback failure, temporary-file cleanup; '
          'shared timer helper default and custom override')


if __name__ == '__main__':
    main()
