# Musca documentation

Musca is open-source firmware for the PETKIT YumShare Dual-Hopper 2 (P592) feeder: local control, Home Assistant over
MQTT, no vendor cloud, and a way back to stock at every step. The project is early; pages mark what is **planned**.

| Page | For | Content |
|---|---|---|
| [Hardware overview](hardware.md) | everyone | what is inside the P592, with a confidence level per fact |
| [Architecture](architecture.md) | everyone | boot chain, A/B slots, the M1 hook, `muscad`, planned image and updates |
| [Install guide (M1)](install.md) | users | prerequisites, risks, backup, install, first boot, uninstall |
| [Home Assistant](home-assistant.md) | users | entities, MQTT topics and commands |
| [Configuration reference](configuration.md) | users | every `config.toml` key with default and safety notes |
| [Safety and recovery](safety-recovery.md) | users | fail-safes, what never to touch, recovery ladder, feed limits |
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
