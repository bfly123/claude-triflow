# AutoFlow File-Op

Claude stays in **plan mode**. This command delegates **all repo file I/O** to Codex using the `FileOpsREQ` / `FileOpsRES` JSON protocol.

**Protocol**: See `~/.claude/skills/docs/protocol.md`

---

## Input

From `$ARGUMENTS`:
- A single `FileOpsREQ` JSON object (must include `proto: "autoflow.fileops.v1"`).

---

## Execution

1. Validate `$ARGUMENTS` is a single JSON object (no prose).
2. Send to Codex (executor-aware):

```
Bash(cask "Execute this FileOpsREQ JSON exactly and return FileOpsRES JSON only.\n\n## CRITICAL: Roles Self-Resolution (Hard Constraint)\nYou MUST read roles config yourself to determine executor. Do NOT rely on Claude passing constraints.executor.\n\nRoles priority (first valid wins):\n1. .autoflow/roles.session.json\n2. .autoflow/roles.json\n3. ~/.config/cca/roles.json\n4. Default: executor=codex\n\nValidation: schemaVersion=1, enabled=true; otherwise skip to next.\n\n## Executor Routing\n- executor=codex (or missing): execute ops directly.\n- executor=opencode:\n  - Do NOT directly edit repo files yourself.\n  - Supervise OpenCode via oask to perform file changes.\n  - Translate ops into clear OpenCode instructions, request execution, validate results.\n  - Ask OpenCode to return: {changedFiles, diffSummary, commands, notes}.\n  - If insufficient, iterate (max constraints.max_attempts or 3).\n  - Return valid FileOpsRES JSON (status ok/ask/fail/split).\n- executor=codex+opencode:\n  - Same as executor=opencode above.\n  - You are the SUPERVISOR: refine tasks, delegate via oask, review results.\n\n$ARGUMENTS", run_in_background=true)
TaskOutput(task_id=<task_id>, block=true)
```

3. Validate the response is JSON only and matches `proto`/`id`.
4. Dispatch by `status`:
   - `ok`: return the JSON to the caller
   - `ask`: surface `ask.questions`
   - `split`: surface `split.substeps`
   - `fail`: surface `fail.reason` and stop

---

## Principles

1. **Claude never edits files**: all writes/patches happen in Codex
2. **JSON-only boundary**: request/response must be machine-parsable
3. **Prefer domain ops**: use `autoflow_*` ops for state/todo/log updates
