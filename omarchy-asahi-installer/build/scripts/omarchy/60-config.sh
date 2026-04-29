#!/bin/bash
# Clone omarchy repo and install configs, themes, and bin scripts
set -e

echo "Installing Omarchy configs and themes..."

OMARCHY_REPO="${OMARCHY_REPO:-techiventure/asahi-omarchy}"
OMARCHY_REF="${OMARCHY_REF:-master}"

# Clone the omarchy repo
cd /tmp
git clone --depth 1 --branch "$OMARCHY_REF" "https://github.com/$OMARCHY_REPO.git" omarchy-src || \
  git clone --depth 1 "https://github.com/$OMARCHY_REPO.git" omarchy-src

OMARCHY_SRC=/tmp/omarchy-src
OMARCHY_PATH=/usr/share/omarchy

# Install omarchy to the system path
mkdir -p "$OMARCHY_PATH"
cp -r "$OMARCHY_SRC"/* "$OMARCHY_PATH/"

# Install bin scripts to /usr/local/bin
if [[ -d "$OMARCHY_SRC/bin" ]]; then
  for script in "$OMARCHY_SRC/bin/"*; do
    [[ -f $script ]] || continue
    cp "$script" /usr/local/bin/
    chmod +x "/usr/local/bin/$(basename "$script")"
  done
fi

# Copy config to /etc/skel so new users get it
mkdir -p /etc/skel/.config
if [[ -d "$OMARCHY_SRC/config" ]]; then
  cp -r "$OMARCHY_SRC/config/"* /etc/skel/.config/
fi

# Copy default configs
mkdir -p /etc/skel/.local/share/omarchy
cp -r "$OMARCHY_SRC"/* /etc/skel/.local/share/omarchy/ 2>/dev/null || true

# Install .desktop files
if [[ -d "$OMARCHY_SRC/applications" ]]; then
  mkdir -p /usr/share/applications
  cp "$OMARCHY_SRC/applications/"*.desktop /usr/share/applications/ 2>/dev/null || true
fi

# Install themes
if [[ -d "$OMARCHY_SRC/themes" ]]; then
  mkdir -p /etc/skel/.local/share/omarchy/themes
  cp -r "$OMARCHY_SRC/themes/"* /etc/skel/.local/share/omarchy/themes/ 2>/dev/null || true
fi

# Enable key services
systemctl enable docker.service
systemctl enable bluetooth.service
systemctl enable sddm.service
systemctl enable cups.service
systemctl enable avahi-daemon.service
systemctl enable plocate-updatedb.timer 2>/dev/null || true

# Set default shell to zsh for new users
sed -i 's|SHELL=/bin/bash|SHELL=/bin/zsh|' /etc/default/useradd 2>/dev/null || true

# Clean up source
rm -rf "$OMARCHY_SRC"

echo "Omarchy configs and themes installed."
