# Development

Contributor rules are in [CONTRIBUTING.md](contributing.md); this page is the practical side. No build or test step
touches a device.

## Layout

| Path | Content |
|---|---|
| `agent/` | Cargo workspace: `muscad`, `supervisor` and the device crates ([architecture](architecture.md)) |
| `m1/` | M1 package: boot hook `system_init.sh`, installer, uninstaller, offline tests |
| `br2-musca/` | Buildroot external tree for an own root filesystem (planned image) |
| `tools/build/` | U-Boot, kernel and kernel-module builds in Docker from pinned sources; patches; pins in `pins.env` |
| `tools/` (top level) | `imgpack.py` (boot image container), `mcu-trace.py` (MCU capture analysis), export script |
| `tools/docs/` | documentation checks |
| `tools/ci/` | the test entry point, the hygiene guard, `docker-gc.sh`, `pins-sync.sh` |
| `.devcontainer/` | development container with the pinned toolchain |
| `lab/` | local test bench (docker compose): mosquitto, muscad against the MCU simulator, optional Home Assistant |

## Build

Everything builds in Docker with images pinned by tag and sha256 digest; do not replace a digest by a bare tag.

```
agent/scripts/build.sh test        # cargo test for the workspace
agent/scripts/build.sh clippy      # lints
agent/scripts/build.sh release     # static armv7 musl muscad + supervisor, reproducible
m1/build.sh                        # M1 package (needs the release binaries)
tools/build/build.sh all           # U-Boot + kernel images (long; experimental, see tools/build/README.md)
```

Release builds are reproducible: two builds give the same SHA-256, and `tools/ci/run-all.sh --full` checks it.
`tools/release/make-release.sh` writes SLSA-style provenance and an SBOM next to each artefact, and
`tools/release/verify-release.sh` rebuilds and compares. Details per artefact: website, `dropbear`, `muscad`/`supervisor`
and the build container images (`tools/build/build.sh image --repro`) are proven reproducible; the boot-image header can be
generated from a public description (`tools/imgpack-headers/`, `MUSCA_IMGHDR`), so no flash dump of a device is needed for
it. A manually started workflow (`.github/workflows/repro-proof.yml`) repeats the rebuild on a GitHub runner and signs
the provenance.

## Tests

```
tools/ci/run-all.sh              # fast set
tools/ci/run-all.sh --full       # plus reproducibility double builds and the history scan
tools/ci/run-all.sh --no-docker  # only suites that need no Docker; the rest show as SKIP, not ok
```

The fast set runs: the hygiene guard on tracked files, its self test, Python unit tests, the firmware-extract and
audit tests, the documentation checks, the M1 shell tests (shellcheck and a busybox dry run in a fake `/opt`), `cargo
test`, `clippy`, a `cargo deny` gate (licences, advisories, sources), the camera tools' host tests and a secret scan. It prints a table and exits non-zero on any failure.

### Development container

`.devcontainer/` (VS Code or any devcontainer client) builds one image with everything the scripts expect, so nothing is
installed on the host: Rust 1.100.0 on Debian bookworm (the image of `agent/scripts/build.sh`, same digest) with the
`armv7-unknown-linux-musleabihf` target, clippy and rustfmt, `dtc` 1.7.2 (built from the release tarball, sha256 checked;
the 4.19 SDK trees ship 1.4.6, bookworm 1.6.1), shellcheck 0.10.0 (copied from the pinned image `run-all.sh` uses),
`gcc-arm-linux-gnueabihf` 12.2 and python3. Its cargo target directory is a named volume, not `agent/target` (cargo bakes absolute paths into test binaries, and `build.sh` mounts `agent/` at another path). Inside it `cargo test --workspace --locked` runs directly. Without an IDE:
`docker build -t musca-dev .devcontainer`. `tools/ci/pins-sync.sh` (part of `run-all.sh`) fails when the pins in the build
script, the devcontainer, the lab and `run-all.sh` drift apart.

### Build containers: label, time limit, clean-up

Every `docker run` of the build and test scripts carries `--label musca.build=1` and runs under
`timeout -k 20 ${MUSCA_DOCKER_TIMEOUT:-4h}`. If a caller is killed anyway, the container can keep running; list and stop
such leftovers with

```
tools/ci/docker-gc.sh                 # dry run: running musca.build containers older than 5 h
tools/ci/docker-gc.sh --older-than 2 --apply
```

Only labeled containers are considered; images, volumes and everything else are left alone.

### Local lab

`lab/compose.yaml` is a test bench on one machine: mosquitto 2.0.22 (published on 127.0.0.1:18883 only), and `muscad`
built from `agent/` running against `mcu-sim` (one container, because the simulated UART is a pty). Optional: Home
Assistant 2026.10.4 with `--profile ha` on 127.0.0.1:18123 (add the MQTT integration once in its UI: broker `mosquitto`,
port 1883; `run-ha-scenario.sh` does it through the API). All images are pinned by digest. No device, no real broker, no real Home Assistant is involved.

```
lab/run-scenarios.sh          # 1 start, 2 remote feed, 3 MQTT outage and return, 4 silent MCU, 5 feed after the outage (resubscribe), 6 daily limit across a muscad restart; PASS/FAIL + RESULT line, details in lab/run-scenarios.log
docker compose -f lab/compose.yaml up -d --build     # keep it up for manual poking (mcu-sim control: /run/musca/sim.ctl in the musca container)
```

`lab/run-ha-scenario.sh` is a separate scenario, "HA discovery", with the real Home Assistant (pinned digest, compose profile
`ha`, first start pulls the image once) and no manual step: its own project `musca-lab-ha`, label `musca.agent=ha-check`, MQTT
port 18884, HA port 18124, whole run limited to 25 minutes (`LAB_HA_LIMIT`), torn down by a trap (`--keep` leaves it up).
`lab/ha-check.py` (stdlib only) onboards the fresh HA through its API with a throw-away account and token that exist only in
the disposable container, adds the MQTT integration by config flow, then checks via REST/WebSocket: one Musca device, all 44
entities of the golden table in `ha-check.py` (31 diagnostic ones, "Remote feeds today" among them; the 15 that start disabled
are registered without a state), plausible states, a press of "Feed now" in HA gives exactly one CMD 05 at the simulator, and
the 11th portion of the day is refused (`daily_limit`, daily limit 10). It takes about 6 minutes (60 s remote feed interval).
Changing the entity table in `components.rs` means changing the golden table in `ha-check.py`; this scenario then fails.

The scenarios reuse `musca-sim` (`mcu-sim` gained `--status` and `--ctl`); the same behaviours are covered in-process, with
more detail, by `agent/crates/musca/tests/e2e.rs`. The lab is not part of `run-all.sh`.

### Documentation checks

| Check | What it does |
|---|---|
| `python3 -I tools/docs/check-config-docs.py` | every key of `Config` in `config.rs` needs a row in [configuration.md](configuration.md), with the same default; stale rows fail too |
| `python3 -I tools/docs/check-links.py` | offline check of relative Markdown links and `#anchors` in `docs/` and the top-level documents |
| `sh tools/docs/test/run-tests.sh` | tests of both checks against fixtures (including a deliberately undocumented key) |

When you add a config key, add its row in the same commit; the check tells you if you forget.

## Writing code

- The Rust toolchain is pinned in the build image. Tests use no network and no device; the MCU link is tested with
  in-memory I/O.
- Anything that writes to the MCU or to flash is off by default and needs an explicit config switch, a dry-run mode and a
  test. Never add a feed path that bypasses the limits in [safety and recovery](safety-recovery.md#feed-safety-limits).
- Shell scripts run on a busybox target: POSIX `sh`, shellcheck-clean.
- New dependency: check its licence against `tools/audit/policy.json` (`tools/audit/test/run-tests.sh`).
- A decoded MCU payload that is not yet verified is marked tentative in code and in the docs.

## Clean-room rules

- Vendor (PETKIT, Axera, Realtek) source, headers, binaries, firmware dumps and decompiled output are never copied into
  this repository, an issue, a pull request or a document.
- Behaviour is documented from observation of your own device (captured traffic, register reads) and then implemented
  from scratch. Describe what is observed, not what the vendor code looks like.
- A contributor who has read vendor code does not write the replacement for that part. If you have, say so in the pull
  request and leave that part to someone else.
- Device-specific vendor files are pulled from the user's own device at install time, never redistributed.
- Never commit: `backup/`, `extract/`, `analysis/`, `ubifs-root/`, `build/`, logs, photos, `secrets.yaml`, flash dumps,
  private keys, device MAC addresses, serial numbers, tokens, passwords. `tools/ci/hygiene.py` enforces this and the
  optional pre-commit hook (`tools/ci/install-hooks.sh`) runs it on staged files.
- In examples, logs and bug reports use placeholders: documentation addresses (`192.0.2.0/24`), `<device-ip>`,
  `p592_abcdef`.

## Commits and pull requests

Small commits, one topic each, message `area: what and why` in English. Say what you tested and on which hardware, and
do not describe an unverified behaviour as fact. Changes that touch a device-writing path need a documented rollback.
