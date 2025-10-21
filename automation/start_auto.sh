#!/bin/bash

# Claude TriFlow 自动化系统启动脚本

WORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$WORK_DIR"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Claude TriFlow 自动化系统启动        ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# 步骤 1: 检查依赖
echo -e "${YELLOW}[1/5] 检查依赖...${NC}"

if ! command -v tmux &> /dev/null; then
    echo -e "${RED}❌ tmux 未安装${NC}"
    exit 1
fi

if ! command -v claude &> /dev/null; then
    echo -e "${RED}❌ claude 命令未找到${NC}"
    exit 1
fi

if ! command -v python3 &> /dev/null; then
    echo -e "${RED}❌ python3 未安装${NC}"
    exit 1
fi

echo -e "${GREEN}✅ 依赖检查通过${NC}"

# 步骤 2: 初始化状态文件
echo -e "${YELLOW}[2/5] 初始化状态文件...${NC}"

if [ ! -f "task_state.json" ]; then
    echo -e "${YELLOW}运行 init_state.sh...${NC}"
    bash init_state.sh
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ 初始化失败${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✅ task_state.json 已存在${NC}"
    echo -e "${YELLOW}当前状态:${NC}"
    cat task_state.json | grep -E '"current_task"|"total_tasks"|"status"'
    echo ""
    read -p "是否重新初始化？(y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        bash init_state.sh
    fi
fi

# 步骤 3: 启动 Worker 会话
echo -e "${YELLOW}[3/5] 启动 Worker 会话...${NC}"

if tmux has-session -t claude-worker 2>/dev/null; then
    echo -e "${YELLOW}⚠️  Worker 会话已存在${NC}"
    read -p "是否重启 Worker 会话？(y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        tmux kill-session -t claude-worker
        sleep 1
    else
        echo -e "${GREEN}✅ 使用现有 Worker 会话${NC}"
    fi
fi

if ! tmux has-session -t claude-worker 2>/dev/null; then
    echo -e "${GREEN}创建 Worker 会话...${NC}"
    tmux new-session -d -s claude-worker
    sleep 1

    tmux send-keys -t claude-worker "cd '$WORK_DIR'" Enter
    sleep 1
    tmux send-keys -t claude-worker "claude" Enter

    echo -e "${YELLOW}等待 Worker 启动...（10秒）${NC}"
    sleep 10

    echo -e "${GREEN}✅ Worker 会话已创建${NC}"
fi

# 步骤 4: 显示系统信息
echo -e "${YELLOW}[4/5] 系统信息${NC}"
echo -e "  工作目录: ${GREEN}$WORK_DIR${NC}"
echo -e "  任务文件: ${GREEN}tasks.md${NC}"
echo -e "  状态文件: ${GREEN}task_state.json${NC}"
echo -e "  Worker 会话: ${GREEN}claude-worker${NC}"
echo ""

# 步骤 5: 启动 Python 监控脚本
echo -e "${YELLOW}[5/5] 启动 Python 监控脚本...${NC}"
echo -e "${GREEN}系统即将开始自动执行任务${NC}"
echo ""
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo -e "${YELLOW}提示：${NC}"
echo -e "  查看 Worker:  ${GREEN}tmux attach -t claude-worker${NC}"
echo -e "  停止系统:     ${RED}Ctrl+C${NC} (在此终端)"
echo -e "  查看结果:     ${GREEN}tail -f task_results.md${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo ""

read -p "按 Enter 开始执行..."

echo ""
echo -e "${GREEN}🚀 启动监控...${NC}"
echo ""

# 启动 Python 脚本
python3 python_activator.py

# 清理
echo ""
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo -e "${GREEN}系统已停止${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}"
