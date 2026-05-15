#!/usr/bin/env bash

SKDOS_VERSION="${SKDOS_VERSION:-1.0}"
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
    HOME) printf '%s\n' "$SKDOS_HOME" ;;
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
  IFS='\' read -r -a parts <<< "$rest"
  for part in "${parts[@]}"; do
    case "$part" in
      ''|.) ;;
      ..)
        if [ "${#out[@]}" -gt 0 ]; then
          unset "out[$((${#out[@]} - 1))]"
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
  awk -F= -v key="$key" '$1 == key { sub(/^[ \t]+/, "", $2); sub(/[ \t]+$/, "", $2); print $2; exit }' "$manifest"
}

skdos_app_manifest() {
  local app="$1"
  local candidate="$SKDOS_APPS_DIR/$app/manifest.conf"
  [ -f "$candidate" ] && printf '%s\n' "$candidate"
}

skdos_task_register() {
  local app_id="$1"
  local pid="$2"
  local user="${SKDOS_USER:-system}"
  local task_file="$SKDOS_TASK_DIR/$pid.task"
  mkdir -p "$SKDOS_TASK_DIR"
  printf 'pid=%s\napp=%s\nuser=%s\nstarted=%s\n' "$pid" "$app_id" "$user" "$(date -Is)" > "$task_file"
}

skdos_task_unregister() {
  rm -f "$SKDOS_TASK_DIR/$1.task"
}

skdos_task_cleanup_dead() {
  local file pid
  for file in "$SKDOS_TASK_DIR"/*.task; do
    [ -e "$file" ] || continue
    pid="$(awk -F= '$1 == "pid" { print $2; exit }' "$file")"
    if [ -z "$pid" ] || ! kill -0 "$pid" 2>/dev/null; then
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
    task_user="$(awk -F= '$1 == "user" { print $2; exit }' "$file")"
    [ "$task_user" = "$user" ] || continue
    pid="$(awk -F= '$1 == "pid" { print $2; exit }' "$file")"
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
    fi
    rm -f "$file"
  done
}
