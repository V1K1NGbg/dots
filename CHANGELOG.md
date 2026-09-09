# Changelog

## Unreleased

- Remove the bundled font license file, its installer copy and its validation check.

- Replace the monitor controller with Bash and jq, preserving profile identity,
  saved choices, scaling, rotation, mirroring, serialized hotplug handling and
  reload behavior. Update startup, Rofi, installer and selective deployment;
  back up and retire the old Python controller. Tests exercise the Bash code.
  Laptop validation passed for all five arrangements, Rofi selection, geometry,
  profile persistence, cancellation and reload behavior. Applied with backups;
  restored MSI-right. Physical unplug/replug and reboot remain untested.

- Replace the embedded Python font installer with Bash, preserving unrelated
  INI settings and original backups. Bundle the exact installed console bitmap
  without a runtime converter, removing the Pillow dependency.
  Standalone Python scripts remain; the font check now tests the Bash code.
  Isolated desktop and system checks passed on the laptop, including settings
  preservation, repeated edits, original backups and byte-identical console fonts.

- Remove the lock screen's reserved error area and reduce the panel to 420×260.
  Display the latest password or fingerprint failure inside the input field,
  replacing the placeholder at a bounded font size. Applied with a backup and
  visually checked both normal and sample-error states on the laptop; the error
  fits inside the field and fingerprint readiness passes.

- Remove the lock screen's session and fingerprint-ready labels, reduce blur,
  and reserve separate password/fingerprint error rows below a fixed-width input.
- Escape closes directly opened Run (Super+R); Run opened from the menu returns
  there. Tab still opens the menu. Add coverage for both navigation paths and a
  preview with simultaneous sample authentication errors.
- Applied the four selected configs with backups. Direct Run Escape, Tab to the
  menu, and all 12 utility-to-menu routes passed on the laptop. Inspected both
  error rows together in a disposable preview; no overlap, and fingerprint
  readiness passed. Actual failed authentication was not triggered.

- Move font configuration into the installer and add a dedicated system-font
  task; remove the standalone deployment script. Existing installations need no
  migration, and font downloads are reused.
- Make Hyprlock a compact 420×340 Rofi-style translucent panel with six-pixel
  corners, a cyan outline and slightly stronger screenshot blur.
- Avoid persistent workspace rules: Waybar 0.15 imports those without applying
  each taskbar's workspace filter, duplicating app groups on startup. Keep all
  nine custom workspace buttons and create empty workspaces on demand.
- Start Spotify with Arch's `spotify-launcher` and retain startup command logs
  in the journal instead of discarding errors.
- Laptop validation: font installer staging, desktop policy checks, fresh Waybar
  group membership without reload, and empty workspace creation on both monitors
  passed. Inspected the compact lock preview; fingerprint readiness passed.
  Spotify launched successfully. Applied selected configs with backups; a full
  reboot and physical unlock are still untested. No release tag created.

- Apply Monocraft defaults across fontconfig, GTK 2/3/4, Qt 5/6 and desktop
  font settings. Add selective deployment with backups, a custom Plymouth theme,
  a generated console bitmap font and explicit font inclusion in boot images.
- Applied desktop font settings on the laptop with backups. Font matching, emoji
  fallback, staged Plymouth configuration, and PSF generation/Unicode-table checks
  passed. System activation and reboot validation await local sudo authentication.

- Redesign Hyprlock with a blurred, dimmed desktop, translucent charcoal panel,
  large cyan clock, date, password field, keyboard layout and fingerprint status.
- Enable native fingerprint scanning alongside password entry. Use Arch's login
  password PAM stack directly so the legacy hyprlock pam_fprintd entry cannot
  delay password verification or compete for the sensor. Stop adding that entry
  in the installer; sudo fingerprint authentication is unchanged.
- Rendered and inspected a nested lock-screen preview on the laptop; confirmed
  fingerprint verification starts without keyboard input. Successful password
  and fingerprint unlocks require the user's physical test. Add targeted backup
  and deployment plus a disposable nested compositor validation script.

- Move the display picker into `rofi/modi/monitors.sh` using shared menu helpers;
  keep profile and layout handling in the Hyprland controller.

- Add monitor-specific layout profiles: MSI MAG272QR automatically sits right of
  the laptop and becomes primary. Gather windows by logical workspace when a
  layout is selected or a display connects; preserve minimized restore targets.
- Ask for Right, Left, Top, Bottom or Duplicate in Rofi for unknown displays;
  remember choices separately from repository defaults. Super+Ctrl+P reopens the
  picker. Reloads apply profiles without gathering manually relocated windows.
- Add targeted deployment with backups and monitor policy/live tests. All five
  arrangements, Rofi selection, and desktop state tests passed on the laptop;
  visually inspected the picker. Physical unplug/replug remains to be checked.

- Remove the icon license file and the generator dependency on it.

- Remove `rofi/utils` entirely; keep upgrade migration in repository scripts.
  Align dashboard columns using Unicode character counts, including weather.
  Laptop settings migration, offline icons and alarm delivery passed; inspected
  the rendered menu. Automated Escape on the external monitor timed out; the
  test window was closed manually.

- Merge weather/sound settings into `rofi/settings.json`, move sounds to
  `rofi/sounds`, and keep icon attribution in `icon-gen/LICENSE` outside icons.

- Move the private backend into `rofi/utils`; update launcher, installer,
  migration and clock-unit paths. Merge stats and shared helpers into
  `modi/common.sh`, and clock commands into `modi/time.sh`; utils keeps only
  settings, sounds and migration. Preserve saved clocks and systemd unit names.
  Laptop migration preserved clock data exactly; notification dismissal and
  all menu shortcuts/live editors passed after removing the old config folder.

- Compact the dashboard into three rows using the panel width for aligned
  left/right stats; keep colored labels and wrap on narrower screens.

- Move the main-menu clock into the dashboard, with a clear date heading,
  colored labels and separate lines for power, network and weather. Laptop
  rendering and panel checks passed. Verified obsolete worker units are absent;
  retain only native alarm scheduling and its one-shot delivery handler.

- Keep Mako and dismiss clock alerts directly from the notification, stopping
  their sound. Remove Snooze and the alert-action rows from the Time menu.

- Use uniform, smaller menu tiles with prominent shortcut letters; remove striped
  rows and legacy emoji, and match the Files terminal padding to its background.
- Escape returns utility pages to the main menu; Escape there closes the launcher.
- Let llama.cpp unload model and KV cache after 10 idle seconds for all clients;
  the next request reloads automatically and has a longer first-response time.
- Laptop validation: all 12 shortcuts, 13 utility Escape routes, live editors,
  Files rendering, cold AI completion and cancellation passed. Confirmed native
  model sleep before and after requests; process RSS settled below 710 MiB.
  Applied selected configs with a backup; no release commit or tag created.

- Bind Super+E to the Rofi menu. Match every Rofi panel to the desktop's charcoal,
  cyan, Monocraft typography and six-pixel corners; use content-sized lists,
  compact live editors, clearer selection/search highlights, and a blurred fade.
  Add a clock header and readable music volume percentages. Laptop panel previews,
  the registered Super+E binding, and AI completion/cancellation were validated.

- Laptop validation (2026-09-09): native Run/Tab navigation, 12 menu shortcuts,
  live timer/spelling previews, fzf, and configuration migration passed. Removed
  the active worker; a real native timer caught a missed deadline, delivered its
  notification/sound unit, and cleaned up after dismissal. Installed a pinned
  rofi-blocks build in the user plugin directory without sudo. Automatic AI answers,
  Cancel and Escape cleanup also passed after keeping the input widget hidden
  (removing it crashes the plugin). Native systemd units validate, and no utility
  process remains with menus closed and no clocks pending. Physical sound audibility
  and a full reboot/suspend cycle were not verified; no release tag created.

- Open native Run first and switch to a smaller menu with Tab. Remove the tray
  page and bottom hints; nest audio outputs in Music and power profiles in Power.
  Close the launcher after completed actions.
- Remove the persistent dots-utils worker and network rates. Sample CPU/memory
  on open and fetch weather only when its cache is stale.
- Schedule clocks with a persistent native systemd calendar timer and one-shot
  expiry handler. Preserve saved clocks, recurring alarms, snooze and stopwatch.
- Add Bash live views through rofi-blocks: timer previews and alarm input errors,
  spelling suggestions, and automatic short AI answers with Cancel while waiting.


- Laptop validation (2026-09-08): deployed Bash rofi and `dots-utils`; Home
  shortcuts, typing, floating fzf search and Escape passed. Stats/weather update,
  tray discovery and local AI health passed; a short AI answer completed in 2s.
  A real timer fired and its notification/sound unit was dismissed and cleaned up.
  Physical audibility and user acceptance remain to be confirmed; no release tagged.

- Replace the custom Files picker with streaming `fd` + `fzf` in a floating
  Alacritty window. Preserve exact paths when opening VS Code, move exclusions
  to rofi settings, and remove background file indexing from `dots-utils`.

- Use the final name `dots-utils` for the backend, service, paths and checks;
  preserve migration from `utils` and the earlier names.

- Rename the backend to `utils` and `utils.service`, including paths, alert
  units and checks. Retain migration from all earlier names.

- Rename the shared backend to `desktop-utils`, including its service, state,
  caches and alert units. Migrate both earlier names without overwriting current data.
- Schedule refreshes by time deadlines, isolate slow sampling from one-second
  clock checks, prevent overlapping samplers, and expose configurable intervals
  (0 disables background refresh). Add settings validation and JSON status with
  cache ages and clock counts; report manual refresh failures correctly.
- Local behavior, slow-sampler scheduling and migration checks pass; laptop
  systemd/audio validation remains pending while off-network.

- Remove rofi `config.rasi`; use the shared theme for standalone keybindings
  and route the power button through the launcher. Back up the old config before
  removing it during installation/deployment, with rollback coverage.

- Remove separate rofi and desktop defaults files. Read one complete settings
  file per component; migrate older partial settings without losing personal values.

- Nest finished icons under `rofi/icon-gen/icons/`; move common helpers into
  `modi/common.sh` and combine the AI menu and request commands in `modi/ai.sh`.
  Update generation, migration, deployment, documentation and checks.

- Add an editable `ICONS` list to the icon generator. Reuse valid local sources,
  fetch only missing/invalid originals, and render colored copies to `icons/`.
  Check cache reuse, offline refusal, downloads, and preservation on failure.

- Split rofi into a small launcher, `modi/`, shared UI helpers, finished
  `icons/`, and `icon-gen/` with pinned sources and offline rendering.
- Move clocks, stats, weather, sounds, and indexing to `dots-desktop/` and
  `dots-desktop.service`. Publish filenames as JSON lines for other consumers;
  migrate legacy settings and clocks while preserving existing overrides.
- Update installation, selected deployment/rollback, and local behavior checks
  for the new layout. Local behavior and isolated deployment/rollback checks
  pass; laptop testing remains pending while off-network.

- Rewrite the rofi runtime, window menu, tests, asset importer, and selected
  deployment tools in Bash. Replace the Python socket service with cached files,
  `jq`, and systemd-owned jobs; retain settings, clock state, icons and sound.
- Local Bash behavior checks pass for clocks, cache failure recovery, shortcuts,
  icons, and AI request handling. Arch desktop validation and deployment remain
  pending because the laptop is off-network; no release is tagged.

- Replace handmade Home icons with bundled Lucide SVGs, a shared configurable
  tint, and icon-name mappings in `hub.json`; add a pinned asset importer and
  automatic deployment discovery for new icons.
- Replace the generated alert tone with the Minecraft villager idle “hmm” from
  the requested Minecraft Wiki sounds section, retaining custom sound overrides.
- Local validation: 15 behavior/asset checks passed, including SVG transparency,
  shared tint/cache invalidation, and the complete 0.668-second Vorbis stream.
- These follow-up assets have only been checked locally; laptop validation and
  deployment are pending while the laptop is on a different network.

- Add a larger rofi dashboard with a four-column grid and Home-only one-key
  navigation, consistent icons, cyan selection, and monitor-aware sizing.
- Add cached Delft weather and system stats, indexed home path search opening in
  VS Code, short non-reasoning local AI requests, persistent clocks with audible
  notifications, tray submenus, and system-wide playback output selection.
- Add a session worker, focused behavior checks, and selected deployment with
  backups/rollback; preserve existing launcher utilities and per-machine settings.
- Rofi laptop validation is in progress; release pending.

- Restore Awesome-style workspace and window behavior while preserving the
  Hyprland theme and all existing keyboard assignments/pointer speeds.
- Give each monitor nine logical workspaces with wrapping navigation; merge
  matching workspaces and minimized restore destinations when a monitor leaves.
- Rebuild native Dwindle in stable order, splitting right then down; add Floating
  to the layout cycle and complete Fair's incomplete columns.
- Fix app icons and clicks using stock Waybar taskbars plus configurable workspace
  buttons. No Waybar patch, custom binary, build dependency, or package change.
- Define the nine Waybar workspace groups once in a configuration generator,
  check in its output for normal startup, and consolidate workspace styles.
- Tighten horizontal spacing between workspace labels, app icons, and bar groups.
- Preserve minimized/sticky/keep-on-top state across reloads, restore touchpad
  actions, add a Wayland-aware Rofi window chooser, and avoid duplicate startup apps.
- Add focused policy/state tests, disposable-window live checks, and selective
  desktop deployment with backups and rollback.
- Laptop validation: configuration checks, layout round trips with 1/2/3/5/9
  windows (including deliberate swaps and different focus/cursor positions),
  minimize/reload/restore, sticky/keep-on-top, magnification, per-monitor
  wrapping, and actual workspace/app icon clicks passed. Physical gestures,
  unplug/replug, and user acceptance remain pending; changes are not yet released.

- Make OpenCode files reusable by removing the fixed username, machine-specific
  guidance, concrete deck examples, and bytecode containing personal paths.

- Remove the competitive-programming agent and `/cp` command; retain the Java
  templates. Restore the writing profile as a required source.

- Rework OpenCode's shared instructions and the retained 18 agents, make Build the default,
  restrict Plan to analysis, and route commands to their intended specialists.
- Consolidate OpenCode permissions, use built-in LSP/formatter discovery, remove
  catalog URLs from skill discovery, and clarify MTG and writing workflows.
- Add `scripts/check-opencode.py` and an OpenCode configuration guide.
- Add password-free SSH inspection and working-tree snapshot transfer to the
  Arch test laptop using `scripts/laptop-dev.py`.
- Document separate laptop testing and `v1.2.x` release tags.
