# cca (Claude Code AutoFlow)

![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)
![License](https://img.shields.io/badge/license-AGPL--3.0-green.svg)
![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS%20%7C%20WSL-lightgrey.svg)

**Claude Code AutoFlow (cca)** is a structured task automation workflow system designed for AI-assisted development. It leverages standard communication protocols to enable Claude to plan (`/tp`) and execute (`/tr`) complex tasks autonomously and safely.

## 🔗 Dependency Chain

`cca` sits at the top of the automation stack:

```mermaid
graph LR
    WezTerm --> ccb[ccb (Claude Code Bridge)]
    ccb --> cca[cca (Claude Code AutoFlow)]
```

- **WezTerm**: The terminal emulator backbone.
- **ccb**: The bridge connecting the terminal to the AI context.
- **cca**: The high-level workflow engine for task automation.

## ✨ Core Features

| Feature | Command | Description |
| :--- | :--- | :--- |
| **Task Planning** | `/tp [req]` | Generates a structured plan and initiates the state machine. |
| **Task Execution** | `/tr` | Executes the current step with dual-design validation. |
| **Automation** | `autoloop` | Background daemon for continuous context-aware execution. |
| **State Management** | SSOT | Uses `state.json` as the Single Source of Truth for task status. |

## 🚀 Installation

### 1. Install WezTerm
Download and install WezTerm from the official website:
[https://wezfurlong.org/wezterm/](https://wezfurlong.org/wezterm/)

### 2. Install ccb (Claude Code Bridge)
```bash
git clone https://github.com/bfly123/claude_code_bridge.git
cd claude_code_bridge
./install.sh install
```

### 3. Install cca (AutoFlow)
```bash
git clone https://github.com/bfly123/claude-autoflow.git
cd claude-autoflow
./install.sh install
```

## 📖 Usage

### CLI Management
Manage your project's automation permissions via the `cca` command line tool.

| Command | Description |
| :--- | :--- |
| `cca add .` | Configure Codex automation permissions for the current directory. |
| `cca add /path` | Configure automation for a specific project path. |
| `cca update` | Update `cca` core and global skills definitions. |
| `cca version` | Display version information. |

### Slash Skills (In-Session)
Once inside a Claude session, use these skills to drive the workflow:

<details>
<summary><strong>/tp - Task Plan</strong></summary>

Creates a new task plan based on your requirements.
```text
/tp Implement user login feature using JWT
```
*Triggers: Dual-design phase -> Plan file generation -> Autoloop start*
</details>

<details>
<summary><strong>/tr - Task Run</strong></summary>

Executes the next pending step in the plan.
```text
/tr
```
*Triggers: Preflight -> Design -> Execution -> Review -> Finalization*
</details>

## 📄 License

This project is licensed under the [AGPL-3.0](LICENSE).
