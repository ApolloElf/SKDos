#!/usr/bin/env bash
set -euo pipefail

if [ -z "${SKDOS_ROOT:-}" ]; then
  SKDOS_ROOT="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
  export SKDOS_ROOT
fi

exec "$SKDOS_ROOT/bin/sksession" "$@"
