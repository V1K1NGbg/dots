#!/usr/bin/env bash
# Apply saved display layouts; ask with Rofi for unknown displays.
MONITOR_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
MONITOR_SAVED=${XDG_CONFIG_HOME:-$HOME/.config}/dots-monitors/profiles.json
MONITOR_LAYOUTS=(right left top bottom duplicate)

monitor_query() { hyprctl monitors all -j | jq -ce 'if type=="array" then . else error("Invalid monitor response") end'; }
monitor_read() {
    if [[ -f $1 ]]; then jq -ce 'if type=="object" then . else error("Invalid profile object") end' "$1"; else printf '{}\n'; fi
}
monitor_lua_string() {
    # Encode UTF-8 bytes as Lua decimal escapes, including quotes and newlines.
    printf '"'
    printf '%s' "$1" | od -An -v -tu1 | awk '{for(i=1;i<=NF;i++) printf "\\%03d", $i}'
    printf '"'
}
monitor_dispatch() {
    local result
    result=$(hyprctl dispatch "function() $1 end") || return
    [[ $result == ok ]] || { printf '%s\n' "$result" >&2; return 1; }
}
monitor_choose() {
    local title=$1; shift
    printf '%s\n' "$@" | bash "$MONITOR_ROOT/../rofi/modi/monitors.sh" --choose "$title" 8>&-
}
monitor_positions() {
    jq -cn --arg layout "$1" --argjson internal "$2" --argjson external "$3" '
      def nearest:
        floor as $f | if .-$f==0.5 then (if $f%2==0 then $f else $f+1 end) else round end;
      def size:
        (if (.transform//0)%2==1 then [.height,.width] else [.width,.height] end) as $s
        | [$s[] / .scale | nearest];
      ($internal|size) as $i | ($external|size) as $e |
      {right:[0,0,$i[0],0],left:[$e[0],0,0,0],top:[0,$e[1],0,0],
       bottom:[0,0,0,$i[1]],duplicate:[0,0,0,0]}[$layout] // error("Unknown layout")'
}
monitor_rule() {
    local monitor=$1 position=$2 mirror=${3:-} name width height refresh scale transform mode
    name=$(jq -r '.name' <<<"$monitor") || return
    read -r width height refresh scale transform < <(jq -r '[.width,.height,.refreshRate,.scale,(.transform//0)]|@tsv' <<<"$monitor")
    LC_NUMERIC=C printf -v mode '%sx%s@%.3f' "$width" "$height" "$refresh" || return
    printf 'hl.monitor({output=%s,mode=%s,position=%s,scale=%s,transform=%s,mirror=%s})' \
        "$(monitor_lua_string "$name")" "$(monitor_lua_string "$mode")" \
        "$(monitor_lua_string "$position")" "$scale" "$transform" "$(monitor_lua_string "$mirror")"
}
monitor_apply() {
    local internal=$1 external=$2 layout=$3 gather=${4:-true} positions a b mirror='' first second live names tries command
    positions=$(monitor_positions "$layout" "$internal" "$external") || return
    a=$(jq -r '.[0:2]|map(tostring)|join("x")' <<<"$positions") || return
    b=$(jq -r '.[2:4]|map(tostring)|join("x")' <<<"$positions") || return
    first=$(jq -r '.name' <<<"$internal"); second=$(jq -r '.name' <<<"$external")
    [[ $layout != duplicate ]] || mirror=$second
    command=$(monitor_rule "$external" "$b") || return
    command+="; $(monitor_rule "$internal" "$a" "$mirror")" || return
    monitor_dispatch "$command" || return
    for ((tries=0; tries<50; tries++)); do
        live=$(monitor_query) || return
        names=$(jq -c --arg a "$first" --arg b "$second" '[.[]|select(.name==$a or .name==$b)]' <<<"$live") || return
        [[ $(jq length <<<"$names") == 2 ]] || return 2 # Unplugged during selection.
        if jq -e --arg a "$first" --arg b "$second" --arg layout "$layout" --argjson p "$positions" '
          (map(select(.name==$a))[0]) as $i | (map(select(.name==$b))[0]) as $e |
          if $layout=="duplicate" then ($i.mirrorOf==$b or $i.mirrorOf==($e.id|tostring))
          else $i.mirrorOf=="none" and $e.mirrorOf=="none" and [$i.x,$i.y,$e.x,$e.y]==$p end' <<<"$names" >/dev/null; then
            monitor_dispatch "dots.set_primary($(monitor_lua_string "$second"), $gather)"
            return
        fi
        sleep .1
    done
    printf 'Display layout did not settle; reopen Super+Ctrl+P to retry\n' >&2
    return 1
}
monitor_main() (
    set -euo pipefail
    local auto=false reload=false arg runtime monitors topology previous internal external saved profiles targets index
    local monitor layout selected live first second gather rc temporary=''
    for arg in "$@"; do
        case $arg in --auto) auto=true;; --reload) reload=true;; *) printf 'Unknown option: %s\n' "$arg" >&2; exit 1;; esac
    done
    runtime=${XDG_RUNTIME_DIR:?}/dots-monitors-${HYPRLAND_INSTANCE_SIGNATURE:?}
    exec 8>"$runtime.lock"; flock -x 8
    trap '[[ -z $temporary ]] || rm -f -- "$temporary"' EXIT
    sleep .3
    monitors=$(monitor_query)
    topology=$(jq -c '[.[]|.name+":"+.description]|sort' <<<"$monitors")
    previous=$(monitor_read "$runtime")
    if $auto && ! $reload && [[ $(jq -c '.topology' <<<"$previous") == "$topology" ]]; then exit 0; fi
    internal=$(jq -c '[.[]|select(.name|test("^(eDP-|LVDS-|DSI-)"))][0]//null' <<<"$monitors")
    external=$(jq -c --argjson internal "$internal" '[.[]|select(.name!=$internal.name and (.disabled//false|not))]' <<<"$monitors")
    if [[ $internal == null || $(jq length <<<"$external") == 0 ]]; then
        if [[ $internal != null ]]; then
            monitor_dispatch "$(monitor_rule "$internal" 0x0)"
            monitor_dispatch "dots.set_primary($(monitor_lua_string "$(jq -r '.name' <<<"$internal")"), true)"
        fi
        if ! $auto; then notify-send Displays 'Connect an external monitor to choose a layout.'; fi
    else
        saved=$(monitor_read "$MONITOR_SAVED")
        profiles=$(jq -c --argjson saved "$saved" '(.profiles//{})+$saved' <<<"$(monitor_read "$MONITOR_ROOT/monitors.json")")
        if $auto; then
            targets=$(jq -c --argjson previous "$previous" '[.[]|select((.name+":"+.description) as $id | ($previous.topology//[]|index($id))==null)]' <<<"$external")
            [[ $(jq length <<<"$targets") != 0 ]] || targets=$external
        else
            index=0
            if [[ $(jq length <<<"$external") != 1 ]]; then
                local -a descriptions=()
                while IFS= read -r monitor; do descriptions+=("$(jq -r '.description' <<<"$monitor")"); done < <(jq -c '.[]' <<<"$external")
                index=$(monitor_choose Display "${descriptions[@]}") || exit 0
            fi
            [[ $index =~ ^[0-9]+$ && $index -lt $(jq length <<<"$external") ]] || exit 1
            targets=$(jq -c --argjson index "$index" '[.[$index]]' <<<"$external")
        fi
        while IFS= read -r monitor; do
            layout=''; selected=false
            if $auto; then layout=$(jq -r --arg id "$(jq -r '.description' <<<"$monitor")" '.[$id].layout//""' <<<"$profiles"); fi
            case $layout in right|left|top|bottom|duplicate) ;; *)
                index=$(monitor_choose 'External display position' Right Left Top Bottom Duplicate) || continue
                [[ $index =~ ^[0-4]$ ]] || exit 1
                layout=${MONITOR_LAYOUTS[index]}; selected=true;;
            esac
            live=$(monitor_query)
            first=$(jq -c --arg name "$(jq -r '.name' <<<"$internal")" '[.[]|select(.name==$name)][0]//null' <<<"$live")
            second=$(jq -c --arg name "$(jq -r '.name' <<<"$monitor")" '[.[]|select(.name==$name)][0]//null' <<<"$live")
            [[ $first != null && $second != null ]] || continue
            gather=true
            if $auto && [[ $(jq -c '.topology' <<<"$previous") == "$topology" ]]; then gather=false; fi
            rc=0; monitor_apply "$first" "$second" "$layout" "$gather" || rc=$?
            ((rc!=2)) || continue
            ((rc==0)) || exit "$rc"
            if $selected; then
                saved=$(jq -c --arg id "$(jq -r '.description' <<<"$monitor")" --arg layout "$layout" '.[$id]={layout:$layout}' <<<"$saved")
                mkdir -p "${MONITOR_SAVED%/*}"
                temporary=$(mktemp "$MONITOR_SAVED.XXXXXXXX")
                printf '%s\n' "$saved" > "$temporary"; mv -- "$temporary" "$MONITOR_SAVED"; temporary=''
            fi
        done < <(jq -c '.[]' <<<"$targets")
    fi
    temporary=$(mktemp "$runtime.XXXXXXXX")
    jq -n --argjson topology "$topology" '{topology:$topology}' > "$temporary"
    mv -- "$temporary" "$runtime"; temporary=''
)
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    set -Eeo pipefail
    trap 'rc=$?; notify-send "Display configuration failed" "Display layout could not be applied; see the session log." || :; exit "$rc"' ERR
    monitor_main "$@"
fi
