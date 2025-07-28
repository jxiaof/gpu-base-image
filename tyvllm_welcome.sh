#!/bin/bash

# 定义颜色
GREEN='\033[32m'
BLUE='\033[34m'
YELLOW='\033[33m'
CYAN='\033[36m'
MAGENTA='\033[35m'
RESET='\033[0m'
BOLD='\033[1m'

echo -e "${GREEN}=======================ty-vllm 环境就绪==============================${RESET}"
echo -e "${BOLD}${BLUE}TyVLLM 大模型推理平台${RESET}"
echo -e "${YELLOW}════════════════════════════════════════════════════════════════════${RESET}"

echo -e "${BOLD}📋 快速开始:${RESET}"
echo -e "${YELLOW}  1. 启动 TyVLLM 服务器:${RESET}"
echo -e "${CYAN}     nohup tyvllm-server --model /workspace/Qwen3-0.6B --port 8000 > tyvllm.log 2>&1 &${RESET}"
echo ""
echo -e "${YELLOW}  2. 查看服务日志:${RESET}"
echo -e "${CYAN}     tail -f tyvllm.log${RESET}"
echo ""
echo -e "${YELLOW}  3. 测试推理接口:${RESET}"
echo -e "${CYAN}     python3 /workspace/ty-vllm-doc/examples/generate_stream.py --query '234 + 567'${RESET}"
echo ""
echo -e "${YELLOW}  4. 查找服务:${RESET}"
echo -e "${CYAN}     pgrep -f tyvllm-server ${RESET}"
echo ""
echo -e "${YELLOW}════════════════════════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}📁 重要目录:${RESET}"
echo -e "   容器内模型: ${CYAN}/workspace/Qwen3-0.6B${RESET}"
echo -e "   容器内文档: ${CYAN}/workspace/ty-vllm-doc${RESET}"
echo -e "   用户数据: ${CYAN}/datadisk${RESET} (挂载目录)"
echo -e "   示例代码: ${CYAN}/workspace/ty-vllm-doc/examples/${RESET}"

echo -e "${YELLOW}════════════════════════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}🔧 环境验证:${RESET}"
echo -e "${YELLOW}  • 检查 PyTorch: ${CYAN}python -c 'import torch; print(torch.__version__)'${RESET}"
echo -e "${YELLOW}  • 检查 TyVLLM: ${CYAN}python -c 'import tyvllm; print(\"TyVLLM Ready\")'${RESET}"
echo -e "${YELLOW}  • 检查 Flash Attention: ${CYAN}python -c 'import flash_attn; print(\"Flash Attention Ready\")'${RESET}"

echo -e "${GREEN}=====================================================${RESET}"