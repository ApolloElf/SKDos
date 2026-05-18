#!/usr/bin/env bash

SKDOS_VERSION="${SKDOS_VERSION:-1.1}"
SKDOS_ROOT="${SKDOS_ROOT:-/opt/skdos}"
SKDOS_CONFIG_DIR="${SKDOS_CONFIG_DIR:-/etc/skdos}"
SKDOS_STATE_DIR="${SKDOS_STATE_DIR:-/var/lib/skdos}"

SKDOS_SYSTEM_CONFIG="$SKDOS_ROOT/config/system.conf"
SKDOS_LOCAL_CONFIG="$SKDOS_CONFIG_DIR/system.conf"
SKDOS_USERS_DB="$SKDOS_STATE_DIR/system/users.db"
SKDOS_USERS_DIR="$SKDOS_STATE_DIR/users"
SKDOS_APPS_DIR="${SKDOS_APPS_DIR:-$SKDOS_ROOT/apps}"
SKDOS_COMMANDS_DIR="${SKDOS_COMMANDS_DIR:-$SKDOS_ROOT/commands}"
SKDOS_TASK_DIR="$SKDOS_STATE_DIR/run/tasks"
SKDOS_PACKAGE_REGISTRY="$SKDOS_STATE_DIR/system/packages.tsv"

skdos_die() {
  printf '%s\n' "$*" >&2
  return 1
}

skdos_load_config() {
  if [ -f "$SKDOS_SYSTEM_CONFIG" ]; then
    # shellcheck disable=SC1090
    . "$SKDOS_SYSTEM_CONFIG"
  fi
  if [ -f "$SKDOS_LOCAL_CONFIG" ]; then
    # shellcheck disable=SC1090
    . "$SKDOS_LOCAL_CONFIG"
  fi
}

skdos_ensure_layout() {
  mkdir -p "$SKDOS_CONFIG_DIR" "$SKDOS_STATE_DIR/system" "$SKDOS_USERS_DIR" \
    "$SKDOS_TASK_DIR" "$SKDOS_APPS_DIR" "$SKDOS_COMMANDS_DIR"
  touch "$SKDOS_PACKAGE_REGISTRY"
}

skdos_valid_id() {
  case "${1:-}" in
    ''|*[^A-Za-z0-9._-]*) return 1 ;;
    *) return 0 ;;
  esac
}

skdos_hash_password() {
  if command -v sha256sum >/dev/null 2>&1; then
    printf '%s' "$1" | sha256sum | awk '{print $1}'
  else
    printf '%s' "$1" | shasum -a 256 | awk '{print $1}'
  fi
}

skdos_authenticate() {
  local user="$1"
  local pass="$2"
  local hash
  hash="$(skdos_hash_password "$pass")"
  [ -f "$SKDOS_USERS_DB" ] || return 1
  awk -F: -v user="$user" -v hash="$hash" '$1 == user && $2 == hash { found = 1 } END { exit found ? 0 : 1 }' "$SKDOS_USERS_DB"
}

skdos_user_exists() {
  local user="$1"
  [ -f "$SKDOS_USERS_DB" ] || return 1
  awk -F: -v user="$user" '$1 == user { found = 1 } END { exit found ? 0 : 1 }' "$SKDOS_USERS_DB"
}

skdos_create_user() {
  local user="$1"
  local pass="$2"
  local hash

  case "$user" in
    ''|*[^A-Za-z0-9._-]*)
      printf 'Invalid SKDos user name: %s\n' "$user" >&2
      return 2
      ;;
  esac

  if skdos_user_exists "$user"; then
    printf 'User already exists: %s\n' "$user" >&2
    return 3
  fi

  hash="$(skdos_hash_password "$pass")"
  umask 077
  mkdir -p "$(dirname "$SKDOS_USERS_DB")" "$SKDOS_USERS_DIR/$user/home"
  printf '%s:%s\n' "$user" "$hash" >> "$SKDOS_USERS_DB"
}

skdos_fs_root_for_drive() {
  case "$1" in
    HOME)
      [ -n "${SKDOS_HOME:-}" ] || {
        printf 'SKFilesystem root C:\\HOME is unavailable outside a user session.\n' >&2
        return 1
      }
      printf '%s\n' "$SKDOS_HOME"
      ;;
    APPS) printf '%s\n' "$SKDOS_APPS_DIR" ;;
    SYSTEM) printf '%s\n' "$SKDOS_ROOT" ;;
    *) return 1 ;;
  esac
}

skdos_fs_normalize() {
  local input="${1:-$SKDOS_CWD}"
  local base="${SKDOS_CWD:-C:\\HOME}"

  input="${input//\//\\}"
  case "$input" in
    C:[A-Za-z]*)
      input="C:\\${input#C:}"
      ;;
  esac
  case "$base" in
    C:[A-Za-z]*)
      base="C:\\${base#C:}"
      ;;
  esac
  if [[ "$input" != C:\\* ]]; then
    input="${base}\\${input}"
  fi

  local drive="${input#C:\\}"
  drive="${drive%%\\*}"
  local rest="${input#C:\\$drive}"
  rest="${rest#\\}"
  drive="${drive^^}"

  local -a out=()
  local part
  local -a parts=()
  IFS='\' read -r -a parts <<< "$rest"
  for part in "${parts[@]}"; do
    case "$part" in
      ''|.) ;;
      ..)
        if [ "${#out[@]}" -gt 0 ]; then
          out=("${out[@]:0:$((${#out[@]} - 1))}")
        fi
        ;;
      *)
        out+=("$part")
        ;;
    esac
  done

  local joined=""
  if [ "${#out[@]}" -gt 0 ]; then
    local IFS='\'
    joined="\\${out[*]}"
  fi
  printf 'C:\\%s%s\n' "$drive" "$joined"
}

skdos_fs_resolve() {
  local logical
  logical="$(skdos_fs_normalize "${1:-$SKDOS_CWD}")"
  local without="${logical#C:\\}"
  local drive="${without%%\\*}"
  local rest="${without#"$drive"}"
  rest="${rest#\\}"

  local root
  root="$(skdos_fs_root_for_drive "$drive")" || {
    printf 'Unknown SKFilesystem root: C:\\%s\n' "$drive" >&2
    return 1
  }

  local resolved="$root"
  if [ -n "$rest" ]; then
    resolved="$root/${rest//\\//}"
  fi

  case "$(realpath -m "$resolved")" in
    "$(realpath -m "$root")"| "$(realpath -m "$root")"/*)
      realpath -m "$resolved"
      ;;
    *)
      printf 'Path escapes SKFilesystem root: %s\n' "$logical" >&2
      return 1
      ;;
  esac
}

skdos_manifest_value() {
  local manifest="$1"
  local key="$2"
  awk -F= -v key="$key" '
    /^[[:space:]]*($|#)/ { next }
    {
      k = $1
      sub(/^[ \t]+/, "", k)
      sub(/[ \t]+$/, "", k)
      if (k == key) {
        value = $0
        sub(/^[^=]*=/, "", value)
        sub(/^[ \t]+/, "", value)
        sub(/[ \t]+$/, "", value)
        print value
        exit
      }
    }
  ' "$manifest"
}

skdos_app_manifest() {
  local app="$1"
  skdos_valid_id "$app" || return 1
  local candidate="$SKDOS_APPS_DIR/$app/manifest.conf"
  [ -f "$candidate" ] && printf '%s\n' "$candidate"
}

skdos_validate_manifest_dir() {
  local app_dir="$1"
  local manifest="$app_dir/manifest.conf"
  local id type runner

  [ -d "$app_dir" ] || { printf 'App directory not found: %s\n' "$app_dir" >&2; return 1; }
  [ -f "$manifest" ] || { printf 'Missing manifest.conf\n' >&2; return 1; }

  id="$(skdos_manifest_value "$manifest" id)"
  type="$(skdos_manifest_value "$manifest" type)"
  runner="$(skdos_manifest_value "$manifest" run)"
  runner="${runner:-run.sh}"
  type="${type:-script}"

  skdos_valid_id "$id" || { printf 'Invalid app id in manifest: %s\n' "$id" >&2; return 1; }
  case "$type" in
    script) ;;
    *) printf 'Unsupported app type: %s\n' "$type" >&2; return 1 ;;
  esac
  case "$runner" in
    ''|/*|*'..'*|*\\*) printf 'Invalid app runner: %s\n' "$runner" >&2; return 1 ;;
  esac
  [ -f "$app_dir/$runner" ] || { printf 'Missing runner: %s\n' "$runner" >&2; return 1; }
}

skdos_parse_command() {
  local line="$1"
  local out_name="$2"
  local -a parsed=()
  local token="" quote="" char
  local token_started=false
  local i=0 len=${#line}

  while [ "$i" -lt "$len" ]; do
    char="${line:i:1}"
    if [ -n "$quote" ]; then
      if [ "$quote" = "'" ]; then
        if [ "$char" = "'" ]; then
          quote=""
        else
          token+="$char"
          token_started=true
        fi
      elif [ "$char" = '"' ]; then
        quote=""
      elif [ "$char" = "\\" ]; then
        token+="\\"
        token_started=true
      else
        token+="$char"
        token_started=true
      fi
    elif [[ "$char" =~ [[:space:]] ]]; then
      if [ "$token_started" = true ]; then
        parsed+=("$token")
        token=""
        token_started=false
      fi
    elif [ "$char" = "'" ]; then
      quote="'"
      token_started=true
    elif [ "$char" = '"' ]; then
      quote='"'
      token_started=true
    elif [ "$char" = "\\" ]; then
      token+="\\"
      token_started=true
    else
      token+="$char"
      token_started=true
    fi
    i=$((i + 1))
  done

  [ -z "$quote" ] || { printf 'Unclosed quote in command line.\n' >&2; return 2; }
  [ "$token_started" = false ] || parsed+=("$token")
  eval "$out_name=(\"\${parsed[@]}\")"
}

skdos_task_field() {
  local file="$1"
  local key="$2"
  awk -F= -v key="$key" '$1 == key { $1 = ""; sub(/^=/, "", $0); print $0; exit }' "$file"
}

skdos_pid_alive() {
  local pid="$1"
  case "$pid" in ''|*[!0-9]*) return 1 ;; esac
  kill -0 "$pid" 2>/dev/null
}

skdos_proc_start_time() {
  local pid="$1"
  [ -r "/proc/$pid/stat" ] || return 1
  awk '{ print $22 }' "/proc/$pid/stat" 2>/dev/null
}

skdos_task_process_matches() {
  local file="$1"
  local pid proc_start current_start
  pid="$(skdos_task_field "$file" pid)"
  skdos_pid_alive "$pid" || return 1
  proc_start="$(skdos_task_field "$file" proc_start)"
  [ -n "$proc_start" ] || return 0
  current_start="$(skdos_proc_start_time "$pid" || true)"
  [ -z "$current_start" ] || [ "$current_start" = "$proc_start" ]
}

skdos_task_register() {
  local app_id="$1"
  local pid="$2"
  local user="${SKDOS_USER:-system}"
  local session="${SKDOS_SESSION_ID:-system}"
  local app_dir="${SKDOS_APP_DIR:-}"
  local proc_start=""
  local task_file="$SKDOS_TASK_DIR/$pid.task"
  mkdir -p "$SKDOS_TASK_DIR"
  skdos_valid_id "$app_id" || { printf 'Invalid app id: %s\n' "$app_id" >&2; return 1; }
  skdos_pid_alive "$pid" || { printf 'Cannot register non-running process: %s\n' "$pid" >&2; return 1; }
  proc_start="$(skdos_proc_start_time "$pid" || true)"
  umask 077
  {
    printf 'pid=%s\n' "$pid"
    printf 'proc_start=%s\n' "$proc_start"
    printf 'app=%s\n' "$app_id"
    printf 'user=%s\n' "$user"
    printf 'session=%s\n' "$session"
    printf 'app_dir=%s\n' "$app_dir"
    printf 'started=%s\n' "$(date -Is)"
  } > "$task_file"
}

skdos_task_unregister() {
  rm -f "$SKDOS_TASK_DIR/$1.task"
}

skdos_task_cleanup_dead() {
  local file
  for file in "$SKDOS_TASK_DIR"/*.task; do
    [ -e "$file" ] || continue
    if ! skdos_task_process_matches "$file"; then
      rm -f "$file"
    fi
  done
}

skdos_task_cleanup_user() {
  local user="$1"
  local file pid task_user
  skdos_task_cleanup_dead
  for file in "$SKDOS_TASK_DIR"/*.task; do
    [ -e "$file" ] || continue
    task_user="$(skdos_task_field "$file" user)"
    [ "$task_user" = "$user" ] || continue
    pid="$(skdos_task_field "$file" pid)"
    if skdos_task_process_matches "$file"; then
      kill -- "$pid" 2>/dev/null || true
    fi
    rm -f "$file"
  done
}
