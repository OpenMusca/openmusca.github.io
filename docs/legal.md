# Legal

This page is a plain-language summary for users and contributors. It is not legal advice.

## Licences

| Part | Licence |
|---|---|
| `agent/`, `m1/`, scripts in `tools/`, documentation | MIT (`LICENSE`) |
| `br2-musca/` (Buildroot external tree) | GPL-2.0-or-later |
| U-Boot patches in `tools/build/patches/uboot/` | GPL-2.0-or-later, same as U-Boot |
| Linux kernel patches in `tools/build/patches/kernel/` | GPL-2.0-only, same as the Linux kernel |
| Third-party code in the M1 package (dropbear, musl, Rust crates, the Wi-Fi driver module built from Realtek's GPL source) | their own licences; texts ship in the package (`THIRD_PARTY.md`, `LICENSES/`) |

The full table, including parts whose status is still under review, is in [LICENSING.md](licensing.md). The device
tree in `tools/build/dts/` is derived from a vendor file and is not part of the public tree until its status is cleared.

## No vendor material

This repository and every published image contain no vendor firmware, kernel modules, libraries, boot images,
device dumps or vendor-derived text. Files that the running system needs from the vendor image (for example the
camera and encoder modules, or the stock root filesystem pieces) are never redistributed.

## Your own firmware

If a step needs something from the stock firmware, you extract it from your own device, and it stays with you.

- The install procedure pulls the device-specific files from your unit at install time (for example the stock Wi-Fi
  configuration).
- Your flash backup is yours. Do not publish it, do not attach it to issues, do not commit it. It contains identifiers
  and account material that belong to you and your account.
- Do not redistribute vendor files you extracted, and do not ask others to send you theirs.

## GPL source offer

For every binary release that contains GPL or LGPL components (our U-Boot and kernel builds, Buildroot packages,
BusyBox, and others), the complete corresponding source is provided:

1. The release lists the components with licences and the exact source revisions (SBOM and `THIRD_PARTY.md`).
2. The source archives, our patches and the build configuration are published next to the binaries and kept for at
   least three years after the last release that contains them. The build is reproducible, so you can verify that the
   binary comes from that source.
3. The written offer is part of each image and of the release notes. Until the contact address and the mirror URL for
   it are published, there is no binary release that needs the offer: **planned**.
4. If you cannot find the source for a binary you received from the project, ask in an issue; we will provide it.

Maintainers check each release against a fixed list: source archives, SBOM, checksums, licence texts and a scan for vendor files.

## Reverse engineering and interoperability

The MCU protocol, the XINCUN flash support and the boot chain were worked out by observing a lawfully owned device, for
interoperability with replacement software. Documents describe observed behaviour, not vendor code.

## Trademarks

PETKIT, Axera, Realtek, Telink and other names are trademarks of their owners and are used only to identify the
hardware this project works with. Musca is unofficial and is not affiliated with or endorsed by any of them.

## Warranty

The software is provided as is, without warranty of any kind, under the licences above. Installing it can brick the
device, void the manufacturer warranty or interrupt feeding of an animal. See [safety and recovery](safety-recovery.md).

## AI assistance

Musca is developed with AI coding assistants under human direction and review. The clean-room process, its limits
(analyst and implementer are separate sessions of the same AI model) and our reading of the EU AI Act and of
§ 2 Abs. 2 UrhG are described on the website: https://openmusca.github.io/disclaimer/
