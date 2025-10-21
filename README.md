# Claude Code TriFlow

[![Version](https://img.shields.io/badge/version-3.1-blue.svg)](https://github.com/yourusername/claude-triflow)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-Compatible-purple.svg)](https://claude.com/claude-code)

Intelligent `/plan` → `/run` workflow guidance for Claude Code agents. TriFlow v3.1 keeps todo files lean, aligns execution with persistent state, enforces quality via Codex review, and maintains execution continuity through result logging.

## Why TriFlow?
Claude Code falters when context grows past ~60% usage (≈120k tokens). Common failures:
- Token waste from oversized repos and drifting `TODO.md`.
- Latency spikes and decision errors when steps sprawl.
- Manual rewrites that reintroduce bugs because state is stale.

TriFlow v3.1 counters this with four pillars:
1. **Deep contextual planning** – `/plan` inspects the repo, classifies complexity, defines final goals, and writes concise steps.
2. **Objective-first execution** – Every `TODO.md` starts with final goal + key findings so `/run` stays aligned.
3. **Execution result logging** – `/run` records outcomes and key information for continuity between steps.
4. **Flexible context management** – Optional `/clear` usage maintains useful context while preventing bloat.

## Core Concepts
- **Adaptive Planning** – Token-aware plans that limit `TODO.md` to ~20 lines and highlight risks up front.
- **State-Aware Execution** – Persistent store tracks current step/substep so restarts resume correctly.
- **Objective Snapshot** – Single place to restate the mission; edits must retain one `[▶️]`.
- **Codex QA Loop** – Each step is reviewed; scores below 28/40 block automatic progression.

For a deeper design discussion, see `PLAN.md` and `PROJECT.md`.

## Workflow at a Glance
1. `/plan <task>`  
   - Restates the task, analyses the repo, and author writes `TODO.md` with the snapshot, analysis, and ordered steps.
2. `/run`  
   - Reads the snapshot, refreshes the state store with the active `[▶️]`, reassesses complexity, then executes or expands as needed.
   - Logs Codex review results and updates `TODO.md`/state on completion.
3. `/clear` (Optional)
   - Resets chat context when needed; no longer mandatory after each step.

Helpful utilities:
- `/progress` – Summarises the active step, dependencies, and recent history.
- `/token-info` – Monitors context usage to avoid performance cliffs.

## TODO.md Layout
`/plan` enforces the snapshot-first layout. Keep the snapshot short (≤3 bullets) and ensure there is exactly one active marker.

```markdown
# TODO - Upgrade workflow

## 🎯 Objective Snapshot
- Goal: Sync run workflow state before expansions
- Key Findings: CLI skipped state refresh; auto-advance left stale markers

## 🔍 Analysis
- Complexity: Simple (~35k tokens)
- Risks: State/todo drift if markers misalign

## 📋 Steps
- [▶️] Refine run guidance
- [ ] Update CLI behaviour
- [ ] Validate with sample run
```

## Command Playbooks
- `commands/plan.md` – Deep-context checklist, complexity tier definitions, `TODO.md` authoring rules.
- `commands/run.md` – Execution phases, state-sync requirements, expansion criteria, auto-transition messaging.
- `commands/progress.md` – Reporting format for active step snapshots.
- Additional guidance lives in `docs/`, including change logs and architecture notes.

Contributor expectations (style, naming, testing) are documented in `AGENTS.md` and `CONTRIBUTING.md`.

## Best Practices
**Do**
- Stay in the `/plan` → `/run` → `/clear` rhythm.
- Keep `TODO.md` lean; archive finished steps instead of appending.
- When editing `TODO.md` manually, mirror the snapshot format and refresh the state store.
- Record Codex review scores and address any issues before advancing.

**Don’t**
- Skip `/clear` after large executions or long conversations.
- Expand Simple steps unless new modules are implicated.
- Leave multiple `[▶️]` markers or remove the objective snapshot header.
- Ignore dependency warnings or stale state errors.

## Setup & Validation
- Copy the command files into Claude Code’s command directory (or run the installer script if available).
- Restart Claude Code so `/plan`, `/run`, and `/progress` register.
- Dry-run with `/plan Demo task` followed by `/run` to confirm state sync, snapshot placement, and auto-transition messaging align with expectations.

## 中文速览
- 核心节奏：`/plan`（规划）→ `/run`（执行）→ `/clear`（清理上下文）。
- `todo.md` 顶部必须包含「Objective Snapshot」，写明目标与关键发现，并保持唯一 `[▶️]`。
- `/run` 会先刷新状态存档，再判断是否展开子步骤并推进；审查分低于 28/40 时需先修复。
- 更多贡献规范请参阅 `AGENTS.md` 与 `CONTRIBUTING.md`。
