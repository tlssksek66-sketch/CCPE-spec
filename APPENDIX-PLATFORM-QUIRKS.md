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
