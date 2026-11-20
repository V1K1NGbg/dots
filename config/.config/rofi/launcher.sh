#!/usr/bin/env bash
set -uo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/modi/common.sh"
for module in run files ai time music network power clipboard windows calc; do source "$ROOT/modi/$module.sh"; done
main() {
    exec 9>"$RUNTIME/launcher.lock"; flock -n 9 || return 0
    cpu_snapshot
    menu_setup
    local mode=${1:-run} rc
    while :; do
        rc=0
        case $mode in
            run|apps)
                # Super+R: Escape closes, Tab opens the menu.
                run_menu || rc=$?
                ((rc==10)) || return 0
                mode=menu; continue;;
            menu|home)
                choose Menu "$(dashboard)" home < <(home_rows) || return 0
                mode=${MODES[${CHOICE#key:}]}
                continue;;
            files) files_menu || rc=$?;; ai) ai_menu || rc=$?;; time) time_menu || rc=$?;; music) music_menu || rc=$?;;
            power) power_menu || rc=$?;; network|wifi|bluetooth) network_menu || rc=$?;;
            clipboard|autocorrector) clipboard_menu || rc=$?;;
            window) windows_menu || rc=$?;;
            calc) calc_menu || rc=$?;;
            keys) choose Keybindings '' list < <("$ROOT/modi/keybinds.sh" --list) || rc=$?;;
            *) info Rofi 'Unknown page';;
        esac
        if ((rc==1 || rc==10)); then mode=menu; continue; fi
        return 0
    done
}
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then main "$@"; fi
