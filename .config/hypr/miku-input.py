#!/usr/bin/env python3
"""Run Miku and handle native right-click events on her sprites."""
import os
from pathlib import Path
import runpy
import shutil


def clicked(engine, client, packet):
    # Native events identify the actual clicked mascot, including overlaps.
    if packet.object_id in engine["mascots"] and len(engine["mascots"]) < 5:
        client.queue_packet(engine["ApplyBehavior"](packet.object_id, "SplitIntoTwo"))


def disposed(engine, client, packet):
    mascot = engine["mascots"].pop(packet.object_id, None)
    engine["objects"].pop(packet.object_id, None)
    if mascot and mascot.environment:
        mascot.environment.mascots.pop(packet.object_id, None)
    if not engine["mascots"]:
        client.queue_packet(engine["Stop"]())
        raise SystemExit(0)


def main():
    executable = shutil.which("shimejictl")
    if not executable:
        raise SystemExit("Install wl_shimeji-git first")
    engine = runpy.run_path(executable, run_name="dots_miku_input")
    required = {"Client", "MascotClicked", "MascotDisposed", "ApplyBehavior", "Stop", "mascots", "objects"}
    if not required <= engine.keys():
        raise SystemExit("Unsupported shimejictl input API")
    runtime = Path(os.environ["XDG_RUNTIME_DIR"])
    data = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "dots-miku"
    socket = str(runtime / "dots-miku.sock")
    # The existing client starts the renderer in this service's cgroup. It
    # cannot attach to another instance because start=True rejects that case.
    launcher = engine["Client"](socket, {"start": True, "verbose": True, "cmdline": [
        "-s", socket, "-cd", str(data), "-pr", str(data / "prototypes"),
        "-c", str(Path(__file__).with_name("miku") / "overlay.conf"), "--no-plugins", "-se",
    ]})
    # The inherited startup connection is absent from the renderer's broadcast
    # list. A normal socket connection receives clicks, births and removals.
    client = engine["Client"](socket, {"start": False})
    launcher.socket.close()
    client.register_callback(engine["MascotClicked"], lambda c, p: clicked(engine, c, p))
    client.register_callback(engine["MascotDisposed"], lambda c, p: disposed(engine, c, p))
    client.dispatch_events()


if __name__ == "__main__":
    main()
