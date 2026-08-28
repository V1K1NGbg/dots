export OSH="$HOME/.oh-my-bash"
OSH_THEME="agnoster"
DISABLE_AUTO_UPDATE="true"
#ENABLE_CORRECTION="true"
COMPLETION_WAITING_DOTS="true"

if [[ -r "$OSH/oh-my-bash.sh" ]]; then
  source "$OSH/oh-my-bash.sh"
fi

echo "UwU" | cowsay -f tux | lolcat --spread=0.5

alias clear="clear && source ~/.bashrc"
alias notes="code -n ~/pCloudDrive/0Notes.md"
alias config="code -n ~/dots"
alias shutdown="systemctl poweroff"

alias lgit="lazygit"

hgrep() {
  history | awk '{$1=""; sub(/^[ \t]+/, ""); print}' | grep "$1" --color=always -B "${2:-0}" -A "${3:-0}"
}

show() {
  for item in "$@"; do
    if [ -f "$item" ]; then
      printf '\n\033[1;36mFILE: %s\033[0m' "$item"
      printf '\n\033[34m%s\033[0m\n\n' "$(printf '%*s' $(( $(tput cols) )) '' | tr ' ' '-')"
      cat "$item"
    elif [ -d "$item" ]; then
      printf '\n\033[1;36mDIRECTORY: %s\033[0m' "$item"
      printf '\n\033[34m%s\033[0m\n\n' "$(printf '%*s' $(( $(tput cols) )) '' | tr ' ' '-')"
      ll "$item"
    else
      printf '\033[1;31mERROR: Not a file or directory: %s\033[0m\n' "$item"
    fi
  done
}

lastline() {
  declare -a lines
  line_count=0
  first_print=1
  prev_lines=0
  [ "$#" = 1 ] || { >&2 echo "number needed"; exit 9; }
  nlines=$1

  printf "\033[?25l"

  trap 'printf "\033[?25h"; exit' INT TERM EXIT

  while IFS= read -r line; do
    if [ "$line_count" -lt "$nlines" ]; then
      lines[line_count]=$line
      line_count=$((line_count + 1))
    else
      for ((i=1; i<nlines; i++)); do
        lines[$((i-1))]=${lines[i]}
      done
      lines[$((nlines-1))]=$line
    fi
    
    if [ "$first_print" = 0 ]; then
      printf "\033[%dA" "$prev_lines"
      for ((i=0; i<line_count; i++)); do
        printf "\033[K%s\n" "${lines[i]}"
      done
      for ((i=line_count; i<prev_lines; i++)); do
        printf "\033[K\n"
      done
      if [ "$line_count" -lt "$prev_lines" ]; then
        printf "\033[%dA" "$((prev_lines - line_count))"
      fi
    else
      first_print=0
      for ((i=0; i<line_count; i++)); do
        printf '%s\n' "${lines[i]}"
      done
    fi
    prev_lines=$line_count
  done

  printf "\033[?25h"
}

#Fzf
# eval "$(fzf --bash)"
# source /usr/share/fzf/completion.bash

# export FZF_COMPLETION_TRIGGER=''

# _fzf_compgen_path() {
#    fd --hidden --follow --exclude ".git" . "$1"
# }

# _fzf_compgen_dir() {
#    fd --type d --hidden --follow --exclude ".git" . "$1"
# }

# source $HOME/fzf-tab-completion/bash/fzf-bash-completion.sh
# bind -x '"\t": fzf_bash_completion'

# _fzf_bash_completion_loading_msg() { echo "${PS1@P}${READLINE_LINE}"; }

# complete -d cd

#Ranger
export VISUAL=vim
export EDITOR=vim

#Rofi
export TERMINAL=alacritty
