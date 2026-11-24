# Privacy: what data goes where

This page lists what Musca keeps on the device and what it sends out, as far as the code and the other pages show. It is
a technical description, not legal advice. Everything below is the default unless a setting says otherwise; keys are in
the [configuration reference](configuration.md).

## Short version

- No vendor cloud: Musca's own programs do not contact it, and the boot hook does not start the vendor cloud, upload or media programs
  ([architecture](architecture.md)).
- No telemetry to the project. There is no built-in "phone home".
- Data leaves the device only to places you configure or that a feature needs, listed in the table below.

## Where data goes

| Destination | What | When |
|---|---|---|
| Your MQTT broker (`mqtt.host`) | state, events, diagnostics, discovery for Home Assistant; topic list in [Home Assistant](home-assistant.md#topics) | whenever MQTT is configured; plain text, no TLS |
| An NTP server | time requests only. The hook's default is a public pool server; you can point it at a local one with `NTP_SERVER` in `/opt/musca/musca.conf` ([configuration](configuration.md#hook-settings-muscaconf)) | at boot and while running; without NTP the host clock is not synced, the MCU meal plan keeps its own clock |
| Your browser (web UI) | status and settings pages | only if you enable the web UI; LAN only, no TLS ([web UI](web-ui.md#security-notes)) |
| An OIDC identity provider | login exchange | only if you enable `[web.oidc]` ([configuration](configuration.md#web)) |
| The update server (`updater.url`) | download of signed bundles | only if you set `updater.url` and send an update command; not part of the M1 path ([configuration](configuration.md#updater)) |

## What MQTT carries

Published by `muscad` to your broker, mostly retained so Home Assistant shows the last value after a restart:

- Feeder state: portions, MCU link health, motor running, tentative food-low flag, LED, results and requests of feeds,
  button events, last feed, remote feeds today.
- Diagnostics: version, boot slot, uptime, host time sync flag, Wi-Fi signal strength (`rssi_dbm`) and system and Wi-Fi
  statistics, MCU clock offset.
- Availability (`online` / last-will `offline`) and the Home Assistant discovery bundle, which contains the device id
  (derived from the Wi-Fi MAC unless you set `device_id`).

Anyone who can read your broker can read these. The broker password is stored in clear text in `config.toml` (mode 0600).
Restrict broker access: [securing MQTT](home-assistant.md#securing-mqtt).

## Optional sensors

All of these are off by default.

- **Microphone** (`[mic] enabled`): `muscad` measures one second of sound per interval and publishes only two numbers
  (RMS level and peak, in dBFS). No audio is stored or sent anywhere
  ([Home Assistant](home-assistant.md#microphone-level-optional)).
- **Camera** (`[camera] enabled`): JPEG snapshots are published over MQTT, retained by default (`camera.retain`), so
  the last image stays on the broker until it is replaced. Set `camera.retain = false` if you do not want that
  ([configuration](configuration.md#camera)). The camera is not a supported feature yet
  ([compatibility](compatibility.md)).
- **Speaker** (`[sound]`): plays short built-in tones; nothing is recorded.

## What stays on the device

- `config.toml` (mode 0600): MQTT password in clear text, web password hash (salted PBKDF2-SHA256, never the plain
  password), OIDC settings. `client_secret` is write-only and never appears in the settings API or the log.
- `config.web.toml`: settings saved from the web UI ([web UI](web-ui.md)).
- Wi-Fi credentials in `/opt/musca/wpa_supplicant.conf` (mode 600).
- The remote-feed counter on flash, so the daily cap survives restarts.
- Logs: `/tmp/musca/` (RAM, lost at reboot) and a persistent, size-bounded copy in `/opt/musca/state/log/`. They are
  designed not to contain keys, password hashes or Wi-Fi credentials; check before you share one
  ([troubleshooting](troubleshooting.md)).

## Reducing what leaves the device

- Run the broker on your local network, with an access list ([securing MQTT](home-assistant.md#securing-mqtt)).
- Point `NTP_SERVER` at a local time source if you do not want the feeder to ask a public pool.
- Block the vendor cloud at your router while stock firmware is still around
  ([install guide](install.md#6-optional-steps-each-separately)); the stock firmware talks to it.
- Keep the web UI, microphone, camera and updater off unless you need them.
- Before sharing logs or issues, remove addresses, serial numbers, Wi-Fi names and credentials
  ([asking for help](troubleshooting.md#asking-for-help)).
