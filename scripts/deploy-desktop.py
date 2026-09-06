#!/usr/bin/env python3
"""Run on the laptop: validate, back up and apply selected desktop files.

Usage: python3 scripts/deploy-desktop.py SNAPSHOT
       python3 scripts/deploy-desktop.py --restore BACKUP
Never runs the installer, replaces Waybar, or changes ~/dots.
"""
import argparse
from datetime import datetime
import json
import os
from pathlib import Path
import shutil
import subprocess
import time

FILES = [
    ".config/hypr/desktop-core.lua", ".config/hypr/desktop.lua",
    ".config/hypr/autostart.sh", ".config/waybar/config.jsonc",
    ".config/waybar/style.css", ".config/waybar/focus-window.sh",
    ".config/rofi/config.rasi", ".config/rofi/windows.py",
    ".config/hypr/hyprland.lua",  # Install last: Hyprland watches this file.
]


def session_env():
    env = os.environ.copy()
    env["XDG_RUNTIME_DIR"] = f"/run/user/{os.getuid()}"
    instances = json.loads(subprocess.check_output(["hyprctl", "instances", "-j"], env=env))
    if len(instances) != 1:
        raise SystemExit("Expected exactly one running Hyprland instance")
    env["HYPRLAND_INSTANCE_SIGNATURE"] = instances[0]["instance"]
    env["WAYLAND_DISPLAY"] = instances[0]["wl_socket"]
    return env


def reload_desktop(env, restoring=False):
    subprocess.run(["hyprctl", "reload"], env=env, check=True)
    time.sleep(1)
    errors = subprocess.check_output(["hyprctl", "configerrors"], env=env, text=True).strip()
    if errors:
        raise RuntimeError(errors)
    subprocess.run(["pkill", "-x", "waybar"], env=env, check=False)
    time.sleep(0.3)
    subprocess.Popen(["systemd-cat", "--identifier=dots-waybar", "/usr/bin/waybar"],
                     env=env, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                     stderr=subprocess.DEVNULL, start_new_session=True)
    time.sleep(1)
    subprocess.run(["pgrep", "-x", "waybar"], check=True, stdout=subprocess.DEVNULL)
    if not restoring:
        subprocess.run(["hyprctl", "dispatch", "function() dots.bar_restarted() end"], env=env, check=True)


def restore(backup, home, env):
    manifest = json.loads((backup / "manifest.json").read_text())
    for name in FILES:
        if name not in manifest:
            continue
        destination = home / name
        if manifest.get(name):
            shutil.copy2(backup / name, destination)
        elif destination.exists():
            destination.unlink()
    reload_desktop(env, restoring=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("--restore", action="store_true")
    args = parser.parse_args()
    home, env = Path.home(), session_env()
    source = args.source.resolve()
    if args.restore:
        restore(source, home, env)
        print(f"Restored configs from {source}; window placement is not rolled back")
        return

    verify_env = env.copy()
    verify_env.pop("HYPRLAND_INSTANCE_SIGNATURE", None)
    subprocess.run(["lua", "scripts/check-desktop.lua"], cwd=source, env=verify_env, check=True)
    subprocess.run(["Hyprland", "--verify-config", "-c", str(source / FILES[-1])], env=verify_env, check=True)
    for name in FILES:
        if not (source / name).is_file():
            raise SystemExit(f"Missing source file: {name}")
    backup = home / "dots-dev" / "backups" / datetime.now().strftime("desktop-%Y%m%d-%H%M%S")
    backup.mkdir(parents=True, mode=0o700)
    manifest = {}
    for name in FILES:
        active = home / name
        manifest[name] = active.exists()
        if active.exists():
            target = backup / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(active, target)
    (backup / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"Backup: {backup}", flush=True)
    try:
        for name in FILES:
            target = home / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source / name, target)
        reload_desktop(env)
    except Exception:
        restore(backup, home, env)
        raise
    print(f"Applied {source}; installed Waybar and ~/dots unchanged")


if __name__ == "__main__":
    main()
