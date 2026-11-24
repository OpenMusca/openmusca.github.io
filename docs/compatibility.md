# Compatibility and support status (v0.1)

## Hardware and firmware

| Item | Supported in v0.1 | Notes |
|---|---|---|
| Device | **PETKIT YumShare Dual-Hopper 2, model P592 only** | Other PETKIT models, hardware revisions and clones: do not install. No "try anyway" mode |
| Vendor firmware | **895** (kernel 4.19.125, `uname -v` build date Mar 23 2026; `/proc/cmdline` contains `version=261201`) | The only version tested. Read it with `uname -v`, `cat /proc/cmdline` and the vendor app. A different version is refused by the installer and must not be installed by hand |
| Boot slot | A (stock kernel) | v0.1 changes nothing in flash; `/opt` is the only thing written |
| Network | 2.4 GHz Wi-Fi on the vendor driver | Wi-Fi comes up the way stock brings it up; set the network up in the vendor app first |
| Host for the installer (planned) | Linux, macOS, Windows | Coming with the installer |
| Home Assistant | any recent version with the MQTT integration | Entities via MQTT discovery |

## What is in v0.1

| Feature | State | Page |
|---|---|---|
| Local control daemon `muscad`, supervisor, boot hook with automatic fall back to stock | works | [safety](safety-recovery.md) |
| MQTT + Home Assistant discovery: buttons, food low (tentative), motors, MCU link, feed events, diagnostics | works | [Home Assistant](home-assistant.md) |
| Remote feeding with hard limits | works, **off by default**, opt-in | [safety](safety-recovery.md#feed-safety-limits) |
| SSH (dropbear, key-only), optional telnet off | works | [install](install.md) |
| Firewall helper (nft) | works | [configuration](configuration.md) |
| On-device web UI (status, settings, optional test feed; the schedule page is display only) | works, **off by default**, LAN only, no TLS | [web-ui.md](web-ui.md) |
| Back to stock | works | [uninstall.md](uninstall.md) |

## What is not in v0.1

- No own kernel, bootloader or slot B: not part of this release. Do not follow any page that flashes partitions.
- No camera, microphone or audio streaming as a supported feature (experimental code exists; keep it off).
- No over-the-air update service: updating means installing a new package ([install](install.md#updating)).
- No change of the MCU's meal plan, no setting of the MCU clock (`mcu.set_time` is off).
- No vendor app or cloud. After Musca takes over, the vendor app cannot control the feeder, and you can neither view nor change the MCU meal plan (to change it: uninstall, change it in the app, install again).
- Whether the vendor app works again after an uninstall has not been tested.

Marks used here: **works** = seen working on a real device; see [conventions](overview.md#conventions).
