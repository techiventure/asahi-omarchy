#!/bin/bash
# Install Asahi-specific packages (Apple Silicon hardware support)
# Source: omarchy-asahi.packages
set -e

echo "Installing Asahi-specific packages..."

PACKAGES="
  asahi-audio
  vulkan-asahi
"

pacman --noconfirm --needed -S $PACKAGES

echo "Asahi packages installed."
