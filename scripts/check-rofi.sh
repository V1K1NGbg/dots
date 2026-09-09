#!/usr/bin/env bash
# Portable behavior checks. Desktop commands are stubbed; no session is changed.
set -euo pipefail
repo=$(cd -- "$(dirname -- "$0")/.." && pwd)
for file in "$repo"/.config/rofi/*.sh "$repo"/.config/rofi/modi/*.sh "$repo"/.config/rofi/icon-gen/*.sh "$repo"/scripts/*rofi*.sh; do bash -n "$file"; done
scratch=$(mktemp -d "${TMPDIR:-/tmp}/dots-rofi-check.XXXXXX")
trap 'rm -rf -- "$scratch"' EXIT
export HOME=$scratch/home XDG_STATE_HOME=$scratch/state XDG_CACHE_HOME=$scratch/cache XDG_RUNTIME_DIR=$scratch/runtime
export ROFI_SETTINGS=$scratch/settings.json TEST_LOG=$scratch/log TEST_PATHS=$scratch/paths TEST_RESPONSE=$scratch/response
mkdir -p "$HOME" "$scratch/bin"
cp "$repo/.config/rofi/settings.json" "$ROFI_SETTINGS"
cat > "$scratch/bin/flock" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
cat > "$scratch/bin/systemctl" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$TEST_LOG"
[[ $* != *is-active* ]]
STUB
cat > "$scratch/bin/systemd-run" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$TEST_LOG"
STUB
cat > "$scratch/bin/fd" <<'STUB'
#!/usr/bin/env bash
cat "$TEST_PATHS"
exit "${TEST_FAIL:-0}"
STUB
cat > "$scratch/bin/curl" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" >> "$TEST_LOG"
while (($#)); do
    if [[ $1 == -o ]]; then cp "$TEST_RESPONSE" "$2"; exit "${TEST_FAIL:-0}"; fi
    shift
done
cat "$TEST_RESPONSE"
exit "${TEST_FAIL:-0}"
STUB
cat > "$scratch/bin/hyprctl" <<'STUB'
#!/usr/bin/env bash
printf '[{"focused":true,"name":"TEST","width":1920,"height":1080,"scale":1,"transform":0}]\n'
STUB
cat > "$scratch/bin/rofi" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$TEST_LOG"
printf '%s' "${TEST_CHOICE:-0}"
exit "${TEST_RC:-0}"
STUB
chmod +x "$scratch/bin/"*
export PATH=$scratch/bin:$PATH
source "$repo/.config/rofi/modi/common.sh"
clock=$ROOT/modi/time.sh
[[ $("$clock" duration 1h30m) == 5400 ]]
[[ $("$clock" duration .5m 2>/dev/null || printf invalid) == invalid ]]
[[ $("$clock" duration 1.5m) == 90 ]]
for bad in 0s -2m 2x '1m;id'; do if "$clock" duration "$bad" >/dev/null 2>&1; then exit 1; fi; done
export TZ=Europe/Amsterdam
friday=$(wall_epoch '2026-09-11 23:00')
next=$("$clock" next 07:30 weekdays "$friday")
[[ $(at_epoch "$next" '+%F %H:%M') == '2026-09-14 07:30' ]]
"$clock" add-timer 10m 'Tea $(touch /tmp/never-evaluate-rofi)'
jq -e '.items|length==1' "$STATE/clocks.json" >/dev/null
jq '.items[0].due=1' "$STATE/clocks.json" | atomic "$STATE/clocks.json"
"$clock" fire; "$clock" fire
jq -e '(.alerts|length)==1 and .items[0].due==null' "$STATE/clocks.json" >/dev/null
alert_id=$(jq -r '.alerts[0].id' "$STATE/clocks.json")
"$clock" dismiss "$alert_id"
jq -e '(.alerts|length)==0 and (.items|length)==1' "$STATE/clocks.json" >/dev/null
before=$(cat "$STATE/clocks.json"); "$clock" dismiss nonexistent
[[ $(cat "$STATE/clocks.json") == "$before" ]]
"$clock" add-alarm 07:30 daily Wake
jq '(.items[]|select(.kind=="alarm")).due=1' "$STATE/clocks.json" | atomic "$STATE/clocks.json"
"$clock" fire; "$clock" fire
jq -e --argjson now "$(date +%s)" '(.alerts|length)==1 and ([.items[]|select(.kind=="alarm")][0].due>$now)' "$STATE/clocks.json" >/dev/null
"$clock" watch-start; "$clock" watch-lap; "$clock" watch-pause
jq -e '.watch.started==null and (.watch.laps|length)==1 and .watch.elapsed>=0' "$STATE/clocks.json" >/dev/null
"$clock" watch-reset
jq -e '.watch=={}' "$STATE/clocks.json" >/dev/null
printf 'PASS: duration validation, recurring alarms, catch-up deduplication, dismissal, stopwatch\n'
path=$HOME/$'a name\nwith newline\n'
printf '%s\0' "$path" > "$TEST_PATHS"
touch "$path"
cat > "$scratch/bin/fzf" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$TEST_LOG"
cat
exit "${FZF_TEST_CANCEL:-0}"
STUB
cat > "$scratch/bin/code" <<'STUB'
#!/usr/bin/env bash
printf '%s\0' "$@" > "$TEST_OPENED"
STUB
chmod +x "$scratch/bin/fzf" "$scratch/bin/code"
export TEST_OPENED=$scratch/opened
"$ROOT/modi/files.sh" pick
jq -Rse --arg path "$path" 'split("\u0000")==["--",$path,""]' "$TEST_OPENED" >/dev/null
grep -q -- '--read0 --print0 --scheme=path' "$TEST_LOG"
rm "$TEST_OPENED"
FZF_TEST_CANCEL=130 "$ROOT/modi/files.sh" pick || :
[[ ! -f $TEST_OPENED ]]
printf 'PASS: fzf opens exact filenames in VS Code and cancellation opens nothing\n'
printf '{"current":{"temperature_2m":18,"weather_code":0}}' > "$TEST_RESPONSE"
weather
touch -t 202001010000 "$CACHE/weather"
cp "$CACHE/weather" "$scratch/weather.before"
if TEST_FAIL=1 weather; then exit 1; fi
cmp "$scratch/weather.before" "$CACHE/weather"
printf 'PASS: exact unusual filenames and preserved caches after failed refreshes\n'
menu_setup
[[ $WIDTH == 1100 && $HEIGHT == 720 ]]
for i in "${!KEYS[@]}"; do export TEST_RC=$((i+10)); choose HOME '' home </dev/null; [[ $CHOICE == key:$i ]]; done
export TEST_RC=22; choose HOME '' home </dev/null; [[ $CHOICE == key:12 ]]
export TEST_RC=10; choose Files '' list </dev/null; [[ $CHOICE == refresh ]]
export TEST_RC=0 TEST_CHOICE=1; choose Files '' list </dev/null; [[ $CHOICE == 1 ]]
export TEST_RC=1; if choose HOME '' home </dev/null; then exit 1; fi
home_rows > "$scratch/home.rows"
[[ $(wc -l < "$scratch/home.rows" | tr -d ' ') == 12 ]]
for icon in "$ROOT/icon-gen/icons/"*.svg; do grep -q 'fill="none"' "$icon"; grep -q '#67ffeb' "$icon"; done
mkdir -p "$scratch/icon-test"
cp -R "$ROOT/icon-gen" "$scratch/icon-test/"
mkdir -p "$scratch/icon-test/icon-gen/icons"
cp "$ROOT/settings.json" "$scratch/icon-test/settings.json"
jq '.icon_color="#abcdef"' "$ROOT/settings.json" > "$scratch/colors.json"
ROFI_SETTINGS=$scratch/colors.json bash "$scratch/icon-test/icon-gen/generate.sh" --offline >/dev/null
for icon in "$scratch/icon-test/icon-gen/icons/"*.svg; do grep -q '#abcdef' "$icon"; done
cp "$ROOT/icon-gen/sources/bot.svg" "$TEST_RESPONSE"
cp "$TEST_LOG" "$scratch/log.before"
ROFI_SETTINGS=$scratch/colors.json TEST_FAIL=1 bash "$scratch/icon-test/icon-gen/generate.sh" >/dev/null
cmp "$scratch/log.before" "$TEST_LOG"
rm "$scratch/icon-test/icon-gen/sources/bot.svg"
if bash "$scratch/icon-test/icon-gen/generate.sh" --offline bot >/dev/null 2>&1; then exit 1; fi
cmp "$scratch/log.before" "$TEST_LOG"
ROFI_SETTINGS=$scratch/colors.json bash "$scratch/icon-test/icon-gen/generate.sh" bot >/dev/null
grep -q '#abcdef' "$scratch/icon-test/icon-gen/icons/bot.svg"
[[ -f $scratch/icon-test/icon-gen/sources/bot.svg ]]
grep -q '/icons/bot.svg' "$TEST_LOG"
cp "$scratch/icon-test/icon-gen/icons/bot.svg" "$scratch/icon.before"
rm "$scratch/icon-test/icon-gen/sources/bot.svg"
if TEST_FAIL=1 bash "$scratch/icon-test/icon-gen/generate.sh" bot >/dev/null; then exit 1; fi
cmp "$scratch/icon.before" "$scratch/icon-test/icon-gen/icons/bot.svg"
printf 'PASS: monitor sizing, all Home shortcuts, normal selection, transparent tinted icons\n'
printf 'hello' | "$ROOT/modi/ai.sh" start
printf '{"choices":[{"message":{"content":"Hello."}}]}' > "$TEST_RESPONSE"
"$ROOT/modi/ai.sh" run
jq -e '.status=="done" and .answer=="Hello."' "$RUNTIME/ai.json" >/dev/null
grep -q '"enable_thinking": false' "$TEST_LOG"
grep -q '"max_tokens": 128' "$TEST_LOG"
printf 'hello' | "$ROOT/modi/ai.sh" start
printf '{"choices":[{"message":{"content":"<think>hidden</think>Hi"}}]}' > "$TEST_RESPONSE"
"$ROOT/modi/ai.sh" run
jq -e '.status=="error"' "$RUNTIME/ai.json" >/dev/null
"$ROOT/modi/ai.sh" cancel
jq -e '.error=="Cancelled"' "$RUNTIME/ai.json" >/dev/null
printf 'hello' | "$ROOT/modi/ai.sh" start
"$ROOT/modi/ai.sh" status | jq -e '.status=="error"' >/dev/null
printf 'PASS: bounded no-thinking requests, answer handling, rejection of reasoning, cancellation and stale jobs\n'
source "$ROOT/launcher.sh"
pactl() {
    printf '%s\n' "$*" >> "$TEST_LOG"
    case $* in
        '-f json list sinks') printf '[{"name":"speakers","description":"Speakers"},{"name":"headset","description":"Headset"}]';;
        get-default-sink) printf speakers;;
        '-f json list sink-inputs') printf '[{"index":42},{"index":43}]';;
    esac
}
selections=0
choose() { selections=$((selections+1)); if ((selections==1)); then CHOICE=1; else return 1; fi; }
outputs_menu || :
grep -q '^set-default-sink headset$' "$TEST_LOG"
grep -q '^move-sink-input 42 headset$' "$TEST_LOG"
grep -q '^move-sink-input 43 headset$' "$TEST_LOG"
printf 'PASS: moving all playback streams\n'
mkdir -p "$scratch/migration/config/rofi" "$scratch/migration/state/dots-rofi"
printf '{"icon_color":"#123456","weather":{"city":"Example"},"sound":"/custom.ogg"}' > "$scratch/migration/config/rofi/hub.json"
cp "$STATE/clocks.json" "$scratch/migration/state/dots-rofi/clocks.json"
XDG_CONFIG_HOME=$scratch/migration/config XDG_STATE_HOME=$scratch/migration/state bash "$repo/scripts/migrate-rofi.sh"
jq -e '.icon_color=="#123456"' "$scratch/migration/config/rofi/settings.json" >/dev/null
jq -e '.weather.city=="Example" and .sound=="/custom.ogg"' "$scratch/migration/config/rofi/settings.json" >/dev/null
cmp "$STATE/clocks.json" "$scratch/migration/state/dots-utils/clocks.json"
printf '{"items":[],"alerts":[],"watch":{}}' > "$scratch/migration/state/dots-utils/clocks.json"
XDG_CONFIG_HOME=$scratch/migration/config XDG_STATE_HOME=$scratch/migration/state bash "$repo/scripts/migrate-rofi.sh"
jq -e '.items|length==0' "$scratch/migration/state/dots-utils/clocks.json" >/dev/null
printf 'PASS: merged settings and idempotent clock migration\n'
mkdir -p "$scratch/rename/config/utils" "$scratch/rename/state/utils" "$scratch/rename/state/dots-rofi" "$scratch/rename/cache/utils"
printf '{"weather":{"city":"Newest"}}' > "$scratch/rename/config/utils/settings.json"
cp "$STATE/clocks.json" "$scratch/rename/state/utils/clocks.json"
printf '{"items":[],"alerts":[],"watch":{}}' > "$scratch/rename/state/dots-rofi/clocks.json"
printf 'Cached weather' > "$scratch/rename/cache/utils/weather"
XDG_CONFIG_HOME=$scratch/rename/config XDG_STATE_HOME=$scratch/rename/state XDG_CACHE_HOME=$scratch/rename/cache bash "$repo/scripts/migrate-rofi.sh"
cmp "$STATE/clocks.json" "$scratch/rename/state/dots-utils/clocks.json"
jq -e '.weather.city=="Newest" and (has("refresh_seconds")|not)' "$scratch/rename/config/rofi/settings.json" >/dev/null
[[ $(cat "$scratch/rename/cache/dots-utils/weather") == 'Cached weather' ]]
printf 'PASS: desktop rename migration without worker settings\n'
[[ $(head -c 4 "$ROOT/sounds/villager-idle1.ogg") == OggS ]]
printf 'All local Bash checks passed. Locks, systemd, DBus, rendering and audio require Arch live testing.\n'
