# OpenTimestamps Anchors

Cryptographic priority evidence anchored to the Bitcoin blockchain via [OpenTimestamps](https://opentimestamps.org).

## What these files prove

Each `.ots` file proves that the corresponding source file existed in this exact form at or before the timestamp's anchoring time. This is independent third-party evidence with sub-day temporal resolution, suitable for priority disputes.

## Verification (anyone can run)

```bash
pip install opentimestamps-client
ots verify <filename>.ots
```

The verifier downloads the corresponding Bitcoin block header and confirms the timestamp inclusion proof. No trust in the originator or GitHub is required.

## Upgrade workflow

Fresh `.ots` files are "incomplete" — they contain a pending proof that gets upgraded once Bitcoin confirms the calendar server's commitment (typically within 1-6 hours).

To upgrade after waiting:

```bash
ots upgrade *.ots
git add timestamps/
git commit -m "ots: upgrade with full Bitcoin proofs"
```

## File inventory

- `HEAD-snapshot.txt` — current HEAD commit metadata (hash + date + author)
- `PRIORITY.md.ots` — authorship declaration
- `SPEC.md.ots` — core specification
- `CITATION.cff.ots` — citation metadata
- `README.md.ots` — project overview
- `release_notes/v0.1.5.md.ots` — first formal release notes
- `APPENDIX-PLATFORM-QUIRKS.md.ots` — observed quirks compendium

## Going forward

Re-run `scripts/ots-backfill.sh` after each release to anchor that release's state. Optionally add to CI/CD as a release-time step.
