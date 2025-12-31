# AutoFlow File Formats

## todo.md

```markdown
# Task: [Task Name]

## Context
- Repo: [project type/tech stack]
- Key files: [key file paths]
- Background: [why doing this]

## Objective
- Goal: [one sentence]
- Non-goals: [what NOT to do]

## Constraints
- [constraint 1]
- [constraint 2]

## Steps
- [>] S1: [title]
- [ ] S2: [title]
- [ ] S3: [title]

## Substeps (if expanded)
- [x] S2.1: [title]
- [>] S2.2: [title]
- [ ] S2.3: [title]

## Done
- [criterion 1]
- [criterion 2]
```

**Markers**: `[x]` done, `[>]` current (exactly one), `[ ]` pending

**Blocked format**: `- [>] S2: title (BLOCKED)`

## state.json

```json
{
  "taskName": "Task Name",
  "objective": {
    "goal": "one sentence goal",
    "nonGoals": "what NOT to do",
    "doneWhen": "one-line completion summary"
  },
  "context": {
    "repoType": "python",
    "keyFiles": ["a.py", "b.py"],
    "background": "why doing this"
  },
  "constraints": ["constraint1", "constraint2"],
  "current": {
    "type": "step|substep|none",
    "stepIndex": 1,
    "subIndex": null
  },
  "steps": [
    {
      "index": 1,
      "title": "step title",
      "status": "todo|doing|done|blocked",
      "attempts": 0,
      "substeps": []
    }
  ],
  "finalDone": ["criterion1", "criterion2"]
}
```

**Status values**: `todo`, `doing`, `done`, `blocked`

**substeps array** (when expanded):
```json
"substeps": [
  { "index": 1, "title": "substep title", "status": "doing" },
  { "index": 2, "title": "substep title", "status": "todo" }
]
```

## plan_log.md

```markdown
# Plan Log - [Task Name]

## Initial Plan
- Created: [YYYY-MM-DD]
- Objective: [goal]
- Total steps: [N]

---

## S1: [title] - DONE
- Completed: [YYYY-MM-DD HH:MM]
- Changes: [file1, file2]
- Verification: [how verified]
```
