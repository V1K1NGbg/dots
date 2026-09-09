#!/usr/bin/env bash
# Native scheduler and live-input behavior, isolated from the desktop and clocks.
set -euo pipefail
repo=$(cd -- "$(dirname -- "$0")/.." && pwd)
scratch=$(mktemp -d)
trap 'rm -rf -- "$scratch"' EXIT
export HOME=$scratch/home XDG_CONFIG_HOME=$scratch/config XDG_STATE_HOME=$scratch/state XDG_CACHE_HOME=$scratch/cache XDG_RUNTIME_DIR=$scratch/runtime
export TEST_LOG=$scratch/commands
mkdir -p "$HOME" "$scratch/bin"
for cmd in flock systemctl systemd-run; do
    printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >> "$TEST_LOG"\n' > "$scratch/bin/$cmd"
done
chmod +x "$scratch/bin/"*
export PATH=$scratch/bin:$PATH
clock=$repo/.config/rofi/modi/time.sh
state=$XDG_STATE_HOME/dots-utils/clocks.json
override=$XDG_CONFIG_HOME/systemd/user/dots-utils-clock.timer.d/deadline.conf
"$clock" add-timer 2h Later
"$clock" add-timer 1h Earlier
source "$repo/.config/rofi/modi/common.sh"
due=$(jq -r '[.items[].due]|min' "$state")
grep -Fq "OnCalendar=$(at_epoch "$due" '+%Y-%m-%d %H:%M:%S')" "$override"
grep -q 'restart --no-block dots-utils-clock.timer' "$TEST_LOG"
early=$(jq -r '.items[1].id' "$state")
"$clock" delete "$early"
due=$(jq -r '.items[0].due' "$state")
grep -Fq "OnCalendar=$(at_epoch "$due" '+%Y-%m-%d %H:%M:%S')" "$override"
"$clock" delete "$(jq -r '.items[0].id' "$state")"
grep -q 'disable --now dots-utils-clock.timer' "$TEST_LOG"
: > "$TEST_LOG"
"$clock" watch-start
[[ ! -s $TEST_LOG ]] || [[ $(cat "$TEST_LOG") == 9$'\n'-u\ 9 ]]
# Invalid live input does not create clocks; corrected input previews and saves.
printf '%s\n' '{"name":"input change","value":"2x"}' '{"name":"execute custom input","value":"2x"}' | bash "$repo/.config/rofi/modi/time.sh" live timer > "$scratch/invalid"
jq -es 'any(.[];.message|contains("Invalid duration"))' "$scratch/invalid" >/dev/null
jq -e '.items|length==0' "$state" >/dev/null
printf '%s\n' '{"name":"input change","value":"1.5m Tea"}' '{"name":"select entry","data":"once"}' | bash "$repo/.config/rofi/modi/time.sh" live timer > "$scratch/valid"
jq -es 'any(.[];.message|contains("00:01:30"))' "$scratch/valid" >/dev/null
jq -e '.items[0].label=="Tea"' "$state" >/dev/null
printf '%s\n' '{"name":"input change","value":"25:90 Wake"}' '{"name":"execute custom input","value":"25:90"}' | bash "$repo/.config/rofi/modi/time.sh" live alarm > "$scratch/alarm"
jq -es 'any(.[];.message|contains("Invalid time"))' "$scratch/alarm" >/dev/null
jq -e '.items|length==1' "$state" >/dev/null
printf 'PASS: native next-deadline scheduling, deletion, idle stopwatch, live previews and invalid input\n'
