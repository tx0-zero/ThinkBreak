#!/bin/bash

# Platform helpers for macOS and other Unix-like hosts. The functions are
# intentionally best-effort: a missing accessibility permission must never
# make an Agent hook fail.

tb_platform_name() {
  case "${OSTYPE:-}" in
    darwin*) printf 'macos\n' ;;
    *) printf 'unix\n' ;;
  esac
}

tb_capture_origin() {
  local app="${THINKBREAK_SOURCE_APP:-}"
  local window="${THINKBREAK_SOURCE_WINDOW:-}"
  local pid="${THINKBREAK_SOURCE_PID:-}"

  if [[ -z "$app" && "${OSTYPE:-}" == darwin* ]] && command -v osascript >/dev/null 2>&1; then
    app="$(osascript -e 'tell application "System Events" to get name of first process whose frontmost is true' 2>/dev/null || true)"
    window="$(osascript -e 'tell application "System Events" to get name of front window of first process whose frontmost is true' 2>/dev/null || true)"
  fi

  app="${app//$'\n'/ }"
  window="${window//$'\n'/ }"
  pid="${pid//$'\n'/ }"
  printf 'SOURCE_APP=%s\nSOURCE_WINDOW=%s\nSOURCE_PID=%s\n' "$app" "$window" "$pid"
}

tb_open_url() {
  local url="${1:-}"
  [[ -n "$url" ]] || return 0

  if [[ -n "${THINKBREAK_TEST_OPEN_LOG:-}" ]]; then
    printf '%s\n' "$url" >> "$THINKBREAK_TEST_OPEN_LOG"
    return 0
  fi

  if [[ -n "${THINKBREAK_OPEN_COMMAND:-}" ]]; then
    # A user-supplied command receives the URL as its final argument. This is
    # deliberately opt-in and is not read from a recipe file.
    "$THINKBREAK_OPEN_COMMAND" "$url" >/dev/null 2>&1 || true
    return 0
  fi

  if command -v open >/dev/null 2>&1; then
    open "$url" >/dev/null 2>&1 || true
  elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$url" >/dev/null 2>&1 || true
  fi
}

tb_restore_origin() {
  local app="${1:-}"
  local pid="${3:-}"
  [[ -n "$app" ]] || return 0

  if [[ -n "${THINKBREAK_TEST_RESTORE_LOG:-}" ]]; then
    printf '%s|%s|%s\n' "$app" "${2:-}" "$pid" >> "$THINKBREAK_TEST_RESTORE_LOG"
    return 0
  fi

  if [[ "${OSTYPE:-}" == darwin* ]] && command -v osascript >/dev/null 2>&1; then
    osascript -e "tell application \"$app\" to activate" >/dev/null 2>&1 || true
  elif command -v open >/dev/null 2>&1; then
    open -a "$app" >/dev/null 2>&1 || true
  fi
}
