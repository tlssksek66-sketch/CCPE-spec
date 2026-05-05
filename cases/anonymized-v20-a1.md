# Case: Split Reload Hits Row Cap on Large Tabular Target (anonymized v20-a1)

## Context
- Project: K-brand operational data sync (anonymized)
- Strategy instance: prescribed split-reload strategy across 4 wrappers to circumvent execution-side 6min hard limit
- Execution instance: 1st wrapper executed; meta-event also occurred (routing boundary violation, see §Meta)

## Trigger
- Large tabular target T1: existing 71K rows, expected 222K (3× headroom assumption)
- Wrapper #1 (2-day window) appended 28,709 rows successfully — ended at exactly 100,000 rows
- Vendor row cap hit silently; verify reported `ok=false` from a separate dedup-key mismatch

## Branch Tree Applied (Block 5)
- A. PASS + dataRows ~99K → 2nd wrapper. Partial fit.
- B. timeout → re-split smaller. Not triggered (148s, well under 6min).
- C. raw file partition discovered → fileId direct reload. N/A.
- D. mappingSource mismatch → recheck. N/A.
- **New gate observed: row cap silent overflow.** Wrappers 2-4 cannot proceed without trim/partition.

Strategy instance accepted A partially; gated 2nd wrapper pending cap strategy.

## Safety Guards Triggered (Block 6)
- includeSheets single-target limit: held
- UTF-8 byte body pattern reused from v19-b5: held
- Backup auto-generation: skipped (clear scanned 71,291, deleted 0 — pre-existing rows out of date window)

## Block 7 Prediction vs Actual

| Field | Predicted | Actual |
|---|---|---|
| dataRows | ~99K (4/20-21 add) | 100,000 — exact cap |
| recoveryTime | ≤4 round-trips (4 wrappers) | 1 effective; 2-4 blocked by cap |
| irreversible loss | 0 | 0 |
| usage delta | +5.6%p | ~+6.3%p |
| timeout | none expected (2-day window) | ✅ none (148s wall) |
| verify ok | true | ❌ false (multiDupes 2,886 — dedup key mismatch) |

## Findings
1. **Row cap silent overflow** — vendor maxRows=100K cap is a *real* gate, not just `cell quota`. v19-b5 inferred this; v20-a1 confirms by exact-match (71,291 + 28,709 = 100,000). 2 independent cases.
2. **Verify dedup-key mismatch** — verify rule used 4-key dedup (date/campaign/adgroup/searchterm) but T1's natural unique key includes time-bucket/device/medium. multiDupes=2,886 is false-positive, not data corruption. 1 case.
3. **6min anti-pattern: not reproduced** — 148s well under limit. v19-b5 candidate #1 stays HOLD; v20-a1 is condition-mismatch (short batch), not negative evidence.
4. **Scope dispatcher branch** — single-file targets use direct-file reload; multi-file targets use full-folder scan with date filter. Same input shape, different cost (52s vs 148s). Worth documenting at execution-side.

## Meta-Event: Routing Boundary Violation
A wrapper #1 execution command was misrouted to the strategy aux instance. Aux instance refused, citing Role Charter §3 + the just-promoted §2.x verify rule. Operator re-routed to execution main instance (R1 path).

This is the **first positive evidence of CCPE Role Charter §3 working under live load** — the boundary refusal itself is the proof.

## Lessons
- Row cap is a vendor constraint, not a CCPE structural concern → belongs in PLATFORM-QUIRKS, not SPEC
- Verify rules are tooling artifacts; false-positives must be distinguishable from real failure
- Split strategy correctly addressed 6min limit but encountered *different* gate (row cap) — anti-patterns can stack
- Strategy instance's prediction missed cap by treating 71K → 222K as headroom; should have validated cap before prescribing wrappers
- Boundary refusal is *successful* spec behavior; refusal logs should be preserved as positive cases

## Promotion Candidates
- **#4 Row cap silent overflow** → APPENDIX-PLATFORM-QUIRKS.md (2 cases — v19-b5, v20-a1)
- **#5 Verify dedup-key mismatch** → HOLD (1 case, await reproduction)
- **#R Role boundary enforcement** → SPEC §3 sub-rule (1 case + deductive — PR-D)
