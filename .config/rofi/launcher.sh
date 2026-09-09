#!/usr/bin/env bash
set -uo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/modi/common.sh"
for module in run files ai time music network power; do source "$ROOT/modi/$module.sh"; done
main() {
    exec 9>"$RUNTIME/launcher.lock"; flock -n 9 || return 0
    menu_setup
    local mode=${1:-run} run_origin=direct i rc
    while :; do
        rc=0
        case $mode in
            apps|run) run_menu "$run_origin" || rc=$?;;
            menu|home)
                run_origin=menu
                choose Menu "$(dashboard)" home < <(home_rows) || return 0
                i=${CHOICE#key:}
                if ((i==12)); then mode=run; else mode=${MODES[i]}; fi
                continue;;
            files) files_menu;; ai) ai_menu || rc=$?;; time) time_menu || rc=$?;; music) music_menu || rc=$?;;
            outputs) outputs_menu || rc=$?;; power) power_menu || rc=$?;;
            wifi|bluetooth) network_menu "$mode" || rc=$?;;
            autocorrector) live_menu autocorrect || rc=$?;;
            calc) rofi_native Escape -modi calc -show calc -display-calc Calculator -no-persist-history || rc=$?;;
            keys) choose Keybindings '' list < <("$ROOT/modi/keybinds.sh" --list) || rc=$?;;
            window) rofi_native Escape -modi "window:$ROOT/modi/windows.sh" -show window || rc=$?;;
            clipboard|power-mode) rofi_native Escape -modi "$mode:$ROOT/modi/$mode.sh" -show "$mode" || rc=$?;;
            *) info Rofi 'Unknown page';;
        esac
        if [[ $mode == run || $mode == apps ]] && [[ $run_origin == direct ]] && ((rc==1)); then return 0; fi
        if ((rc==1 || rc==10)); then mode=menu; continue; fi
        return 0
    done
}
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then main "$@"; fi
