#!/usr/bin/env bash
set -euo pipefail

"${SKDOS_ROOT:-/opt/skdos}/bin/skapp" run "$@"
