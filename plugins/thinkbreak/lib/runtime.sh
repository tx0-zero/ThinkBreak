#!/bin/bash
set -u

TB_RUNTIME_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TB_PLUGIN_ROOT="${THINKBREAK_PLUGIN_ROOT:-$(cd "$TB_RUNTIME_DIR/.." && pwd)}"
# shellcheck disable=SC1091
source "$TB_RUNTIME_DIR/platform-unix.sh"

_tb_now() { date +%s; }
_tb_one_line() { printf '%s' "${1:-}" | tr '\r\n' '  '; }
_tb_log() { [[ "${THINKBREAK_DEBUG:-}" == "1" ]] && printf '[ThinkBreak] %s\n' "$*" >&2 || true; }
_tb_warn() { printf '[ThinkBreak] %s\n' "$*" >&2; }

_tb_home() {
  if [[ -n "${THINKBREAK_HOME:-}" ]]; then
    printf '%s\n' "$THINKBREAK_HOME"
  elif [[ -n "${XDG_CONFIG_HOME:-}" ]]; then
    printf '%s/thinkbreak\n' "$XDG_CONFIG_HOME"
  else
    printf '%s/.config/thinkbreak\n' "${HOME:-.}"
  fi
}

_tb_config_file() { printf '%s/config.env\n' "$(_tb_home)"; }
_tb_sessions_dir() { printf '%s/sessions\n' "$(_tb_home)"; }
_tb_current_dir() { printf '%s/current\n' "$(_tb_home)"; }
_tb_lock_dir() { printf '%s/.lock\n' "$(_tb_home)"; }

_tb_init_dirs() {
  mkdir -p "$(_tb_home)" "$(_tb_sessions_dir)" "$(_tb_current_dir)" "$(_tb_home)/recipes" 2>/dev/null || return 1
}

_tb_read_key() {
  local file="$1" key="$2" default="${3:-}" line value
  [[ -f "$file" ]] || { printf '%s\n' "$default"; return 0; }
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ "$line" =~ ^[[:space:]]*${key}[[:space:]]*= ]] || continue
    value="${line#*=}"
    value="${value#${value%%[![:space:]]*}}"
    value="${value%${value##*[![:space:]]}}"
    if [[ "$value" == \"*\" && "$value" == *\" ]]; then value="${value:1:${#value}-2}"; fi
    if [[ "$value" == \'.*\' && "$value" == *\' ]]; then value="${value:1:${#value}-2}"; fi
    printf '%s\n' "$value"
    return 0
  done < "$file"
  printf '%s\n' "$default"
}

_tb_write_key() {
  local file="$1" key="$2" value="$3" tmp line found=0
  mkdir -p "$(dirname "$file")" || return 1
  tmp="${file}.tmp.$$"
  : > "$tmp" || return 1
  if [[ -f "$file" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      if [[ "$line" =~ ^[[:space:]]*${key}[[:space:]]*= ]]; then
        if [[ "$found" == 0 ]]; then
          printf '%s=%s\n' "$key" "$(_tb_one_line "$value")" >> "$tmp"
          found=1
        fi
      else
        printf '%s\n' "$line" >> "$tmp"
      fi
    done < "$file"
  fi
  [[ "$found" == 1 ]] || printf '%s=%s\n' "$key" "$(_tb_one_line "$value")" >> "$tmp"
  mv -f "$tmp" "$file"
}

_tb_acquire_lock() {
  local lock="$(_tb_lock_dir)" i=0
  mkdir -p "$(_tb_home)" || return 1
  while ! mkdir "$lock" 2>/dev/null; do
    i=$((i + 1)); [[ $i -ge 100 ]] && return 1
    sleep 0.01
  done
  printf '%s\n' "$$" > "$lock/pid"
}
_tb_release_lock() { rm -f "$(_tb_lock_dir)/pid" 2>/dev/null || true; rmdir "$(_tb_lock_dir)" 2>/dev/null || true; }

_tb_valid_id() { [[ "${1:-}" =~ ^[A-Za-z0-9._-]{1,96}$ ]]; }
_tb_safe_id() { printf '%s' "${1:-}" | tr -c 'A-Za-z0-9._-' '_' | cut -c1-96; }
_tb_session_key() { printf '%s__%s\n' "$1" "$(_tb_safe_id "$2")"; }
_tb_session_file() { printf '%s/%s.env\n' "$(_tb_sessions_dir)" "$(_tb_session_key "$1" "$2")"; }
_tb_current_file() { printf '%s/%s\n' "$(_tb_current_dir)" "$(_tb_safe_id "$1")"; }

_tb_write_session() {
  local file="$1" tmp="$1.tmp.$$"; shift
  : > "$tmp" || return 1
  while (($#)); do
    printf '%s=%s\n' "$1" "$(_tb_one_line "${2:-}")" >> "$tmp"
    shift 2
  done
  mv -f "$tmp" "$file"
}

_tb_current_key() { cat "$(_tb_current_file "$1")" 2>/dev/null || true; }
_tb_set_current() {
  local file="$(_tb_current_file "$1")" tmp="${file}.tmp.$$"
  printf '%s\n' "$2" > "$tmp" && mv -f "$tmp" "$file"
}
_tb_clear_current_if() {
  local file="$(_tb_current_file "$1")" expected="$2" actual
  actual="$(_tb_current_key "$1")"
  [[ "$actual" == "$expected" ]] && rm -f "$file"
}

_tb_config_enabled() { [[ "$(_tb_read_key "$(_tb_config_file)" ENABLED true)" == "true" ]]; }
_tb_delay() { local v="$(_tb_read_key "$(_tb_config_file)" DELAY_SECONDS 2)"; [[ "$v" =~ ^[0-9]+$ ]] && printf '%s\n' "$v" || printf '2\n'; }
_tb_safety_timeout() { local v="$(_tb_read_key "$(_tb_config_file)" SAFETY_TIMEOUT_SECONDS 1800)"; [[ "$v" =~ ^[0-9]+$ ]] && printf '%s\n' "$v" || printf '1800\n'; }
_tb_action_timeout() { local v="$(_tb_read_key "$(_tb_config_file)" ACTION_TIMEOUT_SECONDS 4)"; [[ "$v" =~ ^[0-9]+$ ]] && printf '%s\n' "$v" || printf '4\n'; }
_tb_recipe_id() { printf '%s\n' "$(_tb_read_key "$(_tb_config_file)" RECIPE_ID douyin-example)"; }

_tb_recipe_dir() {
  local id="$1" user built_in
  user="$(_tb_home)/recipes/$id"
  built_in="$TB_PLUGIN_ROOT/recipes/$id"
  _tb_valid_id "$id" || return 1
  if [[ -d "$user" ]]; then printf '%s\n' "$user"; elif [[ -d "$built_in" ]]; then printf '%s\n' "$built_in"; else return 1; fi
}
_tb_recipe_key() { _tb_read_key "$1/recipe.env" "$2" "${3:-}"; }

_tb_run_with_timeout() {
  local timeout="$1" label="$2"; shift 2
  "$@" &
  local pid=$! elapsed=0
  while kill -0 "$pid" 2>/dev/null; do
    if (( elapsed >= timeout )); then
      _tb_warn "$label exceeded ${timeout}s; continuing without blocking the Agent"
      kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
      return 124
    fi
    sleep 1
    elapsed=$((elapsed + 1))
  done
  wait "$pid" 2>/dev/null || return $?
  return 0
}

_tb_run_recipe_event() {
  local event="$1" recipe_dir="$2" session_file="$3" script
  case "$event" in
    wait) script="$recipe_dir/on-wait.sh" ;;
    return) script="$recipe_dir/on-return.sh" ;;
    attention) script="$recipe_dir/on-attention.sh" ;;
    timeout) script="$recipe_dir/on-timeout.sh" ;;
    *) return 0 ;;
  esac
  [[ -x "$script" ]] || return 0

  export THINKBREAK_EVENT="$event"
  export THINKBREAK_HOST="$(_tb_read_key "$session_file" HOST)"
  export THINKBREAK_SESSION_ID="$(_tb_read_key "$session_file" SESSION_ID)"
  export THINKBREAK_PLATFORM="$(tb_platform_name)"
  export THINKBREAK_SOURCE_APP="$(_tb_read_key "$session_file" SOURCE_APP)"
  export THINKBREAK_SOURCE_WINDOW="$(_tb_read_key "$session_file" SOURCE_WINDOW)"
  export THINKBREAK_SOURCE_PID="$(_tb_read_key "$session_file" SOURCE_PID)"
  export THINKBREAK_RECIPE_ID="$(_tb_read_key "$session_file" RECIPE_ID)"
  export THINKBREAK_RECIPE_DIR="$recipe_dir"
  export THINKBREAK_WAIT_URL="$(_tb_recipe_key "$recipe_dir" RECIPE_WAIT_URL)"
  export THINKBREAK_HOME="$(_tb_home)"
  _tb_run_with_timeout "$(_tb_action_timeout)" "Recipe $event" "$script"
}

_tb_run_recipe_event_ps_fallback() { :; }

_tb_create_session() {
  local host="$1" session_id="$2" recipe_id="$3" source_app source_window source_pid file key now
  file="$(_tb_session_file "$host" "$session_id")"; key="$(_tb_session_key "$host" "$session_id")"; now="$(_tb_now)"
  SOURCE_APP=""; SOURCE_WINDOW=""; SOURCE_PID=""
  while IFS='=' read -r capture_key capture_value; do
    case "$capture_key" in
      SOURCE_APP) SOURCE_APP="$capture_value" ;;
      SOURCE_WINDOW) SOURCE_WINDOW="$capture_value" ;;
      SOURCE_PID) SOURCE_PID="$capture_value" ;;
    esac
  done < <(tb_capture_origin)
  source_app="${THINKBREAK_SOURCE_APP:-${SOURCE_APP:-}}"
  source_window="${THINKBREAK_SOURCE_WINDOW:-${SOURCE_WINDOW:-}}"
  source_pid="${THINKBREAK_SOURCE_PID:-${SOURCE_PID:-}}"
  _tb_write_session "$file" \
    SESSION_ID "$session_id" HOST "$host" STATE pending RECIPE_ID "$recipe_id" \
    SOURCE_APP "$source_app" SOURCE_WINDOW "$source_window" SOURCE_PID "$source_pid" \
    CREATED_AT "$now" || return 1
  _tb_set_current "$host" "$key"
  printf '%s\n' "$file"
}

_tb_worker() {
  local host="$1" session_id="$2" file="$(_tb_session_file "$1" "$2")" key="$(_tb_session_key "$1" "$2")"
  local delay="$(_tb_delay)" timeout="$(_tb_safety_timeout)" recipe_dir recipe_id deadline
  sleep "$delay"
  if [[ ! -f "$file" || "$(_tb_current_key "$host")" != "$key" || ! _tb_config_enabled ]]; then
    _tb_clear_current_if "$host" "$key"
    rm -f "$file"
    return 0
  fi
  recipe_id="$(_tb_read_key "$file" RECIPE_ID "$(_tb_recipe_id)")"
  recipe_dir="$(_tb_recipe_dir "$recipe_id")" || {
    _tb_warn "Recipe not found: $recipe_id"
    _tb_clear_current_if "$host" "$key"
    rm -f "$file"
    return 0
  }
  if [[ "$(_tb_recipe_key "$recipe_dir" RECIPE_ENABLED true)" != true ]]; then
    _tb_clear_current_if "$host" "$key"
    rm -f "$file"
    return 0
  fi
  _tb_write_key "$file" STATE active
  _tb_run_recipe_event wait "$recipe_dir" "$file" || _tb_log "Recipe on-wait failed: $recipe_id"
  deadline=$(( $(_tb_now) + timeout ))
  while [[ -f "$file" && "$(_tb_current_key "$host")" == "$key" ]]; do
    if (( $(_tb_now) >= deadline )); then
      _tb_timeout "$host" "$session_id" "$file" "$key" "$recipe_dir"
      return 0
    fi
    sleep 1
  done
}

_tb_finish() {
  local event="$1" host="$2" session_id="$3" file="$4" key="$5" recipe_dir="$6"
  [[ -f "$file" ]] || return 0
  local state="$(_tb_read_key "$file" STATE pending)"
  _tb_write_key "$file" STATE ended
  _tb_clear_current_if "$host" "$key"
  if [[ "$state" == active ]]; then
    _tb_run_recipe_event "$event" "$recipe_dir" "$file" || _tb_log "Recipe on-$event failed"
    # A newer task may have taken ownership while the recipe was cleaning up.
    [[ -z "$(_tb_current_key "$host")" ]] && tb_restore_origin "$(_tb_read_key "$file" SOURCE_APP)" "$(_tb_read_key "$file" SOURCE_WINDOW)" "$(_tb_read_key "$file" SOURCE_PID)"
  fi
  rm -f "$file"
}

_tb_timeout() {
  local host="$1" session_id="$2" file="$3" key="$4" recipe_dir="$5"
  [[ "$(_tb_current_key "$host")" == "$key" ]] || return 0
  _tb_finish timeout "$host" "$session_id" "$file" "$key" "$recipe_dir"
  _tb_warn "Waiting session $session_id reached the safety timeout and returned to the source window"
}

tb_dispatch() {
  local event="${1:-}" host="${2:-unknown}" session_id="${3:-}" recipe_id file key recipe_dir current
  _tb_init_dirs || return 0
  case "$event" in
    start)
      _tb_config_enabled || return 0
      session_id="${session_id:-${THINKBREAK_SESSION_ID:-}}"
      [[ -n "$session_id" ]] || session_id="${host}-$(date +%s)-$$-${RANDOM:-0}"
      session_id="$(_tb_safe_id "$session_id")"
      recipe_id="$(_tb_recipe_id)"
      _tb_recipe_dir "$recipe_id" >/dev/null 2>&1 || { _tb_warn "Recipe not found: $recipe_id"; return 0; }
      _tb_acquire_lock || return 0
      _tb_create_session "$host" "$session_id" "$recipe_id" >/dev/null || true
      _tb_release_lock
      nohup "$TB_PLUGIN_ROOT/hooks/dispatch.sh" worker "$host" "$session_id" >/dev/null 2>&1 &
      ;;
    worker)
      _tb_worker "$host" "$session_id" || true
      ;;
    stop|attention)
      current="$(_tb_current_key "$host")"
      if [[ -z "$session_id" ]]; then
        [[ -n "$current" ]] || return 0
        session_id="${current#*__}"
      fi
      file="$(_tb_session_file "$host" "$session_id")"; key="$(_tb_session_key "$host" "$session_id")"
      [[ -f "$file" ]] || return 0
      [[ "$current" == "$key" ]] || { rm -f "$file"; return 0; }
      recipe_id="$(_tb_read_key "$file" RECIPE_ID "$(_tb_recipe_id)")"
      recipe_dir="$(_tb_recipe_dir "$recipe_id")" || recipe_dir="$TB_PLUGIN_ROOT/recipes/custom-template"
      if [[ "$event" == stop ]]; then event=return; fi
      _tb_finish "$event" "$host" "$session_id" "$file" "$key" "$recipe_dir"
      ;;
    timeout)
      file="$(_tb_session_file "$host" "$session_id")"; key="$(_tb_session_key "$host" "$session_id")"
      [[ -f "$file" && "$(_tb_current_key "$host")" == "$key" ]] || return 0
      recipe_id="$(_tb_read_key "$file" RECIPE_ID "$(_tb_recipe_id)")"; recipe_dir="$(_tb_recipe_dir "$recipe_id")" || return 0
      _tb_timeout "$host" "$session_id" "$file" "$key" "$recipe_dir"
      ;;
    status)
      printf 'enabled=%s\nrecipe=%s\ndelay_seconds=%s\nsafety_timeout_seconds=%s\nhome=%s\n' \
        "$(_tb_read_key "$(_tb_config_file)" ENABLED true)" "$(_tb_recipe_id)" "$(_tb_delay)" "$(_tb_safety_timeout)" "$(_tb_home)"
      ;;
    enable|disable)
      _tb_write_key "$(_tb_config_file)" ENABLED "$([[ "$event" == enable ]] && printf true || printf false)"
      ;;
    use)
      recipe_id="$4"; _tb_valid_id "$recipe_id" || return 0
      _tb_recipe_dir "$recipe_id" >/dev/null 2>&1 || { _tb_warn "Recipe not found: $recipe_id"; return 0; }
      _tb_write_key "$(_tb_config_file)" RECIPE_ID "$recipe_id"
      ;;
    set-delay|set-timeout)
      [[ "${4:-}" =~ ^[0-9]+$ ]] || return 0
      if [[ "$event" == set-delay ]]; then _tb_write_key "$(_tb_config_file)" DELAY_SECONDS "$4"; else _tb_write_key "$(_tb_config_file)" SAFETY_TIMEOUT_SECONDS "$4"; fi
      ;;
    validate)
      tb_validate
      ;;
    test)
      _tb_config_enabled || { _tb_warn 'ThinkBreak is disabled'; return 0; }
      tb_dispatch start "$host" "test-$$-$(date +%s)"
      ;;
    init)
      _tb_init_config
      ;;
    *)
      _tb_warn "Unknown event: $event"
      ;;
  esac
}

_tb_init_config() {
  _tb_init_dirs || return 0
  local file="$(_tb_config_file)"
  [[ -f "$file" ]] || cat > "$file" <<'CONFIG'
# ThinkBreak local configuration. Values are deliberately simple key=value pairs.
ENABLED=true
RECIPE_ID=douyin-example
DELAY_SECONDS=2
SAFETY_TIMEOUT_SECONDS=1800
ACTION_TIMEOUT_SECONDS=4
CONFIG
  printf 'ThinkBreak config: %s\n' "$file"
}

tb_validate() {
  local recipe_id="$(_tb_recipe_id)" dir="$(_tb_recipe_dir "$(_tb_recipe_id)" 2>/dev/null || true)" status=0 script
  [[ -n "$dir" ]] || { _tb_warn "Recipe not found: $recipe_id"; return 1; }
  _tb_valid_id "$recipe_id" || { _tb_warn "Invalid recipe id: $recipe_id"; status=1; }
  [[ -f "$dir/recipe.env" ]] || { _tb_warn "Missing recipe.env: $dir"; status=1; }
  for script in on-wait.sh on-return.sh on-attention.sh on-timeout.sh; do
    [[ ! -e "$dir/$script" || -x "$dir/$script" ]] || { _tb_warn "Not executable: $dir/$script"; status=1; }
  done
  [[ "$status" == 0 ]] && printf 'Recipe %s is valid (%s)\n' "$recipe_id" "$dir"
  return "$status"
}
