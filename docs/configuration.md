# Configuration reference

`muscad` reads one TOML file. On an M1 install it is `/opt/musca/muscad/config.toml`; `muscad` itself defaults to
`/opt/muscad/config.toml` (a symlink created by the boot hook) and accepts `--config <path>`. Keep the file mode at
`0600`: it can hold the MQTT password. The installer never overwrites an existing config.

Command line: `muscad [--config <path>] [--dry-run] [--help|--version]`. `--dry-run` builds and logs every feed frame
but never writes it to the UART, and implies `feed.enabled`.

Unknown keys are ignored (an old key does not stop the daemon), a wrong value for a known key does, with the key named
in the error. Only `[mqtt] host` is required. A change takes effect after `muscad` restarts: `kill $(pidof muscad)`
and the supervisor respawns it.

This page is checked against `agent/crates/musca-core/src/config.rs` by `tools/docs/check-config-docs.py` (part of
`tools/ci/run-all.sh`): a key without a row here, a row without a key, or a different default fails the test. The
Default column therefore holds the literal default, `unset` for optional keys, and `required` where there is none.
The `m1` package ships a template that sets some keys explicitly (notably `feed.enabled = false`).

## Top level

| Key | Type | Default | Notes |
|---|---|---|---|
| `device_id` | string | `unset` | Id used in topics and Home Assistant unique ids. `[a-z0-9_-]`, 1 to 32 characters; invalid values refuse to start. Unset: derived from the `wlan0` MAC (`p592_<last 3 bytes>`), then the hostname, then `p592`. Set it explicitly if you want ids that survive a Wi-Fi module swap. |
| `device` | string | `p592` | Compiled-in device module. Only `p592` exists. |
| `serial_port` | string | `unset` | Serial port of the feeder MCU. Unset: the device module's default (`/dev/ttyS3` on the P592). `muscad` must be the only process that opens it; two openers steal each other's bytes. |
| `tz` | string | `Europe/Berlin` | IANA time zone for the local schedule and the MCU clock offset. Change it, the default is the author's. A bundled tz database is used, not the device's. |
| `max_portions_per_hour` | integer | `20` | Hard cap on portions dispensed per rolling hour (monotonic clock), enforced by the agent for manual feeds. Valid 1 to 50; anything else logs a warning and uses the default. Lower it if in doubt. This is in addition to the fixed per-request limits (see [safety](safety-recovery.md#feed-safety-limits)). |
| `feed_counter_file` | string | `/opt/musca/state/feed_today.json` | File that keeps the remote-feed day counter (`feed.max_portions_per_day`) across `muscad` restarts and reboots. Written atomically with mode 0600 whenever the count changes; an unreadable or corrupt file counts as "limit reached" for a rolling 24 h, never as unlimited. Delete it to reset the counter. Keep it on the flash volume, not in RAM. |
| `state_dir` | string | `/opt/muscad` | Directory for state and schedule on the writable flash volume. Do not point it at RAM (`/tmp`) if you want state to survive a reboot. |

## `[mqtt]`

| Key | Type | Default | Notes |
|---|---|---|---|
| `mqtt.host` | string | `required` | Broker host or IP. The M1 template ships `192.0.2.1`, a documentation address, so a fresh install starts but connects nowhere until you edit it. |
| `mqtt.port` | integer | `1883` | Plain MQTT, no TLS (planned). Run the broker on the local network only; see [SECURITY.md](security.md). |
| `mqtt.user` | string | `unset` | Broker user; used only if `pass` is set too. Use a dedicated account with access to `musca/#` and `homeassistant/#` only. |
| `mqtt.pass` | string | `unset` | Broker password, stored in clear text in the file (mode 0600). Never reuse a password from elsewhere. |

## `[mcu]`

The MCU link options. Defaults are the conservative ones; anything that writes to the MCU beyond the basic exchange is
off.

| Key | Type | Default | Notes |
|---|---|---|---|
| `mcu.status_keepalive` | bool | `false` | Send the vendor's host status message (CMD 0x09) about every 61 s. Purpose unknown; leave off. |
| `mcu.time_query` | bool | `true` | Read-only: ask the MCU for its version and clock at link-up and log them (also periodically, see `time_check_interval_s`). Safe. |
| `mcu.set_time` | bool | `false` | Set the MCU clock from the host clock. Only acts if the host clock is NTP-synced and plausible. Off because the frame has not yet been seen on the wire; the MCU clock drives its own meal schedule, so a wrong time moves meals. Enable only after you have compared the logged MCU and host clocks. The M1 package builder refuses to ship it as `true`. |
| `mcu.time_check_interval_s` | integer | `3600` | Seconds between MCU clock checks. With `set_time`, a drift of 2 s or more or a changed UTC offset re-sets the clock. |
| `mcu.answer_surplus` | bool | `true` | Answer the MCU's food-surplus query like the stock firmware does without a cloud, so the MCU does not wait for a reply. Needs a plausible host clock. |
| `mcu.ntp_stamp` | string | `/tmp/musca/ntp-sync` | Stamp file written by the NTP hook on each sync; a fresh stamp is the proof of a synced host clock for `set_time`. An empty string disables the stamp and falls back to the kernel flag only, which busybox `ntpd` does not clear reliably. |
| `mcu.ntp_stamp_max_age_s` | integer | `10800` | Maximum age of that stamp in seconds. |
| `mcu.ack_feed_log` | bool | `false` | Acknowledge every MCU feed-log record the way the stock firmware does after the cloud confirmed it. Never seen on the wire, so off. The M1 package builder refuses to ship it as `true`. |
| `mcu.diag` | bool | `true` | Publish read-only diagnostics to Home Assistant under `state/diag/` (host time synced, MCU clock offset, boot slot, kernel build, muscad version, uptime, Wi-Fi signal, last feed). Reads `/proc` files only and never sends anything to the MCU. See [Home Assistant](home-assistant.md#diagnostics). |

The "Hopper 1/2 food low" binary sensors (tentative decoding of the MCU status message) need no setting: they are
always announced, read only from frames the MCU sends on its own, and are independent of `mcu.diag` and `feed.enabled`.
See [Home Assistant](home-assistant.md#food-low-tentative).

## `[feed]`

| Key | Type | Default | Notes |
|---|---|---|---|
| `feed.enabled` | bool | `false` | Announce the feed buttons and the portion number in Home Assistant and accept feed commands. Off by default: the MCU feeds on its own schedule and a fresh install must not react to MQTT commands. Turn on only after a dry run, and only on a network where nobody untrusted can publish to the broker. |
| `feed.dry_run` | bool | `false` | Build and log every feed frame but never write it to the UART. Use it first on a new setup. The M1 package builder refuses to ship it as `true`. |
| `feed.max_portions_per_day` | integer | `10` | Cap on portions fed remotely (Home Assistant, MQTT) per day. The MCU's own meals do not count; there is no lock window around them. The day ends at local midnight (`tz`) while the host clock is NTP-synced, otherwise a rolling 24 h window applies. Valid 1 to 50; anything else logs a warning and uses the default (never unlimited, never everything refused). The count survives restarts and reboots (see `feed_counter_file`). A refused request is reported as `daily_limit`; the current count is shown in Home Assistant as "Remote feeds today". |

## `[sound]`

Speaker clips from Home Assistant. Off by default; needs the own kernel (a sound card). See
[Home Assistant](home-assistant.md#speaker-sounds-optional).

| Key | Type | Default | Notes |
|---|---|---|---|
| `sound.enabled` | bool | `false` | Announce the sound button, select and volume, and accept the commands. |
| `sound.device` | string | `/dev/snd/pcmC0D0p` | ALSA playback node. |
| `sound.level_db` | float | `-20.0` | Old name of the ceiling, used only if `max_level_dbfs` is unset; never above -20. |
| `sound.max_level_dbfs` | float | `unset` | Level of 100 % volume in dBFS. Unset: -20. Limited to -60 .. -6. |
| `sound.volume_file` | string | `/opt/musca/state/sound_volume.json` | Persisted volume. Empty: RAM only. |
| `sound.min_interval_s` | integer | `10` | Minimum seconds between two clips; values below 10 are raised to 10. |

## `[mic]`

Microphone level sensor. Off by default: nothing is captured. Only RMS and peak numbers are published, never audio. See
[Home Assistant](home-assistant.md#microphone-level-optional).

| Key | Type | Default | Notes |
|---|---|---|---|
| `mic.enabled` | bool | `false` | Announce the sensors and measure. |
| `mic.device` | string | `/dev/snd/pcmC0D1c` | ALSA capture node. |
| `mic.rate` | integer | `16000` | Capture rate, `16000` or `48000`; anything else refuses to start. |
| `mic.interval_s` | integer | `10` | Seconds between two 1 s measurements; values below 5 are raised to 5. |
| `mic.spl_offset_db` | float | `unset` | Calibration: estimated dB SPL = dBFS + this (within +-200). Unset: dBFS only. |

## `[audio_rx]`

Experimental audio receiver (Snapcast client or RTP listener). Off by default: with `mode = "off"` nothing is started and no
entity is announced. Whether the receiver runs is the Home Assistant switch "Audio receiver", which is off after every
`muscad` start unless `autostart = true`. The sink (`musca-sink`) enforces the volume cap, the no-sound file and the feeding
windows (a margin around each scheduled meal, fixed in `tools/audio/musca-sink.c`; adjust them to your schedule); it refuses to start in them and stops
when one begins. `muscad` only starts, stops and restarts it (backoff 5 s to 300 s, fixed 60 s after a refused start). An
invalid config or a missing binary makes the receiver unavailable with a log warning; `muscad` keeps running. See
[Home Assistant](radio.md).

| Key | Type | Default | Notes |
|---|---|---|---|
| `audio_rx.mode` | string | `off` | `off`, `snapcast` (`musca-snap` connects to a snapserver and feeds the sink) or `rtp` (`musca-sink --rtp` listens for RTP). Any other value makes the receiver unavailable (warning). |
| `audio_rx.autostart` | bool | `false` | Start the receiver right after `muscad` starts. `false`: only the HA switch turns it on. |
| `audio_rx.bin_dir` | string | `/opt/musca/bin` | Directory with `musca-snap` and `musca-sink`. Must be an absolute path. |
| `audio_rx.host` | string | `""` | `snapcast` only: IPv4 address of the snapserver. Required there; private LAN (RFC 1918), loopback or link-local only. Public addresses and host names are refused. |
| `audio_rx.port` | integer | `0` | `snapcast`: snapserver port; `rtp`: UDP port to listen on. `0` means 1704 (`snapcast`) or 5004 (`rtp`). 0 to 65535. |
| `audio_rx.bind` | string | `""` | `rtp` only: this device's concrete unicast IPv4 address to listen on. Required there; never `0.0.0.0`, broadcast or multicast. |
| `audio_rx.codec` | string | `l16` | `rtp` only: `l16` or `opus`. Anything else is refused. |
| `audio_rx.volume_db` | float | `-20.0` | Software attenuation of the sink in dB. Clamped to -60 .. -6 (the sink itself refuses anything above -6). |
| `audio_rx.max_seconds` | integer | `600` | Auto-stop of one sink run, 1 to 3600 (outside: receiver unavailable). While the switch is on, `muscad` restarts the receiver afterwards. |
| `audio_rx.nosound_file` | string | `/opt/musca/state/no-sound` | Absolute path. While this file exists the sink refuses to start and stops. Create it to silence the device at once. |
| `audio_rx.name` | string | `Futterautomat` | `snapcast` only: client name shown in Snapcast / Music Assistant. 1 to 63 characters of `A-Z a-z 0-9 . _ : -`. |

## `[led]`

The MCU status LED. See [Home Assistant](home-assistant.md) for the matching select entity.

| Key | Type | Default | Notes |
|---|---|---|---|
| `led.enabled` | bool | `true` | Send LED modes and announce the select and the diagnostic sensor. `false`: `muscad` never sends an LED frame. |
| `led.mode` | string | `status` | `status`: the online value while MQTT is connected, the offline value otherwise; `on`: always 1; `off`: always 0. Anything else is rejected at start. |
| `led.online_value` | integer | `1` | Mode sent while MQTT is connected, 0 to 3. |
| `led.offline_value` | integer | `2` | Mode sent while MQTT is down, 0 to 3. Set it equal to `online_value` to never show "offline". |
| `led.recheck_s` | integer | `10` | Seconds between comparing the MCU's echoed mode with the target; a mismatch re-sends. At least 1. |

## `[updater]`

Planned. The over-the-air updater (signed SWUpdate packages, A/B with automatic roll-back) is designed but not part of
the M1 path; setting these keys today has no effect on a normal install. See [architecture](architecture.md#updates-planned).

| Key | Type | Default | Notes |
|---|---|---|---|
| `updater.url` | string | `unset` | Device-facing update URL (`https://mirror.repohost.de/musca/<device>/<channel>/`). Only ever use an HTTPS URL you trust. |
| `updater.fetch_script` | string | `/app/bin/fetch-update.sh` | Wrapper that calls SWUpdate. Only runs on an explicit `cmd/update` MQTT message, which is one more reason to restrict who can publish. |

## Hook settings (`musca.conf`)

The boot hook has its own shell-syntax file, `/opt/musca/musca.conf`, separate from the TOML above: `NTP_SERVER`,
`SSH_PORT`, `WIFI_MTU`, `MOUNT_LAYERS`, `MAX_CRASHES`, `WINDOW`, `MAX_BOOTS`, `STABLE`, `NET_FAIL`, `STRAY_SERVICES`.
The shipped file lists the defaults, commented out. The fail-safe values (`MAX_BOOTS`, `MAX_CRASHES`, `NET_FAIL`) are
what return the device to the stock start-up; do not raise them without a reason.
