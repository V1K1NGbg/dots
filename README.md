# dots

Dotfiles and profile-aware installer for my Arch Linux laptop. The desktop can
be installed as either Hyprland/Wayland or Awesome/X11; only one profile is
deployed at a time. The Hyprland profile is a minimal, barless Wayland version
of the Awesome setup, with the same visual identity and keyboard workflow.

```bash
./install.sh
```

Other useful commands:

```bash
./install.sh --list
./install.sh --status
./install.sh --task TASK_ID
./install.sh --phase PHASE_ID
./install.sh --dry-run
./install.sh --desktop hyprland
./install.sh --desktop awesome
./install.sh --switch-desktop hyprland
./backup.sh          # preview
./backup.sh --apply  # update this repository
```

Tasks are in `tasks/`. Add a check function, an install function, and one
`register_task` line. Shared and desktop-specific package/dotfile manifests are
listed separately in `config/`.
