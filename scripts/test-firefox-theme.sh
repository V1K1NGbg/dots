#!/usr/bin/env bash
# Check discovery, preservation, backups, repeat installation and failure safety.
set -euo pipefail

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
theme=$repo/config/.config/themeapply/firefox
scratch=$(mktemp -d)
trap 'rm -rf -- "$scratch"' EXIT
home_dir=$scratch/home
legacy=$home_dir/.mozilla/firefox
modern=$home_dir/.config/mozilla/firefox
profiles=("$legacy/a.default" "$modern/b.default" "$home_dir/custom profile")

apply_theme() {
    # A separate shell preserves errexit when a test expects a nonzero status.
    bash -c 'source "$1"; apply_firefox "$2" "$2/.config" "$3"' \
        _ "$theme.sh" "$home_dir" "$theme" > "$scratch/output" 2>&1
}

if apply_theme; then echo 'Accepted missing profiles' >&2; exit 1; fi
grep -q 'Open Firefox once' "$scratch/output"
for profile in "${profiles[@]}"; do
    mkdir -p "$profile/chrome"
    printf 'user_pref("my.setting", "keep me");\n' > "$profile/user.js"
    printf '// Firefox owns this file\n' > "$profile/prefs.js"
    printf '/* keep my CSS */\n' > "$profile/chrome/userChrome.css"
done
printf '[Profile0]\nIsRelative=1\nPath=a.default\n[Profile1]\nPath=%s\nIsRelative=0\n' \
    "${profiles[2]}" > "$legacy/profiles.ini"
printf '[General]\r\nStartWithLastProfile=1\r\n[Profile0]\r\nPath=b.default\r\n[Profile1]\r\nIsRelative=0\r\nPath=%s\r\n' \
    "${profiles[2]}" > "$modern/profiles.ini"
apply_theme
[[ $(grep -c 'Firefox transparency configured:' "$scratch/output") == 3 ]]
for profile in "${profiles[@]}"; do
    grep -Fxq 'user_pref("my.setting", "keep me");' "$profile/user.js"
    [[ $(grep -c '// BEGIN dots transparency' "$profile/user.js") == 1 ]]
    [[ $(cat "$profile/user.js.dots-backup") == 'user_pref("my.setting", "keep me");' ]]
    [[ $(cat "$profile/prefs.js") == '// Firefox owns this file' ]]
    grep -Fxq '/* keep my CSS */' "$profile/chrome/userChrome.css"
    for name in userChrome.css userContent.css; do
        cmp "$profile/chrome/dots-$name" "$theme/$name"
    done
done
cp -pR "$home_dir" "$scratch/before"
apply_theme
diff -r "$scratch/before" "$home_dir"
while IFS= read -r -d '' file; do
    original=$scratch/before/${file#"$home_dir/"}
    [[ ! $file -nt $original && ! $original -nt $file ]]
done < <(find "$home_dir" -type f -print0)

# Invalid registries must fail before changing any profile.
printf '[Profile2]\nIsRelative=0\nPath=relative/path\n' >> "$modern/profiles.ini"
if apply_theme; then echo 'Accepted invalid profile' >&2; exit 1; fi
cp "$scratch/before/.config/mozilla/firefox/profiles.ini" "$modern/profiles.ini"
diff -r "$scratch/before" "$home_dir"

printf 'keep this too\n' > "$scratch/external.js"
rm -- "${profiles[0]}/user.js"
ln -s "$scratch/external.js" "${profiles[0]}/user.js"
if apply_theme; then echo 'Accepted symlinked user.js' >&2; exit 1; fi
grep -q 'symlink' "$scratch/output"
[[ $(cat "$scratch/external.js") == 'keep this too' ]]
rm -- "${profiles[0]}/user.js"
printf '// BEGIN dots transparency\nkeep unfinished block\n' > "${profiles[0]}/user.js"
if apply_theme; then echo 'Accepted unfinished managed block' >&2; exit 1; fi
grep -q 'Unclosed dots transparency block' "$scratch/output"
grep -q 'keep unfinished block' "${profiles[0]}/user.js"

echo 'Firefox theme checks passed'
