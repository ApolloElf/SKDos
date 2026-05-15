#!/usr/bin/env bash

if [ -z "${SKDOS_ROOT:-}" ]; then
  SKDOS_ROOT="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
  export SKDOS_ROOT
fi

run_command() {
  local cmd="$1"
  shift || true

  case "$cmd" in
    skapp|skpkg|skfs|sktask|skuser)
      "$SKDOS_ROOT/bin/$cmd" "$@"
      ;;
    run)
      "$SKDOS_ROOT/bin/skapp" run "$@"
      ;;
    *)
      if [ -f "$SKDOS_ROOT/commands/$cmd.sh" ]; then
        bash "$SKDOS_ROOT/commands/$cmd.sh" "$@"
      else
        printf 'Unknown command: %s\n' "$cmd" >&2
      fi
      ;;
  esac
}
