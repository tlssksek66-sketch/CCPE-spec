# 7-Block Command Template

Use this format for every command from strategy → execution.

```
═══════════════════════════════════════════════════════════
[Title] — [one-line summary]
═══════════════════════════════════════════════════════════

[1] Autonomy mode
- always-on yes / non-interrupting / auto deploy / single raw return

[2] Variables
- CONST_X = ...
- CANDIDATES = [...]
- THRESHOLD = ...
- PATH = ...
- DEPLOY_DESC = "..."

[3] Synthesis spec
- File: <path>
- Function body inline
- Allowlist additions

[4] Execution sequence
$ command1
$ command2
$ command3

[5] Branch tree
- A. <condition> → <action>
- B. <condition> → <action>
- C. <condition> → <action>
- D. <condition> → <action>

[6] Safety guards
- BLOCKED if <cond>
- restore <var> on exception
- backup <target> automatic

[7] Expected result + return format
- predicted_metric: <value>
- return fields: [...]
- raw report JSON
```

## Why this format

- Eliminates the human as relay between instances
- Forces explicit branch handling (no mid-flight clarification)
- Standardizes safety guards across all commands
- Makes raw return parseable by strategy instance
