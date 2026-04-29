# Omarchy Asahi Installer - Plan

## Goal

A single command run from macOS that installs Omarchy on Apple Silicon Macs (M1/M2/M3):

```bash
curl -fsSL https://asahi-omarchy.techiventure.com/install | sh
```

The user reboots, connects to wifi, enters their name/password, and lands on a fully configured Omarchy desktop.

## How Asahi ALARM Works (Background)

Apple Silicon Macs cannot boot from USB/ISO. They use Apple's proprietary boot chain:

```
Apple iBoot --> m1n1 (stub) --> U-Boot --> GRUB --> Linux kernel
```

The Asahi ALARM installer runs from **macOS** because it must:

1. Resize the APFS container (macOS filesystem)
2. Create new partitions (EFI + root)
3. Install the m1n1 stub into Apple's boot infrastructure
4. Register the new OS with Apple's boot picker (recoveryOS approval)

There is no way around this step -- it is a firmware-level requirement.

### Asahi ALARM Installer Flow

```
macOS terminal
  |
  v
curl https://asahi-alarm.org/installer-bootstrap.sh | sh
  |
  v
Bootstrap script downloads:
  - installer-v0.8.0.tar.gz (Python installer)
  - installer_data.json (OS options + image URLs)
  |
  v
Python installer runs as root:
  - Shows OS options (Minimal, Desktop, UEFI-only, etc.)
  - User picks one
  - Installer downloads the corresponding .zip package
  - Partitions disk (EFI 500MB + Root)
  - Writes root.img to root partition
  - Writes esp/ to EFI partition
  - Installs m1n1 boot stub
  |
  v
User reboots into recoveryOS to approve boot policy
  |
  v
Boots into Linux (m1n1 -> U-Boot -> GRUB -> kernel)
```

### How Images Are Built (asahi-alarm-builder)

The `asahi-alarm/asahi-alarm-builder` repo builds rootfs images:

1. Downloads `ArchLinuxARM-aarch64-latest.tar.gz` (base Arch ARM)
2. Extracts into a directory, runs `pacstrap` for keyring
3. Runs `scripts/base/*` in arch-chroot (pacman config, packages, kernel, fstab, grub, networkmanager)
4. For desktop variant: runs `scripts/desktop/*` (users, desktop packages, calamares, bluetooth)
5. Creates `root.img` (ext4 or btrfs filesystem image) + `esp/` (EFI tree with m1n1 + GRUB)
6. Zips into `asahi-desktop.zip`, uploads to asahi-alarm.org

## Our Approach

### Architecture (Revised)

We have **three** repos, fully self-contained:

```
techiventure/asahi-omarchy (package build pipeline)
  |
  |- PKGBUILDs/
  |    |- linux-asahi/PKGBUILD     # Kernel, from AsahiLinux/linux
  |    |- m1n1/PKGBUILD            # Bootloader, from AsahiLinux/m1n1
  |    |- mesa/PKGBUILD            # GPU driver (vulkan-asahi)
  |    |- ... (20 packages total)
  |
  |- build-all.sh                  # Build all packages
  |- .github/workflows/
       |- build-packages.yml       # CI: build + upload to Releases
  |
  GitHub Releases (tag: aarch64) hosts .pkg.tar.zst files
  Acts as a pacman-compatible package repository


techiventure/asahi-omarchy (image builder)
  |
  |- build/
  |    |- build-rootfs.sh          # Builds rootfs from Arch ARM + our packages
  |    |- scripts/base/*           # Base system setup
  |    |- scripts/omarchy/*        # Omarchy install + config
  |    |- scripts/firstboot/*      # First-boot service
  |    |- files/                   # Overlay files
  |
  |- installer/
  |    |- install.sh               # Our own bootstrap (forked from Asahi)
  |    |- installer_data.json      # Points to our image
  |    |- installer/               # Forked Python installer
  |
  |- .github/workflows/
       |- build-image.yml          # CI: build image + upload to Releases


omarchy/omarchy (existing repo)
  |
  Configs, themes, bin scripts, package lists
  Referenced during image build
```

### Key Decisions

1. **No dependency on asahi-alarm org.** All 20 Asahi packages built from official
   AsahiLinux/* upstream source repos. Hosted in our own pacman repo.

2. **Forked installer.** The Python installer and bootstrap script are forked from
   asahi-alarm, inspected, modified, and self-hosted. Full control over the
   macOS-side install process.

3. **Arch Linux ARM official mirrors retained.** Standard packages (hyprland,
   pipewire, etc.) come from official Arch ARM mirrors. GPG-signed, impractical
   to self-host. Approved.

4. **All AUR PKGBUILDs audited.** 15 packages reviewed. No suspicious code found.
   See DEPENDENCIES.md.

### Image Contents

Our `omarchy.zip` will contain a root.img with:

- Arch Linux ARM base system (from official Arch ARM tarball)
- Asahi kernel + drivers built from source (our techiventure/asahi-omarchy repo)
- All Omarchy packages pre-installed
- Omarchy configs, themes, binaries
- First-boot systemd service (handles user creation, wifi, personalization)
- GRUB configured for Asahi boot chain

### User Experience

```
1. User runs: curl -fsSL https://asahi-omarchy.techiventure.com/install | sh
   (from macOS Terminal)

2. Asahi installer runs:
   - Shows "Omarchy" as the install option
   - User confirms disk space allocation
   - Downloads omarchy.zip (~3-6 GB)
   - Partitions and writes image

3. User reboots, selects "Omarchy" from Apple boot picker

4. First boot:
   - Connects to wifi (nmtui or nmcli prompt)
   - Enters: username, password, full name, email
   - System creates user, applies final config
   - Reboots into full Omarchy desktop
```

## Build Environment

We are building on **Fedora Asahi Remix 43** (aarch64, M1 Mac). Since this is Fedora (not Arch), we use **systemd-nspawn** with the official Arch ARM tarball to get an Arch build environment. No third-party Docker images.

```
Host: Fedora Asahi Remix 43 (aarch64, 10 cores, 16 GB RAM, 206 GB free)
Build env: systemd-nspawn with ArchLinuxARM-aarch64-latest.tar.gz
```

## Phases

### Phase 0: Build Asahi Packages From Source (NEW)

Build all 20 Apple Silicon packages from official AsahiLinux/* source repos:

1. Set up package build environment (makepkg + dependencies)
2. Generate our own GPG signing key (omarchy-asahi-keyring)
3. Build packages in dependency order (see ASAHI-PACKAGES-BUILD.md)
4. Upload .pkg.tar.zst files to GitHub Releases (omarchy/asahi-packages)
5. Create pacman-compatible repo database

Estimated time: ~1.5-3 hours for full build on M1.

### Phase 1: Build Rootfs Image

Build the full Omarchy rootfs using our own packages:

1. Download Arch ARM base tarball (official, GPG verified)
2. Configure pacman to use our asahi-packages repo + official Arch ARM mirrors
3. Install all packages (base + omarchy + asahi)
4. Apply configs, themes, first-boot service
5. Package into omarchy.zip (root.img + esp/)

### Phase 2: Fork + Self-Host Installer

1. Fork asahi-alarm-installer Python code
2. Audit and modify (branding, hardcoded URLs)
3. Write our own bootstrap script
4. Host installer on our domain / GitHub

### Phase 3: GitHub CI + Release

- CI builds packages on tag push (techiventure/asahi-omarchy)
- CI builds image on tag push (techiventure/asahi-omarchy)
- Uploads to GitHub Releases
- Auto-triggered when upstream Asahi or Omarchy release

### Phase 4: End-to-End Testing

- Run the installer from macOS on a test Mac
- Verify boot, first-boot service, full Omarchy desktop

### Phase 5: Polish + Distribution

- Short URL: asahi-omarchy.techiventure.com
- User-facing install docs
- Auto-rebuild on upstream releases

## Constraints

- **GitHub Releases file limit**: 2 GB per file. Split zip or use better compression if exceeded.
- **Build environment**: systemd-nspawn on native aarch64 (local) or GitHub ARM runners (CI).
- **Boot**: Always dual-boot with macOS. Cannot replace macOS on Apple Silicon.
- **Wifi**: Cannot be pre-configured. User must connect manually on first boot.
- **Package builds**: ~20 Asahi packages must be rebuilt when upstream releases. Roughly monthly.

## Upstream References (source only, no runtime dependency)

| Resource | URL | Usage |
|----------|-----|-------|
| AsahiLinux/linux (kernel) | https://github.com/AsahiLinux/linux | Build linux-asahi |
| AsahiLinux/m1n1 | https://github.com/AsahiLinux/m1n1 | Build m1n1 bootloader |
| AsahiLinux/u-boot | https://github.com/AsahiLinux/u-boot | Build uboot-asahi |
| AsahiLinux/* (various) | https://github.com/AsahiLinux | Source for all Asahi packages |
| asahi-alarm PKGBUILDs (reference) | https://github.com/asahi-alarm/PKGBUILDs | Reference for our PKGBUILDs |
| asahi-alarm-installer (forked) | https://github.com/asahi-alarm/asahi-alarm-installer | Fork base for our installer |
| Arch Linux ARM tarball | https://archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz | Base rootfs |
| Arch Linux ARM mirrors | http://*.mirror.archlinuxarm.org | Standard packages |
| Existing Omarchy ARM PR | https://github.com/basecamp/omarchy (amarchy-3-x branch) | Reference |
