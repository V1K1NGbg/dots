#!/usr/bin/env bash
set -euo pipefail
case ${1:-} in
    '') [[ $# == 0 ]] || exit 2 ;;
    --ocr) [[ $# == 1 ]] || exit 2 ;;
    *) printf 'Usage: %s [--ocr]\n' "$0" >&2; exit 2 ;;
esac
notice() { notify-send 'Screen text' "$1" || :; }
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
geometry=$(slurp) || exit 0
[[ -n $geometry ]] || exit 0
capture=$(mktemp "${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/dots-screenshot.XXXXXXXX")
trap 'rm -f -- "$capture"' EXIT
if ! grim -g "$geometry" "$capture"; then
    [[ ${1:-} != --ocr ]] || notice 'Could not capture the selected area.'
    exit 1
fi
if [[ ${1:-} == --ocr ]]; then
    if ! text=$(tesseract "$capture" stdout -l eng+bul --psm 11); then
        notice 'Text recognition failed. Check Tesseract and its English/Bulgarian language data.'
        exit 1
    fi
    if [[ ! $text =~ [^[:space:]] ]]; then
        notice 'No text found in the selected area.'
        exit 0
    fi
    if ! printf '%s' "$text" | wl-copy --type 'text/plain;charset=utf-8'; then
        notice 'Could not copy the recognized text.'
        exit 1
    fi
    notice 'Recognized text copied.'
    exit 0
fi
# Capture succeeded. Playback failure must not prevent opening the editor.
bash "$root/sound.sh" screenshot >/dev/null 2>&1 &
swappy -f "$capture"
