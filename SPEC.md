# CCPE Specification v0.1

## 1. Shared State Layer

An external read/write store accessible by both instances.

Requirements:
- Append-only logging preferred (replay/audit)
- Authentication per instance
- Sub-second latency for command polling

Reference implementations:
- Cloudflare Workers + D1 (lightweight)
- Google Sheets via API (familiar)
- Redis / Postgres (production)

## 2. Command Bus

Structured message queue between instances.

Schema:

```json
{
  "id": "uuid",
  "source": "strategy|execution",
  "ts": "ISO8601",
  "type": "command|result|error",
  "payload": {}
}
```

Polling cadence: strategy 1×/turn, execution 5min cron or webhook.

## 3. Role Charter

Explicit responsibilities written into each instance's system prompt.

Example division:
- **Strategy**: planning, interpretation, long-term memory, user communication, error diagnosis
- **Execution**: tool calls, raw I/O, environment commands, retries

The charter must be **mutual** — each instance knows the other's role.

## 4. Failure Protocol

When one instance fails:
- Timeout threshold: e.g. 5 min for execution polling
- Notification channel: Slack DM or equivalent
- Recovery action: re-issue command / fallback / human escalation

Both instances must implement detection on their counterpart.

## 5. Context Distribution

### Verify Round-Trip Rule

Verify commands MUST be issued as separate round-trips by the strategy instance, not bundled as sub-steps within an execution command.

Rationale: prevents intra-context confirmation bias on partial-write modes. Execution instance verifying its own write within the same context window cannot detect silent partial-write failures that an independent strategy-side verify would catch.
Token budgets are explicitly partitioned:
- Strategy instance: high-level memory, rules, user history
- Execution instance: raw command + immediate environment + recent results

Long-term memory belongs to strategy. Execution treats each command as near-stateless to maximize raw output capacity.

### Boundary Enforcement

On boundary violation — when a command falls outside the receiving instance's chartered role — the receiving instance MUST refuse and request routing clarification, not execute via implicit role extension.

Rationale: implicit self-extension to fulfill misrouted commands collapses the instance separation CCPE depends on. Refusal is correct spec behavior.

### Hard-Limit + Clear-Then-Write Anti-Pattern

When the execution platform enforces a per-invocation time limit (server-side hard limit), do not combine clearing operations with full re-write within a single invocation. Split the operation into smaller units that each fit safely under the limit.

Rationale: timeout mid-clear-and-write produces partial-state corruption. Auto-backup mitigates but does not eliminate the corruption surface — the surface is wider than the backup window. Reproduced across multiple cases (reload-stage and verify-rule-change-stage timeouts share the same class).
