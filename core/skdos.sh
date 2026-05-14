#!/bin/bash
export TERM=linux

clear
while true; do
clear
echo "====================="
echo "    SKDos - V0.1     "
echo "====================="
echo "1 WLAN connect"
echo "2 Pingtest"
echo "3 Show Files"
echo "4 SHELL"
echo "5 Reboot"
echo "6 Shutdown"
echo "---------------------"

read -p ">>> " c

case "$c" in
1)
nmcli dev wifi list
read -p "SSID: " s
read -p "Pass: " p
nmcli dev wifi connect "$s" password "$p"
;;
2)
ping -c 3 1.1.1.1 ;;
3)
ls ;;
4)
bash ;;
5)
reboot ;;
6)
poweroff ;;
esac
done
