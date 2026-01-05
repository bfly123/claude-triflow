#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_PREFIX="${CCA_INSTALL_PREFIX:-$HOME/.local/share/cca}"
BIN_DIR="${CCA_BIN_DIR:-$HOME/.local/bin}"

# GitHub repo (for version injection fallback).
REPO_OWNER="bfly123"
REPO_NAME="claude_code_autoflow"

readonly REPO_ROOT INSTALL_PREFIX BIN_DIR REPO_OWNER REPO_NAME

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { printf "${GREEN}[+]${NC} %s\n" "$1"; }
log_warn() { printf "${YELLOW}[!]${NC} %s\n" "$1"; }
log_error() { printf "${RED}[-]${NC} %s\n" "$1"; }
log_blue() { printf "${BLUE}[*]${NC} %s\n" "$1"; }

usage() {
  cat <<'USAGE'
Usage:
  ./install.sh install
  ./install.sh uninstall

Optional environment variables:
  CCA_INSTALL_PREFIX   Install directory (default: ~/.local/share/cca)
  CCA_BIN_DIR          Executable directory (default: ~/.local/bin)
USAGE
}

detect_platform() {
  local name
  name="$(uname -s 2>/dev/null || echo unknown)"
  case "$name" in
    Linux) echo "linux" ;;
    Darwin) echo "macos" ;;
    *) echo "unknown" ;;
  esac
}

require_platform() {
  local p
  p="$(detect_platform)"
  if [[ "$p" != "linux" && "$p" != "macos" ]]; then
    log_error "Unsupported platform: $(uname -s 2>/dev/null || echo unknown) (Linux/macOS only)"
    exit 1
  fi
}

sed_inplace() {
  local script="$1"
  local file="$2"
  sed -i.bak "$script" "$file"
  rm -f "${file}.bak"
}

handle_migration() {
  local cca_home="${XDG_CONFIG_HOME:-$HOME/.config}/cca"
  local old_bin="$BIN_DIR/cca"
  if [[ -e "$old_bin" && ! -L "$old_bin" ]]; then
    mkdir -p "$cca_home/backup"
    local ts
    ts="$(date +%Y%m%d%H%M%S 2>/dev/null || echo now)"
    mv -f "$old_bin" "$cca_home/backup/cca.$ts"
    log_info "Backed up legacy wrapper: $cca_home/backup/cca.$ts"
  fi
}

copy_project() {
  local staging
  staging="$(mktemp -d)"
  trap 'rm -rf "$staging"' EXIT

  if command -v rsync >/dev/null 2>&1; then
    rsync -a \
      --exclude '.git/' \
      --exclude 'tmp/' \
      --exclude '__pycache__/' \
      --exclude '.pytest_cache/' \
      --exclude '*.session' \
      --exclude '*.lock' \
      --exclude '*.log' \
      --exclude '*.pid' \
      --exclude 'settings.local.json' \
      "$REPO_ROOT"/ "$staging"/
  else
    tar -C "$REPO_ROOT" \
      --exclude '.git' \
      --exclude 'tmp' \
      --exclude '__pycache__' \
      --exclude '.pytest_cache' \
      --exclude '*.session' \
      --exclude '*.lock' \
      --exclude '*.log' \
      --exclude '*.pid' \
      --exclude 'settings.local.json' \
      -cf - . | tar -C "$staging" -xf -
  fi

  rm -rf "$INSTALL_PREFIX"
  mkdir -p "$(dirname "$INSTALL_PREFIX")"
  mv "$staging" "$INSTALL_PREFIX"
  trap - EXIT
}

inject_version_info() {
  local git_commit="" git_date=""

  # Method 1: From local git repo (best effort).
  if command -v git >/dev/null 2>&1 && [[ -d "$REPO_ROOT/.git" ]]; then
    git_commit="$(git -C "$REPO_ROOT" log -1 --format='%h' 2>/dev/null || echo "")"
    git_date="$(git -C "$REPO_ROOT" log -1 --format='%cs' 2>/dev/null || echo "")"
  fi

  # Method 2: From environment variables (passed by cca update).
  if [[ -z "$git_commit" && -n "${CCA_GIT_COMMIT:-}" ]]; then
    git_commit="$CCA_GIT_COMMIT"
    git_date="${CCA_GIT_DATE:-}"
  fi

  # Method 3: From GitHub API (fallback).
  if [[ -z "$git_commit" ]] && ( command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1 ); then
    local api="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/commits/main"
    local api_response
    if command -v curl >/dev/null 2>&1; then
      api_response="$(curl -fsSL "$api" 2>/dev/null || echo "")"
    else
      api_response="$(wget -q -O - "$api" 2>/dev/null || echo "")"
    fi
    if [[ -n "$api_response" ]]; then
      git_commit="$(echo "$api_response" | grep -o '"sha": "[^"]*"' | head -1 | cut -d'"' -f4 | cut -c1-7)"
      git_date="$(echo "$api_response" | grep -o '"date": "[^"]*"' | head -1 | cut -d'"' -f4 | cut -c1-10)"
    fi
  fi

  if [[ -n "$git_commit" && -f "$INSTALL_PREFIX/cca" ]]; then
    sed_inplace "s/^GIT_COMMIT=.*/GIT_COMMIT=\"$git_commit\"/" "$INSTALL_PREFIX/cca"
    sed_inplace "s/^GIT_DATE=.*/GIT_DATE=\"$git_date\"/" "$INSTALL_PREFIX/cca"
  fi
}

install_bin_links() {
  mkdir -p "$BIN_DIR"

  if [[ ! -f "$INSTALL_PREFIX/cca" ]]; then
    log_error "Missing installed cca at: $INSTALL_PREFIX/cca"
    exit 1
  fi

  chmod +x "$INSTALL_PREFIX/cca" "$INSTALL_PREFIX/install.sh" 2>/dev/null || true
  if ln -sf "$INSTALL_PREFIX/cca" "$BIN_DIR/cca" 2>/dev/null; then
    :
  else
    cp -f "$INSTALL_PREFIX/cca" "$BIN_DIR/cca"
    chmod +x "$BIN_DIR/cca" 2>/dev/null || true
  fi

  log_info "Installed: $BIN_DIR/cca"

  # PreToolUse hook (best effort)
  if [[ -f "$INSTALL_PREFIX/cca-roles-hook" ]]; then
    chmod +x "$INSTALL_PREFIX/cca-roles-hook" 2>/dev/null || true
    if ln -sf "$INSTALL_PREFIX/cca-roles-hook" "$BIN_DIR/cca-roles-hook" 2>/dev/null; then
      :
    else
      cp -f "$INSTALL_PREFIX/cca-roles-hook" "$BIN_DIR/cca-roles-hook" 2>/dev/null || true
      chmod +x "$BIN_DIR/cca-roles-hook" 2>/dev/null || true
    fi
    log_info "Installed: $BIN_DIR/cca-roles-hook"
  fi
}

install_global_skills() {
  local target="$HOME/.claude"
  mkdir -p "$target/skills" "$target/commands"

  for skill in tr tp dual-design file-op ask-codex ask-gemini roles review mode-switch docs; do
    rm -rf "$target/skills/$skill" 2>/dev/null || true
    cp -a "$INSTALL_PREFIX/claude_source/skills/$skill" "$target/skills/"
  done

  for cmd in tr.md tp.md dual-design.md file-op.md ask-codex.md ask-gemini.md roles.md review.md mode-switch.md; do
    cp -a "$INSTALL_PREFIX/claude_source/commands/$cmd" "$target/commands/"
  done

  log_info "Installed skills/commands to ~/.claude/ (globally visible)"
}

ensure_path_configured() {
  if [[ ":$PATH:" == *":$BIN_DIR:"* ]]; then
    return
  fi

  local shell_rc=""
  local current_shell
  current_shell="$(basename "${SHELL:-/bin/bash}")"

  case "$current_shell" in
    zsh)  shell_rc="$HOME/.zshrc" ;;
    bash)
      if [[ -f "$HOME/.bash_profile" ]]; then
        shell_rc="$HOME/.bash_profile"
      else
        shell_rc="$HOME/.bashrc"
      fi
      ;;
    *)    shell_rc="$HOME/.profile" ;;
  esac

  local marker="# Added by cca installer"
  local path_line="export PATH=\"\$HOME/.local/bin:\$PATH\""

  if [[ -f "$shell_rc" ]] && grep -qF "$marker" "$shell_rc" 2>/dev/null; then
    log_warn "PATH update already present in $shell_rc (restart terminal to apply)"
    return
  fi

  {
    echo ""
    echo "$marker"
    echo "$path_line"
  } >> "$shell_rc"

  log_warn "Added PATH export to $shell_rc (restart terminal to apply)"
}

cmd_install() {
  require_platform
  handle_migration

  log_blue "Installing cca to: $INSTALL_PREFIX"
  copy_project
  inject_version_info
  install_bin_links
  install_global_skills
  ensure_path_configured
  log_info "Installation complete"
}

cmd_uninstall() {
  require_platform

  log_blue "Uninstalling cca..."
  rm -f "$BIN_DIR/cca" 2>/dev/null || true
  rm -rf "$INSTALL_PREFIX" 2>/dev/null || true
  log_info "Uninstall complete"
}

case "${1:-}" in
  install)   cmd_install ;;
  uninstall) cmd_uninstall ;;
  -h|--help|"") usage ;;
  *)
    log_error "Unknown command: $1"
    usage
    exit 1
    ;;
esac
