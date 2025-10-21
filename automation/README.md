# Automation

Claude TriFlow 交互式自动化工作流工具。

## 文件说明

- `triflow_bridge.py` - TriFlow 交互式桥接器，支持实时监控和用户交互
- `test_tasks.md` - 测试任务文件，用于验证功能

## 🚀 快速开始

### 1. 准备任务文件

创建符合格式的任务文件，例如：

```markdown
## Task 1: 任务标题

任务描述和要求

## Task 2: 另一个任务

详细描述...
```

### 2. 启动 Claude Code 会话

```bash
# 启动 Worker 会话（执行任务）
tmux new-session -s claude-worker -d
tmux send-keys -t claude-worker "claude" Enter

# 启动 Brain 会话（监控决策）
tmux new-session -s claude-brain -d
tmux send-keys -t claude-brain "claude" Enter
```

### 3. 运行交互式桥接器

```bash
# 基本用法
python automation/triflow_bridge.py tasks.md

# 自定义会话名
python automation/triflow_bridge.py tasks.md --worker my-worker --brain my-brain

# 测试功能
python automation/triflow_bridge.py test_tasks.md
```

## 🎯 交互式功能

### 实时监控
- **实时显示**: Worker 会话的输出实时显示在控制台
- **智能过滤**: 只显示新的、非空输出
- **状态跟踪**: 自动检测 Worker 运行状态

### 用户交互命令
在运行时，你可以输入以下命令：

| 命令 | 说明 |
|------|------|
| `quit` | 停止当前任务 |
| `skip` | 跳过当前任务 |
| `pause` | 暂停监控（输入 `resume` 继续） |
| `resume` | 恢复监控 |
| `attach` | 直接连接到 Worker 会话 |
| `help` | 显示帮助信息 |
| 其他输入 | 直接发送给 Worker 会话 |

### 智能决策
- **自动状态检测**: 检测 Worker 是否需要帮助
- **Brain 交互**: 自动询问 Brain 进行状态判断
- **智能输入**: Brain 可以建议具体输入内容

## 🔧 命令行参数

| 参数 | 简写 | 默认值 | 说明 |
|------|------|--------|------|
| `tasks_file` | - | 必需 | 任务文件路径 |
| `--worker` | `-w` | `claude-worker` | Worker 会话名 |
| `--brain` | `-b` | `claude-brain` | Brain 会话名 |

## 💡 使用技巧

1. **直接操作**: 可以随时 `tmux attach -t claude-worker` 直接操作 Worker
2. **输出查看**: 使用 `tmux capture-pane -t claude-worker -p` 实时查看输出
3. **任务分解**: 将复杂任务分解为小任务提高成功率
4. **状态管理**: 使用 `pause` 暂停，需要时手动干预

## ⚠️ 注意事项

- 确保两个 tmux 会话都已启动 Claude Code
- 任务文件格式需要正确（参考 `test_tasks.md`）
- 监控过程中可以通过键盘随时控制流程
- 网络连接稳定很重要，避免 API 调用失败

## 🔍 故障排除

### 常见问题

1. **会话不存在**
   ```
   RuntimeError: Worker 会话不存在
   ```
   **解决**: 检查会话名，确保 tmux 会话已启动

2. **Claude Code 未响应**
   **解决**: 检查会话中是否有安全确认提示

3. **任务文件格式错误**
   **解决**: 参考 `test_tasks.md` 的格式

---

**注意**: 此工具专为交互式自动化设计，提供实时反馈和用户控制能力。