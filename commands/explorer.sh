#!/bin/bash

while true; do
    clear
    echo "==== SKDos File Explorer ===="
    echo "Current: $(pwd)"
    echo
    ls
    echo
    echo "[cd <dir>] | [open <file>] | [back]"

    read -r cmd arg

    case "$cmd" in
        cd)
            cd "$arg" 2>/dev/null
            ;;
        open)
            nano "$arg"
            ;;
        back)
            break
            ;;
    esac
done
