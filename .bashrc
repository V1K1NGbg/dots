#FOR AUTO COMPLETE: (!OH MY BASH SUPPORTS IT OUT OF THE BOX!)
echo 'set completion-ignore-case On' | sudo tee -a /etc/inputrc

#FOR CTRL+BCKSPACE to delete last word: (!RESTART TERMINAL!)
echo '"\C-H":"\C-W"' | sudo tee -a /etc/inputrc

#BASH PROFILE (.bash_profile):
if [ -z "$DISPLAY" ] && [ "$XDG_VTNR" = 1 ]; then
 exec startx
fi

---

OSH_THEME="agnoster"

DISABLE_AUTO_UPDATE="true"

#ENABLE_CORRECTION="true"

COMPLETION_WAITING_DOTS="true"


echo "UwU" | cowsay -f tux | lolcat --spread=0.5

alias clear="clear && source ~/.bashrc"
alias notes="code ~/pCloudDrive/0Notes.md"
alias shutdown="shutdown now"

#Fzf
source /usr/share/fzf/completion.bash

_fzf_compgen_path() {
   fd --hidden --follow --exclude ".git" . "$1"
}

_fzf_compgen_dir() {
   fd --type d --hidden --follow --exclude ".git" . "$1"
}

#Ranger
export VISUAL=vim
export EDITOR=vim

#Rofi
export TERMINAL=/usr/bin/alacritty