#!/usr/bin/env bash

TUI_CURSOR=0
TUI_SCROLL=0
TUI_MESSAGE=""

tui_restore() {
  tput cnorm 2>/dev/null || true
  printf '%s' "$NC"
}

tui_draw() {
  local rows visible end i id phase selected=0 done=0
  rows=$(tput lines 2>/dev/null || printf 24)
  visible=$((rows - 11))
  ((visible < 5)) && visible=5
  end=$((TUI_SCROLL + visible - 1))
  ((end >= ${#TASK_IDS[@]})) && end=$((${#TASK_IDS[@]} - 1))

  for id in "${TASK_IDS[@]}"; do
    [[ ${TASK_SELECTED[$id]} == 1 ]] && ((selected++)) || true
    [[ ${TASK_STATE[$id]} == done ]] && ((done++)) || true
  done

  tput clear 2>/dev/null || printf '\033[2J\033[H'
  printf '%s%sDOTS INSTALLER%s  profile: %s\n' "$BOLD" "$CYAN" "$NC" "$DESKTOP_PROFILE"
  printf 'Done %d/%d  Selected %d\n' "$done" "${#TASK_IDS[@]}" "$selected"
  printf '%s────────────────────────────────────────────────────────────────────────%s\n' "$DIM" "$NC"

  for ((i=TUI_SCROLL; i<=end; i++)); do
    id=${TASK_IDS[$i]}
    phase=${PHASE_LABEL[${TASK_PHASE[$id]}]}
    if ((i == TUI_CURSOR)); then printf '%s▶%s ' "$CYAN" "$NC"; else printf '  '; fi
    if [[ ${TASK_SELECTED[$id]} == 1 ]]; then
      printf '[%s●%s] ' "$YELLOW" "$NC"
    else
      printf '[%s○%s] ' "$DIM" "$NC"
    fi
    printf '%-18.18s %-30.30s ' "$phase" "${TASK_LABEL[$id]}"
    state_symbol "$id"
    printf '\n'
  done

  printf '%s────────────────────────────────────────────────────────────────────────%s\n' "$DIM" "$NC"
  id=${TASK_IDS[$TUI_CURSOR]}
  printf '%s%s%s' "$BOLD" "$id" "$NC"
  [[ -n ${TASK_REASON[$id]} ]] && printf ' — %s' "${TASK_REASON[$id]}"
  printf '\n'
  printf '%sDependencies:%s %s  %sFlags:%s %s\n' "$DIM" "$NC" "${TASK_DEPS[$id]:-none}" "$DIM" "$NC" "${TASK_FLAGS[$id]:-none}"
  [[ -n "$TUI_MESSAGE" ]] && printf '%s\n' "$TUI_MESSAGE"
  printf '↑↓ navigate  SPACE toggle  A all  U unfinished  P phase  N none  R refresh\n'
  printf '%sENTER run%s  %sQ quit%s\n' "$GREEN" "$NC" "$RED" "$NC"
}

tui_adjust_scroll() {
  local rows visible
  rows=$(tput lines 2>/dev/null || printf 24)
  visible=$((rows - 11)); ((visible < 5)) && visible=5
  ((TUI_CURSOR < TUI_SCROLL)) && TUI_SCROLL=$TUI_CURSOR
  ((TUI_CURSOR >= TUI_SCROLL + visible)) && TUI_SCROLL=$((TUI_CURSOR - visible + 1))
}

run_tui() {
  local key seq id phase i
  [[ -t 0 && -t 1 ]] || die "interactive mode requires a terminal; use --list or --task"
  refresh_status
  trap tui_restore EXIT INT TERM
  tput civis 2>/dev/null || true

  while true; do
    TUI_MESSAGE=""
    tui_draw
    IFS= read -rsn1 key
    if [[ $key == $'\e' ]]; then
      IFS= read -rsn2 -t 0.1 seq || true
      case "$seq" in
        '[A') ((TUI_CURSOR > 0)) && ((TUI_CURSOR--)) || true ;;
        '[B') ((TUI_CURSOR < ${#TASK_IDS[@]} - 1)) && ((TUI_CURSOR++)) || true ;;
      esac
      tui_adjust_scroll
    elif [[ $key == ' ' ]]; then
      id=${TASK_IDS[$TUI_CURSOR]}
      if [[ ${TASK_SELECTED[$id]} == 1 ]]; then
        TASK_SELECTED[$id]=0
      else
        select_with_dependencies "$id"
      fi
    elif [[ ${key,,} == a ]]; then
      for id in "${TASK_IDS[@]}"; do select_with_dependencies "$id"; done
    elif [[ ${key,,} == u ]]; then
      clear_selection
      for id in "${TASK_IDS[@]}"; do
        [[ ${TASK_STATE[$id]} != done ]] && select_with_dependencies "$id"
      done
    elif [[ ${key,,} == p ]]; then
      id=${TASK_IDS[$TUI_CURSOR]}
      phase=${TASK_PHASE[$id]}
      for i in "${TASK_IDS[@]}"; do
        [[ ${TASK_PHASE[$i]} == "$phase" ]] && select_with_dependencies "$i"
      done
    elif [[ ${key,,} == n ]]; then
      clear_selection
    elif [[ ${key,,} == r ]]; then
      refresh_status
    elif [[ ${key,,} == q ]]; then
      break
    elif [[ -z $key ]]; then
      tput cnorm 2>/dev/null || true
      tput clear 2>/dev/null || true
      run_selection || true
      read -r -p 'Press Enter to return to the installer...' _
      tput civis 2>/dev/null || true
    fi
  done
}
