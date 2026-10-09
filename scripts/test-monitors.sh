#!/usr/bin/env bash
# Exercise the entry point without a compositor or a notification daemon.
set -euo pipefail

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
scratch=$(mktemp -d)
trap 'rm -rf -- "$scratch"' EXIT
export XDG_RUNTIME_DIR=$scratch XDG_CONFIG_HOME=$scratch/config
export HYPRLAND_INSTANCE_SIGNATURE=test MONITOR_TEST_CASE=success
mkdir -p "$XDG_CONFIG_HOME"
cat > "$scratch/monitors.json" <<'JSON'
[
  {"id":0,"name":"eDP-1","description":"Panel","width":1920,"height":1080,"refreshRate":60,"scale":1,"x":0,"y":0,"mirrorOf":"none"},
  {"id":1,"name":"DP-1","description":"Microstep MSI MAG272QR CA8A190020273","width":2560,"height":1440,"refreshRate":144,"scale":1,"x":-2560,"y":0,"mirrorOf":"none"}
]
JSON

hyprctl() {
    if [[ $1 == monitors ]]; then
        if [[ $MONITOR_TEST_CASE == query-error ]]; then
            printf 'invalid monitor response\n'
        else
            cat "$XDG_RUNTIME_DIR/monitors.json"
        fi
    elif [[ $1 == dispatch ]]; then
        printf '%s\n' "$2" >> "$XDG_RUNTIME_DIR/dispatches"
        if [[ $MONITOR_TEST_CASE == dispatch-error ]]; then
            printf 'test dispatch failure\n' >&2
            return 7
        fi
        printf 'ok\n'
    else
        return 1
    fi
}
notify-send() { printf '%s\n' "$*" >> "$XDG_RUNTIME_DIR/notifications"; }
# These tests are sequential and use already settled display positions.
flock() { :; }
sleep() { :; }
export -f hyprctl notify-send flock sleep

run_monitors() {
    bash "$repo/config/.config/hypr/monitors/monitors.sh" --auto "$@" > "$scratch/output" 2>&1
}

run_monitors
[[ ! -e $scratch/notifications ]]
[[ $(wc -l < "$scratch/dispatches") -eq 2 ]]
grep -q 'dots.set_primary' "$scratch/dispatches"
cp "$scratch/dots-monitors-test" "$scratch/previous"
run_monitors
[[ $(wc -l < "$scratch/dispatches") -eq 2 ]]

for MONITOR_TEST_CASE in query-error dispatch-error; do
    : > "$scratch/notifications"
    rc=0
    run_monitors --reload || rc=$?
    [[ $rc != 0 ]]
    [[ $(wc -l < "$scratch/notifications") -eq 1 ]] || { echo 'Expected one failure notification' >&2; exit 1; }
    grep -q 'Display configuration failed' "$scratch/notifications"
    cmp "$scratch/previous" "$scratch/dots-monitors-test"
    if [[ $MONITOR_TEST_CASE == query-error ]]; then
        grep -q 'parse error' "$scratch/output"
    else
        [[ $rc == 7 ]]
        grep -q 'test dispatch failure' "$scratch/output"
    fi
done

echo 'Monitor startup checks passed'
