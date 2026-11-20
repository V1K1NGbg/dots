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
# Pango-escape $1 into REPLY without spawning a process.
esc() { REPLY=${1//"&"/"&amp;"}; REPLY=${REPLY//"<"/"&lt;"}; REPLY=${REPLY//">"/"&gt;"}; REPLY=${REPLY//'"'/"&quot;"}; REPLY=${REPLY//"'"/"&#39;"}; }
escape() { local text; IFS= read -rd '' text || :; esc "$text"; printf '%s' "$REPLY"; }
hms() { awk -v s="$1" 'BEGIN{s=int(s);if(s<0)s=0;printf "%02d:%02d:%02d",s/3600,s/60%60,s%60}'; }
# One table defines the home letters, labels and routes (a 3x3 icon grid).
# Run lives on its own shortcut. Icons live in settings.json.
KEYS=(f w c v q t m n p)
LABELS=(Files Windows Calculator 'Clipboard & Spelling' 'Ask AI' Time 'Music & Audio' 'Wi-Fi & Bluetooth' 'Power & Display')
MODES=(files window calc clipboard ai time music network power)

# Rofi also supports user plugins; packaged plugins remain the primary source.
if [[ -f ${XDG_DATA_HOME:-$HOME/.local/share}/rofi/plugins/blocks.so ]]; then
    export ROFI_PLUGIN_PATH="${XDG_DATA_HOME:-$HOME/.local/share}/rofi/plugins${ROFI_PLUGIN_PATH:+:$ROFI_PLUGIN_PATH}"
fi
menu_setup() {
    local monitor width height lines
    width=1100; height=720
    ROFI=(rofi -no-config -theme "$ROOT/theme.rasi" -i -matching fuzzy -no-sort)
    monitor=$(hyprctl monitors -j 2>/dev/null | jq -r '[.[]|select(.focused)][0] // empty |
        (if (.transform%2)==1 then [.height,.width] else [.width,.height] end) as $size |
        [($size[0]/.scale*0.9|floor|[.,1100]|min),($size[1]/.scale*0.9|floor|[.,720]|min),.name]|@tsv') || monitor=
    if [[ -n $monitor ]]; then
        IFS=$'\t' read -r width height monitor <<<"$monitor"
        ROFI+=(-monitor "$monitor")
    fi
    WIDTH=$width; HEIGHT=$height
    local font=15
    ((width<1000 || height<680)) && font=12
    lines=$(( (height-190)/54 )); ((lines<=8)) || lines=8; ((lines>=3)) || lines=3
    ROFI+=(-theme-str "window { width: ${width}px; } listview { lines: $lines; } * { font: \"Monocraft Nerd Font $font\"; }")
}

# Rows arrive on stdin. CHOICE is a row index, key:N (home) or refresh; Escape
# returns 1. Kinds: home (the icon grid) and list (rows are numbered and the
# bare digits 1-9, 0 pick and run them; letters still filter).
# A row written as "## Title" becomes an unnumbered, unselectable heading.
choose() {
    local title=$1 message=${2:-} kind=${3:-list} rc=0 i n=0 row
    shift 3
    local args=("${ROFI[@]}" -dmenu -no-custom -p "$title" -format i -markup-rows)
    if [[ -n $message ]]; then
        if [[ $kind == home ]]; then args+=(-mesg "$message")
        else esc "$message"; args+=(-mesg "$REPLY"); fi
    fi
    if [[ $kind == home ]]; then
        args+=(-show-icons -theme-str 'inputbar { children: [prompt]; padding: 6px 4px 12px; } mainbox { spacing: 12px; } textbox { padding: 10px 16px; } listview { columns: 3; lines: 3; fixed-height: true; flow: horizontal; spacing: 12px; scrollbar: false; } element { children: [element-icon,element-text]; orientation: vertical; background-color: #242424; border-color: #404040; padding: 14px 8px; spacing: 10px; } element alternate.normal { background-color: #242424; } element-icon { size: 30px; horizontal-align: 0.5; } element-text { horizontal-align: 0.5; } element selected.normal { background-color: #223b37; border-color: #67ffeb; }')
        for i in "${!KEYS[@]}"; do args+=("-kb-custom-$((i+1))" "${KEYS[i]}"); done
        args+=(-kb-element-next '' -kb-row-tab '' -kb-mode-next '')
        if ((WIDTH<1000 || HEIGHT<680)); then args+=(-theme-str 'mainbox { padding: 16px; spacing: 10px; } textbox { padding: 10px; } element { padding: 6px; spacing: 4px; } element-icon { size: 24px; }'); fi
        if ((WIDTH<700)); then args+=(-theme-str "window { height: ${HEIGHT}px; }"); args+=(-theme-str 'listview { columns: 2; lines: 5; scrollbar: true; }'); fi
        if ((HEIGHT<580)); then args+=(-theme-str '* { font: "Monocraft Nerd Font 11"; } mainbox { padding: 12px; spacing: 8px; } inputbar { padding: 6px; } textbox { padding: 8px; } listview { spacing: 6px; } element { padding: 4px; spacing: 2px; } element-icon { size: 18px; }'); fi
        # Preserve the icon metadata (including NUL bytes) across the two views.
        local rows
        rows=$(mktemp "$RUNTIME/home-rows.XXXXXX") || return 1
        cat > "$rows"
        # Rofi always has an internal row. Before navigation, hide its highlight
        # and disable keyboard acceptance so Enter cannot launch it accidentally.
        CHOICE=$("${args[@]}" "$@" -no-auto-select -no-hover-select \
            -theme-str 'element selected.normal { background-color: #242424; border-color: #404040; }' \
            -kb-row-up '' -kb-row-down '' -kb-row-left '' -kb-row-right '' \
            -kb-move-char-back Control+b -kb-move-char-forward Control+f \
            -kb-accept-entry '' -kb-accept-alt '' -kb-accept-custom '' \
            -kb-accept-custom-alt '' -kb-custom-14 Up,Down,Left,Right \
            < "$rows" 9>&-) || rc=$?
        if ((rc==23)); then
            rc=0
            CHOICE=$("${args[@]}" "$@" -selected-row 0 < "$rows" 9>&-) || rc=$?
        fi
        rm -f -- "$rows"
        if ((rc==1)); then return 1; fi
        if ((rc>=10 && rc<10+${#KEYS[@]})); then CHOICE=key:$((rc-10)); return; fi
        [[ $rc == 0 && $CHOICE =~ ^[0-9]+$ ]]
        return
    fi
    local rows=() map=() extra=() selected=0
    args+=(-kb-custom-1 Control+r)
    while IFS= read -r row; do rows+=("$row"); done
    # Rofi ignores Enter and custom keys while a heading is highlighted, so
    # never start on one (Wi-Fi opens with its "## Wi-Fi" heading first).
    while (($#)); do
        if [[ $1 == -selected-row && $# -ge 2 ]]; then selected=$2; shift 2; else extra+=("$1"); shift; fi
    done
    while ((selected<${#rows[@]})) && [[ ${rows[selected]} == '## '* ]]; do ((selected++)); done
    ((selected<${#rows[@]})) || selected=0
    set -- "${extra[@]}" -selected-row "$selected"
    for i in "${!rows[@]}"; do
        [[ ${rows[i]} != '## '* ]] || continue
        ((++n<=10)) || break
        map[n]=$i
        args+=("-kb-custom-$((n+1))" "$((n%10))")
    done
    CHOICE=$(n=0
        for row in "${rows[@]}"; do
            if [[ $row == '## '* ]]; then
                esc "${row#'## '}"
                printf '<span foreground="#808080" weight="bold">%s</span>\0nonselectable\x1ftrue\n' "$REPLY"
                continue
            fi
            esc "$row"
            if ((++n<=10)); then printf '<span foreground="#67ffeb" weight="bold">%s</span>  %s\n' "$((n%10))" "$REPLY"
            else printf '   %s\n' "$REPLY"; fi
        done | "${args[@]}" "$@" 9>&-) || rc=$?
    if ((rc==1)); then return 1; fi
    if ((rc==10)); then CHOICE=refresh; return; fi
    if ((rc>=11 && rc<=20)) && [[ -n ${map[rc-10]:-} ]]; then CHOICE=${map[rc-10]}; return; fi
    [[ $rc == 0 && $CHOICE =~ ^[0-9]+$ ]]
}
prompt() { esc "$2"; ANSWER=$("${ROFI[@]}" -dmenu -p "$1" -mesg "$REPLY" </dev/null 9>&-); }
info() { choose "$1" "$2" list <<<'Back'; }

home_rows() {
    local i name names=()
    while IFS= read -r name; do names+=("$name"); done < <(printf '%s\n' "${MODES[@]}" | jq -Rr --argjson config "$CONFIG" '$config.icons[.] // "layout-grid"')
    for i in "${!MODES[@]}"; do
        name=${names[i]}
        [[ $name =~ ^[a-z0-9-]+$ && -f $ROOT/icon-gen/icons/$name.svg ]] || name=layout-grid
        esc "${LABELS[i]}"
        printf '<span foreground="#67ffeb" weight="bold" size="large">%s</span>  %s\0icon\x1f%s\n' "${KEYS[i]}" "$REPLY" "$ROOT/icon-gen/icons/$name.svg"
    done
}
# CPU usage is the delta between cpu_snapshot (taken as the launcher starts)
# and the dashboard, so the sample overlaps with Rofi setup instead of sleeping.
cpu_snapshot() {
    local _ user nice system idle iowait irq softirq steal
    read -r _ user nice system idle iowait irq softirq steal _ < /proc/stat 2>/dev/null || return 0
    CPU_TOTAL=$((user+nice+system+idle+iowait+irq+softirq+steal)) CPU_IDLE=$((idle+iowait)) CPU_TIME=${EPOCHREALTIME/[.,]/}
}
dashboard() {
    local cpu=unavailable memory=unavailable temperature=unavailable battery=unavailable weather=Unavailable
    local total idle old_total=${CPU_TOTAL:-} old_idle=${CPU_IDLE:-} wait key value unit name hottest=0 status
    (weather >/dev/null 2>&1 9>&- &) # Refreshes the cache for the next open.
    if [[ -n $old_total ]]; then
        wait=$(( 50000-(${EPOCHREALTIME/[.,]/}-CPU_TIME) ))
        ((wait<=0)) || sleep "0.$(printf '%06d' "$wait")"
        cpu_snapshot
        total=$((CPU_TOTAL-old_total)) idle=$((CPU_IDLE-old_idle))
        ((total<=0)) || cpu="$((100-100*idle/total))%"
    fi
    local mem_total=0 mem_available=0
    while read -r key value unit; do
        case $key in MemTotal:) mem_total=$value;; MemAvailable:) mem_available=$value; break;; esac
    done < /proc/meminfo 2>/dev/null
    if ((mem_total>0)); then
        value=$(( (mem_total-mem_available)*10/1048576 ))
        memory="$((value/10)).$((value%10))/$(( (mem_total+524288)/1048576 )) GiB"
    fi
    for name in /sys/class/hwmon/hwmon*/name; do
        read -r key 2>/dev/null < "$name" || continue
        case $key in k10temp|coretemp|zenpower)
            for value in "${name%/name}"/temp*_input; do
                read -r value 2>/dev/null < "$value" || continue
                [[ $value =~ ^[0-9]+$ ]] && ((value>hottest)) && hottest=$value
            done;; esac
    done
    ((hottest>0)) && temperature="$((hottest/1000))°C"
    for name in /sys/class/power_supply/*; do
        read -r value 2>/dev/null < "$name/capacity" || continue
        read -r status 2>/dev/null < "$name/status" || status=
        battery="$value% $status"; break
    done
    [[ -r $CACHE/weather ]] && IFS= read -r weather < "$CACHE/weather"
    weather=${weather% · updated *}
    dashboard_row "$(printf '%(%H:%M)T')" "$(printf '%(%a, %d %b)T')" POWER "$battery"
    dashboard_row CPU "$cpu" RAM "$memory"
    dashboard_row TEMP "$temperature" WEATHER "$weather"
}
# Monospaced columns use the available panel width, with a narrow-screen wrap.
# Count before escaping so names containing markup characters keep their spacing.
dashboard_row() {
    local left="$1  $2" right="$4  $3" columns gap font_width=13 a b c d
    ((WIDTH>=1000 && HEIGHT>=680)) || font_width=11
    columns=$(( (WIDTH-88)/font_width ))
    gap=$((columns-${#left}-${#right}))
    esc "$1"; a=$REPLY; esc "$2"; b=$REPLY; esc "$3"; c=$REPLY; esc "$4"; d=$REPLY
    printf '<span foreground="#67ffeb">%s</span>  <span foreground="#f8f8f2">%s</span>' "$a" "$b"
    if ((gap<3)); then printf '\n'; else printf '%*s' "$gap" ''; fi
    printf '<span foreground="#f8f8f2">%s</span>  <span foreground="#67ffeb">%s</span>\n' "$d" "$c"
}
live_menu() {
    local command height args=()
    case $1 in ai) height=0;; time) if [[ ${2:-timer} == timer ]]; then height=280; else height=400; fi;; *) height=580;; esac
    ((height<=HEIGHT)) || height=$HEIGHT
    # Automatic height lets Rofi relayout the answer on every streamed update.
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
    "${ROFI[@]}" "$@" -kb-cancel "${ROFI_CANCEL_KEYS:-}" -kb-mode-next "$keys" -kb-mode-previous '' \
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
    curl -fsS --connect-timeout 3 --max-time 8 --get 'https://api.open-meteo.com/v1/forecast' \
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
