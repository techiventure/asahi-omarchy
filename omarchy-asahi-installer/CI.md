# CI Pipeline

Automated build and release pipeline for the Omarchy Asahi image.

This is Phase 2 -- implement after manual builds are validated.

## Overview

```
Tag push (v2025.04.28)
  |
  v
GitHub Actions: build-image.yml
  |
  v
aarch64 build environment (QEMU or self-hosted)
  |
  v
build-rootfs.sh produces omarchy.zip
  |
  v
Upload to GitHub Releases
  |
  v
installer_data.json updated (or uses "latest" tag)
```

## Workflow: `.github/workflows/build-image.yml`

```yaml
name: Build Omarchy Asahi Image

on:
  push:
    tags:
      - 'v*'
  workflow_dispatch:
    inputs:
      omarchy_ref:
        description: 'Omarchy repo ref to build from'
        required: false
        default: 'master'

jobs:
  build:
    runs-on: ubuntu-24.04
    timeout-minutes: 120

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up QEMU
        uses: docker/setup-qemu-action@v3
        with:
          platforms: arm64

      - name: Build image
        run: |
          docker run --rm --privileged \
            --platform linux/arm64 \
            -v ${{ github.workspace }}:/work \
            -w /work/build \
            archlinux:latest \
            bash -c "pacman -Sy --noconfirm arch-install-scripts bsdtar rsync zip wget && ./build-rootfs.sh"

      - name: Check image size
        run: |
          ls -lh build/images/omarchy.zip
          SIZE=$(stat -c%s build/images/omarchy.zip)
          echo "IMAGE_SIZE=$SIZE" >> $GITHUB_ENV
          # 2 GB = 2147483648 bytes
          if (( SIZE > 2147483648 )); then
            echo "NEEDS_SPLIT=true" >> $GITHUB_ENV
            split -b 1900M build/images/omarchy.zip build/images/omarchy.zip.part-
          else
            echo "NEEDS_SPLIT=false" >> $GITHUB_ENV
          fi

      - name: Create Release
        uses: softprops/action-gh-release@v2
        with:
          files: |
            build/images/omarchy.zip*
          body: |
            Omarchy Asahi Image ${{ github.ref_name }}

            Install from macOS:
            ```
            curl -fsSL https://raw.githubusercontent.com/techiventure/asahi-omarchy/main/installer/install.sh | sh
            ```
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## Build Environment Options

### Option A: QEMU on GitHub-hosted runner (free)

- Uses `ubuntu-24.04` runner + QEMU user-mode emulation
- `docker run --platform linux/arm64` runs aarch64 binaries via QEMU
- Slow (~60-90 minutes) but free and requires no infrastructure
- May hit GitHub Actions timeout (6 hours max, but we set 2 hours)

### Option B: Self-hosted aarch64 runner

- Oracle Cloud free tier offers aarch64 VMs (Ampere A1, 4 cores, 24 GB RAM)
- Or use an M1 Mac as a self-hosted runner
- Fast native builds (~15-20 minutes)
- Requires setup and maintenance

### Option C: Asahi-alarm's approach

- They use `ubuntu-24.04-arm` (GitHub's ARM runners, currently in beta)
- Run inside a Docker container: `josdehaes/asahi-alarm-pkgbuild:latest`
- Upload via SCP to their own server

### Recommendation

Start with **Option A** (QEMU). It's free and requires no infrastructure. If build times are unacceptable, move to **Option B** (Oracle Cloud free aarch64 VM).

## Trigger: Omarchy Main Repo Updates

To auto-rebuild when the main omarchy repo releases:

### Option 1: Repository Dispatch

In the main `omarchy` repo, add a step to the release workflow:

```yaml
- name: Trigger Asahi image rebuild
  uses: peter-evans/repository-dispatch@v3
  with:
    token: ${{ secrets.ASAHI_REPO_TOKEN }}
    repository: techiventure/asahi-omarchy
    event-type: omarchy-release
    client-payload: '{"ref": "${{ github.ref_name }}"}'
```

In `asahi-omarchy`, listen for this:

```yaml
on:
  repository_dispatch:
    types: [omarchy-release]
```

### Option 2: Scheduled Builds

Build weekly (like asahi-alarm does) to pick up any upstream changes:

```yaml
on:
  schedule:
    - cron: '0 6 * * 1'  # Monday 6:00 UTC
```

### Option 3: Manual Only

Just push a tag when you want a new build. Simplest approach for Phase 2.

## Release Naming

Use date-based tags that sort chronologically:

```
v2025.04.28
v2025.05.15
v2025.06.01
```

The `installer_data.json` can reference the `latest` release:

```
https://github.com/techiventure/asahi-omarchy/releases/latest/download/omarchy.zip
```

This URL always resolves to the most recent release, so no JSON update needed.

## Checksums

Add SHA256 checksum verification:

```yaml
- name: Generate checksums
  run: |
    cd build/images
    sha256sum omarchy.zip* > SHA256SUMS
```

The bootstrap script verifies:

```bash
echo "Verifying download..."
sha256sum -c SHA256SUMS
```

## Image Size Monitoring

Track image size across builds to catch bloat:

```yaml
- name: Report image size
  run: |
    SIZE_MB=$(( $(stat -c%s build/images/omarchy.zip) / 1048576 ))
    echo "## Image Size: ${SIZE_MB} MB" >> $GITHUB_STEP_SUMMARY
```

## Future: ARM Package Mirror

Currently, omarchy has a package mirror for x86_64 but not ARM. Once an ARM mirror exists:
- Many packages can be pulled from the mirror instead of building from source
- Build times decrease significantly
- Image freshness improves (mirror packages update independently)

This would change the build from "install everything from scratch" to "install from omarchy ARM mirror" -- similar to how x86 builds work today.
