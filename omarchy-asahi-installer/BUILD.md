# Build Process

Step-by-step guide to building the Omarchy rootfs image for Asahi ALARM.

## Prerequisites

- An aarch64 machine (M1/M2 Mac running Asahi, or aarch64 VM)
- Root access
- ~30 GB free disk space
- Internet connection
- Packages: `arch-install-scripts`, `bsdtar`, `rsync`, `zip`, `wget`

## Overview

The build process follows the same pattern as `asahi-alarm-builder`:

```
Download Arch ARM base tarball
  --> Extract into chroot
  --> Run base scripts (pacman, kernel, fstab, grub, networking)
  --> Run omarchy scripts (packages, configs, themes, binaries)
  --> Run firstboot scripts (systemd service for user setup)
  --> Clean caches
  --> Create root.img (ext4 filesystem image)
  --> Create esp/ (EFI tree with m1n1 + GRUB)
  --> Zip into omarchy.zip
```

## Directory Structure

```
build/
  |- build-rootfs.sh              # Main build script
  |- scripts/
  |    |- base/
  |    |    |- 00-pacman.sh       # Configure pacman + asahi-alarm repo
  |    |    |- 10-base-packages.sh # Install base system packages
  |    |    |- 15-kernel.sh       # Install asahi kernel + mkinitcpio
  |    |    |- 20-fstab.sh        # Generate /etc/fstab
  |    |    |- 30-grub.sh         # Install + configure GRUB bootloader
  |    |    |- 30-networkmanager.sh # Enable NetworkManager + iwd
  |    |- omarchy/
  |    |    |- 00-pacman-omarchy.sh  # Add omarchy ARM repos + mirrors
  |    |    |- 10-base-packages.sh   # Install omarchy-base packages
  |    |    |- 20-arm-packages.sh    # Install omarchy-arm packages
  |    |    |- 30-asahi-packages.sh  # Install asahi-specific packages
  |    |    |- 40-aur-packages.sh    # Install AUR packages via yay
  |    |    |- 50-arm-binaries.sh    # Install pre-built ARM binaries (1password, obsidian, etc.)
  |    |    |- 60-config.sh          # Apply omarchy configs, themes, dotfiles
  |    |    |- 70-services.sh        # Enable omarchy systemd services
  |    |- firstboot/
  |         |- 00-firstboot-service.sh # Install first-boot systemd service
  |- files/
       |- mirrorlist.asahi-alarm       # Asahi ALARM mirror
       |- mirrorlist.arm               # Arch Linux ARM mirrors
       |- pacman.conf.arm              # ARM pacman config
       |- omarchy-firstboot.service    # systemd unit
       |- omarchy-firstboot            # First-boot script
```

## Build Steps (Detailed)

### Step 1: Download Base Image

```bash
wget -c https://archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz
```

This is the official Arch Linux ARM generic aarch64 tarball (~450 MB). Same base used by asahi-alarm-builder.

### Step 2: Extract and Prepare Chroot

```bash
mkdir -p root
bsdtar -xpf ArchLinuxARM-aarch64-latest.tar.gz -C root
mount --bind root root
```

The bind mount is needed for `arch-chroot` to work properly.

### Step 3: Run Base Scripts (from asahi-alarm-builder)

These are adapted from upstream `asahi-alarm-builder/scripts/base/`:

#### 00-pacman.sh
- Enable ParallelDownloads
- Add `[asahi-alarm]` repo to pacman.conf
- Copy mirrorlist.asahi-alarm
- Initialize pacman keyring

#### 10-base-packages.sh
- Remove default `linux-aarch64` kernel
- Install base packages: `asahi-scripts asahi-fwextract m1n1 uboot-asahi mkinitcpio grub iwd sudo vim man networkmanager noto-fonts btrfs-progs`

#### 15-kernel.sh
- Configure mkinitcpio HOOKS for Asahi
- Install `linux-asahi` kernel and `asahi-meta`

#### 20-fstab.sh
- Write /etc/fstab with correct UUIDs for root (ext4) and EFI (vfat)

#### 30-grub.sh
- Build GRUB EFI image for arm64
- Configure GRUB to find root partition by UUID
- Install GRUB modules and themes

#### 30-networkmanager.sh
- Configure NetworkManager with iwd backend
- Enable NetworkManager and iwd services

### Step 4: Run Omarchy Scripts (new)

These install all Omarchy components into the rootfs:

#### 00-pacman-omarchy.sh

Configure ARM-specific repos. Based on the existing `default/pacman/pacman.conf.arm` in omarchy:

```bash
# Add Arch Linux ARM repos (core, extra, alarm, aur)
# Add asahi-alarm repo
# Add omacom.io ARM repo (for pre-built ARM packages)
# Disable multilib (not available on ARM)
```

#### 10-base-packages.sh

Install cross-platform omarchy packages. Source: `install/packaging/omarchy-base-official.packages`

These are the ~126 packages from official Arch repos that work on both x86 and ARM:
- Hyprland + wayland stack
- Development tools (git, neovim, lazygit, etc.)
- Audio (pipewire, wireplumber)
- System utilities
- Fonts

#### 20-arm-packages.sh

Install ARM-specific packages. Source: `install/packaging/omarchy-arm-official.packages`

```
pipewire-jack (must be installed before jack2 to avoid conflicts)
widevine
asahi-audio
vulkan-asahi
fuse2
...
```

#### 30-asahi-packages.sh

Install Asahi-specific packages. Source: `install/packaging/omarchy-asahi.packages`

```
asahi-audio
vulkan-asahi
```

#### 40-aur-packages.sh

Install AUR packages. Source: `install/packaging/omarchy-arm-aur.packages`

This requires building `yay` first (or using a pre-built binary), then:
```
blueberry
localsend-bin
wayfreeze-git
...
```

Note: AUR packages are built from source, which is slow on ARM. Consider pre-building these.

#### 50-arm-binaries.sh

Install pre-built ARM64 binaries that don't have ARM packages. These come from the existing `install/arm_install_scripts/` in omarchy:

- **1Password**: ARM64 tarball from official site
- **Obsidian**: ARM64 AppImage
- **Walker**: Pre-built ARM64 binary (avoids long compilation)
- **ASDControl**: Apple Silicon display control binary
- **Omarchy Chromium**: Custom ARM64 build with Widevine
- **Omarchy LazyVim**: Built from source for ARM

#### 60-config.sh

Apply all omarchy configurations:

```bash
# Copy config/ tree to /etc/skel/.config/
# Copy default/ templates
# Apply default theme (Tokyo Night)
# Install bin/ scripts to /usr/local/bin/
# Copy applications/ .desktop files
```

This ensures every new user created on first boot gets the full Omarchy config.

#### 70-services.sh

Enable systemd services needed by Omarchy:
```bash
systemctl enable bluetooth.service
systemctl enable sddm.service
# ... other omarchy services
```

### Step 5: Run First-Boot Scripts

#### 00-firstboot-service.sh

Install the first-boot systemd service and script. See FIRSTBOOT.md for details.

### Step 6: Clean Up

```bash
# Remove package cache
rm -f root/var/cache/pacman/pkg/*

# Remove build artifacts
rm -rf root/tmp/*

# Remove files/ overlay directory
rm -rf root/files
```

### Step 7: Create root.img

```bash
# Calculate size: du + 12.5% padding + 256 MiB
size=$(du -B M -s root | cut -dM -f1)
size=$((size + (size / 8) + 256))

# Create ext4 image
truncate -s "${size}M" root.img
mkfs.ext4 -U "725346d2-f127-47bc-b464-9dd46155e8d6" -L "asahi-root" root.img

# Mount and copy
mount -o loop root.img /mnt
rsync -aHAX --exclude /files --exclude '/tmp/*' root/ /mnt/
umount /mnt
```

The UUID must match what's in the fstab and GRUB config.

### Step 8: Create ESP Tree

```bash
mkdir -p esp/EFI/BOOT
cp root/boot/grub/arm64-efi/core.efi esp/EFI/BOOT/BOOTAA64.EFI
cp -r root/boot/efi/m1n1 esp/
```

### Step 9: Package

```bash
mkdir -p omarchy
mv root.img omarchy/
mv esp omarchy/
zip -1 -r omarchy.zip omarchy/
```

The resulting `omarchy.zip` is the complete installable image.

## Expected Image Size

| Component | Estimated Size |
|-----------|---------------|
| Arch ARM base | ~600 MB |
| Asahi kernel + drivers | ~200 MB |
| Hyprland + Wayland stack | ~400 MB |
| Omarchy packages (all) | ~2-3 GB |
| Configs, themes, binaries | ~500 MB |
| **Total (uncompressed)** | **~4-5 GB** |
| **Compressed (zip -1)** | **~3-4 GB** |

If >2 GB (GitHub Releases limit), split with:
```bash
split -b 1900M omarchy.zip omarchy.zip.part-
```

And reassemble in the installer:
```bash
cat omarchy.zip.part-* > omarchy.zip
```

## Source Files from Omarchy Repo

The build scripts pull package lists and configs from the existing omarchy repo (amarchy-3-x branch):

| Omarchy File | Used In |
|---|---|
| `install/packaging/omarchy-base-official.packages` | scripts/omarchy/10-base-packages.sh |
| `install/packaging/omarchy-arm-official.packages` | scripts/omarchy/20-arm-packages.sh |
| `install/packaging/omarchy-arm-aur.packages` | scripts/omarchy/40-aur-packages.sh |
| `install/packaging/omarchy-arm-omacom-io.packages` | scripts/omarchy/50-arm-binaries.sh |
| `install/packaging/omarchy-asahi.packages` | scripts/omarchy/30-asahi-packages.sh |
| `install/arm_install_scripts/*` | scripts/omarchy/50-arm-binaries.sh |
| `default/pacman/pacman.conf.arm` | scripts/omarchy/00-pacman-omarchy.sh |
| `default/pacman/mirrorlist.arm` | files/mirrorlist.arm |
| `default/pacman/mirrorlist.asahi-alarm` | files/mirrorlist.asahi-alarm |
| `config/*` | scripts/omarchy/60-config.sh |
| `bin/*` | scripts/omarchy/60-config.sh |
| `themes/*` | scripts/omarchy/60-config.sh |

## Running the Build

```bash
git clone https://github.com/techiventure/asahi-omarchy.git
cd asahi-omarchy/build
sudo ./build-rootfs.sh
```

Output: `images/omarchy.zip`
