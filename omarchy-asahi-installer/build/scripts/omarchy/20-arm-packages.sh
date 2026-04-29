#!/bin/bash
# Install ARM-specific packages from official repos
# Source: omarchy-arm-official.packages
set -e

echo "Installing ARM-specific packages..."

PACKAGES="
  e2fsprogs
  fuse2
  gst-plugin-pipewire
  libpulse
  pipewire
  pipewire-alsa
  pipewire-pulse
  wf-recorder
"

pacman --noconfirm --needed -S $PACKAGES

# Widevine from our omarchy-asahi repo (self-built)
pacman --noconfirm --needed -S omarchy-asahi/widevine || echo "WARNING: widevine not available, skipping"

echo "ARM packages installed."
