# Troubleshooting

Find the symptom, check the cause, apply the fix. Commands run in a shell on the device (SSH, or stock telnet/UART after a
fallback). Logs: `/tmp/musca/hook.log`, `/tmp/musca/supervisor.log` (RAM) and the persistent, size-bounded
`/opt/musca/state/log/`. They are designed not to hold keys or passwords; check before you share one. Do not reboot or
restart near a scheduled meal (40 minutes either side, on your clock and the feeder's, see the [install guide](install.md#path-b-manual)). Every `kill $(pidof muscad)` counts toward the hook's fallback: five restarts in ten minutes fall back to stock, so restart at most three times in ten minutes.

## Food did not come

First, who owns the meal? The **feeder MCU** runs the meal plan from the vendor app on its own clock, with Linux up or
down. Musca does not change it. A missed scheduled meal is therefore almost never a `muscad` problem.

| Check | Cause | Fix |
|---|---|---|
| Home Assistant "Feed event" / `event/feed` shows `fed` | Meal was dispensed; the hopper may be empty or jammed | Check the hopper; `food low` is tentative. Hand-feed now |
| Event shows `jammed` | Food stuck in the dispenser | Clear it by hand (power off first), then retry |
| Event shows `skipped` | Also produced at its time by every web-UI schedule entry (`manual: false`); the schedule page never dispenses food. Otherwise the feeder reported a skipped meal (reasons not decoded yet) | Do not rely on web-UI schedule entries. For a real skip, hand-feed and check the MCU clock offset |
| Remote feed answered `refused` (reason in the event) | A safety limit: `daily_limit`, `rolling_limit`, `busy`, `no_link`, rate limit | Wait, or raise `feed.max_portions_per_day` deliberately ([limits](safety-recovery.md#feed-safety-limits)). `no_link`: see "MCU link OFF" below |
| No feed buttons in HA | `feed.enabled = false` (the default) | Remote feeding is opt-in; see [install](install.md#6-optional-steps-each-separately) |
| Press did nothing, `dry_run` event | `feed.dry_run = true`: frames are logged, not sent | Set `dry_run = false`, restart `muscad` |
| MCU link `OFF` | No valid frames from the MCU | See the row below |
| Meal time came while the feeder was rebooting or in fallback | The MCU still feeds from its own plan; a rebooting board does not stop it | Check the vendor-app plan survived; if unsure, hand-feed and check the clock (`diag/mcu_clock`) |
| Meal never came and nothing else is wrong | The MCU plan itself is missing or wrong | Hand-feed. Musca cannot read, change or restore the plan while it runs; to change it, uninstall, edit it in the vendor app, install again |

When in doubt: hand-feed first, debug afterwards.

## The feeder

| Symptom | Likely cause | Fix |
|---|---|---|
| Not on the network after install and reboot | Hook fell back to stock, or Wi-Fi did not come up (`NET_FAIL` after 300 s) | Stock telnet/UART; read `/opt/musca/state/log/hook.log`; fix the cause, then `rm -f /opt/musca/state/boots`; see [recovery ladder](safety-recovery.md#recovery-ladder) |
| No Wi-Fi at all | Wrong or missing Wi-Fi copy; the unit was never joined to Wi-Fi in the vendor app; weak signal | Join Wi-Fi in the vendor app first (a factory-reset unit has no other way without UART). Check `/opt/musca/wpa_supplicant.conf` exists (mode 600). Power-cycle after moving the router or changing its channel |
| Reboots by itself every ~90 s | The MCU resets the board when it gets no valid frames from `muscad` | Make sure only `muscad` opens the serial port; check `pidof supervisor muscad`; read the supervisor log |
| Stock behaviour after a few boots (vendor `ctrl` runs, telnet is back) | Boot guard: 3 boots without 5 stable minutes, 5 crashes in 10 minutes, or `DISABLE` | Read the FALLBACK reason in `state/log/hook.log`. Boot counter reason only: `rm -f /opt/musca/state/boots /opt/musca/state/planned-used`, reboot, keep 5+ minutes of uptime. Other reasons: fix the cause |
| SSH refused / telnet gone | Telnet was turned off (`musca-harden off`) and the key does not match | UART, or power-cycle into a fallback; `/opt/musca/musca-harden stock` works only in an SSH session; from telnet/UART use `touch /opt/musca/DISABLE` and reboot |
| `install.sh` stops on space | `/opt` needs about 13 MB free | Remove old backups and archives from `/opt` and retry |

## MQTT and Home Assistant

| Symptom | Likely cause | Fix |
|---|---|---|
| `availability` stays `offline` | Wrong `mqtt.host`/user/pass, broker down, or a firewall between feeder and broker | Check `config.toml` and the supervisor log; test with `mosquitto_sub` from another host; restart `muscad` after edits |
| No "Musca P592" device in HA | MQTT integration without discovery, a different discovery prefix, or the retained message was cleared | Enable discovery in the integration; restart `muscad` to republish `homeassistant/device/musca_<id>/config` |
| An entity is missing | It needs a config switch: feed buttons need `feed.enabled`, sound/mic/LED entities their `[sound]`, `[mic]`, `[led]` switches; some diagnostics are off by default | Table in [Home Assistant](home-assistant.md#entities); set the switch, restart `muscad`, then reload the entity list |
| Duplicate or orphaned entities | `device_id` changed (it is derived from the Wi-Fi MAC when unset) | Set `device_id` explicitly; remove the old device in HA |
| Entities unavailable but feeder fine | Broker restarted without retained data, or HA restarted before the feeder | Wait for the next publish or restart `muscad` |
| MCU link `OFF` | Serial link broken or MCU silent | Wait one minute; if it stays, power-cycle the feeder; `mcu tx`/`mcu rx` lines in the supervisor log |
| "Host time synced" off | No NTP reachable (feeder has no internet) | Point `ntpd` at a local NTP server; the MCU meal plan keeps its own clock either way |

## The web UI is not reachable

| Symptom | Likely cause | Fix |
|---|---|---|
| Nothing answers right after a reboot | `muscad` starts before Wi-Fi/DHCP and retries the bind every 5 s | Wait a minute; the UI comes back by itself while the feeder keeps its address. Check the log for `web: listening on` |
| Worked before, not now | DHCP gave the feeder a new address; the listener keeps retrying the old one forever and `public_origin` no longer matches | Add a DHCP reservation, set `bind`/`public_origin` to the new address (re-enable, see [web-ui.md](web-ui.md#enable)), restart `muscad` |
| Page loads, login gives 403 | You used a hostname URL; only the exact `public_origin` is accepted | Open `http://<device-ip>:8080/` exactly as configured |
| Login gives 429 | 5 wrong passwords: all logins locked for 60 s | Wait a minute |
| "Connection refused" | `[web] enabled = false`, wrong port, bad or empty `password_hash` | Fix `[web]`; the log says why the listener stayed closed; restart `muscad` |
| Port 8080 in use | Another listener on the port | Choose another `port` and set `public_origin` to match |
| UI off, log says `config.web.toml ... the web UI stays OFF` | The settings overlay saved by the UI is broken (hand-edited, truncated) and changed a login-related value; falling back to `config.toml` could bring back an older setting, so the UI stays off (since m30) | Fix or delete `config.web.toml` next to `config.toml`, restart `muscad` (see [web-ui.md](web-ui.md)) |

Feeding is never affected by the web UI failing. See [web-ui.md](web-ui.md).

## Asking for help

Open an issue with the supervisor log excerpt and your `muscad --version`, after removing addresses, serial numbers,
Wi-Fi names and credentials. Security problems: see [SECURITY.md](security.md). A hardware or flash incident that left a
device unrecoverable: [safety and recovery](safety-recovery.md#reporting-a-bad-outcome).
