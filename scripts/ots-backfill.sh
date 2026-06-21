#!/usr/bin/env bash
# ots-backfill.sh
# Anchor CCPE-spec priority evidence to Bitcoin blockchain via OpenTimestamps.
# Run from repo root: bash scripts/ots-backfill.sh

set -e

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

echo "=== CCPE OpenTimestamps Backfill ==="
echo "Repo: $REPO_ROOT"
echo ""

# ============================================
# 1. Install opentimestamps-client if missing
# ============================================
if ! command -v ots &> /dev/null; then
    echo "[1/5] Installing opentimestamps-client..."
    pip install opentimestamps-client
else
    echo "[1/5] opentimestamps-client already installed ($(ots --version 2>&1 | head -1))"
fi
echo ""

# ============================================
# 2. Prepare timestamps directory
# ============================================
echo "[2/5] Preparing timestamps/ directory..."
mkdir -p timestamps
cd timestamps

# ============================================
# 3. Snapshot HEAD commit hash
# ============================================
echo "[3/5] Snapshotting current HEAD..."
HEAD_HASH=$(git rev-parse HEAD)
HEAD_DATE=$(git log -1 --format=%cI)
echo "Commit: $HEAD_HASH" > HEAD-snapshot.txt
echo "Date: $HEAD_DATE" >> HEAD-snapshot.txt
echo "Author: $(git log -1 --format='%an <%ae>')" >> HEAD-snapshot.txt
echo "Repo: tlssksek66-sketch/CCPE-spec" >> HEAD-snapshot.txt
echo "Verified at: $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> HEAD-snapshot.txt
echo "  → HEAD-snapshot.txt created"

# ============================================
# 4. Stamp priority-critical files
# ============================================
echo "[4/5] Stamping priority-critical files..."

STAMP_TARGETS=(
    "HEAD-snapshot.txt"
    "../PRIORITY.md"
    "../SPEC.md"
    "../CITATION.cff"
    "../README.md"
    "../release_notes/v0.1.5.md"
    "../APPENDIX-PLATFORM-QUIRKS.md"
)

for target in "${STAMP_TARGETS[@]}"; do
    if [ -f "$target" ]; then
        echo "  Stamping: $target"
        BASENAME="$(basename "$target").ots"
        # Defect A (idempotency): a prior run committed timestamps/*.ots; ots stamp
        # refuses to overwrite an existing .ots and would abort under `set -e`.
        # Clear any prior anchor (source-adjacent + timestamps/) so re-stamp is safe.
        rm -f "${target}.ots" "./$BASENAME"
        ots stamp "$target"
        # Move .ots file into timestamps/ for organization (if not already there)
        OTS_FILE="${target}.ots"
        if [ -f "$OTS_FILE" ] && [ "$(dirname "$OTS_FILE")" != "." ]; then
            mv -f "$OTS_FILE" "./$BASENAME"
            echo "    → moved to timestamps/$BASENAME"
        fi
    else
        echo "  ⚠️  Skipped (not found): $target"
    fi
done
echo ""

# ============================================
# 5. Create README explaining ots files
# ============================================
echo "[5/5] Writing timestamps/README.md..."
cat > README.md << 'EOF'
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
EOF

cd "$REPO_ROOT"
echo ""
echo "=== Done ==="
echo ""
echo "Next steps:"
echo "1. git add timestamps/"
echo "2. git commit -m 'ots: anchor priority evidence to Bitcoin blockchain'"
echo "3. git push"
echo "4. Wait 1-6 hours for Bitcoin confirmation"
echo "5. Run 'ots upgrade timestamps/*.ots' to attach full proofs"
echo "6. Commit upgraded .ots files"
