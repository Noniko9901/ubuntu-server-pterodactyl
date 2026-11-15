#!/usr/bin/env bash
set -Eeuo pipefail

: "${SERVER_PORT:?Pterodactyl must provide SERVER_PORT}"
: "${SSH_PUBLIC_KEY:?Set SSH_PUBLIC_KEY to your public SSH key}"

if ! [[ "$SERVER_PORT" =~ ^[0-9]+$ ]] || (( SERVER_PORT < 1 || SERVER_PORT > 65535 )); then
  echo "ERROR: SERVER_PORT is not a valid TCP port." >&2
  exit 1
fi

SSH_DIR="${HOME:-/home/container}/.ssh"
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

printf '%s\n' "$SSH_PUBLIC_KEY" > "$SSH_DIR/authorized_keys"
chmod 600 "$SSH_DIR/authorized_keys"

HOST_KEY="$SSH_DIR/dropbear_ed25519_host_key"
if [[ ! -s "$HOST_KEY" ]]; then
  dropbearkey -t ed25519 -f "$HOST_KEY"
fi
chmod 600 "$HOST_KEY"

echo "Starting Dropbear for user container on TCP port ${SERVER_PORT} (public-key authentication)."
exec /usr/sbin/dropbear -F -E -s -p "$SERVER_PORT" -r "$HOST_KEY" -P "$SSH_DIR/dropbear.pid"
