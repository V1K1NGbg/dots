# Changelog

## Unreleased

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
