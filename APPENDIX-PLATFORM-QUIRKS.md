# Appendix: Platform Quirks

CCPE SPEC describes structural rules for twin-instance coordination. This appendix documents *vendor-specific constraints* observed in the field — not part of the spec itself, but worth tracking because they shape execution-side strategy.

## Purpose
Separating platform quirks from SPEC keeps the core rules portable across LLM/runtime combinations. When a quirk reproduces across vendors, consider promoting it to SPEC; until then, it stays here.

## Quirks

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

### #1 6-Minute Server-Side Hard Limit
- **Vendor**: Apps Script execution
- **Limit**: 6 minutes per server-side function invocation
- **Symptom**: Mid-batch corruption when long-running clear-then-write sequences exceed limit
- **Cases**: v19-b5 (P3 reload, 3 sheets corrupted)
- **Status**: HOLD as Promotion Candidate pending 2nd independent reproduction
- **Mitigation**: Split into ≤6min units; never combine clear and full re-write in single invocation
