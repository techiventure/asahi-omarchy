#!/bin/bash
# Omarchy Asahi Image Builder
# Based on asahi-alarm/asahi-alarm-builder
#
# Produces omarchy.zip containing:
#   - root.img (ext4 filesystem with Omarchy pre-installed)
#   - esp/ (EFI system partition tree: m1n1 + GRUB)
#
# Must be run as root on an aarch64 system (or in an aarch64 container).

set -e

BASE_IMAGE_URL="https://archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz"
BASE_IMAGE="$(basename "$BASE_IMAGE_URL")"

DL="$PWD/dl"
ROOT="$PWD/root"
FILES="$PWD/files"
IMAGES="$PWD/images"
IMG="$PWD/img"

EFI_UUID=2ABF-9F91
ROOT_UUID=725346d2-f127-47bc-b464-9dd46155e8d6
FSTYPE=ext4
export ROOT_UUID EFI_UUID FSTYPE

OMARCHY_REPO="${OMARCHY_REPO:-techiventure/asahi-omarchy}"
OMARCHY_REF="${OMARCHY_REF:-master}"
export OMARCHY_REPO OMARCHY_REF

if [[ $(whoami) != "root" ]]; then
  echo "ERROR: Must be run as root."
  exit 1
fi

if [[ $(uname -m) != "aarch64" ]]; then
  echo "ERROR: Must be run on aarch64 (native or container)."
  exit 1
fi

# ─────────────────────────────────────────────
# Helper functions
# ─────────────────────────────────────────────

clean_mounts() {
  while grep -q "$ROOT/[^ ]" /proc/mounts 2>/dev/null; do
    grep "$ROOT" /proc/mounts | cut -d" " -f2 | xargs umount 2>/dev/null || true
    sleep 0.1
  done
}

run_scripts() {
  local group="$1"
  echo ""
  echo "============================================"
  echo "  Running script group: $group"
  echo "============================================"
  for script in "scripts/$group/"*.sh; do
    [[ -f $script ]] || continue
    echo ""
    echo "--- Running: $script ---"
    arch-chroot "$ROOT" /bin/bash < "$script"
    clean_mounts
  done
}

# ─────────────────────────────────────────────
# Step 1: Download and extract base image
# ─────────────────────────────────────────────

echo ""
echo "============================================"
echo "  Step 1: Prepare base Arch Linux ARM image"
echo "============================================"

clean_mounts
umount "$IMG" 2>/dev/null || true
mkdir -p "$DL" "$IMG" "$IMAGES"

if [[ ! -e "$DL/$BASE_IMAGE" ]]; then
  echo "Downloading base image..."
  wget -c "$BASE_IMAGE_URL" -O "$DL/$BASE_IMAGE.part"
  mv "$DL/$BASE_IMAGE.part" "$DL/$BASE_IMAGE"
else
  echo "Using cached base image: $DL/$BASE_IMAGE"
fi

umount "$ROOT" 2>/dev/null || true
rm -rf "$ROOT"
mkdir -p "$ROOT"

echo "Extracting base image..."
bsdtar -xpf "$DL/$BASE_IMAGE" -C "$ROOT"

# Copy overlay files into the chroot
cp -r "$FILES" "$ROOT/files"

# Bind mount for arch-chroot
mount --bind "$ROOT" "$ROOT"

# Save original mirrorlist for later restoration
cp "$ROOT/etc/pacman.d/mirrorlist" "$ROOT/etc/pacman.d/mirrorlist.orig"

echo "Initializing pacman keyring..."
pacstrap -G "$ROOT" archlinuxarm-keyring

# ─────────────────────────────────────────────
# Step 2: Run base scripts (Asahi system setup)
# ─────────────────────────────────────────────

echo ""
echo "============================================"
echo "  Step 2: Base system setup"
echo "============================================"

run_scripts base

# ─────────────────────────────────────────────
# Step 3: Run omarchy scripts (packages + config)
# ─────────────────────────────────────────────

echo ""
echo "============================================"
echo "  Step 3: Omarchy installation"
echo "============================================"

run_scripts omarchy

# ─────────────────────────────────────────────
# Step 4: Run firstboot scripts
# ─────────────────────────────────────────────

echo ""
echo "============================================"
echo "  Step 4: First-boot service setup"
echo "============================================"

run_scripts firstboot

# ─────────────────────────────────────────────
# Step 5: Clean up
# ─────────────────────────────────────────────

echo ""
echo "============================================"
echo "  Step 5: Cleanup"
echo "============================================"

echo "Cleaning package cache..."
rm -rf "$ROOT/var/cache/pacman/pkg/"*
rm -rf "$ROOT/tmp/"*
rm -rf "$ROOT/files"

# Restore original mirrorlist
mv -f "$ROOT/etc/pacman.d/mirrorlist.orig" "$ROOT/etc/pacman.d/mirrorlist"

# ─────────────────────────────────────────────
# Step 6: Create root.img
# ─────────────────────────────────────────────

echo ""
echo "============================================"
echo "  Step 6: Create root.img"
echo "============================================"

IMGNAME="omarchy"
IMGDIR="$IMAGES/$IMGNAME"
mkdir -p "$IMGDIR"

echo "Calculating image size..."
SIZE_MB=$(du -B M -s "$ROOT" | cut -dM -f1)
echo "  Root filesystem: ${SIZE_MB} MiB"
SIZE_MB=$((SIZE_MB + (SIZE_MB / 8) + 256))
echo "  Padded size: ${SIZE_MB} MiB"

echo "Creating ext4 filesystem image..."
rm -f "$IMGDIR/root.img"
truncate -s "${SIZE_MB}M" "$IMGDIR/root.img"
mkfs.ext4 -U "$ROOT_UUID" -L "asahi-root" -O '^metadata_csum' "$IMGDIR/root.img"

echo "Mounting and copying files..."
mount -o loop "$IMGDIR/root.img" "$IMG"
rsync -aHAX \
  --exclude /files \
  --exclude '/tmp/*' \
  --exclude /etc/machine-id \
  --exclude '/boot/efi/*' \
  "$ROOT/" "$IMG/"

echo "Running grub-mkconfig..."
arch-chroot "$IMG" grub-mkconfig -o /boot/grub/grub.cfg

echo "Unmounting root.img..."
umount "$IMG"

# ─────────────────────────────────────────────
# Step 7: Create ESP tree
# ─────────────────────────────────────────────

echo ""
echo "============================================"
echo "  Step 7: Create EFI system partition tree"
echo "============================================"

mkdir -p "$IMGDIR/esp/EFI/BOOT"
cp "$ROOT/boot/grub/arm64-efi/core.efi" "$IMGDIR/esp/EFI/BOOT/BOOTAA64.EFI"
cp -r "$ROOT/boot/efi/m1n1" "$IMGDIR/esp/"

# ─────────────────────────────────────────────
# Step 8: Package into zip
# ─────────────────────────────────────────────

echo ""
echo "============================================"
echo "  Step 8: Create omarchy.zip"
echo "============================================"

rm -f "$IMAGES/$IMGNAME.zip"
(
  cd "$IMGDIR"
  zip -1 -r "../$IMGNAME.zip" -- *
)
rm -rf "$IMGDIR"

# ─────────────────────────────────────────────
# Done
# ─────────────────────────────────────────────

clean_mounts

ZIP_SIZE=$(du -h "$IMAGES/$IMGNAME.zip" | cut -f1)
echo ""
echo "============================================"
echo "  BUILD COMPLETE"
echo "  Output: $IMAGES/$IMGNAME.zip ($ZIP_SIZE)"
echo "============================================"
