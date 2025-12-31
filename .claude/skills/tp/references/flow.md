# AutoFlow Plan

Create executable plan artifacts: `todo.md` + `state.json` + `plan_log.md`

**File formats**: See `../../docs/formats.md`
**Protocol**: See `../../docs/protocol.md`

---

## Architecture Note

- Claude stays in **plan mode** for the entire workflow (planning + review only).
- **All file I/O (create/modify)** is executed by **Codex** via `FileOpsREQ` / `FileOpsRES`.
- This command must never directly write files; it only prepares the plan content and delegates writes to Codex.

---

## Execution Flow

### 1. Initialize
- Get requirement from `$ARGUMENTS`
- Analyze project: tech stack, key files, background
- If requirement involves unfamiliar technologies/APIs/libraries, use WebSearch/WebFetch to review official docs + best practices before finalizing the plan

### 2. Dual Design (Plan)

Invoke `/dual-design` skill:

```
design_type: plan
requirement: [from $ARGUMENTS]
context: [tech stack, key files, background]
```

This executes:
1. Claude independent plan design
2. Codex independent plan design
3. Merge discussion (2-3 rounds)

Returns merged plan with: goal, nonGoals, steps, acceptance.

### 3. User Confirmation

Show final merged plan:

```
## Plan Summary

**Goal**: [goal]
**Non-goals**: [non-goals]

**Steps** (N total):
1. [S1 title]
2. [S2 title]
...

**Acceptance**:
- [done 1]
- [done 2]

**Review notes**: [key decisions from merge discussion]

Confirm? (Y/adjust)
```

### 4. Save Files

After user confirms, delegate file creation to `/file-op` using `FileOpsREQ`:

Call:

```json
{
  "proto": "autoflow.fileops.v1",
  "id": "TP",
  "purpose": "write_plan_files",
  "summary": "Initialize todo.md/state.json/plan_log.md from confirmed plan",
  "done": ["Plan files exist and match formats"],
  "ops": [
    {
      "op": "autoflow_plan_init",
      "plan": {
        "taskName": "<Task Name>",
        "objective": { "goal": "<goal>", "nonGoals": "<non-goals>", "doneWhen": "<one-line summary>" },
        "context": { "repoType": "<type>", "keyFiles": ["<path>"], "background": "<why>" },
        "constraints": ["<constraint>"],
        "steps": ["S1 title", "S2 title"],
        "finalDone": ["criterion 1", "criterion 2"]
      }
    },
    { "op": "run", "cmd": "bash .claude/skills/tr/scripts/autoloop.sh start", "cwd": "." }
  ],
  "report": { "changedFiles": true, "diffSummary": true, "commandOutputs": "never" }
}
```

Then run:

```
/file-op <the JSON above>
```

Codex returns `FileOpsRES` JSON only (via `/file-op`).

### 5. Output

```
Plan saved:
- todo.md
- state.json
- plan_log.md

Next: Use /tr to start execution
```

---

## Principles

1. **Parallel Design**: Claude and Codex plan independently first
2. **Merge Discussion**: 2-3 rounds to eliminate redundancy and fill gaps
3. **Coarse-grained**: Titles only, details in /tr
4. **Recoverable**: Context enables continuity after /clear
5. **Research-driven**: Use WebSearch and WebFetch to gather info on unfamiliar tech/APIs/best practices before finalizing the plan
