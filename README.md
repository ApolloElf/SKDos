# SKDos v1.0

SKDos is a minimal, modular, Surface-focused operating-system userland intended to run on top of a Linux system using the linux-surface kernel.

Linux remains the hardware abstraction layer. SKDos owns the visible runtime: boot flow, login system, shell, app model, package system, logical filesystem view, and process registry.

Quick Start
git clone https://github.com/ApolloElf/SKDos
cd SKDos
sudo ./install.sh
sudo systemctl enable skdos.service
sudo systemctl start skdos.service

Reboot is recommended:

sudo reboot

After reboot, SKDos will start automatically on tty1.

What you will see after boot

After starting SKDos:

system boots directly into tty1
SKDos login prompt appears
user session is created
SKShell or SKDesktop starts
apps can be executed via skapp

This is a full userland environment, not a theme or wrapper.

Why SKDos exists

SKDos is built to explore a minimal, user-controlled operating system layer where Linux is hidden and the user interacts only with a clean, deterministic runtime environment.

The goal is maximum control with minimal system complexity.

Architecture
BOOT
 ↓
linux-surface kernel
 ↓
systemd (minimal services)
 ↓
SKDos init (skdos-init)
 ↓
session manager (sksession)
 ↓
runtime (skshell / skdesktop)
 ↓
system APIs:
   - skapp   (applications)
   - skpkg   (package system)
   - skfs    (filesystem abstraction)
   - sktask  (process registry)
Repository Layout
bin/        Core SKDos runtime commands
core/       Compatibility entry points and legacy boot logic
lib/        Shared runtime functions
commands/   Extensible shell commands
apps/       SKDos-native application packages
config/     Default system configuration
systemd/    systemd service definition
Installation

Run from repository root:

sudo ./install.sh

This will:

copy SKDos to /opt/skdos
create /var/lib/skdos
create /etc/skdos/system.conf if missing
install and enable skdos.service
Development Mode

Run SKDos without installing:

SKDOS_ROOT="$PWD" \
SKDOS_CONFIG_DIR="$PWD/.local/etc" \
SKDOS_STATE_DIR="$PWD/.local/state" \
bash core/skdos.sh
Shell Commands
help
logout
pwd
cd C:\HOME
dir C:\APPS
type C:\HOME\notes.txt
explorer

skfs roots

skpkg install apps/notes
skpkg list

skapp list
skapp run notes

sktask list
sktask kill <pid>
SKFilesystem

SKDos exposes a logical filesystem abstraction layer.

Users do not interact directly with Linux paths by default.

C:\HOME    → /var/lib/skdos/users/<user>/home
C:\APPS    → /opt/skdos/apps
C:\SYSTEM  → /opt/skdos

All navigation in shell and desktop is resolved through skfs.

Native Application System

SKDos applications are real executable units.

There are two types:

1. Script Apps

Folder-based applications:

apps/notes/
 ├── manifest.conf
 └── run.sh
Example manifest.conf
id=notes
name=SKNotes
version=1.0.0
type=script
run=run.sh
```

Install local folders or archives with `skpkg install <source>`. Installed apps live under `/opt/skdos/apps/<id>` and are executed by `skapp run <id>` as real child processes registered in the SKDos task table.
