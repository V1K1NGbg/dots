#!/usr/bin/env bash
# Sourced by launcher.sh; uses the shared menu helpers.
windows_menu() {
    local clients address
    while :; do
        clients=$(hyprctl clients -j 2>/dev/null | jq -r 'sort_by(.workspace.id<0,.workspace.id,.class,.title)[] |
          (if .workspace.id<0 then "minimized" else "ws\((.workspace.id-1)%10+1)" end) as $w |
          .address+"\t"+("\($w) · \(.class) · \(.title)"|gsub("[\u0000-\u001f\u007f]";" "))') || {
            info Windows 'Hyprland is unavailable.' || :; return 10; }
        [[ -n $clients ]] || { info Windows 'No open windows.' || :; return 10; }
        # Digits pick rows like every other page.
        choose Windows '' list < <(cut -f2- <<<"$clients") || return
        [[ $CHOICE == refresh ]] && continue
        break
    done
    address=$(sed -n "$((CHOICE+1))p" <<<"$clients"); address=${address%%$'\t'*}
    [[ $address =~ ^0x[0-9a-fA-F]+$ ]] || return 10
    hyprctl dispatch "function() dots.focus_window('$address') end" >/dev/null
}
