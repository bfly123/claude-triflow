# cca (Claude Code AutoFlow)

![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)
![License](https://img.shields.io/badge/license-AGPL--3.0-green.svg)
![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS%20%7C%20WSL-lightgrey.svg)

**Claude Code AutoFlow (cca)** 是一个专为 AI 辅助开发设计的结构化任务自动化工作流系统。它利用标准通信协议，使 Claude 能够自主、安全地规划 (`/tp`) 和执行 (`/tr`) 复杂任务。

## 🔗 依赖链

`cca` 位于自动化技术栈的顶层：

```mermaid
graph LR
    WezTerm --> ccb[ccb (Claude Code Bridge)]
    ccb --> cca[cca (Claude Code AutoFlow)]
```

- **WezTerm**: 终端模拟器基础。
- **ccb**: 连接终端与 AI 上下文的桥梁。
- **cca**: 高级任务自动化工作流引擎。

## ✨ 核心功能

| 功能 | 命令 | 说明 |
| :--- | :--- | :--- |
| **任务规划** | `/tp [需求]` | 生成结构化计划并初始化状态机。 |
| **任务执行** | `/tr` | 执行当前步骤，包含双重设计 (Dual-Design) 验证。 |
| **自动化** | `autoloop` | 后台守护进程，实现持续的上下文感知执行。 |
| **状态管理** | SSOT | 使用 `state.json` 作为任务状态的唯一数据源。 |

## 🚀 安装步骤

### 1. 安装 WezTerm
从官方网站下载并安装 WezTerm：
[https://wezfurlong.org/wezterm/](https://wezfurlong.org/wezterm/)

### 2. 安装 ccb (Claude Code Bridge)
```bash
git clone https://github.com/bfly123/claude_code_bridge.git
cd claude_code_bridge
./install.sh install
```

### 3. 安装 cca (AutoFlow)
```bash
git clone https://github.com/bfly123/claude-autoflow.git
cd claude-autoflow
./install.sh install
```

## 📖 使用指南

### CLI 管理
通过 `cca` 命令行工具管理项目的自动化权限。

| 命令 | 说明 |
| :--- | :--- |
| `cca add .` | 为当前目录配置 Codex 自动化权限。 |
| `cca add /path` | 为指定项目路径配置自动化权限。 |
| `cca update` | 更新 `cca` 核心组件及全局 Skills 定义。 |
| `cca version` | 显示版本信息。 |

### Slash Skills (会话内)
在 Claude 会话中，使用以下 Skills 驱动工作流：

<details>
<summary><strong>/tp - Task Plan (任务规划)</strong></summary>

根据需求创建新的任务计划。
```text
/tp 实现基于 JWT 的用户登录功能
```
*触发流程：并行设计 -> 生成计划文件 -> 启动自动循环*
</details>

<details>
<summary><strong>/tr - Task Run (任务执行)</strong></summary>

执行计划中的下一个待办步骤。
```text
/tr
```
*触发流程：预检 -> 设计 -> 执行 -> 审查 -> 归档*
</details>

## 📄 许可协议

本项目采用 [AGPL-3.0](LICENSE) 许可证。
