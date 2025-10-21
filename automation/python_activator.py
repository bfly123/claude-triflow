#!/usr/bin/env python3
"""
Claude TriFlow Python Activator
轻量级监控脚本：检测 Worker 停止并激活 Brain
"""

import subprocess
import time
import sys
import os
from datetime import datetime

# 配置
WORKER_SESSION = "claude-worker"
BRAIN_SESSION = "brain-temp"
WORK_DIR = "/home/bfly/运维/claude-triflow"
CHECK_INTERVAL = 3
BRAIN_STARTUP_WAIT = 10
BRAIN_MAX_WAIT = 60

class Colors:
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    RED = '\033[0;31m'
    BLUE = '\033[0;34m'
    NC = '\033[0m'

def log(message, color=Colors.GREEN):
    """日志输出"""
    timestamp = datetime.now().strftime("%H:%M:%S")
    print(f"{color}[{timestamp}] {message}{Colors.NC}", flush=True)

def check_session_exists(session_name):
    """检查 tmux 会话是否存在"""
    try:
        result = subprocess.run(
            ["tmux", "has-session", "-t", session_name],
            capture_output=True,
            timeout=5
        )
        return result.returncode == 0
    except:
        return False

def get_worker_output(lines=10):
    """获取 Worker 输出的最后 N 行"""
    try:
        result = subprocess.run(
            ["tmux", "capture-pane", "-t", WORKER_SESSION, "-p"],
            capture_output=True,
            text=True,
            timeout=5
        )
        if result.returncode == 0:
            all_lines = result.stdout.split('\n')
            return '\n'.join(all_lines[-lines:])
        return ""
    except Exception as e:
        log(f"获取 Worker 输出失败: {e}", Colors.RED)
        return ""

def is_worker_running():
    """检测 Worker 是否在运行（检测 'esc to interrupt'）"""
    output = get_worker_output(10)
    return "(esc to interrupt)" in output.lower()

def activate_brain():
    """激活 Brain 临时会话"""
    log("🧠 激活 Brain...", Colors.BLUE)

    # 如果 Brain 会话已存在，先关闭
    if check_session_exists(BRAIN_SESSION):
        log("关闭旧的 Brain 会话...", Colors.YELLOW)
        try:
            subprocess.run(["tmux", "kill-session", "-t", BRAIN_SESSION], timeout=5)
            time.sleep(1)
        except:
            pass

    # 创建临时 Brain 会话
    try:
        subprocess.run(
            ["tmux", "new-session", "-d", "-s", BRAIN_SESSION],
            timeout=5,
            check=True
        )
    except Exception as e:
        log(f"创建 Brain 会话失败: {e}", Colors.RED)
        return False

    time.sleep(1)

    # 启动 claude
    try:
        subprocess.run(
            ["tmux", "send-keys", "-t", BRAIN_SESSION,
             f"cd {WORK_DIR} && claude", "Enter"],
            timeout=5
        )
    except Exception as e:
        log(f"启动 claude 失败: {e}", Colors.RED)
        return False

    log(f"等待 Brain 启动... ({BRAIN_STARTUP_WAIT}秒)", Colors.YELLOW)
    time.sleep(BRAIN_STARTUP_WAIT)

    # 读取并发送提示词
    prompt_file = os.path.join(WORK_DIR, "brain_controller_prompt.md")

    if not os.path.exists(prompt_file):
        log(f"提示词文件不存在: {prompt_file}", Colors.RED)
        return False

    try:
        with open(prompt_file, 'r', encoding='utf-8') as f:
            prompt = f.read()
    except Exception as e:
        log(f"读取提示词失败: {e}", Colors.RED)
        return False

    # 使用 tmux load-buffer 发送提示词
    try:
        proc = subprocess.Popen(
            ["tmux", "load-buffer", "-"],
            stdin=subprocess.PIPE
        )
        proc.communicate(prompt.encode('utf-8'))

        subprocess.run(
            ["tmux", "paste-buffer", "-t", BRAIN_SESSION, "-d"],
            timeout=5
        )
        time.sleep(1)

        # 提交（双 Enter）
        subprocess.run(
            ["tmux", "send-keys", "-t", BRAIN_SESSION, "Enter"],
            timeout=5
        )
        time.sleep(1)
        subprocess.run(
            ["tmux", "send-keys", "-t", BRAIN_SESSION, "Enter"],
            timeout=5
        )

        log("✅ Brain 提示词已发送", Colors.GREEN)

    except Exception as e:
        log(f"发送提示词失败: {e}", Colors.RED)
        return False

    # 等待 Brain 处理完成
    log("等待 Brain 处理...", Colors.YELLOW)

    for i in range(BRAIN_MAX_WAIT):
        time.sleep(1)

        # 检测 Brain 是否还在运行
        try:
            output = subprocess.check_output(
                ["tmux", "capture-pane", "-t", BRAIN_SESSION, "-p"],
                text=True,
                timeout=5
            )
            last_lines = '\n'.join(output.split('\n')[-5:])

            # 如果 Brain 不在运行中（没有 esc to interrupt），说明处理完成
            if "(esc to interrupt)" not in last_lines.lower():
                log(f"✅ Brain 处理完成 ({i+1}秒)", Colors.GREEN)
                break

        except:
            # 会话可能已关闭
            log(f"✅ Brain 已退出 ({i+1}秒)", Colors.GREEN)
            break
    else:
        log(f"⚠️  Brain 处理超时 ({BRAIN_MAX_WAIT}秒)", Colors.YELLOW)

    # 清理：关闭 Brain 会话
    time.sleep(2)
    try:
        if check_session_exists(BRAIN_SESSION):
            subprocess.run(
                ["tmux", "kill-session", "-t", BRAIN_SESSION],
                timeout=5
            )
            log("🗑️  Brain 会话已关闭", Colors.BLUE)
    except:
        pass

    return True

def check_all_complete():
    """检查是否所有任务完成"""
    state_file = os.path.join(WORK_DIR, "task_state.json")

    if not os.path.exists(state_file):
        return False

    try:
        with open(state_file, 'r') as f:
            content = f.read()
            return '"status": "all_complete"' in content
    except:
        return False

def main():
    """主函数"""
    log("=== Claude TriFlow Python Activator ===", Colors.BLUE)
    log(f"Worker 会话: {WORKER_SESSION}")
    log(f"工作目录: {WORK_DIR}")
    log(f"检查间隔: {CHECK_INTERVAL} 秒")

    # 检查 Worker 会话
    if not check_session_exists(WORKER_SESSION):
        log(f"❌ Worker 会话不存在: {WORKER_SESSION}", Colors.RED)
        log("请先启动 Worker 会话", Colors.YELLOW)
        sys.exit(1)

    log(f"✅ Worker 会话已就绪", Colors.GREEN)

    # 初始化：第一次激活 Brain 发送第一个任务
    log("🚀 初始化：激活 Brain 发送第一个任务", Colors.BLUE)
    activate_brain()

    log("等待 Worker 开始执行...")
    time.sleep(5)

    # 主监控循环
    log("🔄 开始监控循环...", Colors.BLUE)

    last_running_state = True
    activation_count = 0

    while True:
        time.sleep(CHECK_INTERVAL)

        # 检查是否所有任务完成
        if check_all_complete():
            log("🎉 所有任务完成！监控结束", Colors.GREEN)
            break

        # 检测 Worker 是否在运行
        is_running = is_worker_running()

        # 检测状态变化：从运行 → 停止
        if last_running_state and not is_running:
            activation_count += 1
            log(f"⚠️  Worker 已停止 → 激活 Brain (第 {activation_count} 次)", Colors.YELLOW)

            # 等待输出稳定
            time.sleep(2)

            # 激活 Brain
            success = activate_brain()

            if not success:
                log("⚠️  Brain 激活失败，将在下次循环重试", Colors.YELLOW)

            # 等待 Brain 处理和 Worker 重新启动
            time.sleep(3)

        last_running_state = is_running

    log("=== Python Activator 已停止 ===", Colors.BLUE)

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        log("\n👋 收到中断信号，退出", Colors.YELLOW)
        sys.exit(0)
    except Exception as e:
        log(f"❌ 发生错误: {e}", Colors.RED)
        sys.exit(1)
