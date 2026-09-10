# dots

##### ***!Disclaimer: the install script is more of a general guideline for installing rather than a concrete script!***

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
