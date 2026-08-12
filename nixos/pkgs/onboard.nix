{
  coreutils,
  dconf,
  findutils,
  gnugrep,
  writeShellApplication,
}:

writeShellApplication {
  name = "dots-onboard";
  runtimeInputs = [
    coreutils
    dconf
    findutils
    gnugrep
  ];
  text = ''
    set -u

    pass=0
    action=0

    check_command() {
      label="$1"
      command="$2"
      if command -v "$command" >/dev/null 2>&1; then
        printf '  [ok]     %s\n' "$label"
        pass=$((pass + 1))
      else
        printf '  [action] %s (missing command: %s)\n' "$label" "$command"
        action=$((action + 1))
      fi
    }

    check_path() {
      label="$1"
      path="$2"
      if [[ -e "$path" ]]; then
        printf '  [ok]     %s\n' "$label"
        pass=$((pass + 1))
      else
        printf '  [action] %s (missing: %s)\n' "$label" "$path"
        action=$((action + 1))
      fi
    }

    printf 'dots migration check\n\n'
    printf 'Core desktop\n'
    check_command 'Awesome window manager' awesome
    check_command 'Picom animation fork' picom
    check_command 'Fusuma gesture daemon and bundled plugins' fusuma
    check_command 'Firefox' firefox
    check_command 'Nemo' nemo
    check_command 'VS Code' code
    check_command 'OpenCode' opencode
    check_command 'Spotify' spotify
    check_command 'pCloud' pcloud

    printf '\nWritable application state\n'
    check_path 'KeePassXC preferences seed' "$HOME/.config/keepassxc/keepassxc.ini"
    check_path 'BetterDiscord plugin settings directory' "$HOME/.config/BetterDiscord/plugins"
    check_path 'Private Awesome weather values' "$HOME/.local/state/dots/awesome-const.lua"

    printf '\nManual account/device steps\n'
    printf '  [action] Enroll fingerprints: fprintd-enroll\n'
    printf '  [action] Authenticate GitHub: gh auth login\n'
    printf '  [action] Import WireGuard: nmcli connection import type wireguard file /path/to/profile.conf\n'
    printf '  [action] Disable VPN autoconnect unless intended: nmcli connection modify NAME connection.autoconnect no\n'
    printf '  [action] Sign in to Firefox and restore Vimium/Bonjourr exports plus required cookie exceptions\n'
    printf '  [action] Sign in to VS Code and wait for Settings Sync to finish\n'
    printf '  [action] Sign in to Discord, Spotify, Steam and pCloud\n'
    printf '  [action] In pCloud, restore the PC sync and BackUp backup mappings\n'
    printf '  [action] Install BetterDiscord into the Nix Discord client if still wanted\n'
    printf '  [action] Import CopyQ: copyq importData ~/.local/share/dots/imports/copyq.cpq\n'
    printf '  [action] Review/apply Nemo settings:\n'
    printf '           dconf load /org/nemo/ < ~/.local/share/dots/imports/nemo_config\n'
    printf '  [action] Add Flathub and install non-nixpkgs apps only after reviewing them\n'
    printf '  [action] Restore NVM only if a project needs a Node version unavailable from the pinned system\n'
    printf '  [action] Restore Ollama models/volume before changing its backend\n'
    printf '  [action] Verify Fusuma is running: pgrep -a fusuma\n'
    printf '  [action] If gestures fail, stop the daemon and inspect devices with: fusuma -l\n'
    printf '  [action] Confirm SendkeyExecutor is enabled: fusuma --show-config -c ~/.config/fusuma/config.yml\n'
    printf '  [action] Check services: systemctl --failed && systemctl --user --failed\n'

    printf '\nOptional Hyprland trial\n'
    printf '  Build without switching: nix build .#checks.x86_64-linux.hyprland-system\n'
    printf '  Activate when ready: sudo nixos-rebuild boot --flake .#dots-hyprland\n'
    printf '  Revert default: sudo nixos-rebuild boot --flake .#dots\n'

    printf '\nSummary: %d automatic checks passed; %d automatic checks need attention.\n' "$pass" "$action"
  '';
  meta.description = "Post-install checklist for the dots NixOS migration";
}
