#!/bin/sh
set -eu

: "${SERVER_PORT:?Pterodactyl primary allocation must provide SERVER_PORT}"
: "${UBUNTU_VERSION:=24.04}"
: "${SSH_AUTH_MODE:=key}"
: "${SSH_PASSWORD:=}"
: "${SSH_PUBLIC_KEY:=}"

case "$UBUNTU_VERSION" in 20.04|22.04|24.04|26.04) ;; *) echo "UBUNTU_VERSION must be 20.04, 22.04, 24.04 or 26.04"; exit 1 ;; esac
case "$SSH_AUTH_MODE" in key|password|both) ;; *) echo "SSH_AUTH_MODE must be key, password or both"; exit 1 ;; esac
case "$SERVER_PORT" in ''|*[!0-9]*) echo "Invalid SERVER_PORT"; exit 1 ;; esac
[ "$SERVER_PORT" -ge 1 ] && [ "$SERVER_PORT" -le 65535 ] || { echo "Invalid SERVER_PORT"; exit 1; }

case "$SSH_AUTH_MODE" in
  key) [ -n "$SSH_PUBLIC_KEY" ] || { echo "SSH_PUBLIC_KEY is required"; exit 1; } ;;
  password) [ -n "$SSH_PASSWORD" ] || { echo "SSH_PASSWORD is required"; exit 1; } ;;
  both) [ -n "$SSH_PASSWORD" ] && [ -n "$SSH_PUBLIC_KEY" ] || { echo "SSH_PASSWORD and SSH_PUBLIC_KEY are required"; exit 1; } ;;
esac

ROOTFS="$HOME/ubuntu-rootfs"
if [ ! -f "$ROOTFS/.ptero-ubuntu-version" ] || [ "$(cat "$ROOTFS/.ptero-ubuntu-version")" != "$UBUNTU_VERSION" ]; then
  rm -rf "$ROOTFS"
  /install-ubuntu.sh "$UBUNTU_VERSION" "$ROOTFS"
fi

# Run as PRoot fake-root: root privileges apply only inside this rootfs.
PROOT="/usr/local/bin/proot"
P="$PROOT -0 -r $ROOTFS -w /root -b /dev -b /proc -b /sys -b /etc/resolv.conf"

# Install and configure SSH inside the selected Ubuntu filesystem.
$PROOT -0 -r "$ROOTFS" -w /root -b /dev -b /proc -b /sys -b /etc/resolv.conf \
  /bin/bash -c 'export DEBIAN_FRONTEND=noninteractive; apt-get update; apt-get install -y --no-install-recommends dropbear ca-certificates passwd; rm -rf /var/lib/apt/lists/*'

if [ "$SSH_AUTH_MODE" = password ] || [ "$SSH_AUTH_MODE" = both ]; then
  printf 'root:%s\n' "$SSH_PASSWORD" | $PROOT -0 -r "$ROOTFS" -w /root /usr/sbin/chpasswd
else
  # Lock password authentication for key-only mode.
  $PROOT -0 -r "$ROOTFS" -w /root /usr/bin/passwd -l root >/dev/null 2>&1 || true
fi

if [ -n "$SSH_PUBLIC_KEY" ]; then
  mkdir -p "$ROOTFS/root/.ssh"
  printf '%s\n' "$SSH_PUBLIC_KEY" > "$ROOTFS/root/.ssh/authorized_keys"
  chmod 700 "$ROOTFS/root/.ssh"
  chmod 600 "$ROOTFS/root/.ssh/authorized_keys"
fi

# Generate persistent host keys if missing.
if [ ! -s "$ROOTFS/etc/dropbear/dropbear_ed25519_host_key" ]; then
  $PROOT -0 -r "$ROOTFS" -w /root /usr/bin/dropbearkey -t ed25519 -f /etc/dropbear/dropbear_ed25519_host_key
fi

# Dropbear stays in foreground; login shell is an Ubuntu root shell via PRoot.
# Dropbear -s disables password login only for key-only mode.
mkdir -p "$ROOTFS/usr/local/sbin"
cat > "$ROOTFS/usr/local/sbin/ptero-root-shell" <<'SHELL'
#!/bin/sh
exec /bin/bash -l
SHELL
chmod 0755 "$ROOTFS/usr/local/sbin/ptero-root-shell"

echo "Ubuntu ${UBUNTU_VERSION} ready. Starting root SSH on SERVER_PORT=${SERVER_PORT}."
if [ "$SSH_AUTH_MODE" = key ]; then
  exec $PROOT -0 -r "$ROOTFS" -w /root -b /dev -b /proc -b /sys -b /etc/resolv.conf \
    /usr/sbin/dropbear -F -E -p "$SERVER_PORT" -r /etc/dropbear/dropbear_ed25519_host_key -s
else
  exec $PROOT -0 -r "$ROOTFS" -w /root -b /dev -b /proc -b /sys -b /etc/resolv.conf \
    /usr/sbin/dropbear -F -E -p "$SERVER_PORT" -r /etc/dropbear/dropbear_ed25519_host_key
fi
