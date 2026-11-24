# Musca documentation

Musca is open-source firmware for the PETKIT YumShare Dual-Hopper 2 (P592) feeder: local control, Home Assistant over
MQTT, no vendor cloud, and a way back to stock at every step. The project is early; pages mark what is **planned**.

| Page | For | Content |
|---|---|---|
| [Hardware overview](hardware.md) | everyone | what is inside the P592, with a confidence level per fact |
| [Architecture](architecture.md) | everyone | boot chain, A/B slots, the M1 hook, `muscad`, planned image and updates |
| [Quickstart](quickstart.md) | users | one page from stock to Home Assistant |
| [Compatibility](compatibility.md) | users | supported model and firmware, what v0.1 does and does not include |
| [Install guide](install.md) | users | installer flow (coming) and the manual path: risks, backup, install, first boot, updating |
| [Web UI](web-ui.md) | users | enable, log in, what it can do, security notes |
| [Troubleshooting](troubleshooting.md) | users | symptom, cause, fix; "food did not come" |
| [FAQ](faq.md) | users | short answers, with pointers to the details |
| [Uninstall](uninstall.md) | users | back to stock, with checks |
| [Home Assistant](home-assistant.md) | users | entities, MQTT topics and commands |
| [Configuration reference](configuration.md) | users | every `config.toml` key with default and safety notes |
| [Safety and recovery](safety-recovery.md) | users | fail-safes, what never to touch, recovery ladder, feed limits |
| [Privacy](privacy.md) | users | what data stays on the device and what goes where |
| [Development](development.md) | contributors | build, tests, clean-room rules |
| [Legal](legal.md) | everyone | licences, GPL source offer, no vendor blobs, your own firmware |

Also see [SECURITY.md](security.md) for the threat model and how to report a problem,
[CONTRIBUTING.md](contributing.md), and [LICENSING.md](licensing.md).

## Conventions

- Placeholders: `<id>` is your device id, `<device-ip>` your feeder's address; examples use documentation addresses
  such as `192.0.2.1`. Never paste your own addresses, serial numbers or credentials into an issue.
- **works** means seen working on a real device; **experimental** means built or partly tested; **planned** means designed
  only.
- The documentation checks (`tools/docs/`) run in the fast test set: [development](development.md#documentation-checks).
