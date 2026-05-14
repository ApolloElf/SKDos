#!/bin/bash

APP="$1"

if [ -f "$HOME/SKDos/apps/$APP.sh" ]; then
    bash "$HOME/SKDos/apps/$APP.sh"
else
    echo "App not found"
fi
