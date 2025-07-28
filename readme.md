
# pytorch 2.5.1
# CUDA 11.8
pip install torch==2.5.1 torchvision==0.20.1 torchaudio==2.5.1 --index-url https://download.pytorch.org/whl/cu118
# CUDA 12.1
pip install torch==2.5.1 torchvision==0.20.1 torchaudio==2.5.1 --index-url https://download.pytorch.org/whl/cu121
# CUDA 12.4
pip install torch==2.5.1 torchvision==0.20.1 torchaudio==2.5.1 --index-url https://download.pytorch.org/whl/cu124



# pytorch 2.6.0
# CUDA 11.8
pip install torch==2.6.0 torchvision==0.21.0 torchaudio==2.6.0 --index-url https://download.pytorch.org/whl/cu118
# CUDA 12.4
pip install torch==2.6.0 torchvision==0.21.0 torchaudio==2.6.0 --index-url https://download.pytorch.org/whl/cu124
# CUDA 12.6
pip install torch==2.6.0 torchvision==0.21.0 torchaudio==2.6.0 --index-url https://download.pytorch.org/whl/cu126


# pytorch 2.7.1
pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128
pip3 install torch torchvision torchaudio
pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118


# nvida/cuda images
nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04 
nvidia/cuda:12.4.1-cudnn-devel-ubuntu22.04
nvidia/cuda:11.8.0-cudnn8-devel-ubuntu22.04

nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04 


rsync -avz -e "ssh -p 2234" /Users/soovv/ty/tycloud/deploy/base ubuntu@112.90.156.84:/home/soovv/base


sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json <<-'EOF'
{
  "registry-mirrors": [
    "https://24pc9xnf.mirror.aliyuncs.com",
    "https://hub-mirror.c.163.com",
    "https://registry.docker-cn.com"
  ]
}
EOF

sudo systemctl daemon-reload
sudo systemctl restart docker