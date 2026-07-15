#!/bin/bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/runtime.sh"

event="${1:-}"
host="${2:-${THINKBREAK_HOST:-}}"
session_id="${3:-${THINKBREAK_SESSION_ID:-}}"

if [[ -z "$host" ]]; then
  if [[ -n "${CODEX_PLUGIN_ROOT:-}" || -n "${CODEX_HOME:-}" || -n "${CODEX_THREAD_ID:-}" ]]; then
    host=codex
  elif [[ -n "${CLAUDE_PLUGIN_ROOT:-}" || -n "${CLAUDE_CODE_ENTRYPOINT:-}" ]]; then
    host=claude-code
  else
    host=unknown
  fi
fi

# Provider hooks normally provide JSON on stdin. Session IDs are optional; the
# dispatcher has a host-level fallback when a provider does not expose one.
if [[ "$event" != worker && "$event" != status && "$event" != enable && "$event" != disable && "$event" != use && "$event" != set-delay && "$event" != set-timeout && "$event" != validate && "$event" != test && "$event" != init ]]; then
  input="$(cat 2>/dev/null || true)"
  if [[ -z "$session_id" && -n "$input" && -n "$(command -v python3 || true)" ]]; then
    session_id="$(printf '%s' "$input" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("session_id") or d.get("sessionId") or "")' 2>/dev/null || true)"
  fi
fi

tb_dispatch "$event" "$host" "$session_id" "${4:-}"
exit 0
