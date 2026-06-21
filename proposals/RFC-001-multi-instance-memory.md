# RFC-001 — Multi-Instance Judgment Continuity

> **Scope note**: This RFC was originally queued as "multi-instance memory" (see `SESSION-HANDOFF.md` item #5, `cases/v22-cross-product-memory.md` §6). Development revised the core thesis: the governing problem is **not** shared memory (facts across time) but **shared judgment** (decision criteria across concurrent instances). Filename retained as `RFC-001-multi-instance-memory.md` to preserve existing cross-references; title and content reflect the revised scope.

| Field | Value |
|---|---|
| RFC | 001 |
| Title | Multi-Instance Judgment Continuity |
| Status | **Draft** — evidence-gathering; targets SPEC §5 promotion |
| Author | eulpeul |
| Created | 2026-06-21 |
| Targets | v0.1.7 PR (proposal stage); SPEC §5 (candidate, post-evidence) |
| Evidence base | `cases/v21-bootstrap.md` §7.2/§7.4 · `cases/v22-cross-product-memory.md` §4.1/§4.4/§4.6 |
| Supersedes scope of | "multi-instance memory" framing in v22 §6 cross-ref |

---

## §1 Abstract

CCPE coordinates twin (or N) instances of the same model family. As coordination moves from **human-relay serialized** (the current state, evidenced in v21/v22) toward **live concurrent**, the binding constraint is not whether the instances share *facts* — that is a substrate problem, increasingly solved by retrieval layers (Obsidian, RAG) and per-runtime memory subsystems. The binding constraint is whether they share *judgment*: the operating principles, refusal criteria, and trust invariants under which a delegated action from instance A can be safely executed or extended by instance B.

This RFC defines **judgment continuity** as a distinct layer, situates it above the converging transport stack (MCP for tool access, A2A for agent-to-agent), and specifies a phased path from today's 0%-automated propagation to a synchronized judgment layer. The transport layers are **not** re-invented here; they are adopted as §1/§2 implementation candidates exactly as `PRIORITY.md` §Distinguishing Features anticipated.

## §2 Motivation — why judgment, not memory

The 2026 agent-interoperability stack has stabilized into transport + governance. MCP standardizes agent→tool access; A2A standardizes agent→agent coordination. Both are, by the explicit statements of their own specifications, transport mechanisms — they route tasks and context but do not govern the *quality* or *judgment basis* of what is routed. That gap — "who governs which agents may act, under what conditions, and on whose accountability" — is the unoccupied governance layer.

CCPE's white space is a **specific** corner of that layer: not heterogeneous multi-vendor orchestration under compliance/authority (the enterprise framing), but **same-model N-instance coordination under shared operational judgment**. The distinction matters because it changes the mechanism:

- Enterprise governance substitutes **external authority** for shared judgment (enforced workflows, approval gates, on-chain separation-of-powers contracts). Trust is imposed from outside the agents.
- CCPE's bet is **shared judgment foundations** — instances that operate from the same evolving criteria, so that trust between them is *intrinsic*, not externally policed.

The empirical seed already exists. In v22 §4.4, CC refused to elevate its own permissions — and refused the alternate-tool workaround — **unprompted**, articulating that bypassing a guardrail via a different tool defeats the guardrail's intent. That refusal was not in any explicit allow/deny rule. It was a judgment artifact. Judgment continuity asks: how does *that* propagate across instances, so that instance B inherits not just A's facts but A's refusal criteria?

## §3 The layering (2026 stack, CCPE position)

```
┌─────────────────────────────────────────────────────────┐
│  CCPE judgment layer  (this RFC)                         │  ← unoccupied; CCPE's corner
│  Role Charter · Failure Protocol · Context Distribution  │
│  + judgment invariants (refusal criteria, trust basis)   │
├─────────────────────────────────────────────────────────┤
│  §2 Command Bus    →  A2A   (agent↔agent transport)      │  ← adopt, don't reinvent
│  §1 Shared State   →  context layer  (Obsidian + sync)   │  ← adopt, don't reinvent
├─────────────────────────────────────────────────────────┤
│  MCP  (agent↔tool access)                                │  ← already in use
├─────────────────────────────────────────────────────────┤
│  Execution runtimes: Claude Code · Hermes+LM Studio · …  │  ← instances
└─────────────────────────────────────────────────────────┘
```

**Adoption decisions** (each provable as a §1/§2 implementation candidate, not a CCPE redefinition):

| CCPE element | Implementation candidate | Rationale |
|---|---|---|
| §2 Command Bus | A2A (Linux Foundation standard) | de-facto agent↔agent transport; HTTP+SSE+JSON-RPC; broad framework support. Reinventing it isolates CCPE from the ecosystem. |
| §1 Shared State | Context layer (Obsidian vault + sync) | the "governed shared context" substrate both transports run on but neither provides. |
| tool access | MCP | already the foundation layer; CCPE instances already use it. |

CCPE itself remains the **discipline above** these — it is not any of them. This is the `PRIORITY.md` thesis, now made concrete against named 2026 standards.

## §4 Problem statement — what concurrency breaks

Human-relay coordination (v21/v22) has one accidental virtue: it **serializes** everything. Only one instance acts at a time; the human is a sequential lock. Live concurrency removes that lock and surfaces problems the relay model never hit:

1. **State write conflicts** — two live instances writing shared state simultaneously. Never observed in v21/v22 because relay serialized writes. Requires an explicit consistency discipline.
2. **Judgment divergence** — instance A and instance B reach different refusal/safety conclusions on the same input because their judgment basis is not synchronized. A2A will happily route a task A considers unsafe to a B that does not.
3. **Stale-judgment propagation** — a superseded judgment (e.g. a retired anti-pattern) still active in one instance after the other has updated. Analogous to the comment-code drift CCPE §verify already guards against, but for *judgment* rather than *code*.

## §5 The judgment-continuity model

Define two sharable classes, deliberately separated:

- **Facts** — project state, commit hashes, file contents, prior decisions. Substrate-layer; delivered by §1 Shared State (Obsidian/context layer). Already partially solved.
- **Judgment** — the criteria by which an instance decides *whether* and *how* to act:
  - **Operating principles** — e.g. AUTONOMY.md §Default/§Exceptions; "verify, don't assume."
  - **Refusal criteria** — e.g. self-permission-elevation guardrail (#16); citable-repo-pollution avoidance (v22 §4.4); soft-delete-never-hard-rm.
  - **Trust invariants** — the conditions under which a delegation from another instance may be executed without re-deriving its safety.

**Continuity claim**: two instances are judgment-continuous iff, given identical facts, they reach identical *act / refuse / escalate* decisions. Memory continuity is necessary (shared facts) but not sufficient (shared facts + divergent criteria → divergent action).

This reframes RFC-001's target from "sync the memory" to "sync the criteria, and prove the criteria converge."

## §6 State consistency (the concurrency discipline)

Required before any live-concurrent write path:

- **Idempotent contracts extended** — APPENDIX #10 (Cleanup Idempotent Contract) generalizes from single-instance cleanup to concurrent writes: a write must be safe to apply, re-apply, or apply-after-peer without corrupting shared state.
- **Broad-verify + narrow-execute (SPEC §3.x)** applied to concurrency — each instance executes a narrow scope but verifies the broad shared state, catching peer-induced drift. This is the same asymmetry that caught the OTS defect in v22, now used to catch concurrent-write conflicts.
- **Lease before write** (proposed) — an instance acquires a short lease on a shared-state region before writing; conflicting leases escalate to the human (Phase ≤1) or to a deterministic resolution rule (Phase ≥2). Concrete mechanism deferred to implementation; the *contract* is what this RFC fixes.

## §7 Identity & Trust  ★ (the core)

This is the section the rest of the RFC exists to support, and the part with no equivalent in A2A/MCP.

**Trust requires shared judgment, not shared facts.** A2A authenticates *who* an agent is (signed agent cards) and routes *what* task; it does not establish that the receiver shares the sender's judgment basis. For same-model twin instances the authentication problem is trivial (same model family, operator-controlled); the **judgment-basis problem** is the hard one and the novel one.

Formalization targets:

1. **Judgment manifest** — an explicit, versioned declaration of an instance's operating principles, refusal criteria, and trust invariants. Derived from sources already in the repo: AUTONOMY.md, the contract-class APPENDIX entries (#10, #16, #18), and case-derived autonomous judgments (v22 §4.4). The manifest is the unit of judgment that propagates.
2. **Convergence check** — before two instances enter a concurrent path, each verifies the other's judgment manifest version matches (or is a compatible superset of) its own. Mismatch → no concurrent delegation; fall back to relay or escalate.
3. **Judgment promotion** — when an instance exhibits a novel autonomous judgment (as CC did in v22 §4.4), it enters the existing case → APPENDIX → SPEC pipeline **as judgment**, not merely as a quirk/contract about platform behavior. Promotion updates the manifest; the manifest version bump is what tells peers their judgment basis has moved.

**Why this is "세상에 없는 것"**: the enterprise stack solves trust by *external enforcement* (authority contracts, approval gates). CCPE proposes trust by *shared, versioned, promotable judgment* between instances of the same model. No transport protocol provides this; no enterprise governance layer targets the same-model-twin case. It is the corner CCPE has occupied since before the 2026 convergence made the corner visible.

## §8 Phased rollout (long-term stability, staged growth)

Per project doctrine, no concurrency before the discipline that makes it safe.

| Phase | State | Sync scope | Gate to next |
|---|---|---|---|
| **0** (current) | Human-relay serialized | 0% automated; facts via manual typing + per-runtime memory recall | v21/v22 documented ✓ |
| **1** | Shared artifact layer | §1 Shared State live (Obsidian vault as substrate); handoff standardized; judgment manifest authored (static) | manifest convergence check passes manually |
| **2** | A2A command bus | §2 over A2A; near-concurrent → concurrent transport; lease-before-write contract active | state-consistency discipline (§6) validated under concurrent writes |
| **3** | Judgment propagation | judgment manifest auto-synchronized; convergence check automated; judgment promotion bumps manifest across instances | — (research frontier; this RFC's terminus) |

Phase 0→1 is buildable now and depends on nothing external. Phase 2 rides A2A as it matures. Phase 3 is the open research target and where CCPE's distinct contribution concentrates.

## §9 Non-goals

- **Not** re-implementing MCP/A2A transport. They are adopted, not rebuilt.
- **Not** an enterprise compliance/authority layer. CCPE governs by shared judgment, not external enforcement. Different mechanism, different audience.
- **Not** single-instance memory persistence. That is the substrate (Obsidian, Hermes SQLite/FTS5 memory) — explicitly out of scope and explicitly *relied upon*.
- **Not** a general multi-vendor multi-model orchestration spec. CCPE's scope is same-model N-instance; the narrowness is the moat.

## §10 Boundary with execution-runtime self-improvement

Execution runtimes (Hermes, and analogously Claude Code) carry their own memory and self-improvement loops (e.g. trace-driven skill optimization). To avoid layer collision:

- **Runtime self-improvement** optimizes an instance's *execution* skills internally. Stays inside the instance.
- **CCPE judgment continuity** governs *cross-instance* coordination judgment. Lives in the layer above.

Keep them clean: a runtime improving how it opens a PR is execution; two instances agreeing on whether a push is safe is coordination judgment. The case → APPENDIX → SPEC pipeline governs the latter only.

## §11 Open questions

1. Manifest granularity — per-principle versioning, or whole-manifest version bumps?
2. Convergence on *compatible-superset* manifests — when is B's richer judgment safe to pair with A's, vs when does the asymmetry itself require escalation?
3. Lease conflict resolution at Phase ≥2 — deterministic rule vs human escalation; which classes of shared state tolerate which?
4. Does judgment promotion need a stricter evidence bar than platform-quirk promotion? (A wrong judgment propagates harm; a wrong quirk note is merely noise.)
5. Failure Protocol (SPEC §4) under concurrency — when a peer hangs mid-lease, recovery semantics?

## §12 Promotion path

- This RFC ships in v0.1.7 as `proposals/RFC-001-multi-instance-memory.md` (proposal status — no SPEC change yet).
- Evidence accrues from Phase 1 dogfooding (manifest authoring + manual convergence checks).
- On ≥2 cases demonstrating judgment-manifest convergence preventing a divergent action, promote the model to **SPEC §5 (Judgment Continuity)** under the standard promotion discipline. Contract-class elements (manifest, convergence check) follow the 1-case rule for positive contracts; the lease/consistency mechanisms follow the 2-case quirk rule.

## §13 Cross-references

- `PRIORITY.md` §Distinguishing Features — the "any comms tool is at most a §1/§2 implementation" thesis this RFC operationalizes against A2A/MCP.
- `AUTONOMY.md` — primary source for the operating-principles portion of the judgment manifest.
- `cases/v21-bootstrap.md` §7.2 (naming-convention drift), §7.4 (broad-verify+narrow-execute) — concurrency-discipline ancestry.
- `cases/v22-cross-product-memory.md` §4.1 (capability composition across instance boundaries), §4.4 (CC autonomous judgment — the judgment-artifact seed), §4.6 (single-instance cross-session recall — the substrate this RFC builds atop).
- `APPENDIX-PLATFORM-QUIRKS.md` #10, #16, #18 (contract-class entries feeding the judgment manifest).
- SPEC §3.x Broad-Verify+Narrow-Execute, §4 Failure Protocol — applied under concurrency in §6/§11.

---

## Meta

RFC-001 marks the point where CCPE's thesis stops being only retrospective (case-derived discipline) and becomes **forward-specifying**: it names a layer the 2026 stack left open, claims a specific corner of it (same-model N-instance, judgment-based trust), and stages a buildable path there. The lineage note:

> CCPE-as-self-auditing-discipline (v22+)

extends to

> CCPE-as-forward-specifying-discipline (RFC-001+)

— the discipline now proposes structure ahead of the evidence, then holds itself to its own promotion bar before that structure enters SPEC.
