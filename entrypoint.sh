#!/bin/sh
set -eu

# ==========================================
# Ubuntu Multi-Version Pterodactyl
# SSH server with PRoot
# ==========================================

echo "=========================================="
echo "       UBUNTU VPS STARTUP"
echo "=========================================="

# Pterodactyl variables
: "${SERVER_PORT:?SERVER_PORT is required}"
: "${UBUNTU_VERSION:=24.04}"
: "${SSH_AUTH_MODE:=key}"
: "${SSH_PASSWORD:=}"
: "${SSH_PUBLIC_KEY:=}"

# Validate Ubuntu version
case "$UBUNTU_VERSION" in
    20.04|22.04|24.04|26.04)
        ;;
    *)
        echo "ERROR: Unsupported Ubuntu version: $UBUNTU_VERSION"
        exit 1
        ;;
esac

# Validate SSH port
case "$SERVER_PORT" in
    ''|*[!0-9]*)
        echo "ERROR: Invalid SERVER_PORT"
        exit 1
        ;;
esac

if [ "$SERVER_PORT" -lt 1 ] || [ "$SERVER_PORT" -gt 65535 ]; then
    echo "ERROR: SERVER_PORT must be between 1 and 65535"
    exit 1
fi

# Validate authentication mode
case "$SSH_AUTH_MODE" in
    key)
        [ -n "$SSH_PUBLIC_KEY" ] || {
            echo "ERROR: SSH_PUBLIC_KEY is required"
            exit 1
        }
        ;;
    password)
        [ -n "$SSH_PASSWORD" ] || {
            echo "ERROR: SSH_PASSWORD is required"
            exit 1
        }
        ;;
    both)
        [ -n "$SSH_PASSWORD" ] && [ -n "$SSH_PUBLIC_KEY" ] || {
            echo "ERROR: SSH_PASSWORD and SSH_PUBLIC_KEY are required"
            exit 1
        }
        ;;
    *)
        echo "ERROR: SSH_AUTH_MODE must be key, password or both"
        exit 1
        ;;
esac

# ==========================================
# Find PRoot
# ==========================================

PROOT="$(command -v proot || true)"

if [ -z "$PROOT" ] || [ ! -x "$PROOT" ]; then
    echo "ERROR: PRoot is not installed!"
    echo "Install proot in Dockerfile using apk."
    exit 1
fi

echo "PRoot found: $PROOT"
"$PROOT" --version || true

# ==========================================
# Ubuntu root filesystem
# ==========================================

ROOTFS="$HOME/ubuntu-rootfs"

mkdir -p "$HOME"

if [ ! -f "$ROOTFS/.ptero-ubuntu-version" ] || \
   [ "$(cat "$ROOTFS/.ptero-ubuntu-version")" != "$UBUNTU_VERSION" ]; then

    echo "Ubuntu rootfs missing or version changed."
    echo "Installing Ubuntu ${UBUNTU_VERSION}..."

    rm -rf "$ROOTFS"

    /install-ubuntu.sh "$UBUNTU_VERSION" "$ROOTFS"
fi

if [ ! -x "$ROOTFS/bin/bash" ]; then
    echo "ERROR: Ubuntu bash not found!"
    exit 1
fi

# ==========================================
# PRoot helper
# ==========================================

ubuntu() {
    "$PROOT" \
        -0 \
        -r "$ROOTFS" \
        -w /root \
        -b /dev \
        -b /proc \
        -b /sys \
        -b /etc/resolv.conf \
        "$@"
}

echo "Ubuntu rootfs: $ROOTFS"

# ==========================================
# Install Dropbear inside Ubuntu
# ==========================================

echo "Installing SSH server inside Ubuntu..."

ubuntu /usr/bin/env DEBIAN_FRONTEND=noninteractive \
    /bin/bash -c '
        apt-get update
        apt-get install -y --no-install-recommends dropbear ca-certificates passwd
        rm -rf /var/lib/apt/lists/*
    '

# ==========================================
# Configure root password
# ==========================================

if [ "$SSH_AUTH_MODE" = "password" ] || \
   [ "$SSH_AUTH_MODE" = "both" ]; then

    echo "Configuring root password..."

    printf 'root:%s\n' "$SSH_PASSWORD" | ubuntu /usr/sbin/chpasswd
else
    echo "Password authentication disabled."
    ubuntu /usr/bin/passwd -l root >/dev/null 2>&1 || true
fi

# ==========================================
# Configure SSH public key
# ==========================================

if [ -n "$SSH_PUBLIC_KEY" ]; then
    echo "Configuring SSH public key..."

    mkdir -p "$ROOTFS/root/.ssh"

    printf '%s\n' "$SSH_PUBLIC_KEY" \
        > "$ROOTFS/root/.ssh/authorized_keys"

    chmod 700 "$ROOTFS/root/.ssh"
    chmod 600 "$ROOTFS/root/.ssh/authorized_keys"
fi

# ==========================================
# Generate SSH host key
# ==========================================

mkdir -p "$ROOTFS/etc/dropbear"

if [ ! -s "$ROOTFS/etc/dropbear/dropbear_ed25519_host_key" ]; then
    echo "Generating SSH host key..."

    ubuntu /usr/bin/dropbearkey \
        -t ed25519 \
        -f /etc/dropbear/dropbear_ed25519_host_key
fi

# ==========================================
# Configure SSH shell
# ==========================================

echo "Configuring root shell..."

# Ensure root has a valid shell.
if ! grep -q '^root:' "$ROOTFS/etc/passwd"; then
    echo "ERROR: Root account missing from Ubuntu."
    exit 1
fi

# ==========================================
# Start SSH
# ==========================================

echo "=========================================="
echo "       UBUNTU VPS READY"
echo "=========================================="
echo "Ubuntu: ${UBUNTU_VERSION}"
echo "SSH user: root"
echo "SSH port: ${SERVER_PORT}"
echo "Authentication: ${SSH_AUTH_MODE}"
echo "=========================================="

if [ "$SSH_AUTH_MODE" = "key" ]; then

    echo "Starting SSH with public-key authentication..."

    exec "$PROOT" \
        -0 \
        -r "$ROOTFS" \
        -w /root \
        -b /dev \
        -b /proc \
        -b /sys \
        -b /etc/resolv.conf \
        /usr/sbin/dropbear \
        -F \
        -E \
        -p "$SERVER_PORT" \
        -r /etc/dropbear/dropbear_ed25519_host_key \
        -s

else

    echo "Starting SSH with password authentication..."

    exec "$PROOT" \
        -0 \
        -r "$ROOTFS" \
        -w /root \
        -b /dev \
        -b /proc \
        -b /sys \
        -b /etc/resolv.conf \
        /usr/sbin/dropbear \
        -F \
        -E \
        -p "$SERVER_PORT" \
        -r /etc/dropbear/dropbear_ed25519_host_key

fi

echo "Starting SSH server..."

if [ "$SSH_AUTH_MODE" = "key" ]; then
    "$PROOT" -0 -r "$ROOTFS" -w /root \
        -b /dev -b /proc -b /sys -b /etc/resolv.conf \
        /usr/sbin/dropbear \
        -p "$SERVER_PORT" \
        -r /etc/dropbear/dropbear_ed25519_host_key \
        -s
else
    "$PROOT" -0 -r "$ROOTFS" -w /root \
        -b /dev -b /proc -b /sys -b /etc/resolv.conf \
        /usr/sbin/dropbear \
        -p "$SERVER_PORT" \
        -r /etc/dropbear/dropbear_ed25519_host_key
fi
echo "=========================================="
echo "Starting Ubuntu terminal..."
echo "=========================================="

export TERM=xterm-256color

exec "$PROOT" -0 \
    -r "$ROOTFS" \
    -w /root \
    -b /dev \
    -b /proc \
    -b /sys \
    -b /etc/resolv.conf \
    /bin/bash --login -i
