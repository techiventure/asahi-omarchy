# Custom Installer

Forked Asahi installer, fully self-hosted on our infrastructure.

## Architecture

All installer components are hosted on our CDN. No runtime dependency on asahi-alarm.org.

```
R2 CDN (r2-foss.techiventure.com/asahi-omarchy/)
  ├── installer/
  │   ├── install.sh              # Bootstrap script (curl|sh entry point)
  │   ├── installer.tar.gz        # Forked Python installer
  │   └── installer_data.json     # Points to our image
  ├── images/
  │   └── omarchy.zip             # Root filesystem + ESP
  └── packages/
      └── aarch64/                # Our pacman repo (self-built Asahi packages)

Website (asahi-omarchy.techiventure.com)
  Single-page Next.js app with install instructions
  /install redirects to the bootstrap script on R2
```

## Component 1: Bootstrap Script

File: `installer/install.sh`

Hosted at: `https://r2-foss.techiventure.com/asahi-omarchy/installer/install.sh`

The website at `asahi-omarchy.techiventure.com/install` redirects to this URL so users can run:

```bash
curl -fsSL https://asahi-omarchy.techiventure.com/install | sh
```

The bootstrap script:
1. Verifies running on macOS
2. Downloads our forked Python installer tarball from R2
3. Downloads our installer_data.json from R2
4. Runs the installer with our config

All downloads come from `r2-foss.techiventure.com` -- no external dependencies at install time.

## Component 2: Forked Python Installer

The Asahi Python installer (~3000 lines) handles:
- Apple Silicon partition table manipulation
- APFS container resizing
- m1n1 stub installation
- Boot policy registration
- Firmware extraction and copying

We fork it from `github.com/asahi-alarm/asahi-alarm-installer`, audit the code, rebrand, and host the tarball on R2.

Source repo: `omarchy/asahi-installer` (our fork)

Changes from upstream:
- Branding (Omarchy instead of Asahi ALARM)
- Hardcoded URLs removed/replaced with our CDN
- Audited for security

## Component 3: installer_data.json

```json
{
  "os_list": [
    {
      "name": "Omarchy",
      "default_os_name": "Omarchy",
      "boot_object": "m1n1.bin",
      "next_object": "m1n1/boot.bin",
      "package": "https://r2-foss.techiventure.com/asahi-omarchy/images/omarchy.zip",
      "supported_fw": ["12.3", "12.3.1", "13.5"],
      "extras": {},
      "partitions": [
        {
          "name": "EFI",
          "type": "EFI",
          "size": "524288000B",
          "format": "fat",
          "volume_id": "0x2abf9f91",
          "copy_firmware": true,
          "copy_installer_data": true,
          "source": "esp"
        },
        {
          "name": "Root",
          "type": "Linux",
          "size": "8000000000B",
          "expand": true,
          "image": "root.img"
        }
      ]
    }
  ]
}
```

## Component 4: Image Hosting (Cloudflare R2)

The `omarchy.zip` image (~3-6 GB) is hosted on R2:

```
https://r2-foss.techiventure.com/asahi-omarchy/images/omarchy.zip
```

R2 advantages over GitHub Releases:
- No 2 GB file size limit
- Global CDN (Cloudflare edge network)
- No split/reassembly needed
- Bandwidth is cheap

### R2 Bucket Structure

```
asahi-omarchy/
  ├── installer/
  │   ├── install.sh
  │   ├── installer.tar.gz
  │   └── installer_data.json
  ├── images/
  │   ├── omarchy.zip              # Latest image
  │   └── omarchy-v2025.04.28.zip  # Versioned archive
  └── packages/
      └── aarch64/
          ├── omarchy-asahi.db
          ├── omarchy-asahi.db.tar.gz
          ├── linux-asahi-6.x-1-aarch64.pkg.tar.zst
          ├── m1n1-1.x-1-aarch64.pkg.tar.zst
          └── ... (all self-built packages)
```

## User-Facing Install Command

```bash
curl -fsSL https://asahi-omarchy.techiventure.com/install | sh
```

### What the User Sees

```
$ curl -fsSL https://asahi-omarchy.techiventure.com/install | sh

  ____  __  __    _    ____   ____ _   ___   __
 / __ \|  \/  |  / \  |  _ \ / ___| | | \ \ / /
| |  | | |\/| | / _ \ | |_) | |   | |_| |\ V /
| |  | | |  | |/ ___ \|  _ <| |___|  _  | | |
 \____/|_|  |_/_/   \_|_| \_\\____|_| |_| |_|

Omarchy Installer for Apple Silicon

macOS version: 14.5
Downloading installer...
Downloading configuration...
Extracting...

Starting installation...
NOTE: You will be asked how much disk space to allocate to Omarchy.
      Recommended: at least 50 GB.

Available OS options:
  1. Omarchy

Choose an OS [1]: 1

How much disk space would you like to allocate? [50 GB]:

...
(partitioning and image writing follows)
...

Installation complete! Reboot and select "Omarchy" from the boot picker.
```

## Updating the Image

When omarchy releases a new version:

1. Build updated Asahi packages (if upstream changed)
2. Upload packages to R2: `r2-foss.techiventure.com/asahi-omarchy/packages/aarch64/`
3. Build new rootfs image
4. Upload to R2: `r2-foss.techiventure.com/asahi-omarchy/images/omarchy.zip`
5. No installer_data.json change needed (URL stays the same)

## Upload to R2

Using wrangler (Cloudflare CLI) or rclone:

```bash
# Upload image
rclone copy images/omarchy.zip r2:asahi-omarchy/images/

# Upload packages
rclone sync packages/aarch64/ r2:asahi-omarchy/packages/aarch64/

# Upload installer
rclone copy installer/ r2:asahi-omarchy/installer/
```

## Compatibility

### Supported Hardware
- M1, M1 Pro, M1 Max, M1 Ultra
- M2, M2 Pro, M2 Max, M2 Ultra
- M3, M3 Pro, M3 Max (with appropriate firmware)

### macOS Version Requirements
- macOS 12.3+ for basic support
- macOS 13.5+ recommended

### Dual Boot
Always dual-boot. macOS cannot be removed from Apple Silicon (needed for firmware updates and recoveryOS).
