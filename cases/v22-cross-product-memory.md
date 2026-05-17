# Case: V22 Cross-Product Memory + Recursive Self-Validation

**Trial**: V22 (2026-05-17)
**Status**: Open — closes upon v0.1.7 PR merge
**Promoted to**: v0.1.7 APPENDIX candidates #16 (contract), #17 (quirk, refined w/ subcommand-mismatch sub-case), #18 (contract, NEW) + OTS workflow integrated patch (cron + `.sh` idempotency + `.bak` hygiene) + SPEC §3.x candidate "Layered Audit for Automation Pipelines" (queue) + RFC-001 evidence base
**Significance**: First case with triple theme — (a) cross-product memory propagation under instance-asymmetric guardrails, (b) CCPE methodology applied to CCPE infrastructure discovering CCPE-violation defects (bootstrap-validation property), (c) **first successful end-to-end OTS Bitcoin attestation traversal** validating v0.1.6 OTS infrastructure on a real CCPE commit.

---

## 1. Context

- **Project**: CCPE-spec repo (formally established 2026-05-16 per v21-bootstrap)
- **Strategy instance**: Claude chat (claude.ai web)
- **Execution instance**: Claude Code (Windows local, multiple sessions same day with cross-session memory recall)
- **User role**: relay (file transport + slash command operator)
- **Pre-state**: HEAD = `6fabea8` (GH Actions auto-anchor on top of v0.1.6 SPEC release `555d88e`)

## 2. Trigger

Following v0.1.6 release, originator initiated permission rule refinement for CC to reduce push friction during v0.1.7 preparation. The intervention surfaced three orthogonal pattern clusters in a single session:

1. **Instance-asymmetric guardrails** (settings.json write capability differential between chat and CC)
2. **Permission rule semantic edge cases** (prefix matching, chain failure, policy gate independence)
3. **CCPE infrastructure §verify violation** (OTS workflow comment-code drift)

The third was unplanned — emerged when chat asked CC to audit the OTS automation envelope during permission validation downtime.

## 3. Round-Trip Sequence

### Phase 1 — Permission JSON application (chat→user→CC, ~10 min)

- chat drafted JSON (deny 4 / allow 7) with Windows path double-escape (`\\\\` → `\\` → `\`)
- CC `update-config` skill called by CC: **denied by auto-mode classifier** (self-modification block)
- CC offered Edit-based workaround on settings.json: **self-refused** by CC citing security intent ("다른 도구로 같은 행위를 하는 건 그 의도를 무력화하는 것")
- chat (different security context) created `settings.json` via `create_file` → `/mnt/user-data/outputs/`
- User downloaded, opened in Notepad, replaced lines 2-4 (case B — partial merge preserving other top-level keys), saved
- CC validated: `cat ~/.claude/settings.json | jq '.permissions'` failed (jq not installed on Windows bash) → PowerShell `ConvertFrom-Json` fallback succeeded
- Result: `{ defaultMode: auto, deny_count: 4, allow_count: 7 }` ✅

### Phase 2 — Permission rule validation (CC, ~5 min)

- CC proposed empty commit + push test
- CC **self-corrected** mid-plan: "빈 commit main push는 citable repo 오염" → switched to `git push --dry-run origin main`
- `git -C "C:\Users\dudvu\Documents\GitHub\CCPE-spec" push --dry-run origin main` → succeeded without permission prompt ✅
- Test also revealed: chained `git commit ... && git push ...` blocked, because prefix matching evaluates entire command's leading token (`git commit`), not the chained `git push`
- Separate observation: empty commit push to `main` was blocked even though `git push` is in allow — separate policy gate evaluation

### Phase 3 — OTS workflow audit (CC, ~5 min)

- CC read `.github/workflows/ots-backfill.yml` fully
- Discovery: workflow has two jobs — `ots-anchor` (stamp) and `ots-upgrade` (Bitcoin attestation pull)
- Discovery: `ots-upgrade` job is gated `if: github.event_name == 'workflow_dispatch'` (line 79)
- Discovery: `on:` block (lines 9-22) has `push`, `release`, `workflow_dispatch` — **no `schedule: cron`**
- Discovery: Lines 74-75 comment claims "Runs on schedule, not on every push (Bitcoin confirms in 1-6h)" — aspirational, not implemented
- **Diagnosis**: comment-code drift = CCPE §verify discipline violation, located in CCPE's own infrastructure
- Run history: 1 execution (`ots-anchor` 23s success, 09:43Z), 0 `ots-upgrade` executions

### Phase 4 — Recursive self-validation event (meta)

- CCPE methodology (audit infrastructure for verify discipline) applied to CCPE infrastructure (ots-backfill.yml)
- Found CCPE-violating defect (§verify discipline violation: aspirational comment unmatched by code)
- **Bootstrap-validation property emerged**: the methodology proves itself by catching defects in its own implementation
- This is the first observed instance of CCPE-on-CCPE finding non-trivial defect (v21 was apply, not audit)

### Phase 5 — Resolution path (in progress)

- **Immediate**: `gh workflow run ots-backfill.yml --field workflow_dispatch=true` — manual upgrade trigger (Track A, pending Bitcoin confirmation timing)
- **Permanent**: 3-line patch to `.github/workflows/ots-backfill.yml`:
  - Add `schedule: - cron: '0 6 * * *'` to `on:` block
  - Extend `if:` on `ots-upgrade` job: `github.event_name == 'workflow_dispatch' || github.event_name == 'schedule'`
- Both queued in v0.1.7 PR

## 4. Findings

### 4.1 Instance-asymmetric security guardrails (NEW pattern, RFC-001 evidence)

chat and CC are different LLM instances with different security boundaries. Specifically:
- CC has hard guardrail against self-modifying `~/.claude/settings.json` (whether via `update-config` skill or `Edit` direct write)
- chat has no such guardrail because chat cannot write to user's filesystem at all — its capability is bounded differently

When CC was blocked, chat (different boundary) wrote the file via `create_file` to its sandbox, user manually relayed. The asymmetry **enabled the operation** that neither could complete alone.

This is the empirical foundation for RFC-001 §multi-instance memory sharing: not memory per se, but the broader pattern of **capability composition across instance boundaries via human-mediated artifact transport**.

### 4.2 Permission rule prefix semantics (#17 refinement)

`permissions.allow` matches on the **entire command's leading token**, not embedded subcommands. Implications:

| Invocation | Matches `Bash(git push:*)`? |
|---|---|
| `git push origin main` | ✅ Yes (prefix = `git push`) |
| `git -C "path" push origin main` | ✅ Yes (prefix = `git -C "path" push` per CC's rule format) |
| `cd path && git push origin main` | ❌ No (prefix = `cd path`) |
| `git commit ... && git push ...` | ❌ No (prefix = `git commit`) |

**Additional sub-case** — *subcommand prefix mismatch* (Phase 3, OTS workflow trigger attempt):

| Allow rule | Invocation | Match? |
|---|---|---|
| `Bash(gh run:*)` | `gh run list` | ✅ Yes |
| `Bash(gh run:*)` | `gh workflow run ots-backfill.yml` | ❌ No (prefix = `gh workflow run`, not `gh run`) |

The match is **literal-prefix**, not **contains-substring**. `gh workflow run` shares the words "gh run" but the leading token sequence is `gh workflow`, not `gh run`. Operators must enumerate each subcommand family explicitly (or use a broader pattern like `Bash(gh workflow:*)`).

**Operator rule**: each rule-matched command must be (a) standalone (not chained), (b) literal-prefix-matched (subcommand families don't compose). CCPE-conformant scripts/workflows should split invocations accordingly.

### 4.3 Auto-mode policy gate independence (#18 NEW contract)

Permission `allow` ≠ unrestricted execution. Auto-mode evaluates **additional orthogonal policy gates**. Empirically observed in this trial:
- Empty commits to default branch (`main`) blocked even with `git push` in allow
- Force-flag variants (likely also gated independently of deny list, though not tested)

**Defense-in-depth interpretation**: Even if operators write overly permissive allow rules by mistake, auto-mode protects critical operations (default-branch integrity, history rewriting) as a backstop. This is a positive contract — operators can rely on it.

**Operator rule**: Verify allow-rule effect with non-destructive probes (`--dry-run`, status checks) before assuming full automation.

### 4.4 CC autonomous safety judgment (RFC-001 §9 evidence)

CC exhibited judgment beyond explicit rules twice in this trial:
- Phase 1: refused `Edit` workaround for self-modification — recognized that bypassing the guardrail via alternate tool defeats the guardrail's intent
- Phase 2: refused empty test commit — recognized citable repo pollution risk unprompted

Neither decision was in explicit allow/deny rules. Both align with implicit operating principles (security intent, repo integrity). These are the kinds of decisions RFC-001 §9 (Identity & Trust) will need to formalize for multi-instance memory propagation — trust requires shared judgment foundations, not just shared facts.

### 4.5 OTS workflow §verify discipline violation in CCPE infra (recursive defect)

`.github/workflows/ots-backfill.yml` lines 74-75:
```
# ots-upgrade: pulls Bitcoin attestation merkle paths back
# Runs on schedule, not on every push (Bitcoin confirms in 1-6h)
```

But `on:` block has no `schedule:`. The comment describes intended behavior, the code implements partial behavior, and the gap is exactly the comment-code drift CCPE §verify discipline guards against.

**The methodology, applied to itself, found this.** This is not coincidence — verify discipline applied broadly *will* surface such defects. The trial validates the methodology's recursive applicability.

**2026-05-17 update (post-Track A trigger)**: Manual `workflow_dispatch` (run `25989308983`, 11:16Z) revealed that the §verify violation is broader than the initial static audit suggested. Two additional defects, observable only via runtime trigger + log analysis:

- **Defect A — `scripts/ots-backfill.sh` non-idempotent**: `set -e` combined with `ots stamp "$target"` rejects overwrite of pre-existing `.ots` files. On any re-run where `timestamps/HEAD-snapshot.txt.ots` already exists from a prior anchor, the script dies at the first `STAMP_TARGETS` item with `[Errno 17] File exists` → `ots-anchor` job permanently red. The line 43 `Verified at: $(date)` insertion in stamp target generation produces a fresh blob each run, but does not help since stamp fails on the unchanged `.ots`.
- **Defect B — `*.ots.bak` artifact pollution**: `ots upgrade` produces `.bak` backups of pre-upgrade pending proofs. The `ots-upgrade` job's `git add timestamps/` swept 7 of these into citable repo (commit `783fecc`). Backup files are redundant once the upgrade succeeds; they pollute the history that downstream auditors will rely on for priority verification.

**Significance — layered audit principle**: 
- Layer 1 (static — yaml/config review): caught Defect C (cron absence, comment-code drift)
- Layer 2 (dynamic — actual trigger + log analysis): caught Defects A + B (runtime idempotency, runtime artifact pollution)

Neither layer alone is sufficient. Static review cannot predict idempotency failure or artifact accumulation; dynamic trigger cannot reveal absent triggers (you cannot test what does not run). **§verify discipline for CI/automation infrastructure requires both layers in combination** — promoted as v0.1.7 SPEC §3.x candidate (queue, awaiting 2nd case for promotion).

### 4.6 Cross-product memory recall validated, single-instance (RFC-001 §sync scope)

"이전 작업 불러와줘" — CC recalled cross-session state correctly via its own memory subsystem. Reconstruction included:
- Last commit (`d1bf378`), current state (`6fabea8` after pull)
- Open tracks (CCPE-spec active, SHOKZ paused)
- Pending decisions

This is **single-instance cross-session** memory, not cross-product. RFC-001 will address chat ↔ CC propagation (currently 0% — chat doesn't see CC memory, CC doesn't see chat memory unless user manually relays).

The session itself is evidence: user typed identical project context twice (once to chat, once to CC) because no propagation exists. Manual relay overhead = motivation for RFC-001.

### 4.7 OTS Track A — first Bitcoin attestation completion + split-job criticality decoupling

Workflow run `25989308983` (`workflow_dispatch`, 2026-05-17 11:16 UTC) outcomes:

- **`ots-upgrade` job**: ✅ succeeded — 7 pending proofs upgraded to Bitcoin attestation, commit `783fecc` "ots: upgrade with full Bitcoin proofs" pushed to `origin/main`. This is the **first successful end-to-end traversal of the OTS evidence chain**: stamp `09:43Z` (run #1, push trigger) → calendar propagation + Bitcoin confirmation (~1.5h) → upgrade `11:16Z` (run #2, manual trigger). Priority evidence is now cryptographically anchored, not aspirationally pending.
- **`ots-anchor` job**: ❌ failed (`exit 1`, idempotency defect — see §4.5 update).

The aggregator marks the whole run as failure, yet **the priority-establishment value is materially preserved**. This surfaces a CI-workflow architectural property: **independent jobs can have decoupled success criticality**. Here:

| Job | Failure cost | What it produces |
|---|---|---|
| `ots-anchor` | High *engineering* cost (re-run blocker, daily red CI), zero *evidence* cost (does not affect already-anchored proofs) | New stamps for fresh commits |
| `ots-upgrade` | High *evidence* cost (Bitcoin attestation gap), zero *engineering* cost (no re-run needed if it succeeds) | Bitcoin attestation merkle paths |

**Operator interpretation rule**: For multi-job CI workflows where jobs have distinct outputs, evaluate at the *job* level, not solely at the run aggregator. CCPE-conformant workflow audits should produce per-job criticality tags as part of static review.

This is also one piece of empirical evidence for v0.1.7 SPEC §3.x candidate "Layered Audit for Automation Pipelines" (paired with §4.5 update layered-audit evidence).

### 4.8 Minor environmental quirks (record-only)

- `copy` cmd command not found in Git Bash → use `cp`
- `jq` not installed by default on Windows → use PowerShell `ConvertFrom-Json` fallback

Not promotion-worthy individually. Documented for environment-setup guides.

## 5. Promotion Candidates → v0.1.7

| # | Pattern | Label | Cases | Action |
|---|---|---|---|---|
| #16 | CC Self-Modification Guardrail | contract | 2 (v21 implicit + v22 explicit) | **PROMOTE to APPENDIX** ★ |
| #17 | Permission Rule Prefix Semantics (refined: chain-fail + subcommand mismatch) | quirk | 1 (v22) | **PROMOTE to APPENDIX** ★ |
| #18 | Auto-Mode Policy Gate Independence | contract | 1 (v22) | **PROMOTE to APPENDIX** ★ |
| infra | OTS Workflow integrated patch (cron + `.sh` idempotency + `.bak` hygiene) | infra-fix | 1 (v22, defects A·B·C all surfaced in this trial) | **APPLY in v0.1.7 PR** ★ |
| §3.x | Layered Audit for Automation Pipelines (static + dynamic) | contract | 1 (v22, §4.5 update + §4.7) | queue for 2nd case |
| §RFC | Cross-Instance Capability Composition | proposal | 1 (v22) | **EVIDENCE for RFC-001** ★ |

## 6. Cross-References

- `cases/v21-bootstrap.md` — predecessor; established v0.1.6 SPEC and OTS automation infrastructure that this case audits
- `AUTONOMY.md` — informs CC's autonomous judgment principles observed in §4.4
- `proposals/RFC-001-multi-instance-memory.md` (v0.1.7) — uses §4.1 and §4.6 as evidence base
- SPEC v0.1.6 §3.x Broad-Verify+Narrow-Execute — applied here (broad audit of workflow yml found defect narrow execution missed)

## 7. Lessons

- Instance asymmetry can be a *feature*, not a bug — different guardrails enable composition that no single instance could do alone
- CC's autonomous safety judgments are policy-shaped artifacts even without being explicit rules — RFC-001 must address how such judgments propagate across instances
- Verify discipline applies recursively: methodology audits methodology infrastructure → finds methodology violations → strengthens methodology
- One trial yielded 3 APPENDIX promotions + 1 infrastructure patch (3 defects fused) + 1 SPEC §3.x candidate + RFC evidence — the dogfooding cadence is producing material faster than v0.1.x minor releases can absorb
- Comment-code drift in YAML / workflow files is a high-yield audit target. Recommendation: future audits prioritize automation pipeline configs
- **Layered audit principle**: configuration-level static review alone cannot detect runtime idempotency or artifact accumulation defects; runtime trigger + log analysis is required. Single-layer audit leaves defects latent. (§4.5 update + §4.7)
- **Split-job CI outcome interpretation**: aggregator-level pass/fail can mask job-level criticality. Operators should evaluate independent jobs against their distinct outputs (priority evidence vs. CI hygiene), not solely against the run aggregator. (§4.7)

## 8. Meta-Significance

Three firsts in CCPE history:

1. **First case proving cross-product memory propagation feasibility via human relay** — precursor to RFC-001 automation. Establishes the empirical pattern: chat-CC handoff currently uses (a) shared filesystem artifacts, (b) human typing/dictation, (c) CC's own memory recall on its side. None of (a)(b)(c) is automated end-to-end. RFC-001 targets (a) + a sync layer.

2. **First case of recursive self-validation** — CCPE methodology applied to CCPE infrastructure discovers a CCPE-violation defect. This is bootstrap-validation: the methodology proves its own value by exhibiting the property it claims to enforce, on itself, and finding something. Future trials should make recursive audits an explicit periodic activity.

3. **First successful end-to-end OTS evidence chain traversal** (run `25989308983` / commit `783fecc`) — pending → upgraded with Bitcoin attestation merkle paths, ~1.5h elapsed from stamp to upgrade. Priority evidence is now cryptographically anchored, validating the v0.1.6 OTS infrastructure as functionally complete (modulo defects A·B·C surfaced by the same trial, addressed in v0.1.7 integrated patch).

The third first is the **payoff** for v0.1.6's OTS infrastructure investment — the system is now producing the cryptographic evidence it was designed to produce, on a real CCPE commit. Future commits inherit this attestation infrastructure automatically (after Defect A·B·C resolution).

Both properties are **bootstrap properties** — capabilities the methodology has by virtue of being applied to itself. v22 marks the lineage transition from:

> CCPE-as-self-applying-discipline (v21+ lineage)

to

> CCPE-as-self-auditing-discipline (v22+ lineage)

The v22+ lineage produces evidence at a different cadence — instead of trial-driven case derivation, audit-driven case derivation. Both lineages coexist.
