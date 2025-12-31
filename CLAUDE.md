## Project Context

This is the **cct (Claude Code TriFlow)** development repository.

Key considerations:
- **Cross-platform**: Scripts must work on Linux and macOS (BSD vs GNU tools)
- **Portability**: Use relative paths and environment variables, avoid hardcoded paths
- **Self-contained**: All dependencies bundled in .claude/skills/
- **Safe installation**: cct add/delete must not damage user's other tools
- **Documentation**: Keep docs/triflow_v3_architecture.md updated

This is NOT a regular project - changes here affect all TriFlow installations.

---

# claude_triflows — Project Memory (TriFlow)

Pure Skill workflow for structured task execution.

## After `/clear`

Read these files to restore context:
- `todo.md` - current task and steps
- `state.json` - authoritative progress state

## Commands

- `/tp [requirement]` - Create plan (see `commands/tp.md`)
- `/tr` - Execute current step (see `commands/tr.md`)

Skill sources: `commands/tp.md`, `commands/tr.md` (mirrored in `.claude/commands/`)

<!-- TRIFLOW -->
## TriFlow

Task execution workflow. After `/clear`, read:
- `todo.md` - current task and steps
- `state.json` - progress state

Commands: `/tp [requirement]` (plan), `/tr` (run)
<!-- /TRIFLOW -->
