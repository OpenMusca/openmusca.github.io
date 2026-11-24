# Licensing

| Path | License |
|---|---|
| everything not listed below (`agent/`, `m1/`, `tools/` scripts, docs) | MIT, see `LICENSE` |
| `br2-musca/` (Buildroot external tree) | GPL-2.0-or-later, see `br2-musca/LICENSE` |
| `tools/build/patches/` (U-Boot and kernel patches) | GPL-2.0-or-later (U-Boot) / GPL-2.0-only (Linux), as the patched project, or the SPDX line in each file; see `tools/build/patches/LICENSE` |
| `tools/build/dts-clean/` and the device-tree tests | `(GPL-2.0-or-later OR MIT)`, as in each file's SPDX line |
| OpenMusca logo (`tools/site/branding/`, published with the website and the organisation profile) | CC BY 3.0, based on "Fly" by Delapouite ([game-icons.net](https://game-icons.net/1x1/delapouite/fly.html)), modified (colours, background tile) |

Not part of the public tree: material derived from vendor sources (the decompiled stock device tree `tools/build/dts/`,
the SDK-based patch sets and two analysis helpers). Their licence status is under review; the public build uses the
clean-room replacements listed in `tools/build/README.md`.

No vendor binaries are part of this repository or of published images. Device-specific vendor files are pulled from the
owner's own device at install time.

Licence checks: `tools/audit/sbom.sh` (SBOM and the check that blocks non-allowed licences), `tools/audit/br2-sbom.py`,
`tools/audit/vendor-scan.sh`; background in [docs/legal.md](legal.md). Third-party texts shipped in the m1 package: `tools/audit/license-texts/`.

## Matter prototype build tools (20.11.2026)

The Matter prototype crate (`agent/crates/musca-matter`) uses three MPL-2.0 crates (`brownstone`, `indent_write`, `nom-supreme`) as build-time tooling only (via the `rs-matter-codegen` build-dependency). They are allowed by per-crate exceptions in that crate's own `deny.toml`; the workspace policy stays permissive-only, and a gate in `matter-proto.sh deny` fails if any of them reaches the shipped binary. See `research/license-audit.md` and `research/matter-prototype.md`.
