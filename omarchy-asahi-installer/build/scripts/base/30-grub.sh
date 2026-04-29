#!/bin/bash
# Install and configure GRUB bootloader for ARM64
set -e

echo "Configuring GRUB..."

MODULES="ext2 part_gpt search"
GRUB_PREFIX="/boot/grub"

mkdir -p /boot/efi

cat > /tmp/grub-core.cfg <<EOF
search.fs_uuid $ROOT_UUID root
set prefix=(\$root)'$GRUB_PREFIX'
EOF

# Remove problematic GRUB module
sed -i '/efi_uga/d' /etc/grub.d/00_header

echo "Installing GRUB..."
mkdir -p /boot/grub
touch /boot/grub/device.map
dd if=/dev/zero of=/boot/grub/grubenv bs=1024 count=1 2>/dev/null
cp -r /usr/share/grub/themes /boot/grub/ 2>/dev/null || true
cp -r /usr/lib/grub/arm64-efi /boot/grub/
rm -f /boot/grub/arm64-efi/*.module

mkdir -p /boot/grub/{fonts,locale}
cp /usr/share/grub/unicode.pf2 /boot/grub/fonts/ 2>/dev/null || true

for i in /usr/share/locale/*/LC_MESSAGES/grub.mo; do
  [[ -f $i ]] || continue
  lc=$(echo "$i" | cut -d/ -f5)
  cp "$i" "/boot/grub/locale/$lc.mo"
done

echo "Generating GRUB image..."
grub-mkimage \
  --directory /usr/lib/grub/arm64-efi \
  -c /tmp/grub-core.cfg \
  --prefix /boot/grub \
  --output /boot/grub/arm64-efi/core.efi \
  --format arm64-efi \
  --compression auto \
  $MODULES

rm -f /etc/grub.d/30_uefi-firmware

echo "GRUB configured."
