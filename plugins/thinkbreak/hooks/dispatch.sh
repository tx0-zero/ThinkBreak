#!/bin/bash
set -u

event_name="${1:-}"
host_name="claude-code"
if [[ -n "${CODEX_PLUGIN_ROOT:-}" || -n "${CODEX_HOME:-}" || -n "${CODEX_THREAD_ID:-}" || "${CODEX_SHELL:-}" == "1" ]]; then
  host_name="codex"
fi

hook_bin="${THINKBREAK_HOOK_BIN:-$HOME/.local/bin/thinkbreak-hook}"
if [[ -x "$hook_bin" ]]; then
  exec "$hook_bin" "$event_name" "$host_name"
fi

printf '[ThinkBreak] hook binary not installed at %s\n' "$hook_bin" >&2
exit 0
