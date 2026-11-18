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
| `tools/ci/` | the test entry point and the hygiene guard |

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

## Tests

```
tools/ci/run-all.sh              # fast set
tools/ci/run-all.sh --full       # plus reproducibility double builds and the history scan
tools/ci/run-all.sh --no-docker  # only suites that need no Docker; the rest show as SKIP, not ok
```

The fast set runs: the hygiene guard on tracked files, its self test, Python unit tests, the firmware-extract and
audit tests, the documentation checks, the M1 shell tests (shellcheck and a busybox dry run in a fake `/opt`), `cargo
test`, `clippy` and a secret scan. It prints a table and exits non-zero on any failure.

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
