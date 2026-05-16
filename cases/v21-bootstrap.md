# Case: V21 Bootstrap — CCPE Self-Deployment Round-Trip

**Trial**: V21 Bootstrap (2026-05-16)
**Status**: Closed — first-PR success (commit `b894611`, push `f4e491c..b894611 main → main`)
**Promoted to**: v0.1.6 APPENDIX candidates #11 / #12 / #13 + §3.x Broad-Verify+Narrow-Execute promotion
**Significance**: First instance of CCPE applied to CCPE itself — strategy-execution dogfooding with 4 new pattern emergences in single round-trip.

---

## 1. Context

- **Project**: CCPE-spec repo (formally separated from operational track on 2026-05-16 per `PRIORITY.md`)
- **Strategy instance**: Claude chat (claude.ai web) — drafted 5 PR files, issued 7-block command
- **Execution instance**: Claude Code (fresh Windows local session) — applied edits, verified, pushed
- **User role**: relay-only (file transport between strategy and execution; no manual edits)
- **Track scope**: first PR establishing author identity + citation infrastructure + autonomy charter

## 2. Trigger

After v0.1.5 release (2026-05-08), originator decided to formally separate CCPE from operational track for priority establishment + future monetization via authority model. First PR scope:

- **New files**: `PRIORITY.md`, `AUTONOMY.md`, `CITATION.cff`
- **Modified files**: `README.md` (author line), `release_notes/v0.1.5.md` (author footer)
- **Value substitution**: `[FILL IN — real name or consistent pen name]` → `eulpeul`
  - Criterion: consistency with existing `README.md` line 2 "created by eulpeul"
  - Alternative declined: `tlssksek66-sketch` (GitHub handle) — citation readability weak
- **Structural**: `CITATION.cff` `family-names/given-names` placeholder → `name: "eulpeul"` (Zenodo entity form, raised by CC during execution)

## 3. Round-Trip Sequence

### Phase 1 — Strategy-side draft (chat, ~30 min)
- 5 files drafted with `[FILL IN]` placeholders
- 7-block command issued with embedded variables, branch tree, safety guards
- Files routed to user via chat file presentation

### Phase 2 — User relay (manual, ~5 min)
- 4 files downloaded, manually placed in `C:\Users\dudvu\Documents\GitHub\CCPE-spec\`
- `CITATION.cff` separately handled (initial download incompatibility → MD wrapper detour → eventual placement)

### Phase 3 — Execution-side first attempt (CC session, ~5 min)
- Pre-check: 5/5 files present ✅
- `CITATION.cff` drift detected: file was already at `alias: "eulpeul"` (prior session leftover). CC adapted and applied `alias → name` structural fix anyway.
- 4-file substitutions: PRIORITY.md 2회, README.md 1회, release_notes/v0.1.5.md **0회 (PREDICTED 1회)** ⚠️
- Verification grep: real-name pattern still **1 hit** at `release_notes_v0.1.5.md:67` (root, underscore, scope-外)
- **Safety guard [6] fired** — push 중단, originator 결정 요청

### Phase 4 — Strategy-side resolution (chat, ~5 min)
- Diagnosis: strategy's chat-output filename `release_notes_v0.1.5.md` (underscore for cross-platform compatibility) ≠ repo's canonical path `release_notes/v0.1.5.md` (slash). User relay placed file at root verbatim → duplicate.
- Branch tree expansion: **Option 5 — Merge then delete** (additional to CC's 4 default options):
  - Root substitution → overwrite canonical subdir → trash root
- New 7-block patch issued

### Phase 5 — Execution-side completion (CC session, ~3 min)
- Root file substituted (1회)
- CC observed: root content is **strict superset** of canonical (identical body + footer with `../CITATION.cff` relative path). Reconciliation = canonical takes root content (entire file write).
- Root file deleted to Recycle Bin (강 안전 모드 — never hard `rm`, per CC's project-agnostic dedup rule)
- Verification re-run: real-name pattern **0 hits** ✅
- `git add -A`: included `CITATION.md` (scope-外, manually placed by user with leftover `[FILL IN]`)
- Commit `b894611`, push `f4e491c..b894611 main → main` ✅

**Total elapsed**: ~50 min strategy + execution combined, ~9 min of which was CC active (8m 40s reported).

## 4. Branch Tree Applied

- A. CC's prediction matches actual → straight push. ❌ Not triggered (substitution count mismatch).
- B. Real-name 잔존 detected → push 중단. ✅ **Triggered, intended behavior.**
- C. YAML invalid → push 중단. Not triggered.
- D. Git push fail (auth/conflict) → stash + report. Not triggered.
- E (resolution branches presented to originator):
  - E1. Substitute root + keep both → declined (canonical pollution)
  - E2. Trash root + keep subdir clean → declined (footer 콘텐츠 유실)
  - E3. Leave root untracked + push 5 scope → declined (guard 완화 필요)
  - E4. Full abort → declined (no progress)
  - **E5. Merge then delete → adopted** ★ (only option preserving footer + 단일 canonical)

## 5. Safety Guards Triggered

- **[6] Real-name pattern broad-verify** fired once → working as designed
- **Strict-superset reconciliation rule** applied automatically by CC (existing file dedup heuristic, not part of original 7-block)
- **Soft-delete rule** applied automatically — never hard `rm` (CC's existing memory, project-agnostic)
- **`git add -A` scope-leak** detected post-fact (CITATION.md unintentionally committed) — non-blocking flag

## 6. Block 7 Prediction vs Actual

| Field | Predicted | Actual |
|---|---|---|
| preCheck | ok | ✅ ok |
| missingFiles | [] | ✅ [] |
| citationStructured | true | ✅ true |
| substitutions.PRIORITY.md | 2 | ✅ 2 |
| substitutions.README.md | 1 | ✅ 1 |
| substitutions.release_notes/v0.1.5.md | 1 | ❌ 0 (1 in scope-外 root file) |
| remainingFillInRealName | 0 | ⚠️ 1 → resolved to 0 after Option 5 |
| yamlValid | true | ✅ true |
| gitCommitHash | "<7+chars>" | ✅ b894611 |
| gitPushOk | true | ✅ true |
| branch | main | ✅ main |
| files changed (final) | 5 | ⚠️ 6 (CITATION.md scope-leak via `git add -A`) |

**Prediction accuracy**: 9/12 exact, 2/12 corrected mid-trip (substitution location, file count), 1/12 scope-leak observed post-trip.

## 7. Findings

### 7.1 Strategy-side file naming convention drift (NEW)
Strategy instance (chat) generates file artifacts with cross-platform-safe naming: `/` → `_`. User relay does not auto-correct. Target repo has canonical `/` structure. → duplicate file at root, scope-外.

**Mitigation candidates**:
- Strategy-side: explicit target path declaration in file presentation
- User-side: pre-relay path verification
- Execution-side: detect by name similarity heuristic (already does)

### 7.2 Strict-superset reconciliation (NEW, positive contract)
When candidate file A (root) ⊃ canonical file B (subdir) in content (identical body + extra), reconciliation rule = A → B (overwrite canonical), then trash A. Preserves all content, restores single-canonical invariant.

CC noticed this via internal file dedup rule. The `../CITATION.cff` relative path in A's footer (only resolvable from inside `release_notes/`) was the **deciding evidence** — file was *intended* for subdir.

**Generalizes to**: any case where strategy output gets misplaced relative to canonical repo structure but content provenance suggests intended location.

### 7.3 `git add -A` scope pollution (NEW, anti-pattern)
7-block command [5] used `git add -A` which captures all working tree changes including out-of-scope files (CITATION.md). Result: scope-外 file (CITATION.md with leftover `[FILL IN]`) committed alongside intended 5 files.

**Mitigation**: explicit `git add <FILES list>` or strict glob in 7-block [5]. Update 7-block template to default-against `add -A` when FILES variable is explicit.

### 7.4 Broad-verify + narrow-execute combo (CONFIRMED, ≥2 cases — PROMOTION READY)
- 1st case: v20-a1 Phase 2 (broad verify caught row-cap silent overflow that narrow execute missed)
- 2nd case: this trial (broad grep caught scope-外 잔존)

**Promotion threshold reached.** The pattern: execution scope is intentionally narrow (FILES list), verification scope is intentionally broad (entire repo). The asymmetry catches:
- Scope misspecification (this case)
- Hidden side effects (v20-a1)
- Stale state outside execution path

→ **Promote to SPEC §3.x in v0.1.6.**

## 8. Promotion Candidates → v0.1.6

| # | Pattern | Label | Cases | Action |
|---|---|---|---|---|
| #11 | Strategy-Side File Naming Convention Drift | quirk | 1 (this) | APPENDIX queue (need 2nd case for promotion) |
| #12 | Strict-Superset Reconciliation | contract | 1 (this) | APPENDIX queue |
| #13 | `git add -A` Scope Pollution | anti-pattern | 1 (this) | APPENDIX queue |
| §3.x | Broad-Verify + Narrow-Execute Combo | contract | 2 (v20-a1 P2 + this) | **PROMOTE to SPEC §3.x** ★ |

## 9. Lessons

- CCPE self-applies cleanly: strategy/execution split worked as specified
- File transport via human relay surfaces drift patterns that pure-API integration would not (cross-platform naming)
- CC's existing project-agnostic safety rules (soft-delete, file dedup) composed cleanly with CCPE's project-specific safety guards — no rule conflict
- 7-block [6] safety guards prevented a bad push despite [4] execution scope misspecification — **defensive verification redundancy works**
- Single round-trip is rarely achievable when human relay involved — 2 round-trips (Phase 3 + Phase 5) was the minimum here
- v21-bootstrap is the first case with same-week trial-to-case lag (compare v19-b5: 4-day lag, v20-g2: 2-day lag). Active dogfooding accelerates case derivation.

## 10. Cross-references

- Strategy-side governance: `AUTONOMY.md` — this trial validates §Default Behavior + §Exception #2 (information only originator has)
- Sister case: `cases/anonymized-v20-a1.md` — provides 2nd case for Broad-Verify promotion
- SPEC v0.1.4 §2.x Verify Round-Trip Rule — this trial validates separation of execute vs verify
- SPEC v0.1.4 §3 Role Charter, §4 Hard-Limit Anti-Pattern — no triggers (different failure modes)

---

## Meta-significance

This is the **first case file generated within the CCPE-spec repo itself** (vs. anonymized cases derived from operational track). It marks the lineage transition from:

> CCPE-as-extracted-from-operations (v19-v20 lineage)

to

> CCPE-as-self-applying-discipline (v21+ lineage)

Future trials that exercise CCPE on CCPE will populate this lineage. The operational-track cases remain valid as anonymized historical evidence; v21+ cases can be cited directly without anonymization.
