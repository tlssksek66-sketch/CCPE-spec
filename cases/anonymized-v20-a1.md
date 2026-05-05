# Case: V20 Track — Split Reload, Sibling Reload, Verify-Patch Cycle (anonymized)

## Context
- Project: K-brand operational data sync (anonymized)
- Strategy instance: prescribed multi-phase recovery across an inventory of tabular targets
- Execution instance: same vendor platform as v19-b5; same per-invocation hard limit (~6min)
- Track scope: large target T1 (split reload across 4 wrappers), sibling-domain targets T7 + T8 (auto-create + reload), verify-rule patch + redeploy

## Phase 1 — A-1 Split Reload (large target T1)

### Trigger
- Large tabular target T1: existing 71K rows, expected 222K (3× headroom assumption)
- Wrapper #1 (2-day window) appended 28,709 rows successfully — landed at exactly 100,000 rows
- Vendor row cap hit silently; verify reported `ok=false` from a separate dedup-key mismatch

### Branch Tree Applied
- A. PASS + dataRows ~99K → 2nd wrapper. Partial fit only.
- B. timeout → re-split smaller. Not triggered (148s, well under 6min).
- C. raw file partition → fileId direct reload. N/A.
- D. mappingSource mismatch → recheck. N/A.
- **New gate observed: row cap silent overflow.** Wrappers 2-4 cannot proceed without trim/partition.

### Safety Guards (Phase 1)
- includeSheets single-target limit held
- UTF-8 byte body pattern reused from v19-b5
- Backup auto-generation skipped (clear scanned 71,291, deleted 0 — pre-existing rows out of date window)

### Block 7 — Phase 1
| Field | Predicted | Actual |
|---|---|---|
| dataRows | ~99K (4/20-21 add) | 100,000 — exact cap |
| recoveryTime | ≤4 round-trips (4 wrappers) | 1 effective; 2-4 blocked by cap |
| irreversible loss | 0 | 0 |
| timeout | none | ✅ none (148s wall) |
| verify ok | true | ❌ false (multiDupes 2,886 — dedup key mismatch) |

## Phase 2 — G1 Sibling-Domain Reload

### Context
After A-1 wrapper #1, strategy instance pivoted from row-cap-blocked target to sibling-domain reload (smaller targets T7/T8 in different category, expected to clear without cap pressure).

### Findings
- Auto-creation of absent sheets confirmed (vendor `getSheetByName` + `insertSheet` path; respond field `sheetCreated: true`)
- Target T7 (small, 5K rows): clean reload, exact-match expected count
- Target T8 (mid, 22K rows): clean reload but expected count from inventory metadata was stale (+11,665 actual vs 10,721 declared) — data correct, metadata wrong
- Verify rule defects surfaced again across 4 targets — STATIC dedup-key mapping registered placeholders that did not match raw header strings exactly. Vendor `_verifyDedupOK` uses strict equality (`String(header).trim() === want`), no fuzzy match.
- Dispatcher branch difference: single-file reload path (lean, ~25-50s) vs full-folder reload path (heavy, 148s+). Same input shape, very different cost. Worth surfacing at execution-side strategy.

### Phase 2 Result
- Targets T7 + T8 reloaded; `match` count moved from 5/12 → 6/12
- T8 still flagged miss due to stale-metadata delta, not data corruption

## Phase 3 — G1-fix (Verify-Rule Patch + 6min Reproduces)

### Trigger
Strategy instance prescribed 4-line dedup-key correction in static mapping table + push + redeploy. Reload retry expected to validate fix with `verify ok=true`.

### Branch Tree Applied
- A. Verify ok=true on first retry → fix validated. ❌ Did not occur — timeout intercepted.
- B. Wrapper-args dispatch defect surfaced separately during recovery → required additional fix + second redeploy.
- **6min Hard-Limit Anti-Pattern reproduced** — retry of small-target reload (1.6K rows) hit ~6min server-side timeout twice in succession (one larger target, one smaller). Mid-run partial-state corruption.
- Auto-backup mechanism preserved corrupted-state recoverability; restore wrapper restored both targets in <1min.

### Block 7 — Phase 3
| Field | Predicted | Actual |
|---|---|---|
| verify ok | true after fix | unknown — never received (timeout intercepted) |
| recoveryTime | ≤1 round-trip | 4 round-trips (2 timeouts + dispatch fix + restore) |
| irreversible loss | 0 | 0 (auto-backup + restore worked) |
| deploys consumed | 1 (dedup fix) | 3 (dedup → dispatch fix → restore) |
| sibling defect | none expected | wrapper-args dispatch routing gap discovered |

### Findings
- **6min Hard-Limit reproduced** — same anti-pattern class as v19-b5 P3, different mechanism. v19-b5 = simple long-running clear-then-write; v20-g1-fix = multi-key verify dictionary expansion + cold-start overhead. Combined: 2 cases of same class.
- **Wrapper-args dispatch routing gap** — function in `allowed`-map but absent from explicit args dispatch branch silently received empty args; returned false-positive "OK" with empty result. Vendor implementation pattern, not CCPE structural concern.
- **Auto-backup as recovery infrastructure** — V19-B5 backup function reused on different failure path (timeout-induced corruption vs P3 clear-and-write race). Pattern generalizes.
- **Strict-equality header matching** — small string differences (`'소재 ID'` registered vs `'광고 소재 ID'` in raw, `'매체'` vs `'매체이름'`) silent-fail at verify step; surface as inflated multiDupes counts read as `verify ok=false`.

### Safety Guards (Phase 3)
- Code edits scoped to STATIC mapping table (4 lines) + dispatcher branch (1 block) — no algorithm changes
- `clasp deploy --deploymentId` preserved same URL across @300 → @301 → @302 (no consumer-side migration)
- Auto-backup intact during both timeout incidents
- Restore wrapper invocable from execution-side via fixed dispatcher route (after Phase 3 patch)

## Meta-Event — Routing Boundary Violation
A wrapper #1 execution command was misrouted to the strategy aux instance. Aux instance refused, citing Role Charter §3 + the just-promoted §2.x verify rule. Operator re-routed to execution main instance (R1 path).

This is the **first positive evidence of CCPE Role Charter §3 working under live load** — the boundary refusal itself is the proof. Aux instance's refusal logs were preserved as positive case evidence.

## Lessons
- Row cap is a vendor constraint, not a CCPE structural concern → belongs in PLATFORM-QUIRKS, not SPEC
- Verify rules are tooling artifacts; false-positives must be distinguishable from real failure (strict-equality header matching is one such pattern)
- Split strategy correctly addressed 6min limit but encountered *different* gate (row cap) — anti-patterns can stack across phases of the same recovery
- Strategy instance's prediction in Phase 1 missed cap by treating 71K → 222K as headroom; should have validated cap before prescribing wrappers
- Boundary refusal is *successful* spec behavior; refusal logs should be preserved as positive cases
- Verify-rule changes that expand dedup-key cardinality (5-key → 6-key) can push reload past 6min via multiCombo dictionary expansion + cold-start; test on smallest target first
- Auto-backup + dispatcher-routed restore is a generalizable recovery pattern across distinct failure modes (race condition, timeout-induced corruption)
- Wrapper-args dispatch routing requires explicit per-function branch; pure registry-pattern is insufficient and produces false-positive "OK" results

## Promotion Candidates (post-track)
- **#1 Hard-Limit + Clear-Then-Write Anti-Pattern** — count 1 → **2 cases** (v19-b5 P3, v20-g1-fix). Profile differs but mechanism class matches. **Promoted to SPEC §4 in v0.1.4.**
- **#4 Row Cap Silent Overflow** — 2 cases (v19-b5 inferred + v20-a1 confirmed). APPENDIX-PLATFORM-QUIRKS #1 (separate from spec).
- **#5 Strict-Equality Verify Header Matching** — count 1 → **2+ cases** (A-1 1-key, G1 4-keys). Vendor verify-rule pattern → APPENDIX-PLATFORM-QUIRKS #5.
- **#7 Wrapper-Args Dispatch Routing Gap** — 1 case (v20-g1-fix). Vendor implementation pattern → APPENDIX-PLATFORM-QUIRKS #7.
- **#R Role Boundary Enforcement** — 1 case (this track meta-event) + deductive argument → already promoted to SPEC §3 in v0.1.3.
