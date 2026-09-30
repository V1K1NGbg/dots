#!/usr/bin/env bash
set -euo pipefail
if [[ ${ROFI_RETV:-0} == 1 && ${ROFI_INFO:-} =~ ^0x[0-9a-fA-F]+$ ]]; then
    hyprctl dispatch "function() dots.focus_window('$ROFI_INFO') end" >/dev/null
else
    printf '\0prompt\x1fWindows\n'
    hyprctl clients -j | jq -r 'sort_by(.workspace.id,.class,.title)[] |
      (if .workspace.id<0 then "minimized" else (((.workspace.id-1)%10+1)|tostring) end) as $w |
      ("\($w) · \(.class) · \(.title)"|gsub("[\u0000-\u001f\u007f]";" "))+"\u0000info\u001f"+.address'
fi
