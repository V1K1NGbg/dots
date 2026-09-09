#!/usr/bin/env bash
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
STATE=${XDG_STATE_HOME:-$HOME/.local/state}/dots-utils
CACHE=${XDG_CACHE_HOME:-$HOME/.cache}/dots-utils
RUNTIME=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/dots-utils
umask 077
mkdir -p "$STATE" "$CACHE" "$RUNTIME"
clean() { LC_ALL=C tr '\000-\037\177' ' '; }
atomic() { local temp; temp=$(mktemp "$1.XXXXXX") || return; cat > "$temp" && mv -f -- "$temp" "$1"; }
id_new() { printf '%s-%s-%s\n' "$(date +%s)" "$$" "$RANDOM"; }
# BSD date support is for local checks; Arch uses GNU date.
if date -d @0 +%s >/dev/null 2>&1; then
    at_epoch() { date -d "@$1" "$2"; }
    wall_epoch() { date -d "$1" +%s; }
else
    at_epoch() { date -r "$1" "$2"; }
    wall_epoch() { date -j -f '%Y-%m-%d %H:%M' "$1" +%s; }
fi
CONFIG=$(jq -e . "${ROFI_SETTINGS:-$ROOT/settings.json}")
cfg() { jq -r "$1" <<<"$CONFIG"; }
escape() { jq -Rrs '@html'; }
hms() { awk -v s="$1" 'BEGIN{s=int(s);if(s<0)s=0;printf "%02d:%02d:%02d",s/3600,s/60%60,s%60}'; }
# One table defines the home letters, labels and routes. Icons live in settings.json.
KEYS=(r f q t m w c v a n b p)
LABELS=(Run Files 'Ask AI' Time Music Windows Calculator Clipboard Autocorrect Wi-Fi Bluetooth Power)
MODES=(run files ai time music window calc clipboard autocorrector wifi bluetooth power)

# Rofi also supports user plugins; packaged plugins remain the primary source.
if [[ -f ${XDG_DATA_HOME:-$HOME/.local/share}/rofi/plugins/blocks.so ]]; then
    export ROFI_PLUGIN_PATH="${XDG_DATA_HOME:-$HOME/.local/share}/rofi/plugins${ROFI_PLUGIN_PATH:+:$ROFI_PLUGIN_PATH}"
fi
menu_setup() {
    local monitor width height lines
    monitor=$(hyprctl monitors -j 2>/dev/null | jq -c '[.[]|select(.focused)][0] // empty') || monitor=
    width=1100; height=720
    ROFI=(rofi -no-config -theme "$ROOT/theme.rasi" -i -matching fuzzy -no-sort)
    if [[ -n $monitor ]]; then
        read -r width height < <(jq -r '(if (.transform%2)==1 then [.height,.width] else [.width,.height] end) as $size | [($size[0]/.scale*0.9|floor|[.,1100]|min),($size[1]/.scale*0.9|floor|[.,720]|min)]|@tsv' <<<"$monitor")
        ROFI+=(-monitor "$(jq -r .name <<<"$monitor")")
    fi
    WIDTH=$width; HEIGHT=$height
    local font=15
    ((width<1000 || height<680)) && font=12
    lines=$(( (height-190)/54 )); ((lines<=8)) || lines=8; ((lines>=3)) || lines=3
    ROFI+=(-theme-str "window { width: ${width}px; } listview { lines: $lines; } * { font: \"Monocraft Nerd Font $font\"; }")
}

# Rows arrive on stdin. CHOICE is an index, key:N, or refresh; Escape returns 1.
choose() {
    local title=$1 message=${2:-} kind=${3:-list} rc=0 i
    shift 3
    local args=("${ROFI[@]}" -dmenu -no-custom -p "$title" -format i)
    if [[ -n $message ]]; then
        if [[ $kind == home ]]; then args+=(-mesg "$message")
        else args+=(-mesg "$(printf '%s' "$message" | escape)"); fi
    fi
    if [[ $kind == home ]]; then
        args+=(-show-icons -markup-rows -theme-str 'inputbar { children: [prompt]; padding: 6px 4px 12px; } mainbox { spacing: 12px; } textbox { padding: 10px 16px; } listview { columns: 4; lines: 3; fixed-height: true; flow: horizontal; spacing: 12px; scrollbar: false; } element { children: [element-icon,element-text]; orientation: vertical; background-color: #242424; border-color: #404040; padding: 14px 8px; spacing: 10px; } element alternate.normal { background-color: #242424; } element-icon { size: 30px; horizontal-align: 0.5; } element-text { horizontal-align: 0.5; } element selected.normal { background-color: #223b37; border-color: #67ffeb; }')
        for i in "${!KEYS[@]}"; do args+=("-kb-custom-$((i+1))" "${KEYS[i]}"); done
        args+=(-kb-custom-13 Tab -kb-element-next '' -kb-row-tab "" -kb-mode-next "")
        if ((WIDTH<1000 || HEIGHT<680)); then args+=(-theme-str 'mainbox { padding: 16px; spacing: 10px; } textbox { padding: 10px; } element { padding: 6px; spacing: 4px; } element-icon { size: 24px; }'); fi
        if ((WIDTH<700)); then args+=(-theme-str "window { height: ${HEIGHT}px; }"); args+=(-theme-str 'listview { columns: 2; lines: 6; scrollbar: true; }'); fi
        if ((HEIGHT<580)); then args+=(-theme-str '* { font: "Monocraft Nerd Font 11"; } mainbox { padding: 12px; spacing: 8px; } inputbar { padding: 6px; } textbox { padding: 8px; } listview { spacing: 6px; } element { padding: 4px; spacing: 2px; } element-icon { size: 18px; }'); fi
    else
        args+=(-kb-custom-1 Control+r)
    fi
    CHOICE=$("${args[@]}" "$@" 9>&-) || rc=$?
    if ((rc==1)); then return 1; fi
    if [[ $kind == home ]] && ((rc>=10 && rc<=22)); then CHOICE=key:$((rc-10)); return; fi
    if ((rc==10)); then CHOICE=refresh; return; fi
    [[ $rc == 0 && $CHOICE =~ ^[0-9]+$ ]]
}
prompt() { ANSWER=$("${ROFI[@]}" -dmenu -p "$1" -mesg "$(printf '%s' "$2" | escape)" </dev/null 9>&-); }
info() { choose "$1" "$2" list <<<'Back'; }

home_rows() {
    local i name names=()
    while IFS= read -r name; do names+=("$name"); done < <(printf '%s\n' "${MODES[@]}" | jq -Rr --argjson config "$CONFIG" '$config.icons[.] // "layout-grid"')
    for i in "${!MODES[@]}"; do
        name=${names[i]}
        [[ $name =~ ^[a-z0-9-]+$ && -f $ROOT/icon-gen/icons/$name.svg ]] || name=layout-grid
        printf '<span foreground="#67ffeb" weight="bold" size="large">%s</span>  %s\0icon\x1f%s\n' "${KEYS[i]}" "${LABELS[i]}" "$ROOT/icon-gen/icons/$name.svg"
    done
}
dashboard() {
    stats
    weather 2>/dev/null || :
    local stats cpu temperature memory battery network weather
    stats=$(cat "$CACHE/stats")
    cpu=${stats#CPU }; cpu=${cpu%% · *}
    temperature=${stats#* · }; temperature=${temperature%% · *}
    memory=${stats##*RAM }
    battery=$(cat "$CACHE/battery")
    network=$(cat "$CACHE/network")
    weather=$(cat "$CACHE/weather" 2>/dev/null || printf 'Unavailable')
    weather=${weather% · updated *}
    dashboard_row "$(date +%H:%M)" "$(date '+%a, %d %b')" POWER "$battery"
    dashboard_row CPU "$cpu" RAM "$memory"
    dashboard_row TEMP "$network" WEATHER "$weather"
}
# Monospaced columns use the available panel width, with a narrow-screen wrap.
# Count before escaping so names containing markup characters keep their spacing.
dashboard_row() {
    local left="$1  $2" right="$4  $3" columns gap length font_width=13
    ((WIDTH>=1000 && HEIGHT>=680)) || font_width=11
    columns=$(( (WIDTH-88)/font_width ))
    length=$(printf '%s' "$left$right" | jq -Rrs length)
    gap=$((columns-length))
    printf '<span foreground="#67ffeb">%s</span>  <span foreground="#f8f8f2">%s</span>' "$(printf '%s' "$1" | escape)" "$(printf '%s' "$2" | escape)"
    if ((gap<3)); then printf '\n'; else printf '%*s' "$gap" ''; fi
    printf '<span foreground="#f8f8f2">%s</span>  <span foreground="#67ffeb">%s</span>\n' "$(printf '%s' "$4" | escape)" "$(printf '%s' "$3" | escape)"
}
live_menu() {
    local command height args=()
    case $1 in ai) height=440;; time) if [[ ${2:-timer} == timer ]]; then height=280; else height=400; fi;; *) height=580;; esac
    ((height<=HEIGHT)) || height=$HEIGHT
    args+=(-theme-str "window { height: ${height}px; }")
    [[ $1 != ai && $1 != time ]] || args+=(-theme-str 'listview { scrollbar: false; }')
    [[ $1 != ai ]] || args+=(-theme-str 'entry { enabled: false; }')
    printf -v command '%q ' "$ROOT/modi/$1.sh" live "${@:2}"
    rofi_native Escape -modi blocks -show blocks -blocks-wrap "$command" "${args[@]}"
}
# rofi-blocks keeps these scripts attached to the window, then closes on EOF.
live_page() {
    jq -cn --arg prompt "$1" --arg message "$2" --argjson lines "$3" \
        '{prompt:$prompt,message:($message|@html),lines:$lines,"input action":"send","close on exit":true}'
}

# Native modes all return zero for Escape. Route it through the mode-change
# hook instead, and wait for the signal before returning a distinct Back code.
rofi_native() (
    local keys=$1 owner=${BASHPID:-$$} child='' back=false rc=0
    shift
    trap '[[ -z $child ]] || kill "$child" 2>/dev/null || :' EXIT
    trap 'back=true; [[ -z $child ]] || kill "$child" 2>/dev/null || :' USR1
    trap 'exit 1' TERM INT HUP
    "${ROFI[@]}" "$@" -kb-cancel '' -kb-mode-next "$keys" -kb-mode-previous '' \
        -on-mode-changed "kill -USR1 $owner" 9>&- &
    child=$!
    wait "$child" 2>/dev/null || rc=$?
    wait "$child" 2>/dev/null || :
    child=''
    if $back; then return 10; fi
    return "$rc"
)

weather() (
    set -euo pipefail
    exec 9>"$RUNTIME/weather.lock"; flock -n 9 || exit 0
    if [[ -f $CACHE/weather ]]; then
        stamp=$(stat -c %Y "$CACHE/weather" 2>/dev/null) || stamp=$(stat -f %m "$CACHE/weather")
        (( $(date +%s)-stamp >= 900 )) || exit 0
    fi
    temp=$(mktemp "$CACHE/weather.XXXXXX"); trap 'rm -f -- "$temp"' EXIT
    curl -fsS --connect-timeout 1 --max-time 2 --get 'https://api.open-meteo.com/v1/forecast' \
        --data-urlencode "latitude=$(cfg .weather.latitude)" --data-urlencode "longitude=$(cfg .weather.longitude)" \
        --data-urlencode 'current=temperature_2m,weather_code' --data-urlencode timezone=auto |
        jq -er --arg city "$(cfg .weather.city)" --arg stamp "$(date '+%H:%M')" '
        .current | select(.temperature_2m!=null) | .weather_code as $c |
        (if $c==0 then "Clear" elif $c<=3 then "Cloudy" elif $c<=48 then "Fog"
         elif $c<=57 then "Drizzle" elif $c<=67 then "Rain" elif $c<=77 then "Snow"
         elif $c<=86 then "Showers" else "Thunderstorms" end) as $condition |
        "\($city) \(.temperature_2m)°C · \($condition) · updated \($stamp)"' > "$temp" || return 1
    mv -f -- "$temp" "$CACHE/weather"
)
stats() (
    set -euo pipefail
    exec 9>"$RUNTIME/stats.lock"; flock -n 9 || exit 0
    local total idle old_total=0 old_idle=0 cpu=unavailable memory=unavailable temp=0 value name battery=unavailable
    if [[ -r /proc/stat ]]; then
        read -r total idle < <(awk '/^cpu / {for(i=2;i<=9;i++)s+=$i;print s,$5+$6;exit}' /proc/stat)
        old_total=$total; old_idle=$idle
        sleep .1
        read -r total idle < <(awk '/^cpu / {for(i=2;i<=9;i++)s+=$i;print s,$5+$6;exit}' /proc/stat)
        if ((old_total>0 && total>old_total)); then cpu="$((100-100*(idle-old_idle)/(total-old_total)))%"; fi
        memory=$(awk '/MemTotal:/{t=$2}/MemAvailable:/{a=$2}END{printf "%.1f/%.0f GiB",(t-a)/1048576,t/1048576}' /proc/meminfo)
    fi
    for name in /sys/class/hwmon/hwmon*/name; do
        [[ -f $name ]] || continue
        case $(cat "$name") in k10temp|coretemp|zenpower)
            for value in "${name%/name}"/temp*_input; do
                [[ -r $value ]] || continue; value=$(cat "$value")
                if [[ $value =~ ^[0-9]+$ ]] && ((value>temp)); then temp=$value; fi
            done;; esac
    done
    for name in /sys/class/power_supply/*; do
        [[ -r $name/capacity ]] || continue
        battery="$(cat "$name/capacity")% $(cat "$name/status")"; break
    done
    printf '%s\n' "$battery" | atomic "$CACHE/battery"
    value=unavailable; ((temp>0)) && value="$((temp/1000))°C"
    printf 'CPU %s · %s · RAM %s\n' "$cpu" "$value" "$memory" | atomic "$CACHE/stats"
    local net
    net=$(timeout 2 nmcli -t -f STATE,CONNECTION device 2>/dev/null | sed -n 's/^connected://p' | head -c 24 | clean) || net='Network unavailable'
    printf '%s\n' "${net:-Disconnected}" | atomic "$CACHE/network"
)
