#!/usr/bin/env bash
set -euo pipefail

printf 'SKDos user: %s\n' "${SKDOS_USER:-unknown}"
printf 'SKDos root: %s\n' "${SKDOS_ROOT:-unknown}"
printf 'SKDos home: %s\n' "${SKDOS_HOME:-unknown}"
printf 'SKDos path: %s\n' "${SKDOS_CWD:-C:\\HOME}"
printf 'Kernel: '
uname -sr
printf 'Machine: '
uname -m
