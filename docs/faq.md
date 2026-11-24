# FAQ

Short answers with a pointer to the page that has the details. For a symptom you see right now, start with
[troubleshooting](troubleshooting.md).

## Food did not come. What now?

Hand-feed first, debug afterwards. A scheduled meal is run by the feeder's own controller (the MCU) from the plan you set
in the vendor app, whether Linux is up or not; Musca does not change that plan. So a missed scheduled meal is almost never
a `muscad` problem. The checklist is in [troubleshooting](troubleshooting.md#food-did-not-come).

## Does Musca change my meal schedule?

No. The MCU keeps its own plan. Musca cannot read, change or restore it while Musca runs. To change it: uninstall, edit it
in the vendor app, install again ([compatibility](compatibility.md), [uninstall](uninstall.md)).

## Can I feed from Home Assistant?

Yes, but it is off by default (`feed.enabled = false`). Turn it on deliberately and restrict who can publish to the
command topics: see [Home Assistant](home-assistant.md#securing-mqtt). Every request passes fixed limits (per hopper,
per hour, per day, one at a time); see [feed safety limits](safety-recovery.md#feed-safety-limits). A refused request is
reported as a `refused` event with the reason.

## Why did my feed request get `refused`?

A safety limit applied: `daily_limit`, `rolling_limit`, `busy`, `no_link` or a rate limit. The
[troubleshooting table](troubleshooting.md#food-did-not-come) lists the fix per reason.

## Why is the "food low" sensor not reliable?

It is tentative: the decoding of the MCU status message is not final, and the value stays unknown until the MCU sends its
next event. See [Home Assistant](home-assistant.md#entities). Do not rely on it to know whether the hopper is empty.

## Does the feeder still talk to the vendor cloud or app?

Musca's own programs do not contact the vendor cloud, and the boot hook does not start the vendor cloud programs
([architecture](architecture.md)). After Musca takes over, the vendor app cannot control the feeder
([compatibility](compatibility.md)). You can additionally block the vendor cloud at your router
([install guide](install.md#6-optional-steps-each-separately)). What data goes where: [privacy](privacy.md).

## Does it work on battery?

Untested. Keep mains power connected and never install, update or flash on battery
([safety and recovery](safety-recovery.md#battery-operation-untested)).

## The feeder fell back to stock after a few reboots. Is it broken?

No, this is the boot guard working as designed: after repeated boots without stable uptime, repeated crashes, a missing
file or a missing network it runs the stock start-up. Read the reason in the hook log and fix the cause; see
[fail-safes](safety-recovery.md#fail-safes-in-the-m1-hook) and the
[recovery ladder](safety-recovery.md#recovery-ladder).

## Can I go back to stock?

Yes, at every step. See [uninstall](uninstall.md) and the [recovery ladder](safety-recovery.md#recovery-ladder).

## Is it safe to reboot or restart `muscad` any time?

Not near a scheduled meal: keep 40 minutes either side, on your clock and the feeder's. Restart `muscad` at most three
times in ten minutes, because a fifth restart makes the hook fall back to stock. Details in
[troubleshooting](troubleshooting.md) and the [install guide](install.md).

## Why is the web UI off, and is it safe to turn on?

It is off by default and for a private LAN only: no TLS, one shared password. Feeding is not affected whether it is on,
off or broken. See [web UI](web-ui.md#security-notes).

## The web UI does not load or rejects my login.

Usual causes are a changed DHCP address, a hostname URL instead of the exact `public_origin`, or a login lock-out of 60
seconds after five wrong passwords. See [web UI unreachable](troubleshooting.md#the-web-ui-is-not-reachable).

## Why are entities missing or duplicated in Home Assistant?

Many entities need a config switch, and a changed `device_id` creates a new device. See
[MQTT and Home Assistant](troubleshooting.md#mqtt-and-home-assistant).

## Which logs can I share when I ask for help?

The logs are designed not to hold keys, password hashes or Wi-Fi credentials, but check before you share, and remove
addresses and serial numbers. See [asking for help](troubleshooting.md#asking-for-help).

## Is this legal and does it void my warranty?

That is outside what this documentation can answer. See [legal](legal.md) for licences and what is and is not
redistributed.
