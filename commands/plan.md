---
description: Adaptive plan with deep context analysis
argument-hint: [task-description]
---

Use Codex to analyze $ARGUMENTS and produce an adaptive execution plan.

## Phase 0: Deep Context Review

Before planning, **deeply analyze the task and project**:

1. **Restate the task** in your own words to confirm understanding
2. **Inspect the repository**:
   - List relevant directories, modules, docs, dependencies
   - Identify existing code that may be affected
   - Check project architecture and patterns
3. **Identify integration points**:
   - Data models, APIs, external services
   - Side effects, migrations, breaking changes
4. **Surface hidden complexity**:
   - Security implications
   - Performance considerations
   - Cross-module impact
   - Testing requirements
5. **Capture unknowns**: Assumptions that require validation

⚠️ **Critical**: User descriptions may be simple but hide complexity.
Example: "add login" → authentication system, session management, security, password handling, database schema, API endpoints, frontend integration.

## Phase 1: Complexity Classification

Estimate effort in tokens using context review insights:

**Tier Decision**:
- **Trivial** (<20k): Single atomic change, execute immediately
  - Examples: Fix typo, update config value, add simple log statement

- **Simple** (20-60k): Limited scope, 1-3 meaningful steps
  - Examples: Add new API endpoint, refactor single module, write documentation

- **Complex** (≥60k): Multi-component change, ambiguous requirements, or notable risk
  - Examples: Implement authentication, migrate database, redesign architecture

**Escalation Rules**:
- If description seems simple but context reveals hidden work → escalate tier
- If unfamiliar patterns or technologies involved → escalate tier
- Always explain tier choice with evidence from context review

⚠️ **Flag underestimation risks** when:
- Requirements are vague
- Multiple modules affected
- External dependencies involved
- Security/performance critical

## Phase 2: Adaptive Plan Construction

**Trivial Tasks**:
```
Single-step plan:
- Step 1 [Trivial] (~Xk): [Direct action]
Recommendation: Execute immediately with /run
```

**Simple Tasks** (1-3 steps):
- Only essential milestones
- Avoid unnecessary granularity
- Each step = meaningful deliverable

**Complex Tasks** (3-7 steps):
- Comprehensive breakdown
- Merge overlapping work
- Flag where substeps might be needed later
- Clear dependencies between steps

**Quality Control**:
- Validate that each step is truly necessary
- Merge overly granular steps
- Ensure logical sequence and dependencies

## Output Format

```markdown
## 🔍 Context Analysis
Task: [Restated understanding]
Project Type: [Framework/language/architecture]
Affected Modules: [List]
Integration Points: [APIs, services, databases]
Hidden Complexity: [Security, performance, migrations, etc.]
Unknowns: [Assumptions to validate]

## 📊 Complexity Assessment
Tier: Trivial/Simple/Complex (~XXk tokens)
Reasoning: [Why this tier? Evidence from context]
Risks: [Underestimation flags or "None noted"]

## 📋 Execution Plan

Step N [Tier] (~Xk tokens): [Title]
├─ Role: [Why this step matters]
├─ Deliverable: [Concrete outcome]
├─ Validation: [How to confirm completion]
├─ Dependencies: [Previous steps or external requirements]
└─ Notes: [Integrations, blockers, assumptions, risks]

[Repeat for each step...]

Step N+1 [Trivial] (~1k tokens): 最终审查：验证目标达成情况
├─ Role: 确保所有功能都符合最终目标要求
├─ Deliverable: 完整的项目验收报告
├─ Validation: 对照最终目标逐一验证
├─ Dependencies: 所有前置步骤完成
└─ Notes: 这是必须执行的最后步骤

## 📈 Summary
- Total Steps: N+1 (Trivial: X, Simple: Y, Complex: Z, Final: 1)
- Est. Tokens: XXk / 120k (YY% of budget)
- Complexity Tier: [Overall tier]
- Risk Level: [Low/Medium/High with explanation]
- 最终目标: [明确的项目完成目标]
```

**Validation**:
- Trivial: 1 step only
- Simple: 1-3 steps only
- Complex: 3-7 steps only
- Total tokens < 120k

## Phase 3: Persist to todo.md

Create `./todo.md` with the **最终目标 prominently displayed at the very top** so every execution run can realign before acting:

```markdown
# TODO - [Task Name]

## 🎯 最终目标
[项目的最终完成目标和验收标准]

## 🔍 关键发现
[Top 2-3 insights from analysis that must stay visible for subsequent steps]

## 📊 执行概览
- **复杂度**: [Tier] (~XXk tokens)
- **总步骤**: N 步 (Trivial: X, Simple: Y, Complex: Z)
- **预估 Token**: XXk / 120k (YY%)
- **风险级别**: [Low/Medium/High]
- **创建时间**: [date]

## 📋 执行步骤
- [▶️] Step 1 [Tier]: [Title] (~Xk)
- [ ] Step 2 [Tier]: [Title] (~Xk)
- [ ] Step 3 [Tier]: [Title] (~Xk)
- [ ] 最终审查: 验证目标达成情况

## 📝 执行日志
[此区域用于记录每步执行结果和关键信息]

---
💡 **下一步**: /run (开始执行第一步骤)
```

**For Trivial tasks**, add note:
```
⚡ Trivial task - planning optional, execute immediately with /run
```

## Completion Message

```
✅ Plan created with [Tier] complexity (N+1 steps including final review)
📊 Estimated: XXk / 120k tokens (YY% of budget)
🎯 最终目标: [项目最终目标]
🔍 Context analyzed: [key findings]
⚠️ Risks: [any flags or "None noted"]
📝 Saved to todo.md with final review step

💡 Next: /run (开始执行第一步骤)
```

---

**Key Principles**:
- **Context first**: Deep analysis before planning
- **Adaptive granularity**: Match step count to actual complexity
- **Escalate when needed**: Simple descriptions may hide complex work
- **Quality over quantity**: Fewer, meaningful steps beat many trivial ones
- **Flag risks early**: Better to overestimate than underestimate
