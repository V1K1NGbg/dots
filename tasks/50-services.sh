#!/usr/bin/env bash

register_phase services "Services & containers"

check_ollama() {
  docker inspect -f '{{.State.Running}}' ollama 2>/dev/null | grep -qx true
}

install_ollama() {
  if ((DRY_RUN)); then
    log "docker compose up --detach"
  else
    (cd "$DOTS_ROOT" && docker compose up --detach)
  fi
}

register_task ollama services "Start Ollama container" check_ollama install_ollama "docker" "relogin docker-ready"
