# Configuration reference

`muscad` reads one TOML file. On an M1 install it is `/opt/musca/muscad/config.toml`; `muscad` itself defaults to
`/opt/muscad/config.toml` (a symlink created by the boot hook) and accepts `--config <path>`. Keep the file mode at
`0600`: it can hold the MQTT password. The installer never overwrites an existing config.

Command line: `muscad [--config <path>] [--dry-run] [--help|--version]`. `--dry-run` builds and logs every feed frame
but never writes it to the UART, and implies `feed.enabled`.

Unknown keys are ignored (an old key does not stop the daemon), a wrong value for a known key does, with the key named
in the error. The one exception is `[web]`: any invalid value in it (range, cross-field, or a wrong type such as `port = "8080"`) only
disables the web UI, with a warning in the log and the reason in the web status; feeding, MQTT and the rest start normally.
What still stops `muscad`: a TOML syntax error anywhere in the file (an unparseable document, also one confined to `[web]`)
and any invalid value or type error in another section. If the merged `config.toml` + `config.web.toml` leaves `[web]`
invalid, the `[web]` of `config.toml` alone is used (warning naming the overlay); the whole overlay is then ignored.
Only `[mqtt] host` is required. A change takes effect after `muscad` restarts: `kill $(pidof muscad)`
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
| `feed_counter_file` | string | `/opt/musca/state/feed_today.json` | File that keeps the remote-feed day counter (`feed.max_portions_per_day`) and the feeds of the rolling 24 h limit across `muscad` restarts and reboots. Written atomically with mode 0600 whenever the count changes; an unreadable or corrupt file counts as "limit reached" for 24 h, never as unlimited, and is replaced at once by a "limit reached" marker so that restarts and reboots do not extend those 24 h. Delete it to reset the counter. Keep it on the flash volume, not in RAM. |
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
| `feed.max_portions_per_day` | integer | `10` | Cap on portions fed remotely (Home Assistant, MQTT) per day. The MCU's own meals do not count; there is no lock window around them. The day ends at local midnight (`tz`) while the host clock is NTP-synced, otherwise a rolling 24 h window applies. Valid 1 to 50; anything else logs a warning and uses the default (never unlimited, never everything refused). The count survives restarts and reboots (see `feed_counter_file`). A refused request is reported as `daily_limit`. Independent of the wall clock, at most twice this cap per rolling 24 h (`rolling_limit`, see [safety and recovery](safety-recovery.md#feed-safety-limits)). The current count is shown in Home Assistant as "Remote feeds today". |
| `feed.min_interval_s` | integer | `60` | Minimum spacing of two accepted remote feeds, in seconds. `0` turns the spacing off: a second feed is accepted as soon as the first one is finished (a feed still running is refused as `busy`). Valid 0 to 3600; anything else logs a warning and uses the default. The daily, hourly and rolling caps stay in force. A refused request is reported as `interval`. With `0`, a command that the broker delivers twice (MQTT QoS 1 after a reconnect) can feed twice, so keep the per-day cap low. |

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
`muscad` start unless `autostart = true`. The sink (`musca-sink`) enforces the volume cap and the no-sound file (it refuses to start and stops while that file exists). `muscad` only starts, stops and restarts it (backoff 5 s to 300 s, fixed 60 s after a refused start). An
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

## `[web]`

The local web UI (settings, status, feed buttons). Off by default. Served by `muscad` itself on the LAN; see
[web-ui.md](web-ui.md) for enabling it and its threat model. Settings changes made in the UI are written
to an overlay file (`config.web.toml`) next to this one.

| Key | Type | Default | Notes |
|---|---|---|---|
| `web.enabled` | bool | `false` | Start the web UI. |
| `web.bind` | string | `127.0.0.1` | Listen address, an IP literal. The default is loopback only; set the LAN address (or `0.0.0.0`) deliberately. |
| `web.port` | integer | `8080` | TCP port. |
| `web.password_hash` | string | `""` | Login password as `pbkdf2-sha256$<iterations>$<salt hex>$<hash hex>`. Never put a plain password here. Empty: password login cannot succeed. |
| `web.allow_test_feed` | bool | `false` | Show the "test feed" button. It goes through the normal manual-feed path and its rate limiter. |
| `web.password_login` | bool | `true` | Password login (the break-glass path). `false` is accepted only together with `[web.oidc] enabled = true`. |
| `web.public_origin` | string | `""` | The origin users type in the browser, `http(s)://host[:port]` without path (for example `https://musca.lan` behind a TLS reverse proxy). Empty: `http://<Host header>` (direct LAN access). When set it is the only `Origin` the POST CSRF check accepts, and `[web.oidc] redirect_uri` defaults to `<public_origin>/oidc/callback`. |
| `web.allowed_hosts` | array of strings | `[]` | Extra `Host` header values accepted. Always accepted: IP literals, `localhost`, the host of `public_origin`. Any other Host gets `421` (DNS-rebinding guard). Add a name used in the browser (e.g. `["musca.lan"]`); `["*"]` switches the check off. File-only, not editable in the UI. An invalid `[web]` section (this key included) disables the web UI with a warning in the log; the rest of muscad starts normally (a TOML syntax error in the file still stops it). |
| `web.oidc` | table | see below | OpenID Connect login, the `[web.oidc]` table. Needs a build with the `web-oidc` feature. |

### `[web.oidc]`

Authorization Code flow with PKCE against a confidential client. All keys default to empty/false except where noted.
`client_secret` is write-only: it never appears in the settings API or the log.

- `enabled` (bool, `false`): turn OIDC login on.
- `issuer` (string): exact issuer string, `https://host/application/o/<slug>/` for Authentik.
- `client_id`, `client_secret` (string): the confidential client's credentials.
- `auth_method` (string, `basic`): `basic` (client_secret_basic) or `post` (client_secret_post).
- `redirect_uri` (string): must equal the URI registered at the IdP; the path must be `/oidc/callback`.
- `scopes` (string, `openid profile email`): requested scopes.
- `allowed_groups`, `allowed_subs`, `allowed_emails` (list of strings): login is allowed when any entry matches; at
  least one list must be non-empty.
- `ca_file` (string): PEM bundle of the CA(s) that signed the IdP's TLS certificate.
- `spki_pin_sha256` (string): optional pin of the IdP's public key, SHA-256 of the leaf's SubjectPublicKeyInfo DER,
  as 64 hex characters or `sha256//<base64>`. A certificate renewal with the same key keeps working. Without
  `ca_file` it is the only trust anchor (self-signed IdP certificate).
- `cert_pin_sha256` (string): removed; kept only so an old config gets a clear error instead of being ignored.

## `[camera]`

Periodic or on-demand JPEG snapshot published over MQTT. Off by default.

| Key | Type | Default | Notes |
|---|---|---|---|
| `camera.enabled` | bool | `false` | Enable snapshots. |
| `camera.command` | list of strings | `[]` | Capture command (argv, no shell). Runs as a child process in its own process group and is killed on timeout. It writes one JPEG to stdout, or to `output_file` when that is set. |
| `camera.output_file` | string | `unset` | Read the JPEG from this file after the command exited 0 (removed before each run) instead of from stdout. |
| `camera.timeout_s` | integer | `20` | Kill the capture after this many seconds, 1 to 120. |
| `camera.min_interval_s` | integer | `10` | Minimum seconds between two capture starts, whatever asked (button, automation, periodic). 1 to 3600. |
| `camera.interval_s` | integer | `0` | Periodic snapshot every N seconds; 0 = only on demand. Values 1 to 59 are raised to 60. |
| `camera.max_bytes` | integer | `524288` | JPEGs larger than this are rejected (MQTT message size, broker limits). 16 KiB to 4 MiB. |
| `camera.retain` | bool | `true` | Publish the image retained, so Home Assistant shows the last snapshot after a restart. |
| `camera.daynight` | table | see below | Day/night control, the `[camera.daynight]` table. |

An invalid `[camera]` or `[camera.daynight]` section does not stop muscad: it logs one warning and runs with the camera
off and day/night manual, everything else of the config stays.

### `[camera.daynight]`

IR-cut coil and IR LED control, independent of the snapshot. Default off: nothing is exported or written and there is no
Home Assistant entity. Limits are enforced again in `musca-camera`.

- `enabled` (bool, `false`): turn day/night control on.
- `swap` (bool, `false`): exchange the day and night coil lines. The default mapping is of low confidence; check on the
  device which one gives the right filter position.
- `day_gpio` (integer, `50`), `night_gpio` (integer, `53`): coil lines. Each must be 50 or 53, and they must differ.
- `pulse_ms` (integer, `200`): length of the one coil pulse, 1 to 250.
- `min_interval_s` (integer, `10`): minimum seconds between two switches, 1 to 3600.
- `pwm_channel` (integer, `1`): PWM channel of the IR LED; only 1 is accepted.
- `ir_duty_pct` (integer, `0`): IR LED duty in percent while in night mode, 0 to 70. 0 = the LED is never on.
- `mode` (string, `"manual"`): `"auto"` switches day and night by itself from the scene brightness of the periodic
  snapshot, and adds the option `auto` to the Home Assistant select. Needs `camera.enabled = true`, a capture command
  that prints the brightness line (`musca-cam`, with auto exposure) and `camera.interval_s` > 0. Picking `day` or
  `night` in Home Assistant leaves auto until you pick `auto` again.
- `to_night_below` (number, `0.05`), `to_day_above` (number, `0.5`): brightness (`lum`, shown in the retained state
  `state/daynight`) below which it goes to night, and above which it goes to day. `to_day_above` must be greater.
  The defaults are a guess: look at `lum` at dusk and dawn and set both. With the filter out and the IR LED on, the same
  scene is much brighter, so keep `to_day_above` well above the night reading.
- `dwell_samples` (integer, `3`, 1 to 100), `dwell_s` (integer, `120`, 120 to 86400): a switch needs this many
  consecutive new snapshots on the same side of a threshold, spanning at least this many seconds. A `dwell_s` below 120
  is replaced by 120 with a warning in the log (auto mode only). Only the periodic snapshots count, never a press of
  the snapshot button.
- `max_sample_age_s` (integer, `900`, 10 to 86400): a brightness value older than this is ignored (no switch). Must be
  larger than `camera.interval_s` (at least 60) plus `camera.timeout_s`.

After a failed switch auto pauses for five minutes (or `min_interval_s` if longer). Switches always obey `min_interval_s`, and
two switches that auto starts are always at least 10 minutes apart, whatever the settings (a pending switch waits).

## `[updater]`

The over-the-air updater (signed Ed25519 bundles, A/B with automatic roll-back). The fetch and verify half is built;
the real install target is not (`install_target = none` verifies only), so it is not part of the M1 path and setting
these keys changes nothing on a normal install. See [architecture](architecture.md#updates-planned).

| Key | Type | Default | Notes |
|---|---|---|---|
| `updater.url` | string | `unset` | Device-facing update URL (`https://mirror.repohost.de/musca/<device>/<channel>/`). Only ever use an HTTPS URL you trust. |
| `updater.fetch_script` | string | empty | Command run in the background on an explicit `cmd/update` MQTT message (one more reason to restrict who can publish). Empty = this muscad's own `muscad bundle-fetch`: it downloads the signed bundle (`manifest`, `manifest.sig`, payloads) from `updater.url`, verifies the Ed25519 signature, the anti-rollback counter and every sha256 before it installs anything. A path overrides the command (tests). The URL always comes from this file, never from MQTT. |
| `updater.allow_http` | bool | `false` | Accept a plain `http://` `updater.url`. The signature protects the bundle either way; TLS only adds confidentiality. |
| `updater.ca_file` | string | empty | PEM bundle anchoring an `https://` `updater.url` (no built-in root store). `https` needs a muscad built with the `web-oidc` feature; without it `https` URLs are refused with a clear message. |
| `updater.spki_pin_sha256` | string | empty | Alternative trust anchor: SHA-256 of the server certificate's SubjectPublicKeyInfo (same syntax as the OIDC pin). |
| `updater.install_target` | string | `none` | The OTA enable switch. `none` (default): `bundle-fetch` verifies manifest, signature and payload hashes into staging, then refuses (exit 80); nothing outside staging is touched. `mpkg`: install the m-package bundle into `/opt/musca` (P3b.0): per file with a journal, a backup in the `rollout-m.sh` format (so `rollout-m.sh --rollback mNN` undoes it), restart of muscad only, then a trial that muscad commits and the boot hook rolls back. Only `bin/muscad`, `bin/musca-sink`, `bin/musca-snap`, `bin/musca-cam` and `share/**` may change; anything else (boot hook, supervisor, Wi-Fi/firewall scripts, removals) is refused with "host rollout needed". Needs a device that was rolled out with the OTA bootstrap package and rebooted once. The retired `appimg-legacy` and any other value count as `none`. |
| `updater.staging_dir` | string | `/tmp/musca-ota` | Staging directory, deleted recursively and recreated for every fetch, removed afterwards. Rule: absolute, plain components (no `..`), below `/tmp` or `/run` (tmpfs), last component starts with `musca`, and never equal to, a parent of, or inside the state dir, `/opt`, `/opt/musca` or the marker dir; otherwise the fetch fails before anything is deleted. |
| `updater.commit_after_s` | integer | `300` | Not used since the m-package OTA (P3b.0): the commit waits for the boot hook's `trial-stable` witness (the new muscad ran `STABLE` s with an IPv4 address) and an MCU round trip instead. Still accepted so existing configs load. |
| `updater.meal_guard` | table | see below | Meal guard, the `[updater.meal_guard]` table. |

### `[updater.meal_guard]`

No install and no reboot near a meal. On by default.

- `enabled` (bool, `true`): `false` turns every check off (logged at start-up).
- `meals` (list of `"HH:MM"`, `["12:00", "13:30"]`): local meal times.
- `include_schedule` (bool, `true`): also guard the enabled entries of muscad's own `schedule.json`.
- `margin_min` (integer, `40`): minutes on each side of a meal.
- `install_budget_min` (integer, `10`): expected length of a fetch and install; an install is refused when a window
  starts within this many minutes. 0 = only the window itself.

## Hook settings (`musca.conf`)

The boot hook has its own shell-syntax file, `/opt/musca/musca.conf`, separate from the TOML above: `NTP_SERVER`,
`SSH_PORT`, `WIFI_MTU`, `MOUNT_LAYERS`, `MAX_CRASHES`, `WINDOW`, `MAX_BOOTS`, `STABLE`, `NET_FAIL`, `STRAY_SERVICES`.
The shipped file lists the defaults, commented out. The fail-safe values (`MAX_BOOTS`, `MAX_CRASHES`, `NET_FAIL`) are
what return the device to the stock start-up; do not raise them without a reason.
