
#!/bin/sh
set -eu

# ==========================================
# Ubuntu Multi-Version Pterodactyl Installer
# Ubuntu 20.04 / 22.04 / 24.04 / 26.04
# ==========================================

VERSION="${1:?Missing Ubuntu version}"
ROOTFS="${2:?Missing rootfs directory}"

echo "=========================================="
echo "       UBUNTU VPS INSTALLER"
echo "=========================================="

# Select Ubuntu release
case "$VERSION" in
    20.04)
        SUITE="focal"
        ;;
    22.04)
        SUITE="jammy"
        ;;
    24.04)
        SUITE="noble"
        ;;
    26.04)
        SUITE="resolute"
        ;;
    *)
        echo "ERROR: Unsupported Ubuntu version: $VERSION"
        exit 1
        ;;
esac

# Detect architecture
ARCH="$(uname -m)"

case "$ARCH" in
    x86_64)
        UBUNTU_ARCH="amd64"
        ;;
    aarch64)
        UBUNTU_ARCH="arm64"
        ;;
    *)
        echo "ERROR: Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

# Official Ubuntu minimal cloud image
URL="https://cloud-images.ubuntu.com/minimal/releases/${SUITE}/release/ubuntu-${VERSION}-minimal-cloudimg-${UBUNTU_ARCH}-root.tar.xz"

echo "Ubuntu version: $VERSION"
echo "Ubuntu codename: $SUITE"
echo "Architecture: $UBUNTU_ARCH"
echo "Download URL: $URL"

# Prepare directories
mkdir -p "$ROOTFS"
mkdir -p "$HOME"

# Temporary archive
TMP="$HOME/ubuntu-${VERSION}-rootfs.tar.xz"

rm -f "$TMP"

# Download Ubuntu
echo ""
echo "[1/5] Downloading Ubuntu..."

curl -fL \
    --retry 4 \
    --retry-delay 3 \
    --connect-timeout 30 \
    "$URL" \
    -o "$TMP"

if [ ! -s "$TMP" ]; then
    echo "ERROR: Ubuntu archive is empty!"
    exit 1
fi

echo "Download completed."

# Clean root filesystem
echo ""
echo "[2/5] Preparing root filesystem..."

rm -rf "$ROOTFS"
mkdir -p "$ROOTFS"

# Extract Ubuntu without special host device files
echo ""
echo "[3/5] Extracting Ubuntu..."

tar -xJf "$TMP" \
    -C "$ROOTFS" \
    --no-same-owner \
    --exclude='./dev' \
    --exclude='./dev/*' \
    --exclude='dev' \
    --exclude='dev/*' \
    --exclude='./proc' \
    --exclude='./proc/*' \
    --exclude='proc' \
    --exclude='proc/*' \
    --exclude='./sys' \
    --exclude='./sys/*' \
    --exclude='sys' \
    --exclude='sys/*' \
    --exclude='./run' \
    --exclude='./run/*' \
    --exclude='run' \
    --exclude='run/*'

echo "Extraction completed."

# Remove downloaded archive
rm -f "$TMP"

# Create required directories
echo ""
echo "[4/5] Creating system directories..."

mkdir -p "$ROOTFS/dev"
mkdir -p "$ROOTFS/proc"
mkdir -p "$ROOTFS/sys"
mkdir -p "$ROOTFS/run"
mkdir -p "$ROOTFS/tmp"
mkdir -p "$ROOTFS/root"
mkdir -p "$ROOTFS/etc"
mkdir -p "$ROOTFS/etc/dropbear"

chmod 1777 "$ROOTFS/tmp"

# Configure DNS
echo "Configuring DNS..."

rm -f "$ROOTFS/etc/resolv.conf"

cat > "$ROOTFS/etc/resolv.conf" <<EOF
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF

# Save Ubuntu version
printf '%s\n' "$VERSION" > "$ROOTFS/.ptero-ubuntu-version"

# Verify installation
echo ""
echo "[5/5] Verifying Ubuntu installation..."

if [ ! -x "$ROOTFS/bin/bash" ]; then
    echo "ERROR: Ubuntu bash not found!"
    exit 1
fi

if [ ! -d "$ROOTFS/etc" ]; then
    echo "ERROR: Ubuntu /etc directory missing!"
    exit 1
fi

if [ ! -f "$ROOTFS/etc/resolv.conf" ]; then
    echo "ERROR: DNS configuration missing!"
    exit 1
fi

# Success
echo ""
echo "=========================================="
echo "       UBUNTU INSTALLED SUCCESSFULLY"
echo "=========================================="
echo "Version: $VERSION"
echo "Codename: $SUITE"
echo "Architecture: $UBUNTU_ARCH"
echo "Rootfs: $ROOTFS"
echo "=========================================="
