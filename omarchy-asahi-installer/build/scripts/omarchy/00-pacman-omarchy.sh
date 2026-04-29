#!/bin/bash
# Configure pacman for Omarchy ARM (replace default Arch ARM config)
set -e

echo "Configuring pacman for Omarchy ARM..."

# Copy full Omarchy ARM pacman config
cp /files/pacman/pacman.conf.arm /etc/pacman.conf
cp /files/pacman/mirrorlist.arm /etc/pacman.d/mirrorlist
cp /files/pacman/mirrorlist.omarchy-asahi /etc/pacman.d/mirrorlist.omarchy-asahi

# Refresh package databases with new config
pacman -Syy --noconfirm

echo "Omarchy pacman configured."
