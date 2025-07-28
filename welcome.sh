#!/bin/bash

# 定义颜色
GREEN='\033[32m'
BLUE='\033[34m'
YELLOW='\033[33m'
CYAN='\033[36m'
MAGENTA='\033[35m'
RESET='\033[0m'
BOLD='\033[1m'

# 获取Docker容器分配的资源
get_docker_resources() {
    # CPU核心数获取
    local cpu_cores=""
    
    # 优先从环境变量读取（启动时传入）
    if [ -n "$CPU_LIMIT" ]; then
        cpu_cores="$CPU_LIMIT"
    # 从Docker cgroup读取CPU限制
    elif [ -f "/sys/fs/cgroup/cpu/cpu.cfs_quota_us" ] && [ -f "/sys/fs/cgroup/cpu/cpu.cfs_period_us" ]; then
        local quota=$(cat /sys/fs/cgroup/cpu/cpu.cfs_quota_us 2>/dev/null || echo "-1")
        local period=$(cat /sys/fs/cgroup/cpu/cpu.cfs_period_us 2>/dev/null || echo "100000")
        if [ "$quota" -gt 0 ] && [ "$period" -gt 0 ]; then
            cpu_cores=$(echo "scale=1; $quota / $period" | bc 2>/dev/null || echo $((quota / period)))
        fi
    # 从Docker cgroup v2读取
    elif [ -f "/sys/fs/cgroup/cpu.max" ]; then
        local cpu_max=$(cat /sys/fs/cgroup/cpu.max 2>/dev/null)
        if [ "$cpu_max" != "max" ] && [ -n "$cpu_max" ]; then
            local quota=$(echo $cpu_max | cut -d' ' -f1)
            local period=$(echo $cpu_max | cut -d' ' -f2)
            if [ "$quota" != "max" ] && [ "$period" -gt 0 ]; then
                cpu_cores=$(echo "scale=1; $quota / $period" | bc 2>/dev/null || echo $((quota / period)))
            fi
        fi
    fi
    
    # 默认值
    CPU_CORES=${cpu_cores:-$(nproc)}
    
    # 内存限制获取
    local memory_limit=""
    
    # 优先从环境变量读取
    if [ -n "$MEMORY_LIMIT" ]; then
        memory_limit="$MEMORY_LIMIT"
    # 从Docker cgroup读取内存限制
    elif [ -f "/sys/fs/cgroup/memory/memory.limit_in_bytes" ]; then
        local limit=$(cat /sys/fs/cgroup/memory/memory.limit_in_bytes 2>/dev/null || echo "0")
        # 检查是否是合理的限制值（不是系统最大值）
        if [ "$limit" -gt 0 ] && [ "$limit" -lt 9223372036854775807 ]; then
            local limit_gb=$((limit / 1024 / 1024 / 1024))
            memory_limit="${limit_gb}G"
        fi
    # 从Docker cgroup v2读取
    elif [ -f "/sys/fs/cgroup/memory.max" ]; then
        local limit=$(cat /sys/fs/cgroup/memory.max 2>/dev/null)
        if [ "$limit" != "max" ] && [ -n "$limit" ]; then
            local limit_gb=$((limit / 1024 / 1024 / 1024))
            memory_limit="${limit_gb}G"
        fi
    fi
    
    # 默认值
    ALLOCATED_MEMORY=${memory_limit:-$(free -h | awk 'NR==2{print $2}')}
}

# 获取容器信息
get_container_info() {
    # 尝试获取容器ID
    if [ -f "/proc/self/cgroup" ]; then
        CONTAINER_ID=$(cat /proc/self/cgroup | head -1 | sed 's/.*\///' | cut -c1-12 2>/dev/null)
    fi
    
    # 尝试从hostname获取容器名
    CONTAINER_NAME=$(hostname 2>/dev/null)
}

echo -e "${BLUE}============================ WELCOME =================================="
echo -e "${BOLD}${BLUE}                     欢迎进入腾云智算云平台${RESET}"
echo -e "${BLUE}=========================== WELCOME =================================="
echo -e "${GREEN}"
echo -e "╭─────────────────────────────────────────────────────────────────────╮"
echo -e "│                                                                     │"
echo -e "│                                                                     │"
echo -e "│  ████████╗███████╗███╗   ██╗██╗   ██╗██╗   ██╗███╗   ██╗███╗   ██╗  │"
echo -e "│  ╚══██╔══╝██╔════╝████╗  ██║╚██╗ ██╔╝██║   ██║████╗  ██║████╗  ██║  │"
echo -e "│     ██║   █████╗  ██╔██╗ ██║ ╚████╔╝ ██║   ██║██╔██╗ ██║██╔██╗ ██║  │"
echo -e "│     ██║   ██╔══╝  ██║╚██╗██║  ╚██╔╝  ██║   ██║██║╚██╗██║██║╚██╗██║  │"
echo -e "│     ██║   ███████╗██║ ╚████║   ██║   ╚██████╔╝██║ ╚████║██║ ╚████║  │"
echo -e "│     ╚═╝   ╚══════╝╚═╝  ╚═══╝   ╚═╝    ╚═════╝ ╚═╝  ╚═══╝╚═╝  ╚═══╝  │"
echo -e "│                                                                     │"
echo -e "│                            ${CYAN}tenyunn.com${GREEN}                              │"
echo -e "│                      ${MAGENTA}Intelligent Computing Platform${GREEN}                 │"
echo -e "│                                                                     │"
echo -e "╰─────────────────────────────────────────────────────────────────────╯"

echo -e "${YELLOW}════════════════════════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}容器信息:${RESET}"
echo -e "   用户: ${CYAN}$(whoami)${RESET}"
echo -e "   时间: ${CYAN}$(date +"%Y-%m-%d %H:%M:%S")${RESET}"
echo -e "   主机: ${CYAN}$(hostname)${RESET}"
echo -e "   系统: ${CYAN}$(uname -s) $(uname -r)${RESET}"

# 获取分配的资源和容器信息
get_docker_resources
get_container_info

# 显示容器分配的资源
echo -e "   CPU核心: ${CYAN}${CPU_CORES} cores${RESET}"

# 获取内存使用情况
USED_MEM=$(free -h | awk 'NR==2{print $3}')
MEM_USAGE=$(free | awk 'NR==2{printf "%.1f%%", $3*100/$2}')
echo -e "   内存: ${CYAN}${USED_MEM}/${ALLOCATED_MEMORY} (${MEM_USAGE})${RESET}"

# 显示容器信息
if [ -n "$CONTAINER_ID" ] && [ "$CONTAINER_ID" != "" ]; then
    echo -e "   容器ID: ${CYAN}${CONTAINER_ID}${RESET}"
fi

if [ -n "$TENANT_ID" ]; then
    echo -e "   租户ID: ${CYAN}${TENANT_ID}${RESET}"
fi

echo ""
echo -e "${BOLD}磁盘信息:${RESET}"

# 系统盘信息
SYS_DISK_INFO=$(df -h / | awk 'NR==2{print $3"/"$2" ("$5")"}')
echo -e "   系统盘(/): ${CYAN}${SYS_DISK_INFO}${RESET}"

# # 工作目录信息
# if [ -d "/workspace" ]; then
#     WORKSPACE_INFO=$(df -h /workspace | awk 'NR==2{print $3"/"$2" ("$5")"}')
#     echo -e "   工作目录(/workspace): ${CYAN}${WORKSPACE_INFO}${RESET}"
# fi

# 数据盘信息
if [ -d "/datadisk" ]; then
    DATA_DISK_INFO=$(df -h /datadisk | awk 'NR==2{print $3"/"$2" ("$5")"}')
    echo -e "   数据盘(/datadisk): ${CYAN}${DATA_DISK_INFO}${RESET}"
fi

# 获取GPU信息
if command -v nvidia-smi &> /dev/null; then
    echo ""
    echo -e "${BOLD}GPU信息:${RESET}"
    
    # 获取CUDA版本
    CUDA_VERSION=$(nvidia-smi | grep -oP "CUDA Version: \K[0-9.]+" | head -1)
    echo -e "   CUDA版本: ${MAGENTA}${CUDA_VERSION}${RESET}"
    
    # 获取GPU数量和型号
    GPU_COUNT=$(nvidia-smi -L | wc -l)
    # 获取第一个GPU的型号作为代表
    GPU_MODEL=$(nvidia-smi -L | head -1 | sed 's/GPU [0-9]*: //' | sed 's/ (UUID:.*//')
    
    echo -e "   GPU数量: ${MAGENTA}${GPU_COUNT}${RESET}"
    echo -e "   GPU型号: ${GREEN}${GPU_MODEL}${RESET}"
else
    echo ""
    echo -e "${BOLD}GPU信息:${RESET}"
    echo -e "   ❌ 未检测到NVIDIA GPU"
fi

echo -e "${YELLOW}════════════════════════════════════════════════════════════════════${RESET}"

# 显示PyTorch环境信息
# if python3 -c "import torch" 2>/dev/null; then
#     echo -e "${BOLD}PyTorch环境:${RESET}"
#     TORCH_VERSION=$(python3 -c "import torch; print(torch.__version__)" 2>/dev/null)
#     TORCH_CUDA=$(python3 -c "import torch; print('是' if torch.cuda.is_available() else '否')" 2>/dev/null)
#     echo -e "   PyTorch版本: ${GREEN}${TORCH_VERSION}${RESET}"
#     echo -e "   CUDA支持: ${GREEN}${TORCH_CUDA}${RESET}"
#     echo -e "${YELLOW}════════════════════════════════════════════════════════════════════${RESET}"
# fi

echo -e "${GREEN}=====================================================${RESET}"
echo -e "${BOLD}${CYAN}⚠️  注意事项:${RESET}"
echo -e "${YELLOW}  • 当前容器资源限制: CPU=${CPU_CORES}核, 内存=${ALLOCATED_MEMORY}${RESET}"
# echo -e "${YELLOW}  • 定期保存工作进度到 /workspace 目录${RESET}"
echo -e "${YELLOW}  • 长时间训练建议使用 screen 或 tmux${RESET}"
echo -e "${YELLOW}  • 监控GPU使用情况: nvidia-smi${RESET}"
echo -e "${GREEN}=====================================================${RESET}"
echo -e "${BOLD}${CYAN}💡 tips:${RESET}"
echo -e "${YELLOW}  • 文档说明: ${CYAN}请访问 -> https://docs.tenyunn.com${RESET}"
echo -e "${YELLOW}  • 提交反馈: ${CYAN}请登录 -> https://cloud.tenyunn.com 提交工单${RESET}"
# echo -e "${YELLOW}  • 启动Jupyter: ${CYAN}jupyter lab --ip=0.0.0.0 --port=8888 --allow-root${RESET}"
# echo -e "${YELLOW}  • 查看PyTorch: ${CYAN}python -c 'import torch; print(torch.__version__)'${RESET}"
echo -e "${GREEN}=====================================================${RESET}"