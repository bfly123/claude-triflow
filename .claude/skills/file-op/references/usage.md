# AutoFlow File-Op

Claude stays in **plan mode**. This command delegates **all repo file I/O** to Codex using the `FileOpsREQ` / `FileOpsRES` JSON protocol.

**Protocol**: See `../../docs/protocol.md`

---

## Input

From `$ARGUMENTS`:
- A single `FileOpsREQ` JSON object (must include `proto: "autoflow.fileops.v1"`).

---

## Execution

1. Validate `$ARGUMENTS` is a single JSON object (no prose).
2. Send to Codex:

```
Bash(cask "Execute this FileOpsREQ JSON exactly and return FileOpsRES JSON only:\n\n$ARGUMENTS", run_in_background=true)
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
