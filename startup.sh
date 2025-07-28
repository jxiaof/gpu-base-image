#!/bin/bash
set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# 显示欢迎信息
clear
echo -e "${CYAN}"
cat << "EOF"

╭─────────────────────────────────────────────────────────────────────╮
│                                                                     │
│                                                                     │
│  ████████╗███████╗███╗   ██╗██╗   ██╗██╗   ██╗███╗   ██╗███╗   ██╗  │
│  ╚══██╔══╝██╔════╝████╗  ██║╚██╗ ██╔╝██║   ██║████╗  ██║████╗  ██║  │
│     ██║   █████╗  ██╔██╗ ██║ ╚████╔╝ ██║   ██║██╔██╗ ██║██╔██╗ ██║  │
│     ██║   ██╔══╝  ██║╚██╗██║  ╚██╔╝  ██║   ██║██║╚██╗██║██║╚██╗██║  │
│     ██║   ███████╗██║ ╚████║   ██║   ╚██████╔╝██║ ╚████║██║ ╚████║  │
│     ╚═╝   ╚══════╝╚═╝  ╚═══╝   ╚═╝    ╚═════╝ ╚═╝  ╚═══╝╚═╝  ╚═══╝  │
│                                                                     │
│                            tenyunn.com                              │
│                      Intelligent Computing Platform                 │
│                                                                     │
╰─────────────────────────────────────────────────────────────────────╯
EOF
echo -e "${NC}"

echo -e "${GREEN}========================================"
echo "    tenyunn.com 智算容器启动成功!"
echo "    Container Name: ${CONTAINER_HOSTNAME}"
echo "    Container ID: ${HOSTNAME}"
echo "    User: ${USER:-root}"
echo "    Date: $(date '+%Y-%m-%d %H:%M:%S')"

# 检查nvidia-smi是否可用
if command -v nvidia-smi &> /dev/null; then
    CUDA_VERSION=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader,nounits | head -1 2>/dev/null || echo "N/A")
    echo "    CUDA Version: ${CUDA_VERSION}"
else
    echo "    CUDA Version: N/A (nvidia-smi not available)"
fi
echo "========================================${NC}"
echo ""

echo -e "${YELLOW}🔧 正在初始化环境...$ -- $TENYUNN_JUPYTER_TOKEN <----->  $TENYUNN_SSH_PWD ${NC}"

# 生成随机密码
ROOT_PASSWORD="${TENYUNN_SSH_PWD:-$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-16)}"
JUPYTER_TOKEN="${TENYUNN_JUPYTER_TOKEN:-$(openssl rand -hex 16)}"

# 设置root密码
echo "root:${ROOT_PASSWORD}" | chpasswd
echo -e "${GREEN}✓${NC} root密码已设置"

# 更新Jupyter配置文件中的token（如果存在）
if [ -f "/root/.jupyter/jupyter_notebook_config.py" ]; then
    sed -i "s/JUPYTER_TOKEN_PLACEHOLDER/${JUPYTER_TOKEN}/" /root/.jupyter/jupyter_notebook_config.py
    echo -e "${GREEN}✓${NC} Jupyter token已设置"
fi

# 显示访问信息
echo -e "${BLUE}🔐 访问凭证:${NC}"
echo -e "  ${YELLOW}Root密码:${NC} ${RED}${ROOT_PASSWORD}${NC}"
echo -e "  ${YELLOW}Jupyter Token:${NC} ${RED}${JUPYTER_TOKEN}${NC}"
echo "${JUPYTER_TOKEN}" > /workspace/.jupyter_token.txt
chmod 600 /workspace/.jupyter_token.txt
echo ""

echo -e "${BLUE}🌐 服务访问地址:${NC}"
echo -e "  ${CYAN}SSH:${NC}     ssh root@<host_ip> -p <ssh_port>"
echo -e "  ${CYAN}Jupyter:${NC} http://<host_ip>:<jupyter_port>/?token=${JUPYTER_TOKEN}"
echo ""

# 启动服务
echo -e "${YELLOW}🚀 正在启动服务...${NC}"

# 确保目录权限正确
if [ -d "/workspace" ]; then
    chown -R root:root /workspace 2>/dev/null || true
    chmod 755 /workspace
fi

# 启动Jupyter Lab服务
# echo "PATH=$PATH" >> /var/log/container/startup_debug.log
# which jupyter >> /var/log/container/startup_debug.log 2>&1
if command -v jupyter &> /dev/null; then
    nohup jupyter lab --config=/root/.jupyter/jupyter_notebook_config.py > /var/log/container/jupyter.log 2>&1 &
    echo -e "${GREEN}✓${NC} Jupyter Lab已启动，日志见 /var/log/container/jupyter.log"
else
    echo -e "${RED}✗ 未检测到jupyter命令，Jupyter服务未启动${NC}"
fi

# SSH服务
if command -v service &> /dev/null; then
    service ssh start
    if [ $? -eq 0 ]; then
        echo -e "  ${GREEN}✓${NC} SSH服务已启动 ${CYAN}(端口: 22)${NC}"
        
        # 显示最终提示
        echo ""
        echo -e "${GREEN}🎉 容器启动完成！${NC}"
        echo -e "${CYAN}请使用以下信息登录:${NC}"
        echo -e "  ${YELLOW}用户名:${NC} root"
        echo -e "  ${YELLOW}密码:${NC} ${RED}${ROOT_PASSWORD}${NC}"
        echo ""
        echo -e "${BLUE}💡 提示:${NC}"
        echo -e "  • 使用 ${YELLOW}nvidia-smi${NC} 查看GPU信息"
        echo -e "  • 使用 ${YELLOW}nvtop${NC} 监控GPU使用情况"
        echo -e "  • 工作目录位于 ${YELLOW}/workspace${NC}"
        echo -e "  • 访问 ${YELLOW}https://tenyunn.com${NC} 获取更多帮助"
        echo ""
        
        # 保持容器运行
        tail -f /dev/null
    fi
    else
        echo -e "  ${RED}✗${NC} SSH服务启动失败"
        exit 1
    fi
else
    echo -e "  ${YELLOW}⚠${NC} service命令不可用，跳过SSH服务启动"
    echo -e "${RED}警告: 无法启动SSH服务，容器可能无法正常访问${NC}"
    tail