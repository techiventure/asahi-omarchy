# First-Boot Service

After the Asahi installer writes our image and the user reboots, the system needs to:
1. Connect to wifi
2. Create a user account
3. Apply final personalization
4. Disable the first-boot service so it doesn't run again

## Architecture

```
Boot
  |
  v
systemd starts omarchy-firstboot.service (multi-user.target)
  |
  v
omarchy-firstboot script runs on TTY1:
  1. Welcome screen
  2. Wifi connection (nmtui or nmcli)
  3. User creation (username, password, name, email)
  4. Final config (git config, etc.)
  5. Disable self
  6. Reboot into SDDM -> Hyprland
```

## systemd Service Unit

File: `/etc/systemd/system/omarchy-firstboot.service`

```ini
[Unit]
Description=Omarchy First Boot Setup
After=network-online.target
Wants=network-online.target
ConditionPathExists=/etc/omarchy-firstboot

[Service]
Type=oneshot
ExecStart=/usr/local/bin/omarchy-firstboot
StandardInput=tty
StandardOutput=tty
TTYPath=/dev/tty1
TTYReset=yes
TTYVHangup=yes
RemainAfterExit=no

[Install]
WantedBy=multi-user.target
```

Key details:
- `ConditionPathExists=/etc/omarchy-firstboot` -- only runs if this sentinel file exists. The script deletes it when done, so it never runs again.
- `StandardInput=tty` + `TTYPath=/dev/tty1` -- the script runs interactively on the first virtual console so the user can type input.
- `After=network-online.target` -- waits for network stack to be ready (but wifi won't be connected yet).

## First-Boot Script

File: `/usr/local/bin/omarchy-firstboot`

```bash
#!/bin/bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

clear

echo -e "${BOLD}"
echo "  ____  __  __    _    ____   ____ _   ___   __"
echo " / __ \|  \/  |  / \  |  _ \ / ___| | | \ \ / /"
echo "| |  | | |\/| | / _ \ | |_) | |   | |_| |\ V / "
echo "| |  | | |  | |/ ___ \|  _ <| |___|  _  | | |  "
echo " \____/|_|  |_/_/   \_|_| \_\\\\____|_| |_| |_|  "
echo -e "${NC}"
echo ""
echo -e "${BOLD}Welcome to Omarchy! Let's set up your system.${NC}"
echo ""

# ─────────────────────────────────────────────
# Step 1: Network Connection
# ─────────────────────────────────────────────

echo -e "${BLUE}Step 1: Connect to the internet${NC}"
echo ""

# Check if already connected (ethernet)
if ping -c 1 -W 3 archlinuxarm.org &>/dev/null; then
    echo -e "${GREEN}Already connected to the internet.${NC}"
else
    echo "You need an internet connection to complete setup."
    echo ""
    echo "Choose connection method:"
    echo "  1. WiFi (recommended for MacBooks)"
    echo "  2. Skip (if using ethernet)"
    echo ""
    read -p "Choice [1]: " net_choice
    net_choice=${net_choice:-1}

    if [[ $net_choice == "1" ]]; then
        # Use nmtui for a friendly TUI wifi picker
        nmtui connect

        # Verify connection
        echo ""
        echo "Verifying connection..."
        sleep 3
        if ! ping -c 1 -W 5 archlinuxarm.org &>/dev/null; then
            echo -e "${RED}Could not reach the internet. Please try again.${NC}"
            echo "You can run 'nmcli device wifi connect <SSID> password <password>' manually."
            echo "Then run 'omarchy-firstboot' to continue setup."
            exit 1
        fi
        echo -e "${GREEN}Connected!${NC}"
    fi
fi

echo ""

# ─────────────────────────────────────────────
# Step 2: System Update (optional but recommended)
# ─────────────────────────────────────────────

echo -e "${BLUE}Step 2: Checking for updates...${NC}"
pacman -Syu --noconfirm || true
echo ""

# ─────────────────────────────────────────────
# Step 3: User Account
# ─────────────────────────────────────────────

echo -e "${BLUE}Step 3: Create your user account${NC}"
echo ""

# Username
while true; do
    read -p "Username: " username
    if [[ -z $username ]]; then
        echo -e "${RED}Username cannot be empty.${NC}"
        continue
    fi
    if [[ ! $username =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        echo -e "${RED}Invalid username. Use lowercase letters, numbers, hyphens, underscores.${NC}"
        continue
    fi
    break
done

# Password
while true; do
    read -s -p "Password: " password
    echo ""
    read -s -p "Confirm password: " password2
    echo ""
    if [[ $password != "$password2" ]]; then
        echo -e "${RED}Passwords don't match.${NC}"
        continue
    fi
    if [[ -z $password ]]; then
        echo -e "${RED}Password cannot be empty.${NC}"
        continue
    fi
    break
done

# Full name
read -p "Full name: " fullname

# Email (for git config)
while true; do
    read -p "Email: " email
    if [[ -z $email ]]; then
        echo -e "${RED}Email cannot be empty (needed for git config).${NC}"
        continue
    fi
    break
done

echo ""
echo "Creating user '$username'..."

# Create user with home directory, add to wheel group
useradd -m -G wheel,video,audio,input -s /bin/zsh -c "$fullname" "$username"
echo "$username:$password" | chpasswd

# Configure sudo for wheel group
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# Git config
su - "$username" -c "git config --global user.name \"$fullname\""
su - "$username" -c "git config --global user.email \"$email\""

echo -e "${GREEN}User '$username' created.${NC}"
echo ""

# ─────────────────────────────────────────────
# Step 4: Final Configuration
# ─────────────────────────────────────────────

echo -e "${BLUE}Step 4: Applying final configuration...${NC}"

# Set hostname
read -p "Hostname [omarchy]: " hostname
hostname=${hostname:-omarchy}
echo "$hostname" > /etc/hostname

# Set timezone interactively
echo ""
echo "Select timezone (e.g., America/New_York, Europe/London, Asia/Tokyo):"
read -p "Timezone [UTC]: " timezone
timezone=${timezone:-UTC}
ln -sf "/usr/share/zoneinfo/$timezone" /etc/localtime
hwclock --systohc

# Generate locales
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Disable root login (user has sudo)
passwd -l root

# Enable display manager
systemctl enable sddm.service

echo ""
echo -e "${GREEN}Configuration complete!${NC}"

# ─────────────────────────────────────────────
# Step 5: Cleanup and Reboot
# ─────────────────────────────────────────────

# Remove sentinel file so this service never runs again
rm -f /etc/omarchy-firstboot

# Disable the service
systemctl disable omarchy-firstboot.service

echo ""
echo -e "${BOLD}Setup complete! Your system will reboot in 5 seconds.${NC}"
echo -e "You'll be greeted by the Omarchy login screen."
echo ""
sleep 5
reboot
```

## Sentinel File

File: `/etc/omarchy-firstboot`

This is an empty file whose presence tells the systemd service to run. Contents don't matter, but for documentation:

```
# This file triggers the Omarchy first-boot setup.
# It is automatically removed after setup completes.
# Do not delete manually unless you want to skip first-boot setup.
```

## What's Pre-Configured in the Image (vs First-Boot)

### Pre-configured in the rootfs image (BUILD.md)

- All packages installed
- Hyprland, SDDM, Pipewire configured
- Omarchy themes, configs in /etc/skel/
- Omarchy bin/ scripts in /usr/local/bin/
- systemd services enabled (bluetooth, NetworkManager, etc.)
- Locale files present (but not selected)
- GRUB + kernel installed

### Configured at first boot

- Wifi connection
- User account (username, password, name, email)
- Git config
- Hostname
- Timezone
- Locale selection
- Root account locked
- SDDM enabled (after user exists)

## Error Handling

- If wifi fails, the script exits with instructions to retry manually
- If the user presses Ctrl+C, the script exits. They can run `/usr/local/bin/omarchy-firstboot` manually later.
- If the script crashes, the sentinel file still exists, so it will retry on next boot.
- `pacman -Syu` failures are non-fatal (|| true) since the image is already complete.

## Alternative: Login-Based First Boot

Instead of a systemd service on TTY1, an alternative is:

1. Image ships with a default `alarm` user (password: `alarm`) and root (password: `root`)
2. Auto-login as root to TTY1
3. `.bash_profile` runs the first-boot script
4. Script creates the real user, removes alarm user, configures system

This is simpler but less clean. The systemd service approach is preferred because:
- No default passwords in the image
- Clean service lifecycle (enable → run → disable)
- Proper TTY handling
- Can be conditioned on sentinel file

## Testing

To test the first-boot service without reinstalling:

```bash
# Re-create sentinel file
sudo touch /etc/omarchy-firstboot

# Re-enable service
sudo systemctl enable omarchy-firstboot.service

# Reboot
sudo reboot
```
