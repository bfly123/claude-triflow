## Project Context

This is the **cca (Claude Code AutoFlow)** development repository.

Key considerations:
- **Cross-platform**: Scripts must work on Linux and macOS (BSD vs GNU tools)
- **Portability**: Use relative paths and environment variables, avoid hardcoded paths
- **Self-contained**: All dependencies bundled in .claude/skills/
- **Safe installation**: cca add/delete must not damage user's other tools
- **Documentation**: Keep docs/autoflow_v3_architecture.md updated

This is NOT a regular project - changes here affect all AutoFlow installations.

---

## Collaboration Rules

- Claude 不直接执行文件修改，通过 `cask`/`oask`/`gask` 委派
- 根据 `roles.json` 选择执行者/审查者/文档者/设计者（项目级配置优先于系统级配置）
- 默认工作流：任何涉及仓库文件修改或命令执行 → 必须走 `/file-op`；任何需要交叉审查 → 走 `/review`
- 执行者选择：
  - `executor=codex` → 通过 `cask`（默认）
  - `executor=opencode` → 通过 `oask`（或由 Codex 通过 `oask` 转发并监督）
  - `reviewer/documenter=gemini` → 通过 `gask`

---

## Version Management

- **Commit**: Every change must be committed
- **Push**: Only push when explicitly requested by user
- **Version bump**: Increment minor version (e.g., 1.0.0 → 1.1.0) on each push
- **README update**: Update version badge and add entry to Version History section
- **Version History**: Collapsible section at end of README with changelog

---

# claude_autoflows — Project Memory (AutoFlow)

Pure Skill workflow for structured task execution.

## After `/clear`

Read these files to restore context:
- `todo.md` - current task and steps
- `state.json` - authoritative progress state

## Commands

- `/tp [requirement]` - Create plan (see `commands/tp.md`)
- `/tr` - Execute current step (see `commands/tr.md`)

Skill sources: `commands/tp.md`, `commands/tr.md` (mirrored in `.claude/commands/`)

<!-- AUTOFLOW -->
## AutoFlow

Task execution workflow. After `/clear`, read:
- `todo.md` - current task and steps
- `state.json` - progress state

Commands: `/tp [requirement]` (plan), `/tr` (run)
<!-- /AUTOFLOW -->

<!-- CCA_WORKFLOW_POLICY -->
## CCA Workflow Policy

### Claude's Role (CRITICAL)
**Claude is the MANAGER, not the executor.**
- Plan and coordinate tasks
- Check role assignments before ANY action
- Delegate to appropriate executor (cask/oask/gask)
- NEVER execute file modifications directly

### Role-Based Delegation
| Role | Scope | Delegate |
|------|-------|----------|
| executor | Write/Edit, file-changing Bash | cask/oask |
| searcher | WebSearch/WebFetch | cask/oask/gask |
| git_manager | git add/commit/push/merge | cask/oask/gask |

### Commands
- codex: cask "task"
- opencode: oask "task"  
- gemini: gask "task"

### Rules (MANDATORY)
1. If role ≠ claude, delegate IMMEDIATELY without asking user
2. DO NOT ask user to choose execution method - auto-delegate based on role
3. DO NOT offer options like "委托给 Codex" or "直接执行"
4. Allowed direct: Read, Grep, Glob, .autoflow/**, /tmp/**
<!-- /CCA_WORKFLOW_POLICY -->
