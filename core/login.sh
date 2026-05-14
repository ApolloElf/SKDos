#!/bin/bash

clear
echo "-----------"
echo "SKDos Login"
echo "-----------"

read -p "User: " u
read -p "Pass: " p

if grep -q "$u:$p" ~/SKDos/system/users.db; then
    echo "Login succesful"
    sleep 1
else
    echo "Access denied"
    exit
fi
