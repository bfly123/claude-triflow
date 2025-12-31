# Mode Switch

Switch Claude between plan mode and bypass mode.

---

## Status: Deprecated (New Architecture)

AutoFlow now assumes **Claude stays in plan mode** (planning + review only), while **Codex performs all file I/O**.

- New flows should not call `/mode-switch`.
- This file is kept for backward compatibility with older scripts/docs.

## Modes

| Mode | Tool | Purpose |
|------|------|---------|
| `plan` | `EnterPlanMode` | Structured exploration, no execution |
| `bypass` | `ExitPlanMode` | Direct execution, make changes |

---

## Input

From `$ARGUMENTS`:
- `mode`: "plan" or "bypass"

---

## Execution

### If mode = "plan"

1. Request Codex to auto-confirm (background):

```
Bash(cask 'Execute immediately without asking:

sleep 5 && lask ""

This sends Enter to confirm plan mode.', run_in_background=true)
```

2. Use `EnterPlanMode` tool (Codex auto-confirms after 5s)
3. Confirm: `Mode: PLAN (explore only)`

### If mode = "bypass"

1. Request Codex to auto-confirm (background):

```
Bash(cask 'Execute immediately without asking:

sleep 5 && lask ""

This sends Enter to confirm bypass mode.', run_in_background=true)
```

2. Use `ExitPlanMode` tool (Codex auto-confirms after 5s)
3. Confirm: `Mode: BYPASS (execute)`

---

## Usage

Called by other skills:

```
# Before design phase
/mode-switch plan

# After design, ready to execute
/mode-switch bypass
```

---

## Notes

- Idempotent: safe to call if already in target mode
- No user interaction required
- bypass = normal execution mode
