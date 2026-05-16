# CCPE Priority Declaration

## Originating Authorship

**Connect Prompt Engineering (CCPE)** was originally formulated, named, and developed by **eulpeul** in 2026.

The concept emerged from sustained operational work on twin-instance LLM coordination in production data sync automation (anonymized as "K-brand operational track" across the `cases/` directory). The discipline — including its 5 structural elements, 7-block command standard, role charter, failure protocol, context distribution rule, and the case-driven promotion pipeline (APPENDIX → SPEC) — represents an originating contribution distinct from adjacent patterns documented below.

## Timeline of Record

| Date (UTC) | Milestone | Evidence |
|---|---|---|
| 2026-05-04 | v19-b5 case — first documented twin-instance recovery from partial failure (6-min hard-limit + clear-then-write anti-pattern) | `cases/anonymized-v19b5.md` |
| 2026-05-04 | Initial idempotent cleanup contract observation | retro-promoted to APPENDIX #10 (v0.1.5) |
| 2026-05-06 | v20-a1 case — split reload, row cap silent overflow, strict-equality verify header matching | `cases/anonymized-v20-a1.md` |
| 2026-05-06 | v20-g2 case — workbook cell cap, requireNonEmpty guard missing, contract label discipline introduced | `cases/v20-g2.md` |
| 2026-05-08 | **SPEC v0.1.5 release** — formalized §2.x Verify Round-Trip, §3 Boundary Enforcement, §4 Hard-Limit Anti-Pattern; APPENDIX expanded with #8/#9/#10 (label-mixed: 2 quirks + 1 contract) | `release_notes/v0.1.5.md` |
| 2026-05-16 | Authorship and priority formally declared; CCPE established as separate project (lifted out of operational context for formal development) | This document |

Continuing development proceeds **alongside** the originator's production automation work — i.e., CCPE evolves through ongoing dogfooding, not retrospective documentation.

## Verification Infrastructure

Independent verification of priority is supported by:

- **Git commit history** — immutable SHA-256 hash chain across all commits
- **OpenTimestamps anchoring** (planned, backfill all existing commits) — Bitcoin blockchain timestamping, sub-day resolution, sub-second economic cost
- **Zenodo DOI** (planned, GitHub-Zenodo integration) — academic-citable archival snapshot per release
- **arXiv preprint** (planned, cs.AI) — academic priority standard
- **Korean Copyright Registry registration** (planned) — legal presumption of authorship date
- **Trademark "CCPE"** (planned, Korean Intellectual Property Office, classes 9 / 41 / 42)
- **This declaration document** (effective from publication commit)

## Distinguishing Features

CCPE is **not** any of the following, despite occasional surface resemblance:

| Adjacent pattern | Distinction from CCPE |
|---|---|
| **Multi-agent orchestration** | Assumes different roles or different models. CCPE assumes same model family, two instances with explicit cognitive role division. |
| **Inter-session communication plugins** (e.g., Claude Code-to-Claude Code messaging tools) | Provide plumbing for SPEC §1 (Shared State Layer) or §2 (Command Bus) only. CCPE additionally specifies role charter, failure protocol, context distribution, boundary enforcement, and promotion governance — the *discipline* layer. |
| **Prompt chaining** | Sequential single-instance pattern. CCPE is concurrent twin-instance coordination. |
| **Multi-session memory** | Single-instance persistence across sessions. CCPE is two-instance coordination within or across sessions. |
| **Agent harness frameworks** | Govern one agent's behavior. CCPE governs the *pair* and the *protocol between them*. |

The originating contribution is the **discipline + specification** layer (methodology, governance, promotion criteria, role charter), not any single implementation primitive. Any inter-instance communication tool that exists or may exist is — at most — one candidate implementation of CCPE §1 or §2; not CCPE itself.

## Citation

Machine-readable: see `CITATION.cff`.

Prose:

> eulpeul (2026). *Connect Prompt Engineering (CCPE) Specification v0.1.5*. GitHub: `tlssksek66-sketch/fromeulpeul`. https://github.com/tlssksek66-sketch/fromeulpeul

## License vs. Attribution — Important Distinction

The CCPE specification is released under MIT License (see `LICENSE`). This grants free use including commercial use, modification, and redistribution.

**Originating authorship is a separate matter from license grant.** MIT does not transfer authorship attribution rights. Authorship of CCPE remains with the originator named above in perpetuity, regardless of how broadly the specification is used, implemented, forked, or commercialized.

Users implementing CCPE-conformant systems are encouraged but not required to cite this specification. Commercial implementations are permitted under MIT terms. Misrepresentation of authorship is not permitted.

## Contact

For collaboration, consulting, certification inquiries, or formal communications regarding priority/attribution:

- GitHub: [`tlssksek66-sketch/fromeulpeul`](https://github.com/tlssksek66-sketch/fromeulpeul) (Issues / Discussions)
- Additional channels: [FILL IN — to be added as established]

---

**Effective date**: 2026-05-16
**Document version**: 1.0
