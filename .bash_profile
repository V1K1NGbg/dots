#
# ~/.bash_profile
#

[[ -f ~/.bashrc ]] && . ~/.bashrc

if [[ -z $DISPLAY ]] && [[ $(tty) = /dev/tty1 ]]; then
    if read -t 3 -n 1 -p "(1-3) 1-Awesome, 2-Hyperland, 3-Terminal: " choice; then
        echo
    else
        choice=1
        echo -e "\nDefaulting to option 1..."
    fi

    case $choice in
        1)
            echo "Starting X11..."
            exec startx
            ;;
        2)
            echo "Starting Hyperland with Wayland..."
            exec hyperland
            ;;
        3)
            echo "Staying in terminal mode."
            ;;
        *)
            echo "Invalid choice. Staying in terminal mode."
            ;;
    esac
fi
