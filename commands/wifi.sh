#!/usr/bin/env bash
set -euo pipefail

if command -v nmcli >/dev/null 2>&1; then
  nmcli dev wifi list
else
  printf 'NetworkManager nmcli is not installed or not in PATH.\n' >&2
  exit 1
fi
