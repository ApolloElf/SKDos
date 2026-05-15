#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SKDOS_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
export SKDOS_ROOT

exec "$SKDOS_ROOT/bin/skdos-init" "$@"
