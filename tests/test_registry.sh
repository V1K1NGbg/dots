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

# shellcheck source=../lib/core.sh
source "$TEST_ROOT/lib/core.sh"
# shellcheck source=../lib/runner.sh
source "$TEST_ROOT/lib/runner.sh"

load_task_files

[[ ${#PHASE_IDS[@]} -eq 6 ]]
[[ ${#TASK_IDS[@]} -ge 30 ]]
[[ ${TASK_DEPS[ollama]} == docker ]]
[[ ${TASK_PHASE[dotfiles]} == dotfiles ]]

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

printf 'registry and runner tests passed (%d tasks)\n' "${#TASK_IDS[@]}"
