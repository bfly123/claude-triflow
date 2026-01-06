#!/usr/bin/env python3
"""
cca-roles-hook (PreToolUse)

Hard requirements:
- Best-effort "first tool call" only using a marker file
- Marker invalidates automatically when roles config changes (signature-based)
- Prints a compact, machine-friendly roles payload to stdout for context injection

Roles priority:
1) .autoflow/roles.session.json
2) .autoflow/roles.json
3) ~/.config/cca/roles.json (or $XDG_CONFIG_HOME/cca/roles.json)
4) defaults

Tool blocking:
- If Claude Code invokes Write/Edit, block and instruct delegation based on executor.
"""

from __future__ import annotations

import hashlib
import json
import os
import re
import select
import shlex
import sys
import time
from pathlib import Path
from typing import Any, Optional, Tuple

DEFAULT_ROLES: dict[str, Any] = {
    "schemaVersion": 1,
    "enabled": True,
    "executor": "codex",
    "reviewer": "codex",
    "documenter": "codex",
    "designer": ["claude", "codex"],
    "searcher": "claude",
    "git_manager": "codex",
}


def _find_repo_root(start: Path) -> Path:
    cur = start.resolve()
    for p in [cur, *cur.parents]:
        if (p / ".autoflow").is_dir():
            return p
        if (p / ".claude").is_dir():
            return p
        if (p / ".git").is_dir():
            return p
    return cur


def _config_home() -> Path:
    xdg = os.environ.get("XDG_CONFIG_HOME")
    if xdg:
        return Path(xdg).expanduser()
    return Path.home() / ".config"


def _try_read_json(path: Path) -> Optional[dict[str, Any]]:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        if not isinstance(data, dict):
            return None
        return data
    except Exception:
        return None


def _is_enabled_v1(obj: dict[str, Any]) -> bool:
    try:
        if int(obj.get("schemaVersion", 0)) != 1:
            return False
        return obj.get("enabled", True) is True
    except Exception:
        return False


def _candidates(repo_root: Path) -> list[tuple[Path, str]]:
    return [
        (repo_root / ".autoflow" / "roles.session.json", "session"),
        (repo_root / ".autoflow" / "roles.json", "project"),
        (_config_home() / "cca" / "roles.json", "system"),
    ]


def _file_sig(path: Path) -> str:
    try:
        st = path.stat()
        return f"{path}|{st.st_mtime_ns}|{st.st_size}"
    except FileNotFoundError:
        return f"{path}|missing"
    except Exception:
        return f"{path}|error"


def _config_signature(repo_root: Path) -> str:
    parts = [_file_sig(p) for p, _ in _candidates(repo_root)]
    raw = "\n".join(parts).encode("utf-8", errors="replace")
    return hashlib.sha256(raw).hexdigest()[:16]


def _marker_path(repo_root: Path, sig: str) -> Path:
    repo_hash = hashlib.sha256(str(repo_root).encode("utf-8")).hexdigest()[:12]
    name = f"cca-roles-hook.{repo_hash}.{sig}.marker"
    tmp = os.environ.get("TMPDIR") or os.environ.get("TEMP") or "/tmp"
    return Path(tmp) / name


def _resolve_roles(repo_root: Path) -> Tuple[dict[str, Any], str]:
    for path, label in _candidates(repo_root):
        obj = _try_read_json(path)
        if not obj:
            continue
        if not _is_enabled_v1(obj):
            continue
        return obj, f"{label}:{path}"
    return DEFAULT_ROLES, "default"


def _tool_name() -> str:
    for key in (
        "CLAUDE_TOOL_NAME",
        "CLAUDE_TOOL",
        "ANTHROPIC_TOOL_NAME",
        "TOOL_NAME",
    ):
        val = os.environ.get(key)
        if isinstance(val, str) and val.strip():
            return val.strip()
    return ""


def _tool_input_from_env() -> Any:
    for key in ("CLAUDE_TOOL_INPUT", "CLAUDE_TOOLINPUT", "ANTHROPIC_TOOL_INPUT", "TOOL_INPUT"):
        val = os.environ.get(key)
        if not isinstance(val, str) or not val.strip():
            continue
        try:
            return json.loads(val)
        except Exception:
            return None
    return None


def _merge_env_payload(obj: Any) -> Any:
    tool = _tool_name()
    tool_input = _tool_input_from_env()
    if not tool and tool_input is None:
        return obj

    env_obj: dict[str, Any] = {}
    if tool:
        env_obj["tool_name"] = tool
    if isinstance(tool_input, dict):
        env_obj["tool_input"] = tool_input

    if not env_obj:
        return obj
    if obj is None or not isinstance(obj, dict):
        return env_obj
    for k, v in env_obj.items():
        obj.setdefault(k, v)
    return obj

def _tool_name_from_payload(obj: Any) -> str:
    if isinstance(obj, dict):
        for key in ("tool_name", "toolName", "tool", "name"):
            if key not in obj:
                continue
            val = obj.get(key)
            if isinstance(val, str) and val.strip():
                return val.strip()
            if isinstance(val, dict):
                for k2 in ("tool_name", "toolName", "name"):
                    v2 = val.get(k2)
                    if isinstance(v2, str) and v2.strip():
                        return v2.strip()
        for key in ("params", "parameters", "input", "data", "event", "payload", "request"):
            val = obj.get(key)
            name = _tool_name_from_payload(val)
            if name:
                return name
    elif isinstance(obj, list):
        for item in obj:
            name = _tool_name_from_payload(item)
            if name:
                return name
    return ""


def _extract_file_path_from_payload(obj: Any) -> str:
    if not isinstance(obj, dict):
        return ""

    def _from_tool_input(d: dict) -> str:
        tool_input = d.get("tool_input")
        if not isinstance(tool_input, dict):
            tool_input = d.get("toolInput")
        if not isinstance(tool_input, dict):
            return ""
        fp = tool_input.get("file_path")
        if not isinstance(fp, str):
            fp = tool_input.get("filePath")
        if isinstance(fp, str) and fp.strip():
            return fp.strip()
        return ""

    fp = _from_tool_input(obj)
    if fp:
        return fp

    for key in ("params", "parameters", "input", "data", "event", "payload", "request"):
        val = obj.get(key)
        if isinstance(val, dict):
            fp = _from_tool_input(val)
            if fp:
                return fp
    return ""


def _extract_command_from_payload(obj: Any) -> str:
    if not isinstance(obj, dict):
        return ""

    def _from_tool_input(d: dict) -> str:
        tool_input = d.get("tool_input")
        if not isinstance(tool_input, dict):
            tool_input = d.get("toolInput")
        if not isinstance(tool_input, dict):
            return ""
        cmd = tool_input.get("command")
        if not isinstance(cmd, str):
            cmd = tool_input.get("cmd")
        if isinstance(cmd, str) and cmd.strip():
            return cmd.strip()
        return ""

    cmd = _from_tool_input(obj)
    if cmd:
        return cmd

    for key in ("params", "parameters", "input", "data", "event", "payload", "request"):
        val = obj.get(key)
        if isinstance(val, dict):
            cmd = _from_tool_input(val)
            if cmd:
                return cmd
    return ""


def _is_under(path: Path, base: Path) -> bool:
    try:
        path.relative_to(base)
        return True
    except Exception:
        return False


def _normalize_target_path(file_path: str, cwd: Path) -> Optional[Path]:
    if not isinstance(file_path, str) or not file_path.strip():
        return None
    p = Path(file_path.strip()).expanduser()
    if not p.is_absolute():
        p = (cwd / p)
    try:
        return p.resolve(strict=False)
    except Exception:
        return p.absolute()


def _is_whitelisted(target: Path, repo_root: Path) -> bool:
    allow = [
        (Path.home() / ".claude" / "plans").expanduser(),
        Path("/tmp"),
        (repo_root / ".autoflow"),
    ]
    for base in allow:
        try:
            base_resolved = base.resolve(strict=False)
        except Exception:
            base_resolved = base
        if _is_under(target, base_resolved):
            return True
    return False


def _read_stdin_with_timeout(timeout: float = 0.1, max_bytes: int = 2_000_000) -> str:
    try:
        if sys.stdin is None:
            return ""
        fd = sys.stdin.fileno()
    except Exception:
        return ""

    chunks: list[bytes] = []
    total = 0
    deadline = time.monotonic() + float(timeout)

    try:
        while time.monotonic() < deadline:
            remaining = deadline - time.monotonic()
            r, _, _ = select.select([fd], [], [], max(0.0, remaining))
            if not r:
                break
            data = os.read(fd, 65536)
            if not data:
                break
            chunks.append(data)
            total += len(data)
            if total >= max_bytes:
                break
            # Drain any immediately available bytes without waiting.
            while True:
                r2, _, _ = select.select([fd], [], [], 0.0)
                if not r2:
                    break
                data2 = os.read(fd, 65536)
                if not data2:
                    break
                chunks.append(data2)
                total += len(data2)
                if total >= max_bytes:
                    break
    except Exception:
        return ""

    if not chunks:
        return ""
    return b"".join(chunks).decode("utf-8", errors="replace")


def _is_file_mod_tool(name: str) -> bool:
    n = name.strip().lower()
    return n in {"write", "edit"}


def _is_bash_tool(name: str) -> bool:
    return (name or "").strip().lower() == "bash"


def _is_delegation_command(tokens: list[str]) -> bool:
    """Check if command is a delegation command (cask/oask/gask)."""
    if not tokens:
        return False
    cmd = tokens[0].lower()
    return cmd in {"cask", "oask", "gask", "cask-w", "oask-w", "gask-w"}


def _is_exit_plan_mode(name: str) -> bool:
    """Check if tool is ExitPlanMode."""
    n = (name or "").strip().lower().replace("_", "")
    return n in {"exitplanmode", "exitplan"}


def _is_readonly_tool(name: str) -> bool:
    n = (name or "").strip().lower()
    return n in {"read", "grep", "glob", "lsp"}


def _is_search_tool(name: str) -> bool:
    n = (name or "").strip().lower()
    return n in {"websearch", "webfetch"}


def _role_value(roles: dict[str, Any], key: str, default: str) -> str:
    val = roles.get(key, default)
    if isinstance(val, str) and val.strip():
        return val.strip()
    return default


def _is_claude_role(val: str) -> bool:
    return isinstance(val, str) and val.strip().lower() == "claude"


def _block_executor(executor: str) -> int:
    sys.stderr.write(
        "File modification blocked. Use executor delegation:\n"
        '      - executor=codex: cask "<task>"\n'
        '      - executor=opencode: oask "<task>"\n'
        f"      Current executor: {executor}\n"
    )
    return 2


def _block_git_manager(git_manager: str) -> int:
    hint = "cask"
    if git_manager.strip().lower() == "opencode":
        hint = "oask"
    elif git_manager.strip().lower() == "gemini":
        hint = "gask"
    sys.stderr.write(
        "Git operation blocked. Use git_manager delegation:\n"
        f'      - git_manager={git_manager}: {hint} "<task>"\n'
        f"      Current git_manager: {git_manager}\n"
    )
    return 2


def _block_searcher(searcher: str) -> int:
    hint = "cask"
    s = (searcher or "").strip().lower()
    if s == "opencode":
        hint = "oask"
    elif s == "gemini":
        hint = "gask"
    sys.stderr.write(f"Search blocked. Use searcher delegation: {hint}\n")
    return 2


def _safe_shlex_split(command: str) -> list[str]:
    try:
        return shlex.split(command, posix=True)
    except Exception:
        return []


def _git_subcommand(tokens: list[str]) -> str:
    if len(tokens) >= 2 and tokens[0] == "git":
        return tokens[1]
    return ""


def _is_git_readonly_subcmd(subcmd: str) -> bool:
    return subcmd in {"status", "log", "diff", "show"}


def _is_git_mutating_subcmd(subcmd: str) -> bool:
    return subcmd in {"add", "commit", "push", "merge", "rebase", "reset"}


def _extract_redirect_targets(command: str) -> list[str]:
    targets: list[str] = []
    for m in re.finditer(r"(?:^|[^\"])(?:\d?>|>>|&>>|&>)\s*([^\s;|&]+)", command):
        t = (m.group(1) or "").strip()
        if t:
            targets.append(t)
    return targets


def _extract_tee_targets(tokens: list[str]) -> list[str]:
    targets: list[str] = []
    i = 0
    while i < len(tokens):
        if tokens[i] != "tee":
            i += 1
            continue
        i += 1
        while i < len(tokens) and tokens[i].startswith("-"):
            i += 1
        while i < len(tokens) and tokens[i] not in {"|", ";", "&&", "||"}:
            t = tokens[i]
            if t and not t.startswith("-"):
                targets.append(t)
            i += 1
    return targets


def _extract_cp_mv_dest(tokens: list[str]) -> Optional[str]:
    if not tokens:
        return None
    cmd = tokens[0]
    if cmd not in {"cp", "mv"}:
        return None
    args = [t for t in tokens[1:] if t and not t.startswith("-")]
    if len(args) >= 2:
        return args[-1]
    return None


def _extract_rm_targets(tokens: list[str]) -> list[str]:
    if not tokens or tokens[0] != "rm":
        return []
    return [t for t in tokens[1:] if t and not t.startswith("-")]


def _extract_sed_inplace_targets(tokens: list[str]) -> list[str]:
    if not tokens:
        return []
    if tokens[0] not in {"sed", "gsed"}:
        return []
    if not any(t.startswith("-i") for t in tokens[1:]):
        return []
    args = [t for t in tokens[1:] if t and not t.startswith("-")]
    if args:
        return [args[-1]]
    return []


def _bash_touches_repo(paths: list[str], cwd: Path, repo_root: Path) -> bool:
    for p in paths:
        target = _normalize_target_path(p, cwd)
        if target is None:
            continue
        if _is_under(target, repo_root) and not _is_whitelisted(target, repo_root):
            return True
    return False


def main() -> int:
    raw = ""
    obj: Any = None
    try:
        raw = _read_stdin_with_timeout(0.1)
        if raw.strip():
            obj = json.loads(raw)
    except Exception:
        obj = None
    obj = _merge_env_payload(obj)

    try:
        with open("/tmp/cca-hook-debug.log", "a", encoding="utf-8") as f:
            f.write("--- hook called ---\n")
            f.write(f"stdin_len={len(raw)}\n")
            if raw.strip():
                f.write("stdin_raw:\n")
                max_len = 20000
                if len(raw) > max_len:
                    f.write(raw[:max_len] + "\n...[truncated]...\n")
                else:
                    f.write(raw + ("\n" if not raw.endswith("\n") else ""))
            else:
                f.write("stdin_raw:<empty>\n")
            for k, v in sorted(os.environ.items()):
                if "CLAUDE" in k or "TOOL" in k or "ANTHROPIC" in k:
                    upper = k.upper()
                    val = v
                    if any(s in upper for s in ("TOKEN", "KEY", "SECRET", "PASSWORD")):
                        val = "<redacted>"
                    f.write(f"{k}={val}\n")
            f.write("\n")
    except Exception:
        pass

    repo_root = _find_repo_root(Path.cwd())

    tool = _tool_name_from_payload(obj) if obj is not None else ""
    if not tool:
        tool = _tool_name()

    # Check ExitPlanMode first (plan mode enforcement)
    if _is_exit_plan_mode(tool):
        roles, _ = _resolve_roles(repo_root)
        if roles.get("plan_mode_enforced", False):
            sys.stderr.write(
                "ExitPlanMode blocked (plan_mode_enforced=true).\n"
                "Use delegation: cask/oask/gask\n"
                "To disable: set plan_mode_enforced=false in .autoflow/roles.json\n"
            )
            return 2

    if _is_search_tool(tool):
        roles, _ = _resolve_roles(repo_root)
        searcher = _role_value(roles, "searcher", "claude")
        if not _is_claude_role(searcher):
            return _block_searcher(searcher)

    if _is_readonly_tool(tool):
        pass
    elif _is_file_mod_tool(tool):
        file_path = _extract_file_path_from_payload(obj) if obj is not None else ""
        target = _normalize_target_path(file_path, Path.cwd())
        if target is not None and _is_under(target, repo_root) and not _is_whitelisted(target, repo_root):
            roles, _source = _resolve_roles(repo_root)
            executor = _role_value(roles, "executor", "codex")
            if not _is_claude_role(executor):
                return _block_executor(executor)
    elif _is_bash_tool(tool):
        command = _extract_command_from_payload(obj) if obj is not None else ""
        tokens = _safe_shlex_split(command)
        # Allow delegation commands (cask/oask/gask) to pass through
        if _is_delegation_command(tokens):
            pass
        else:
            subcmd = _git_subcommand(tokens)
            if _is_git_readonly_subcmd(subcmd):
                pass
            elif _is_git_mutating_subcmd(subcmd):
                roles, _source = _resolve_roles(repo_root)
                gm = _role_value(roles, "git_manager", "codex")
                if not _is_claude_role(gm):
                    return _block_git_manager(gm)
            else:
                paths: list[str] = []
                if command:
                    paths.extend(_extract_redirect_targets(command))
                paths.extend(_extract_tee_targets(tokens))
                paths.extend(_extract_sed_inplace_targets(tokens))
                paths.extend(_extract_rm_targets(tokens))
                dest = _extract_cp_mv_dest(tokens)
                if dest:
                    paths.append(dest)

                if paths and _bash_touches_repo(paths, Path.cwd(), repo_root):
                    roles, _source = _resolve_roles(repo_root)
                    executor = _role_value(roles, "executor", "codex")
                    if not _is_claude_role(executor):
                        return _block_executor(executor)

    sig = _config_signature(repo_root)
    marker = _marker_path(repo_root, sig)

    try:
        if marker.exists():
            return 0
        marker.write_text("ok\n", encoding="utf-8")
    except Exception:
        # If marker write fails, still output (best effort).
        pass

    roles, source = _resolve_roles(repo_root)

    payload = {
        "proto": "cca.roles.v1",
        "source": source,
        "repoRoot": str(repo_root),
        "roles": roles,
    }
    sys.stdout.write("[CCA_ROLES_V1] " + json.dumps(payload, ensure_ascii=False, separators=(",", ":")) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
