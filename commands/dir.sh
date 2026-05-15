#!/usr/bin/env bash
set -euo pipefail

"${SKDOS_ROOT:-/opt/skdos}/bin/skfs" list "${1:-${SKDOS_CWD:-C:\\HOME}}"
