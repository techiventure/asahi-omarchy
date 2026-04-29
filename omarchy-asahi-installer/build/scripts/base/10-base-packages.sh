#!/bin/bash
# Install base system packages for Asahi Linux
set -e

echo "Installing base packages..."

# Create required boot directories
mkdir -p /boot/efi/EFI/BOOT
mkdir -p /boot/efi/m1n1
touch /boot/efi/.builder

# Remove default kernel (we'll install asahi kernel)
pacman --noconfirm -R linux-aarch64 || true

# Full system upgrade
pacman --noconfirm -Syu

# Core system packages
PACKAGES="
  asahi-scripts
  asahi-fwextract
  m1n1
  uboot-asahi
  mkinitcpio
  grub
  iwd
  sudo
  vim
  man
  networkmanager
  noto-fonts
  noto-fonts-cjk
  noto-fonts-emoji
  btrfs-progs
  wget
  git
  base-devel
"

pacman --noconfirm --needed -S $PACKAGES

echo "Base packages installed."
