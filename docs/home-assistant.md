# Home Assistant integration

Musca talks to Home Assistant (HA) over MQTT with device-based MQTT discovery (needs HA 2024.12 or newer). There is no
custom integration to install: you need an MQTT broker (for example Mosquitto) on your local network, the HA MQTT
integration pointed at it, and the broker settings in `muscad`'s [configuration](configuration.md).

This page is derived from `agent/crates/musca-p592/src/components.rs`, `agent/crates/musca-p592/src/device.rs` and
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
| `musca/<id>/state/feed_result` | device to broker | no | JSON, raw result of the last feed (diagnostic) |
| `musca/<id>/state/feed_request` | device to broker | no | JSON `{"id", "status", "h1", "h2"}`: `sent`, `dry_run`, `accepted`, `refused` with a reason |
| `musca/<id>/state/led` | device to broker | yes | JSON LED target, MCU echo and manual override (only with `led.enabled`) |
| `musca/<id>/event/button_1`, `button_2` | device to broker | no | JSON `{"event_type": "press" \| "long_press" \| "release"}` |
| `musca/<id>/event/feed` | device to broker | no | JSON `{"event_type": "fed" \| "jammed" \| "skipped" \| "refused", "h1", "h2", "manual", "reason"}` |
| `musca/<id>/cmd/...` | broker to device | never | commands, see below |

Command topics are subscribed at QoS 1. A retained message on any `cmd/` topic is ignored on purpose, so a command
never fires again after a reconnect. `muscad` also republishes its state when HA announces itself on
`homeassistant/status`.

## Entities

| Entity | Platform | Needs | Notes |
|---|---|---|---|
| Button 1, Button 2 | event | always | the two buttons on the device |
| Hopper 1 motor, Hopper 2 motor | binary sensor (running) | always | tentative decoding of the MCU motor message |
| MCU link | binary sensor (connectivity, diagnostic) | always | `OFF` means no valid frames from the feeder MCU |
| Last feed result (raw) | sensor (diagnostic) | always | undecoded; field layout is not final |
| Feed event | event | always | `fed`, `jammed`, `skipped`, `refused` |
| Feed now | button | `feed.enabled` | feeds with the stored portion counts |
| Feed hopper 1, Feed hopper 2 | button | `feed.enabled` | feeds the shared "Feed portions" count from one hopper |
| Feed portions | number, 1 to 4 | `feed.enabled` | portion count used by the buttons |
| Status LED | select (config) | `led.enabled` | `auto`, `off`, `online`, `offline`, `update` |
| Status LED mode (MCU) | sensor (diagnostic) | `led.enabled` | the mode the MCU reports back |

Not announced yet (planned): food level and "food low", battery and mains state, next meal, firmware `update`
entity, camera. The MCU keeps its own meal schedule; Musca does not change it.

## Commands

| Topic | Payload | Effect |
|---|---|---|
| `cmd/feed` | `PRESS`, or JSON `{"h1": 0..4, "h2": 0..4, "id": "<unique>"}` | manual feed; a repeated `id` is ignored (de-duplication) |
| `cmd/feed_h1`, `cmd/feed_h2` | `PRESS` | feed the "Feed portions" count from that hopper |
| `cmd/feed_portions` | integer 1 to 4 | set the count; anything else is ignored |
| `cmd/led_mode` | `auto`, `off`, `online`, `offline`, `update` (or `0` to `3`) | override the status LED until the next restart |
| `cmd/portions_h1`, `cmd/portions_h2` | integer 0 to 10 | stored default count for `cmd/feed` without a payload (not announced to HA) |
| `cmd/update` | `INSTALL` | planned: start the signed OTA updater; not part of the M1 install |

The feed commands do nothing unless `feed.enabled = true`; a refused request is reported on `event/feed` and
`state/feed_request` with a reason (`disabled`, `bad_amount`, `no_link`, `busy`, `interval`, `hourly_limit`,
`portion_cap`, `send_error`, or `no_mcu_answer`). The limits behind these are listed in
[safety and recovery](safety-recovery.md#feed-safety-limits).

## Broker hygiene

Anyone who can publish to `musca/<id>/cmd/feed*` can make the feeder dispense food, within the limits above. Put the
broker on a trusted network segment, require a user and password, and use an ACL that lets only Home Assistant and
`muscad` write to `musca/<id>/cmd/#`. See [SECURITY.md](security.md).
