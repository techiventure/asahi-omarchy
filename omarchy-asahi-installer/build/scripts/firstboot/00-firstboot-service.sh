#!/bin/bash
# Install the Omarchy first-boot systemd service
set -e

echo "Installing first-boot service..."

# Copy the systemd service unit
cp /files/systemd/omarchy-firstboot.service /etc/systemd/system/

# Copy the first-boot script
cp /files/systemd/omarchy-firstboot /usr/local/bin/omarchy-firstboot
chmod +x /usr/local/bin/omarchy-firstboot

# Create sentinel file (service only runs while this exists)
touch /etc/omarchy-firstboot

# Enable the service
systemctl enable omarchy-firstboot.service

# Remove the default alarm user (from Arch ARM base)
userdel -r alarm 2>/dev/null || true

# Lock root password (will be unlocked during firstboot if needed)
# Actually keep root accessible for emergency -- firstboot will lock it after user creation
echo "root:root" | chpasswd

# Disable SDDM initially (firstboot enables it after user creation)
systemctl disable sddm.service 2>/dev/null || true

echo "First-boot service installed."
