# Changelog

## Unreleased

- Open the Rofi launcher tile menu without a highlighted item. The first arrow
  selects the first tile; subsequent arrows navigate normally. Enter is inactive
  before navigation; letter shortcuts, Tab and mouse clicks remain available.
  Live checks passed for initial Enter/Escape, all four first-arrow keys,
  subsequent navigation and letter/Tab shortcuts; initial screenshot reviewed.
  Applied with backup `~/dots-dev/rofi-selection-backup.x3i3ceb3`.

- Remove the workspace-travel experiments and restore direct workspace selection
  and the original 550ms fluid timing. Old desktop windows slide down; new
  desktop windows rise from below. Keep the three-layout cycle (Dwindle, Tile,
  Fair), migration of saved Floating layouts and the Vimium configuration.
  Regression tests, config validation and live direct-switch/reversal/wrap
  checks passed on eDP-1. Applied with backup
  `~/dots-dev/workspace-backup.2bup64rt`; original focus restored.
  Visual motion and external-display checks remain unverified.

- Add native first-result Vimium shortcuts: g1 for Google's I'm Feeling Lucky
  and d1 for DuckDuckGo's first result. Skip other engines instead of substituting
  site-scoped web searches. Document usage and import instructions in VIMIUM.md;
  preserve existing engines and other settings. JSON, keyword uniqueness and
  query encoding checks passed; browser import and live redirects are untested.

- Reduce visualizer delay: raise CAVA from 30 to 60fps, lower its noise
  reduction to 20 and disable its once-per-second wakeup after silence. Draw
  new peaks immediately upon input; replace 45ms attack/110ms release with
  immediate attack/35ms release. Restore the earlier small corner tips.
  Bash continues to control the pipeline; Cairo drawing remains in the native
  helper. Strict build, immediate-attack/normalization/corner tests, live audio,
  shared capture, repeated toggles and geometry checks passed. Corner capture
  reviewed. Applied with backup `~/dots-dev/visualizer-backup.wVczxd3h`.
  Perceived end-to-end audio/display synchronization is not instrumented.

- Try a native GTK/Cairo layer-shell visualizer in place of Waybar text glyphs.
  Draw a continuous antialiased spectrum with spatial interpolation, temporal
  smoothing and pixel-based corner tapering. Share one normalized CAVA capture
  across all displays. Bash still controls compilation, startup and Super+G;
  retain the old bars as an environment-selectable fallback. Explicitly list
  native build dependencies. Strict-warning compilation, native normalization,
  parser/corner tests and live audio, three toggle cycles, capture cleanup,
  four 16px surfaces per display and unchanged focus/reserved space passed.
  Curve/corner screenshots reviewed. Applied with backup
  `~/dots-dev/visualizer-backup.dM6SSFjF`; left running. No release tag created.
- Bring CAVA's tapered tips closer to the corners with a four-column taper
  ending at one glyph step, and add 1px separation between columns. Recalculate
  column count and distribute remaining spacing to retain the full edge span.
  Applied with backup `~/dots-dev/visualizer-backup.BayJHtAG`. Offline sizing
  and taper checks, live music/toggle/cleanup checks, and corner/full-edge
  screenshot review passed. Left running.

- Increase Hyprland outer gaps from 18px to 24px and inner gaps from 12px to
  14px. Replace the visualizer's shortened sides with full-length surfaces and
  a symmetric six-column amplitude taper at every corner. Offline full-scale
  taper tests and live music/toggle/geometry checks passed; corner and desktop
  screenshots reviewed. Applied with backups `~/dots-dev/gaps-backup.XEAG0pPT`
  and `~/dots-dev/visualizer-backup.TADN3ko2`. Left running.

- Increase the Waybar clocks from 10pt to 11pt while preserving the 30px bar
  height. Let the visualizer's full-width top/bottom strips own the corners;
  inset each side by 16px at both ends and match its measured spectrum length.
  Applied with backups `~/dots-dev/clock-size-backup.UKtQGlkK` and
  `~/dots-dev/visualizer-backup.pacJYh3P`. Clock/corner screenshot reviewed;
  live checks on both displays confirmed non-overlapping surfaces, unchanged
  reserved space/focus, music response and clean repeated toggles.

- Restore the original slim 16px cyan visualizer without glow or separated
  columns. Fill each available edge using measured Pango font advances and
  subpixel spacing; interpolate 64 CAVA bands instead of capping line length.
  Normalize 16-bit amplitude values before glyph quantization so system and
  Spotify volume changes retain similar spectrum heights. Use one persistent
  awk process per Bash stream; silence remains blank. Explicitly list Pango
  for its measurement tool. Applied with backup
  `~/dots-dev/visualizer-backup.PQV9YMaT`. Offline proportional-level, release,
  silence and sizing tests passed; live music, repeated toggles, cleanup and
  16px geometry checks passed. Measured 2559.98px text width on a 2560px edge.
  Quarter-volume system/Spotify/both tests retained mean peaks 8, 8 and 7.85
  out of 8; restored original volumes. No release tag created.

- Refine the audio visualizer for both occupied and empty desktops: broader
  separated columns, clear corners, softer cyan and a subtle glow. Increase
  bottom-layer surfaces to 48px so empty workspaces reveal taller spectra;
  application windows naturally cover the inner peaks, keeping the effect
  visible in the existing outer gaps. Reduce column counts to fit live font
  metrics. Applied with backups `visualizer-backup.4Qybf8Gl` and
  `visualizer-backup.xtRxi88N` under `~/dots-dev/`. Reviewed screenshots with
  Spotify open and an empty laptop display. Bash checks and live music,
  three toggle cycles, capture cleanup, 48px geometry, unchanged focus and
  reserved-space checks passed. Left running; no release tag created.

- Recognize both `pcloud` and `pcloud.bin` during Hyprland autostart so a second
  invocation cannot reopen the main window. The laptop's existing start-minimized
  preference is enabled and was preserved. A fresh compositor launch and repeated
  autostart both remained windowless in live checks; fresh login is untested.
- Increase watermark text from 10pt to 15pt (50% larger). Applied selectively
  with the pCloud fix; backup: `~/dots-dev/pcloud-watermark-backup.1nsj6ku7`.
  Live surfaces grew from 34px to 50px on both displays; the laptop crop was
  visually checked for fit and readability.

- Fix Spotify autostart when login precedes DNS readiness by launching the
  installed client with `--skip-update`; normal launches can still check updates.
  Start Waybar directly from Hyprland, using a PID-validated helper for readiness,
  visibility and signals targeted to the main bar. No Waybar service is used;
  the temporary service was backed up and removed from the laptop at the user's
  request. Direct startup, restart and bound show/hide actions passed live.
  Removal backup: `~/dots-dev/startup-fixes-backup.ke3cw1gd`.
  Spotify's skip-update path passed; fresh login during DNS failure is untested.

- Add an on-demand Hyprland audio visualizer toggled with Super+G. Bash converts
  CAVA streams into cyan spectra in four 16px outer-gap Waybar strips per
  monitor, below application windows, with click-through and no reserved space.
  Use a separate Waybar instance, ignoring top-bar toggle signals, with
  session-owned systemd cleanup and serialized toggles. Add only CAVA to the
  installer; no Python visualizer or Python tests. Offline Bash frame handling,
  scaled/rotated output sizing, config and mocked toggle checks passed.
  Activated on the laptop on 2026-09-10 with backups in
  `~/dots-dev/visualizer-backup.DD0zfEkG` and `visualizer-backup.bO5uxuw3`.
  Live music, registered Super+G binding, three stop/start cycles, CAVA/surface
  cleanup, four 16px strips per display, unchanged focus/reserved space and
  narrow edge screenshot checks passed. Fix GTK's 17px minimum by using an
  11px font; replace per-bar regex parsing with byte-wise Bash substitutions.
  Add reusable Bash selective deployment and live checks. Physical key/input,
  real silence, fullscreen, live scaling/hotplug, top-bar toggling and logout
  checks remain pending. No release tag created.

- Add a faint lower-right “Activate Linux” desktop watermark using the existing
  Waybar process. Its transparent bottom layer stays below application windows,
  passes pointer input through, reserves no space and ignores top-bar toggles.
  No new package or managed application window. Update the config generator and
  adapt the taskbar startup check for multiple layer surfaces.
  Activated with backups in `~/dots-dev/desktop-effects-backup.hbkad_vp`.
  Live checks confirmed bottom-layer placement on both outputs, zero reserved
  space and persistence through top-bar toggles. Visually inspected the laptop
  panel crop. Fresh Waybar workspace membership check passed. Physical pointer
  click-through, reconnect and fresh-login checks remain pending.

- Add Minecraft villager sounds for Hyprland battery low (20%, deny1), battery
  critical (10%, hurt1), and successful screenshots (accept1, quieter).
  Both Super+P and Print use a capture helper that stays silent on cancellation
  or capture failure. Add a session-owned systemd battery timer, with 30-second
  checks, notifications and threshold repeat suppression; align Waybar colors
  to 20%/10%. Bundle the audio and source links. Rofi timers and alarms use
  the shared sound helper with their original idle1 sound and volume, preserving
  custom sound overrides and the existing repeating alert behavior. Move the
  original timer asset alongside the other sounds in `hypr/sounds/` and include
  it in selective Rofi deployment.
  Activated with the desktop-effects backup above. Arch fixture checks passed
  for battery thresholds/repeats/charging and screenshot failures. Real PipeWire
  playback passed for all new cues; the native timer passed delivery, action
  dismissal and close dismissal with cleanup. Real screenshot selection
  cancellation and capture into Swappy (fixed test region) passed. Battery
  units validate and the periodic check exits successfully. Physical audibility
  and manual shortcut confirmation remain pending; battery discharge and fresh
  login were not forced. No release tag created.

- Set the current Bonjourr backup's custom CSS to use local Monocraft throughout
  the page, with a monospace fallback. Other backup settings are preserved.
  JSON validation passed; live browser rendering remains untested.

- Restyle Vimium hints and its search/tab picker with charcoal, cyan and
  Monocraft. Limit normal-mode shortcuts to the requested navigation, link,
  search and tab controls; t opens a new tab and T restores the latest closed
  tab. Keep 12 search engines,
  removing Scholar, Wolfram Alpha, MDN, Stack Overflow and all direct launchers.
  Add a shortcut reference. Local Vimium 2.2.1 parser and query-encoding checks
  passed; browser visuals and laptop activation remain untested off-network.

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
