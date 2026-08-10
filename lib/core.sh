#!/usr/bin/env bash

declare -ag PHASE_IDS=()
declare -Ag PHASE_LABEL=()
declare -ag TASK_IDS=()
declare -Ag TASK_LABEL=() TASK_PHASE=() TASK_CHECK=() TASK_ACTION=()
declare -Ag TASK_DEPS=() TASK_FLAGS=() TASK_SELECTED=() TASK_STATE=() TASK_REASON=()

DRY_RUN=${DRY_RUN:-0}
NONINTERACTIVE=${NONINTERACTIVE:-0}
STATE_ROOT=${XDG_STATE_HOME:-"$HOME/.local/state"}/dots
LOG_ROOT="$STATE_ROOT/logs"
CONFIRM_ROOT="$STATE_ROOT/confirmations"
BACKUP_ROOT="$STATE_ROOT/backups"
DESKTOP_PROFILE=${DESKTOP_PROFILE:-}

RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
CYAN=$'\033[0;36m'
BOLD=$'\033[1m'
DIM=$'\033[2m'
NC=$'\033[0m'

die() { printf '%sError:%s %s\n' "$RED" "$NC" "$*" >&2; exit 1; }
log() { printf '  %s▶%s %s\n' "$BLUE" "$NC" "$*"; }
success() { printf '  %s✓%s %s\n' "$GREEN" "$NC" "$*"; }
warn() { printf '  %s!%s %s\n' "$YELLOW" "$NC" "$*" >&2; }
command_exists() { command -v "$1" >/dev/null 2>&1; }
package_installed() { pacman -Qq "$1" >/dev/null 2>&1; }

valid_desktop_profile() { [[ $1 == awesome || $1 == hyprland ]]; }
desktop_profile_file() { printf '%s/desktop-profile\n' "$STATE_ROOT"; }
recorded_desktop_profile() {
  local profile_file profile
  profile_file=$(desktop_profile_file)
  [[ -r $profile_file ]] || return 1
  IFS= read -r profile <"$profile_file"
  valid_desktop_profile "$profile" || return 1
  printf '%s\n' "$profile"
}
record_desktop_profile() {
  valid_desktop_profile "$1" || die "invalid desktop profile: $1"
  if ((DRY_RUN)); then
    log "record desktop profile: $1"
  else
    mkdir -p "$STATE_ROOT"
    printf '%s\n' "$1" >"$(desktop_profile_file)"
  fi
}

read_manifest() {
  sed -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$/d' "$1"
}

profile_manifest() {
  local kind=$1 profile=${2:-$DESKTOP_PROFILE}
  valid_desktop_profile "$profile" || die "desktop profile is not selected"
  printf '%s/config/%s-%s.txt\n' "$DOTS_ROOT" "$kind" "$profile"
}

register_phase() {
  local id=$1 label=$2
  [[ -z ${PHASE_LABEL[$id]+x} ]] || die "duplicate phase: $id"
  PHASE_IDS+=("$id")
  PHASE_LABEL[$id]=$label
}

register_task() {
  local id=$1 phase=$2 label=$3 check=$4 action=$5 deps=${6:-} flags=${7:-}
  [[ -n ${PHASE_LABEL[$phase]+x} ]] || die "task $id uses unknown phase $phase"
  [[ -z ${TASK_LABEL[$id]+x} ]] || die "duplicate task: $id"
  declare -F "$check" >/dev/null || die "task $id has unknown check: $check"
  declare -F "$action" >/dev/null || die "task $id has unknown action: $action"
  TASK_IDS+=("$id")
  TASK_LABEL[$id]=$label
  TASK_PHASE[$id]=$phase
  TASK_CHECK[$id]=$check
  TASK_ACTION[$id]=$action
  TASK_DEPS[$id]=$deps
  TASK_FLAGS[$id]=$flags
  TASK_SELECTED[$id]=0
}

load_task_files() {
  local file
  for file in "$DOTS_ROOT"/tasks/*.sh; do
    # shellcheck disable=SC1090
    source "$file"
  done
  validate_registry
}

validate_registry() {
  local id dep
  for id in "${TASK_IDS[@]}"; do
    for dep in ${TASK_DEPS[$id]}; do
      [[ -n ${TASK_LABEL[$dep]+x} ]] || die "task $id depends on unknown task $dep"
      [[ $dep != "$id" ]] || die "task $id depends on itself"
    done
  done
  declare -A visiting=() visited=()
  for id in "${TASK_IDS[@]}"; do validate_dependency_branch "$id"; done
}

validate_dependency_branch() {
  local id=$1 dep
  [[ -z ${visited[$id]+x} ]] || return 0
  [[ -z ${visiting[$id]+x} ]] || die "dependency cycle detected at task: $id"
  visiting[$id]=1
  for dep in ${TASK_DEPS[$id]}; do validate_dependency_branch "$dep"; done
  unset "visiting[$id]"
  visited[$id]=1
}

has_flag() { [[ " ${TASK_FLAGS[$1]} " == *" $2 "* ]]; }
confirmed() { [[ -f "$CONFIRM_ROOT/$1.done" ]]; }
mark_confirmed() { mkdir -p "$CONFIRM_ROOT"; : >"$CONFIRM_ROOT/$1.done"; }

run() {
  if ((DRY_RUN)); then
    printf '  %sDRY%s' "$YELLOW" "$NC"
    printf ' %q' "$@"
    printf '\n'
    return 0
  fi
  "$@"
}

run_shell() {
  local command=$1
  if ((DRY_RUN)); then
    printf '  %sDRY%s %s\n' "$YELLOW" "$NC" "$command"
    return 0
  fi
  bash -o pipefail -c "$command"
}

prompt_continue() {
  local prompt=$1
  if ((NONINTERACTIVE)); then
    warn "manual input required: $prompt"
    return 2
  fi
  read -r -p "  $prompt [Enter to continue, q to cancel] " reply
  [[ ${reply:-} != q && ${reply:-} != Q ]]
}

render_template() {
  local source=$1 destination=$2 temp
  temp=$(mktemp)
  sed \
    -e "s|@@USER@@|$USER|g" \
    "$source" >"$temp"
  if ((DRY_RUN)); then
    printf '  %sDRY%s install %s -> %s\n' "$YELLOW" "$NC" "$source" "$destination"
  else
    sudo install -D -m 0644 "$temp" "$destination"
  fi
  rm -f "$temp"
}
