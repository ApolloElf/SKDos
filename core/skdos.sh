#!/bin/bash
export TERM=linux
source ~/SKDos/core/command_loader.sh
source ~/SKDos/config/settings.conf

clear
while true; do
clear
echo "====================="
echo "    SKDos - V0.1     "
echo "====================="
echo "Type showcommands to "
echo "show all commands.   " 
echo "---------------------"

read -r input
run_command $input
