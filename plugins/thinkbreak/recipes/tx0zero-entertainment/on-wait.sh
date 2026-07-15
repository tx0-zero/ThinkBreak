#!/bin/bash
set -u
[[ -n "${THINKBREAK_WAIT_URL:-}" ]] || exit 0
if command -v open >/dev/null 2>&1; then open "$THINKBREAK_WAIT_URL" >/dev/null 2>&1 || true
elif command -v xdg-open >/dev/null 2>&1; then xdg-open "$THINKBREAK_WAIT_URL" >/dev/null 2>&1 || true
fi
