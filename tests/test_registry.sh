#!/usr/bin/env bash

set -Eeuo pipefail

[[ ${BASH_VERSINFO[0]} -ge 5 ]] || {
  printf 'SKIP: Bash 5 is required (found %s)\n' "$BASH_VERSION"
  exit 0
}

TEST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_TMP=$(mktemp -d)
trap 'rm -rf "$TEST_TMP"' EXIT
export HOME="$TEST_TMP/home"
mkdir -p "$HOME"
export DOTS_ROOT="$TEST_ROOT"
export XDG_STATE_HOME="$TEST_TMP/state"
export DESKTOP_PROFILE=hyprland

# shellcheck source=../lib/core.sh
source "$TEST_ROOT/lib/core.sh"
# shellcheck source=../lib/runner.sh
source "$TEST_ROOT/lib/runner.sh"

load_task_files

[[ ${#PHASE_IDS[@]} -eq 6 ]]
[[ ${#TASK_IDS[@]} -ge 32 ]]
[[ ${TASK_DEPS[ollama]} == docker ]]
[[ ${TASK_PHASE[dotfiles]} == dotfiles ]]
[[ ${TASK_DEPS[desktop-profile]} == "dotfiles picom" ]]

for profile in awesome hyprland; do
  DESKTOP_PROFILE=$profile
  mapfile -t profile_packages < <(read_packages)
  mapfile -t profile_dotfiles < <(manifest_entries)
  ((${#profile_packages[@]} > 70))
  ((${#profile_dotfiles[@]} > 10))
done

DESKTOP_PROFILE=hyprland
read_packages | grep -qx hyprland
read_packages | grep -qx wlrctl-git
! read_packages | grep -qx quickshell
! read_packages | grep -qx brightnessctl
! read_packages | grep -qx cliphist
! read_packages | grep -qx hyprshutdown
! read_packages | grep -qx upower
! read_packages | grep -qx awesome-git
manifest_entries | grep -qx .config/hypr
! manifest_entries | grep -qx .config/quickshell
! manifest_entries | grep -qx .config/awesome

DESKTOP_PROFILE=awesome
read_packages | grep -qx awesome-git
read_packages | grep -qx xorg-xinit
! read_packages | grep -qx hyprland
manifest_entries | grep -qx .config/awesome
! manifest_entries | grep -qx .config/hypr

if comm -12 \
  <(read_manifest "$TEST_ROOT/config/packages-awesome.txt" | sort) \
  <(read_manifest "$TEST_ROOT/config/packages-hyprland.txt" | sort) | grep -q .; then
  printf 'desktop package manifests overlap\n' >&2
  exit 1
fi
if comm -12 \
  <(read_manifest "$TEST_ROOT/config/dotfiles-awesome.txt" | sort) \
  <(read_manifest "$TEST_ROOT/config/dotfiles-hyprland.txt" | sort) | grep -q .; then
  printf 'desktop dotfile manifests overlap\n' >&2
  exit 1
fi

[[ -f "$TEST_ROOT/.config/hypr/hyprland.lua" ]]
[[ -f "$TEST_ROOT/.config/hypr/hypridle.conf" ]]
[[ -f "$TEST_ROOT/.config/hypr/hyprlock.conf" ]]
[[ -f "$TEST_ROOT/.config/hypr/hyprpaper.conf" ]]
[[ -f "$TEST_ROOT/.config/hypr/hyprsunset.conf" ]]
[[ -x "$TEST_ROOT/.config/hypr/scripts/screenshot" ]]
[[ -x "$TEST_ROOT/.config/hypr/scripts/keybinds" ]]
[[ ! -e "$TEST_ROOT/.config/quickshell" ]]
grep -Fxq '.config/hypr/wall.jpg' "$TEST_ROOT/.gitignore"
grep -Fq 'DOTS_ROOT/.config/awesome/wall.jpg' "$TEST_ROOT/tasks/30-dotfiles.sh"

clear_selection
select_task_csv dotfiles
for task in packages monocraft ohmybash dotfiles; do
  [[ ${TASK_SELECTED[$task]} == 1 ]]
done

register_phase test "Test"
check_failure_probe() { return 1; }
install_failure_probe() { false; printf 'must not run\n'; }
register_task failure-probe test "Failure probe" check_failure_probe install_failure_probe "" ""
preflight_runtime
if run_task failure-probe >/dev/null 2>&1; then
  printf 'runner incorrectly accepted a failed command\n' >&2
  exit 1
fi
[[ ${TASK_STATE[failure-probe]} == failed ]]

DRY_RUN=1
clear_selection
select_with_dependencies desktop-profile
run_selection >/dev/null
for task in packages monocraft ohmybash dotfiles picom desktop-profile; do
  [[ ${TASK_SELECTED[$task]} == 0 ]]
  [[ ${TASK_STATE[$task]} == done ]]
done

printf 'registry, profiles, and runner tests passed (%d tasks)\n' "${#TASK_IDS[@]}"
