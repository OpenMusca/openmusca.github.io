# OpenMusca

**Open-source, local-only firmware for the PETKIT YumShare Dual-Hopper 2 (P592) pet feeder.**
Control it from Home Assistant over MQTT, without the vendor cloud, and with a way back to stock at every step.

!!! warning "Experimental, work in progress"
    This is unofficial software for hardware that dispenses food for animals. Installing it can brick the device,
    void the warranty, or leave a pet without food. Keep the feeder's own meal schedule or a manual fallback in
    place, test unattended before relying on it, and never run it on a device you cannot recover.
    Read [Safety and recovery](safety-recovery.md) first. Use at your own risk.

## Status

Early. A reversible soft-install (no flashing) runs on one P592 with one vendor firmware version. The full image,
signed updates and the camera are in progress. Expect breaking changes. The source repository
([OpenMusca/musca](https://github.com/OpenMusca/musca)) is **coming soon**; until it is released, this site
is the public documentation of the project.

## What works today

- **Local control.** `muscad`, a small Rust daemon, replaces the vendor control program through a reversible boot
  hook. It talks to the feeder's MCU, enforces feed safety limits and publishes food levels, button events and
  feed events to **Home Assistant via MQTT discovery**. No vendor cloud is started.
- **A/B slots with fallback.** Our U-Boot lives in slot B; stock stays in slot A. A power cut or repeated failed
  boots fall back to the stock start-up, so recovery is always possible.
- **Own U-Boot and kernel, in progress.** U-Boot 2020.04 with a SPI-NAND driver for the feeder's flash boots a
  kernel copy from slot B. Own kernel builds exist but have not booted on the device yet.
- **Clean-room policy.** No vendor firmware, libraries, dumps or images are part of the project. Anything
  device-specific is pulled from your own device at install time; behaviour is documented from observation and
  rewritten from scratch. See [Legal](legal.md).

## Where to start

| I want to... | Read |
|---|---|
| understand the hardware | [Hardware](hardware.md), [Architecture](architecture.md) |
| try it on my feeder | [Safety and recovery](safety-recovery.md), then [Install guide](install.md) |
| connect Home Assistant | [Home Assistant](home-assistant.md), [Configuration](configuration.md) |
| help | [Contributing](contributing.md), [Development](development.md) |
| report a security issue | [Security policy](security.md) |

Recent changes are listed in [News](news.md). All pages are in the navigation. The [Overview](overview.md) explains the status labels (works, experimental,
planned).

## Licence and disclaimer

Text and site content are released under the [MIT licence](licensing.md) (code parts under the licences
listed there). OpenMusca is an independent community project. It is not affiliated with, authorised or endorsed
by PETKIT. "PETKIT" and "YumShare" are trademarks of their owners and are used here only to name the hardware
this project is compatible with. Use at your own risk; read the full [Disclaimer](disclaimer.md), which also
explains the legal background for owners in Germany and the EU.
