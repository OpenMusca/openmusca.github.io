# Web UI

A small web page served by `muscad` on your LAN: status (incl. system load, RAM, flash, temperature and kernel), settings and an optional test feed. It is
**off by default** and opening it is a deliberate step. It never replaces Home Assistant; feeding is not affected
whether the UI is on, off or broken.

## Enable

The manual way, on the device (an installer step will do this for you):

1. Back up the config: `cp -p /opt/musca/muscad/config.toml /opt/musca/muscad/config.toml.bak`.
2. Choose a password of at least 12 characters (the tool refuses fewer than 8), not used anywhere else. Make the hash on the
   device from an **SSH session or UART, never telnet** (telnet sends what you type in clear text). The password goes in on
   stdin (over SSH use `ssh -t root@<device-ip> ...` so it has a terminal), so it is not in `ps`; it is visible on screen while you type, so make sure nobody watches and clear the terminal after:
   ```
   /opt/musca/bin/muscad --hash-password       # type the password, press Enter; prints pbkdf2-sha256$...
   ```
3. Check that the config has no `[web]` section yet: `grep -n '^\[web\]' /opt/musca/muscad/config.toml` must print nothing. A reinstall
   keeps an earlier config, and a second `[web]` is invalid TOML (`muscad` then refuses to start); in that case edit the existing
   section instead. Append to `/opt/musca/muscad/config.toml` (keep the file mode `0600`; append with `cat >> file <<'EOF'` or edit
   with busybox `vi`):
   ```
   [web]
   enabled = true
   bind = "<device-ip>"          # the LAN address, never 0.0.0.0
   port = 8080
   password_hash = "pbkdf2-sha256$..."
   public_origin = "http://<device-ip>:8080"
   allow_test_feed = false
   ```
4. Restart: `kill $(pidof muscad)` (the supervisor starts it again). `/tmp/musca/supervisor.log` (RAM, lost at reboot; persistent copy
   `/opt/musca/state/log/log.0`) must say `web: listening on ...`.
   If it shows a config error: `cp -p config.toml.bak config.toml; kill $(pidof muscad)`. Restart at most three times in ten
   minutes (a fifth makes the hook fall back to stock).

This manual enable was tested on a P592 on 20.11.2026 (PASS): enable, log in, status page as described below, disable with
`config.toml` byte-identical to the backup.

Give the feeder a **DHCP reservation**: the address in `bind` and `public_origin` has to stay the same. After a reboot
the UI comes back by itself (the listener retries every 5 s until the address is there); with a changed address it retries
forever and `public_origin` no longer matches, so enable it again with the new address.
Switch it off again by removing the `[web]` section (or `enabled = false`) and restarting `muscad`. Settings saved from the UI
live in `config.web.toml` and stay in force after that; delete that file too (see below) for a complete switch-off.
Key reference: [configuration](configuration.md#web).

## Log in

Open `http://<device-ip>:8080/` from a device on the same LAN, using exactly the address in `public_origin` (a hostname
URL loads the page but every login is refused with 403). Five wrong passwords lock logins from that client address for 60 seconds (other hosts are unaffected;
60 failures from many hosts within any sliding 10-minute window lock everybody for 60 seconds); at most 4 sessions at a time (the oldest is
replaced); they end after 30 idle minutes (the cookie is renewed while you use the page) or when `muscad` restarts.
The `Host` header must be an IP, `localhost`, the host of `public_origin` or listed in `web.allowed_hosts`, else `421`.

## What it can do

| Page | Can | Cannot |
|---|---|---|
| Status | version, boot slot, uptime, MCU link, MQTT state, next feed, the last feeds | show hopper level (not estimated yet) |
| Schedule | on the P592 the schedule editor is hidden: the meal plan runs in the feeder itself (MCU) | read or change the feeder MCU's own meal plan |
| Settings | MQTT host/port/user/password, timezone, portion cap per hour, LED, sound, `public_origin` | change `[feed]`, `[mcu]`, the web login, network or firmware |
| Test feed | one deliberate feed, only if `allow_test_feed = true`, with a confirm tick box | bypass the rate limits and daily cap |

Settings are saved to an overlay file `config.web.toml` next to `config.toml`, which is never rewritten. Most changes need
a `muscad` restart (the page tells you). Delete `config.web.toml` and restart to undo all UI changes (also if a wrong `public_origin` saved in the UI makes every login return 403). If `config.web.toml` is invalid, it is ignored as a whole and `config.toml` applies; the log says so. The one exception is
the `[web]` section: if the broken overlay changes a `[web.oidc]` value (such as an `allowed_*` list or the client secret; the UI can
edit these), or a hand-edited one sets `password_hash`, `password_login`, `allowed_hosts` or `enabled` differently from `config.toml`, or
the overlay cannot be read or is not valid TOML at all, the web UI stays off, so an older OIDC setting or wider access list does not silently come back.
Fix or delete the overlay and restart. Feeding and MQTT run either way. A test feed moves
food: use it only on purpose, never to "see if it works" near a meal.

## Security notes

- **LAN only.** Do not forward the port on your router and do not put the feeder on a guest or shared network.
- **No TLS.** The password and session cookie cross the LAN in clear text, so anyone who can sniff your Wi-Fi can read
  them. For anything beyond a private LAN, put a TLS reverse proxy in front and set `public_origin` to its `https://` URL.
- One shared password, no per-user audit. It is stored salted (PBKDF2-SHA256, 120000 rounds) in `config.toml`, so keep that
  file private and the password strong.
- Someone on the LAN can keep the UI locked by failing logins; this does not stop feeding or MQTT.
  - **Behind a reverse proxy** every request arrives from the proxy's address, so all users share ONE lockout bucket:
    five wrong passwords from anybody lock logins for everybody for 60 seconds. The client address is not taken from
    `X-Forwarded-For` (it can be forged).
  - **Global lock:** 60 failures within any sliding 10-minute window (so a slow guesser below 6 per minute never
    triggers it) lock all logins for 60 seconds. Two or more LAN addresses (each is
    limited to 5 failures per lock) can reach that and keep the whole UI locked indefinitely by repeating it. This is a
    known limit (denial of service of the UI only, never of feeding, the schedule or MQTT); a restart of muscad clears
    the counters. The feeder itself is operated by its own buttons and the schedule as usual.
- **Connection limits** (fixed, not configurable): at most 4 connections at a time, one request each. The request line
  and headers must arrive within 4 s of connecting and the whole request within 10 s (else `408`); each connection is
  closed 15 s after it was accepted at the latest, response included, however slowly the client reads. A 5th
  connection gets `503 busy` at once, and `web: all 4 connection slots busy, N connection(s) refused ...` is logged at
  most once a minute. Someone on the LAN can still keep the UI busy by reconnecting all the time (UI only, never
  feeding or MQTT); that log line shows it.
- **A bad `[web]` value never stops the feeder.** If `[web]` is invalid (`bind`, `public_origin`, `allowed_hosts`,
  `password_login` without OIDC, `[web.oidc]`), muscad logs `config: [web] invalid (...); the web UI is DISABLED` and starts
  without a web listener; feeding, the MCU link and MQTT run normally. Fix `config.toml` and restart muscad.
- Never paste the password or the hash into an issue or chat.

## After a reboot or address change

Troubleshooting: [web UI unreachable](troubleshooting.md#the-web-ui-is-not-reachable).

Boot audit: the supervisor hook's listener audit (`hook.log`, 30 s after boot) treats `tcp/<port>` as expected only while
`/opt/musca/muscad/config.toml` has `[web]` with `enabled = true` (and logs `web enabled: tcp/<port> expected`); with the
web UI off, a web listener is reported as `UNEXPECTED listener`.
