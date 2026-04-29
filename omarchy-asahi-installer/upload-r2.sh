#!/bin/bash
# Upload built packages and/or image to Cloudflare R2
# Requires rclone configured with an "r2" remote.
#
# Usage:
#   ./upload-r2.sh packages   # Upload pacman repo packages
#   ./upload-r2.sh image      # Upload omarchy.zip
#   ./upload-r2.sh all        # Upload both

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
R2_REMOTE="r2"
R2_BUCKET="asahi-omarchy"
PACKAGES_DIR="$SCRIPT_DIR/packages/aarch64"
IMAGE_DIR="$SCRIPT_DIR/build/images"

if ! command -v rclone &>/dev/null; then
  echo "ERROR: rclone not installed."
  exit 1
fi

if ! rclone listremotes | grep -q "^${R2_REMOTE}:$"; then
  echo "ERROR: rclone remote '$R2_REMOTE' not configured."
  echo ""
  echo "Configure it with:"
  echo "  rclone config create r2 s3 \\"
  echo "    provider=Cloudflare \\"
  echo "    access_key_id=YOUR_ACCESS_KEY \\"
  echo "    secret_access_key=YOUR_SECRET_KEY \\"
  echo "    endpoint=https://YOUR_ACCOUNT_ID.r2.cloudflarestorage.com"
  exit 1
fi

upload_packages() {
  echo "── Uploading packages to R2 ──"

  if [[ ! -d "$PACKAGES_DIR" ]] || ! ls "$PACKAGES_DIR"/*.pkg.tar.zst &>/dev/null; then
    echo "ERROR: No packages found in $PACKAGES_DIR"
    echo "Run build-packages.sh first."
    exit 1
  fi

  if [[ ! -f "$PACKAGES_DIR/omarchy-asahi.db" ]]; then
    echo "ERROR: Repository database not found."
    exit 1
  fi

  echo "Syncing packages to ${R2_REMOTE}:${R2_BUCKET}/packages/aarch64/"
  rclone sync "$PACKAGES_DIR" "${R2_REMOTE}:${R2_BUCKET}/packages/aarch64/" \
    --progress \
    --transfers=8

  echo ""
  echo "Packages uploaded. Repo URL:"
  echo "  https://r2-foss.techiventure.com/asahi-omarchy/packages/aarch64/"
}

upload_image() {
  echo "── Uploading image to R2 ──"

  if [[ ! -f "$IMAGE_DIR/omarchy.zip" ]]; then
    echo "ERROR: omarchy.zip not found in $IMAGE_DIR"
    echo "Run run-build.sh first."
    exit 1
  fi

  local size
  size=$(du -h "$IMAGE_DIR/omarchy.zip" | cut -f1)
  echo "Uploading omarchy.zip ($size)..."

  rclone copy "$IMAGE_DIR/omarchy.zip" "${R2_REMOTE}:${R2_BUCKET}/images/" \
    --progress

  # Also upload a SHA256 checksum
  (cd "$IMAGE_DIR" && sha256sum omarchy.zip > omarchy.zip.sha256)
  rclone copy "$IMAGE_DIR/omarchy.zip.sha256" "${R2_REMOTE}:${R2_BUCKET}/images/" \
    --progress

  echo ""
  echo "Image uploaded. URLs:"
  echo "  https://r2-foss.techiventure.com/asahi-omarchy/images/omarchy.zip"
  echo "  https://r2-foss.techiventure.com/asahi-omarchy/images/omarchy.zip.sha256"
}

case "${1:-}" in
  packages)
    upload_packages
    ;;
  image)
    upload_image
    ;;
  all)
    upload_packages
    echo ""
    upload_image
    ;;
  *)
    echo "Usage: $0 {packages|image|all}"
    exit 1
    ;;
esac

echo ""
echo "Upload complete."
