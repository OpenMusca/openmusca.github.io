# Security policy

Musca controls a device that dispenses food and sits on your home network, so security problems matter beyond the
usual. Thank you for reporting them responsibly.

## Reporting a vulnerability

Do **not** open a public issue for a security problem. Use GitHub's private vulnerability reporting ("Security" tab of
the repository, "Report a vulnerability") once the repository is published. Include what you found, the version
(`muscad --version` and the package checksum), how to reproduce it, and what you think the impact is. Do not include
your Wi-Fi credentials, MQTT password, flash dumps or device identifiers; redact them.

What to expect: an acknowledgement within a week, a fix or a mitigation plan as soon as it is understood, and credit in
the release notes if you want it. Please give us reasonable time to fix before you disclose. There is no bug bounty.

Supported versions: only the latest release. The project is early (pre-1.0); expect breaking changes.

## Threat model

Musca is designed for a trusted home network. It is not hardened for exposure to the internet and must never be.

| Asset | Threat | Mitigation today | Gap |
|---|---|---|---|
| Feeding commands (MQTT) | another host on the LAN publishes `cmd/feed*` | feeding is off by default; per-request, per-minute and per-hour limits in `muscad`; retained commands are ignored; duplicates ignored | MQTT is plain (no TLS) and authentication is the broker's job. Use a broker with user, password and ACLs on a segment you trust. TLS is **planned** |
| MQTT credentials | read from the device or the network | config file mode 0600; sent in clear on the LAN | no TLS yet; use a dedicated low-privilege broker account |
| Remote shell | telnet with a public root password on stock | M1 can start dropbear key-only (no passwords, no forwarding, 3 tries, idle timeout), turn telnet off and rotate the root password per boot | telnet stays on until you opt in to turn it off and the stock fallback re-enables it on purpose, so recovery is possible |
| Vendor cloud | data leaves the home | M1 never starts the vendor cloud programs | block the device's internet access at your router as well; the stock fallback would talk to the cloud |
| Software updates | a malicious or corrupt update | none automatic today: updates are manual and checksummed | signed update bundles (SWUpdate) with a project key, anti-rollback and A/B roll-back are **planned** |
| Supply chain | tampered binaries or dependencies | reproducible builds, pinned Docker images and dependencies, SBOM, licence and secret scanning in CI | a project signing key does not exist yet |
| Physical access | someone with the UART or the flash | not addressed: UART console gives root by design (it is the recovery path); the boot chain is not signed by the SoC in a way we can rely on | out of scope |

Out of scope: attacks needing physical access to the device, denial of service by flooding the local network, a
compromised broker or Home Assistant, and weaknesses of the stock vendor firmware that Musca does not touch.

## Hardening checklist for users

1. Put the feeder and the broker on a separate network segment with no inbound access from the internet.
2. Deny the device's outbound internet access except NTP; Musca needs nothing else today.
3. Use broker authentication and an ACL that allows only `muscad` to publish `musca/<id>/#` state and only Home
   Assistant to publish `musca/<id>/cmd/#`.
4. Install an SSH key, verify login after a reboot, then turn telnet off; keep UART recovery available.
5. Leave `feed.enabled` off until you need remote feeding.
6. Do not expose the device, the broker or Home Assistant to the internet without a VPN.

## Project safeguards

- No secrets, device identifiers or dumps in the repository; a hygiene guard, secret scanning (gitleaks) and a leak
  check on the public export run in CI.
- Private signing keys never live in the repository; only public keys and placeholders do.
- No vendor binaries; see [docs/legal.md](legal.md).
