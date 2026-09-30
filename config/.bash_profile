#
# ~/.bash_profile
#

[[ -f ~/.bashrc ]] && . ~/.bashrc

if [[ -z $WAYLAND_DISPLAY && -z $DISPLAY ]] && [[ $(tty) = /dev/tty1 ]] && uwsm check may-start; then
    exec uwsm start hyprland.desktop
fi
