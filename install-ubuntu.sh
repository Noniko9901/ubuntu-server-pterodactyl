#!/bin/sh
set -eu
VERSION="${1:?version required}"
ROOTFS="${2:?rootfs path required}"

case "$VERSION" in
  20.04) SUITE=focal ;;
  22.04) SUITE=jammy ;;
  24.04) SUITE=noble ;;
  26.04) SUITE=resolute ;;
  *) echo "Unsupported Ubuntu version: $VERSION" >&2; exit 1 ;;
esac

ARCH="$(uname -m)"
case "$ARCH" in
  x86_64) UBUNTU_ARCH=amd64 ;;
  aarch64) UBUNTU_ARCH=arm64 ;;
  *) echo "Unsupported architecture: $ARCH" >&2; exit 1 ;;
esac

# Official Ubuntu cloud image rootfs tarballs.
URL="https://cloud-images.ubuntu.com/minimal/releases/${SUITE}/release/ubuntu-${VERSION}-minimal-cloudimg-${UBUNTU_ARCH}-root.tar.xz"
mkdir -p "$ROOTFS"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT
echo "Downloading Ubuntu ${VERSION} (${UBUNTU_ARCH})..."
curl -fL --retry 4 --retry-delay 3 "$URL" -o "$TMP"
tar -xJf "$TMP" -C "$ROOTFS"
mkdir -p "$ROOTFS"/{dev,proc,sys,run,tmp,root,etc/dropbear}
chmod 1777 "$ROOTFS/tmp"
printf '%s\n' "$VERSION" > "$ROOTFS/.ptero-ubuntu-version"

# Ensure basic runtime files exist for a container/PRoot environment.
printf 'nameserver 1.1.1.1\nnameserver 8.8.8.8\n' > "$ROOTFS/etc/resolv.conf"
