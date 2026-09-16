# Miku companion assets

Sprites: **Canary Yellow**, [しめはつね](https://canarypop.ciao.jp/shimehatsune.htm).
Original download: https://canarypop.ciao.jp/shimemiku.zip
Original archive SHA-256: `f54ba231b7bbd2139cdd068bbbc5923d48c6b8ead3982bef92831fc66903e6ab`

All 61 character sprites and the icon are bundled unchanged in `assets/miku/`
at the repository root. They were extracted from the checksum-verified original
archive. Setup converts all 62 local PNGs to QOI with wl_shimeji and needs
no image download. The archive's Java executables are not included.
Artwork credit remains with Canary Yellow; Hatsune Miku belongs to Crypton
Future Media. These third-party sprites are not relicensed as repository code.

The XML translates the artist's complete Japanese action and behavior files
to the English Shimeji-EE names accepted by wl_shimeji. All 91 named original
actions are retained, including running, dashing, looking around, lounging,
crawling, ceiling movement, jumping, landing, tripping, being dragged and
resisting, pulling out another Miku, splitting, and window interactions.
Frame timing and anchors follow the original pack. Setup crops transparent
side margins and twelve additional wall-facing pixels from the four converted
wall sprites (`WALL_INSET` in `scripts/setup-miku.py`). Their surfaces now fit
inside the display at both walls, avoiding Hyprland's subsurface squeezing;
the bundled PNGs remain unchanged.

Compatibility adjustments: fix a missing `()` on `Math.random` in the ceiling
route; move crawl conditions from behavior references (ignored by the converter)
onto their definitions; use `mascot.count` and a five-Miku threshold for cloning.
The engine's configured `mascot_limit` is also five. To raise that ceiling,
update both the config limit and the two cloning conditions in `behaviors.xml`.
Mouse-chasing has a low natural frequency and its follow-up behaviors can return
to normal wandering. Both original window-dashing actions have behavior entries.

Miku uses a pinned wl_shimeji renderer with `patches/wl-shimeji-drag.patch`.
It preserves the grab offset, uses the rendered sprite origin for pointer
coordinates, and migrates the dragged mascot using global pointer coordinates
even when the compositor keeps pointer focus on the original display.
It removes the fixed 120-pixel pickup/drop offset that could push a floor click
outside the screen. Out-of-bounds recovery clamps to the nearest edge instead
of respawning near the top, including throws beyond the last display.
Hyprland's synthetic-release handling is retained.
Window interactions are disabled. Releasing within 24 pixels of a side wall moves
her anchor onto it and holds for 1500 animation ticks. Dragging skips the
resistance sequence.

The engine divides sprite dimensions by `mascot_scale`: `0.75` gives about
171px at display scale 1. Edit `overlay.conf` to
change it. Super+Shift+M starts one Miku and later stops the entire group.
Hold the left mouse button directly on Miku and move the pointer to drag her;
release to drop her. Cloning happens automatically while she is on the floor.
**Right-click Miku** to start her split animation and create a clone.
**Middle-click Miku** removes that individual. Removing the last Miku stops
the renderer and input helper, so the next
Super+Shift+M starts a fresh one. The configured group limit is five.
**Super+right-drag** continues to resize application windows. Miku's click
controls apply only over her visible sprite rectangles; no global mouse binding is added.

For the alternate pulling-out animation, run
`shimejictl -s "$XDG_RUNTIME_DIR/dots-miku.sock" --do-not-start mascot set-behavior PullUpShimeji`
and click a Miku standing on the floor.

`overlay_layer=3` explicitly places Miku on the Wayland overlay layer, above
normal application windows and the audio visualizer's bottom layer in both
its native and Waybar renderers.
Toggle Miku off/on after applying the config to recreate her surfaces.

`miku-input.py` reuses the installed engine's IPC client to receive right-clicks
over mascot sprites and request `SplitIntoTwo` for that mascot's ID.
Setup adds a middle-click removal hotspot to every animation and one native
Dispose behavior. These use native hit testing; no screen polling or global
mouse listener is needed. Both processes live in the same systemd service.

To inspect the running pack's behaviors:
`shimejictl -s "$XDG_RUNTIME_DIR/dots-miku.sock" --do-not-start prototypes info Miku`.
To try a behavior, run, for example,
`shimejictl -s "$XDG_RUNTIME_DIR/dots-miku.sock" --do-not-start mascot set-behavior SitAndSpinHead`
and click a Miku.

Setup detects source changes, compiles the replacement before touching the
installed pack, and backs up old assets under `dots-miku/backup-*/Miku` beside
the `prototypes` directory. Backups cannot spawn extra characters. Unchanged
reruns do nothing. Stop Miku before updating; the selective deploy script does so.

`bash scripts/build-miku-renderer.sh` builds wl_shimeji commit
`787b5a072a9d1439af26fb2d247ba0822498023c` with the repository patch into
`~/.local/share/dots-miku/bin`. Only Miku's service adds that directory to PATH;
the system package stays intact. Build requires base-devel, git, pkgconf,
wayland, wayland-protocols, libarchive and uthash. The initial build fetches
upstream source and two pinned submodules. Unchanged builds are skipped;
replacement builds preserve `bin/shimeji-overlayd.previous`. An optional first
argument supplies an existing upstream Git repository instead of the URL.
The AUR CLI supplies the converter and IPC client; setup fails if its API changes.
Setup and build do not need a compositor. Upstream still lists Hyprland as
unsupported; this patch addresses the tested drag paths, not all compatibility.

Check: `python3 scripts/check-miku.py --engine /usr/bin/shimejictl`.

`python3 scripts/check-miku-walls-live.py` checks both outer screen walls and
an ordinary drop away from the edges against a running Miku service.

`python3 scripts/check-miku-drag-live.py` checks real pointer grabs over an empty
workspace and an application, both display crossings, throws beyond both outer
display edges, release and repeated
floor clicks. It requires two adjacent scale-1 displays, an empty workspace,
Alacritty and a C compiler. It restores workspace/pointer state and uses an
isolated renderer. `--renderer /usr/bin/shimeji-overlayd` tests the unpatched
package for comparison; `--data PATH` selects a staged pack and renderer.
