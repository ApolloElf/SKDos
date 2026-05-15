#!/usr/bin/env bash
set -euo pipefail

"${SKDOS_ROOT:-/opt/skdos}/bin/skdesktop" "${1:-${SKDOS_CWD:-C:\\HOME}}"
