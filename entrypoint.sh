
#!/bin/sh
set -eu

echo "=========================================="
echo "          UBUNTU VPS STARTUP"
echo "=========================================="

# Pterodactyl variables
: "${SERVER_PORT:?SERVER_PORT is required}"
: "${UBUNTU_VERSION:=24.04}"
: "${SSH_AUTH_MODE:=password}"
: "${SSH_PASSWORD:=}"
: "${SSH_PUBLIC_KEY:=}"

# ==========================================
# Validate Ubuntu version
# ==========================================

case "$UBUNTU_VERSION" in
    20.04|22.04|24.04|26.04)
        ;;
    *)
        echo "ERROR: Unsupported Ubuntu version: $UBUNTU_VERSION"
        exit 1
        ;;
esac

# ==========================================
# Validate port
# ==========================================

case "$SERVER_PORT" in
    ''|*[!0-9]*)
        echo "ERROR: Invalid SERVER_PORT"
        exit 1
        ;;
esac

if [ "$SERVER_PORT" -lt 1 ] || [ "$SERVER_PORT" -gt 65535 ]; then
    echo "ERROR: Invalid SSH port"
    exit 1
fi

# ==========================================
# Validate authentication mode
# ==========================================

case "$SSH_AUTH_MODE" in
    password)
        [ -n "$SSH_PASSWORD" ] || {
            echo "ERROR: SSH_PASSWORD is empty"
            exit 1
        }
        ;;
    key)
        [ -n "$SSH_PUBLIC_KEY" ] || {
            echo "ERROR: SSH_PUBLIC_KEY is empty"
            exit 1
        }
        ;;
    both)
        [ -n "$SSH_PASSWORD" ] && [ -n "$SSH_PUBLIC_KEY" ] || {
            echo "ERROR: Password and public key are required"
            exit 1
        }
        ;;
    *)
        echo "ERROR: SSH_AUTH_MODE must be password, key or both"
        exit 1
        ;;
esac

# ==========================================
# Locate PRoot
# ==========================================

PROOT="$(command -v proot || true)"

if [ -z "$PROOT" ] || [ ! -x "$PROOT" ]; then
    echo "ERROR: PRoot not found"
    exit 1
fi

echo "PRoot found: $PROOT"

# ==========================================
# Ubuntu root filesystem
# ==========================================

ROOTFS="/home/container/ubuntu-rootfs"

mkdir -p /home/container

if [ ! -f "$ROOTFS/.ptero-ubuntu-version" ] || \
   [ "$(cat "$ROOTFS/.ptero-ubuntu-version")" != "$UBUNTU_VERSION" ]; then

    echo "Installing Ubuntu $UBUNTU_VERSION..."

    rm -rf "$ROOTFS"

    /install-ubuntu.sh "$UBUNTU_VERSION" "$ROOTFS"

    mkdir -p "$ROOTFS"
    printf '%s\n' "$UBUNTU_VERSION" > "$ROOTFS/.ptero-ubuntu-version"
fi

if [ ! -x "$ROOTFS/bin/bash" ]; then
    echo "ERROR: Ubuntu bash not found"
    exit 1
fi

# ==========================================
# Ubuntu command helper
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
# Install Dropbear
# ==========================================

if [ ! -x "$ROOTFS/usr/sbin/dropbear" ]; then
    echo "Installing Dropbear..."

    ubuntu /usr/bin/env DEBIAN_FRONTEND=noninteractive \
        /bin/bash -c '
            apt-get update
            apt-get install -y --no-install-recommends dropbear passwd
            rm -rf /var/lib/apt/lists/*
        '
fi

# ==========================================
# Configure root password
# ==========================================

if [ "$SSH_AUTH_MODE" = "password" ] || \
   [ "$SSH_AUTH_MODE" = "both" ]; then

    echo "Configuring root password..."

    printf 'root:%s\n' "$SSH_PASSWORD" | ubuntu /usr/sbin/chpasswd
else
    ubuntu /usr/bin/passwd -l root >/dev/null 2>&1 || true
fi

# ==========================================
# Configure SSH public key
# ==========================================

if [ "$SSH_AUTH_MODE" = "key" ] || \
   [ "$SSH_AUTH_MODE" = "both" ]; then

    echo "Configuring SSH public key..."

    mkdir -p "$ROOTFS/root/.ssh"

    printf '%s\n' "$SSH_PUBLIC_KEY" \
        > "$ROOTFS/root/.ssh/authorized_keys"

    chmod 700 "$ROOTFS/root/.ssh"
    chmod 600 "$ROOTFS/root/.ssh/authorized_keys"
fi

# ==========================================
# Generate RSA SSH host key
# ==========================================

echo "Checking SSH host key..."

mkdir -p "$ROOTFS/etc/dropbear"

if [ ! -s "$ROOTFS/etc/dropbear/dropbear_rsa_host_key" ]; then
    echo "Generating RSA SSH host key..."

    ubuntu /usr/bin/dropbearkey \
        -t rsa \
        -s 3072 \
        -f /etc/dropbear/dropbear_rsa_host_key
fi

# ==========================================
# Verify Dropbear
# ==========================================

if [ ! -x "$ROOTFS/usr/sbin/dropbear" ]; then
    echo "ERROR: Dropbear executable not found"
    exit 1
fi

# ==========================================
# Start SSH in background
# ==========================================

echo "Starting SSH server in background..."

if [ "$SSH_AUTH_MODE" = "key" ]; then

    "$PROOT" \
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
        -r /etc/dropbear/dropbear_rsa_host_key \
        -s &

else

    "$PROOT" \
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
        -r /etc/dropbear/dropbear_rsa_host_key &

fi

SSH_PID=$!

sleep 2

if ! kill -0 "$SSH_PID" 2>/dev/null; then
    echo "WARNING: SSH process may have exited"
else
    echo "SSH process started: $SSH_PID"
fi

# ==========================================
# Start Ubuntu in Pterodactyl Console
# ==========================================

echo ""
echo "=========================================="
echo "           UBUNTU VPS READY"
echo "=========================================="
echo "Ubuntu: $UBUNTU_VERSION"
echo "SSH user: root"
echo "SSH port: $SERVER_PORT"
echo "Authentication: $SSH_AUTH_MODE"
echo "=========================================="
echo ""
echo "Starting Ubuntu panel terminal..."

export TERM="${TERM:-xterm-256color}"
export HOME=/root

exec "$PROOT" \
    -0 \
    -r "$ROOTFS" \
    -w /root \
    -b /dev \
    -b /proc \
    -b /sys \
    -b /etc/resolv.conf \
    /bin/bash --login -i
