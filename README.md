# fromeulpeul
created by eulpeul

# CCPE — Connect Prompt Engineering

> A coordination pattern for two instances of the same model family
> (e.g. Claude Chat + Claude Code) operating in parallel through
> shared state, role distribution, and failure recovery.

---

## What

**Connect Prompt Engineering (CCPE)** is the discipline of designing prompt protocols that let multiple instances of the same model family operate as a coordinated pair — not as independent sessions, not as multi-agent orchestration of different models, but as **twin instances with divided cognitive load**.

One instance handles strategy, interpretation, and long-term memory. The other handles execution, raw I/O, and tool calls. They share state through an external bus, exchange commands through a structured format, and recover from each other's failures.

## Why

Existing patterns don't address this:

- **Multi-agent orchestration** assumes different roles or different models
- **Prompt chaining** is sequential, not concurrent
- **Multi-session memory** is single-instance persistence
- **Agent harness** governs one agent's behavior, not pairs

CCPE fills the gap: **same model, two instances, real-time coordination**.

## The 5 Core Elements

1. **Shared State Layer** — an external store both instances can read/write (event bus, spreadsheet, database)
2. **Command Bus** — structured command queue: instance A pushes, instance B polls and responds
3. **Role Charter** — explicit division of responsibilities written into both system prompts
4. **Failure Protocol** — when one instance hangs or errors, the other detects and recovers
5. **Context Distribution** — token budget split: strategy context vs execution context never share the same window

## The 7-Block Command Standard

When the strategy instance issues a command to the execution instance, the message must contain seven blocks in order:

1. **Autonomy mode** — always-on, no mid-flight confirmations, single raw response
2. **Variables** — constants, candidate arrays, thresholds, paths, deploy descriptions
3. **Synthesis spec** — function bodies inline, allowlist mappings, file locations
4. **Execution sequence** — push, deploy, calls, parallel greps
5. **Branch tree** — automatic handling of all possible outcomes (A/B/C/D/E/F)
6. **Safety guards** — block conditions, try/restore, automatic backups
7. **Expected result + return format** — numerical predictions, raw fields

This format eliminates the human as a relay and enables fully autonomous round-trips.

## Reference Architecture

```
┌──────────────────┐      Command Bus       ┌──────────────────┐
│                  │ ─────────────────────▶ │                  │
│  Strategy        │   (Event Bus / D1)     │  Execution       │
│  Instance        │                        │  Instance        │
│  (Chat)          │ ◀───────────────────── │  (Code)          │
│                  │     Result Stream      │                  │
└────────┬─────────┘                        └─────────┬────────┘
         │                                            │
         │           Shared State Layer               │
         │       (Spreadsheet / Database)             │
         └─────────────────────┬──────────────────────┘
                               ▼
                        Role Charter
                       Failure Protocol
                     Context Distribution
```

## Status

This specification is in early development. Contributions, critique, and reference implementations welcome.

## Author

Originally formulated in 2026.

## License

MIT — see [LICENSE](LICENSE)
