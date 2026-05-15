#!/usr/bin/env bash
set -euo pipefail

: "${SKDOS_HOME:?SKDOS_HOME is not set}"

notes_file="$SKDOS_HOME/notes.txt"
touch "$notes_file"

editor="${EDITOR:-}"
if [ -n "$editor" ] && command -v "$editor" >/dev/null 2>&1; then
  "$editor" "$notes_file"
elif command -v nano >/dev/null 2>&1; then
  nano "$notes_file"
elif command -v vi >/dev/null 2>&1; then
  vi "$notes_file"
else
  printf 'SKNotes: no editor found. Showing notes file instead.\n\n'
  sed -n '1,200p' "$notes_file"
fi
