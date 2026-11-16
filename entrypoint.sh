
# ==========================================
# Start SSH + Pterodactyl Console
# ==========================================

echo "=========================================="
echo "       UBUNTU VPS READY"
echo "=========================================="
echo "Ubuntu: ${UBUNTU_VERSION}"
echo "SSH user: root"
echo "SSH port: ${SERVER_PORT}"
echo "Authentication: ${SSH_AUTH_MODE}"
echo "=========================================="

# Start Dropbear in background
echo "Starting SSH server..."

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
        -F -E \
        -p "$SERVER_PORT" \
        -r /etc/dropbear/dropbear_ed25519_host_key \
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
        -F -E \
        -p "$SERVER_PORT" \
        -r /etc/dropbear/dropbear_ed25519_host_key &
fi

sleep 2

# Start interactive Ubuntu terminal in Pterodactyl Console
echo ""
echo "=========================================="
echo "       UBUNTU CONSOLE STARTED"
echo "=========================================="
echo ""

export TERM="${TERM:-xterm-256color}"

exec "$PROOT" \
    -0 \
    -r "$ROOTFS" \
    -w /root \
    -b /dev \
    -b /proc \
    -b /sys \
    -b /etc/resolv.conf \
    /bin/bash --login -i
