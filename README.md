# SKDos

A minimal DOS-like Linux system for Surface devices.

## Features
- Boots into text-only interface
- DOS-style command menu
- WiFi support via NetworkManager
- Runs on Arch Linux with linux-surface kernel

## Boot concept
System starts directly into a systemd service which launches a TUI shell.

## Start command
```bash
bash core/skdos.sh
