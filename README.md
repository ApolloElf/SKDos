# SKDos v1.0

SKDos is a minimal, modular, Surface-focused operating-system userland intended to run on top of a Linux system using the `linux-surface` kernel. Linux remains the hardware abstraction layer; SKDos owns the visible runtime, login flow, shell, app model, package install path, logical filesystem view, and process registry.

## Architecture

```text
linux-surface kernel
-> systemd skdos.service on tty1
-> bin/skdos-init
-> bin/sksession
-> bin/skshell or bin/skdesktop
-> bin/skapp / bin/skpkg / bin/skfs / bin/sktask
```

## Repository Layout

```text
bin/        Executable SKDos runtime commands
core/       Compatibility entry points for older SKDos starts
lib/        Shared runtime functions
commands/   Extensible shell command scripts
apps/       SKDos-native app packages
config/     Default system configuration
systemd/    Boot service unit
```

## Install On A Target System

Run as root from this repository:

```bash
./install.sh
systemctl start skdos.service
```

The installer copies SKDos into `/opt/skdos`, writes `/etc/skdos/system.conf` if it does not already exist, enables `skdos.service`, and prepares `/var/lib/skdos`.

On first boot, SKDos prompts on `tty1` to create the first SKDos user. Passwords are stored as SHA-256 hashes in `/var/lib/skdos/system/users.db`.

## Running In A Development Checkout

```bash
SKDOS_ROOT="$PWD" SKDOS_CONFIG_DIR="$PWD/.local/etc" SKDOS_STATE_DIR="$PWD/.local/state" bash core/skdos.sh
```

## Shell Commands

```text
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
```

## SKFilesystem

SKDos exposes logical roots by default:

```text
C:\HOME    /var/lib/skdos/users/<user>/home
C:\APPS    /opt/skdos/apps
C:\SYSTEM  /opt/skdos
```

The shell and desktop resolve paths through `skfs`; users are not sent to raw Linux paths for normal navigation.

## Native App Format

A script app is a folder containing:

```text
manifest.conf
run.sh
```

Example `manifest.conf`:

```ini
id=notes
name=SKNotes
version=1.0.0
type=script
run=run.sh
```

Install local folders or archives with `skpkg install <source>`. Installed apps live under `/opt/skdos/apps/<id>` and are executed by `skapp run <id>` as real child processes registered in the SKDos task table.
