#!/bin/bash
# Install AUR packages using yay
# Source: omarchy-base-aur.packages, omarchy-arm-aur.packages
set -e

echo "Setting up yay for AUR access..."

# Create a temporary build user (yay can't run as root)
useradd -m -s /bin/bash builder 2>/dev/null || true
echo "builder ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/builder

# Install yay from AUR
su - builder -c '
  cd /tmp
  git clone https://aur.archlinux.org/yay-bin.git
  cd yay-bin
  makepkg -si --noconfirm
'

echo "Installing AUR packages..."

# Base AUR packages
AUR_PACKAGES="
  hyprshade
  aether
  elephant
  elephant-bluetooth
  elephant-calc
  elephant-clipboard
  elephant-desktopapplications
  elephant-files
  elephant-menus
  elephant-providerlist
  elephant-runner
  elephant-symbols
  elephant-todo
  elephant-unicode
  elephant-websearch
  python-terminaltexteffects
  ttf-ia-writer
  tzupdate
  ufw-docker
  xdg-terminal-exec
"

# ARM-specific AUR packages
ARM_AUR_PACKAGES="
  blueberry
  hyprland-preview-share-picker-git
  localsend-bin
  wayfreeze-git
"

# Install all AUR packages
for pkg in $AUR_PACKAGES $ARM_AUR_PACKAGES; do
  echo "Installing AUR: $pkg"
  su - builder -c "yay -S --noconfirm --needed $pkg" || echo "WARNING: Failed to install $pkg, skipping"
done

# Skipping heavy packages that need special handling in the image:
# - claude-code (npm package, installed via mise/npm at runtime)
# - opencode (npm package)
# - typora (may not have ARM build)
# - omarchy-chromium-bin (large, handled by arm_install_scripts)

# Update icon cache
gtk-update-icon-cache -f /usr/share/icons/hicolor/ 2>/dev/null || true

# Clean up build user
rm -f /etc/sudoers.d/builder

echo "AUR packages installed."
