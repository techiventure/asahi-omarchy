#!/bin/bash
# Build all Asahi packages from source inside a systemd-nspawn Arch ARM container.
# Produces a pacman-compatible package repository ready for upload to R2.
#
# Must be run as root on an aarch64 host (e.g., Fedora Asahi Remix).
#
# Output:
#   packages/aarch64/*.pkg.tar.zst   - built packages
#   packages/aarch64/omarchy-asahi.db - pacman repo database
#   packages/aarch64/omarchy-asahi.files

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTAINER_ROOT="$SCRIPT_DIR/.pkg-build-root"
ARCH_ARM_URL="https://archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz"
ARCH_ARM_TAR="$SCRIPT_DIR/build/dl/ArchLinuxARM-aarch64-latest.tar.gz"
PKGBUILDS_REPO="https://github.com/asahi-alarm/PKGBUILDs.git"
OUTPUT_DIR="$SCRIPT_DIR/packages/aarch64"

# Packages we need to build, in dependency order
PACKAGES_PHASE1=(
  asahi-configs
  alsa-ucm-conf-asahi
  asahi-scripts
  lzfse
  asahi-fwextract
  bankstown
)

PACKAGES_PHASE2=(
  asahi-bless
  asahi-btsync
  asahi-wifisync
  tiny-dfr
  speakersafetyd
)

PACKAGES_PHASE3=(
  linux-asahi
)

PACKAGES_PHASE4=(
  m1n1
  uboot-asahi
)

PACKAGES_PHASE5=(
  mesa
)

PACKAGES_PHASE6=(
  asahi-audio
  asahi-meta
)

PACKAGES_PHASE7=(
  widevine
)

# ─────────────────────────────────────────────
# Preflight checks
# ─────────────────────────────────────────────

if [[ $(whoami) != "root" ]]; then
  echo "ERROR: Must be run as root."
  exit 1
fi

if [[ $(uname -m) != "aarch64" ]]; then
  echo "ERROR: Must be run on aarch64."
  exit 1
fi

if ! command -v systemd-nspawn &>/dev/null; then
  echo "ERROR: systemd-nspawn required (dnf install systemd-container)."
  exit 1
fi

if ! command -v bsdtar &>/dev/null; then
  echo "ERROR: bsdtar required (dnf install bsdtar)."
  exit 1
fi

# Common nspawn flags: share host DNS for network access
NSPAWN="systemd-nspawn -D $CONTAINER_ROOT --resolv-conf=bind-host --pipe"

echo "============================================"
echo "  Asahi Package Builder"
echo "============================================"
echo ""
echo "Output: $OUTPUT_DIR"
echo ""

# ─────────────────────────────────────────────
# Step 1: Prepare Arch ARM container
# ─────────────────────────────────────────────

echo "── Step 1: Preparing Arch ARM build container ──"

mkdir -p "$OUTPUT_DIR" "$(dirname "$ARCH_ARM_TAR")"

if [[ ! -e "$ARCH_ARM_TAR" ]]; then
  echo "Downloading Arch Linux ARM tarball..."
  wget -c "$ARCH_ARM_URL" -O "$ARCH_ARM_TAR.part"
  mv "$ARCH_ARM_TAR.part" "$ARCH_ARM_TAR"
else
  echo "Using cached Arch ARM tarball."
fi

# Clean and recreate container
rm -rf "$CONTAINER_ROOT"
mkdir -p "$CONTAINER_ROOT"

echo "Extracting container rootfs..."
bsdtar -xpf "$ARCH_ARM_TAR" -C "$CONTAINER_ROOT"

# ─────────────────────────────────────────────
# Step 2: Bootstrap the container
# ─────────────────────────────────────────────

echo ""
echo "── Step 2: Bootstrapping build container ──"

$NSPAWN /bin/bash <<'BOOTSTRAP'
set -e

# Init pacman keyring
pacman-key --init
pacman-key --populate archlinuxarm

# Full system upgrade + build deps
pacman -Syu --noconfirm
pacman -S --noconfirm --needed \
  base-devel \
  git \
  rust \
  cargo \
  python \
  python-pip \
  python-setuptools \
  python-wheel \
  python-build \
  python-installer \
  meson \
  ninja \
  cmake \
  bc \
  cpio \
  kmod \
  pahole \
  xmlto \
  inetutils \
  imagemagick \
  llvm \
  clang \
  lld \
  libxml2 \
  libxslt \
  dtc \
  uboot-tools \
  wget \
  unzip \
  rsync

# Create a non-root build user (makepkg won't run as root)
useradd -m -s /bin/bash builder
echo "builder ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/builder

echo "Container bootstrapped."
BOOTSTRAP

# ─────────────────────────────────────────────
# Step 3: Clone reference PKGBUILDs
# ─────────────────────────────────────────────

echo ""
echo "── Step 3: Cloning asahi-alarm PKGBUILDs (reference) ──"

$NSPAWN /bin/bash <<CLONE
set -e
su - builder -c 'git clone --depth 1 $PKGBUILDS_REPO /home/builder/PKGBUILDs'
CLONE

echo "PKGBUILDs cloned."

# ─────────────────────────────────────────────
# Step 4: Build packages phase by phase
# ─────────────────────────────────────────────

build_package() {
  local pkg="$1"
  echo ""
  echo "━━━ Building: $pkg ━━━"

  systemd-nspawn -D "$CONTAINER_ROOT" --resolv-conf=bind-host \
    --bind="$OUTPUT_DIR":/output \
    --pipe /bin/bash <<BUILDSCRIPT
set -e

PKGDIR="/home/builder/PKGBUILDs/$pkg"
if [[ ! -d "\$PKGDIR" ]]; then
  echo "ERROR: PKGBUILD not found for $pkg"
  exit 1
fi

# Install any built packages so far (for dependencies)
if ls /output/*.pkg.tar.zst &>/dev/null; then
  pacman -U --noconfirm --needed /output/*.pkg.tar.zst || true
fi

cd "\$PKGDIR"

# Fix ownership for builder
chown -R builder:builder "\$PKGDIR"

# Build
su - builder -c "cd \$PKGDIR && makepkg -s --noconfirm --skippgpcheck 2>&1" || {
  echo "WARNING: Failed to build $pkg"
  exit 1
}

# Copy built packages to output
cp -v \$PKGDIR/*.pkg.tar.zst /output/ 2>/dev/null || true
echo "✓ $pkg built successfully"
BUILDSCRIPT
}

build_phase() {
  local phase_name="$1"
  shift
  local packages=("$@")

  echo ""
  echo "============================================"
  echo "  $phase_name"
  echo "============================================"

  for pkg in "${packages[@]}"; do
    build_package "$pkg"
  done
}

build_phase "Phase 1: Config/meta packages" "${PACKAGES_PHASE1[@]}"
build_phase "Phase 2: Rust packages" "${PACKAGES_PHASE2[@]}"
build_phase "Phase 3: Kernel" "${PACKAGES_PHASE3[@]}"
build_phase "Phase 4: Bootloaders" "${PACKAGES_PHASE4[@]}"
build_phase "Phase 5: Mesa/Vulkan" "${PACKAGES_PHASE5[@]}"
build_phase "Phase 6: Meta packages" "${PACKAGES_PHASE6[@]}"
build_phase "Phase 7: Widevine" "${PACKAGES_PHASE7[@]}"

# ─────────────────────────────────────────────
# Step 5: Create pacman repo database
# ─────────────────────────────────────────────

echo ""
echo "── Step 5: Creating pacman repository database ──"

systemd-nspawn -D "$CONTAINER_ROOT" --resolv-conf=bind-host \
  --bind="$OUTPUT_DIR":/output \
  --pipe /bin/bash <<'REPODB'
set -e
cd /output
repo-add omarchy-asahi.db.tar.gz *.pkg.tar.zst
# repo-add creates symlinks; flatten them for static hosting
for f in omarchy-asahi.db omarchy-asahi.files; do
  if [[ -L "$f" ]]; then
    target=$(readlink "$f")
    rm "$f"
    cp "$target" "$f"
  fi
done
echo "Repository database created."
REPODB

# ─────────────────────────────────────────────
# Step 6: Cleanup
# ─────────────────────────────────────────────

echo ""
echo "── Step 6: Cleanup ──"
rm -rf "$CONTAINER_ROOT"

echo ""
echo "============================================"
echo "  PACKAGE BUILD COMPLETE"
echo "============================================"
echo ""
echo "Output directory: $OUTPUT_DIR"
echo ""
ls -lh "$OUTPUT_DIR"/*.pkg.tar.zst 2>/dev/null | wc -l | xargs -I{} echo "  {} packages built"
ls -lh "$OUTPUT_DIR"/omarchy-asahi.db 2>/dev/null && echo "  Repository database: OK" || echo "  WARNING: No repo database"
echo ""
echo "Next step: upload to R2"
echo "  rclone sync $OUTPUT_DIR r2:asahi-omarchy/packages/aarch64/"
