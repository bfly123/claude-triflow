# AutoFlow Communication Protocol

This protocol is designed for the "Claude stays in plan mode, Codex does all file I/O" architecture.

---

## FileOpsREQ (Claude → Codex)

Codex executes a list of explicit operations (`ops`) and returns `FileOpsRES`.

```json
{
  "proto": "autoflow.fileops.v1",
  "id": "S2",
  "purpose": "execute_step|write_plan_files|finalize_step|read_state|split_step",
  "summary": "1 sentence intent for humans",
  "constraints": {
    "no_network": false,
    "writable_roots": ["."],
    "max_attempts": 2
  },
  "done": ["condition 1", "condition 2"],
  "ops": [
    { "op": "read_file", "path": "state.json" },
    { "op": "write_file", "path": "todo.md", "content": "..." },
    { "op": "write_json", "path": "state.json", "value": { "k": "v" } },
    { "op": "apply_patch", "patch": "*** Begin Patch\\n*** Update File: a.txt\\n@@\\n-Old\\n+New\\n*** End Patch\\n" },
    { "op": "run", "cmd": "pytest -q", "cwd": ".", "timeoutMs": 600000 }
  ],
  "report": {
    "changedFiles": true,
    "diffSummary": true,
    "commandOutputs": "on_failure|always|never"
  }
}
```

---

## FileOpsREQ Validation Schema

### Required Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| proto | string | ✓ | Must be "autoflow.fileops.v1" |
| id | string | ✓ | Unique request ID (e.g., "TR-PREFLIGHT") |
| purpose | enum | ✓ | One of: execute_step, write_plan_files, finalize_step, read_state, split_step |
| summary | string | ✓ | 1-sentence intent (max 100 chars) |
| done | string[] | ✓ | At least 1 done condition |
| ops | object[] | ✓ | At least 1 operation |
| report | object | ✓ | Report configuration |

### Optional Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| constraints | object | {} | Execution constraints |
| constraints.no_network | bool | false | Disallow network access |
| constraints.writable_roots | string[] | ["."] | Allowed write paths |
| constraints.max_attempts | int | 2 | Max retry attempts |

### ops[] Validation

Each op must have:
- `op`: string (required) - operation type

**Standard ops:**

| op | Required fields | Optional fields |
|----|-----------------|-----------------|
| read_file | path | - |
| write_file | path, content | - |
| write_json | path, value | - |
| apply_patch | patch | - |
| run | cmd | cwd, timeoutMs |

**AutoFlow domain ops:**

| op | Required fields | Optional fields |
|----|-----------------|-----------------|
| autoflow_plan_init | plan | - |
| autoflow_state_preflight | path | maxAttempts |
| autoflow_state_apply_split | stepIndex, substeps | - |
| autoflow_state_finalize | verification | changedFiles |
| autoflow_state_mark_blocked | reason | - |
| autoflow_state_append_steps | steps | maxAllowed |

### report Validation

| Field | Type | Values |
|-------|------|--------|
| changedFiles | bool | true/false |
| diffSummary | bool | true/false |
| commandOutputs | enum | "on_failure" \| "always" \| "never" |

### Validation Errors

On validation failure, return before execution:

```json
{
  "proto": "autoflow.fileops.v1",
  "id": "<from request>",
  "status": "validation_error",
  "errors": [
    { "field": "purpose", "error": "invalid value 'do_thing', must be one of: ..." },
    { "field": "ops[0].path", "error": "required field missing" }
  ]
}
```

### Supported `ops`

- `read_file`: returns file content (use sparingly; prefer summaries for large files)
- `write_file`: overwrite full content
- `write_json`: write JSON value (pretty-printed, stable key ordering if possible)
- `apply_patch`: apply `apply_patch`-format patch
- `run`: run a shell command

### AutoFlow domain `ops` (recommended)

These ops let Codex update `todo.md` / `state.json` / `plan_log.md` without Claude constructing full file contents.

- `autoflow_plan_init`
  - input: `plan` (taskName, objective, context, constraints, steps[], finalDone[])
  - effect: writes `todo.md`, `state.json`, `plan_log.md`
- `autoflow_state_preflight`
  - input: `path` (default `state.json`), `maxAttempts`
  - effect: loads state, validates `current`, increments attempts if allowed, persists state
  - output (in `data`): current step/substep context and a compact state summary
- `autoflow_state_apply_split`
  - input: `stepIndex`, `substeps` (3-7 titles)
  - effect: writes substeps into `state.json`, regenerates `todo.md`
- `autoflow_state_finalize`
  - input: `verification` (short), `changedFiles` (optional)
  - effect: marks current step/substep done, advances `current`, regenerates `todo.md`, appends `plan_log.md`
  - note: the recommended `TR-FINALIZE` request adds a best-effort git commit after finalization:
    ```json
    { "op": "run", "cmd": "git add -A && git commit -m \"Step {{stepIndex}}: {{stepTitle}}\" --allow-empty || true", "cwd": "." }
    ```
    - placeholders:
      - `{{stepIndex}}`: step number (prefer 1-based; if state uses 0-based index, use `stepIndex + 1`)
      - `{{stepTitle}}`: step title
- `autoflow_state_mark_blocked`
  - input: `reason` (short)
  - effect: marks current step/substep blocked, regenerates `todo.md`, appends `plan_log.md` (optional)
- `autoflow_state_append_steps`
  - input: `steps` (1-2 titles), `maxAllowed` (default 2)
  - precondition: `current.type == 'none'` (task completed)
  - effect: appends steps to `state.json`, sets `current` to first new step, regenerates `todo.md`, appends to `plan_log.md`
  - error: if `steps.length > maxAllowed`, return `fail` with suggestion to create follow-up task
- `autoflow_auto_loop` (explicit `run`-based)
  - goal: reliably trigger the next `/tr` without requiring Codex to "understand" a domain op
  - recommended op:
    ```json
    { "op": "run", "cmd": "python3 ~/.claude/skills/tr/scripts/autoloop.py --repo-root . --once", "cwd": ".", "timeoutMs": 600000 }
    ```
  - behavior (implemented by `~/.claude/skills/tr/scripts/autoloop.py`):
    1) loads `state.json` and checks whether there are remaining steps
    2) reads the latest Claude session JSONL under `~/.claude/projects/<project-dir>/*.jsonl` (excluding `agent-*.jsonl`)
    3) finds the latest record with `message.usage` and estimates current context window using:
       - `usage.prompt_tokens` if present, else
       - `usage.input_tokens + usage.cache_creation_input_tokens + usage.cache_read_input_tokens` (plus prompt-token cache fields if present)
    4) gets `context_limit` from `~/.claude/ccline/models.toml` (pattern match) or falls back to `--context-limit`
    5) if usage% > 70%: runs `sleep 5 && lask '/clear' && sleep 2 && lask '/tr'`
       else: runs `sleep 5 && lask '/tr'`
    6) if no remaining work: returns without triggering (task complete)
  - note: `--once` prints a 1-line JSON summary to stdout (usable as `proof`)
  - output (in `data`): `taskComplete`, `next` (optional summary)

---

## FileOpsRES (Codex → Claude)

```json
{
  "proto": "autoflow.fileops.v1",
  "id": "S2",
  "status": "ok|ask|fail|split",
  "changedFiles": ["todo.md", "state.json"],
  "data": {
    "state": { "current": { "type": "step", "stepIndex": 2, "subIndex": null } },
    "stepContext": "compact context for /dual-design"
  },
  "ops": [
    { "opIndex": 0, "status": "ok", "summary": "read state.json (1442 bytes)" },
    { "opIndex": 1, "status": "ok", "summary": "wrote todo.md" }
  ],
  "proof": {
    "commands": [
      { "cmd": "pytest -q", "exitCode": 0, "stdout": "", "stderr": "" }
    ],
    "notes": "verification evidence"
  },
  "split": { "substeps": [] },
  "ask": { "questions": [] },
  "fail": { "reason": "why failed", "hint": "how to fix" }
}
```

**IMPORTANT**: Codex must output ONLY JSON (no markdown, no prose) when responding to FileOpsREQ.

---

## Status Meanings

| status | meaning | required fields |
|--------|---------|-----------------|
| ok | success | `changedFiles`, `ops`, `proof` |
| split | need substeps | `split.substeps` |
| ask | need user info | `ask.questions` |
| fail | failed | `fail.reason` |

---

## Guardrails

| Rule | Value |
|------|-------|
| Max attempts per step | 2 |
| Max substeps | 3-7 |
| Max fix iterations | 1 |
| Substep refinement | 1 retry |

---

## cask Usage

Send FileOpsREQ:
```
/file-op <FileOpsREQ JSON>
```

Wait for response:
```
(handled by `/file-op`)
```

---

## Auto-Loop (Optional)

After step completion, delegate to Codex:
```
Bash(cask "Send /clear and /tr to Claude pane via lask.", run_in_background=true)
```
