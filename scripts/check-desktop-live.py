#!/usr/bin/env python3
"""Exercise the deployed desktop with disposable terminal windows on empty tags.

Run on the laptop after deployment. Only windows created by this script are
closed. Physical gestures and unplugging the monitor are left for user testing.
"""
import json
import os
from pathlib import Path
import shlex
import subprocess
import time


def main():
    env = os.environ.copy()
    env["XDG_RUNTIME_DIR"] = f"/run/user/{os.getuid()}"
    instance, = json.loads(subprocess.check_output(["hyprctl", "instances", "-j"], env=env))
    env.update(HYPRLAND_INSTANCE_SIGNATURE=instance["instance"], WAYLAND_DISPLAY=instance["wl_socket"])

    def query(name):
        return json.loads(subprocess.check_output(["hyprctl", "-j", name], env=env))

    def dispatch(code):
        result = subprocess.check_output(["hyprctl", "dispatch", code], text=True, env=env).strip()
        if result != "ok":
            raise RuntimeError(result)

    def action(code):
        dispatch("function() " + code + " end")
        time.sleep(0.3)

    original = query("activewindow").get("address")
    original_cursor = query("cursorpos")
    original_workspaces = {m["name"]: m["activeWorkspace"]["id"] for m in query("monitors")}
    candidates = [w for w in query("workspaces") if w["windows"] == 0 and w["id"] % 10 in range(1, 10)]
    candidates.sort(key=lambda w: (w["monitor"] != "DP-4", -w["id"]))
    if not candidates:
        raise SystemExit("No empty logical workspace available for live tests")
    workspace = candidates[0]["id"]
    test_class = f"dots-test-{os.getpid()}"

    def clients():
        return sorted([c for c in query("clients") if c["class"] == test_class], key=lambda c: (c["at"][0], c["at"][1]))

    def geometry():
        return {c["address"]: (c["at"], c["size"]) for c in clients()}

    try:
        dispatch(f"hl.dsp.focus({{workspace={workspace}}})")
        for count in range(1, 10):
            command = shlex.join(["alacritty", "--class", test_class, "--title", f"Desktop test {count}", "-e", "sleep", "1800"])
            dispatch("hl.dsp.exec_cmd(" + json.dumps(command) + ")")
            deadline = time.monotonic() + 5
            while len(clients()) != count and time.monotonic() < deadline:
                time.sleep(0.1)
            assert len(clients()) == count, "test window did not open"
            time.sleep(0.3)
            if count not in (1, 2, 3, 5, 9):
                continue
            action("dots.rebuild()")
            baseline = geometry()
            for _ in range(2):
                for _ in range(4):
                    action("dots.cycle_layout()")
                assert geometry() == baseline, f"Dwindle changed after a layout round trip with {count} windows"
            print(f"Dwindle round trips: {count} windows OK", flush=True)

        windows = clients()
        for i in range(1, len(windows)):
            previous, current = windows[i - 1], windows[i]
            assert current["at"][0] >= previous["at"][0] and current["at"][1] >= previous["at"][1], "Spiral reversed"
        dispatch("hl.dsp.focus({window=" + json.dumps("address:" + windows[0]["address"]) + "})")
        action("dots.swap(1)")
        swapped = geometry()
        for _ in range(4):
            action("dots.cycle_layout()")
        assert geometry() == swapped, "Deliberate swap lost on layout round trip"
        # Cursor and focus must not choose the next reconstruction's root.
        dispatch("hl.dsp.focus({window=" + json.dumps("address:" + clients()[-1]["address"]) + "})")
        dispatch("hl.dsp.cursor.move({x=3000,y=900})")
        for _ in range(4):
            action("dots.cycle_layout()")
        assert geometry() == swapped, "Focus/cursor changed spiral reconstruction"
        print("Deliberate swaps survive; focus/cursor do not change the spiral", flush=True)
        chosen = windows[0]["address"]
        dispatch("hl.dsp.focus({window=" + json.dumps("address:" + chosen) + "})")
        action("dots.minimize()")
        assert next(c for c in clients() if c["address"] == chosen)["workspace"]["id"] < 0
        subprocess.run(["hyprctl", "reload"], env=env, check=True, stdout=subprocess.DEVNULL)
        time.sleep(0.8)
        action("dots.restore()")
        assert next(c for c in clients() if c["address"] == chosen)["workspace"]["id"] == workspace
        action("dots.toggle_sticky(); dots.toggle_ontop()")
        action("dots.toggle_ontop(); dots.toggle_sticky()")
        assert not next(c for c in clients() if c["address"] == chosen)["floating"]
        action("dots.magnify()")
        assert next(c for c in clients() if c["address"] == chosen)["floating"]
        action("dots.magnify()")
        assert not next(c for c in clients() if c["address"] == chosen)["floating"]
        print("Minimize/reload/restore, independent sticky/ontop, magnify OK", flush=True)
        for mon in query("monitors"):
            dispatch("hl.dsp.focus({monitor=" + json.dumps(mon["name"]) + "})")
            action("dots.view(9); dots.browse(1)")
            assert query("activeworkspace")["id"] % 10 == 1
            action("dots.browse(-1)")
            assert query("activeworkspace")["id"] % 10 == 9
        print("Both monitors wrap 9→1 and 1→9", flush=True)
        errors = subprocess.check_output(["hyprctl", "configerrors"], env=env, text=True).strip()
        assert not errors, errors
    finally:
        for c in clients():
            dispatch("hl.dsp.window.close({window=" + json.dumps("address:" + c["address"]) + "})")
        time.sleep(0.5)
        for ws in original_workspaces.values():
            dispatch(f"hl.dsp.focus({{workspace={ws}}})")
        if original:
            dispatch("hl.dsp.focus({window=" + json.dumps("address:" + original) + "})")
        dispatch(f"hl.dsp.cursor.move({{x={original_cursor['x']},y={original_cursor['y']}}})")


if __name__ == "__main__":
    main()
