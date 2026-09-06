#!/usr/bin/env python3
"""Rofi script mode for native and XWayland windows, including minimized ones."""
import json
import os
import re
import subprocess

address = os.environ.get("ROFI_INFO", "")
if os.environ.get("ROFI_RETV") == "1" and re.fullmatch(r"0x[0-9a-fA-F]+", address):
    subprocess.run(["hyprctl", "dispatch", f"function() dots.focus_window('{address}') end"],
                   check=True, stdout=subprocess.DEVNULL)
else:
    print("\0prompt\x1fWindows")
    clients = json.loads(subprocess.check_output(["hyprctl", "clients", "-j"]))
    for client in sorted(clients, key=lambda c: (c["workspace"]["id"], c["class"], c["title"])):
        workspace = client["workspace"]["id"]
        label = "minimized" if workspace < 0 else str((workspace - 1) % 10 + 1)
        title = f"{label} · {client['class']} · {client['title']}"
        title = re.sub(r"[\x00-\x1f\x7f]", " ", title)
        print(f"{title}\0info\x1f{client['address']}")
