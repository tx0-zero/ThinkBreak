#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DISPATCH="$ROOT/plugins/thinkbreak/hooks/dispatch.sh"
PLUGIN="$ROOT/plugins/thinkbreak"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export THINKBREAK_HOME="$TMP/home"
export THINKBREAK_PLUGIN_ROOT="$PLUGIN"
export THINKBREAK_SOURCE_APP="Test Agent"
export THINKBREAK_SOURCE_WINDOW="Test Window"
export THINKBREAK_SOURCE_PID="42"
mkdir -p "$THINKBREAK_HOME/recipes/test-recipe"
cat > "$THINKBREAK_HOME/config.env" <<CONFIG
ENABLED=true
RECIPE_ID=test-recipe
DELAY_SECONDS=1
SAFETY_TIMEOUT_SECONDS=3
ACTION_TIMEOUT_SECONDS=2
CONFIG
cat > "$THINKBREAK_HOME/recipes/test-recipe/recipe.env" <<CONFIG
RECIPE_ID=test-recipe
RECIPE_NAME=Test Recipe
RECIPE_WAIT_URL=
CONFIG
cat > "$THINKBREAK_HOME/recipes/test-recipe/on-wait.sh" <<'SCRIPT'
#!/bin/bash
printf 'wait:%s\n' "$THINKBREAK_SESSION_ID" >> "$THINKBREAK_HOME/events"
SCRIPT
cat > "$THINKBREAK_HOME/recipes/test-recipe/on-return.sh" <<'SCRIPT'
#!/bin/bash
printf 'return:%s\n' "$THINKBREAK_SESSION_ID" >> "$THINKBREAK_HOME/events"
SCRIPT
cat > "$THINKBREAK_HOME/recipes/test-recipe/on-attention.sh" <<'SCRIPT'
#!/bin/bash
printf 'attention:%s\n' "$THINKBREAK_SESSION_ID" >> "$THINKBREAK_HOME/events"
SCRIPT
cat > "$THINKBREAK_HOME/recipes/test-recipe/on-timeout.sh" <<'SCRIPT'
#!/bin/bash
printf 'timeout:%s\n' "$THINKBREAK_SESSION_ID" >> "$THINKBREAK_HOME/events"
SCRIPT
chmod +x "$THINKBREAK_HOME/recipes/test-recipe"/*.sh

assert_not_contains() { [[ ! -f "$THINKBREAK_HOME/events" ]] || ! grep -q -- "$1" "$THINKBREAK_HOME/events"; }
assert_contains() { grep -q -- "$1" "$THINKBREAK_HOME/events"; }

# Short task: no waiting action and no cleanup action.
"$DISPATCH" start codex short </dev/null
"$DISPATCH" stop codex short </dev/null
sleep 2
assert_not_contains 'short'

# Long task: waiting action then normal return action.
"$DISPATCH" start codex long </dev/null
sleep 2
assert_contains 'wait:long'
"$DISPATCH" stop codex long </dev/null
sleep 1
assert_contains 'return:long'
[[ ! -e "$THINKBREAK_HOME/current/codex" ]]

# Attention uses its own event and returns immediately.
"$DISPATCH" start claude attention </dev/null
sleep 2
"$DISPATCH" attention claude attention </dev/null
sleep 1
assert_contains 'attention:attention'

# An old stop cannot interrupt the latest foreground owner.
"$DISPATCH" start codex old </dev/null
sleep 2
"$DISPATCH" start codex new </dev/null
sleep 2
"$DISPATCH" stop codex old </dev/null
sleep 1
assert_not_contains 'return:old'
"$DISPATCH" stop codex new </dev/null
sleep 1
assert_contains 'return:new'

# Safety timeout performs timeout cleanup and removes the owner.
"$DISPATCH" start codex timeout </dev/null
sleep 7
assert_contains 'timeout:timeout'
[[ ! -e "$THINKBREAK_HOME/current/codex" ]]

printf 'PASS: ThinkBreak dispatcher lifecycle checks\n'
