# Radio and multi-room audio (experimental)

Since release m19 `muscad` can run an optional audio receiver: your Home Assistant (HA) host plays internet radio or
any other source, and the feeder's speaker is one more room in a Snapcast multi-room setup (or a plain RTP target).
The feeder never fetches a stream itself and never talks to the internet; it only connects to a machine on your own
network.

The receiver is **off by default**, announces no entity until you enable it, and has not been long-term tested on the
device. Treat it as experimental. Keys are listed in [Configuration](configuration.md#audio_rx).

```text
radio station --> Music Assistant / snapserver (HA host) --TCP 1704--> musca-snap --> musca-sink --> speaker
```

## 1. Enable it

The m19 package ships `musca-snap` and `musca-sink` in `/opt/musca/bin`. Edit `/opt/musca/muscad/config.toml`
(keep mode `0600`, copy it to `config.toml.bak` first).

There are two modes: `snapcast` (recommended, works with Music Assistant) and `rtp` (one sender pushes UDP/RTP
packets to the feeder, for example PipeWire). There is no separate "tcp" mode in the configuration.

### Snapcast mode

```toml
[audio_rx]
mode = "snapcast"
host = "<snapserver-IPv4>"  # replace: IPv4 of the snapserver; private LAN address, no host name
# port = 1704              # default; the snapserver stream port
# name = "Futterautomat"   # client name shown in Snapcast / Music Assistant
# volume_db = -20.0        # default, see "Volume"
# max_seconds = 600        # default, see "Safety"
# autostart = false        # default: the HA switch turns it on
```

`host` is the machine that runs the snapserver: the HA host when you use Music Assistant's built-in snapserver or the
"Snapcast Server" add-on, or any other LAN host with a standalone `snapserver`. It must be an IPv4 literal in a private
range (RFC 1918), loopback or link-local. A host name or a public address makes the receiver
unavailable.

### RTP mode

```toml
[audio_rx]
mode = "rtp"
bind = "<feeder-IPv4>"     # replace: the FEEDER's own IPv4 address, never 0.0.0.0
port = 46000               # UDP port to listen on (default 5004)
codec = "l16"              # or "opus"
```

The stream must be 48 kHz stereo: L16 (big-endian 16 bit, as PipeWire's `module-rtp-sink` sends it) or Opus per RFC
7587. Sender setup (PipeWire config, ffmpeg and GStreamer one-liners) is in `research/radio-ha.md` in the source tree;
set the sender's destination to the feeder's IP and `port`. Use a fixed DHCP lease for the feeder so `bind` stays valid.

### Restart

`muscad` reads the config only at start:

```sh
kill $(pidof muscad)       # the supervisor respawns it
```

Check the log (section 4) for `audio_rx: snapcast available, receiver off`. After that the HA switch **Audio receiver**
(config category of the feeder device) exists and is OFF; flipping the switch ON starts the receiver and OFF stops it
within a few seconds. No further restart is needed for switching. Without `autostart = true` the switch is OFF after
every `muscad` restart (and after every reboot), so a power cut never leaves the speaker armed. To undo everything set
`mode = "off"` and restart `muscad`; the switch disappears.

## 2. Home Assistant side

1. Install **Music Assistant** (add-on or container) and add its **Snapcast** player provider. Either let Music Assistant
   run its built-in snapserver (then `host` is the HA host's IP) or point it at a standalone snapserver.
2. Make sure the stream the feeder gets is **PCM or Opus, 48 kHz, 16 bit, stereo** (section 4). Standalone snapserver:
   `codec = pcm` or `opus` and `sampleformat = 48000:16:2` in `snapserver.conf`; `buffer` up to 3000 ms (1000 default).
3. In HA turn the switch **Audio receiver** ON. The feeder connects and shows up as a client named like `audio_rx.name`
   (default "Futterautomat") and as a Music Assistant player.
4. Pick radio in Music Assistant: its radio providers (TuneIn, Radio Browser) list stations; play one on the
   "Futterautomat" player or on a group that contains it. Music Assistant fetches the stream, so the internet access
   stays on the HA host.
5. A client that is connected but idle costs nothing: the speaker is only opened when the first audio arrives and is
   closed again 3 s after the last chunk.

### Volume

There are three layers and they multiply (all attenuate, none can amplify):

| Layer | Where | Notes |
|---|---|---|
| Music Assistant / Snapcast volume and mute | MA player or Snapcast client volume | Sent by the server and applied in `musca-snap`; never above unity. Use this for day-to-day volume. |
| `audio_rx.volume_db` | `config.toml` | Fixed attenuation in the sink, default -20 dB, clamped to -60 .. -6 dB. Raising it needs a `muscad` restart. -6 dB is the hard ceiling (the sink itself refuses louder). |
| HA "Speaker volume" entity (m15) | `[sound]`, `cmd/sound_volume` | Only scales the call/chime/beep clips. It does **not** change radio volume. |

Start with the default -20 dB and set the loudness with the Music Assistant slider.

## 3. Safety

- **No-sound file.** While `/opt/musca/state/no-sound` exists (path: `audio_rx.nosound_file`) the sink refuses and stops.
  Silence the device at once with `touch /opt/musca/state/no-sound`; `rm` it to allow sound again.
- **Time limit.** One sink run ends after `max_seconds` (default 600, maximum 3600); while the switch is ON the receiver
  restarts about 5 s later, so the limit bounds a run, not a day. Switch OFF when you are done.
- **LAN only.** `host` must be private/loopback/link-local IPv4; `bind` must be the feeder's own concrete address. The
  feeder opens one outgoing connection (snapcast) or one UDP socket (rtp) and nothing else.
- **No speaker without the sink.** All paths use `musca-sink`, so volume cap and no-sound file always apply.
  A `muscad` crash takes the receiver with it. The MCU keeps feeding on its own schedule either way.

## 4. Troubleshooting

Logs: `/opt/musca/state/log/` (`log.0` is the current `muscad` log), and `/tmp/musca/supervisor.log` in RAM. Lines
start with `audio_rx:`:

| Log line | Meaning |
|---|---|
| `audio_rx: snapcast available, receiver off ...` | config valid, waiting for the switch |
| `audio_rx: started snapcast (pid N)` / `stopping snapcast` | switch ON / OFF |
| `audio_rx: snapcast ended (...) after N s, restart in M s` | exited; restart waits 5 s, doubling up to 300 s after short runs; exit 3 (sink refused) waits 60 s |
| `audio_rx.host must be ...`, `audio_rx.mode ... is not off, snapcast or rtp`, `...must be 1..3600` | invalid config: receiver unavailable, no switch; `muscad` otherwise runs normally |
| `cannot start .../musca-snap` | `bin_dir` wrong or the package has no audio binaries (`ls /opt/musca/bin`) |

Common failures:

- **No switch in HA**: `mode` is `off`, the config is invalid (see the warning in the log), the binaries are missing, or
  `muscad` was not restarted after the edit.
- **Connects, but silence or "unsupported codec"**: `musca-snap` accepts only `pcm` (16 bit) and `opus`, stereo, 48 kHz
  (PCM also 32 kHz). **FLAC is refused**, as are 44.1 kHz streams; there is no resampling on the feeder. Fix the stream on
  the server (`codec`, `sampleformat=48000:16:2`). If Music Assistant's built-in snapserver offers no such setting, run a
  standalone snapserver (`tools/audio/snapserver/` in the source tree has a pinned Docker setup) and point `host` at it;
  this combination is not verified on the device yet. `buffer` above 3000 ms is refused.
- **Client never appears**: check from another LAN host that the snapserver listens on `host:1704` and that no firewall
  or VLAN blocks the feeder. The feeder connects to the server, not the other way round, so the server host must accept
  inbound TCP 1704 (and 1705 for the HA Snapcast integration). On Windows with WSL2 in NAT mode a snapserver in WSL is not
  reachable from the LAN; see the "LAN reachability" section in `tools/audio/snapserver/README.md` (mirrored networking or
  a portproxy), and use the Windows LAN IP as `host`. A lost server is retried every 5 s without a restart loop.
- **rtp: nothing plays**: `bind` is not the feeder's IP, port mismatch, or a sender format other than 48 kHz stereo L16
  (or Opus with `codec = "opus"`). Check with `tcpdump -n udp port <port>` on the sender host.
- **Stops by itself**: the no-sound file or `max_seconds`; see section 3.
- **Gaps on Wi-Fi**: raise the snapserver `buffer` to 1500-2000 ms, prefer Opus (64 to 128 kbit/s) over PCM (1.5 Mbit/s).
