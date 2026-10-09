#!/usr/bin/env bash
# Apply saved display layouts; ask with Rofi for unknown displays.
MONITOR_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
MONITOR_SAVED=${XDG_CONFIG_HOME:-$HOME/.config}/dots-monitors/profiles.json
MONITOR_LAYOUTS=(right left top bottom duplicate)

monitor_query() { hyprctl monitors all -j | jq -ce 'if type=="array" then . else error("Invalid monitor response") end'; }
monitor_lid_state() { bash "$MONITOR_ROOT/../scripts/power.sh" lid-state; }
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
    printf '%s\n' "$@" | bash "$MONITOR_ROOT/../../rofi/modi/monitors.sh" --choose "$title" 8>&-
}
monitor_positions() {
    jq -cn --arg layout "$1" --argjson internal "$2" --argjson external "$3" \
      --argjson monitors "$4" --argjson profiles "$5" '
      def nearest:
        floor as $f | if .-$f==0.5 then (if $f%2==0 then $f else $f+1 end) else round end;
      def size:
        (if (.transform//0)%2==1 then [.height,.width] else [.width,.height] end) as $s
        | [$s[] / .scale | nearest];
      def rectangle:
        size as $s | . + {x:0,y:0,w:$s[0],h:$s[1],mirrorOf:"none"};
      # Reflow every extended screen, using logical dimensions for occupied space.
      ([$internal|rectangle|.mirrorOf=(if $layout=="duplicate" then $external.name else "none" end)]
        + if $layout=="duplicate" then [$external|rectangle] else [] end) as $base |
      reduce ($monitors[] | select(.name!=$internal.name and (.disabled//false|not)
        and (.name==$external.name or (.mirrorOf//"none")=="none")
        and (.name!=$external.name or $layout!="duplicate"))) as $monitor ($base;
        ($monitor|rectangle) as $m |
        (if $m.name==$external.name then $layout else $profiles[$m.description].layout//"right" end) as $side |
        # Only screens crossing the new display row/column can block placement.
        [ .[] | select(.mirrorOf=="none" and .y<$m.h and .y+.h>0) ] as $row |
        [ .[] | select(.mirrorOf=="none" and .x<$m.w and .x+.w>0) ] as $column |
        (if $side=="left" then [($row|map(.x)|min)-$m.w,0]
         elif $side=="top" then [0,($column|map(.y)|min)-$m.h]
         elif $side=="bottom" then [0,($column|map(.y+.h)|max)]
         else [($row|map(.x+.w)|max),0] end) as $p |
        . + [$m + {x:$p[0],y:$p[1]}]) |
      .[1:]+.[0:1] | map(del(.w,.h))'
}
monitor_rule() {
    local monitor=$1 position=$2 mirror=${3:-} name width height refresh scale transform mode
    name=$(jq -r '.name' <<<"$monitor") || return
    read -r width height refresh scale transform < <(jq -r '[.width,.height,.refreshRate,.scale,(.transform//0)]|@tsv' <<<"$monitor")
    LC_NUMERIC=C printf -v mode '%sx%s@%.3f' "$width" "$height" "$refresh" || return
    printf 'hl.monitor({output=%s,disabled=false,mode=%s,position=%s,scale=%s,transform=%s,mirror=%s})' \
        "$(monitor_lua_string "$name")" "$(monitor_lua_string "$mode")" \
        "$(monitor_lua_string "$position")" "$scale" "$transform" "$(monitor_lua_string "$mirror")"
}
monitor_apply() {
    local internal=$1 external=$2 layout=$3 gather=$4 profiles=$5 positions monitor position mirror second live names tries command=''
    live=$(monitor_query) || return
    positions=$(monitor_positions "$layout" "$internal" "$external" "$live" "$profiles") || return
    second=$(jq -r '.name' <<<"$external")
    while IFS= read -r monitor; do
        position=$(jq -r '[.x,.y]|map(tostring)|join("x")' <<<"$monitor") || return
        mirror=$(jq -r 'if .mirrorOf=="none" then "" else .mirrorOf end' <<<"$monitor") || return
        command+="${command:+; }$(monitor_rule "$monitor" "$position" "$mirror")" || return
    done < <(jq -c '.[]' <<<"$positions")
    monitor_dispatch "$command" || return
    for ((tries=0; tries<50; tries++)); do
        live=$(monitor_query) || return
        names=$(jq -c 'map(.name)' <<<"$live") || return
        jq -e --argjson names "$names" 'all(.[]; .name as $name | $names|index($name)!=null)' <<<"$positions" >/dev/null || return 2 # Unplugged during selection.
        if jq -e --argjson expected "$positions" '
          INDEX(.name) as $live | all($expected[]; . as $p | $live[$p.name] as $m |
            if $p.mirrorOf!="none" then ($m.mirrorOf==$p.mirrorOf or $m.mirrorOf==($live[$p.mirrorOf].id|tostring))
            else $m.mirrorOf=="none" and [$m.x,$m.y]==[$p.x,$p.y] end)' <<<"$live" >/dev/null; then
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
    local monitor layout selected live first second gather rc lid temporary=''
    umask 077
    for arg in "$@"; do
        case $arg in --auto) auto=true;; --reload) reload=true;; *) printf 'Unknown option: %s\n' "$arg" >&2; exit 1;; esac
    done
    runtime=${XDG_RUNTIME_DIR:?}/dots-monitors-${HYPRLAND_INSTANCE_SIGNATURE:?}
    exec 8>"$runtime.lock"; flock -x 8
    trap '[[ -z ${temporary:-} ]] || rm -f -- "$temporary"' EXIT
    sleep .3
    monitors=$(monitor_query)
    topology=$(jq -c '[.[]|.name+":"+.description]|sort' <<<"$monitors")
    previous=$(monitor_read "$runtime")
    internal=$(jq -c '[.[]|select(.name|test("^(eDP-|LVDS-|DSI-)"))][0]//null' <<<"$monitors")
    external=$(jq -c --argjson internal "$internal" '[.[]|select(.name!=$internal.name and (.disabled//false|not))]' <<<"$monitors")
    lid=$(monitor_lid_state)
    if [[ $internal != null && $lid == closed && $(jq length <<<"$external") -gt 0 ]]; then
        if [[ $(jq -r '.disabled//false' <<<"$internal") == false ]]; then
            temporary=$(mktemp "$runtime.panel.XXXXXXXX")
            printf '%s\n' "$internal" > "$temporary"; mv "$temporary" "$runtime.panel"; temporary=''
            monitor_dispatch "hl.monitor({output=$(monitor_lua_string "$(jq -r .name <<<"$internal")"),disabled=true})"
        fi
        monitor_dispatch "dots.set_primary($(monitor_lua_string "$(jq -r '.[0].name' <<<"$external")"), false)"
        exit 0
    fi
    if [[ $internal != null && $(jq -r '.disabled//false' <<<"$internal") == true && ( -f $runtime.panel || $(jq length <<<"$external") == 0 ) ]]; then
        if [[ -f $runtime.panel ]]; then internal=$(monitor_read "$runtime.panel"); fi
        if jq -e '.width>0 and .height>0 and .scale>0' <<<"$internal" >/dev/null; then
            monitor_dispatch "$(monitor_rule "$internal" 0x0)"
        else
            monitor_dispatch "hl.monitor({output=$(monitor_lua_string "$(jq -r .name <<<"$internal")"),disabled=false,mode=\"preferred\",position=\"auto\",scale=1})"
            for ((rc=0; rc<50; rc++)); do
                internal=$(monitor_query | jq -c '[.[]|select(.name|test("^(eDP-|LVDS-|DSI-)"))][0]//null')
                if jq -e '.width>0 and .height>0 and (.disabled|not)' <<<"$internal" >/dev/null; then break; fi
                sleep .1
            done
            [[ $rc -lt 50 ]] || { echo 'Internal display did not recover.' >&2; exit 1; }
        fi
        reload=true
    fi
    if $auto && ! $reload && [[ $(jq -c '.topology' <<<"$previous") == "$topology" ]]; then exit 0; fi
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
            rc=0; monitor_apply "$first" "$second" "$layout" "$gather" "$profiles" || rc=$?
            ((rc!=2)) || continue
            ((rc==0)) || exit "$rc"
            if $selected; then
                saved=$(jq -c --arg id "$(jq -r '.description' <<<"$monitor")" --arg layout "$layout" '.[$id]={layout:$layout}' <<<"$saved")
                profiles=$(jq -c --argjson saved "$saved" '.+$saved' <<<"$profiles")
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
    set -uo pipefail
    # Report once after the fail-fast subshell, not from every nested ERR trap.
    monitor_main "$@"
    rc=$?
    if ((rc!=0)); then
        notify-send "Display configuration failed" "Display layout could not be applied; see the session log." || :
    fi
    exit "$rc"
fi
