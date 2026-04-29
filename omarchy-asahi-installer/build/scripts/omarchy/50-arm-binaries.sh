#!/bin/bash
# Install pre-built ARM binaries and custom packages
# Source: install/arm_install_scripts/*
set -e

echo "Installing pre-built ARM binaries..."

# ── 1Password App ──
echo "Installing 1Password..."
ONEPASSWORD_URL="https://downloads.1password.com/linux/tar/stable/aarch64/1password-latest.tar.gz"
cd /tmp
wget -q "$ONEPASSWORD_URL" -O 1password.tar.gz || echo "WARNING: 1Password download failed"
if [[ -f 1password.tar.gz ]]; then
  tar xf 1password.tar.gz
  mkdir -p /opt/1Password
  cp -r 1password-*/* /opt/1Password/
  ln -sf /opt/1Password/1password /usr/local/bin/1password
  rm -rf 1password* 1password.tar.gz
fi

# ── 1Password CLI ──
echo "Installing 1Password CLI..."
OP_CLI_URL="https://cache.agilebits.com/dist/1P/op2/pkg/v2.30.0/op_linux_arm64_v2.30.0.zip"
cd /tmp
wget -q "$OP_CLI_URL" -O op.zip || echo "WARNING: 1Password CLI download failed"
if [[ -f op.zip ]]; then
  unzip -o op.zip op -d /usr/local/bin/
  chmod +x /usr/local/bin/op
  rm -f op.zip
fi

# ── Obsidian AppImage ──
echo "Installing Obsidian..."
OBSIDIAN_URL="https://github.com/obsidianmd/obsidian-releases/releases/download/v1.8.9/Obsidian-1.8.9-arm64.AppImage"
mkdir -p /opt/obsidian
cd /tmp
wget -q "$OBSIDIAN_URL" -O obsidian.AppImage || echo "WARNING: Obsidian download failed"
if [[ -f obsidian.AppImage ]]; then
  mv obsidian.AppImage /opt/obsidian/obsidian.AppImage
  chmod +x /opt/obsidian/obsidian.AppImage
  ln -sf /opt/obsidian/obsidian.AppImage /usr/local/bin/obsidian
  # Desktop entry
  mkdir -p /usr/share/applications
  cat > /usr/share/applications/obsidian.desktop <<'DESKTOP'
[Desktop Entry]
Name=Obsidian
Exec=/opt/obsidian/obsidian.AppImage --no-sandbox %U
Icon=obsidian
Type=Application
Categories=Office;
MimeType=x-scheme-handler/obsidian;
DESKTOP
fi

# ── Bun (pre-built for ARM) ──
echo "Installing Bun..."
BUN_VERSION="1.2.12"
BUN_URL="https://github.com/oven-sh/bun/releases/download/bun-v${BUN_VERSION}/bun-linux-aarch64.zip"
cd /tmp
wget -q "$BUN_URL" -O bun.zip || echo "WARNING: Bun download failed"
if [[ -f bun.zip ]]; then
  unzip -o bun.zip
  mv bun-linux-aarch64/bun /usr/local/bin/bun
  chmod +x /usr/local/bin/bun
  rm -rf bun* bun.zip
fi

echo "Pre-built ARM binaries installed."
