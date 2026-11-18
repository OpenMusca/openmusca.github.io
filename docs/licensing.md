# Licensing

| Path | License |
|---|---|
| everything not listed below (`agent/`, `m1/`, `tools/` scripts, docs) | MIT, see `LICENSE` |
| `br2-musca/` (Buildroot external tree) | GPL-2.0-or-later, see `br2-musca/LICENSE` |
| `tools/build/patches/` (U-Boot and kernel patches) | GPL-2.0-or-later (U-Boot) / GPL-2.0-only (Linux), as the patched project; see `tools/build/patches/LICENSE` |
| `tools/build/dts/` | GPL-2.0, derived from the vendor SDK device tree; status under review |

No vendor binaries are part of this repository or of published images. Device-specific
vendor files are pulled from the owner's own device at install time.

License audit, SBOM, the check that blocks non-allowed licenses and the GPL release checklist: `research/license-audit.md`; tools `tools/audit/sbom.sh`, `br2-sbom.py`, `vendor-scan.sh`. Third-party texts shipped in the m1 package: `tools/audit/license-texts/`.
