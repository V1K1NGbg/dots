# dots

Arch Linux + Hyprland setup with Rofi.

1. Boot the Arch ISO USB in UEFI mode. In the boot menu, press `e`, append `copytoram=y` to the kernel options, and boot. Lastly, connect to Wi-Fi:

```sh
iwctl station wlan0 connect "SSID"
```

2. Clone and bootstrap (erases the selected disk):

```sh
pacman -Sy git
git clone https://github.com/V1K1NGbg/dots.git
cd dots
sudo bash bootstrap.sh
```

3. After reboot, run as your normal user (NO SUDO):

```sh
cd dots
bash install.sh
```

## Code configuration

The installer uses Arch's [`code` package](https://archlinux.org/packages/extra/x86_64/code/)
and the `code` command. Editor configuration lives in the repository alongside
the other dotfiles:

- `config/.config/Code - OSS/User/`: settings, keybindings, tasks, snippets,
  prompts, MCP/language-model configuration and profile files, when configured.
- `config/.config/Code - OSS/dots-profiles.json`: profile registrations and
  extension versions. Multiple installed versions are reduced to the newest.
- `User/globalStorage/dots-state.json` (also inside named profiles): UI layout,
  extension enablement and extension-declared synced preferences, as readable JSON.
- `config/.vscode-oss/argv.json`: launcher preferences without the machine's
  crash-report identifier.

To refresh these files from your local VS Code after Settings Sync finishes:

```sh
python3 backup-vscode.py
```

Despite its original filename, this script now exports deployable configuration.
It reads the local VS Code installation without launching it. On macOS it uses
`~/Library/Application Support/Code`; on Linux it uses
`${XDG_CONFIG_HOME:-$HOME/.config}/Code`. Extension metadata comes from
`~/.vscode/extensions`. Override `--user-data-dir` and `--extensions-dir` for
Insiders or a custom installation. A previous generated configuration is retained
under Git-ignored `backups/vscode-config-TIMESTAMP/` before replacement.

Future installation needs no Settings Sync login or profile import:

1. Run **Copy dotfiles** in `install.sh`. The editor files are copied and any
   existing configuration is backed up through the normal dotfile installation.
2. With Code closed, run **Set up Code**. This registers saved profiles,
   installs the saved extensions using `code`, and restores UI and enablement
   preferences into Code's native state database. Existing unrelated state
   is preserved. Failed extension installs leave the task incomplete.

Extension downloads require network access and availability in Code's
configured registry. To use a compatible local VSIX instead, put it below
`config/.config/Code - OSS/vsix/` and replace its entry in `dots-profiles.json`
with `vsix/filename.vsix`. Copy dotfiles again before retrying setup.
[The CLI supports extension versions, VSIX files and named profiles.](https://code.visualstudio.com/docs/configure/command-line#_working-with-extensions)

This export contains configuration, not caches, authentication databases,
machine IDs, workspace/session history, project files or remote-host data.
External fonts/tools and files referenced by settings still need to exist on the
target machine. Plaintext credentials explicitly placed in settings or MCP files
remain in those files; review config changes before publishing them.
