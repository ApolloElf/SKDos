#!/bin/bash

COMMAND_DIR="$HOME/SKDos/commands"

run_command() {
    local cmd="$1"
    shift

    if [ -f "$COMMAND_DIR/$cmd.sh" ]; then
        bash "$COMMAND_DIR/$cmd.sh" "$@"
    else
        echo "Unknown command: $cmd"
    fi
}
