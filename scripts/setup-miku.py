#!/usr/bin/env python3
"""Install Miku's sprites and compile behaviors without starting Wayland."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import runpy
import shutil
import tempfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent.parent
CONFIG = ROOT / ".config/hypr/miku"
SPRITES = ROOT / "assets/miku"
WALL_INSET = 12  # Source pixels trimmed from the wall-facing side for closer contact.


def prepare(destination, engine):
    """Convert the complete bundled sprite pack and compile its behaviors."""
    from PIL import Image

    sprites = sorted(SPRITES.glob("*.png"))
    if not sprites:
        raise ValueError("Bundled Miku sprites are missing")
    for node in ET.parse(CONFIG / "actions.xml").iter():
        if "Image" in node.attrib:
            name = node.attrib["Image"].lstrip("/")
            if Path(name).name != name or SPRITES / name not in sprites:
                raise ValueError(f"Missing or invalid sprite: {name}")
    assets = destination / "assets"
    assets.mkdir()
    sizes = {}
    for path in sprites:
        with Image.open(path) as sprite:
            # Hyprland squeezes scaled subsurfaces that extend past a wall.
            # Remove transparent side margins so the zero-anchor wall poses
            # fit entirely on-screen, including when mirrored.
            if path.stem in {"shime12", "shime13", "shime14", "shime52"}:
                left, _, right, _ = sprite.getbbox()
                sprite = sprite.crop((left + WALL_INSET, 0, right, sprite.height))
            sizes[path.with_suffix(".qoi").name] = sprite.size
            engine["encode_img"](sprite.convert("RGBA"), False, str(assets / path.with_suffix(".qoi").name))
    descriptor = os.open(CONFIG, os.O_RDONLY)
    try:
        compiled = engine["Compiler"].compile_shimeji(str(assets), descriptor)
    finally:
        os.close(descriptor)
    programs, actions, behaviors = compiled
    actions = json.loads(actions)
    for action in actions:
        for animation in action["content"]:
            if animation["type"] != "Animation":
                continue
            # Full-frame middle-click hotspot; native right-clicks still reach
            # the input client and left-clicks still begin a drag.
            width = max(sizes[frame["image"]][0] for frame in animation["frames"])
            height = max(sizes[frame["image"]][1] for frame in animation["frames"])
            animation["hotspots"] = [dict(type="Hotspot", shape="Rectangle", x=0, y=0,
                                         width=width, height=height, button="Middle",
                                         behavior="RemoveMiku")]
            animation["hotspots_count"] = 1
    for name, contents in zip(("scripts", "actions", "behaviors"), (programs, json.dumps(actions, indent=2), behaviors)):
        (destination / f"{name}.json").write_text(contents)
    manifest = dict(name="Shimeji.Miku", version="0.0.1", display_name="Miku",
                    description="Full Miku animation pack; sprites by Canary Yellow",
                    artist="Canary Yellow", programs="scripts.json", actions="actions.json",
                    behaviors="behaviors.json", assets="assets", icon="assets/icon.qoi")
    (destination / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    shutil.copyfile(CONFIG / "README.md", destination / "SOURCE.md")


def source_digest():
    digest = hashlib.sha256()
    for path in [Path(__file__), CONFIG / "actions.xml", CONFIG / "behaviors.xml",
                 CONFIG / "README.md", *sorted(SPRITES.glob("*.png"))]:
        digest.update(path.name.encode())
        digest.update(path.read_bytes())
    return digest.hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.parse_args()
    target = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "dots-miku/prototypes/Miku"
    digest = source_digest()
    if target.exists():
        if not (target / "manifest.json").is_file():
            raise SystemExit(f"Incomplete Miku installation at {target}; inspect it before retrying")
        stamp = target / ".source-sha256"
        if stamp.is_file() and stamp.read_text() == digest:
            print(f"Miku already installed: {target}")
            return
    executable = shutil.which("shimejictl")
    if not executable:
        raise SystemExit("Install wl_shimeji-git and python-pillow, then rerun this script")
    # The packaged CLI is a composed Python file. Loading its converter avoids
    # the CLI's unconditional connection to (or launch of) a Wayland daemon.
    engine = runpy.run_path(executable, run_name="dots_miku_converter")
    if not {"Compiler", "encode_img"} <= engine.keys():
        raise SystemExit("Unsupported shimejictl converter; no Miku files installed")
    target.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".miku-", dir=target.parent) as scratch:
        scratch = Path(scratch)
        staged = scratch / "Miku"
        staged.mkdir()
        prepare(staged, engine)
        (staged / ".source-sha256").write_text(digest)
        backup = None
        if target.exists():
            # Outside prototypes: -se must not spawn the backed-up character.
            backup = Path(tempfile.mkdtemp(prefix="backup-", dir=target.parent.parent)) / "Miku"
            target.rename(backup)
        try:
            staged.rename(target)
        except OSError:
            if backup:
                backup.rename(target)
            raise
        if backup:
            print(f"Previous Miku assets: {backup}")
    print(f"Miku installed (not started): {target}")


if __name__ == "__main__":
    main()
