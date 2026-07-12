#!/bin/bash

thinkbreak_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}

thinkbreak_version() {
  local root="${1:-$(thinkbreak_root)}"
  tr -d '[:space:]' < "$root/VERSION"
}

find_claude_cli() {
  if [[ -n "${CLAUDE_CLI:-}" ]]; then
    if [[ -x "$CLAUDE_CLI" ]]; then
      printf '%s\n' "$CLAUDE_CLI"
      return 0
    fi
    if [[ -f "$CLAUDE_CLI" ]]; then
      printf 'node\n%s\n' "$CLAUDE_CLI"
      return 0
    fi
    printf 'CLAUDE_CLI does not exist or is not executable: %s\n' "$CLAUDE_CLI" >&2
    return 1
  fi

  if command -v claude >/dev/null 2>&1; then
    command -v claude
    return 0
  fi

  local candidate
  for candidate in \
    "$HOME/.local/lib/node_modules/@anthropic-ai/claude-code/cli.js" \
    "$HOME/.npm-global/lib/node_modules/@anthropic-ai/claude-code/cli.js" \
    "/usr/local/lib/node_modules/@anthropic-ai/claude-code/cli.js" \
    "/opt/homebrew/lib/node_modules/@anthropic-ai/claude-code/cli.js"; do
    if [[ -f "$candidate" ]]; then
      printf 'node\n%s\n' "$candidate"
      return 0
    fi
  done

  printf 'Claude Code CLI was not found. Install the official Claude Code CLI or set CLAUDE_CLI.\n' >&2
  return 1
}

run_claude_cli() {
  local -a found=()
  while IFS= read -r line; do found+=("$line"); done < <(find_claude_cli)
  if (( ${#found[@]} == 0 )); then
    return 1
  fi
  if [[ "${found[0]}" == "node" ]]; then
    node "${found[1]}" "$@"
  else
    "${found[0]}" "$@"
  fi
}
