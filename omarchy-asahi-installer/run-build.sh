#!/bin/bash
# Run the Omarchy Asahi image build inside a systemd-nspawn container
# Must be run as root on an aarch64 host (e.g., Fedora Asahi Remix on Apple Silicon).
#
# This replaces Docker (no official aarch64 Arch Docker image exists).
# Uses systemd-nspawn with the official Arch Linux ARM tarball.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
NSPAWN_ROOT="$SCRIPT_DIR/.nspawn-root"
ARCH_ARM_URL="https://archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz"
ARCH_ARM_TAR="$BUILD_DIR/dl/ArchLinuxARM-aarch64-latest.tar.gz"

echo "============================================"
echo "  Omarchy Asahi Image Builder (nspawn)"
echo "============================================"
echo ""
echo "Build dir: $BUILD_DIR"
echo "Architecture: $(uname -m)"
echo ""

if [[ $(uname -m) != "aarch64" ]]; then
  echo "ERROR: Must be run on aarch64."
  exit 1
fi

if [[ $(whoami) != "root" ]]; then
  echo "ERROR: Must be run as root (for systemd-nspawn and loop mounts)."
  exit 1
fi

if ! command -v systemd-nspawn &>/dev/null; then
  echo "ERROR: systemd-nspawn is required (part of systemd)."
  exit 1
fi

# ── Prepare nspawn container root ──

echo "Preparing build container..."
rm -rf "$NSPAWN_ROOT"
mkdir -p "$NSPAWN_ROOT" "$BUILD_DIR/dl"

if [[ ! -e "$ARCH_ARM_TAR" ]]; then
  echo "Downloading Arch Linux ARM tarball..."
  wget -c "$ARCH_ARM_URL" -O "$ARCH_ARM_TAR.part"
  mv "$ARCH_ARM_TAR.part" "$ARCH_ARM_TAR"
else
  echo "Using cached Arch ARM tarball."
fi

echo "Extracting container rootfs..."
bsdtar -xpf "$ARCH_ARM_TAR" -C "$NSPAWN_ROOT"

# Initialize pacman keyring and install build dependencies
echo "Installing build dependencies in container..."
systemd-nspawn -D "$NSPAWN_ROOT" --pipe /bin/bash <<'SETUP'
pacman-key --init
pacman-key --populate archlinuxarm
pacman -Syu --noconfirm
pacman -S --noconfirm --needed \
  arch-install-scripts \
  bsdtar \
  dosfstools \
  e2fsprogs \
  rsync \
  wget \
  zip \
  git \
  util-linux
SETUP

# ── Bind-mount the build directory and run ──

echo ""
echo "Running build inside nspawn container..."
echo "(This will take 15-60 minutes depending on network speed)"
echo ""

OMARCHY_REPO="${OMARCHY_REPO:-techiventure/asahi-omarchy}"
OMARCHY_REF="${OMARCHY_REF:-master}"

systemd-nspawn -D "$NSPAWN_ROOT" \
  --bind="$BUILD_DIR":/build \
  --setenv=OMARCHY_REPO="$OMARCHY_REPO" \
  --setenv=OMARCHY_REF="$OMARCHY_REF" \
  --capability=all \
  --pipe \
  /bin/bash /build/build-rootfs.sh

echo ""
echo "Cleaning up nspawn container..."
rm -rf "$NSPAWN_ROOT"

echo ""
echo "Build complete! Output:"
ls -lh "$BUILD_DIR/images/omarchy.zip" 2>/dev/null || echo "ERROR: omarchy.zip not found"
