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
