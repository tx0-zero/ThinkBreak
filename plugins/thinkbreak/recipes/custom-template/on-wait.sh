#!/bin/bash
set -u
# Replace this with your own action. The URL is available as
# THINKBREAK_WAIT_URL. Do not put credentials or task content in this script.
if [[ -n "${THINKBREAK_WAIT_URL:-}" ]]; then
  if command -v open >/dev/null 2>&1; then open "$THINKBREAK_WAIT_URL" >/dev/null 2>&1 || true
  elif command -v xdg-open >/dev/null 2>&1; then xdg-open "$THINKBREAK_WAIT_URL" >/dev/null 2>&1 || true
  fi
fi
