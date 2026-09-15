#!/usr/bin/env python3
"""Local toggle and bundled sprite checks; real conversion with --engine."""
import argparse
import contextlib
import io
import json
import os
from pathlib import Path
import runpy
import shutil
import subprocess
import tempfile
import xml.etree.ElementTree as ET
from unittest import mock
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--engine", type=Path, help="Packaged shimejictl (loaded without launching it)")
args = parser.parse_args()
setup = runpy.run_path(str(ROOT / "scripts/setup-miku.py"))
input_handler = runpy.run_path(str(ROOT / ".config/hypr/miku-input.py"))
sent = []
client = SimpleNamespace(queue_packet=sent.append)
environment = SimpleNamespace(mascots={})
mascots = {i: SimpleNamespace(environment=environment) for i in range(1, 3)}
environment.mascots.update(mascots)
engine = {"mascots": mascots, "objects": dict(mascots),
          "ApplyBehavior": lambda ident, action: (ident, action), "Stop": lambda: "stop"}
input_handler["clicked"](engine, client, SimpleNamespace(object_id=2))
assert sent == [(2, "SplitIntoTwo")]
input_handler["clicked"](engine, client, SimpleNamespace(object_id=99))
assert len(sent) == 1, "Unknown click target was accepted"
for i in range(3, 6):
    mascots[i] = SimpleNamespace(environment=environment)
input_handler["clicked"](engine, client, SimpleNamespace(object_id=1))
assert len(sent) == 1, "Clone requested at the group limit"
input_handler["disposed"](engine, client, SimpleNamespace(object_id=2))
assert 2 not in mascots and 2 not in engine["objects"] and 2 not in environment.mascots
for ident in list(mascots):
    try:
        input_handler["disposed"](engine, client, SimpleNamespace(object_id=ident))
    except SystemExit as result:
        assert result.code == 0 and not mascots
assert sent[-1] == "stop", "Removing the last Miku did not stop the renderer"
print("PASS: clicked-mascot clone, group limit, individual removal and last-Miku shutdown")
with tempfile.TemporaryDirectory() as scratch:
    scratch = Path(scratch)
    callbacks = {}
    launched = {}
    connections = []
    class InputClient:
        def __init__(self, address, options):
            connections.append(options)
            if options["start"]:
                launched.update(address=address, options=options)
            self.socket = mock.Mock()
        def register_callback(self, event, callback):
            callbacks[event] = callback
        def dispatch_events(self):
            launched["listening"] = True
    fake_engine = dict(engine, Client=InputClient, MascotClicked="clicked", MascotDisposed="disposed")
    with mock.patch.dict(os.environ, {"XDG_RUNTIME_DIR": str(scratch), "XDG_DATA_HOME": str(scratch / "data")}), \
         mock.patch.object(input_handler["shutil"], "which", return_value="/usr/bin/shimejictl"), \
         mock.patch.object(input_handler["runpy"], "run_path", return_value=fake_engine):
        input_handler["main"]()
    assert set(callbacks) == {"clicked", "disposed"} and launched["listening"]
    assert launched["address"] == str(scratch / "dots-miku.sock")
    assert launched["options"]["start"] is True
    assert len(connections) == 2 and connections[1] == {"start": False}
    assert "--no-plugins" in launched["options"]["cmdline"] and "-se" in launched["options"]["cmdline"]
    bin_dir = scratch / "bin"
    bin_dir.mkdir()
    def stub(name, body):
        path = bin_dir / name
        path.write_text("#!/bin/bash\nset -eu\n" + body)
        path.chmod(0o755)
    stub("flock", ":\n")  # Host may be macOS; Linux owns the real lock check.
    stub("notify-send", 'printf "%s\\n" "$*" >> "$XDG_RUNTIME_DIR/notices"\n')
    stub("systemctl", '''case "$*" in
      *is-active*) test -f "$XDG_RUNTIME_DIR/active";;
      *start*) test ! -f "$XDG_RUNTIME_DIR/fail-start"; touch "$XDG_RUNTIME_DIR/active";;
      *stop*) rm "$XDG_RUNTIME_DIR/active";;
      *) exit 1;;
    esac
''')
    stub("shimeji-overlayd", 'printf "%s\\n" "$@" > "$XDG_RUNTIME_DIR/engine-args"\n')
    stub("python3", 'printf "%s\\n" "$@" > "$XDG_RUNTIME_DIR/input-args"\n')
    for name in ("bash", "dirname", "touch", "rm"):
        (bin_dir / name).symlink_to(shutil.which(name))
    env = dict(os.environ, XDG_RUNTIME_DIR=str(scratch), XDG_DATA_HOME=str(scratch / "data"),
               PATH=str(bin_dir))
    def toggle(*arguments):
        return subprocess.run(["bash", str(ROOT / ".config/hypr/miku.sh"), *arguments],
                              env=env, capture_output=True, text=True)
    assert toggle().returncode != 0, "Missing assets accepted"
    target = scratch / "data/dots-miku/prototypes/Miku"
    target.mkdir(parents=True)
    (target / "manifest.json").write_text("{}")
    assert toggle().returncode == 0 and (scratch / "active").exists()
    # Stop must work even when the renderer has since been uninstalled.
    (bin_dir / "shimeji-overlayd").rename(bin_dir / "renderer")
    assert toggle().returncode == 0 and not (scratch / "active").exists()
    assert toggle().returncode != 0, "Missing dependency accepted"
    (bin_dir / "renderer").rename(bin_dir / "shimeji-overlayd")
    (scratch / "fail-start").touch()
    assert toggle().returncode != 0 and not (scratch / "active").exists()
    assert toggle("--run").returncode != 0, "Missing patched renderer accepted"
    renderer = scratch / "data/dots-miku/bin/shimeji-overlayd"
    renderer.parent.mkdir()
    renderer.symlink_to(bin_dir / "shimeji-overlayd")
    assert toggle("--run").returncode == 0
    assert (scratch / "input-args").read_text().strip() == str(ROOT / ".config/hypr/miku-input.py")
    assert toggle("invalid").returncode != 0
    if args.engine:
        engine = runpy.run_path(str(args.engine), run_name="dots_miku_test")
        staged = scratch / "converted"
        staged.mkdir()
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            setup["prepare"](staged, engine)
        assert not output.getvalue().strip(), output.getvalue()
        manifest = json.loads((staged / "manifest.json").read_text())
        assert manifest["name"] == "Shimeji.Miku"
        assert (staged / manifest["icon"]).is_file()
        assert len(list((staged / "assets").glob("*.qoi"))) == 62
        actions = json.loads((staged / "actions.json").read_text())
        action_names = {item["name"] for item in actions}
        loaded_actions = set()
        for action in actions:
            for animation in action["content"]:
                if animation["type"] == "ActionReference":
                    assert animation["action_name"] in loaded_actions, "Renderer cannot resolve forward action references"
                for frame in animation.get("frames", []):
                    assert (staged / "assets" / frame["image"]).read_bytes()[:4] == b"qoif"
                    if frame["image"] in {"shime12.qoi", "shime13.qoi", "shime14.qoi", "shime52.qoi"}:
                        from PIL import Image
                        with Image.open(ROOT / "assets/miku" / frame["image"].replace(".qoi", ".png")) as sprite:
                            assert frame["image_anchor_x"] == 0, "Cropped wall sprite needs a zero anchor"
                            header = (staged / "assets" / frame["image"]).read_bytes()
                            assert int.from_bytes(header[4:8], "big") == sprite.getbbox()[2] - sprite.getbbox()[0] - 12, "Wall contact inset was not applied"
                if animation["type"] == "Animation":
                    assert animation["hotspots_count"] == 1
                    hotspot, = animation["hotspots"]
                    assert hotspot["button"] == "Middle" and hotspot["behavior"] == "RemoveMiku"
                    assert hotspot["width"] > 0 and hotspot["height"] >= 128
            loaded_actions.add(action["name"])
        behaviors = json.loads((staged / "behaviors.json").read_text())
        names = {item["name"] for item in behaviors["definitions"]}
        assert {"Fall", "Dragged", "Thrown", "RunAlongWorkAreaFloor", "ChaseMouse",
                "ClimbAlongCeiling", "SplitIntoTwo", "PullUpShimeji", "SitAndSpinHead",
                "ThrowIEFromLeft", "ThrowIEFromRight", "RemoveMiku"} <= names
        remove = next(action for action in actions if action["name"] == "RemoveMiku")
        assert remove["embedded_type"] == "Dispose"
        for behavior in behaviors["definitions"]:
            assert behavior["is_conditioner"] or behavior["action"] in action_names
            assert all(item["name"] in names for item in behavior["next_behavior_list"])
        for action in actions:
            if action.get("born_behavior"):
                assert action["born_behavior"] in names

        # Upgrade the earlier small pack, keep its backup outside the spawn
        # directory, and leave the current installation alone on reruns/failure.
        with mock.patch.dict(os.environ, {"XDG_DATA_HOME": str(scratch / "data")}), \
             mock.patch("sys.argv", ["setup-miku.py"]), \
             mock.patch.object(setup["shutil"], "which", return_value=str(args.engine)):
            setup["main"]()
            assert json.loads((target / "manifest.json").read_text())["name"] == "Shimeji.Miku"
            assert len(list(target.parent.iterdir())) == 1
            backups = list(target.parent.parent.glob("backup-*/Miku/manifest.json"))
            assert len(backups) == 1 and backups[0].read_text() == "{}"
            stamp = target / ".source-sha256"
            before = stamp.stat().st_mtime_ns
            setup["main"]()
            assert stamp.stat().st_mtime_ns == before
            stamp.write_text("outdated")
            with mock.patch.dict(setup["main"].__globals__, {"prepare": mock.Mock(side_effect=ValueError("conversion failed"))}):
                try:
                    setup["main"]()
                    raise AssertionError("Failed conversion was accepted")
                except ValueError as error:
                    assert str(error) == "conversion failed"
            assert stamp.read_text() == "outdated" and (target / "manifest.json").is_file()
        print("PASS: bundled sprite conversion and compiled behavior/sprite references")
        print("PASS: old-pack upgrade, backup isolation, unchanged rerun and conversion failure")

for file in ("actions.xml", "behaviors.xml"):
    ET.parse(ROOT / ".config/hypr/miku" / file)
sprites = {node.attrib["Image"].lstrip("/")
           for node in ET.parse(ROOT / ".config/hypr/miku/actions.xml").iter()
           if "Image" in node.attrib}
bundled = {path.name for path in (ROOT / "assets/miku").glob("*.png")}
assert len(bundled) == 62 and sprites <= bundled
for name in bundled:
    assert (ROOT / "assets/miku" / name).read_bytes()[:8] == b"\x89PNG\r\n\x1a\n"
ns = {"m": "http://www.group-finity.com/Mascot"}
actions = ET.parse(ROOT / ".config/hypr/miku/actions.xml")
behaviors = ET.parse(ROOT / ".config/hypr/miku/behaviors.xml")
action_names = {node.attrib["Name"] for node in actions.findall(".//m:Action", ns) if "Name" in node.attrib}
assert len(action_names) == 93
for ref in actions.findall(".//m:ActionReference", ns):
    assert ref.attrib["Name"] in action_names
names = {node.attrib["Name"] for node in behaviors.findall(".//m:Behavior", ns)}
for ref in behaviors.findall(".//m:BehaviorReference", ns):
    assert ref.attrib["Name"] in names
    assert "Condition" not in ref.attrib, "Engine ignores conditions on behavior references"
overlay = (ROOT / ".config/hypr/miku/overlay.conf").read_text()
assert "breeding=true\n" in overlay and "mascot_limit=5\n" in overlay
for name in ("SplitIntoTwo", "PullUpShimeji"):
    node = next(node for node in behaviors.findall(".//m:Behavior", ns) if node.attrib["Name"] == name)
    assert node.attrib["Condition"] == "#{mascot.count < 5}"
assert (ROOT / ".config/hypr/hyprland.lua").read_text().count(' + SHIFT + M"') == 1
print("PASS: toggle start/stop, missing dependencies/assets, failed start, isolated renderer, XML and bundled PNGs")
config = (ROOT / ".config/hypr/hyprland.lua").read_text()
assert 'bind(mod .. " + mouse:273", hl.dsp.window.resize()' in config
assert 'Remove the clicked Miku' not in config
print("PASS: Super+right-drag remains assigned to window resizing")
