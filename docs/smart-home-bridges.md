# Apple Home, Google Home and Alexa (via Home Assistant)

Musca does not speak HomeKit, Matter, Google or Alexa itself. The feeder reaches these ecosystems through Home
Assistant (HA): `muscad` publishes entities by MQTT discovery (see [Home Assistant](home-assistant.md)), and an HA
bridge re-exposes a few of them. Nothing here touches the device. Steps were checked against the official pages
linked in each section (state: November 2026); menus change, so treat the linked page as authoritative.

!!! warning "Expose as little as possible"
    Anyone who can use the bridged "feed" control can dispense food. Expose only the entities in the table below,
    never config or diagnostic entities, and read [Safety](#safety).

## What to expose

| Musca entity | Expose? | Why |
|---|---|---|
| Feed now (button, needs `feed.enabled`) | yes, via a script (see below) | the only action worth having in a voice assistant |
| Feed hopper 1 / 2 (buttons) | optional | same, one hopper |
| Hopper 1 / 2 food low (binary sensor, tentative) | yes | "refill" notifications and status |
| Remote feeds today (sensor) | optional | status only |
| Feed portions (number), Call sound / Speaker volume / Status LED (config) | no | configuration, not for voice |
| Diagnostics (uptime, Wi-Fi, versions, ...) | no | noise, and hidden by default in HA |
| Buttons 1/2 and Feed event (event entities) | no | event entities are not usable as accessories in most bridges |

Create a dedicated script so the bridged entity is a plain script, not the raw MQTT button:

```yaml
script:
  feed_cat:
    alias: "Feed the cat"
    mode: single
    sequence:
      - action: button.press
        target:
          entity_id: button.p592_abc123_feed_now   # your real id
```

Replace `p592_abc123_feed_now` with the real id (Settings, Devices). `mode: single` ignores a second start while one
runs. The device enforces its own limits regardless (see [Safety](#safety)).

## 1. HomeKit Bridge (Apple Home only)

Official docs: <https://www.home-assistant.io/integrations/homekit/>.

How HA maps the types we care about:

| HA domain | In Apple Home |
|---|---|
| `button`, `script`, `input_boolean` | a **switch** (the docs list them as "all represented as switches") |
| `switch` | switch |
| `binary_sensor` | a sensor; only some device classes (`co2`, `door`, `garage_door`, `gas`, `moisture`, `motion`, `occupancy`, `opening`, `smoke`, `window`), others default to **occupancy**. The "food low" sensor (device class `problem`) therefore shows as an occupancy sensor |
| `sensor` | only temperature, humidity, air quality, CO, CO2, light |
| `camera` | camera (accessory mode; no HomeKit Secure Video) |
| `image`, `event`, `number` | not exposed as accessories |

So the MQTT `button` does appear in Apple Home, as a switch that you tap; HA turns it back off. The script above
is nicer to automate and gives a clear name. A food-low alert is better done as an HA notification, or via
an HA template binary sensor with device class `moisture`/`opening` if you want it as a Home sensor.

Setup:

1. Settings, Devices and services, Add integration, **HomeKit Bridge**. Choose the domains/entities to include
   (pick the script and the food-low sensors, not whole domains). Without a filter HA exposes everything that is not
   hidden or categorized; always set a filter.
2. Pairing: open the QR code/PIN notification in HA, in Apple Home choose Add Accessory, scan, accept the
   "uncertified accessory" warning, finish.
3. Limits: 150 accessories per bridge. Bridge mode (default) is right here. Accessory mode (one entity per
   accessory) is only required for cameras, locks, TV remotes; the camera of a later Musca release would use it.
4. Entities needing `entity_config` need a YAML-configured bridge.

## 2. Matter bridges

Matter has no pet-feeder device type in the spec revisions we checked, so a bridge shows the feeder as an outlet or
switch. Matter bridges are not certified products; Apple, Google and Alexa warn that the bridge is uncertified.
Pair the bridge to the ecosystem, never back to HA (duplicates).

**Home Assistant Matter Hub** (<https://github.com/t0bst4r/home-assistant-matter-hub>, add-on or container). Supported
types per its docs: `button`, `input_button`, `switch`, `script` become an On/Off plug-in unit (a button turns itself
off after about 3 seconds); `sensor` only temperature, humidity, illuminance; `binary_sensor` as on/off, contact,
occupancy or water-leak sensor. Event, number and select are not documented. Use a filter (domain, entity or label)
so only the script and food-low sensor are bridged.

**Matterbridge + matterbridge-hass** (<https://github.com/Luligu/matterbridge-hass>, installed from the Matterbridge
frontend; add-on users install the plugin). Maps `script` to an On/Off outlet that triggers the script and
switches back off; `switch`, `button` (as device entity) likewise; `binary_sensor` by device class to contact,
occupancy, leak, etc., generic contact sensor when there is no class; `event` to a generic switch; `select` / `input_select` to
modes. Filters: area, label, name/id white and black lists, domain lists. Do not pair the bridge back to HA.

Limits: a feed shows as an outlet ("turn all off/on" scenes in the Home app can hit it, see Safety);
there is no food-level value, only the low flag as a contact sensor; naming sometimes needs "split entity" options on
Alexa/Google. Check the current device-type table of the bridge before relying on a mapping, they change often.

## 3. Google Home and Alexa

**Easiest: Home Assistant Cloud** (Nabu Casa, paid, cloud). Settings, Home Assistant Cloud, enable Alexa or Google
Assistant, then choose entities to expose on the Voice assistants page (<https://www.home-assistant.io/cloud/>). The
page announces a rename to "Home Assistant Link" on 2 December 2026. Exposure is by default restricted to what
you pick; keep it that way.

**Manual** (free, work): HA must be reachable over HTTPS with a trusted certificate, which many people do not want.
- Google: <https://www.home-assistant.io/integrations/google_assistant/> (Google Home Developer Console project,
  HomeGraph API, service account). Types: `button` and `script` become **scenes**, `switch` / `input_boolean`
  on/off; `sensor` only temperature, humidity, air quality classes; `binary_sensor` only door, window, opening,
  moisture, smoke, CO, lock, garage door. So the food-low sensor (class `problem`) is **not** exposed to Google. Set
  `expose_by_default: false` and list each entity in `entity_config`.
- Alexa: <https://www.home-assistant.io/integrations/alexa.smart_home/> (Amazon developer account, AWS Lambda,
  account linking). `button` and `script` appear as scenes ("Alexa, turn on feed the cat"), `switch` on/off;
  `sensor` only temperature; `binary_sensor` door/window/opening (contact), motion/presence. No food-low sensor either.
  Use a filter with explicit `include_entities`.

For a low-food alert on Google/Alexa use an HA notification instead (see the example in
[Home Assistant](home-assistant.md#examples)).

## Safety

- **The device keeps the limits.** Whatever path triggers the button, `muscad` applies its own checks: a minimum
  interval, hourly and daily portion caps, portion cap, busy and link checks, and refuses over-limit requests (see
  [safety and recovery](safety-recovery.md#feed-safety-limits)). Bridges cannot raise them. Keep
  `feed.max_portions_per_day` realistic; the "Remote feeds today" sensor shows the count.
- **Avoid accidental triggers.** A feed that appears as a switch/outlet can be hit by "turn everything on", a
  Home scene, a guest or a child. Keep it out of rooms and scenes (do not add it to "All lights/switches" groups),
  give it a distinctive name, and do not put it in automations that turn on everything at a time.
  - Alexa: the skill supports voice PINs only for locks, alarm panels and garage doors, not scripts. Do not rely on a
    PIN; expose the feed only if you accept voice triggering, or use the Alexa app routine with a confirmation.
  - Google: `secure_devices_pin` covers only locks, alarm panels and garage-type covers, not scripts. Same advice.
  - If you need a real confirmation, add a guard in the script: for example require a recent "fed" check, or send an
    HA actionable notification and wait for the answer with `wait_for_trigger` before pressing the button.
- **Do not expose config entities** (portions, sound, volume, LED, diagnostics), and do not expose MQTT itself or
  the HA admin interface to a cloud service you do not need.
- A bridge needs an always-on HA host. If it is down, the feeder still follows its own MCU meal schedule.
- Protect the broker as described in [Securing MQTT](home-assistant.md#securing-mqtt).
