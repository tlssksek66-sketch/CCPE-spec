# Appendix: Platform Quirks

CCPE SPEC describes structural rules for twin-instance coordination. This appendix documents *vendor-specific constraints* observed in the field — not part of the spec itself, but worth tracking because they shape execution-side strategy.

## Purpose
Separating platform quirks from SPEC keeps the core rules portable across LLM/runtime combinations. When a quirk reproduces across vendors, consider promoting it to SPEC; until then, it stays here.

## Quirks

### #1 6-Minute Server-Side Hard Limit
- **Vendor**: Apps Script execution
- **Limit**: 6 minutes per server-side function invocation
- **Symptom**: Mid-batch corruption when long-running clear-then-write sequences exceed limit
- **Cases**: v19-b5 (P3 reload), v20-g1-fix (verify-rule-change retry, two consecutive timeouts on same patch path)
- **Status**: **Promoted to SPEC §4 (v0.1.4)** — class-level Hard-Limit Anti-Pattern now codified in spec
- **Mitigation**: Split into ≤6min units; never combine clear and full re-write in single invocation; verify-rule changes that expand dedup-key cardinality should be tested on smallest target first

### #4 Row Cap Silent Overflow
- **Vendor**: Apps Script Spreadsheet (Google Sheets)
- **Limit**: 100,000 rows maxRows per sheet (default cap)
- **Symptom**: Append operations succeed up to cap, then silently stop accepting rows. No exception thrown; verify routines that count expected vs actual rows surface the gap.
- **Cases**: v19-b5 (inferred), v20-a1 (exact-match confirmed: 71,291 + 28,709 = 100,000)
- **Mitigation candidates**:
  - Pre-trim before append (rolling window deletion)
  - Partition strategy (separate sheets per time bucket)
  - Bypass sheet intermediation (raw CSV → direct BI tool)
  - Expand maxRows via insertRows (caution: empty rows still consume cell quota)

### #5 Strict-Equality Verify Header Matching
- **Vendor**: Apps Script `_verifyDedupOK` and similar verify routines using `String(header).trim() === want`
- **Symptom**: Small string differences between STATIC mapping table values and raw header strings (e.g., `'소재 ID'` registered vs `'광고 소재 ID'` in raw, `'매체'` vs `'매체이름'`) silent-fail at verify step. Result: inflated multiDupes counts read as `verify ok=false`, but underlying data is correct.
- **Cases**: v20-a1 (1 key), v20-g1 (4 keys)
- **Mitigation**: actual raw-header inspection required before STATIC table additions; consider fuzzy matching with logged warnings for near-misses; or auto-derive STATIC from raw on each ingest

### #7 Wrapper-Args Dispatch Routing Gap
- **Vendor**: Apps Script `doPost` wrapper pattern
- **Symptom**: Function registered in `allowed`-map but not added to explicit args dispatch branch silently receives no args; returns false-positive "OK" with empty result instead of error
- **Cases**: v20-g1-fix (`restoreSheetsByPair` invoked with empty `pairs=[]`)
- **Mitigation**: every args-receiving function requires explicit dispatch branch; pure registry-pattern is insufficient; add unit-level test for "function called via dispatcher receives args"


<!-- ============================================================ -->
<!-- v0.1.5 APPENDIX additions — append to existing APPENDIX-PLATFORM-QUIRKS.md -->
<!-- Insert after #7 entry, preserve existing #1/#4/#5/#7 -->
<!-- ============================================================ -->

## #8. Workbook Cell Cap Silent Overflow

**Platform**: Google Sheets (via Apps Script / Sheets API)
**Class**: hard-limit anti-pattern (workbook scope)
**First observed**: V20 G2 (2026-05-06)
**Sister patterns**: #4 (Row Cap Silent Overflow — per-sheet)

### Pattern

Google Sheets enforces a workbook-wide hard limit of 10,000,000 cells across
all sheets in a single spreadsheet. This limit is **distinct from** per-sheet
maxRows cap (#4, default 100 K rows × column count).

Cell budget consumed by all populated regions across all sheets sums to a
single workbook-level total. Examples:
- 100 sheets × 100 K rows × 1 col = 10 M (boundary, last write succeeds)
- 100 sheets × 100 K rows × ≥1 cols (boundary at 1, blocked above)
- Single sheet 1 M rows × 10 cols → blocked at workbook level
- Multiple medium sheets summing to >10 M cells → blocked

### Detection

Reload / append response message (Korean):
> "이 작업을 실행하면 통합문서의 셀 개수가 한도인 10000000개를 초과합니다"

(English equivalent: "This action will exceed the 10,000,000 cells limit
of the workbook")

### Guard

Pre-flight cell budget calculator before reload / batch insert:

```js
function preflightCellBudget(targetRows, targetCols, currentUsage) {
  const HARD_CAP = 10_000_000;
  const projected = currentUsage + (targetRows * targetCols);
  if (projected > HARD_CAP) {
    return { ok: false, deficit: projected - HARD_CAP };
  }
  return { ok: true, headroom: HARD_CAP - projected };
}
```

If deficit detected:
- Option A: Split target across multiple smaller batches
- Option B: External workbook split (move sheet to separate spreadsheet)
- Option C: Drop derived columns / temporal trim before reload

### Anti-pattern

Assuming sheet-level cleanup (#4 trim) recovers workbook-level budget.
β cleanup confirmed idempotent post-initial run — workbook-wide budget
requires structural splits, not row trims.

### Cross-reference

- #4 Row Cap Silent Overflow (per-sheet, different dimension)
- §4 Hard-Limit Anti-Pattern (sister to 6-min Apps Script timeout)

---

## #9. requireNonEmpty Guard Missing

**Platform**: Verification routines (Apps Script / general)
**Class**: verify false-positive
**First observed**: V20 G2 (2026-05-06)
**Sister patterns**: #5 (Strict-Equality Verify Header Matching)

### Pattern

Dedup / multi-dupe verification logic operates on row sets. When the target
sheet has dataRows=0 (e.g., reload blocked, sheet not yet populated), the
verification iterates an empty set and returns ok=true.

This is logically consistent (no dupes found in empty set) but **operationally
misleading** — caller assumes dedup logic confirmed integrity, not absence
of data.

### Detection

**Before** (false-positive case):
```js
{
  ok: true,            // ← misleading: passes vacuously on empty set
  dataRows: 0,         // ← actual data state, but caller may not check
  multiDupes: 0,
  dedupHeadersUsed: [...]
}
```

**After** (with requireNonEmpty guard):
```js
{
  ok: false,
  reason: 'EMPTY_SHEET',  // ← explicit fail when expected non-empty
  dataRows: 0,
  multiDupes: 0,
  dedupHeadersUsed: [...]
}
```

### Guard

Add explicit `requireNonEmpty` option to verify functions:

```js
function verifyDedup(sheet, opts) {
  const rows = sheet.getDataRange().getValues();
  if (opts.requireNonEmpty && rows.length <= 1) {
    return {
      ok: false,
      reason: 'EMPTY_SHEET',
      dataRows: rows.length - 1
    };
  }
  // ... regular dedup logic
}
```

Caller invokes with `{requireNonEmpty: true}` for sheets expected to have
data; omits for genuinely empty checks.

### Anti-pattern

Treating ok=true as "verified integrity" without checking dataRows >= expected
threshold. This pattern compounds with reload failures that silently leave
target sheet empty.

### Cross-reference

- #5 Strict-Equality Verify (sister, different bug class — header matching
  logic, not empty-set semantics)
- v0.1.4 §2.x Verify Round-Trip Rule

---

## #10. Cleanup Idempotent Contract

**Platform**: Apps Script cleanup routines / general
**Class**: positive contract / invariant (NOT a quirk)
**Label discipline**: Distinct from quirks — represents guarantee, not limitation
**First observed**: V19-B5 (2026-05-04), confirmed V20 G2c² (2026-05-06)

### Pattern

`trimEmptyRowsCols()`, `cleanupAfterRestore()`, and similar cleanup primitives
exhibit idempotent contract:

```
Run 1: recovered = R1 cells, trims = T1 sheets
Run 2: recovered = 0,        trims = 0
Run N: recovered = 0,        trims = 0
```

This is a **guarantee fulfillment**, not a degradation:
- After first run reaches steady state, cleanup is safe to invoke repeatedly
- Concurrent / accidental re-invocation cannot corrupt state
- Caller can wrap cleanup in defensive retry loops without side-effect concerns

### Detection

Two consecutive cleanup invocations on same scope yield monotone-decreasing
recovery (R1 ≥ R2 ≥ ... ≥ 0, with R2 = 0 after first stabilization).

### Misreading risk (CRITICAL)

If labeled as a "quirk" or "limitation", subsequent operators may interpret:
- "Cleanup hits a wall, find another way" (incorrect)
- "Avoid running cleanup twice" (incorrect)

Correct interpretation:
- "Cleanup converged; further calls are no-ops by design"
- "Safe to invoke without state-tracking"

### Guard / use

Cleanup callers:
1. Invoke without precondition checks (idempotent allows blind retry)
2. Treat recovered=0 as "already at steady state", not failure
3. Do NOT compose cleanup into "limitation discovery" logic

### Anti-pattern

Treating idempotent zero-recovery as a signal that "cleanup is broken" or
"workbook needs structural intervention". The correct signal is workbook
cell budget itself (#8), not cleanup return value.

### Cross-reference

- #8 Workbook Cell Cap (true structural limit; cleanup idempotency
  rules out cleanup as recovery path, strengthening hypothesis that #8
  structural limit applies — but other causes remain possible: dense
  population, no derived cols, etc.)
- v0.1.4 §4 Hard-Limit Anti-Pattern (#8 is the limit; #10 is one of several
  rule-out mechanisms confirming #8 applies)


<!-- ============================================================ -->
<!-- v0.1.6 APPENDIX additions — append to existing APPENDIX-PLATFORM-QUIRKS.md -->
<!-- Insert after #10 entry, preserve all existing entries -->
<!-- ============================================================ -->

## #11. Strategy-Side File Naming Convention Drift

**Platform**: Chat → user-relay → repo file transport
**Class**: quirk (routing defect)
**First observed**: V21 Bootstrap (2026-05-16)
**Sister patterns**: #7 (Wrapper-Args Dispatch Routing Gap — both *routing* defects)
**Cases**: 1 (v21-bootstrap) — APPENDIX queue, needs 2nd case for promotion

### Pattern

Strategy instance (Chat) generates file artifacts with cross-platform-safe
naming convention: path separators `/` → underscore `_`. User relay does not
auto-correct on placement. Target repo expects canonical `/` directory
structure. Result: duplicate file at root, scope-外 from intended location.

Example from V21 Bootstrap:
- Strategy output: `release_notes_v0.1.5.md` (flat name, portable)
- Intended location: `release_notes/v0.1.5.md` (canonical, in subdirectory)
- Actual placement: root-level `release_notes_v0.1.5.md` (duplicate)
- Existing canonical `release_notes/v0.1.5.md` untouched (stale)

### Detection

Post-edit broad-grep verification catches the duplicate (this is what
§3.x Broad-Verify + Narrow-Execute is designed for). Without broad
verification, the scope-外 duplicate ships uncaught.

### Mitigation candidates

- **Strategy-side**: explicit target path declaration in file presentation
  (e.g., "save as `release_notes/v0.1.5.md`")
- **User-side**: pre-relay path verification (manually create subdirectories
  before placing files)
- **Execution-side**: filename similarity heuristic (already does, but only
  after broad-grep triggers)

### Resolution pattern

When detected, apply #12 Strict-Superset Reconciliation if content
provenance favors canonical location.

### Cross-reference

- #7 Wrapper-Args Dispatch Routing Gap (sister routing defect)
- #12 Strict-Superset Reconciliation (resolution pattern)
- §3.x Broad-Verify + Narrow-Execute (detection mechanism)

---

## #12. Strict-Superset Reconciliation

**Platform**: File dedup / conflict resolution (general)
**Class**: positive contract / invariant (NOT a quirk)
**First observed**: V21 Bootstrap (2026-05-16)
**Sister patterns**: #10 (Cleanup Idempotent Contract — both positive contracts)
**Cases**: 1 (v21-bootstrap) — APPENDIX queue

### Pattern

When candidate file A and canonical file B exist and A ⊃ B in content
(A contains identical body + extras), reconciliation rule is:

1. Apply A → B (overwrite canonical with superset)
2. Trash A (soft-delete to Recycle Bin / .Trash)
3. Confirm single-canonical invariant restored

This preserves all content (B's extras survive in canonical), restores the
single-canonical invariant, and removes the duplicate without data loss.

### Detection signal

Provenance evidence in A's extras that only resolves from canonical location.
Example from V21 Bootstrap:
- A: root-level `release_notes_v0.1.5.md` with footer linking `../CITATION.cff`
- B: canonical `release_notes/v0.1.5.md` without footer
- A's relative path `../CITATION.cff` only resolves from inside
  `release_notes/` → A was *intended* for canonical location

### Use

Reconciliation is safe to invoke when:
- A ⊃ B confirmed by byte-level diff (identical lines + only-in-A lines)
- Provenance signals favor canonical location
- Backup of A retained in Recycle Bin (recoverable for 30+ days)

### Anti-pattern

Naive deletion of either A or B without superset check. Loses content if:
- A trashed without merging extras → B remains stale
- B overwritten without preserving canonical-only lines (rare for this pattern,
  but possible if A is not strict superset)

### Cross-reference

- #11 Strategy-Side File Naming Convention Drift (typical cause)
- #10 Cleanup Idempotent Contract (sister positive contract)
- v21-bootstrap §7.2 (case derivation)

---

## #13. `git add -A` Scope Pollution

**Platform**: Git CLI workflow (general)
**Class**: anti-pattern
**First observed**: V21 Bootstrap (2026-05-16)
**Sister patterns**: #7 (Wrapper-Args Dispatch — both *scope* defects)
**Cases**: 1 (v21-bootstrap) — APPENDIX queue

### Pattern

`git add -A` captures all working tree changes including:
- Files not in the intended FILES variable scope
- Untracked artifacts (test outputs, partial tool outputs, OS metadata)
- Files staged by other parallel work

When a 7-block command's FILES variable is explicit, `git add -A` violates
the intended scope and produces unintended commits.

Example from V21 Bootstrap:
- Intended FILES: 5 files (CITATION.cff, PRIORITY.md, AUTONOMY.md, README.md, release_notes/v0.1.5.md)
- `git add -A` also staged: CITATION.md (manually placed by user, scope-外)
- Result: 6-file commit, CITATION.md committed with leftover `[FILL IN]`

### Detection

Post-commit diff comparison with intended FILES:
```bash
git diff --name-only HEAD~1 HEAD | sort > actual.txt
echo "FILES_LIST" | tr ',' '\n' | sort > intended.txt
diff actual.txt intended.txt
```
Mismatch = scope pollution.

### Mitigation

Default to explicit `git add <FILE list>` when FILES is explicit in 7-block.
Reserve `git add -A` for cases where:
- FILES variable is intentionally "all changes" (rare)
- Working tree is verified clean except for intended changes

Updated 7-block [5] convention:
```
$ git add cases/v21-bootstrap.md scripts/ots-backfill.sh CITATION.md
  # explicit list matches FILES variable
  # NOT: git add -A
```

### Self-validation case

V21 PR #2 (`d1bf378`) used explicit `git add <3 files>` per this mitigation
— validating §7.3 within the same release cycle the case was published.

### Cross-reference

- #7 Wrapper-Args Dispatch Routing Gap (sister scope defect)
- v21-bootstrap §7.3 (case derivation)
- §3.x Broad-Verify + Narrow-Execute (broader principle this anti-pattern violates)

---

## #14. python-bitcoinlib OpenSSL DLL Dependency

**Platform**: Python (Windows embedded, Python 3.14)
**Class**: quirk (environment dependency)
**First observed**: V21 PR #2 OTS attempt (2026-05-16)
**Sister patterns**: (none — first environment-incompat quirk)
**Cases**: 1 (v21-bootstrap PR #2) — APPENDIX queue

### Pattern

`python-bitcoinlib` (transitive dependency of `opentimestamps-client`)
requires OpenSSL DLL via ctypes at import time:

```python
import ctypes
# Inside python-bitcoinlib/core/key.py at import:
ssl = ctypes.cdll.LoadLibrary(ctypes.util.find_library('ssl'))
```

On Windows embedded Python 3.14, `find_library('ssl')` returns None →
`LoadLibrary(None)` raises `TypeError: argument must be str, bytes or os.PathLike`.

`pip install opentimestamps-client` succeeds. The package is "installed" but
import fails at first use:

```
$ ots --version
Traceback (most recent call last):
  ...
TypeError: LoadLibrary() argument 1 must be str, bytes or os.PathLike, not NoneType
```

### Detection

`ots --version` produces Traceback even though `pip show opentimestamps-client`
confirms installation.

### Affected environments

- Windows + embedded Python 3.14 (confirmed)
- Likely: any Windows Python without OpenSSL system-wide install
- Not affected: Linux distributions (libssl ubiquitous), macOS (libssl via brew/system)

### Mitigation

**Recommended (zero user-env dependency)**:
- GitHub Actions runner (Ubuntu) for OTS automation
- See `.github/workflows/ots-backfill.yml` (v0.1.6 release)
- All OTS operations execute in Linux env automatically

**Alternative (manual)**:
- WSL (Windows Subsystem for Linux) — Ubuntu under Windows
- Run `bash scripts/ots-backfill.sh` from WSL prompt
- 1-2 hour initial setup, then native Linux behavior

**Not recommended**:
- Installing OpenSSL system-wide on Windows (fragile, path conflicts)
- Custom build of python-bitcoinlib without OpenSSL dep (out of scope)

### Cross-reference

- v21-bootstrap §7 PR #2 (case derivation)
- `.github/workflows/ots-backfill.yml` (mitigation infrastructure)
- `scripts/ots-backfill.sh` (works in supported envs, fails gracefully in unsupported)
