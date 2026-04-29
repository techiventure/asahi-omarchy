# Security Audit

Full security review of all external images, scripts, binaries, and repos used by the Omarchy Asahi Installer.

Audit date: 2026-04-28

## Dependency Security Matrix

| # | Dependency | URL | Transport | Signed/Verified | Pinned Version | Trust Level | Severity | Issues |
|---|-----------|-----|-----------|-----------------|----------------|-------------|----------|--------|
| 1 | Arch Linux ARM tarball | archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz | HTTPS | GPG sig available (.sig file, key `68B3537F...`) | NO (`latest` = rolling) | High (official project, est. 2009) | **Medium** | Unpinned rolling tarball; content changes silently between builds. Must verify .sig after download. |
| 2 | Asahi ALARM keyring | github.com/asahi-alarm/asahi-alarm/releases | HTTPS (GitHub) | Package signed (key `12CE6799...`) | YES (via pacman) | Medium (community fork of Asahi Linux) | **Medium** | Org has no public members visible on GitHub. Cannot independently verify who controls signing key. |
| 3 | Asahi ALARM package repo | github.com/asahi-alarm/asahi-alarm/releases/download/$arch | HTTPS (GitHub) | Packages GPG-signed | YES (via pacman) | Medium | **Medium** | Same trust concern as #2. All packages flow through this org. |
| 4 | Arch ARM mirrors | fl.us.mirror.archlinuxarm.org etc. | **HTTP (no TLS)** | Packages GPG-signed by pacman | YES (via pacman) | High (official mirrors) | **Medium** | Plain HTTP is MITM-susceptible. Mitigated by pacman GPG verification on every package. Tarball must NOT be fetched from these mirrors. |
| 5 | Omarchy repo | github.com/basecamp/omarchy | HTTPS (GitHub) | N/A (git clone) | Branch-pinned | High (Basecamp/37signals, verified org, 22k stars) | **Low** | Trusted source. Cloned during build via techiventure/asahi-omarchy scripts. |
| 6a | AUR: yay-bin | aur.archlinux.org | HTTPS | No (AUR is unaudited) | Pinned via PKGBUILD | Medium (10k+ stars, widely used) | **Low** | Prebuilt binary from yay GitHub releases. Well-known project. |
| 6b | AUR: elephant-* (12 packages) | aur.archlinux.org | HTTPS | No | Pinned via PKGBUILD | **Low** (omarchy-specific, low adoption) | **Medium** | Low community scrutiny. Should audit PKGBUILDs before including. |
| 6c | AUR: omarchy-chromium-bin | aur.archlinux.org | HTTPS | No | Pinned via PKGBUILD | **Low** | **High** | Prebuilt Chromium browser binary from custom source. Browser is high-value attack target. Must verify PKGBUILD source URL points to trusted build. |
| 6d | AUR: aether | aur.archlinux.org | HTTPS | No | Pinned via PKGBUILD | Low | **Medium** | Less known package. Should audit PKGBUILD. |
| 6e | AUR: other (hyprshade, localsend-bin, wayfreeze-git, etc.) | aur.archlinux.org | HTTPS | No | Pinned via PKGBUILD | Medium | **Low** | Standard community packages. localsend-bin downloads from official GH releases. |
| 7 | 1Password app | downloads.1password.com/linux/tar/stable/aarch64/ | HTTPS | No sig verification in script | YES (but `latest` URL) | High (official AgileBits domain) | **Low** | Official domain verified. `latest` URL means version floats. |
| 8 | 1Password CLI | cache.agilebits.com/dist/1P/op2/pkg/v2.30.0/ | HTTPS | No sig verification in script | YES (v2.30.0 pinned) | High (official AgileBits domain) | **Low** | Pinned version is good. Will go stale over time. |
| 9 | Obsidian AppImage | github.com/obsidianmd/obsidian-releases | HTTPS (GitHub) | No sig verification | YES (v1.8.9 pinned) | High (official org, 17k stars) | **Low** | Closed-source binary. Trusted publisher. No code audit possible. |
| 10 | Bun runtime | github.com/oven-sh/bun/releases/latest/ | HTTPS (GitHub) | No sig verification | **NO** (`latest` tag) | High (official org, 89k stars) | **Medium** | Unpinned `latest` = non-reproducible. Compromised release would auto-propagate. Should pin to specific version. |
| 11 | Asahi installer (Python) | asahi-alarm.org/installer-${VERSION}.tar.gz | HTTPS | No sig on tarball | YES (version from /latest) | Medium | **High** | curl\|sh pattern executes arbitrary code. No signature verification on the script or tarball. HTTPS prevents MITM but does not verify publisher identity. |
| 12 | systemd-nspawn | System tool (part of systemd) | Local | N/A | System version | High (systemd project) | **Low** | Not a security container (documented by systemd). Fine for builds. Keep systemd updated (historical CVEs exist). |

## Critical Findings

### HIGH Severity

| # | Finding | Risk | Recommendation |
|---|---------|------|----------------|
| H1 | `omarchy-chromium-bin` is a prebuilt Chromium binary from AUR | Browsers are the #1 attack surface. A compromised binary has full access to passwords, sessions, etc. | Audit the PKGBUILD source URL. Verify it points to a known/trusted CI build. Consider building from source instead. |
| H2 | Asahi installer uses curl\|sh pattern | Script is downloaded and executed without verification. Network issues could cause partial execution. | Download script first, review, then execute. Or: verify HTTPS certificate chain is intact. Accept as industry-standard risk for installer bootstraps. |

### MEDIUM Severity

| # | Finding | Risk | Recommendation |
|---|---------|------|----------------|
| M1 | Arch ARM tarball is unpinned (`latest`) | Builds are not reproducible. A compromised tarball silently affects all future builds. | Verify GPG signature after every download. Consider archiving known-good tarballs. |
| M2 | Bun uses `latest` tag | Same as M1 -- non-reproducible, auto-propagates compromises. | Pin to specific version (e.g., `v1.2.3`). |
| M3 | Arch ARM mirrors use plain HTTP | MITM possible on package downloads. | Mitigated by pacman GPG verification. Acceptable. Ensure initial tarball always comes from HTTPS. |
| M4 | asahi-alarm org has no public members | Cannot independently verify who controls the signing key and package builds. | Accept if you trust the project. They are the de facto Arch Linux ARM on Apple Silicon community. |
| M5 | `elephant-*` and `aether` AUR packages have low adoption | Less community review = higher risk of unnoticed issues. | Audit PKGBUILDs before including. These appear to be omarchy-ecosystem packages. |

### LOW Severity

| # | Finding | Risk | Recommendation |
|---|---------|------|----------------|
| L1 | 1Password CLI version pinned but will go stale | May miss security patches over time | Update version periodically |
| L2 | Obsidian is closed-source | Cannot audit the binary | Trusted publisher (obsidianmd). Accept. |
| L3 | systemd-nspawn is not a security container | Build environment is not fully isolated | Acceptable for build use. Don't run untrusted code in it. |
| L4 | MD5 checksum provided for ALARM tarball (in addition to GPG) | MD5 is cryptographically broken | Use GPG signature, ignore MD5. |

## Recommendations Before First Build

1. **Add GPG signature verification** to `build-rootfs.sh` for the Arch ARM tarball
2. **Pin Bun to a specific version** instead of `latest`
3. **Audit `omarchy-chromium-bin` PKGBUILD** -- verify the binary source URL
4. **Audit `elephant-*` PKGBUILDs** -- verify they build from trusted source repos
5. **Pin 1Password app** to a specific version instead of `latest` URL

## Resolutions (2026-04-29)

| Finding | Resolution | Status |
|---------|-----------|--------|
| H1: omarchy-chromium-bin | PKGBUILD audited. Binary from github.com/omacom-io/omarchy-chromium, SHA256 verified. **APPROVED by owner.** | RESOLVED |
| H2: curl\|sh installer | **APPROVED by owner.** Accept as industry standard. Will fork installer and self-host. | RESOLVED |
| M1: Unpinned Arch ARM tarball | **ACCEPTED by owner.** GPG signature available for verification. | ACCEPTED |
| M2: Unpinned Bun | **Will pin to specific version.** | TODO |
| M3: HTTP mirrors | **ACCEPTED.** Mitigated by pacman GPG verification. | ACCEPTED |
| M4: asahi-alarm opaque org | **ELIMINATED.** Building all ~20 Asahi packages from source (AsahiLinux/* repos). No dependency on asahi-alarm org. | RESOLVED |
| M5: elephant-*/aether low adoption | PKGBUILD audited. All clean. **APPROVED by owner** as omarchy ecosystem. | RESOLVED |
| L1-L4 | All accepted at current risk level. | ACCEPTED |

## Additional Decisions

| Decision | Rationale |
|----------|-----------|
| Fork Asahi installer | Full control over the macOS bootstrap and Python installer. Self-hosted. |
| Build Asahi packages from source | Eliminate trust dependency on asahi-alarm org. Build from official AsahiLinux/* upstream repos. |
| Keep Arch ARM mirrors | Impractical to self-host thousands of packages. GPG verification is sufficient. |
| All AUR PKGBUILDs audited | 15 packages audited. No suspicious code found. See DEPENDENCIES.md for full table. |
| yaru-icon-theme removed | Package does not exist on AUR. |
