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
