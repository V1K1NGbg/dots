# dots

Dotfiles and installer for my Arch Linux laptop.

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
./backup.sh          # preview
./backup.sh --apply  # update this repository
```

Tasks are in `tasks/`. Add a check function, an install function, and one
`register_task` line. Packages and copied paths are listed in `config/`.
