# Home Assistant integration

Musca talks to Home Assistant (HA) over MQTT with device-based MQTT discovery (needs HA 2024.12 or newer). There is no
custom integration to install: you need an MQTT broker (for example Mosquitto) on your local network, the HA MQTT
integration pointed at it, and the broker settings in `muscad`'s [configuration](configuration.md).

This page is derived from `agent/crates/musca-p592/src/components.rs`, `agent/crates/musca-p592/src/decode.rs`, `agent/crates/musca-p592/src/device.rs`, `agent/crates/musca-p592/src/diag.rs` and
`agent/crates/musca-core/src/mqtt.rs`. `<id>` is the device id (`device_id` in the config, or derived from the Wi-Fi
MAC as `p592_<hex>`).

## Topics

| Topic | Direction | Retained | Content |
|---|---|---|---|
| `homeassistant/device/musca_<id>/config` | device to broker | yes | discovery bundle (one device, all entities) |
| `musca/<id>/availability` | device to broker | yes | `online`, or `offline` as the last will when the connection drops |
| `musca/<id>/state` | device to broker | yes | JSON `{"portions": [..], "feed_portions": n}` |
| `musca/<id>/state/link` | device to broker | yes | JSON `{"up": bool}`, MCU link health |
| `musca/<id>/state/motor` | device to broker | yes | JSON `{"running": [bool, bool], ...}` per hopper |
| `musca/<id>/state/food` | device to broker | yes | JSON `{"low": [bool\|null, bool\|null], "raw": [n, n], "tentative": true}` per hopper, from the MCU status message; `null` = not known yet |
| `musca/<id>/state/feed_result` | device to broker | no | JSON, raw result of the last feed (diagnostic) |
| `musca/<id>/state/feed_request` | device to broker | no | JSON `{"id", "status", "h1", "h2"}`: `sent`, `dry_run`, `accepted`, `refused` with a reason |
| `musca/<id>/state/led` | device to broker | yes | JSON LED target, MCU echo and manual override (only with `led.enabled`) |
| `musca/<id>/state/diag/system` | device to broker | yes | JSON `{"version", "slot", "kernel_build"}`, published once at start (only with `mcu.diag`) |
| `musca/<id>/state/diag/host` | device to broker | yes | JSON `{"synced", "uptime_s", "rssi_dbm"}`; on a change of `synced`, otherwise every 5 minutes |
| `musca/<id>/state/diag/mcu_clock` | device to broker | yes | JSON `{"offset_s"}`, MCU clock minus host clock; on each MCU clock report if it changed or 5 minutes passed |
| `musca/<id>/state/diag/feed_today` | device to broker | yes | JSON `{"portions", "limit"}`: remote-feed portions counted against today's cap, and the cap |
| `musca/<id>/state/diag/stats` | device to broker | yes | JSON system and Wi-Fi statistics, sampled every minute, published on a coarse change or every 5 minutes |
| `musca/<id>/state/diag/last_feed` | device to broker | yes | JSON `{"result", "h1", "h2", "manual", "time"}` after every `event/feed` |
| `musca/<id>/state/sound` | device to broker | yes | JSON `{"select", "volume", "last"}` (only with `sound.enabled`); `last` is `none`, `playing`, `idle`, `busy`, `rate_limited`, `muted` or `error` |
| `musca/<id>/state/mic` | device to broker | no | JSON `{"dbfs", "peak_dbfs"[, "spl_est"]}` (only with `mic.enabled`) |
| `musca/<id>/event/button_1`, `button_2` | device to broker | no | JSON `{"event_type": "press" \| "long_press" \| "release"}` |
| `musca/<id>/event/feed` | device to broker | no | JSON `{"event_type": "fed" \| "jammed" \| "skipped" \| "refused", "h1", "h2", "manual", "reason"}` |
| `musca/<id>/cmd/...` | broker to device | never | commands, see below |

Command topics are subscribed at QoS 1. A retained message on any `cmd/` topic is ignored on purpose, so a command
never fires again after a reconnect. `muscad` also republishes its state when HA announces itself on
`homeassistant/status`. After a lost broker connection (restart of the broker, network outage) `muscad` subscribes to the
command topics again on reconnect, so feeding works again without restarting it.

## Entities

| Entity | Platform | Needs | Notes |
|---|---|---|---|
| Button 1, Button 2 | event | always | the two buttons on the device |
| Hopper 1 motor, Hopper 2 motor | binary sensor (running) | always | tentative decoding of the MCU motor message |
| Hopper 1 food low, Hopper 2 food low | binary sensor (problem) | always | tentative: `ON` = the MCU reports "food lack" for that hopper; unknown until the first MCU status message; attributes `raw` (the two raw bytes) and `tentative`. See below |
| MCU link | binary sensor (connectivity, diagnostic) | always | `OFF` means no valid frames from the feeder MCU |
| Last feed result (raw) | sensor (diagnostic) | always | undecoded; field layout is not final |
| Feed event | event | always | `fed`, `jammed`, `skipped`, `refused` |
| Feed now | button | `feed.enabled` | feeds with the stored portion counts |
| Feed hopper 1, Feed hopper 2 | button | `feed.enabled` | feeds the shared "Feed portions" count from one hopper |
| Feed portions | number, 1 to 4 | `feed.enabled` | portion count used by the buttons |
| Play call sound | button | `sound.enabled`, speaker present | plays the selected clip once |
| Call sound | select (config) | same | `call`, `chime`, `beep` |
| Speaker volume | number 0 to 100 %, step 5 (config) | same | scales the clips; 0 = mute |
| Sound level, Sound peak | sensors (dBFS; peak is diagnostic) | `mic.enabled`, microphone present | see [Microphone level](#microphone-level-optional) |
| Status LED | select (config) | `led.enabled` | `auto`, `off`, `online`, `offline`, `update` |
| Status LED mode (MCU) | sensor (diagnostic) | `led.enabled` | the mode the MCU reports back |

### Diagnostics

With `mcu.diag = true` (the default) these read-only entities are announced as well, all in the diagnostic category.
Nothing here sends a frame to the MCU: the values come from what `muscad` already knows plus a few `/proc` reads (boot
slot and kernel build once at start, uptime and Wi-Fi signal at most every 5 minutes). Set `mcu.diag = false` to drop
them. The ones marked "off" are created disabled; enable them in the entity settings in HA.

| Entity | Platform | Default | Source |
|---|---|---|---|
| Host time synced | binary sensor | on | the NTP verdict (kernel flag plus the ntpd stamp file); unknown until a verdict exists |
| MCU clock offset | sensor, seconds | off | MCU clock report minus host clock; unknown while the host clock is not valid |
| Boot slot | sensor | on | `A` or `B` from `kernel=a`/`kernel=b` on `/proc/cmdline`, `unknown` otherwise |
| Kernel build | sensor | off | `uname -v` (`/proc/sys/kernel/version`) |
| muscad version | sensor | on | the running binary |
| Host uptime | sensor, seconds | off | `/proc/uptime` |
| Wi-Fi signal | sensor, dBm | off | signal level from `/proc/net/wireless`; unknown when the driver does not report one |
| Last feed | sensor | on | result of the last `event/feed` (`fed`, `jammed`, `skipped`, `refused`), with `h1`, `h2`, `manual` as attributes |
| Last feed time | sensor, timestamp | on | host time of that event; unknown while the host clock is not plausible (before 2026) |
| Remote feeds today | sensor, portions | on | portions fed remotely (HA, MQTT) today, counted against `feed.max_portions_per_day`; the cap is an attribute. Persistent: kept across restarts and reboots. Needs no `feed.enabled` to be announced |

System statistics (from `state/diag/stats`, one sample a minute): SoC temperature, CPU usage, 1 min load (off), memory
used and available (off), storage used, free and size (off), flash bad blocks and max erase count (off), Wi-Fi
signal, TX rate (off), RX rate (off) and frequency (off), Wi-Fi download and upload, received and sent bytes (off),
`muscad` memory (off), MQTT reconnects (off) and NTP offset (off). The Wi-Fi values come from nl80211 (with
`/proc/net/wireless` as fallback). While `wlan0` is not registered yet at boot, the sensors stay unknown and the lookup
is retried every sample (a log line `wifi stats unavailable` right after start is normal and clears by itself).

The existing "MCU link" and "Last feed result (raw)" diagnostics are unchanged. The topic names of everything above
this section are unchanged, and availability still comes from `musca/<id>/availability`.

### Food low (tentative)

The MCU status message carries one byte per hopper. `muscad` reads `2` as "enough food" (`OFF`), `0` and `1` as "food
low" (`ON`; the difference between the two is unknown) and every other value, including `0xFF` ("not known yet"), as
unknown. The hardware gives only this flag, so there is no level sensor. The `raw` attribute shows the bytes as sent.

The mapping is tentative. "Enough" (`2`) has been seen on a half-full storage; "low" (`0`/`1`) has not been observed
on a nearly empty one yet. If both hoppers share one storage without a divider, they read the same, so use either one
(or both) for a single "refill" alert. The sensor does not change feeding or the feed limits. The MCU sends the status
on events (button, motor, LED change), not periodically, so after a restart it stays unknown until the next event;
`muscad` republishes an unchanged value every 5 minutes.

### Speaker sounds (optional)

Off by default; set `[sound] enabled = true` (see [Configuration](configuration.md#sound)). The entities appear only
when the device has a sound card, which needs the own kernel; on the stock kernel nothing is announced.

- Play call sound plays the selected clip (`call`, `chime`, `beep`; short built-in tone sequences, 3 s at most).
- Rate limit: one clip at a time and at least 10 s apart. A refused press only updates `last` in `state/sound`
  (`busy`, `rate_limited`).
- Speaker volume is linear in dB between a quiet floor and the configured ceiling (`sound.max_level_dbfs`, default
  -20 dBFS, never above -6). 0 % mutes: a press answers `muted` and nothing plays. A change affects the next clip, not a
  running one. The value persists across restarts and reboots.

### Microphone level (optional)

Off by default (`[mic] enabled = false`): then nothing is announced and the capture device is never opened. Enabled,
`muscad` measures one second of sound every `mic.interval_s` seconds (10 by default) and publishes two numbers: RMS level
and peak, in dBFS (relative to digital full scale, not dB SPL; set `mic.spl_offset_db` after calibrating with a meter to
get an estimated dB SPL). Privacy: no audio is stored or sent anywhere, only these numbers leave the device, and the
sensors become unavailable if no new value arrives for three intervals.

### Radio and multi-room audio (experimental)

Streaming internet radio, RTP or Snapcast to the feeder speaker is under development and not part of a released
package. The device is not expected to fetch streams itself: a helper on your network (for example a Snapcast server)
would deliver them, and the speaker volume above would be shared. Treat it as experimental and do not rely on it.

Not announced yet (planned): food level estimate, battery and mains state, next meal, firmware `update`
entity, camera. The MCU keeps its own meal schedule; Musca does not change it.

## Commands

| Topic | Payload | Effect |
|---|---|---|
| `cmd/feed` | `PRESS`, or JSON `{"h1": 0..4, "h2": 0..4, "id": "<unique>"}` | manual feed; a repeated `id` is ignored (de-duplication) |
| `cmd/feed_h1`, `cmd/feed_h2` | `PRESS` | feed the "Feed portions" count from that hopper |
| `cmd/feed_portions` | integer 1 to 4 | set the count; anything else is ignored |
| `cmd/led_mode` | `auto`, `off`, `online`, `offline`, `update` (or `0` to `3`) | override the status LED until the next restart |
| `cmd/portions_h1`, `cmd/portions_h2` | integer 0 to 10 | stored default count for `cmd/feed` without a payload (not announced to HA) |
| `cmd/sound_play` | `PRESS` | play the selected clip (needs `sound.enabled`) |
| `cmd/sound_select` | `call`, `chime`, `beep` | choose the clip |
| `cmd/sound_volume` | integer 0 to 100 | speaker volume, persisted; 0 = mute |
| `cmd/update` | `INSTALL` | planned: start the signed OTA updater; not part of the M1 install |

The feed commands do nothing unless `feed.enabled = true`; a refused request is reported on `event/feed` and
`state/feed_request` with a reason (`disabled`, `bad_amount`, `no_link`, `busy`, `interval`, `daily_limit`,
`hourly_limit`, `portion_cap`, `send_error`, or `no_mcu_answer`). The limits behind these are listed in
[safety and recovery](safety-recovery.md#feed-safety-limits).

## Enabling and disabling features

Features are switched in `config.toml` (on an M1 install `/opt/musca/muscad/config.toml`; all keys in
[Configuration](configuration.md)). Do it safely:

1. Copy the file: `cp config.toml config.toml.bak`.
2. Edit it, for example `[sound] enabled = true` or `[mic] enabled = true`. Keep mode `0600`.
3. Restart the daemon: `kill $(pidof muscad)`; the supervisor respawns it. Check the log and the entities in HA.
4. To go back, restore the backup or set the key to `false` and restart; the entities then disappear from HA.

Do not change features around meal times; the MCU keeps feeding on its own schedule either way.

## Examples

Replace `p592_abc123` with your device id in the entity ids; check the real ids under Settings, Devices.

Call before the feeding time (a ring tone 2 minutes ahead):

```yaml
automation:
  - alias: "Feeder: call before meal"
    trigger:
      - platform: time
        at: "11:58:00"
    action:
      - action: button.press
        target:
          entity_id: button.p592_abc123_play_call_sound
```

Notify when food is low (either hopper; with a shared storage both change together):

```yaml
automation:
  - alias: "Feeder: food low"
    trigger:
      - platform: state
        entity_id:
          - binary_sensor.p592_abc123_hopper_1_food_low
          - binary_sensor.p592_abc123_hopper_2_food_low
        to: "on"
        for: "00:10:00"
    action:
      - action: notify.notify
        data:
          message: "Feeder: food is low, please refill."
```

Quieter at night:

```yaml
automation:
  - alias: "Feeder: night volume"
    trigger:
      - platform: time
        at: "22:00:00"
        variables: { vol: 20 }
      - platform: time
        at: "07:00:00"
        variables: { vol: 80 }
    action:
      - action: number.set_value
        target:
          entity_id: number.p592_abc123_speaker_volume
        data:
          value: "{{ vol }}"
```

Dashboard card:

```yaml
type: entities
title: Feeder
entities:
  - entity: binary_sensor.p592_abc123_hopper_1_food_low
  - entity: binary_sensor.p592_abc123_hopper_2_food_low
  - entity: select.p592_abc123_call_sound
  - entity: number.p592_abc123_speaker_volume
  - entity: button.p592_abc123_play_call_sound
  - entity: sensor.p592_abc123_sound_level
```

## Securing MQTT

`muscad` has no access control of its own: whoever can publish to `musca/<id>/cmd/#` can make the feeder dispense food
(within the fixed limits in [safety and recovery](safety-recovery.md#feed-safety-limits)), and whoever can write the
retained discovery or state topics can mislead Home Assistant. MQTT on port 1883 is plain text; `muscad` has no TLS
support yet. Protect the broker instead:

- No anonymous access. Give Home Assistant and `muscad` separate accounts with strong, unique passwords.
- Broker ACL, least privilege. The Home Assistant user may write `musca/+/cmd/#` and `homeassistant/status` and read
  `musca/#` and `homeassistant/#`. The `muscad` user may write only `musca/<id>/#` (not `cmd/#`) and
  `homeassistant/device/<id>/config`, and read only `musca/<id>/cmd/#` and `homeassistant/status`. Nothing else.
- Keep the broker on a trusted segment (isolated VLAN or an IoT network with no route from untrusted hosts). Do not
  expose port 1883 to the internet. If the broker must be reached across an untrusted link, terminate TLS in front of it
  and keep the feeder on the plain local listener, since the agent cannot speak TLS.
- Leave `feed.enabled = false` until the ACL is in place, and test a feed with `feed.dry_run = true` first.

Mosquitto example (`acl_file`, replace the user names and `<id>`):

```
user homeassistant
topic readwrite homeassistant/#
topic read musca/#
topic write musca/+/cmd/#

user muscad
topic write musca/<id>/#
topic read musca/<id>/cmd/#
topic write homeassistant/device/<id>/config
topic read homeassistant/status
```

Mosquitto evaluates `readwrite`/`write` for the account that publishes; the `muscad` account's own `write
musca/<id>/#` also covers `cmd/#`, so add an explicit `deny` where your broker supports it, or publish the `cmd/` topics
only through the Home Assistant account. Test the ACL with a client that must be refused before trusting it. See also
[SECURITY.md](security.md).
