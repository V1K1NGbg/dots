#!/usr/bin/env bash

set -euo pipefail

hyprctl binds | awk '
function has_bit(mask, bit) {
    return int(mask / bit) % 2
}

function emit(    modifiers, display_key) {
    if (description == "" || submap != "") {
        return
    }

    modifiers = ""
    if (has_bit(modmask, 64)) modifiers = modifiers "Super+"
    if (has_bit(modmask, 4))  modifiers = modifiers "Ctrl+"
    if (has_bit(modmask, 8))  modifiers = modifiers "Alt+"
    if (has_bit(modmask, 1))  modifiers = modifiers "Shift+"

    display_key = key
    sub(/^mouse:/, "Mouse ", display_key)
    printf "%-26s %s\n", modifiers display_key, description
}

/^bind/ {
    emit()
    modmask = 0
    submap = ""
    key = ""
    description = ""
    next
}

$1 == "modmask:" {
    modmask = $2
    next
}

$1 == "submap:" {
    submap = $2
    next
}

$1 == "key:" {
    key = $2
    next
}

$1 == "description:" {
    sub(/^[[:space:]]*description:[[:space:]]*/, "")
    description = $0
    next
}

END {
    emit()
}
' | rofi -dmenu -i -p "Keybindings" > /dev/null
