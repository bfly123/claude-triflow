# AutoFlow v3.0 架构设计报告

## 1. 项目概述 (Overview)

AutoFlow v3.0 是一个专为 AI 协作设计的高级工作流框架，旨在解决复杂任务中的上下文丢失、执行偏差及状态混乱问题。它通过严格的职责分离、标准化的通信协议以及自动化的上下文管理，实现稳定、可恢复的自动化任务执行。

### 核心理念
*   **Claude (大脑/控制面)**: 永驻 Plan Mode。负责高层规划、逻辑审核与决策，**严禁直接修改文件**。
*   **Codex (手/数据面)**: 执行者。负责所有文件 I/O、代码编写、状态更新及工具调用。
*   **协议通信**: 两者通过基于 JSON 的 `FileOpsREQ/RES` 协议进行交互，杜绝自然语言指令带来的歧义。

---

## 2. 设计原则 (Design Principles)

AutoFlow v3.0 遵循以下五大核心设计原则：

1.  **职责分离 (Separation of Duties)**: Claude 仅负责规划与审核，Codex 负责所有执行操作。这种物理隔离防止了幻觉代码直接写入生产环境。
2.  **数据源唯一 (Single Source of Truth)**: `state.json` 是系统的唯一事实来源。`todo.md` 仅作为自动生成的只读视图存在。
3.  **协议通信 (Protocol-First)**: 使用结构化的 JSON (`FileOpsREQ/RES`) 替代自然语言指令，确保指令的原子性和确定性。
4.  **双重验证 (Dual Verification)**: 在设计阶段采用 `/dual-design` (独立并行设计)，在验收阶段采用 `/dual-review` (交叉审核)，最大程度降低错误率。
5.  **自动恢复 (Auto-Recovery)**: 系统设计为“无状态”依赖。即使 `/clear` 清空上下文，也能通过读取 `state.json` 瞬间恢复执行进度。

---

## 3. 系统架构 (System Architecture)

### 3.1 整体架构图

```mermaid
graph TD
    subgraph Control_Plane [Claude (Plan Mode)]
        TP[/tp Plan/]
        TR[/tr Run/]
        DD[/dual-design/]
        Rev[/review/]
        Ask[/ask-codex/]
    end

    subgraph Comm_Channel [JSON Protocol]
        REQ[FileOpsREQ] --> RES[FileOpsRES]
    end

    subgraph Data_Plane [Codex (Executor)]
        DomainOps[autoflow_* Domain Ops]
        Patch[apply_patch]
        Shell[run shell]
    end

    subgraph Storage [File System]
        State[(state.json)]
        View(todo.md)
        Log(plan_log.md)
        Code(Source Code)
    end

    Control_Plane -- Sends Intent --> REQ
    REQ -- Parsed by --> Data_Plane
    Data_Plane -- Updates --> Storage
    Data_Plane -- Returns Evidence --> RES
    RES -- Feedback --> Control_Plane
    
    style State fill:#f96,stroke:#333,stroke-width:2px
```

### 3.2 项目文件结构

```text
claude_autoflows/
├── .claude/skills/         # Skills 层 (渐进式加载结构)
│   ├── tr/
│   │   ├── SKILL.md       # 简短入口 (~10行)
│   │   ├── references/    # 完整流程 (按需加载)
│   │   │   └── flow.md
│   │   ├── templates/     # JSON 模板
│   │   └── scripts/
│   │       ├── autoloop.py  # 守护进程 (~350 行，含上下文感知)
│   │       ├── autoloop.sh  # 生命周期管理 (Start/Stop)
│   │       └── lask         # 捆绑的 lask 工具 (无外部依赖)
│   ├── tp/
│   ├── dual-design/
│   ├── review/            # 统一审查 skill
│   ├── ask-codex/         # 薄封装工具调用
│   ├── file-op/
│   ├── mode-switch/
│   └── docs/
│       ├── protocol.md    # FileOps 协议规范
│       └── formats.md     # 状态文件格式定义
├── state.json             # 任务状态 (SSOT - 唯一数据源)
├── todo.md                # 只读视图 (由 State 渲染)
└── plan_log.md            # 执行日志 (流水记录)
```

---

## 4. 通信协议 (FileOps Protocol)

### 4.1 FileOpsREQ (Claude → Codex)
请求包含明确的意图、验收标准和原子操作列表。

```json
{
  "proto": "autoflow.fileops.v1",
  "id": "TR-FINALIZE",
  "purpose": "finalize_step",
  "summary": "完成当前步骤并推进状态",
  "done": ["状态更新为 done", "指针移动到下一步"],
  "ops": [
    { "op": "autoflow_state_finalize", "verification": "verify_pointer_moved" },
    { "op": "run", "cmd": "python3 .claude/skills/tr/scripts/autoloop.py --repo-root . --once" }
  ],
  "report": { "changedFiles": true }
}
```

### 4.2 FileOpsRES (Codex → Claude)
响应包含执行状态 (`ok|ask|fail|split`) 和变更证据。

### 4.3 域操作指令 (Domain Ops)
为了保证状态一致性，引入了特定的高层操作指令：
*   `autoflow_plan_init`: 初始化全新的计划文件。
*   `autoflow_state_preflight`: 执行前检查（读取状态 + 递增尝试次数）。
*   `autoflow_state_finalize`: 步骤完成（标记 Done + 移动指针）。
*   `autoflow_state_mark_blocked`: 标记阻塞。
*   `autoflow_state_apply_split`: 动态拆分子任务。
*   `autoflow_state_append_steps`: 任务完成后追加 1-2 个修复步骤（用于 Final Review 发现中等问题时）。

### 4.4 Validation Schema
协议实施严格的校验规则以确保安全性与一致性：

*   **必填字段**: `proto`, `id`, `purpose`, `ops`。
*   **Ops 校验**:
    *   仅允许标准 ops (`run`, `write_file` 等) 和授权的 domain ops (`autoflow_*`)。
    *   禁止高危命令（如 `rm -rf /`）。
*   **Report 校验**: 确保请求的报告格式（如 `changedFiles`）被 Codex 正确理解。
*   **错误响应**: 校验失败时返回 `validation_error` 格式的 JSON 响应，包含具体字段错误说明。

---

## 5. 关键工作流 (Workflows)

### 5.1 /tp 计划流程
1.  **Input**: 用户输入原始需求。
2.  **Dual Design**: Claude 与 Codex 并行设计任务分解。
3.  **Confirmation**: 用户确认计划。
4.  **Init**: 调用 `autoflow_plan_init` 生成 `state.json` 和 `todo.md`。
5.  **Boot**: 启动 `autoloop` 进程。

### 5.2 /tr 执行流程 (9步法)
执行流程包含 9 个步骤：

1.  **Preflight**: (`autoflow_state_preflight`) 读取当前状态，更新重试计数。
2.  **Dual Design**: 双方独立设计 + 合并讨论（包含 split 判断）。
3.  **Split Check**: 设计阶段判断是否需要拆分任务。
    *   *If yes*: 触发 `autoflow_state_apply_split` 并跳过后续执行。
4.  **Build REQ**: 根据合并的设计，构建精确的 `FileOpsREQ`。
5.  **Execute**: Codex 执行操作列表（代码修改、测试运行等）。
6.  **Handle RES**: 解析执行结果，处理 `ask` 或 `fail` 状态。
7.  **Review**: 调用 `/review` skill (Step Mode)，进行代码质量与功能验收。
    *   *7.5 Test (Optional)*: 如需额外验证，插入测试环节。
8.  **Finalize**: (`autoflow_state_finalize`) 完成步骤，更新状态。
9.  **Final Review**: (仅在任务链结束时) 全局审查项目状态，生成总结报告到 `final/` 目录。

### 5.3 Autoloop 与上下文管理

守护进程 `.claude/skills/tr/scripts/autoloop.py` 负责维持心跳和上下文健康：

*   **监控**: 轮询 `state.json` 的 `mtime` (0.5s 间隔, 20s 冷却)。
*   **上下文感知 (Context Awareness)**:
    1.  读取 `~/.claude/projects/<project>/*.jsonl` 日志。
    2.  计算 `usage = prompt_tokens / context_limit`。
*   **决策逻辑**:
    *   `if usage > 70%`: 执行 `/clear` (清理上下文) ➔ `/tr` (无缝恢复)。
    *   `else`: 直接执行 `/tr`。

### 5.4 Skills 层与模板系统

Skills 层采用模块化结构，支持渐进式加载以节省 Context：

*   **主要 Skills**:
    *   `/ask-codex`: 对 cask 调用的薄封装，强制统一为 JSON-only 交互，内置校验与超时控制。
    *   `/review`: 统一审查工具，支持 `step` (单步验收) 和 `task` (全局审查) 两种模式。
*   **模板系统 (Templates)**:
    *   每个 Skill 目录下包含 `templates/` 子目录，存储标准化的 JSON 请求模板。
    *   `_meta.placeholders`: 说明模板中变量（如 `{{CMD}}`）的数据来源。
    *   `README.md`: 提供模板调用的具体指引。