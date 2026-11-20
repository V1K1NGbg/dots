#!/usr/bin/env bash
# Sourced by launcher.sh. Session actions, caffeine, power mode and brightness
# on one page; toggles and levels keep the page open on the same row.
# Confirmations show a single row; Escape is the way back.
power_confirm() { choose "$1?" "$2 Press Escape to cancel." list <<<"$1 now" && [[ $CHOICE == 0 ]]; }
power_menu() {
    local error caffeine selected=0 rows actions action profiles active profile label status device percent='' message
    while :; do
        caffeine=Off; [[ ! -f ${XDG_RUNTIME_DIR:?}/dots-power/caffeine ]] || caffeine=On
        rows=('Lock screen' Suspend Reboot 'Shut down' "Caffeine: $caffeine")
        actions=(lock suspend reboot poweroff caffeine)
        message=''
        if command -v powerprofilesctl >/dev/null && profiles=$(powerprofilesctl list 2>/dev/null); then
            active=$(powerprofilesctl get 2>/dev/null) || active=
            rows+=('## Power mode'); actions+=('')
            for profile in power-saver balanced performance; do
                grep -Eq "^[[:space:]*]+$profile:$" <<<"$profiles" || continue
                case $profile in power-saver) label='Power saver';; balanced) label=Balanced;; performance) label=Performance;; esac
                if [[ $profile == "$active" ]]; then rows+=("● $label"); message="Power mode: $label"; else rows+=("○ $label"); fi
                actions+=("mode:$profile")
            done
        fi
        if status=$(brightnessctl --class=backlight --machine-readable info 2>/dev/null); then
            IFS=, read -r device _ _ percent _ <<<"$status"
        fi
        rows+=('## Display' 'Display layout'); actions+=('' displays)
        if [[ -n ${percent:-} ]]; then
            rows+=('Brightness +5%' 'Brightness −5%'); actions+=("light:5%+" "light:5%-")
            message+="${message:+ · }Brightness: $percent"
        fi
        choose 'Power & Display' "$message" list -selected-row "$selected" < <(printf '%s\n' "${rows[@]}") || return
        [[ $CHOICE == refresh ]] && continue
        action=${actions[CHOICE]:-}; selected=$CHOICE
        case $action in
            lock) hyprctl dispatch 'hl.dsp.exec_cmd("hyprlock")' >/dev/null; return;;
            suspend) power_confirm Suspend 'Lock and suspend this computer.' || continue
                     error=$(bash "$ROOT/../hypr/scripts/power.sh" suspend 2>&1) || info Suspend "$error"; return;;
            reboot) power_confirm Reboot 'Unsaved work in open apps will be lost.' || continue
                    systemctl reboot; return;;
            poweroff) power_confirm 'Shut down' 'Unsaved work in open apps will be lost.' || continue
                      systemctl poweroff; return;;
            # Same picker as Super+Ctrl+Shift+P; closes the launcher.
            displays) exec bash "$ROOT/../hypr/monitors/monitors.sh" 9>&-;;
            caffeine) error=$(bash "$ROOT/../hypr/scripts/power.sh" caffeine 2>&1) || info Caffeine "$error" || :;;
            mode:*) error=$(powerprofilesctl set "${action#mode:}" 2>&1) || info 'Power mode' "${error:-Permission was denied.}" || :;;
            light:*) error=$(brightnessctl --class=backlight --device="$device" set "${action#light:}" 2>&1) ||
                         info Brightness "Could not change screen brightness: $error" || :;;
        esac
    done
}
