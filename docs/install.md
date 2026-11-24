# Install guide

v0.1 installs the **userland package (M1)**: it flashes nothing. It adds a boot hook on the writable `/opt` volume that
starts `muscad` (local control, MQTT, Home Assistant) instead of the vendor cloud programs. Kernel, bootloader and the
stock system stay as they are, and the stock start-up comes back automatically if anything goes wrong. See
[compatibility](compatibility.md) for what v0.1 does and does not include, and the [quickstart](quickstart.md) for the
short version.

## Two ways to install

| Path | For | State |
|---|---|---|
| **A. Installer** (`musca-install`) | non-experts | **coming with the installer**; designed, not built yet |
| **B. Manual** (this page, from "Prerequisites") | people comfortable with a shell | scripts exist; install, uninstall and web UI tested end to end on a P592 on 20.11.2026 (PASS) |

### Path A: the installer (coming with the installer)

One static program for Linux, macOS and Windows. You keep the feeder on the LAN and do the physical parts (set up Wi-Fi
and the meal plan once in the vendor app, keep the adapter plugged in, unplug and replug when asked). The installer does
the rest, step by step, each step as a dry-run plan first:

1. `musca-install probe <device-ip>` reads model, firmware and layout (read only). It **refuses** anything that is not a
   P592 on firmware 895, a power source it cannot confirm, or an unhealthy device.
2. It logs in once over stock telnet using the stock telnet password, which is **bundled with the installer**.
3. `backup` dumps every flash partition and `/opt` to your computer and compares SHA-256 on both ends. The backup stays on
   your machine and is never uploaded.
4. It creates an SSH key and a random per-device recovery password (shown once, keep it), installs the package, reboots,
   and verifies (key login, `muscad` healthy, link up, five minutes of uptime, MQTT online).
5. Optionally it turns telnet off after a key login has survived a reboot.

The installer binary, its checksum and its Ed25519 signature will be published with the release; verifying them will be
one command per operating system. Until it is released, use path B.

### Path B: manual

The steps match the install scripts. Install, uninstall and the web UI were run by hand on a P592 (firmware 895) on 20.11.2026 and
passed. The release signature check in step 2 has not been tested yet: no signing run has happened.

Only vendor firmware **895** on a P592 has been tested. Other firmware versions or models: do not install.

### Risks, read first

- This is unofficial software for a device that dispenses food for an animal. A bug, a wrong config or a dead Wi-Fi link
  can leave the animal without a scheduled meal. The feeder MCU keeps its own meal schedule independently of Linux, and
  M1 does not change it, but you must verify that on your unit and keep a manual fallback for the first days.
- A wrong step can leave the device unreachable over the network. UART access (below) is the way back; plan for it.
- You void the warranty and you are on your own with PETKIT support. No affiliation with PETKIT.
- Do not start an install you cannot finish: the device must stay powered for the whole procedure.

On path B you log in to the stock system yourself. Over telnet that is the vendor's well-known root password; this
documentation does not print it (see [SECURITY.md](security.md) for why it is a known weakness). The release package ships it
in <!-- PLACEHOLDER: file name in the release package not defined yet; fill in when the installer release is built -->
the file named in the release notes. UART0 is the alternative: it gives a root console without the telnet password, see the UART
login steps in the [recovery ladder](safety-recovery.md#recovery-ladder).
Read the meal times from the vendor app before you install; once Musca runs you can no longer view or change the meal plan
(to change it: uninstall, change it in the vendor app, install again).

### Prerequisites

| Need | Why |
|---|---|
| A P592 on firmware 895, root shell access (stock telnet or UART0) | the stock system exposes a root shell; this is how the package gets onto the device |
| About 13 MB free on `/opt` and enough RAM for a 5.4 MB archive in `/tmp` (check with `df /opt` and `free`) | `install.sh` checks free space; 12 MB was too tight in practice |
| A workstation with Docker and Git | builds are in pinned Docker images, nothing installed on the host |
| A local MQTT broker and Home Assistant with the MQTT integration | see [Home Assistant](home-assistant.md) |
| A 3.3 V USB-UART adapter (TX, RX, GND only) | recovery path; see [safety and recovery](safety-recovery.md) |
| Your device on a network segment that you control | the stock firmware talks to the vendor cloud; block it (firewall) while you test |

### 1. Back up first

Do this before anything else and keep the result offline. Writes to flash are never part of the M1 path, so this step
only reads.

1. Note `cat /proc/cmdline` (it contains `kernel=a` or `kernel=b`, the slot that booted), `cat /proc/mtd` and the app's firmware version.
2. The device has little RAM (about 96 MB) and `/tmp` is in RAM: **never dump a partition into `/tmp`**. Check `free`,
   then stream one small raw partition at a time (U-Boot `mtd3`, environment `mtd5`, kernel `mtd7`; check the names in `/proc/mtd`)
   straight to your computer, for example
   on the device `nanddump /dev/mtdN | head -c <size> | nc <your-pc> 9001` and on the computer
   `nc -l -p 9001 > mtdN.bin` (netcat flags differ by build). `/proc/mtd` shows the size in **hex**; convert it in the shell, for
   example `echo $((0x80000))` prints 524288. `head -c` is needed because `nanddump` pads to the page size. If `nanddump` is
   missing on your unit, skip the raw dumps and keep the `/opt` archive. If your computer cannot accept inbound connections
   (for example WSL2 in NAT mode), reverse the direction: the device listens, the computer connects.
   ```
   # default:  computer: nc -l -p 9001 > mtdN.bin                  device: nanddump /dev/mtdN | head -c <size> | nc <your-pc> 9001
   # reversed: device:   nanddump /dev/mtdN | head -c <size> | nc -l -p 9001      computer: nc <device-ip> 9001 > mtdN.bin
   ```
   Start the listener first in both cases; the reversed form blocks the device shell until the computer connects, so use a second session or add `&` for a following command.
   Compare `sha256sum` on both ends. Do not dump the large UBI partition; archive the content instead (next point). Only read
   from `/dev/mtd*`, never write to it.
3. Archive `/opt` as a stream the same way: `tar -C /opt -cf - . | nc <your-pc> 9001`, and keep `/opt/system_init.sh` if it exists.

This backup matters for later flash work, which v0.1 does not do. If a large dump does not work, do not let it block the
install: v0.1 writes only under `/opt`.

Your dump contains data unique to your device (identifiers, encrypted account material). **Never publish it, never
attach it to an issue, and do not commit it.** The repository ignores `backup/` for that reason.

### 2. Get the package

From the release page: `musca-m1.tar` and `musca-m1.tar.sig`, plus `SHA256SUMS` and `SHA256SUMS.sig` (every release file has an
Ed25519 signature `<file>.sig`; `SHA256SUMS` lists the SHA-256 of all of them). Verify before use,
with the project's public key `tools/release/keys/musca-release-ed25519.pub.pem` (fingerprint, the SHA-256 of its DER form:
`d842ecb336b89097c718337d34b262a051df1dbf514a26946d8176221a87eada`):

```
openssl pkey -pubin -in musca-release-ed25519.pub.pem -outform DER | sha256sum     # compare with the fingerprint
openssl pkeyutl -verify -pubin -inkey musca-release-ed25519.pub.pem -rawin -in SHA256SUMS -sigfile SHA256SUMS.sig
openssl pkeyutl -verify -pubin -inkey musca-release-ed25519.pub.pem -rawin -in musca-m1.tar -sigfile musca-m1.tar.sig
sha256sum -c --ignore-missing SHA256SUMS
```

This needs **OpenSSL 3** (`-rawin`). macOS ships LibreSSL, which
does not support it: install OpenSSL 3 from a package manager and call that binary. The signature steps are not tested yet (no signing run).
Or build it yourself:

```
agent/scripts/build.sh release                       # static armv7 muscad and supervisor
m1/build.sh                                          # -> m1/dist/musca-m1.tar and its SHA-256
```

`m1/build.sh` refuses to package a config that enables remote feeding (`feed.enabled`, `feed.dry_run`) or the unproven
MCU switches (`mcu.set_time`, `mcu.ack_feed_log`). Optional: build the static dropbear SSH server first
(`tools/dropbear/build.sh`) and put your public SSH key into `m1/payload/musca/ssh/authorized_keys`. Without a key
there is no SSH server and telnet stays on. See [m1/README.md](https://github.com/OpenMusca/musca/blob/main/m1/README.md) for the package layout and the optional
Wi-Fi module per kernel.

### 3. Transfer and verify

Copy the archive to `/tmp` on the device, then compare the SHA-256 on both ends. Unpack it, and run `sha256sum -c SHA256SUMS`
inside; every line must say OK.

```
# device:       cd /tmp && nohup nc -l -p 9000 > musca-m1.tar 2>/dev/null &   # busybox nc needs -l -p; in the background so the shell stays free
# device:       pidof nc                                                     # must print a pid before you send
# workstation:  nc <device-ip> 9000 < musca-m1.tar
# device:       sha256sum musca-m1.tar                                        # compare, then:
tar xf musca-m1.tar && cd m1 && sha256sum -c SHA256SUMS
```

### 4. Install

```
cd /tmp/m1 && sh install.sh        # the folder created by the tar command above
```

`install.sh` verifies the checksums, needs about twice the payload size free on `/opt`, refuses to replace a
`/opt/system_init.sh` that is not ours, and keeps any existing config, keys and Wi-Fi copy. Then edit
`/opt/musca/muscad/config.toml` (copy it first with `cp -p`; a typo makes `muscad` refuse to start; the stock system has busybox
`vi`, and for appending `cat >> file <<'EOF'` works; both keep the file mode `0600`, which a copy-and-replace may not): set `mqtt.host` (and `mqtt.user`/`mqtt.pass`), your `tz`, and review the rest in the
[configuration reference](configuration.md). Leave `[feed]` off for the first boots.

### 5. First boot and checks

Reboot. Allow about two minutes, then again at six minutes. The first boot after the install counts toward the boot guard
(`MAX_BOOTS=3`, see [safety and recovery](safety-recovery.md#fail-safes-in-the-m1-hook)); the checks below clear the counter.
Pass criteria:

- the device answers on the network (SSH if the package has your key; telnet otherwise, and also if you reinstall over an earlier
  install that turned telnet off, see [uninstall](uninstall.md#reinstalling-later)) and is online in your broker (`musca/<id>/availability` is `online`);
- `pidof supervisor muscad` shows both; `/tmp/musca/supervisor.log` (RAM, lost at reboot; the persistent copy is `/opt/musca/state/log/log.0`) shows `alive healthy=true`;
- the device did not reset by itself (uptime keeps growing past about 3 minutes, the MCU resets the board after ~90 s without valid frames);
- Home Assistant shows the "Musca P592" device with the button events and the MCU link `ON`;
- after about 5 minutes the boot counter is cleared (`/opt/musca/state/boots` is gone);
- `grep -o 'kernel=.' /proc/cmdline` prints `kernel=a` and `uname -r` shows the stock kernel version. If a reboot ever lands in
  slot B (`kernel=b`, only a device with a second kernel in B), the stock-kernel promise does not hold for that boot.

If any check fails, follow [safety and recovery](safety-recovery.md); a plain `reboot`, or removing the hook, returns
you to stock.

### 6. Optional steps, each separately

1. **SSH key-only and telnet off.** First prove a key login works over Wi-Fi and survives a reboot; then
   `musca-harden off` from the SSH session turns telnet off at the next boot. Keep the UART path ready. The helper can
   also rotate the well-known vendor root password at every boot from a hash file you create yourself (`$6$`, mode 0600).
2. **Remote feeding.** Set `feed.dry_run = true` and `feed.enabled = true` first and press a button in HA; the frame is
   logged and not sent. Then set `dry_run = false`, feed one portion, and watch `mcu tx`/`mcu rx` in the log. Restart
   `muscad` after each change (`kill $(pidof muscad)`). Restart at most three times in ten minutes: a fifth restart within
   ten minutes makes the hook fall back to stock (fix the cause, then reboot once).
3. **Block the vendor cloud** at your router or firewall for the device's address. Musca never contacts it, but the
   stock fallback would.

### Uninstall

See [uninstall](uninstall.md). Quick path: `touch /opt/musca/DISABLE` and reboot.

### Updating

Updating M1 means installing a newer package: repeat steps 3 to 5 (first `cp -a /opt/musca/bin /opt/musca/bin.prev`; `install.sh` keeps
your config, keys and Wi-Fi copy). To go back, copy `bin.prev` over `bin` and reboot; delete `bin.prev` afterwards (space). There is no update service in v0.1. Check [compatibility](compatibility.md)
before you update.

### What M1 does not do

No flashing, no signed updates, no camera, no change of the MCU's meal schedule.
