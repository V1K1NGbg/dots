#!/usr/bin/env python3
"""Selectively deploy sounds, timer playback and watermark from a laptop snapshot."""
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parent.parent
home = Path.home()
changes = {}
copies = ['.config/hypr/battery.sh', '.config/hypr/screenshot.sh',
          '.config/hypr/sound.sh', '.config/systemd/user/dots-battery.service',
          '.config/systemd/user/dots-battery.timer']
copies += [str(p.relative_to(root)) for p in (root / '.config/hypr/sounds').iterdir() if p.is_file()]


def replace(text, old, new):
    if old in text:
        return text.replace(old, new)
    if new in text:
        return text
    raise SystemExit(f'Unexpected active configuration: {old}')


path = '.config/hypr/hyprland.lua'
text = (home / path).read_text()
lines = text.splitlines(keepends=True)
count = 0
for i, line in enumerate(lines):
    if '"Take a screenshot"' in line:
        start = line.index('hl.dsp.exec_cmd(')
        end = line.index(', "Take a screenshot"')
        lines[i] = line[:start] + 'hl.dsp.exec_cmd("bash ~/.config/hypr/screenshot.sh")' + line[end:]
        count += 1
assert count == 2, 'Expected exactly two screenshot bindings'
changes[path] = ''.join(lines)
path = '.config/hypr/autostart.sh'
text = (home / path).read_text()
if '    dots-battery.timer \\\n' not in text:
    text = replace(text, '    hypridle.service \\\n', '    dots-battery.timer \\\n    hypridle.service \\\n')
changes[path] = text
path = '.config/rofi/modi/time.sh'
text = (home / path).read_text()
text = replace(text, "sound=$(cfg '.sound // empty'); sound=${sound:-$ROOT/sounds/villager-idle1.ogg}",
               "sound=$(cfg '.sound // empty')")
text = replace(text, 'while :; do pw-play "$sound" & wait $! || exit;',
               'while :; do bash "$ROOT/../hypr/sound.sh" timer "$sound" & wait $! || exit;')
changes[path] = text


def config(path):
    return json.loads('\n'.join(line for line in path.read_text().splitlines()
                                if not line.lstrip().startswith('//')))


path = '.config/waybar/config.jsonc'
bars = config(home / path)
if isinstance(bars, dict):
    bars = [bars]
top = next(bar for bar in bars if bar.get('layer') == 'top')
top['battery']['states'].update(warning=20, critical=10)
watermark = next(bar for bar in config(root / path) if bar.get('name') == 'activate-linux')
bars = [bar for bar in bars if bar.get('name') != 'activate-linux'] + [watermark]
changes[path] = json.dumps(bars, indent=2) + '\n'
path = '.config/waybar/style.css'
marker = '/* Desktop watermark:'
text = (home / path).read_text().split(marker)[0].rstrip()
addition = marker + (root / path).read_text().split(marker, 1)[1]
changes[path] = text + '\n\n' + addition

backup = Path(tempfile.mkdtemp(prefix='desktop-effects-backup.', dir=home / 'dots-dev'))
for path in [*changes, *copies]:
    target = home / path
    if target.exists():
        (backup / path).parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(target, backup / path)
    else:
        with (backup / 'new-files.txt').open('a') as file:
            file.write(path + '\n')
    target.parent.mkdir(parents=True, exist_ok=True)
    if path in changes:
        target.write_text(changes[path])
    else:
        shutil.copy2(root / path, target)
print(f'Backup: {backup}', flush=True)
subprocess.run(['systemctl', '--user', 'daemon-reload'], check=True)
subprocess.run(['hyprctl', 'reload'], check=True)
subprocess.run(['bash', str(home / '.config/hypr/waybar.sh'), 'restart'], check=True)
subprocess.run(['systemctl', '--user', 'start', 'dots-battery.timer'], check=True)
