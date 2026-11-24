# Quickstart

One page from a stock P592 to Musca v0.1 with Home Assistant. Read [safety and recovery](safety-recovery.md) once before
you start: this is unofficial software for a device that feeds an animal.

**What v0.1 is:** the userland package (`muscad`, supervisor, boot hook, SSH, firewall helper) on the **stock kernel**.
Nothing is flashed, and the stock start-up comes back by itself when anything fails. No camera, no own kernel, no
update service. See [compatibility](compatibility.md).

## Before you begin

- A P592 on vendor firmware **895**, already on your Wi-Fi with its meal plan set up in the vendor app. The feeder's own
  MCU keeps running that plan; Musca does not change it. Keep a manual fallback (hand feeding) for the first days. While Musca runs you cannot view or change that meal plan.
- An MQTT broker and Home Assistant with the MQTT integration ([Home Assistant](home-assistant.md)).
- A DHCP reservation for the feeder on your router, and (recommended) its internet access blocked.
- The feeder on its power adapter. Do not install, reboot or restart `muscad` from 40 minutes before to 40 minutes after a scheduled meal, on your local clock and on the feeder's (fixed UTC+1, up to an hour apart in summer); see the [install guide](install.md#path-b-manual).

## 1. Install (about 20 minutes)

Pick one path; both end in the same state. Details in the [install guide](install.md).

- **Installer (coming with the installer):** download `musca-install` and its signature, verify, run
  `musca-install probe <device-ip>`, then `backup`, then `install`. It makes and checks the backup, installs, reboots
  and verifies for you.
- **Manual (available now; install, uninstall and web UI tested on a P592 on 20.11.2026, PASS):** back up, unpack the release package on the device, run `sh install.sh`, edit the config.

## 2. Point it at your broker

Edit `/opt/musca/muscad/config.toml` (the installer asks instead): set `mqtt.host` (and `mqtt.user`/`mqtt.pass`) and your
`tz`. Leave `[feed]` off for the first boots. Reference: [configuration](configuration.md).

## 3. Reboot and check

Reboot (not near a meal; the first boot counts toward the boot guard, the checks below clear it) and wait two minutes, then six. You are done when:

- `musca/<id>/availability` is `online` on your broker and Home Assistant shows the "Musca P592" device;
- the MCU link entity is `ON`, and pressing one of the three buttons on the feeder (the two hopper buttons, and the one next to the LED) shows up as an event (`event/button_1`, `button_2`, `button_3`, see [Home Assistant](home-assistant.md)); Musca only reports presses, no button press via Musca dispenses food;
- the feeder stays up past three minutes and `state/boots` is gone after about five.

If a check fails, use [troubleshooting](troubleshooting.md). A plain reboot or `touch /opt/musca/DISABLE` plus a reboot
returns you to stock.

## 4. Optional, one at a time

1. **Web UI** on your LAN: [web-ui.md](web-ui.md).
2. **SSH key-only, telnet off**, after proving key login survives a reboot ([install guide](install.md#6-optional-steps-each-separately)).
3. **Remote feeding** (off by default): dry run first, then one portion, [install guide](install.md#6-optional-steps-each-separately).

## Going back

[Uninstall](uninstall.md) restores the stock start-up (`sh uninstall.sh` from the package, or `rm /opt/system_init.sh`, then a reboot).
