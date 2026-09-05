#!/usr/bin/env bash
# Convert iwd profiles to NetworkManager keyfiles using Arch ISO tools.
set -euo pipefail
umask 077
export LC_ALL=C

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# Decode only the five escapes accepted by iwd keyfiles. Never source credentials.
unescape() {
    local value=$1 char i
    REPLY=""
    for (( i=0; i<${#value}; i++ )); do
        char=${value:i:1}
        if [[ "$char" == \\ ]]; then
            i=$((i + 1))
            case "${value:i:1}" in
                s) char=' ' ;; t) char=$'\t' ;; r) char=$'\r' ;;
                n) char=$'\n' ;; \\) char='\' ;;
                *) fail "invalid escape in iwd profile" ;;
            esac
        fi
        REPLY+=$char
    done
}

escape() {
    REPLY=${1//\\/\\\\}
    REPLY=${REPLY// /\\s}
    REPLY=${REPLY//$'\t'/\\t}
    REPLY=${REPLY//$'\r'/\\r}
    REPLY=${REPLY//$'\n'/\\n}
}

boolean() {
    case "${1,,}" in
        true|1) REPLY=true ;; false|0) REPLY=false ;;
        *) fail "invalid boolean in iwd profile" ;;
    esac
}

# iwd names files with the literal SSID or = followed by its hex-encoded bytes.
profile_hex() {
    local name=${1##*/}
    name=${name%.*}
    if [[ "$name" == =* ]]; then
        REPLY=${name:1}
    else
        REPLY=$(printf '%s' "$name" | od -An -v -tx1 | tr -d ' \n')
    fi
    [[ "$REPLY" =~ ^([[:xdigit:]]{2}){1,32}$ ]] || fail "invalid SSID in iwd profile filename"
    REPLY=${REPLY,,}
}

render_profile() {
    local profile=$1 hex=$2 force=$3 type=${1##*.}
    local line section='' key value hidden autoconnect mac='' psk='' mode='' secure=false
    local digest uuid ssid='' label='' char byte i
    local -A settings=()
    [[ -f "$profile" && ! -L "$profile" ]] || fail "expected a regular saved iwd profile"
    [[ "$type" != 8021x ]] || fail "enterprise Wi-Fi is not supported"
    while IFS= read -r line || [[ -n "$line" ]]; do
        line=${line%$'\r'}
        line=${line#"${line%%[!$' \t']*}"}
        [[ -n "$line" && "$line" != \#* ]] || continue
        if [[ "$line" =~ ^\[([^][]+)\][[:blank:]]*$ ]]; then
            section=${BASH_REMATCH[1]}
        elif [[ -n "$section" && "$line" == *=* ]]; then
            key=${line%%=*}
            key=${key%"${key##*[!$' \t']}"}
            value=${line#*=}
            value=${value#"${value%%[!$' \t']*}"}
            case "$section.$key" in
                Security.EncryptedSecurity|Security.EncryptedSalt) fail "encrypted iwd credentials are not supported" ;;
                Security.PasswordIdentifier) fail "SAE password identifiers are not supported" ;;
                IPv4.*|IPv6.*|Network.*) fail "custom IP settings are not supported" ;;
            esac
            unescape "$value"
            settings["$section.$key"]=$REPLY
        else
            fail "invalid iwd profile syntax"
        fi
    done < "$profile"

    boolean "${settings[Settings.Hidden]:-false}"; hidden=$REPLY
    boolean "${settings[Settings.AutoConnect]:-true}"; autoconnect=$REPLY
    (( force == 0 )) || autoconnect=true
    boolean "${settings[Settings.AlwaysRandomizeAddress]:-false}"
    [[ "$REPLY" != true ]] || mac=random
    if [[ -n "${settings[Settings.AddressOverride]:-}" ]]; then
        mac=${settings[Settings.AddressOverride]}
        [[ "$mac" =~ ^([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}$ ]] || fail "invalid MAC address override"
    fi
    value=${settings[Settings.DisabledTransitionModes]:-}
    value=,${value//[[:blank:]]/},
    if [[ "$type" == psk ]]; then
        mode=wpa-psk
        [[ "$value" != *,personal,* ]] || mode=sae
        if [[ -n "${settings[Security.Passphrase]+present}" ]]; then
            psk=${settings[Security.Passphrase]}
            (( ${#psk} >= 8 && ${#psk} <= 63 )) || fail "invalid saved Wi-Fi passphrase length"
        else
            psk=${settings[Security.PreSharedKey]:-}
            [[ "$mode" != sae && "$psk" =~ ^[[:xdigit:]]{64}$ ]] \
                || fail "no usable saved Wi-Fi credential; reconnect with iwctl and retry"
        fi
        boolean "${settings[Settings.TransitionDisable]:-false}"; secure=$REPLY
    elif [[ "$value" == *,open,* ]]; then
        mode=owe
    fi

    for (( i=0; i<${#hex}; i+=2 )); do
        byte=${hex:i:2}
        ssid+="$((16#$byte));"
        if [[ "$byte" != 00 ]]; then
            printf -v char '%b' "\x$byte"
            label+=$char
        fi
    done
    [[ "$label" != *[![:print:]]* && -n "$label" ]] || label="Wi-Fi $hex"
    # A stable custom UUID keeps repeated conversions of the same network consistent.
    digest=$(printf '%s' "$hex.$type" | sha256sum)
    uuid=${digest:0:8}-${digest:8:4}-8${digest:13:3}-8${digest:17:3}-${digest:20:12}
    escape "$label"
    printf '[connection]\nid=%s\nuuid=%s\ntype=wifi\nautoconnect=%s\n\n' "$REPLY" "$uuid" "$autoconnect"
    printf '[wifi]\nmode=infrastructure\nssid=%s\nhidden=%s\n' "$ssid" "$hidden"
    [[ -z "$mac" ]] || printf 'cloned-mac-address=%s\n' "$mac"
    if [[ -n "$mode" ]]; then
        printf '\n[wifi-security]\nkey-mgmt=%s\n' "$mode"
        if [[ "$type" == psk ]]; then
            escape "$psk"
            printf 'psk=%s\npsk-flags=0\n' "$REPLY"
        fi
        [[ "$secure" != true ]] || printf 'pmf=3\npairwise=ccmp;\ngroup=ccmp;\n'
    fi
    printf '\n[ipv4]\nmethod=auto\n\n[ipv6]\nmethod=auto\n'
}

main() (
    local connected=0 source destination tree path response network token profile hex stage
    local count=0
    local -A active=()
    if [[ ${1:-} == --connected ]]; then connected=1; shift; fi
    [[ $# == 2 ]] || fail "Usage: bash iwd-to-networkmanager.sh [--connected] SOURCE DESTINATION"
    source=$1 destination=$2
    if (( connected )); then
        tree=$(busctl --system --timeout=10 --list tree net.connman.iwd) \
            || fail "could not query iwd; connect with iwctl and retry"
        while IFS= read -r path; do
            response=$(busctl --system --timeout=10 get-property net.connman.iwd "$path" \
                net.connman.iwd.Station ConnectedNetwork 2>/dev/null) || continue
            [[ "$response" =~ ^o\ \"(/[a-zA-Z0-9_/]*)\"$ ]] || fail "unexpected connected-network response from iwd"
            network=${BASH_REMATCH[1]}
            [[ "$network" != / ]] || continue
            # iwd's network object basename is the SSID bytes in hex plus _TYPE.
            # https://kernel.googlesource.com/pub/scm/network/wireless/iwd/+/master/src/station.c
            token=${network##*/}
            [[ "$token" =~ ^([[:xdigit:]]{2}){1,32}_(psk|open|8021x)$ ]] || fail "unsupported iwd network path"
            active["${token,,}"]=1
        done <<< "$tree"
    fi

    mkdir -p -- "$destination"
    chmod 0700 "$destination"
    stage=$(mktemp -d "$destination/.iwd.XXXXXX")
    trap 'rm -rf -- "$stage"' EXIT
    shopt -s nullglob
    for profile in "$source"/*.psk "$source"/*.open "$source"/*.8021x; do
        profile_hex "$profile"; hex=$REPLY
        token=${hex}_${profile##*.}
        if (( connected )) && [[ -z "${active[$token]:-}" ]]; then continue; fi
        render_profile "$profile" "$hex" "$connected" > "$stage/iwd-$hex.${profile##*.}.nmconnection"
        unset 'active[$token]'
        count=$((count + 1))
    done
    (( ${#active[@]} == 0 )) || fail "the connected Wi-Fi has no saved iwd profile; reconnect with iwctl and retry"
    # Publish only after all selected credentials have been validated.
    for profile in "$stage"/*.nmconnection; do
        mv -f -- "$profile" "$destination/${profile##*/}"
    done
    printf 'Prepared %d saved iwd Wi-Fi profile(s) for NetworkManager.\n' "$count"
)

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; fi
