# Install guide: the M1 path

M1 is the supported way to run Musca today. It flashes nothing: it adds a boot hook on the writable `/opt` volume that
starts `muscad` (local control, MQTT, Home Assistant) instead of the vendor cloud programs. Kernel, bootloader and the
stock system stay as they are, and the stock start-up comes back automatically if anything goes wrong.

Only vendor firmware **895** on a P592 has been tested. Other firmware versions or models: do not install.

## Risks, read first

- This is unofficial software for a device that dispenses food for an animal. A bug, a wrong config or a dead Wi-Fi link
  can leave the animal without a scheduled meal. The feeder MCU keeps its own meal schedule independently of Linux, and
  M1 does not change it, but you must verify that on your unit and keep a manual fallback for the first days.
- A wrong step can leave the device unreachable over the network. UART access (below) is the way back; plan for it.
- You void the warranty and you are on your own with PETKIT support. No affiliation with PETKIT.
- Do not start an install you cannot finish: the device must stay powered for the whole procedure.

## Prerequisites

| Need | Why |
|---|---|
| A P592 on firmware 895, root shell access (stock telnet or UART0) | the stock system exposes a root shell; this is how the package gets onto the device |
| About 13 MB free on `/opt` and enough RAM for a 5.4 MB archive in `/tmp` | the installer checks free space; 12 MB was too tight in practice |
| A workstation with Docker and Git | builds are in pinned Docker images, nothing installed on the host |
| A local MQTT broker and Home Assistant with the MQTT integration | see [Home Assistant](home-assistant.md) |
| A 3.3 V USB-UART adapter (TX, RX, GND only) | recovery path; see [safety and recovery](safety-recovery.md) |
| Your device on a network segment that you control | the stock firmware talks to the vendor cloud; block it (firewall) while you test |

## 1. Back up first

Do this before anything else and keep the result offline. Writes to flash are never part of the M1 path, so this step
only reads.

1. Note `cat /proc/cmdline`, `cat /proc/mtd` and the app's firmware version.
2. Dump every `mtd` partition to RAM (`/tmp`) and copy it off the device over the network; use `nanddump` and pipe its
   output through `head -c <partition-size>` because it pads to the page size. Record a SHA-256 for each file on both
   sides and compare.
3. Copy `/opt` (the whole volume is small) as an archive, and copy `/opt/system_init.sh` if it exists.

Your dump contains data unique to your device (identifiers, encrypted account material). **Never publish it, never
attach it to an issue, and do not commit it.** The repository ignores `backup/` for that reason.

## 2. Build the package

```
agent/scripts/build.sh release                       # static armv7 muscad and supervisor
m1/build.sh                                          # -> m1/dist/musca-m1.tar and its SHA-256
```

`m1/build.sh` refuses to package a config that enables remote feeding (`feed.enabled`, `feed.dry_run`) or the unproven
MCU switches (`mcu.set_time`, `mcu.ack_feed_log`). Optional: build the static dropbear SSH server first
(`tools/dropbear/build.sh`) and put your public SSH key into `m1/payload/musca/ssh/authorized_keys`. Without a key
there is no SSH server and telnet stays on. See [m1/README.md](https://github.com/OpenMusca/musca/blob/main/m1/README.md) for the package layout and the optional
Wi-Fi module per kernel.

## 3. Transfer and verify

Copy the archive to `/tmp` on the device (for example with `nc`, or over SSH when it exists), then compare the
SHA-256 on both ends. Unpack it, and run `sha256sum -c SHA256SUMS` inside; every line must say OK.

## 4. Install

```
cd /tmp/m1 && sh install.sh
```

`install.sh` verifies the checksums, needs about twice the payload size free on `/opt`, refuses to replace a
`/opt/system_init.sh` that is not ours, and keeps any existing config, keys and Wi-Fi copy. Then edit
`/opt/musca/muscad/config.toml`: set `mqtt.host` (and `mqtt.user`/`mqtt.pass`), your `tz`, and review the rest in the
[configuration reference](configuration.md). Leave `[feed]` off for the first boots.

## 5. First boot and checks

Reboot. Allow about two minutes, then again at six minutes. Pass criteria:

- the device answers on the network (SSH if installed, telnet otherwise) and is online in your broker (`musca/<id>/availability` is `online`);
- `pidof supervisor muscad` shows both; `state/log/log.0` shows `alive healthy=true`;
- the device did not reset by itself (uptime keeps growing past about 3 minutes, the MCU resets the board after ~90 s without valid frames);
- Home Assistant shows the "Musca P592" device with the button events and the MCU link `ON`;
- after about 5 minutes the boot counter is cleared (`state/boots` is gone).

If any check fails, follow [safety and recovery](safety-recovery.md); a plain `reboot`, or removing the hook, returns
you to stock.

## 6. Optional steps, each separately

1. **SSH key-only and telnet off.** First prove a key login works over Wi-Fi and survives a reboot; then
   `musca-harden off` from the SSH session turns telnet off at the next boot. Keep the UART path ready. The helper can
   also rotate the well-known vendor root password at every boot from a hash file you create yourself (`$6$`, mode 0600).
2. **Remote feeding.** Set `feed.dry_run = true` and `feed.enabled = true` first and press a button in HA; the frame is
   logged and not sent. Then set `dry_run = false`, feed one portion, and watch `mcu tx`/`mcu rx` in the log. Restart
   `muscad` after each change (`kill $(pidof muscad)`).
3. **Block the vendor cloud** at your router or firewall for the device's address. Musca never contacts it, but the
   stock fallback would.

## Uninstall

`sh uninstall.sh` from the unpacked package (`m1/uninstall.sh`) removes the hook and the shipped files and
restores the stock start-up after a reboot; `--purge` removes the whole `/opt/musca` directory, including your config
and keys. Quick path: `touch /opt/musca/DISABLE` (or `rm /opt/system_init.sh`) and reboot.

## What M1 does not do

No flashing, no signed updates, no camera, no change of the MCU's meal schedule. Updating M1 means rebuilding the
package and repeating steps 3 to 5 (back up the previous binaries first; `install.sh` keeps your config).
