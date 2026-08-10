#!/usr/bin/env bash

preflight_runtime() {
  [[ ${BASH_VERSINFO[0]} -ge 5 ]] || die "Bash 5 or newer is required"
  mkdir -p "$LOG_ROOT" "$CONFIRM_ROOT" "$BACKUP_ROOT"
  migrate_legacy_state
}

migrate_legacy_state() {
  local legacy="$HOME/.local/share/archinstaller" old new
  [[ -d "$legacy" && ! -f "$STATE_ROOT/legacy-state-reviewed" ]] || return 0
  while read -r old new; do
    [[ -f "$legacy/$old.done" ]] && : >"$CONFIRM_ROOT/$new.done"
  done <<'EOF'
discord_setup discord
spotify_setup spotify
vscode_setup vscode
copyq_setup copyq
firefox_setup firefox
steam_setup steam
EOF
  : >"$STATE_ROOT/legacy-state-reviewed"
}

check_task() {
  local id=$1 check=${TASK_CHECK[$1]} dep rc
  TASK_REASON[$id]=""

  "$check" >/dev/null 2>&1
  rc=$?
  if ((rc == 0)); then
    TASK_STATE[$id]="done"
    return 0
  fi

  if has_flag "$id" x11 && [[ -z ${DISPLAY:-} ]]; then
    TASK_STATE[$id]="blocked"
    TASK_REASON[$id]="requires an X11 session"
    return 2
  fi
  if has_flag "$id" manual && ((NONINTERACTIVE)); then
    TASK_STATE[$id]="blocked"
    TASK_REASON[$id]="requires interactive confirmation"
    return 2
  fi
  if has_flag "$id" docker-ready && ! docker info >/dev/null 2>&1; then
    TASK_STATE[$id]="blocked"
    TASK_REASON[$id]="log out and back in for Docker group access"
    return 2
  fi
  for dep in ${TASK_DEPS[$id]}; do
    "${TASK_CHECK[$dep]}" >/dev/null 2>&1 || {
      TASK_STATE[$id]="blocked"
      TASK_REASON[$id]="waiting for $dep"
      return 2
    }
  done

  TASK_STATE[$id]="pending"
  return 1
}

refresh_status() {
  local id
  for id in "${TASK_IDS[@]}"; do check_task "$id" || true; done
}

state_symbol() {
  case ${TASK_STATE[$1]:-pending} in
    done) printf '%s✓ done%s' "$GREEN" "$NC" ;;
    running) printf '%s▶ run %s' "$BLUE" "$NC" ;;
    failed) printf '%s✗ fail%s' "$RED" "$NC" ;;
    blocked) printf '%s⊘ wait%s' "$YELLOW" "$NC" ;;
    *) printf '%s○ todo%s' "$DIM" "$NC" ;;
  esac
}

print_status_table() {
  local phase id deps
  refresh_status
  for phase in "${PHASE_IDS[@]}"; do
    printf '\n%s%s%s\n' "$BOLD" "${PHASE_LABEL[$phase]}" "$NC"
    for id in "${TASK_IDS[@]}"; do
      [[ ${TASK_PHASE[$id]} == "$phase" ]] || continue
      deps=${TASK_DEPS[$id]:--}
      printf '  %-22s %-34s ' "$id" "${TASK_LABEL[$id]}"
      state_symbol "$id"
      [[ -n ${TASK_REASON[$id]} ]] && printf '  %s' "${TASK_REASON[$id]}"
      printf '  [deps: %s]\n' "$deps"
    done
  done
}

clear_selection() {
  local id
  for id in "${TASK_IDS[@]}"; do TASK_SELECTED[$id]=0; done
}

select_with_dependencies() {
  local id=$1 dep
  [[ -n ${TASK_LABEL[$id]+x} ]] || die "unknown task: $id"
  for dep in ${TASK_DEPS[$id]}; do select_with_dependencies "$dep"; done
  TASK_SELECTED[$id]=1
}

select_task_csv() {
  local csv=$1 id old_ifs=$IFS
  IFS=,
  for id in $csv; do select_with_dependencies "$id"; done
  IFS=$old_ifs
}

select_phase() {
  local phase=$1 id
  [[ -n ${PHASE_LABEL[$phase]+x} ]] || die "unknown phase: $phase"
  for id in "${TASK_IDS[@]}"; do
    [[ ${TASK_PHASE[$id]} == "$phase" ]] && select_with_dependencies "$id"
  done
}

run_task() {
  local id=$1 action=${TASK_ACTION[$1]} logfile rc
  logfile="$LOG_ROOT/$(date +%Y%m%d-%H%M%S)-$id.log"
  TASK_STATE[$id]="running"
  printf '\n%s[%s] %s%s\n' "$BOLD" "$id" "${TASK_LABEL[$id]}" "$NC"

  if ((DRY_RUN)); then
    "$action"
    return $?
  fi

  (
    set -Eeuo pipefail
    "$action"
  ) 2>&1 | tee "$logfile"
  rc=${PIPESTATUS[0]}
  if ((rc != 0)); then
    TASK_STATE[$id]="failed"
    TASK_REASON[$id]="exit $rc; log: $logfile"
    warn "task failed: $id"
    return "$rc"
  fi

  "${TASK_CHECK[$id]}" >/dev/null 2>&1
  rc=$?
  if ((rc != 0)); then
    TASK_STATE[$id]="failed"
    TASK_REASON[$id]="post-install check failed; log: $logfile"
    warn "post-install check failed: $id"
    return 1
  fi

  TASK_STATE[$id]="done"
  success "${TASK_LABEL[$id]}"
}

run_selection() {
  local id dep blocked failed=0 progress remaining need_relogin=0 need_reboot=0
  refresh_status

  while true; do
    progress=0
    remaining=0
    for id in "${TASK_IDS[@]}"; do
      [[ ${TASK_SELECTED[$id]} == 1 ]] || continue
      [[ ${TASK_STATE[$id]} != done ]] || { TASK_SELECTED[$id]=0; continue; }
      remaining=1
      blocked=0
      for dep in ${TASK_DEPS[$id]}; do
        [[ ${TASK_STATE[$dep]} == done ]] || { blocked=1; break; }
      done
      ((blocked)) && continue

      if run_task "$id"; then
        has_flag "$id" relogin && need_relogin=1
        has_flag "$id" reboot && need_reboot=1
        TASK_SELECTED[$id]=0
      else
        failed=1
        TASK_SELECTED[$id]=0
      fi
      refresh_status
      progress=1
    done
    ((remaining == 0 || progress == 0)) && break
  done

  for id in "${TASK_IDS[@]}"; do
    if [[ ${TASK_SELECTED[$id]} == 1 ]]; then
      warn "not run: $id (${TASK_REASON[$id]:-dependency failed})"
      failed=1
    fi
  done
  ((need_relogin)) && warn "log out and back in before running tasks that need new group membership"
  ((need_reboot)) && warn "restart the laptop to apply boot and X11 configuration changes"
  return "$failed"
}
