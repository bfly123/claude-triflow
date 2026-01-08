<div align="center">

# cca (Claude Code AutoFlow)

**Multi-Model Interconnection, Automated Collaboration**

**多模型互联，自动化协作**

<p>
  <img src="https://img.shields.io/badge/多模型互联-096DD9?style=for-the-badge" alt="多模型互联">
  <img src="https://img.shields.io/badge/自动化协作-CF1322?style=for-the-badge" alt="自动化协作">
</p>
<p>
  <img src="https://img.shields.io/badge/Multi--Model_Interconnection-096DD9?style=for-the-badge" alt="Multi-Model Interconnection">
  <img src="https://img.shields.io/badge/Automated_Collaboration-CF1322?style=for-the-badge" alt="Automated Collaboration">
</p>

![Version](https://img.shields.io/badge/version-1.2.0-blue.svg)
![License](https://img.shields.io/badge/license-AGPL--3.0-green.svg)
![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS%20%7C%20Windows%20%7C%20WSL-lightgrey.svg)

[English](README.md) | **中文**

</div>

---

**Claude Code AutoFlow (cca)** 是一个专为 AI 辅助开发设计的结构化任务自动化工作流系统。它利用标准通信协议，使 Claude 能够自主、安全地规划 (`/tp`) 和执行 (`/tr`) 复杂任务。

## 🔗 依赖链

`cca` 位于自动化技术栈的顶层：

```
WezTerm  →  ccb (Claude Code Bridge)  →  cca (Claude Code AutoFlow)
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

## 🎭 角色配置（适用于所有任务）

CCA 支持为不同阶段分配不同模型角色。该路由不仅适用于 AutoFlow 工作流（`/tp`、`/tr`），也适用于日常的轻量任务：Claude 常驻计划模式，通过技能委派（例如 `/file-op`、`/review`、`/roles`）让不同执行者完成工作。

### 配置位置与优先级

- **会话级**（最高优先级）：`<project_root>/.autoflow/roles.session.json`
- **项目级**：`<project_root>/.autoflow/roles.json`
- **系统级**：`~/.config/cca/roles.json`

优先级：会话级 > 项目级 > 系统级 > 默认值。

### 支持的角色字段

- **executor**：执行代码修改（例如 `codex`、`opencode`）
- **reviewer**：审查代码/逻辑（例如 `codex`、`gemini`）
- **documenter**：生成文档（例如 `codex`、`gemini`）
- **designer**：参与双重设计（例如 `["claude", "codex"]`）

### /roles（轻量管理）

无需启动完整 `/tp`/`/tr`，可直接用 `/roles` 管理角色：

```bash
/roles show
/roles set executor=opencode reviewer=gemini
/roles clear
/roles init
```

### 示例配置

```json
{
  "schemaVersion": 1,
  "enabled": true,
  "executor": "opencode",
  "reviewer": "gemini",
  "documenter": "gemini",
  "designer": ["claude", "codex"]
}
```

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

**Linux/macOS:**
```bash
git clone https://github.com/bfly123/claude_code_autoflow.git
cd claude_code_autoflow
./install.sh install
```

**Windows:**

**方法 1：自动安装（推荐）**

1. 克隆仓库：
   ```powershell
   git clone https://github.com/bfly123/claude_code_autoflow.git
   cd claude_code_autoflow
   ```

2. 运行安装脚本：
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\install.ps1 install
   ```

   或者直接运行：
   ```powershell
   .\install.ps1 install
   ```

3. 重启终端或刷新 PATH：
   ```powershell
   $env:Path = [System.Environment]::GetEnvironmentVariable("Path","User")
   ```

4. 验证安装：
   ```powershell
   cca --version
   ```

**方法 2：手动安装**

1. 将 `cca.ps1` 复制到 PATH 中的目录：
   ```powershell
   Copy-Item cca.ps1 $env:LOCALAPPDATA\Microsoft\WindowsApps\cca.ps1
   ```

2. 手动安装 skills 和 commands 到 `~\.claude\`

**卸载**

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 uninstall
```

**故障排除**

- 如果遇到"执行策略"错误，运行：
  ```powershell
  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
  ```

- 如果安装后找不到 `cca` 命令，重启终端或手动刷新 PATH：
  ```powershell
  $env:Path = [System.Environment]::GetEnvironmentVariable("Path","User") + ";" + [System.Environment]::GetEnvironmentVariable("Path","Machine")
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

- **`/tp [任务说明]`** - 创建任务计划。
  - 示例：`/tp 实现用户登录功能`
- **`/tr`** - 启动自动执行。
  - 不需要参数。

## 📄 许可协议

本项目采用 [AGPL-3.0](LICENSE) 许可证。

---

<details>
<summary>📜 版本历史</summary>

### v1.2.0
- 添加中英文 SLOGAN 和语言切换
- 添加居中布局和彩色徽章

### v1.1.0
- 添加 Windows PowerShell 支持 (cca.ps1)
- 添加角色配置系统 (P0: reviewer/documenter/designer)
- 添加 OpenCode 执行者支持 (P1: executor routing)
- 添加 Claude plan 模式持久化 (Preflight 模式检查)
- 修复 macOS bash 3.2/4.3 空数组兼容性问题
- 添加 ask-gemini skill 用于 Gemini 集成

### v1.0.0
- 初始发布
- 核心 AutoFlow 工作流 (tp/tr)
- 双重设计验证
- Autoloop 守护进程
- 使用 state.json 进行状态管理

</details>
