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

<!-- ============================================================ -->
<!-- v0.1.7 APPENDIX additions — append to existing APPENDIX-PLATFORM-QUIRKS.md -->
<!-- Insert after #14 entry (python-bitcoinlib OpenSSL DLL Dependency) -->
<!-- ============================================================ -->

## #15. GitHub Actions Workflow Scope Requirement

**Platform**: GitHub OAuth / `gh auth` token scopes
**Class**: quirk
**First observed**: v0.1.6 PR push attempt (2026-05-17, pre-v22)
**Cases**: 1 (v0.1.6 PR Phase — push containing `.github/workflows/` change rejected) — APPENDIX queue

### Pattern

Pushing a commit that adds or modifies files under `.github/workflows/` requires the pushing token to have the `workflow` OAuth scope. Standard `repo` scope is insufficient. Without the scope, GitHub server rejects the push with `refusing to allow an OAuth App to create or update workflow ... without 'workflow' scope`.

### Empirical observation

`gh auth refresh -h github.com -s workflow` (interactive browser auth) was required before the v0.1.6 push containing `.github/workflows/ots-backfill.yml` could succeed.

### Implication for CCPE operators

- Initial repo setup with workflow files needs upfront `workflow` scope grant
- Re-authentication may be required on token rotation
- CI/CD-touching PRs from automation systems must carry sufficient scope or hand off to human-supervised push

### Mitigation

Set up scope at first `gh auth login` with `gh auth login --scopes "repo,workflow"`. Or grant after the fact via `gh auth refresh -h github.com -s workflow`.

---

## #16. Claude Code Self-Modification Guardrail

**Platform**: Claude Code agent
**Class**: contract (positive — defense-in-depth)
**First documented**: `cases/v21-bootstrap.md` (implicit, settings.json attempt)
**Reinforced**: `cases/v22-cross-product-memory.md` §3 Phase 1
**Cases**: 2

### Statement

Claude Code refuses to modify its own permission configuration (`~/.claude/settings.json` `permissions` block) via any tool:
- The dedicated `update-config` skill: hard-blocked by auto-mode classifier
- Direct `Edit` on `settings.json` to add allow rules: blocked OR self-refused by CC citing the security intent

The guardrail's scope is **the intent of self-permission-elevation**, not any specific tool. CC recognizes that the boundary is what's being protected, not the specific path to bypass it.

### Empirical observation

In v22 Phase 1:
1. CC called `update-config` skill → "Denied by auto mode classifier"
2. CC offered Edit-based workaround
3. CC then self-refused, articulating: "다른 도구로 같은 행위를 하는 건 그 의도를 무력화하는 것"

This is judgment beyond rule-following — CC recognized intent and refused even when no explicit deny rule existed.

### Implication for CCPE operators

- Permission rule changes must come from outside CC's loop: user manually editing the file, or `/permissions` UI invocation, or chat instance writing artifact for user relay
- This is a **bootstrap-validation property** of trust: an agent that won't elevate its own privileges can be safely run with high autonomy elsewhere
- CCPE-conformant agent implementations should preserve this property

### Operator workaround (preserves the property)

When CC needs new permission rules:
1. CC reports the desired rule with rationale
2. Chat (different instance, different boundary) writes the updated `settings.json` to artifact
3. User relays artifact to disk
4. CC reads + validates result via PowerShell `ConvertFrom-Json` (or `jq` if available)

The pattern relies on the chat-CC capability asymmetry as a *feature* (see RFC-001 §sync evidence).

---

## #17. Permission Rule Prefix Matching Semantics

**Platform**: Claude Code `permissions.allow` rules
**Class**: quirk
**First documented**: v21-bootstrap (implicit — `cd && X` not matching `Bash(X:*)`)
**Refined**: `cases/v22-cross-product-memory.md` §3 Phase 2 + Phase 3
**Cases**: 1 case with 3 sub-cases (chain failure, subcommand mismatch, literal prefix only)

### Statement

`permissions.allow` rules match by **literal-prefix on the entire command**, where "command" means the full token sequence as invoked. Two non-obvious consequences:

1. **Chain prefix takes precedence**: `A && B` is matched against the prefix `A`, not `B`. To match `Bash(B:*)`, command must invoke `B` standalone.
2. **Subcommand families don't compose**: `Bash(gh run:*)` does **not** match `gh workflow run`. The match is on the literal leading tokens. `gh run` and `gh workflow run` are different prefixes despite the apparent semantic overlap.

### Empirical observation table

| Allow rule | Invocation | Match? | Reason |
|---|---|---|---|
| `Bash(git push:*)` | `git push origin main` | ✅ | exact prefix |
| `Bash(git push:*)` | `cd path && git push origin main` | ❌ | prefix is `cd path` |
| `Bash(git push:*)` | `git commit ... && git push ...` | ❌ | prefix is `git commit` |
| `Bash(git -C "path" push:*)` | `git -C "path" push origin main` | ✅ | exact prefix |
| `Bash(gh run:*)` | `gh run list` | ✅ | exact prefix |
| `Bash(gh run:*)` | `gh workflow run ots-backfill.yml` | ❌ | prefix is `gh workflow run`, not `gh run` |

### Implication for CCPE operators

- Write rules for each invocation pattern actually used
- For subcommand families, enumerate explicitly or use broader patterns: `Bash(gh workflow:*)` covers all `gh workflow X` subcommands
- Avoid `cd path && cmd` patterns in CCPE workflows — use `cmd -C path` form where supported, or invoke standalone after a separate `cd`

### Mitigation pattern

For frequently used command families, prefer broad subcommand patterns:
- `Bash(gh workflow:*)` over `Bash(gh workflow run:*)` + `Bash(gh workflow list:*)` + ...
- `Bash(git -C "<absolute-path>" :*)` style if rule syntax supports it (test in your environment)

---

## #18. Auto-Mode Policy Gate Independence

**Platform**: Claude Code auto-mode classifier
**Class**: contract (positive — defense-in-depth)
**First documented**: `cases/v22-cross-product-memory.md` §3 Phase 2 + §4.3
**Cases**: 1 (v22 Phase 2 — empty commit main push attempt)

### Statement

Claude Code's auto-mode policy gates are an **independent evaluation layer** orthogonal to `permissions.allow` rules. Inclusion of a command pattern in `allow` is **necessary but not sufficient** for autonomous execution. Auto-mode evaluates additional policy heuristics on top of permission rules.

### Empirical observation

In v22 Phase 2, the following allow rule was active:
```
Bash(git -C "C:\\Users\\dudvu\\Documents\\GitHub\\CCPE-spec" push:*)
```

Invocations matching the allow rule:
- ✅ `git -C "..." push --dry-run origin main` → passed (allow rule + dry-run is non-destructive)
- ❌ `git -C "..." commit --allow-empty -m "test" && git -C "..." push origin main` → blocked

The block was not due to allow-rule mismatch (the push portion matched), but due to a separate policy gate evaluating "empty commit + push to default branch."

### Implication for CCPE operators

1. Adding a command to `permissions.allow` does not waive auto-mode's defense-in-depth checks
2. Auto-mode gates protect citable/protected branches from accidental pollution even under permissive allow rules
3. **This is a positive contract**: operators can rely on auto-mode gates as a backstop even if their permission rules are accidentally over-broad

### Contract guarantee

The asymmetry is intentional. CCPE-conformant implementations should preserve this property: agents that can over-permission themselves accidentally still need protection from acting destructively on protected resources.

### Anti-pattern to avoid

Treating allow-list inclusion as "I can do anything starting with this prefix." Verify actual execution behavior with non-destructive probes (`--dry-run`, status checks, `gh workflow list`) before assuming full automation.

### Verification probe

```bash
git -C "<path>" push --dry-run origin main
```
- Allow rule matches → command executes
- Auto-mode policy gates evaluate independently (in dry-run, both layers pass; in destructive form, additional gates may block)
