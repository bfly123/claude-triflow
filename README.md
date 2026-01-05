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

![Version](https://img.shields.io/badge/version-1.1.0-blue.svg)
![License](https://img.shields.io/badge/license-AGPL--3.0-green.svg)
![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS%20%7C%20Windows%20%7C%20WSL-lightgrey.svg)

**English** | [中文](README_zh.md)

</div>

---

**Claude Code AutoFlow (cca)** is a structured task automation workflow system designed for AI-assisted development. It enables Claude to plan and execute complex tasks autonomously with dual-design validation.

## 🔗 Dependency Chain

```
WezTerm  →  ccb (Claude Code Bridge)  →  cca (Claude Code AutoFlow)
```

- **WezTerm**: Terminal emulator with pane control support
- **ccb**: Bridge connecting terminal to AI context
- **cca**: High-level workflow engine for task automation

## ✨ Core Features

| Feature | Description |
| :--- | :--- |
| **Task Planning** | Dual-design (Claude + Codex) plan generation |
| **Auto Execution** | Autoloop daemon triggers `/tr` automatically after planning |
| **State Management** | `state.json` as Single Source of Truth |
| **Context Awareness** | Auto `/clear` when context usage exceeds threshold |

## 🚀 Installation

### 1. Install WezTerm
Download from: [https://wezfurlong.org/wezterm/](https://wezfurlong.org/wezterm/)

### 2. Install ccb (Claude Code Bridge)
```bash
git clone https://github.com/bfly123/claude_code_bridge.git
cd claude_code_bridge
./install.sh install
```

### 3. Install cca (AutoFlow)

**Option A: Via ccb (Recommended)**
```bash
ccb update cca         # Install or update cca via ccb
```

Other ccb commands for cca:
```bash
ccb -v                 # Show CCA version or install suggestion
ccb update             # Update both CCB and CCA
ccb update cca         # Install/update CCA only
```

**Option B: Manual installation**
```bash
git clone https://github.com/bfly123/claude_code_autoflow.git
cd claude_code_autoflow
./install.sh install
```

### Windows (PowerShell)

**Prerequisites**: PowerShell 5.1+ (Windows 10+)

**Installation**:
```powershell
git clone https://github.com/bfly123/claude_code_autoflow.git
cd claude_code_autoflow
# Copy cca.ps1 to your PATH or run directly
Copy-Item cca.ps1 $env:LOCALAPPDATA\Microsoft\WindowsApps\cca.ps1
```

**Usage**:
```powershell
cca.ps1 <command> [options]
# Or if in PATH:
cca <command> [options]
```

## 📖 Usage

### CLI Commands

```bash
cca <command> [options]
```

#### Project Configuration
```bash
cca add .              # Enable AutoFlow for current project
cca add ~/myproject    # Enable AutoFlow for specific path
cca delete .           # Remove AutoFlow config from current project
cca delete ~/myproject # Remove AutoFlow config from specific path
cca list               # Show all configured projects
```

#### Maintenance
```bash
cca update             # Update cca and refresh ~/.claude/ skills
cca update --local     # Refresh ~/.claude/ from local CCA_SOURCE
cca uninstall          # Remove cca from system
cca version            # Show version and commit info
cca help               # Show help
```

#### What `cca add` does:
1. Registers project in `~/.config/cca/installations`
2. Configures Codex permissions in `~/.codex/config.toml`:
   - `trust_level = "trusted"`
   - `approval_policy = "never"`
   - `sandbox_mode = "full-auto"`

### Slash Commands (In-Session)

| Command | Description |
| :--- | :--- |
| `/auto <requirement>` | Create task plan (invokes tp skill) |
| `/auto run` | Execute current step (invokes tr skill) |

Example:
```bash
/auto implement user login    # Creates plan, autoloop starts execution
```

> **Note**: After `/auto <requirement>` completes planning, autoloop automatically triggers execution. No manual `/auto run` needed.

## 📄 License

[AGPL-3.0](LICENSE)

---

<details>
<summary>📜 Version History</summary>

### v1.1.0
- Add Windows PowerShell support (cca.ps1)
- Add role configuration system (P0: reviewer/documenter/designer)
- Add OpenCode executor support (P1: executor routing)
- Add Claude plan mode persistence (Preflight mode check)
- Fix macOS bash 3.2/4.3 empty array compatibility
- Add ask-gemini skill for Gemini integration

### v1.0.0
- Initial release
- Core AutoFlow workflow (tp/tr)
- Dual-design validation
- Autoloop daemon
- State management with state.json

</details>
