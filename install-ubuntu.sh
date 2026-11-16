
#!/bin/sh
set -eu

# ==========================================
# Ubuntu Pterodactyl Installer
# Supported: 20.04, 22.04, 24.04, 26.04
# ==========================================

VERSION="${1:?Missing Ubuntu version}"
ROOTFS="${2:?Missing rootfs directory}"

echo "======================================"
echo " Ubuntu Pterodactyl Installer"
echo " Version: ${VERSION}"
echo "======================================"

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
echo "Architecture: $UBUNTU_ARCH"
echo "Download URL: $URL"

# Prepare directories
mkdir -p "$ROOTFS"
mkdir -p "$HOME"

# Download archive
TMP="$HOME/ubuntu-${VERSION}-rootfs.tar.xz"

rm -f "$TMP"

echo "Downloading Ubuntu ${VERSION}..."

curl -fL \
    --retry 4 \
    --retry-delay 3 \
    --connect-timeout 30 \
    "$URL" \
    -o "$TMP"

echo "Download completed."

# Check downloaded archive
if [ ! -s "$TMP" ]; then
    echo "ERROR: Downloaded archive is empty."
    exit 1
fi

# Extract Ubuntu filesystem
echo "Extracting Ubuntu filesystem..."

mkdir -p "$ROOTFS"

tar -xJf "$TMP" \
    -C "$ROOTFS" \
    --exclude='./dev/*' \
    --exclude='dev/*' \
    --exclude='./proc/*' \
    --exclude='proc/*' \
    --exclude='./sys/*' \
    --exclude='sys/*' \
    --exclude='./run/*' \
    --exclude='run/*'

echo "Extraction completed."

# Remove downloaded archive
rm -f "$TMP"

# Create required system directories
echo "Preparing Ubuntu directories..."

mkdir -p \
    "$ROOTFS/dev" \
    "$ROOTFS/proc" \
    "$ROOTFS/sys" \
    "$ROOTFS/run" \
    "$ROOTFS/tmp" \
    "$ROOTFS/root" \
    "$ROOTFS/etc" \
    "$ROOTFS/etc/dropbear"

chmod 1777 "$ROOTFS/tmp"

# Configure DNS
echo "Configuring DNS..."

rm -f "$ROOTFS/etc/resolv.conf"

cat > "$ROOTFS/etc/resolv.conf" <<EOF
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF

# Save installed version
printf '%s\n' "$VERSION" > "$ROOTFS/.ptero-ubuntu-version"

# Verify installation
if [ ! -x "$ROOTFS/bin/bash" ]; then
    echo "ERROR: Ubuntu bash was not found."
    exit 1
fi

if [ ! -d "$ROOTFS/etc" ]; then
    echo "ERROR: Ubuntu /etc directory is missing."
    exit 1
fi

echo "======================================"
echo " Ubuntu installation completed!"
echo " Ubuntu version: $VERSION"
echo " Architecture: $UBUNTU_ARCH"
echo " Rootfs: $ROOTFS"
echo "======================================"
