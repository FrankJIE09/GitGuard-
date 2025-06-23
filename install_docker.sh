#!/bin/bash

# 脚本：自动安装 Docker Engine - 适用于 Debian/Ubuntu
# 版本：已集成代理设置和国内镜像源 (USTC)

# --- 配置开始 ---
# 代理服务器地址和端口
PROXY_URL="http://127.0.0.1:7890"
# Docker CE 国内镜像源 (此处使用 USTC)
# 注意：请确保你的发行版ID (ubuntu/debian) 和版本代号 (lsb_release -cs) 与镜像源支持的相符
DISTRO_ID=$(. /etc/os-release && echo "$ID") # 获取发行版ID (如 ubuntu, debian)
DISTRO_CODENAME=$(lsb_release -cs) # 获取发行版代号 (如 jammy, focal, bullseye)
DOCKER_CE_MIRROR_URL="https://mirrors.ustc.edu.cn/docker-ce/linux/$DISTRO_ID"
DOCKER_CE_MIRROR_GPG_KEY_URL="$DOCKER_CE_MIRROR_URL/gpg"
# --- 配置结束 ---

# 0. 检查是否以 root/sudo 权限运行
if [ "$EUID" -ne 0 ]; then
  echo "请使用 sudo 或以 root 权限运行此脚本。"
  exit 1
fi

echo "开始自动安装 Docker (使用代理和国内镜像源)..."

# 1. 设置代理环境变量 (供 curl 等命令使用)
echo "正在设置代理环境变量: $PROXY_URL"
export http_proxy="$PROXY_URL"
export https_proxy="$PROXY_URL"
export HTTP_PROXY="$PROXY_URL"
export HTTPS_PROXY="$PROXY_URL"
# （可选）对于本地地址和一些特定域名，你可能不希望它们通过代理
# export no_proxy="localhost,127.0.0.1,.local"
# export NO_PROXY="localhost,127.0.0.1,.local"

# 2. 为 apt 配置代理
echo "正在为 apt 配置代理..."
# 创建或覆盖 apt 代理配置文件
cat <<EOF | sudo tee /etc/apt/apt.conf.d/99proxy.conf > /dev/null
Acquire::http::Proxy "$PROXY_URL";
Acquire::https::Proxy "$PROXY_URL";
Acquire::ftp::Proxy "$PROXY_URL";
Acquire::socks::Proxy "$PROXY_URL";
EOF
if [ $? -ne 0 ]; then
    echo "错误：为 apt 配置代理失败。"
    exit 1
fi
echo "apt 代理配置完成。"

# 3. 更新软件包列表并安装必要的依赖 (将通过代理进行)
echo "正在更新软件包列表并安装依赖 (通过代理)..."
apt-get update -y
if [ $? -ne 0 ]; then
    echo "错误：更新软件包列表失败。请检查代理和网络连接。"
    exit 1
fi

apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common
if [ $? -ne 0 ]; then
    echo "错误：安装依赖失败。"
    exit 1
fi

# 4. 添加 Docker 的 GPG 密钥 (从国内镜像源获取，通过代理)
echo "正在添加 Docker 的 GPG 密钥 (从 $DOCKER_CE_MIRROR_GPG_KEY_URL)..."
# 创建用于存储 GPG 密钥的目录
sudo install -m 0755 -d /etc/apt/keyrings
# 下载 Docker GPG 密钥
# 注意：USTC 镜像建议直接导入，而不是保存为 .asc 再转换
curl -fsSL "$DOCKER_CE_MIRROR_GPG_KEY_URL" | sudo gpg --dearmor -o /etc/apt/keyrings/docker-ce-mirror.gpg
if [ $? -ne 0 ]; then
    echo "错误：下载或处理 Docker GPG 密钥失败。"
    # 尝试删除可能不完整的密钥文件
    sudo rm -f /etc/apt/keyrings/docker-ce-mirror.gpg
    exit 1
fi
# 确保密钥文件权限正确
sudo chmod a+r /etc/apt/keyrings/docker-ce-mirror.gpg

# 5. 设置 Docker 稳定版仓库 (使用国内镜像源)
echo "正在设置 Docker 仓库 (使用 $DOCKER_CE_MIRROR_URL)..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker-ce-mirror.gpg] $DOCKER_CE_MIRROR_URL \
  $DISTRO_CODENAME stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
if [ $? -ne 0 ]; then
    echo "错误：设置 Docker 仓库失败。"
    exit 1
fi

# 6. 再次更新软件包列表 (因为添加了新的仓库，通过代理)
echo "正在再次更新软件包列表..."
apt-get update -y
if [ $? -ne 0 ]; then
    echo "错误：从新的 Docker 镜像源更新软件包列表失败。"
    exit 1
fi

# 7. 安装 Docker Engine, CLI, Containerd 和 Docker Compose (从国内镜像源，通过代理)
echo "正在安装 Docker Engine, CLI, Containerd 和 Docker Compose..."
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
if [ $? -ne 0 ]; then
    echo "错误：安装 Docker 组件失败。"
    exit 1
fi

# 8. (可选) 将当前用户添加到 docker 组
CURRENT_USER=$(logname 2>/dev/null || echo "$SUDO_USER")
if [ -n "$CURRENT_USER" ] && ! id -nG "$CURRENT_USER" | grep -qw "docker"; then
    echo "正在尝试将用户 $CURRENT_USER 添加到 docker 组..."
    usermod -aG docker "$CURRENT_USER"
    echo "用户 $CURRENT_USER 已添加到 docker 组。你需要注销并重新登录才能使更改生效，或者运行 'newgrp docker' 应用新的组。"
elif [ -n "$CURRENT_USER" ]; then
     echo "用户 $CURRENT_USER 已经是 docker 组成员。"
else
    echo "警告：无法确定当前用户以添加到 docker 组。请手动执行 'sudo usermod -aG \$USER docker' 并重新登录。"
fi

# 9. 启动 Docker 服务并设置为开机自启 (对于 systemd 系统)
echo "正在启动并启用 Docker 服务..."
if command -v systemctl &> /dev/null; then
    systemctl start docker
    systemctl enable docker.service # 确保启用的是 .service
    systemctl enable containerd.service # containerd 也建议启用
    echo "Docker 服务已启动并设置为开机自启。"
else
    echo "警告：未找到 systemctl。可能需要手动启动 Docker 服务。"
fi

# 10. 验证 Docker 是否安装成功
echo "正在验证 Docker 安装..."
if command -v docker &> /dev/null; then
    docker --version
    echo "Docker 看起来已成功安装！"
    echo "重要提示：此脚本已配置 Docker Engine 的安装源为国内镜像。"
    echo "         为了加速 'docker pull' 拉取镜像，你可能还需要配置 Docker守护进程的 registry-mirrors。"
    echo "         请参考如何修改 '/etc/docker/daemon.json' 文件并添加国内镜像加速器地址。"
    echo "尝试运行 hello-world 镜像进行测试 (可能需要 sudo，或重新登录后运行): docker run hello-world"
else
    echo "错误：Docker 命令未找到。安装可能失败了。"
    exit 1
fi

echo "Docker 安装脚本执行完毕。"
# 清理 apt 代理配置（可选，如果只想在脚本执行期间使用代理）
# echo "正在清理 apt 代理配置..."
# sudo rm -f /etc/apt/apt.conf.d/99proxy.conf
# echo "apt 代理配置已清理。"

exit 0
