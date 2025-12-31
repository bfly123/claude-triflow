#!/bin/bash
# TriFlow Installer - Install cct CLI tool to system

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { printf "${GREEN}[+]${NC} %s\n" "$1"; }
log_warn() { printf "${YELLOW}[!]${NC} %s\n" "$1"; }
log_error() { printf "${RED}[-]${NC} %s\n" "$1"; }
log_blue() { printf "${BLUE}[*]${NC} %s\n" "$1"; }

# Help
if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    cat << EOF
TriFlow Installer

Usage: ./install.sh [OPTIONS]

This script installs the 'cct' (Claude Code TriFlow) CLI tool to your system.
After installation, use 'cct' to manage TriFlow installations.

Options:
  -h, --help     Show this help
  --uninstall    Remove cct from system

After installation:
  cct add .      Install TriFlow to current project
  cct add all    Install TriFlow globally (~/.claude/commands)
  cct update     Update cct and all installations
  cct list       Show all installations
  cct help       Show all commands

EOF
    exit 0
fi

# Uninstall mode
if [[ "$1" == "--uninstall" ]]; then
    log_blue "Uninstalling cct..."

    # Find and remove cct binary
    for bin_dir in "$HOME/.local/bin" "/usr/local/bin" "$HOME/bin"; do
        if [[ -f "$bin_dir/cct" ]]; then
            rm -f "$bin_dir/cct"
            log_info "Removed: $bin_dir/cct"
        fi
    done

    # Remove config
    if [[ -d "$HOME/.cct" ]]; then
        rm -rf "$HOME/.cct"
        log_info "Removed: $HOME/.cct"
    fi

    log_info "Done!"
    exit 0
fi

echo ""
echo "  TriFlow Installer"
echo "  ================="
echo ""

# Check source files
if [[ ! -f "$SCRIPT_DIR/cct" ]]; then
    log_error "cct script not found in $SCRIPT_DIR"
    exit 1
fi

if [[ ! -d "$SCRIPT_DIR/.claude/skills" ]]; then
    log_error "Skills not found in $SCRIPT_DIR/.claude/skills/"
    exit 1
fi

# Determine installation directory
BIN_DIR=""
for dir in "$HOME/.local/bin" "$HOME/bin" "/usr/local/bin"; do
    if [[ -d "$dir" ]] && [[ -w "$dir" ]]; then
        BIN_DIR="$dir"
        break
    fi
done

# Create ~/.local/bin if no suitable directory found
if [[ -z "$BIN_DIR" ]]; then
    BIN_DIR="$HOME/.local/bin"
    mkdir -p "$BIN_DIR"
    log_info "Created: $BIN_DIR"
fi

# Install cct
cp "$SCRIPT_DIR/cct" "$BIN_DIR/cct"
chmod +x "$BIN_DIR/cct"
log_info "Installed: $BIN_DIR/cct"

# Create config directory
CCT_HOME="$HOME/.cct"
mkdir -p "$CCT_HOME"

# Save source path
echo "$SCRIPT_DIR" > "$CCT_HOME/source_path"
log_info "Config: $CCT_HOME"

# Check if BIN_DIR is in PATH
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    log_warn "$BIN_DIR is not in PATH"
    echo ""
    echo "Add this to your shell config (~/.bashrc or ~/.zshrc):"
    echo ""
    echo "  export PATH=\"\$PATH:$BIN_DIR\""
    echo ""
    echo "Then run: source ~/.bashrc (or ~/.zshrc)"
    echo ""
fi

# Create wrapper that sets CCT_SOURCE
cat > "$BIN_DIR/cct" << EOF
#!/bin/bash
export CCT_SOURCE="$SCRIPT_DIR"
export CCT_HOME="\${CCT_HOME:-\$HOME/.cct}"
exec "$SCRIPT_DIR/cct" "\$@"
EOF
chmod +x "$BIN_DIR/cct"

echo ""
log_info "Installation complete!"
echo ""
echo "Usage:"
echo "  cct add .      Install TriFlow to current project"
echo "  cct add all    Install TriFlow globally"
echo "  cct update     Update cct and all installations"
echo "  cct help       Show all commands"
echo ""

# Ask about immediate installation
echo ""
read -p "Install TriFlow globally now? [Y/n] " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    "$BIN_DIR/cct" add all
fi
