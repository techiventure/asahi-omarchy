#!/bin/bash
# Configure pacman for Arch Linux ARM + Omarchy Asahi repo
set -e

echo "Configuring pacman..."

# Enable parallel downloads
sed -i 's/^#ParallelDownloads = 5/ParallelDownloads = 5/' /etc/pacman.conf

# Add our Omarchy Asahi repo before [core]
sed -i '/\[core\]/i [omarchy-asahi]\nSigLevel = Optional TrustAll\nInclude = /etc/pacman.d/mirrorlist.omarchy-asahi\n' /etc/pacman.conf

# Copy mirrorlists from overlay
cp /files/pacman/mirrorlist.omarchy-asahi /etc/pacman.d/mirrorlist.omarchy-asahi
cp /files/pacman/mirrorlist.arm /etc/pacman.d/mirrorlist

# Initialize keyring
systemd-sysusers
pacman-key --init
pacman-key --populate

echo "Pacman configured."
