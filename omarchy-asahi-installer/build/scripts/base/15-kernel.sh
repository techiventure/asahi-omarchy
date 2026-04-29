#!/bin/bash
# Install Asahi kernel and configure mkinitcpio
set -e

echo "Configuring kernel..."

# Configure mkinitcpio hooks for Asahi
sed -i 's/^HOOKS=(base.*/HOOKS=(base asahi udev autodetect microcode modconf kms keyboard keymap consolefont block filesystems fsck)/' \
  /etc/mkinitcpio.conf

# Create m1n1 boot directory
mkdir -p /boot/efi/m1n1

# Install Asahi kernel
pacman --noconfirm -S linux-asahi asahi-meta

echo "Kernel installed."
