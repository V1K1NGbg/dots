#!/usr/bin/env bash

set -uo pipefail

if ((BASH_VERSINFO[0] < 5)); then
  printf 'Error: this installer requires Bash 5 or newer (found %s).\n' "$BASH_VERSION" >&2
  exit 1
fi

DOTS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTS_ROOT

# shellcheck source=lib/core.sh
source "$DOTS_ROOT/lib/core.sh"
# shellcheck source=lib/runner.sh
source "$DOTS_ROOT/lib/runner.sh"
# shellcheck source=lib/ui.sh
source "$DOTS_ROOT/lib/ui.sh"

load_task_files

usage() {
  cat <<'EOF'
Usage: ./install.sh [option]

Without options, opens the interactive installer.

  --list                 List phases, tasks, dependencies, and status
  --status               Refresh and print status without making changes
  --task ID[,ID...]      Run one or more tasks (dependencies are included)
  --phase ID             Run every unfinished task in a phase
  --desktop PROFILE      Use the awesome or hyprland desktop profile
  --switch-desktop NAME  Install NAME, then back up and remove the inactive profile
  --dry-run              Print commands without executing them
  --non-interactive      Never open GUI programs or wait for prompts
  --help                 Show this help
EOF
}

main() {
  local mode="tui" task_arg="" phase_arg="" requested_profile=""

  while (($#)); do
    case "$1" in
      --list) mode="list" ;;
      --status) mode="status" ;;
      --task)
        [[ $# -ge 2 ]] || die "--task requires an ID"
        mode="run"
        task_arg="$2"
        shift
        ;;
      --phase)
        [[ $# -ge 2 ]] || die "--phase requires an ID"
        mode="run"
        phase_arg="$2"
        shift
        ;;
      --desktop)
        [[ $# -ge 2 ]] || die "--desktop requires awesome or hyprland"
        requested_profile=$2
        shift
        ;;
      --switch-desktop)
        [[ $# -ge 2 ]] || die "--switch-desktop requires awesome or hyprland"
        mode="switch"
        requested_profile=$2
        shift
        ;;
      --dry-run) DRY_RUN=1 ;;
      --non-interactive) NONINTERACTIVE=1 ;;
      --help|-h) usage; return 0 ;;
      *) die "unknown argument: $1" ;;
    esac
    shift
  done

  preflight_runtime
  resolve_desktop_profile "$requested_profile" "$mode"

  case "$mode" in
    list|status)
      print_status_table
      ;;
    run)
      clear_selection
      if [[ -n "$phase_arg" ]]; then
        select_phase "$phase_arg"
      else
        select_task_csv "$task_arg"
      fi
      run_selection
      ;;
    switch)
      switch_desktop_profile
      ;;
    tui)
      run_tui
      ;;
  esac
}

resolve_desktop_profile() {
  local requested=${1:-} mode=${2:-tui} saved="" reply=""
  [[ -z $requested ]] || valid_desktop_profile "$requested" ||
    die "desktop profile must be awesome or hyprland"

  saved=$(recorded_desktop_profile 2>/dev/null || true)
  if [[ -n $requested ]]; then
    DESKTOP_PROFILE=$requested
  elif [[ -n $saved ]]; then
    DESKTOP_PROFILE=$saved
  elif [[ $mode == list || $mode == status ]]; then
    DESKTOP_PROFILE=hyprland
  elif ((NONINTERACTIVE)); then
    die "select a desktop with --desktop awesome|hyprland"
  else
    read -r -p 'Desktop profile [hyprland/awesome] (hyprland): ' reply
    DESKTOP_PROFILE=${reply:-hyprland}
    valid_desktop_profile "$DESKTOP_PROFILE" || die "desktop profile must be awesome or hyprland"
  fi
  export DESKTOP_PROFILE
}

switch_desktop_profile() {
  local previous inactive answer stamp path source backup_path package
  local -a installed=()
  previous=$(recorded_desktop_profile 2>/dev/null || true)
  if [[ $DESKTOP_PROFILE == hyprland ]]; then
    inactive=awesome
  else
    inactive=hyprland
  fi

  if [[ $previous == "$DESKTOP_PROFILE" ]]; then
    if profile_artifacts_present "$inactive"; then
      warn "found stale $inactive profile artifacts; they will be retired"
      previous=$inactive
    else
      success "$DESKTOP_PROFILE is already the active desktop profile"
      return 0
    fi
  elif [[ -z $previous ]] && profile_artifacts_present "$inactive"; then
    previous=$inactive
    warn "detected an existing $inactive profile without a profile marker"
  fi
  if ((NONINTERACTIVE)) && ((DRY_RUN == 0)); then
    die "desktop switching requires interactive confirmation"
  fi
  if [[ -n $previous ]] && ((DRY_RUN == 0)); then
    printf 'Switch desktop from %s to %s? The old profile will be backed up and removed. [y/N] ' \
      "$previous" "$DESKTOP_PROFILE"
    read -r answer
    [[ $answer == y || $answer == Y ]] || die "desktop switch cancelled"
  fi

  clear_selection
  select_with_dependencies desktop-profile
  run_selection || return $?

  [[ -n $previous ]] || return 0
  stamp=$(date +%Y%m%d-%H%M%S)
  while IFS= read -r path; do
    [[ $path != /* && $path != *'..'* ]] || die "unsafe profile path: $path"
    source="$HOME/$path"
    [[ -e $source || -L $source ]] || continue
    backup_path="$BACKUP_ROOT/$stamp/profile-switch/$path"
    run mkdir -p "$(dirname "$backup_path")"
    run cp -a "$source" "$backup_path"
    run rm -rf -- "$source"
  done < <(read_manifest "$(profile_manifest dotfiles "$previous")")

  while IFS= read -r package; do
    package_installed "$package" && installed+=("$package")
  done < <(read_manifest "$(profile_manifest packages "$previous")")
  ((${#installed[@]} == 0)) || run paru -Rns "${installed[@]}"
  success "retired $previous; backup: $BACKUP_ROOT/$stamp/profile-switch"
}

profile_artifacts_present() {
  local profile=$1 path package
  while IFS= read -r path; do
    [[ $path != /* && $path != *'..'* ]] || die "unsafe profile path: $path"
    [[ -e "$HOME/$path" || -L "$HOME/$path" ]] && return 0
  done < <(read_manifest "$(profile_manifest dotfiles "$profile")")
  while IFS= read -r package; do
    package_installed "$package" && return 0
  done < <(read_manifest "$(profile_manifest packages "$profile")")
  return 1
}

main "$@"
