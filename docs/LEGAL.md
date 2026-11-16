# Legal and release policy — QA Sentinels

This document is an inventory and release checklist, not legal advice.

## Required artifacts

- `LICENSE` — full MIT text.
- `THIRD-PARTY-NOTICES.md` — Python, SQLite, libbpf, and local toolchain notes.
- `legal/manifest.json` — machine-readable compliance register.
- `debian/copyright` — Debian copyright and license stanzas.
- `docs/PRIVACY.md` — local data handling and retention.
- `CONTRIBUTING.md` — inbound licensing and DCO.
- `SECURITY.md` — private vulnerability reporting.

## Before every release

1. Run the test suite and `./bin/qa legal --check`.
2. Update `lastReviewed`, `reviewedVersion`, and `reviewedComponents`.
3. Confirm the Debian package installs `LICENSE`, `THIRD-PARTY-NOTICES.md`,
   `legal/manifest.json`, and the updated copyright file.
4. Confirm `toolchain/` remains untracked and excluded from Debian source.
5. Review the trademark/affiliation notice for the QA name.
6. Run the third-party scanner against the repository and review blocked or
   unknown findings.

## Distribution notes

- Python and SQLite are host runtime dependencies, not bundled.
- libbpf is optional and built per host; the Debian package does not ship the
  eBPF tracer.
- MIT requires the copyright and permission notice to accompany copies.
