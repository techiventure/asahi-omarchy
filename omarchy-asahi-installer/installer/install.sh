#!/bin/sh
# Omarchy Installer for Apple Silicon Macs
# Forked from Asahi ALARM installer, self-hosted.
#
# Usage (from macOS):
#   curl -fsSL https://r2-foss.techiventure.com/asahi-omarchy/installer/install.sh | sh

set -e

# Verify running on macOS
if [ ! -d /System ]; then
  echo "ERROR: This installer must be run from macOS."
  echo "If you're already running Arch Linux ARM, use the standard omarchy installer instead."
  exit 1
fi

echo ""
echo "  ____  __  __    _    ____   ____ _   ___   __"
echo " / __ \|  \/  |  / \  |  _ \ / ___| | | \ \ / /"
echo "| |  | | |\/| | / _ \ | |_) | |   | |_| |\ V / "
echo "| |  | | |  | |/ ___ \|  _ <| |___|  _  | | |  "
echo " \____/|_|  |_/_/   \_|_| \_\\\____|_| |_| |_|  "
echo ""
echo "Omarchy Installer for Apple Silicon"
echo ""

# macOS version check
MACOS_VER=$(sw_vers -productVersion)
echo "macOS version: $MACOS_VER"

# All hosted on our R2 CDN
CDN_BASE="https://r2-foss.techiventure.com/asahi-omarchy"

# Our forked installer (Python) and data
INSTALLER_TARBALL_URL="${CDN_BASE}/installer/installer.tar.gz"
INSTALLER_DATA_URL="${CDN_BASE}/installer/installer_data.json"

TMPDIR=$(mktemp -d)
cd "$TMPDIR"

echo "Downloading installer..."
curl -L -o installer.tar.gz "$INSTALLER_TARBALL_URL"

echo "Downloading configuration..."
curl -L -o installer_data.json "$INSTALLER_DATA_URL"

echo "Extracting..."
tar xf installer.tar.gz

echo ""
echo "Starting installation..."
echo "NOTE: You will be asked how much disk space to allocate to Omarchy."
echo "      Recommended: at least 50 GB."
echo ""

cd installer
exec sudo caffeinate -dis ./install.sh "$TMPDIR/installer_data.json"
