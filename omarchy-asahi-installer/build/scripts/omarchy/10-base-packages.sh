#!/bin/bash
# Install Omarchy base packages from official Arch repos
# Source: omarchy-base-official.packages
set -e

echo "Installing Omarchy base packages (official repos)..."

# Critical: install pipewire-jack BEFORE anything that might pull jack2
# This prevents the jack2 <-> pipewire-jack conflict
pacman --noconfirm --needed -S pipewire-jack

# Core Omarchy packages from official repos
# Extracted from omarchy-base-official.packages (comments/blanks stripped)
PACKAGES="
  alacritty
  alsa-utils
  avahi
  bash-completion
  bat
  bluetui
  bolt
  brightnessctl
  btop
  cargo
  clang
  cups
  cups-browsed
  cups-filters
  cups-pdf
  docker
  docker-buildx
  docker-compose
  dust
  evince
  exfatprogs
  expac
  eza
  fastfetch
  fcitx5
  fcitx5-gtk
  fcitx5-qt
  fd
  ffmpegthumbnailer
  fontconfig
  fzf
  github-cli
  gnome-calculator
  gnome-disk-utility
  gnome-keyring
  gnome-themes-extra
  grim
  gum
  gvfs-mtp
  gvfs-nfs
  gvfs-smb
  hypridle
  hyprland
  hyprland-guiutils
  hyprlock
  hyprpicker
  hyprshot
  hyprsunset
  imagemagick
  impala
  imv
  inetutils
  inxi
  iwd
  jq
  kdenlive
  kernel-modules-hook
  kvantum-qt5
  lazydocker
  lazygit
  less
  libqalculate
  libreoffice-fresh
  libsecret
  libyaml
  llvm
  luarocks
  mako
  man-db
  mariadb-libs
  mise
  mpv
  nautilus
  nautilus-python
  noto-fonts
  noto-fonts-cjk
  noto-fonts-emoji
  noto-fonts-extra
  nss-mdns
  pamixer
  playerctl
  plocate
  plymouth
  polkit-gnome
  postgresql-libs
  power-profiles-daemon
  python-gobject
  python-poetry-core
  qt5-wayland
  ripgrep
  ruby
  rust
  satty
  sddm
  slurp
  socat
  starship
  sushi
  swaybg
  swayosd
  system-config-printer
  tldr
  tmux
  tree-sitter-cli
  ttf-cascadia-mono-nerd
  ttf-jetbrains-mono-nerd
  ufw
  unzip
  usage
  uwsm
  waybar
  whois
  wireless-regdb
  wiremix
  wireplumber
  wl-clipboard
  woff2-font-awesome
  xdg-desktop-portal-gtk
  xdg-desktop-portal-hyprland
  xmlstarlet
  xournalpp
  zoxide
  zsh
"

pacman --noconfirm --needed -S $PACKAGES

echo "Base packages installed."
