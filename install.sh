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
  --dry-run              Print commands without executing them
  --non-interactive      Never open GUI programs or wait for prompts
  --help                 Show this help
EOF
}

main() {
  local mode="tui" task_arg="" phase_arg=""

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
      --dry-run) DRY_RUN=1 ;;
      --non-interactive) NONINTERACTIVE=1 ;;
      --help|-h) usage; return 0 ;;
      *) die "unknown argument: $1" ;;
    esac
    shift
  done

  preflight_runtime

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
    tui)
      run_tui
      ;;
  esac
}

main "$@"
