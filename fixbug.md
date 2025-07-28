要卸载现有的 PyTorch 相关包并重新安装，请按以下步骤执行：

## 1. 卸载现有的 PyTorch 相关包

```bash
pip uninstall torch torchvision torchaudio -y
```

## 2. 清理缓存（可选但推荐）

```bash
pip cache purge
```

## 3. 重新安装 PyTorch nightly 版本

```bash
pip install --pre torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cu128
```

## 一行命令完成所有操作

```bash
pip uninstall torch torchvision torchaudio -y && pip cache purge && pip install --pre torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cu128

pip uninstall torch torchvision torchaudio -y && pip cache purge && pip install torch==2.7.1 torchvision==0.22.1 torchaudio==2.7.1 --index-url https://download.pytorch.org/whl/cu128

```

## 验证安装

```bash
python3 -c "import torch; print(f'PyTorch版本: {torch.__version__}'); print(f'CUDA可用: {torch.cuda.is_available()}'); print(f'CUDA版本: {torch.version.cuda}')"
```

使用 `-y` 参数可以自动确认卸载，避免交互式提示。



要卸载现有的 flash-attn 并安装新版本，请按以下步骤执行：

## 1. 卸载现有的 flash-attn

```bash
pip uninstall flash-attn -y
```

## 2. 清理缓存（可选但推荐）

```bash
pip cache purge
```

## 3. 安装新版本的 flash-attn

```bash
pip install flash_attn-2.8.0.post2+cu12torch2.7cxx11abiTRUE-cp310-cp310-linux_x86_64.whl
```

## 一行命令完成所有操作

```bash
wget https://tenyunn-1354648220.cos.ap-guangzhou.myqcloud.com/flash_attn-2.8.0.post2%2Bcu12torch2.7cxx11abiTRUE-cp310-cp310-linux_x86_64.whl && pip uninstall flash-attn -y && pip cache purge && pip install flash_attn-2.8.0.post2+cu12torch2.7cxx11abiTRUE-cp310-cp310-linux_x86_64.whl

wget https://tenyunn-1354648220.cos.ap-guangzhou.myqcloud.com/flash_attn-2.8.0.post2%2Bcu12torch2.7cxx11abiFALSE-cp310-cp310-linux_x86_64.whl && pip uninstall flash-attn -y && pip cache purge && pip install flash_attn-2.8.0.post2+cu12torch2.7cxx11abiFALSE-cp310-cp310-linux_x86_64.whl
```

## 如果你有具体的新版本文件，例如：

```bash
pip uninstall flash-attn -y && pip install /tmp/flash_attn-2.8.0.post2+cu12torch2.5cxx11abiFALSE-cp310-cp310-linux_x86_64.whl
```

## 验证安装

```bash
python3 -c "import flash_attn; print('Flash Attention 安装成功'); print(flash_attn.__version__)"
```

## 查看当前安装的版本

```bash
pip show flash-attn
```

使用 `-y` 参数可以自动确认卸载，避免交互式提示。



📋 快速开始:
  1. 启动 TyVLLM 服务器:
    nohup tyvllm-server --model /workspace/Qwen3-0.6B --port 8000 > tyvllm.log 2>&1 &
    nohup tyvllm-server --model /workspace/Qwen3-0.6B --tensor-parallel-size 2 --port 8000 > tyvllm.log 2>&1 &
  2. 查看服务日志:
     tail -f tyvllm.log

  3. 测试推理接口:
     python3 /workspace/ty-vllm-doc/examples/generate_stream.py --query '234 + 567'

  4. 查找服务:
     pgrep -f tyvllm-server




docker pull swr.cn-north-4.myhuaweicloud.com/ddn-k8s/docker.io/lmsysorg/sglang:blackwell
docker pull docker.m.daocloud.io/lmsysorg/sglang:blackwell




docker run -d --gpus '"device=0,1"' -p 2201:22 -p 8000:8888 -e TENYUNN_JUPYTER_TOKEN=324234141234134 -e TENYUNN_SSH_PWD=1234 --name pytorch_container_blackwell --cpus="8.0" --memory="16g" --memory-swap="32g" default-artifact.tencentcloudcr.com/public/tenyunn/base/pytorch-cuda12.8-ubuntu22.04:blackwell


测试结果：
容器信息:
   用户: root
   时间: 2025-07-26 11:07:31
   主机: 6cb2ee454b36
   系统: Linux 5.15.0-119-generic
   CPU核心: 8.0 cores
   内存: 6.0Gi/16G (0.6%)

磁盘信息:
   系统盘(/): 169G/3.5T (5%)
   数据盘(/datadisk): 169G/3.5T (5%)

GPU信息:
   CUDA版本: 12.8
   GPU数量: 2
   GPU型号: NVIDIA GeForce RTX 5090
PyTorch版本: 2.7.1+cu128
CUDA可用: True
CUDA版本: 12.8exit

docker run -d --gpus '"device=2,3"' -p 2202:22 -p 8001:8888 -e TENYUNN_JUPYTER_TOKEN=324234141234134 -e TENYUNN_SSH_PWD=1234 --name miniconda_container_blackwell --cpus="8.0" --memory="16g" --memory-swap="32g" default-artifact.tencentcloudcr.com/public/tenyunn/base/miniconda-cuda12.8-ubuntu22.04:blackwell


docker run -d --gpus '"device=4,5"' -p 2203:22 -p 8002:8888 -e TENYUNN_JUPYTER_TOKEN=324234141234134 -e TENYUNN_SSH_PWD=1234 --name tyvllm_miniconda_container_blackwell --cpus="8.0" --memory="16g" --memory-swap="32g" default-artifact.tencentcloudcr.com/public/tenyunn/base/tyvllm-miniconda-cuda12.8-ubuntu22.04:blackwell


docker run -d --gpus '"device=6,7"' -p 2204:22 -p 8003:8888 -e TENYUNN_JUPYTER_TOKEN=324234141234134 -e TENYUNN_SSH_PWD=1234 --name tyvllm_miniconda_container_blackwell --cpus="8.0" --memory="16g" --memory-swap="32g" default-artifact.tencentcloudcr.com/public/tenyunn/base/tyvllm-pytorch-cuda12.8-ubuntu22.04:blackwell


docker run -d --gpus all -p 2204:22 -p 8003:8888 -e TENYUNN_JUPYTER_TOKEN=324234141234134 -e TENYUNN_SSH_PWD=1234 --name tyvllm_miniconda_container_blackwell default-artifact.tencentcloudcr.com/public/tenyunn/base/tyvllm-pytorch-cuda12.8-ubuntu22.04:blackwell


python3 -c "import flash_attn; print('Flash Attention 安装成功'); print(flash_attn.__version__)"

python3 -c "import torch; print(f'PyTorch版本: {torch.__version__}'); print(f'CUDA可用: {torch.cuda.is_available()}'); print(f'CUDA版本: {torch.version.cuda}')"


nohup tyvllm-server --model /workspace/Qwen3-0.6B --tensor-parallel-size 2 --port 8000 > tyvllm.log 2>&1 &
nohup tyvllm-server --model /workspace/Qwen3-0.6B --port 8000 > tyvllm.log 2>&1 &

python3 -c "import torch; print(f'可用GPU数量: {torch.cuda.device_count()}'); [print(f'GPU {i}: {torch.cuda.get_device_name(i)}') for i in range(torch.cuda.device_count())]"

DockerHub可用镜像源汇总
http://docker.m.daocloud.io
http://docker.imgdb.de
docker-0.unsee.tech
http://docker.hlmirror.com
http://cjie.eu.org


docker tag default-artifact.tencentcloudcr.com/public/tenyunn/base/pytorch-cuda12.8-ubuntu22.04:blackwell default-artifact.tencentcloudcr.com/public/tenyunn/base/pytorch-cuda12.8-ubuntu22.04:v0.0.4
default-artifact.tencentcloudcr.com/public/tenyunn/base/miniconda-cuda12.8-ubuntu22.04:blackwell
default-artifact.tencentcloudcr.com/public/tenyunn/base/tyvllm-pytorch-cuda12.8-ubuntu22.04:blackwell
default-artifact.tencentcloudcr.com/public/tenyunn/base/tyvllm-pytorch-cuda12.8-ubuntu22.04:blackwell



wget https://gh.llkk.cc/https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh