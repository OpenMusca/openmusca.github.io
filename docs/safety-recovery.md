# Safety and recovery

## Principles

1. **Back up before you change anything**, and verify the backup by checksum.
2. **Never overwrite the stock chain.** Slot A (stock U-Boot and kernel) and the SPL stay as shipped; our code goes to
   the writable `/opt` volume (M1) or to slot B (advanced).
3. **Every step has a way back**, written down before the step is run.
4. The animal comes first: keep the MCU's own meal schedule, and a manual fallback, until you trust the setup.

## What never to touch

| Part | Why |
|---|---|
| SPL (`mtd1`) and ddrinit (`mtd2`) | If either is damaged the board does not start and there is no on-board way to recover it. The secure-boot/eFuse state of your unit is unknown; a write that looks harmless could make the BootROM reject the next stage. Musca never writes them and neither should you |
| eFuses / OTP | One-time and irreversible. Never program or probe them |
| Slot A U-Boot and kernel (`mtd3`, `mtd7`) | They are your recovery system |
| Environment partitions (`mtd5`, `mtd6`) | Our U-Boot does not write them during boot; writing them from Linux can change which slot boots |
| The MCU firmware | It runs the motors; Musca only talks to it |

Flash steps (advanced users only) must compare SHA-256 before and after, and `nanddump` output must be cut to the
partition length (`head -c`), because it pads to the page size.

## Fail-safes in the M1 hook

The hook runs the stock start-up instead of Musca, and re-enables telnet, when any of these is true:

| Condition | Result |
|---|---|
| `/opt/musca` or one of its files is missing | stock start-up |
| `/opt/musca/DISABLE` exists | stock start-up |
| 3 boots without `muscad` running stable for 5 minutes (`MAX_BOOTS`, `STABLE`) | stock start-up; `rm /opt/musca/state/boots` to retry |
| `muscad` restarted 5 times within 10 minutes (`MAX_CRASHES`, `WINDOW`) | stock start-up |
| no IPv4 address on Wi-Fi after 300 s (`NET_FAIL`) | stock start-up (stock brings Wi-Fi up its own way) |

Three power cuts in a row, each within 5 minutes of a boot, also end in the stock start-up. After a fallback the vendor
telnet password is public: re-apply your hardening afterwards.

Logs: `/tmp/musca/hook.log` and `/tmp/musca/supervisor.log` (RAM), and, persistent and size-bounded, `/opt/musca/state/log/`
(hook log, supervisor ring with the last words before a crash, boot snapshots). They are designed not to contain keys,
password hashes or Wi-Fi credentials; check before you share one.

## Recovery ladder

Try in this order.

1. **Reboot** or power-cycle. A power cut returns to slot A, the stock kernel, where the same hook runs and the guards apply.
2. **Disable the hook:** over SSH or telnet, `touch /opt/musca/DISABLE` and reboot. Stock `ctrl` runs again.
3. **Remove the hook:** `rm /opt/system_init.sh` and reboot, or run `sh uninstall.sh` from the package.
4. **Restore `/opt` files from your backup** (hook, binaries, config).
5. **Serial console (UART0, 115200 8N1, 3.3 V, TX/RX/GND only).** Never connect the adapter's power pin; never use a 5 V
   adapter. Log in with the console login, or, with our U-Boot in slot B, stop the boot to start a shell for one boot
   and then remove the hook. Keep this path available: never disable the console login.
6. **Reflash from your own dump** of the affected partition, only with a verified checksum and the exact partition size.
   Last resort; never SPL, ddrinit or eFuses.

## Feed safety limits

These are enforced in `muscad` (`agent/crates/musca-p592/src/device.rs`), independent of what the broker sends:

| Limit | Value |
|---|---|
| portions per hopper per request | 1 to 4 (0 for the other hopper), at least one portion in total |
| minimum time between manual feeds | 60 s |
| manual feeds per rolling hour | 10 |
| portions per rolling hour | `max_portions_per_hour` (default 20) |
| concurrent requests | one; a second one is refused as `busy` |
| duplicate request ids | ignored |
| link down | refused as `no_link` |

Remote feeding is off by default (`feed.enabled = false`), the MCU's own schedule is untouched, and a refused request is
reported as an event. These limits reduce but do not remove the risk: an authenticated MQTT client can still use them
up. Restrict who can publish to the command topics.

## Reporting a bad outcome

If a procedure in this documentation led to an unrecoverable device or an unsafe feeder, open an issue without logs
that contain addresses, serial numbers or credentials, or report privately per [SECURITY.md](security.md) if it is
a security problem.
