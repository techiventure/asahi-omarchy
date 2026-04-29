# Building Asahi Packages From Source

We build all Apple Silicon packages ourselves instead of depending on the asahi-alarm repo.
Source: official AsahiLinux/* GitHub repos + their PKGBUILDs as reference.

## Package Inventory

20 packages total, grouped by complexity:

### Tier 1: Simple config/meta packages (no compilation)

| Package | What It Is | Build Effort |
|---------|-----------|-------------|
| asahi-meta | Meta package, just declares dependencies | Write PKGBUILD with depends=() |
| asahi-configs | Config files (xorg, KDE, natural scrolling) | Package static files |
| alsa-ucm-conf-asahi | ALSA audio hardware config profiles | Clone github.com/AsahiLinux/alsa-ucm-conf-asahi, package files |
| asahi-audio | Meta package for audio stack | Write PKGBUILD with depends=(bankstown, lsp-plugins-lv2, pipewire, speakersafetyd, wireplumber) |
| asahi-alarm-keyring | GPG keyring for package signing | **Generate our own key.** Create omarchy-asahi-keyring instead |

### Tier 2: Small Rust/Python packages (cargo/pip build)

| Package | Source | Build |
|---------|--------|-------|
| asahi-bless | crates.io (asahi-bless) from github.com/AsahiLinux/asahi-nvram | `cargo build --release` |
| asahi-btsync | crates.io (asahi-btsync) from github.com/AsahiLinux/asahi-nvram | `cargo build --release` |
| asahi-wifisync | crates.io (asahi-wifisync) from github.com/AsahiLinux/asahi-nvram | `cargo build --release` |
| tiny-dfr | github.com/AsahiLinux/tiny-dfr | `cargo build --release` + systemd unit + udev rules |
| speakersafetyd | github.com/AsahiLinux/speakersafetyd | `cargo build --release` + systemd unit |
| bankstown | github.com/chadmed/bankstown | Python package, `pip install` or `setup.py` |
| asahi-scripts | github.com/AsahiLinux/asahi-scripts | Shell scripts, just package them |
| asahi-fwextract | From github.com/AsahiLinux/asahi-installer | Python script extraction |

### Tier 3: Complex builds (kernel, bootloader, Mesa)

| Package | Source | Build Time | Notes |
|---------|--------|-----------|-------|
| linux-asahi | github.com/AsahiLinux/linux | **30-90 min** | Full kernel build. Largest package. |
| m1n1 | github.com/AsahiLinux/m1n1 | ~5 min | Stage 1 bootloader. Needs cross-compilation tools. |
| uboot-asahi | github.com/AsahiLinux/u-boot | ~10 min | U-Boot bootloader for Apple Silicon. |
| vulkan-asahi (mesa) | archive.mesa3d.org | **20-40 min** | Full Mesa build with `-Dvulkan-drivers=...asahi`. Large. |

### Tier 4: Special/proprietary

| Package | Source | Notes |
|---------|--------|-------|
| widevine | ChromeOS Lacros images | Proprietary DRM binary extracted from Google ChromeOS. Requires custom extraction script. |

## Build Strategy

### Option A: Build in the image build process (simple, slow)

Build each package inside the rootfs chroot during image creation. No separate package repo needed.

- Pros: Simple, no infrastructure
- Cons: Every image build rebuilds everything (~2-3 hours for kernel + Mesa alone)

### Option B: Pre-build packages, host in our own repo (recommended)

Build packages once, create `.pkg.tar.zst` files, host them in a GitHub Releases-based pacman repo (same pattern asahi-alarm uses).

- Pros: Image builds are fast (just `pacman -S`), reproducible
- Cons: Need to maintain a package build pipeline

### Option C: Hybrid

Pre-build the slow ones (kernel, Mesa), build the rest during image creation.

## Recommended: Option B

### Package Build Pipeline

```
For each package:
  1. Fetch PKGBUILD (from asahi-alarm/PKGBUILDs as reference)
  2. Modify to use our signing key
  3. Build with makepkg on aarch64
  4. Sign with our GPG key
  5. Upload .pkg.tar.zst to GitHub Releases

GitHub repo: techiventure/asahi-omarchy
  ├── PKGBUILDs/
  │   ├── linux-asahi/PKGBUILD
  │   ├── m1n1/PKGBUILD
  │   ├── mesa/PKGBUILD
  │   ├── ...
  ├── build-all.sh
  └── .github/workflows/build-packages.yml
```

### Package Repository (pacman-compatible)

Host as GitHub Releases on `techiventure/asahi-omarchy`:

```
# mirrorlist.omarchy-asahi
Server = https://r2-foss.techiventure.com/asahi-omarchy/packages/$arch
```

Packages are uploaded as release assets. Pacman treats GitHub Releases as a flat-file HTTP repo.

### Signing Key

Generate a new GPG key for the omarchy-asahi package repo:

```bash
gpg --full-generate-key
# Name: Omarchy Asahi Package Signing Key
# Email: packages@techiventure.com

# Export public key
gpg --export -a "packages@techiventure.com" > omarchy-asahi.gpg

# Create keyring package: omarchy-asahi-keyring
```

### Build Order (dependency-aware)

Must build in this order due to dependencies:

```
Phase 1 (no deps):
  - asahi-configs
  - alsa-ucm-conf-asahi
  - asahi-scripts
  - asahi-fwextract
  - bankstown
  - omarchy-asahi-keyring

Phase 2 (Rust packages, parallel):
  - asahi-bless
  - asahi-btsync
  - asahi-wifisync
  - tiny-dfr
  - speakersafetyd

Phase 3 (kernel, sequential):
  - linux-asahi

Phase 4 (bootloaders, after kernel):
  - m1n1
  - uboot-asahi

Phase 5 (Mesa, independent):
  - mesa (provides vulkan-asahi)

Phase 6 (meta packages, after all above):
  - asahi-audio (depends on bankstown, speakersafetyd, etc.)
  - asahi-meta (depends on everything)

Phase 7 (special):
  - widevine (proprietary extraction)
```

## Estimated Build Times (on M1 10-core)

| Phase | Packages | Time |
|-------|----------|------|
| Phase 1 | 6 config/script packages | ~2 min |
| Phase 2 | 5 Rust packages (parallel) | ~10 min |
| Phase 3 | linux-asahi kernel | ~30-90 min |
| Phase 4 | m1n1 + uboot-asahi | ~15 min |
| Phase 5 | Mesa (vulkan-asahi) | ~20-40 min |
| Phase 6 | 2 meta packages | ~1 min |
| Phase 7 | widevine | ~5 min |
| **Total** | **20 packages** | **~1.5-3 hours** |

This only needs to run when upstream Asahi releases new versions (roughly monthly).

## Source Repos to Track

All official AsahiLinux upstream repos:

| Repo | URL | What We Build |
|------|-----|--------------|
| linux | github.com/AsahiLinux/linux | linux-asahi kernel |
| m1n1 | github.com/AsahiLinux/m1n1 | m1n1 bootloader |
| u-boot | github.com/AsahiLinux/u-boot | uboot-asahi |
| asahi-audio | github.com/AsahiLinux/asahi-audio | asahi-audio config |
| asahi-scripts | github.com/AsahiLinux/asahi-scripts | asahi-scripts |
| asahi-installer | github.com/AsahiLinux/asahi-installer | asahi-fwextract |
| asahi-nvram | github.com/AsahiLinux/asahi-nvram | asahi-bless, asahi-btsync, asahi-wifisync |
| tiny-dfr | github.com/AsahiLinux/tiny-dfr | tiny-dfr |
| speakersafetyd | github.com/AsahiLinux/speakersafetyd | speakersafetyd |
| alsa-ucm-conf-asahi | github.com/AsahiLinux/alsa-ucm-conf-asahi | alsa-ucm-conf-asahi |
| Mesa | archive.mesa3d.org | vulkan-asahi |
| bankstown | github.com/chadmed/bankstown | bankstown |

## Reference PKGBUILDs

We use asahi-alarm's PKGBUILDs as reference (not runtime dependency):

```
https://github.com/asahi-alarm/PKGBUILDs/tree/main/<package-name>/PKGBUILD
```

We'll fork/adapt these for our own builds, replacing their signing key with ours.
