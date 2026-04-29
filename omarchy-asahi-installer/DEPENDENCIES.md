# External Dependencies Audit

Every external resource used by the build and installer.

## Approval Status

| # | Dependency | Decision | Notes |
|---|-----------|----------|-------|
| 1 | Arch Linux ARM tarball | **APPROVED** | Official, GPG signed, HTTPS |
| 2 | Asahi ALARM keyring | **REPLACED** | Build our own keyring for our own packages |
| 3 | Asahi ALARM package repo | **REPLACED** | Build all ~20 Asahi packages from source, host ourselves |
| 4 | Arch Linux ARM mirrors | **APPROVED** | Official mirrors, GPG-signed packages. Cannot practically self-host |
| 5 | Omarchy repo | **APPROVED** | Our own repo |
| 6a | AUR: yay-bin | **APPROVED** | Audited. Binary from official github.com/Jguer/yay, SHA256 verified |
| 6b | AUR: elephant-* | **APPROVED** | Audited. Builds from source (github.com/abenz1267/elephant), omarchy ecosystem |
| 6c | AUR: omarchy-chromium-bin | **APPROVED** | Audited. Binary from github.com/omacom-io/omarchy-chromium, SHA256 verified |
| 6d | AUR: aether | **APPROVED** | Audited. Binary from github.com/bjarneo/aether, SHA256 verified |
| 6e | AUR: hyprshade | **APPROVED** | Audited. Source build from PyPI + GitHub |
| 6f | AUR: localsend-bin | **APPROVED** | Audited. Binary from official github.com/localsend, SHA256 verified |
| 6g | AUR: wayfreeze-git | **APPROVED** | Audited. Builds from source via cargo |
| 6h | AUR: hyprland-preview-share-picker-git | **APPROVED** | Audited. Builds from source via cargo |
| 6i | AUR: python-terminaltexteffects | **APPROVED** | Audited. Source build from GitHub |
| 6j | AUR: ttf-ia-writer | **APPROVED** | Audited. Font files from official iA repo, commit-pinned, SHA512 verified |
| 6k | AUR: tzupdate | **APPROVED** | Audited. Source build from GitHub |
| 6l | AUR: ufw-docker | **APPROVED** | Audited. Source build from GitHub |
| 6m | AUR: xdg-terminal-exec | **APPROVED** | Audited. Source build from freedesktop.org GitLab |
| 6n | AUR: yaru-icon-theme | **REMOVED** | Does not exist on AUR |
| 6o | AUR: blueberry | **APPROVED** | Audited. Source build from Linux Mint official |
| 7 | 1Password app | **APPROVED** | Official AgileBits domain, HTTPS |
| 8 | 1Password CLI | **APPROVED** | Official AgileBits domain, HTTPS, pinned version |
| 9 | Obsidian AppImage | **APPROVED** | Official obsidianmd GitHub, pinned version |
| 10 | Bun runtime | **APPROVED** | Official oven-sh GitHub. Must pin to specific version |
| 11 | Asahi installer (Python) | **FORKED** | Will fork, self-host, inspect and modify as our own |
| 12 | installer_data.json | **OWN** | We write our own |
| 13 | systemd-nspawn | **APPROVED** | System tool, part of systemd |

## Removed Dependencies (no longer used)

| Dependency | Reason |
|-----------|--------|
| asahi-alarm keyring | Building our own signing key + keyring |
| asahi-alarm package repo | Building all ~20 Asahi packages from AsahiLinux/* source repos |
| asahi-alarm mirrorlist | Replaced with our own package hosting |
| yaru-icon-theme (AUR) | Package does not exist on AUR |

## Self-Built Asahi Packages

These packages were previously fetched from asahi-alarm. We now build them from source.
See ASAHI-PACKAGES-BUILD.md for full details.

| Package | Upstream Source | Build Method |
|---------|---------------|-------------|
| linux-asahi | github.com/AsahiLinux/linux | Kernel build from PKGBUILD |
| m1n1 | github.com/AsahiLinux/m1n1 | Make from source |
| uboot-asahi | github.com/AsahiLinux/u-boot | Make from source |
| asahi-meta | Meta package (deps only) | Own PKGBUILD |
| asahi-scripts | github.com/AsahiLinux/asahi-scripts | Package from source |
| asahi-fwextract | github.com/AsahiLinux/asahi-installer | Extract from installer repo |
| asahi-audio | github.com/AsahiLinux/asahi-audio | Package config files |
| asahi-bless | github.com/AsahiLinux/asahi-nvram (crates.io) | Cargo build |
| asahi-btsync | github.com/AsahiLinux/asahi-nvram (crates.io) | Cargo build |
| asahi-wifisync | github.com/AsahiLinux/asahi-nvram (crates.io) | Cargo build |
| asahi-configs | Config files (inline in PKGBUILD) | Own PKGBUILD |
| tiny-dfr | github.com/AsahiLinux/tiny-dfr | Cargo build |
| speakersafetyd | github.com/AsahiLinux/speakersafetyd | Cargo build |
| bankstown | github.com/chadmed/bankstown | Python build |
| vulkan-asahi | Built as part of Mesa (archive.mesa3d.org) | Mesa build with Asahi drivers |
| alsa-ucm-conf-asahi | github.com/AsahiLinux/alsa-ucm-conf-asahi | Config files |
| widevine | Extracted from ChromeOS Lacros images | Custom extraction |

## AUR Package Audit Summary

All AUR packages have been audited. Findings:

| Package | Type | Source | Verdict |
|---------|------|--------|---------|
| yay-bin | Binary | github.com/Jguer/yay/releases | Clean. SHA256 verified. |
| elephant | Source | github.com/abenz1267/elephant | Clean. Go build. |
| hyprshade | Source | PyPI + github.com/loqusion/hyprshade | Clean. Python build. |
| localsend-bin | Binary | github.com/localsend/localsend/releases | Clean. SHA256 verified. |
| wayfreeze-git | Source | github.com/Jappie3/wayfreeze | Clean. Cargo build. |
| hyprland-preview-share-picker-git | Source | github.com/WhySoBad/hyprland-preview-share-picker | Clean. Cargo build. Uses MD5 (weak but standard for -git). |
| omarchy-chromium-bin | Binary | github.com/omacom-io/omarchy-chromium/releases | Clean. SHA256 verified. Trust depends on omacom-io. |
| aether | Binary | github.com/bjarneo/aether/releases | Clean. SHA256 verified. (Misleading: not named -bin but downloads binary.) |
| python-terminaltexteffects | Source | github.com/ChrisBuilds/terminaltexteffects | Clean. Python build. |
| ttf-ia-writer | Assets | github.com/iaolo/iA-Fonts (commit-pinned) | Clean. SHA512 verified. |
| tzupdate | Source | github.com/cdown/tzupdate | Clean. Cargo build. |
| ufw-docker | Source | github.com/chaifeng/ufw-docker | Clean. Shell scripts. |
| xdg-terminal-exec | Source | gitlab.freedesktop.org | Clean. Has test suite. |
| blueberry | Source | github.com/linuxmint/blueberry | Clean. Python build. |

No suspicious commands, no rogue downloads, no obfuscated code found in any PKGBUILD.
