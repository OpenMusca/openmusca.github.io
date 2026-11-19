# Contributing

## Run the tests

```
tools/ci/run-all.sh              # fast set: hygiene guard, Python/shell unit tests, m1 dry run, cargo test + clippy
tools/ci/run-all.sh --full       # plus reproducibility double builds (agent release, m1 package) and the history scan
tools/ci/run-all.sh --no-docker  # only the suites that need no Docker (Docker suites show as SKIP, not ok)
```

The script prints a table (suite, result, seconds) and exits non-zero if any suite fails. Single suites:
`agent/scripts/build.sh test|clippy`, `m1/test/run-tests.sh`, `tools/audit/test/run-tests.sh`,
`tools/ci/test/run-tests.sh`, `tools/release/test/run-tests.sh` (provenance/verify selftest; release tooling: `tools/release/README.md`). Tests never touch the device or the network of the
device. Docker images are pinned by tag and sha256 digest; do not replace a digest by a bare tag.

## Hygiene rules

These never go into Git (and never into a public export): `backup/`, `extract/`, `analysis/`, `ubifs-root/`,
`build/`, `logs/`, `photos/`, `secrets.yaml`, flash dumps (`*.bin`, `*.img`), private keys, `root.hash`, device
MAC addresses, tokens and passwords. `tools/ci/hygiene.py` enforces this:

```
tools/ci/install-hooks.sh                # opt in: pre-commit hook (staged files)
python3 tools/ci/hygiene.py tracked      # all tracked files (also part of run-all.sh)
python3 tools/ci/hygiene.py history      # read-only scan of every blob on every ref (also in --full)
```

A finding prints path, line and rule name, never the matching text. A harmless false positive (for example a test
that builds a fake token) is marked with `hygiene:allow` in a comment on that line. If a secret was committed,
do not fix it by pushing a revert: tell the owner, the history has to be rewritten and the secret rotated.

## Commits

Small commits, one topic each, message in English: `area: what and why`. Every commit made with an AI assistant
carries the trailer `Assisted-by: Claude Code (claude-opus-5-5)` (name the model that actually did the work).
Do not commit build outputs or anything from the list above.

## Clean-room rule for vendor code

Vendor (PETKIT, Axera, Realtek) source, headers and binaries are not copied into this repository. Behaviour is
documented from observation and rewritten from scratch; where a vendor file is needed it is pulled from the
owner's own device at install time. Whoever reads vendor code does not write the replacement for it. Details,
rules and process: [docs/development.md](development.md#clean-room-rules); licenses: [LICENSING.md](licensing.md).
