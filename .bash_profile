#
# ~/.bash_profile
#

[[ -f ~/.bashrc ]] && . ~/.bashrc

if [[ -z $WAYLAND_DISPLAY && -z $DISPLAY ]] && [[ $(tty) = /dev/tty1 ]]; then
    profile_file="${XDG_STATE_HOME:-$HOME/.local/state}/dots/desktop-profile"
    desktop_profile=""
    [[ -r $profile_file ]] && IFS= read -r desktop_profile <"$profile_file"

    case $desktop_profile in
        hyprland)
            command -v uwsm >/dev/null 2>&1 || {
                printf 'Hyprland profile is selected, but uwsm is not installed.\n'
                return
            }
            exec uwsm start hyprland-uwsm.desktop
            ;;
        awesome)
            command -v startx >/dev/null 2>&1 || {
                printf 'Awesome profile is selected, but startx is not installed.\n'
                return
            }
            exec startx
            ;;
        *)
            printf 'No desktop profile is active. Run ./install.sh --desktop hyprland or awesome.\n'
            ;;
    esac
fi
