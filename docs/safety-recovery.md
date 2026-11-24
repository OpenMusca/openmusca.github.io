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
| 3 counted boots without `muscad` running stable for 5 minutes (`MAX_BOOTS`, `STABLE`) | stock start-up; `rm -f /opt/musca/state/boots /opt/musca/state/planned-used` to retry |
| `muscad` restarted 5 times within 10 minutes (`MAX_CRASHES`, `WINDOW`) | stock start-up |
| no IPv4 address on Wi-Fi after 300 s (`NET_FAIL`) | stock start-up (stock brings Wi-Fi up its own way) |

After the first IPv4 the boot-time rule above no longer applies; a background loop (`musca-wlan.sh`, `WLAN_WD=0` or `touch /opt/musca/state/wlan-wd-off` turns it off) recovers a lost Wi-Fi with lease/supplicant/interface steps. A recovery reboot exists but ships OFF (`WLAN_REBOOT=0`); when on it is a normal counted boot (never `planned-reboot`), at most 2 per 24 h, 3 h apart, never inside 11:20-12:40 / 12:50-14:10, only with a trusted clock and a stable boot, and a corrupt `state/wlan-reboots` means no reboot. A warm reboot from slot B lands in A. Rollback: `WLAN_WD=0`, the kill-switch file, or remove `musca-wlan.sh`.

Three power cuts in a row, each within 5 minutes of a boot, also end in the stock start-up. Reboots that our own device tools
issue on purpose write `/opt/musca/state/planned-reboot` first; from package m21 on the hook consumes it once and does not count that boot
(older packages ignore the marker and count every boot; while `state/no-boot-count` exists, as during the slot-B kernel tests, nothing is counted and nothing is credited; at most 8 such credits until muscad has been stable for 5 minutes, and never once the counter has reached `MAX_BOOTS`;
`state/planned-used` holds the credits). Unplanned boots always count.
After a fallback the telnet/UART root password is the rotated one when `ssh/root.hash` is valid; only without a valid
`root.hash` is it the vendor password, which is public: re-apply your hardening afterwards.

Logs: `/tmp/musca/hook.log` and `/tmp/musca/supervisor.log` (RAM), and, persistent and size-bounded, `/opt/musca/state/log/`
(hook log, supervisor ring with the last words before a crash, boot snapshots). They are designed not to contain keys,
password hashes or Wi-Fi credentials; check before you share one.

Scripted recovery from a fallback: `tools/device/recover-fallback.sh --pw-file F --read` logs in over stock telnet (port 23, `root`, password from the 0600 file F, the rotated one when `root.hash` is valid), saves the boot counter and hook logs to `build/device/fallback-<ts>.txt` and prints the FALLBACK reason. Only for the boot-counter reason, `--confirm --clear` removes `state/boots`, reboots, waits for SSH and runs `preflight.sh`; other reasons (DISABLE, missing files, crashes, NET_FAIL) are never cleared by the script, fix the cause by hand. Afterwards keep at least 5 minutes of stable uptime.

A reboot without the Musca hook (for example after `DISABLE`, a fallback or `uninstall.sh`) lets stock `ctrl` sync slot A to slot B
(`mtd7` to `mtd8`, `mtd3` to `mtd4`): harmless on a device with a stock copy in B, destructive on one with its own kernel or U-Boot in B.

## Power cut and cold start

What a mains power cut (or unplugging the feeder) does, and what you need to do afterwards.

| Part | Behaviour |
|---|---|
| Meal plan | Lives in the feeder MCU, which runs it on its own clock whether Linux is up or down ([hardware](hardware.md)). Musca neither stores nor changes it. Whether the plan and the MCU clock survive a cut with no batteries inserted is **not yet verified**: after any power cut, watch that the next scheduled meal is dispensed ("Last feed" in Home Assistant) and hand-feed if in doubt |
| Boot slot | A cold start always boots slot A (stock U-Boot and kernel), because the slot register is cleared by the power cut. If you ran a slot-B kernel (advanced), you are back in A. The same Musca hook runs there, so the [fail-safes](#fail-safes-in-the-m1-hook) apply unchanged |
| Host clock | The Linux clock is wrong (1970) until NTP has answered, and Musca does not use the hardware clock on this kernel. Until it is synced, the daily feed count falls back to a rolling 24 h ([limits](#feed-safety-limits)) and log lines carry the uptime instead of a date. The MCU keeps its own clock; compare it with `diag/mcu_clock` |
| Boot counter | A power cut is an unplanned boot and counts. Three cuts in a row, each within 5 minutes of a boot, end in the stock start-up; one cut followed by 5 minutes of stable uptime clears the counter. Only reboots that Musca's own tools issue on purpose are not counted (see above) |
| Feed counters | The daily remote-feed count is stored on flash and survives. The rolling 24 h bound counts the downtime as zero, which is stricter, never looser ([limits](#feed-safety-limits)). |
| Logs | The RAM logs (`/tmp/musca/`) are lost. The persistent ring in `/opt/musca/state/log/` keeps what was flushed, at most about the last minute before the cut is missing. The first `BOOT` line of the new run says that the previous run left no last words, which is what a power cut or a hardware reset looks like |

What to do:

- **Wait.** Wi-Fi, MQTT and the web UI come back by themselves, usually within a minute or two; the web UI may need a minute more
  ([troubleshooting](troubleshooting.md#the-web-ui-is-not-reachable)). Do not power-cycle again while it boots.
- **Check the next meal.** The feeder's plan is not Musca's; if the next scheduled meal is near, hand-feed and sort the rest out after.
- **After a long cut,** check the MCU clock offset (`diag/mcu_clock`, MCU minus host clock) once the host clock is synced, and watch the next scheduled meal.
- **Repeated cuts** (a flaky socket or supply) can use up the boot guard and land in the stock start-up. That is the guard working;
  fix the supply, then follow [the recovery steps](#fail-safes-in-the-m1-hook) and keep 5 minutes of uptime.

What not to do:

- Do not reboot, pull the plug or restart `muscad` near a scheduled meal to "fix" something ([FAQ](faq.md#is-it-safe-to-reboot-or-restart-muscad-any-time)).
- Do not clear the boot counter, remove the hook or reflash because of a single cut: one cut needs no action.
- Do not write the environment partitions or flash slot A to "restore" the slot choice; the cold start in A is the designed recovery state.
- If the feeder stops responding with the network up (no new BOOT line, no ping), do not assume it will reset itself: a hung shutdown can
  leave it stuck until power is cut. This was seen once and its cause is not yet verified; a power cut is then the right way out, and the
  ring's last lines are worth keeping (check them for secrets before sharing).

## Battery operation (untested)

The feeder has a battery compartment. Musca has **not** been tested on battery power: the stock firmware tells the
feeder controller when Linux may be powered down, and Musca does not do this yet, so the behaviour on battery (and how long the
batteries last) is unknown. Keep mains power connected, insert batteries only with mains connected, and never install, update or
flash while running on battery.

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

## OTA rollback (m-package updates, `updater.install_target = "mpkg"`)

An over-the-air update (P3b.0) changes only `bin/muscad`, `bin/musca-sink`, `bin/musca-snap`, `bin/musca-cam` and `share/**` and
restarts only muscad; the boot hook, the supervisor and the Wi-Fi and firewall scripts are never updated over the air. Before the
first change it writes a backup in the same format as `rollout-m.sh` (`bin/*.pre-mNN`, `/opt/system_init.sh.pre-mNN`,
`backup-pre-mNN/`) and a journal (`state/ota-journal`).

- **Automatic rollback.** The boot hook restores the old files when the new muscad restarts three times within ten minutes
  (or is down for 60 s), when it is not confirmed within 15 minutes (a meal window can extend this once by 20 minutes), or
  at the second counted boot of the trial. A power cut in the middle of an install is repaired at the next boot before anything
  of `/opt/musca` is used. If the restore itself fails, the stock fallback runs. The failed generation is removed (a restore
  of the same release may be tried again; a release that crashed or was never confirmed is refused until you remove
  `state/ota-failed-<release>`).
- **By hand.** `rollout-m.sh --confirm --rollback mNN` undoes an OTA install exactly like a host install and clears the OTA
  state files; it refuses while the journal says `installing` or `restoring` (the device-side restore owns it). A stuck
  journal that nothing resolves: `rm /opt/musca/state/ota-journal* /opt/musca/state/ota-trial*` over SSH, then reboot.
- **Restore failed (`OTA-RESTORE-FAILED` in the hook log).** A journal in phase `installed`/`trial` whose backup is missing or
  does not match its pin cannot be restored; the hook then runs the stock fallback on every boot until the OTA state is
  removed. A power cut cannot cause this (journal and trial files are written by rename, the backup is removed after them),
  only manual damage. SSH may be down in the fallback: log in over stock telnet (`tools/device/recover-fallback.sh --pw-file F --read`
  shows the reason), remove `/opt/musca/state/ota-journal* /opt/musca/state/ota-trial*`, reinstall the last good package
  with `rollout-m.sh` if files under `/opt/musca/bin` are mixed, then reboot.
- **Never over the air:** the hook, the supervisor, kernel, U-Boot, file removals. These need `rollout-m.sh`.
- **Disable:** `touch /opt/musca/DISABLE` and reboot, as for any fault; `updater.install_target = "none"` (default) turns the
  OTA install off.

## Feed safety limits

These are enforced in `muscad` (`agent/crates/musca-p592/src/device.rs`), independent of what the broker sends:

| Limit | Value |
|---|---|
| portions per hopper per request | 1 to 4 (0 for the other hopper), at least one portion in total |
| minimum time between manual feeds | 60 s by default, `feed.min_interval_s` (0 = off; a running feed is always refused as `busy`) (all time windows run on the monotonic clock, a clock step changes nothing) |
| manual feeds per rolling hour | 10 |
| portions per rolling hour | `max_portions_per_hour` (default 20) |
| portions per day (remote feeds only, MCU meals not counted) | `feed.max_portions_per_day` (default 10, 1 to 50), refused as `daily_limit`; local midnight when the clock is synced, else rolling 24 h; the count is stored on flash and survives restarts and reboots (`feed_counter_file`), shown in Home Assistant as "Remote feeds today" |
| portions per rolling 24 h, whatever the wall clock says | 2 x `feed.max_portions_per_day` (default 20), refused as `rolling_limit`; on the monotonic clock, so forward clock steps (a broken or spoofed NTP server) cannot open a new daily budget again and again. With a correct clock it does not bind, with two exceptions on the safe side: right around the 23 h day of the spring DST change, and after a reboot for at most the downtime (a power cut does not count as elapsed time, so feeds from before it count up to that much longer). Survives restarts exactly and reboots with the downtime counted as zero (stricter). It is a hard bound of 2 x the daily cap per 24 h, not the daily cap: with a wrong or spoofed clock the calendar cap alone does not hold |
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
