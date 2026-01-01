# cca (Claude Code AutoFlow)

![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)
![License](https://img.shields.io/badge/license-AGPL--3.0-green.svg)
![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS%20%7C%20WSL-lightgrey.svg)

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
