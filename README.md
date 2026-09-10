# dots

##### ***!Disclaimer: the install script is more of a general guideline for installing rather than a concrete script!***

### Edge audio visualizer

**Super+G** toggles a continuous cyan audio spectrum along all four outer edges
of each display. A native Cairo renderer draws antialiased curves without font
glyphs, column gaps or stepped heights. The 16px surfaces fit in the 24px outer
gaps; windows have 14px inner gaps. Each curve spans its available edge and
tapers near the corners to the earlier small one-step tips.
Surfaces sit below windows, pass clicks through and reserve no space.
The top spectrum sits below Waybar's reserved area. Display hotplug is handled
while running. It starts off at login; stopping it also stops audio capture.

The Bash launcher pipes one shared 64-band CAVA capture into a small C renderer
using GTK3, Cairo and GTK layer shell. It compiles with Clang on first start or
after source changes, caching the binary under `~/.cache/dots-visualizer/`.
Dependencies are listed in the installer (`clang`, `pkgconf`, `gtk3`,
`gtk-layer-shell`, `cava`); they were already available on the laptop.
No Python is used. The old Waybar renderer is retained as a fallback.

Peak normalization makes the display similar at different system and Spotify
volumes, with instant normalization attack and a short release after volume drops. The curves
represent relative frequency content rather than absolute playback loudness.
At extremely low levels, capture quantization can affect the shape; silent or
muted capture remains blank. The visualizer does not change playback volume.
Spatial interpolation smooths between frequency bands. CAVA runs at 60fps with
`noise_reduction = 20` and sleep disabled to avoid delayed wakeups. Incoming
peaks draw immediately, with a short 35ms release instead of a second slow
rise/fall filter. Geometry follows each layer surface's
current logical dimensions. Super+T does not hide the visualizer.

Native rendering and placement live in `.config/hypr/visualizer-renderer.c`;
audio settings are in `visualizer-cava.conf`. The Waybar JSON and stylesheet
configure only the fallback renderer.
See the upstream [CAVA configuration](https://github.com/karlstav/cava/blob/master/example_files/config)
and [GTK layer shell documentation](https://wmww.github.io/gtk-layer-shell/).

Fallback checks: `bash scripts/check-visualizer.sh`. Native headless checks on
Linux: build with `bash .config/hypr/visualizer.sh --build`, then run the printed
binary path with `--self-test`. The strict-warning build and native normalization,
parser and corner geometry checks passed on the laptop on 2026-09-10.
Live music produced changing nonzero frames. Three stop/start cycles
passed, leaving no CAVA processes or visualizer surfaces after stopping.
Both displays have four 16px bottom-layer surfaces; focus and reserved space
remain unchanged. The continuous curve and corner screenshots were visually
checked. Only one CAVA capture feeds both displays. Native normalization uses
the same peak envelope as the previously volume-tested Bash implementation;
the native self-test checks equal spectra at proportional input amplitudes.

For selective deployment, run the laptop check/sync workflow, install CAVA,
then run `bash scripts/deploy-visualizer.sh` from the snapshot on the laptop.
It backs up affected files, merges the binding and reloads Hyprland without
starting the visualizer. Initial backup: `~/dots-dev/visualizer-backup.DD0zfEkG`;
before the live fixes: `~/dots-dev/visualizer-backup.bO5uxuw3`.
Before the design revision: `~/dots-dev/visualizer-backup.4Qybf8Gl`;
before final spacing: `~/dots-dev/visualizer-backup.xtRxi88N`.
Before restoring the slim design and adding normalization:
`~/dots-dev/visualizer-backup.PQV9YMaT`.
Before switching to native rendering: `~/dots-dev/visualizer-backup.dM6SSFjF`.
Before the latency/corner revision: `~/dots-dev/visualizer-backup.wVczxd3h`.
With music playing, `bash scripts/check-visualizer-live.sh` repeats the checks
and leaves it on. Do not enable the service; the shortcut starts it on demand.
`bash scripts/check-visualizer-volume-live.sh` temporarily lowers system and
Spotify volume to test normalization, then restores both settings.
To compare the old bars, run `systemctl --user set-environment DOTS_VISUALIZER_RENDERER=bars`
and restart `dots-visualizer.service`. Return to the fluid renderer with
`systemctl --user unset-environment DOTS_VISUALIZER_RENDERER` and restart again.
Physical key/click-through checks, real silence, fullscreen coverage, live
scaling/hotplug, Waybar toggling and logout cleanup remain untested. Diagnostics:
`journalctl --user -u dots-visualizer.service -b`.

### Desktop startup

The centered clocks use 11pt text, slightly larger than the bar's 10pt default,
while retaining the existing 30px bar height.

Super+T controls the main bar through `~/.config/hypr/waybar.sh`. Hyprland
starts it directly, without a Waybar systemd service. The helper tracks and
validates its PID, waits for surfaces and signal handlers, and restores the
requested visibility. It can start a missing bar when called. Signals target
only this process, leaving the edge visualizer alone.
Restart it with `bash ~/.config/hypr/waybar.sh restart`.
Diagnostics: `$XDG_RUNTIME_DIR/dots-waybar-control/waybar.log`.

Spotify autostart uses `spotify-launcher --skip-update`, so an updater DNS failure
at login cannot block the installed client. Launch `spotify-launcher` normally
when online to allow update checks.

pCloud's autostart check recognizes its running `pcloud.bin` process and avoids
opening its window with a duplicate launch. Keep pCloud's **Start minimized**
setting enabled (already enabled on the laptop). Fresh launch and repeated
startup were checked to remain windowless.

These startup fixes are active on the laptop. To apply them from a future
snapshot, run `python3 SNAPSHOT/scripts/deploy-startup-fixes.py` in the graphical
session; it backs up affected files and preserves unrelated active settings.

### Desktop watermark

“Activate Linux” and “Go to Settings to activate Linux.” appear at the lower
right of each display through the existing Waybar process. The transparent,
click-through Wayland bottom layer stays below application windows, reserves
no space and remains visible when the top bar is hidden. It is a desktop layer
surface, not a managed application window; no package is added.

The watermark uses 15pt text, with a larger title.
Edit the text and placement in `scripts/generate-waybar.py`, then run
`python3 scripts/generate-waybar.py`. Styling lives in `.config/waybar/style.css`.
Active on the laptop. Live checks confirmed bottom-layer placement on both
outputs, no reserved space, and persistence while toggling the top bar. The
laptop-panel crop was visually checked. Physical click-through, display reconnect
and fresh-login checks remain pending.

### Hyprland sounds

Super+P and Print play a quiet villager agreement after successful region capture,
then open Swappy. Cancelling selection or failing capture stays silent.
Battery warnings play villager disagreement at 20% and hurt at 10%, only while
discharging. Waybar uses the same thresholds. Each threshold alerts once until
capacity recovers above 22% or 12%, respectively; state lasts for the login session.
Starting below 10% emits only the critical alert. The battery timer checks every
30 seconds and starts through Hyprland autostart, independently of Waybar visibility.

All four sound files live in `.config/hypr/sounds/`. Sound levels and file choices
live in `.config/hypr/sound.sh`; playback respects
output mute and volume. The installer already copies the Hyprland directory and
user systemd units. Rofi timers and alarms use the same helper with their original villager idle
sound at the original volume, with their existing repeat behavior. A custom `sound` in Rofi settings
still overrides that default.
Run `python3 scripts/check-desktop-sounds.py` for offline simulated-event checks.

Active on the laptop, with backups in
`~/dots-dev/desktop-effects-backup.hbkad_vp`. The Arch fixture checks passed for
thresholds, charging, repeat suppression and capture failures. Real PipeWire
playback, native timer notification delivery and both dismissal paths passed.
The live screenshot check passed real selection cancellation and real capture
into Swappy using a fixed test region. Physical audibility and manual shortcut
confirmation remain pending; actual battery discharge and fresh login were not
forced for testing.

For future selective updates, run `python3 scripts/laptop-dev.py check` and
`python3 scripts/laptop-dev.py sync`, then run
`python3 SNAPSHOT/scripts/deploy-desktop-effects.py` in the graphical session.
It backs up affected files and merges the screenshot bindings, battery autostart,
Waybar thresholds and watermark without applying unrelated features.
Live checks: `python3 SNAPSHOT/scripts/check-screenshot-live.py` and
`bash SNAPSHOT/scripts/check-clock-live.sh` (also with `--close`).

### Vimium

Import [vimium-options.json](vimium-options.json) from Vimium's options page
using its backup restore control. Export your existing settings first: importing
replaces the included settings. See [the shortcut and search reference](VIMIUM.md).
The theme uses the locally installed Monocraft font, with a monospace fallback.

The display picker lives in `.config/rofi/modi/monitors.sh`, using the shared
Rofi menu helpers. `.config/hypr/monitors.sh` handles profiles and display changes.
Monitor layouts use Hyprland and Rofi. The MSI MAG272QR is recognized by its full
monitor description and automatically placed to the right of the laptop screen.
The external display becomes primary; existing windows move there while keeping
logical workspace numbers 1–9. Disconnecting it brings windows back to the laptop.

**Super+1–9** and numbered bar buttons switch directly to the selected desktop.
The outgoing desktop slides down and the destination rises from below, using
550ms fluid animations. **Super+, / Super+.** wrap between 1 and 9.
**Super+Shift+Space** cycles Dwindle → Tile → Fair → Dwindle. Individual
windows can still be floated with **Super+Shift+F**.
Apply these settings with `python3 SNAPSHOT/scripts/deploy-workspace-motion.py`;
check direct switching with `python3 SNAPSHOT/scripts/check-workspace-motion-live.py`.

For an unfamiliar monitor, Rofi asks **Right / Left / Top / Bottom / Duplicate**,
relative to the laptop screen. The choice applies immediately and is remembered.
Press **Super+Ctrl+P** to change it later. Escape leaves the layout unchanged.
Duplicate uses the external display as the source for both screens. Current
resolution, refresh rate, scaling and rotation are preserved.

Repository defaults live in `.config/hypr/monitors.json`, keyed by the full
`description` from `hyprctl monitors all -j`. Interactive choices are stored in
`~/.config/dots-monitors/profiles.json` and override those defaults; installer
updates preserve this separate file. Remove an entry there to use its repository
default again. Layout values are `right`, `left`, `top`, `bottom`, and `duplicate`.
These profiles describe an external display relative to the built-in panel.
Reloading reapplies saved layouts without gathering windows again, so you can
manually move windows back onto the secondary display during a session.

Laptop validation: sync with `python3 scripts/laptop-dev.py sync`, then run
`python3 SNAPSHOT/scripts/deploy-monitors.py` on the laptop. It validates and backs
up the affected configs, applies only display changes, and reloads Hyprland.
The installed `~/dots` checkout remains untouched. Tests are
`python3 -B scripts/check-monitors.py` and `lua scripts/check-desktop.lua`;
`scripts/check-monitors-live.py` briefly exercises all layouts on the MSI/laptop
pair and tests Rofi selection, then restores the MSI-right arrangement.

The lock screen uses a compact, translucent Rofi-style panel over a blurred
desktop. It uses native Hyprlock fingerprint authentication in parallel with
password entry: touch the sensor, or type your password and press Enter. Its
configuration is `.config/hypr/hyprlock.conf`. The password method uses Arch's
`login` PAM service, which the stock `hyprlock` service includes, preserving the
system password and failed-attempt checks while avoiding older `pam_fprintd`
entries added to `/etc/pam.d/hyprlock`. No system PAM files need changing.

Apply just this configuration on the laptop with
`bash SNAPSHOT/scripts/deploy-lockscreen.sh`; it backs up the active file and takes
effect on the next **Super+L**. For a preview without locking the real desktop,
launch `scripts/check-lockscreen.py` from the local graphical session (its docstring
shows the SSH/Hyprland launch command). It tests rendering and sensor readiness
in a disposable nested compositor. Actual password/fingerprint matches must be
tested locally; do not send passwords or fingerprint data through chat.

### System fonts

The font is **Monocraft Nerd Font**. In `bash install.sh`, select **Configure
system fonts (desktop, Plymouth, console)**. This applies desktop font defaults,
installs the font system-wide, copies the bundled console bitmap, configures the
Plymouth theme and rebuilds boot images. Font setup uses Bash and standard system
tools, with no embedded Python or font-conversion dependency.
Existing font files are reused. The font implementation lives in `install.sh`.

Desktop backups are under `~/.local/state/dots/backups/fonts.*`; system backups
are under `/var/lib/dots/backups/fonts.*`. Reopen apps to refresh cached fonts;
boot and console changes take effect after reboot. If the earlier font setup
was already applied, no migration or rerun is required.

`python3 scripts/check-fonts.py` checks font matching and stages the installer's
system changes in a temporary directory (no sudo). Emoji and missing characters
keep fallback fonts; embedded images and bundled web fonts are exceptions.
For rollback, restore backed-up files, remove paths in `created-files.txt`,
restore saved `gsettings.txt` values using `gsettings set`, and rebuild boot
images after reverting system files.

Run opened directly with **Super+R** closes on Escape. Tab opens the menu;
Run selected from that menu returns there on Escape.
The compact lock screen shows the latest authentication error inside the input
field, without reserving empty rows. Use `scripts/check-lockscreen.py --errors`
in the graphical session to preview it without failed authentication attempts.
