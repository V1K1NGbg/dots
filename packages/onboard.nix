{ pkgs }:
let
  importRoot = ../assets/imports;
in
pkgs.writeShellApplication {
  name = "onboard";
  runtimeInputs = with pkgs; [
    coreutils
    findutils
    gnugrep
    gnused
    gawk
    shadow
    fprintd
    gh
    networkmanager
    discord
    spotify
    vscode
    copyq
    firefox
    pcloud
  ];

  text = ''
    state_root="''${XDG_STATE_HOME:-$HOME/.local/state}/nixfwbtw/onboarding"
    config_root="''${XDG_CONFIG_HOME:-$HOME/.config}/nixfwbtw/private"
    steps=(password fingerprint github wireguard pcloud discord spotify vscode copyq firefox)
    mkdir -p "$state_root"

    is_manual_step() {
      case "$1" in
        pcloud|discord|spotify|vscode|copyq|firefox) return 0 ;;
        *) return 1 ;;
      esac
    }

    marker() { printf '%s/%s' "$state_root" "$1"; }
    marked() { [[ -f $(marker "$1") ]]; }
    mark() {
      printf 'confirmed-at=%(%FT%TZ)T\n' -1 >"$(marker "$1")"
      chmod 0600 "$(marker "$1")"
    }

    mode_is_0600() {
      [[ -f $1 ]] && [[ $(stat -c '%a' "$1") == 600 ]]
    }

    wireguard_name() {
      basename -- "$config_root/wireguard.conf" .conf
    }

    check_step() {
      case "$1" in
        password)
          passwd -S "$USER" 2>/dev/null | awk '$2 == "P" { found=1 } END { exit !found }'
          ;;
        fingerprint)
          fprintd-list "$USER" 2>/dev/null | grep -q 'finger'
          ;;
        github)
          gh auth status >/dev/null 2>&1
          ;;
        wireguard)
          mode_is_0600 "$config_root/wireguard.conf" &&
            [[ $(nmcli -g connection.type connection show "$(wireguard_name)" 2>/dev/null) == wireguard ]] &&
            [[ $(nmcli -g connection.autoconnect connection show "$(wireguard_name)" 2>/dev/null) == no ]]
          ;;
        pcloud|discord|spotify|vscode|copyq|firefox)
          marked "$1"
          ;;
        *) return 2 ;;
      esac
    }

    show_status() {
      local step kind
      for step in "''${steps[@]}"; do
        if is_manual_step "$step"; then kind=manual; else kind=check; fi
        if check_step "$step"; then
          printf 'pass    %-16s (%s)\n' "$step" "$kind"
        else
          printf 'pending %-16s (%s)\n' "$step" "$kind"
        fi
      done
    }

    confirm_manual() {
      local step=$1 prompt=$2 answer
      printf '%s\n' "$prompt"
      read -r -p "Mark $step complete? Type yes: " answer
      [[ $answer == yes ]] || {
        printf '%s was not marked complete.\n' "$step"
        return 1
      }
      mark "$step"
    }

    run_step() {
      local step=$1 private name
      case "$step" in
        password)
          passwd
          ;;
        fingerprint)
          fprintd-enroll "$USER"
          ;;
        github)
          gh auth login
          ;;
        wireguard)
          private="$config_root/wireguard.conf"
          mode_is_0600 "$private" || {
            printf 'error: create %s with mode 0600 first.\n' "$private" >&2
            return 1
          }
          name=$(wireguard_name)
          if ! nmcli -g connection.type connection show "$name" 2>/dev/null | grep -qx wireguard; then
            nmcli connection import type wireguard file "$private"
          fi
          nmcli connection modify "$name" connection.autoconnect no
          nmcli connection down "$name" >/dev/null 2>&1 || true
          ;;
        pcloud)
          if command -v pcloud >/dev/null 2>&1; then
            pcloud >/dev/null 2>&1 &
          fi
          confirm_manual pcloud 'Log in to pCloud and configure the required sync folders.'
          ;;
        discord)
          discord >/dev/null 2>&1 &
          confirm_manual discord \
            'Log in to Discord and install/verify BetterDiscord. Its configuration is already declarative.'
          ;;
        spotify)
          spotify >/dev/null 2>&1 &
          confirm_manual spotify 'Log in to Spotify and disable song-change notifications.'
          ;;
        vscode)
          code >/dev/null 2>&1 &
          confirm_manual vscode 'Sign in to VS Code and wait for Settings Sync to finish.'
          ;;
        copyq)
          copyq >/dev/null 2>&1 &
          confirm_manual copyq 'In CopyQ, import ${importRoot}/copyq.cpq and configure the window-under-mouse shortcut.'
          ;;
        firefox)
          firefox >/dev/null 2>&1 &
          confirm_manual firefox \
            'Sync Firefox, then import ${importRoot}/vimium-options.json and ${importRoot}/bonjourr.json.'
          ;;
        *)
          printf 'error: unknown step: %s\n' "$step" >&2
          return 2
          ;;
      esac

      if check_step "$step"; then
        printf 'pass: %s\n' "$step"
      else
        printf 'warning: %s still does not pass its status check.\n' "$step" >&2
        return 1
      fi
    }

    usage() {
      printf 'usage: onboard status | onboard run <step>\n'
      printf 'steps: %s\n' "''${steps[*]}"
    }

    case "''${1:-}" in
      status)
        [[ $# == 1 ]] || { usage >&2; exit 2; }
        show_status
        ;;
      run)
        [[ $# == 2 ]] || { usage >&2; exit 2; }
        run_step "$2"
        ;;
      *)
        usage >&2
        exit 2
        ;;
    esac
  '';
}
