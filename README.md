# dots

##### ***!Disclaimer: the install script is more of a general guideline for installing rather than a concrete script!***

## OpenCode

See [the OpenCode guide](.config/opencode/README.md) for agents, slash commands,
the local model, permission behavior, and configuration validation.

## Development on the test laptop

Edit this checkout on the development computer. The Arch test laptop is
`victor@192.168.1.177`, with its installed repository at `~/dots`.
SSH uses the dedicated local key `~/.ssh/dots_laptop`; private keys and passwords
must never be added to this repository.

From this checkout, using Python 3:

```sh
python3 scripts/laptop-dev.py check
python3 scripts/laptop-dev.py sync
```

`sync` prints a fresh snapshot path under the laptop's `~/dots-dev/`.
It includes tracked working-tree edits and new non-ignored files, omits deleted
files, and leaves `~/dots` and the active desktop configuration untouched.
Tracked files remain included even if they match an ignore rule. Review new
files before syncing. Each snapshot is retained for comparison and can be
removed manually when no longer needed. SSH and tar are required on the laptop;
rsync is not required. Override the connection with `--host` and `--identity`.

Read actual laptop files and run checks directly over SSH:

```sh
ssh -i ~/.ssh/dots_laptop -o IdentitiesOnly=yes victor@192.168.1.177
```

In that session, inspect the printed snapshot and validate the component being
changed. The installer copies files into the home directory, so syncing a
snapshot does not activate it. Back up the affected active files before copying
the selected configs from the snapshot, then reload the relevant application.
Do not run the full installer for every config edit. Keep all resulting fixes
in the development checkout, including any necessary installation changes.
Do not copy the laptop's entire home directory back into Git.

## Hyprland desktop behavior

The appearance is configured in `.config/hypr/hyprland.lua`; session behavior
lives in `desktop.lua` with pure workspace/layout policy in `desktop-core.lua`.
Existing keyboard assignments and pointer steps are preserved.

Each monitor has workspaces labelled 1–9. Hyprland requires unique internal IDs:
DP-4 uses 1–9, eDP-1 uses 11–19, and additional outputs get their own ranges.
Keyboard navigation and touchpad swipes wrap within the focused monitor's set.
Disconnecting a monitor merges its windows into the remaining active monitor's
equivalent numbered workspaces. Reconnecting creates an empty set; it does not
pull those windows back. Default applications prefer DP-4, with eDP-1 as fallback.

Super+Shift+Space cycles Dwindle, Tile, Fair, Floating. Returning to Dwindle
rebuilds the native tree: first window left, second upper-right, then successive
splits into the lower-right remainder. Deliberate swaps survive layout cycles;
cursor position and focus do not choose the root. Resizing and swapping retain
their existing shortcuts. Separately floating dialogs stay floating.

Minimizing parks a window on a hidden special workspace outside normal navigation.
Super+Shift+N restores the last minimized window; Rofi's Windows mode can select
any window, including a minimized one. Window state is stored under
`$XDG_RUNTIME_DIR`, scoped to the current Hyprland instance, so reloads preserve it
without carrying old window addresses into a new login session.

Three-finger left/right changes workspaces; up/down restores/minimizes.
Four-finger left/right cycles windows; up/down toggles magnification.
Sticky and keep-on-top can be enabled independently. Super+T toggles the bars,
which start hidden; a visible fullscreen window temporarily hides them.
The manual toggle can show them again while fullscreen remains active.

Waybar remains the distribution package. Each numbered workspace button is a
custom module using Lua dispatch, followed by the stock Hyprland taskbar module.
The `{windows}` format enables the app icons. App clicks reveal and focus that
window, including windows on inactive workspaces. Number labels reflect each
monitor's active workspace and update on compositor events. Logs are available
with `journalctl --user -t dots-waybar`.

Edit `scripts/generate-waybar.py` to change the bar or its shared workspace
definition, then run `python3 scripts/generate-waybar.py`. Commit the resulting
`.config/waybar/config.jsonc` alongside the generator. `--check` detects stale
output. Waybar reads the generated file directly; startup needs no generator
and uses the normal distribution binary.

### Desktop validation and deployment

After `scripts/laptop-dev.py sync`, run on the laptop, from the snapshot:

```sh
lua scripts/check-desktop.lua
env -u HYPRLAND_INSTANCE_SIGNATURE Hyprland --verify-config -c "$PWD/.config/hypr/hyprland.lua"
python3 scripts/deploy-desktop.py "$PWD"
python3 scripts/check-desktop-live.py
```

Deployment validates first, prints a timestamped backup path, applies only the
selected desktop files, and reloads Hyprland and `/usr/bin/waybar`. It preserves
`~/dots`, generated monitor files, display modes, and installed packages. The
live check uses disposable terminals on an empty workspace, cleans them up, and
restores the previous workspaces and focus. It does not unplug displays or test
physical gestures. Test those manually before accepting a release.

To restore a printed backup, run
`python3 scripts/deploy-desktop.py --restore /home/victor/dots-dev/backups/desktop-TIMESTAMP`.
Rollback restores configuration files, not previous window placement. For a
series of deployments, use the original backup for the pre-task configuration.

## Releases

Use Git commits for development and annotated tags `v1.2.0`, `v1.2.1`, and so on
for tested releases. The existing commit titled `v1.2` has no corresponding tag;
the first new tested release can be `v1.2.0`. Record changes and laptop validation
in `CHANGELOG.md` before committing. Tag only after the committed contents have
been tested and the working tree is clean:

```sh
git tag -a v1.2.0 -m 'Release v1.2.0'
```

Push the release commit and its tag to the shared Git remote when ready to
publish. On the laptop, fetch that tag into `~/dots`, check that its working tree
is clean, and switch to the tag with `git switch --detach v1.2.0`. Apply the tested
configs there as needed. A tag records repository contents; it does not restore
active home-directory configs, which require their own backups.
