#!/usr/bin/env bash
# Copy installed, repo-managed settings back into config/ for Git review.

regular_file() {
    local path=$1 remaining=$2 part
    while :; do
        if [[ -L $path ]]; then
            printf 'Skipped symlink: %s\n' "$path"
            return 1
        fi
        if [[ -d $path && ! -x $path ]]; then
            printf 'Failed: cannot read directory: %s\n' "$path" >&2
            return 2
        fi
        [[ -n $remaining ]] || break
        part=${remaining%%/*}
        if [[ $remaining == */* ]]; then remaining=${remaining#*/}; else remaining=; fi
        path=$path/$part
    done
    if [[ ! -f $path ]]; then
        printf 'Skipped missing/nonregular file: %s\n' "$path"
        return 1
    fi
    if [[ ! -r $path ]]; then
        printf 'Failed: cannot read file: %s\n' "$path" >&2
        return 2
    fi
}

backup() (
    set -euo pipefail
    local root=$1 home_dir=$2 etc_dir=$3 scratch temporary='' name relative target base source result
    local failed=0 updated=0
    scratch=$(mktemp -d)
    trap 'rm -f -- "$temporary"; rm -rf -- "$scratch"' EXIT
    git -C "$root" ls-files -z -- config/ > "$scratch/tracked"

    while IFS= read -r -d '' name; do
        relative=${name#config/}
        target=$root/$name
        case $relative in
            # These exports belonged to the retired Code helper, not live settings.
            '.config/Code - OSS/'*'/dots-state.json'|'.config/Code - OSS/dots-profiles.json')
                printf 'Skipped export: %s\n' "$name"; continue ;;
            system/pam.d/dots-hyprlock) base=$etc_dir; source=pam.d/dots-hyprlock ;;
            system/logind/60-dots-power.conf) base=$etc_dir; source=systemd/logind.conf.d/60-dots-power.conf ;;
            system/sleep/60-dots-power.conf) base=$etc_dir; source=systemd/sleep.conf.d/60-dots-power.conf ;;
            system/pacman-hooks/90-dracut-install.hook) base=$etc_dir; source=pacman.d/hooks/90-dracut-install.hook ;;
            .*) base=$home_dir; source=$relative ;;
            nemo_config) base=$scratch; source=nemo ;;
            *) printf 'Skipped unsupported mapping: %s\n' "$name"; continue ;;
        esac
        regular_file "$root" "$name" || {
            result=$?; [[ $result != 2 ]] || failed=1; continue
        }
        if [[ $relative == nemo_config ]]; then
            if ! dconf dump /org/nemo/ > "$scratch/nemo"; then
                printf 'Failed: exporting Nemo settings\n' >&2
                failed=1; continue
            fi
            if ! grep -q '[^[:space:]]' "$scratch/nemo"; then
                printf 'Skipped empty Nemo settings: %s\n' "$name"
                continue
            fi
        fi
        regular_file "$base" "$source" || {
            result=$?; [[ $result != 2 ]] || failed=1; continue
        }
        if cmp -s -- "$base/$source" "$target"; then
            continue
        else
            result=$?
            if [[ $result != 1 ]]; then
                printf 'Failed: comparing %s\n' "$name" >&2
                failed=1; continue
            fi
        fi
        if temporary=$(mktemp "${target%/*}/.${target##*/}.XXXXXXXX") &&
            cat -- "$base/$source" > "$temporary" &&
            chmod --reference="$target" -- "$temporary" &&
            mv -fT -- "$temporary" "$target"; then
            temporary=''
            printf 'Updated: %s\n' "$name"
            updated=$((updated + 1))
        else
            printf 'Failed: copying %s\n' "$name" >&2
            failed=1
            rm -f -- "$temporary"
            temporary=''
        fi
    done < "$scratch/tracked"
    printf 'Updated %s file(s). Review with git diff and git diff --cached.\n' "$updated"
    exit "$failed"
)

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    [[ $# == 0 ]] || { printf 'Usage: bash backup.sh\n' >&2; exit 2; }
    root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd) || exit 1
    backup "$root" "$HOME" /etc
fi
