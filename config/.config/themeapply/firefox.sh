#!/usr/bin/env bash
# Add the dots theme to registered Firefox profiles without replacing user files.

apply_firefox() (
    set -euo pipefail
    umask 077
    local home_dir=$1 config_dir=$2 source_dir=$3 scratch temporary=''
    local root relative profile target previous name import_line
    scratch=$(mktemp -d)
    trap 'rm -f -- "$temporary"; rm -rf -- "$scratch"' EXIT
    : > "$scratch/profiles"

    for root in "$home_dir/.mozilla/firefox" "$config_dir/mozilla/firefox"; do
        [[ -f $root/profiles.ini ]] || continue
        awk '
            function emit() {
                if (!selected) return
                if (path == "" || relative !~ /^(0|1|true|false|yes|no|on|off)$/) {
                    print "Invalid Firefox profile record" > "/dev/stderr"
                    failed = 1; exit 1
                }
                print (relative ~ /^(1|true|yes|on)$/ ? 1 : 0) "\t" path
            }
            { sub(/\r$/, ""); sub(/^[ \t]+/, ""); sub(/[ \t]+$/, "") }
            /^\[/ {
                emit()
                selected = ($0 ~ /^\[Profile[^]]*\]$/)
                path = ""; relative = "1"
                next
            }
            /^[#;]/ || !selected { next }
            {
                equals = index($0, "=")
                if (!equals) next
                key = tolower(substr($0, 1, equals - 1)); sub(/[ \t]+$/, "", key)
                value = substr($0, equals + 1); sub(/^[ \t]+/, "", value)
                if (key == "path") path = value
                if (key == "isrelative") relative = tolower(value)
            }
            END { if (!failed) emit() }
        ' "$root/profiles.ini" > "$scratch/registry"
        while IFS=$'\t' read -r relative profile; do
            if [[ $relative == 1 && $profile != /* ]]; then profile=$root/$profile; fi
            [[ $profile == /* && -d $profile ]] || {
                printf 'Invalid Firefox profile: %s\n' "$profile" >&2
                exit 1
            }
            (cd -- "$profile" && pwd -P) >> "$scratch/profiles"
        done < "$scratch/registry"
    done
    [[ -s $scratch/profiles ]] || {
        echo 'Open Firefox once, close it, then rerun the Firefox setup.' >&2
        exit 1
    }
    sort -u "$scratch/profiles" > "$scratch/sorted"

    write_file() {
        local destination=$1 content=$2 backup=$1.dots-backup result
        [[ ! -L $destination && ! -L $backup && ( ! -e $destination || -f $destination ) ]] || {
            printf 'Refusing symlink or nonregular file: %s\n' "$destination" >&2
            return 1
        }
        if [[ -f $destination ]]; then
            if cmp -s -- "$destination" "$content"; then return; else result=$?; fi
            [[ $result == 1 ]] || return "$result"
            [[ -e $backup ]] || cp -p -- "$destination" "$backup"
        fi
        mkdir -p -- "${destination%/*}"
        temporary=$(mktemp "${destination}.XXXXXXXX")
        cat -- "$content" > "$temporary"
        mv -f -- "$temporary" "$destination"
        temporary=''
    }

    while IFS= read -r profile; do
        target=$profile/user.js
        previous=/dev/null
        [[ ! -e $target ]] || previous=$target
        awk '
            $0 == "// BEGIN dots transparency" { managed = 1; next }
            managed && $0 == "// END dots transparency" { managed = 0; next }
            !managed { print }
            END { if (managed) { print "Unclosed dots transparency block" > "/dev/stderr"; exit 1 } }
        ' "$previous" > "$scratch/user.js"
        {
            printf '// BEGIN dots transparency\n'
            cat -- "$source_dir/user.js"
            printf '// END dots transparency\n'
        } >> "$scratch/user.js"
        write_file "$target" "$scratch/user.js"
        for name in userChrome.css userContent.css; do
            target=$profile/chrome/$name
            previous=/dev/null
            [[ ! -e $target ]] || previous=$target
            import_line="@import url(\"dots-$name\");"
            write_file "$profile/chrome/dots-$name" "$source_dir/$name"
            if ! grep -Fxq -- "$import_line" "$previous"; then
                { printf '%s\n' "$import_line"; cat -- "$previous"; } > "$scratch/style.css"
                write_file "$target" "$scratch/style.css"
            fi
        done
        printf 'Firefox transparency configured: %s\n' "$profile"
    done < "$scratch/sorted"
)

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    apply_firefox "$HOME" "${XDG_CONFIG_HOME:-$HOME/.config}" "${BASH_SOURCE[0]%.sh}"
fi
