#!/usr/bin/env bash
set -euo pipefail

PREFIX="${PREFIX:-/opt/skdos}"
CONFIG_DIR="${CONFIG_DIR:-/etc/skdos}"
STATE_DIR="${STATE_DIR:-/var/lib/skdos}"
SERVICE_DIR="${SERVICE_DIR:-/etc/systemd/system}"

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  printf 'SKDos install must run as root.\n' >&2
  exit 1
fi

SOURCE_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$PREFIX" "$CONFIG_DIR" "$STATE_DIR/system" "$STATE_DIR/users" "$STATE_DIR/run/tasks"
cp -R "$SOURCE_DIR"/bin "$SOURCE_DIR"/commands "$SOURCE_DIR"/config "$SOURCE_DIR"/core "$SOURCE_DIR"/lib "$SOURCE_DIR"/apps "$PREFIX"/
chmod +x "$PREFIX"/bin/* "$PREFIX"/core/*.sh "$PREFIX"/apps/*/run.sh 2>/dev/null || true

if [ ! -f "$CONFIG_DIR/system.conf" ]; then
  sed "s#^SKDOS_APPS_DIR=.*#SKDOS_APPS_DIR=$PREFIX/apps#; s#^SKDOS_COMMANDS_DIR=.*#SKDOS_COMMANDS_DIR=$PREFIX/commands#" \
    "$SOURCE_DIR/config/system.conf" > "$CONFIG_DIR/system.conf"
fi

sed "s#/opt/skdos#$PREFIX#g" "$SOURCE_DIR/systemd/skdos.service" > "$SERVICE_DIR/skdos.service"
systemctl daemon-reload
systemctl enable skdos.service

: > "$STATE_DIR/system/packages.tsv"
for manifest in "$PREFIX"/apps/*/manifest.conf; do
  [ -e "$manifest" ] || continue
  app_dir="$(dirname "$manifest")"
  id="$(awk -F= '$1 == "id" { print $2; exit }' "$manifest")"
  version="$(awk -F= '$1 == "version" { print $2; exit }' "$manifest")"
  [ -n "$id" ] || continue
  printf '%s\t%s\t%s\t%s\n' "$id" "${version:-unknown}" "$app_dir" "$(date -Is)" >> "$STATE_DIR/system/packages.tsv"
done

printf 'SKDos installed to %s\n' "$PREFIX"
printf 'Start it now with: systemctl start skdos.service\n'
printf 'The first TTY login will create the first SKDos user if none exists.\n'
