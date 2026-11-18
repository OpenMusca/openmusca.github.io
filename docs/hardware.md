# Hardware overview: PETKIT YumShare Dual-Hopper 2 (P592)

Facts about the feeder as far as this project knows them. Confidence levels:

- **confirmed**: observed on a real device by this project (boot logs, register reads, captured traffic, our own code running on it);
- **community**: stated by public third-party projects and not independently checked here;
- **guess**: inferred, not verified.

Nothing here is copied from vendor documentation or firmware. Part numbers and addresses are facts about hardware;
behaviour was learned by observation.

| Item | Finding | Confidence |
|---|---|---|
| SoC | Axera AX620E family (AX620Q class), two Cortex-A53 cores run in AArch32 | community, consistent with our boot work |
| RAM | 256 MiB in the SoC package; stock gives Linux 96 MiB and reserves 160 MiB for media/NPU | confirmed (kernel command line) |
| Flash | 128 MiB SPI NAND from XINCUN; builds from the public SDK sources need our added XINCUN driver patch to read it | confirmed |
| Flash layout | `mtd0` and up: SPL, ddrinit, U-Boot (slot A), U-Boot B, env, env B, kernel (slot A), kernel B, then UBI for the rest (`/opt` is writable UBIFS) | confirmed |
| Boot | BootROM, SPL, U-Boot, kernel. The SPL picks slot A or B from a register (`0x02390024`); a power cut returns to slot A | confirmed |
| Boot-image integrity | the SPL checks a magic and two additive word sums, not a signature; the image header carries a key it never reads | confirmed by reading the SPL; eFuse/secure-boot state not verified, treat as unknown |
| Kernel | stock Linux 4.19.125 (armhf); modules are pinned to that exact build | confirmed |
| Console | UART0, 115200 8N1, 3.3 V logic; the stock console login is on it | confirmed |
| Feeder MCU | a separate Telink TLSR82xx-class MCU runs motors, hopper sensors, the meal schedule, RTC, buttons and BLE. It keeps its schedule while Linux is down | community, behaviour confirmed |
| MCU link | UART3 (`/dev/ttyS3`), frames `5A A5`, little-endian length, command, sequence, flags, payload, CRC-16/CCITT-FALSE (poly 0x1021, init 0xFFFF, little-endian). Several payload layouts are still tentative | confirmed (CRC-valid frames captured and decoded) |
| Wi-Fi | Realtek RTL8733BU dual-band over USB; driver `8733bu` (Realtek GPL source). The vendor module is only ABI-compatible with the stock kernel | confirmed |
| Camera | 2 MP GalaxyCore sensor on MIPI, Axera ISP and H.264 encoder (closed vendor blocks) | community; not used by Musca yet (planned) |
| Network services (stock) | telnet with a well-known root password, vendor cloud client over MQTT/HTTP | confirmed |

## Boot flash layout (slot model)

| Partition | Role | Touched by Musca? |
|---|---|---|
| SPL, ddrinit | first-stage loader and DRAM setup | never. They are not rewritable safely and not ours |
| U-Boot (slot A), kernel (slot A), env, UBI rootfs | the stock system, our recovery path | not modified by the M1 install |
| U-Boot B, kernel B | our boot chain (experimental, developer-only today) | by advanced builds only |
| `/opt` (UBIFS) | writable volume; holds the M1 hook and `/opt/musca` | yes, by the M1 install |

## Inside the device

You do not have to open the case for the M1 install. The UART0 pads are the physical recovery path; to use them you
need a 3.3 V USB-UART adapter wired to TX, RX and GND only. Never connect the adapter's power pin to the board and
never use a 5 V adapter. Pad positions vary between hardware revisions; photograph the board before you probe it.

## What is not known

Whether the SoC's secure-boot eFuses are blown on your unit (assume they might be: never write SPL or ddrinit), the exact
camera/ISP chip markings, and the meaning of some MCU payload fields. The [architecture](architecture.md) page says
what depends on which of these.
