#!/usr/bin/env python3
"""Back up and apply only the Spotify/desktop-bar startup fixes on the laptop."""
from pathlib import Path
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parent.parent
home = Path.home()
changes = {}


def replace(text, old, new):
    if old in text:
        return text.replace(old, new)
    if new in text:
        return text
    raise SystemExit(f'Active configuration differs; cannot find: {old}')


path = Path('.config/hypr/autostart.sh')
text = (home / path).read_text()
old = '''if ! pgrep -u "$UID" -x waybar >/dev/null; then
    systemd-cat --identifier=dots-waybar waybar 9>&- &
    (
        sleep 1
        hyprctl dispatch 'function() dots.bar_restarted() end'
    ) 9>&- &
fi'''
text = replace(text, old, 'bash "$HOME/.config/hypr/waybar.sh" ensure 9>&- &')
text = replace(text, '    spawnsl spotify-launcher\n', '    spawnsl spotify-launcher --skip-update\n')
text = replace(text, '    WAYLAND_DISPLAY XDG_CURRENT_DESKTOP',
               '    WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP')
changes[path] = text
path = Path('.config/hypr/desktop.lua')
text = (home / path).read_text()
text = replace(text, 'hl.exec_cmd("pkill -RTMIN+9 -x waybar")',
               'hl.exec_cmd("bash ~/.config/hypr/waybar.sh refresh")')
text = replace(text, 'hl.exec_cmd("pkill -SIGUSR1 -x waybar")',
               'hl.exec_cmd("bash ~/.config/hypr/waybar.sh " .. (visible and "show" or "hide"))')
changes[path] = text
for path in (Path('.config/hypr/waybar.sh'),):
    changes[path] = (root / path).read_text()
backup = Path(tempfile.mkdtemp(prefix='startup-fixes-backup.', dir=home / 'dots-dev'))
for path, text in changes.items():
    target = home / path
    if target.exists():
        (backup / path).parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(target, backup / path)
    else:
        with (backup / 'new-files.txt').open('a') as file:
            file.write(str(path) + '\n')
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(text)
retired = home / '.config/systemd/user/dots-waybar.service'
if retired.exists():
    shutil.copy2(retired, backup / 'dots-waybar.service')
    subprocess.run(['systemctl', '--user', 'stop', 'dots-waybar.service'], check=True)
    retired.unlink()
print(f'Backup: {backup}', flush=True)
subprocess.run(['systemctl', '--user', 'daemon-reload'], check=True)
# Run from the graphical environment (or import its instance variables first).
subprocess.run(['systemctl', '--user', 'import-environment', 'WAYLAND_DISPLAY',
                'HYPRLAND_INSTANCE_SIGNATURE'], check=True)
subprocess.run(['hyprctl', 'reload'], check=True)
subprocess.run(['bash', str(home / '.config/hypr/waybar.sh'), 'ensure'], check=True)
