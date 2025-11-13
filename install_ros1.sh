#!/bin/bash

# ---
# ROS1 (Noetic) 安装脚本
# 适用于 Ubuntu 20.04 (Focal)
# ---

# 遇到错误立即退出
set -e
# 使用未定义的变量时报错
set -u
# 管道中任一命令失败则整个管道失败
set -o pipefail

# --- 检查是否以 root/sudo 权限运行 ---
if [ "$(id -u)" -ne 0 ]; then
  echo "错误：请使用 'sudo bash $0' 来运行此脚本。" >&2
  exit 1
fi

# 获取原始运行脚本的用户名
if [ -z "${SUDO_USER}" ]; then
    echo "错误：无法获取原始用户名，请确保使用 'sudo bash' 而不是 'sudo su' 运行。" >&2
    exit 1
fi
ORIGINAL_USER="${SUDO_USER}"
ORIGINAL_USER_HOME=$(eval echo ~${ORIGINAL_USER})

# 检查 Ubuntu 版本
UBUNTU_VERSION=$(lsb_release -rs)
UBUNTU_CODENAME=$(lsb_release -cs)

echo "检测到 Ubuntu 版本: $UBUNTU_VERSION ($UBUNTU_CODENAME)"
echo "脚本将为用户 '$ORIGINAL_USER' 安装 ROS1 Noetic..."
echo "用户家目录: $ORIGINAL_USER_HOME"
sleep 2

# 验证 Ubuntu 版本是否支持 ROS Noetic
if [ "$UBUNTU_CODENAME" != "focal" ]; then
    echo "警告: ROS Noetic 官方支持 Ubuntu 20.04 (Focal)。"
    echo "当前系统是 $UBUNTU_CODENAME，可能不兼容。"
    read -p "是否继续安装? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# --- 1. 安装必要的工具 ---
echo ">>> [1/6] 正在安装必要的工具..."
apt update
apt install -y \
    curl \
    gnupg2 \
    lsb-release \
    software-properties-common \
    python3-rosdep \
    python3-rosinstall \
    python3-rosinstall-generator \
    python3-wstool \
    build-essential
echo "<<< [1/6] 工具安装完成。"
sleep 1

# --- 2. 添加 ROS 软件源 ---
echo ">>> [2/6] 正在添加 ROS 软件源..."

# 检查是否已添加源
if [ ! -f "/etc/apt/sources.list.d/ros-latest.list" ]; then
    # 添加 ROS 密钥
    echo "添加 ROS 密钥..."
    curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.asc | apt-key add -
    
    # 添加 ROS 源（使用清华镜像）
    echo "添加 ROS 源（使用清华镜像）..."
    echo "deb https://mirrors.tuna.tsinghua.edu.cn/ros/ubuntu/ ${UBUNTU_CODENAME} main" > /etc/apt/sources.list.d/ros-latest.list
    echo "已添加 ROS 源。"
else
    echo "ROS 源已存在，跳过添加。"
fi

echo "<<< [2/6] ROS 软件源配置完成。"
sleep 1

# --- 3. 更新 APT 缓存 ---
echo ">>> [3/6] 正在更新 APT 缓存..."
apt update
echo "<<< [3/6] APT 缓存更新完成。"
sleep 1

# --- 4. 安装 ROS Noetic ---
echo ">>> [4/6] 正在安装 ROS Noetic Desktop Full..."
echo "这将安装完整的 ROS 桌面版本，包括所有常用包和工具。"
echo "如果只需要基础版本，可以稍后运行: sudo apt install ros-noetic-desktop"
sleep 2

apt install -y ros-noetic-desktop-full

echo "<<< [4/6] ROS Noetic 安装完成。"
sleep 1

# --- 5. 初始化 rosdep ---
echo ">>> [5/6] 正在初始化 rosdep..."

# 检查 rosdep 是否已初始化
if [ ! -f "/etc/ros/rosdep/sources.list.d/20-default.list" ]; then
    echo "初始化 rosdep..."
    # 使用清华镜像源配置 rosdep
    mkdir -p /etc/ros/rosdep/sources.list.d
    echo "yaml https://mirrors.tuna.tsinghua.edu.cn/ros/rosdep/sources.list.d/20-default.list" > /etc/ros/rosdep/sources.list.d/20-default.list
    
    # 初始化 rosdep（以用户身份运行）
    sudo -u "$ORIGINAL_USER" rosdep init || echo "注意: rosdep 可能已经初始化过"
    
    # 更新 rosdep
    sudo -u "$ORIGINAL_USER" rosdep update || echo "注意: rosdep 更新可能失败，可以稍后手动运行 'rosdep update'"
else
    echo "rosdep 已初始化，跳过。"
    # 仍然尝试更新
    sudo -u "$ORIGINAL_USER" rosdep update || echo "注意: rosdep 更新可能失败，可以稍后手动运行 'rosdep update'"
fi

echo "<<< [5/6] rosdep 初始化完成。"
sleep 1

# --- 6. 配置环境变量 ---
echo ">>> [6/6] 正在配置 ROS 环境变量..."

BASHRC_FILE="${ORIGINAL_USER_HOME}/.bashrc"
PROFILE_FILE="${ORIGINAL_USER_HOME}/.profile"

# ROS 环境变量配置
ROS_SETUP_LINE="source /opt/ros/noetic/setup.bash"

# 检查是否已存在
if ! sudo -u "$ORIGINAL_USER" grep -qxF "$ROS_SETUP_LINE" "$BASHRC_FILE" 2>/dev/null; then
    echo "添加 ROS 环境变量到 .bashrc..."
    printf '%s\n' "" "# ROS Noetic setup" "$ROS_SETUP_LINE" | sudo -u "$ORIGINAL_USER" tee -a "$BASHRC_FILE" > /dev/null
    echo "已添加到 .bashrc"
else
    echo "ROS 环境变量已存在于 .bashrc 中，跳过添加。"
fi

# 也添加到 .profile（可选）
if ! sudo -u "$ORIGINAL_USER" grep -qxF "$ROS_SETUP_LINE" "$PROFILE_FILE" 2>/dev/null; then
    echo "添加 ROS 环境变量到 .profile..."
    printf '%s\n' "" "# ROS Noetic setup" "$ROS_SETUP_LINE" | sudo -u "$ORIGINAL_USER" tee -a "$PROFILE_FILE" > /dev/null
    echo "已添加到 .profile"
fi

# 添加常用 ROS 工具到 PATH（可选）
CATKIN_WS_SETUP="# 如果存在 catkin 工作空间，取消下面的注释来使用它"
CATKIN_WS_LINE="# source ~/catkin_ws/devel/setup.bash"

if ! sudo -u "$ORIGINAL_USER" grep -qxF "$CATKIN_WS_SETUP" "$BASHRC_FILE" 2>/dev/null; then
    printf '%s\n' "" "$CATKIN_WS_SETUP" "$CATKIN_WS_LINE" | sudo -u "$ORIGINAL_USER" tee -a "$BASHRC_FILE" > /dev/null
fi

echo "<<< [6/6] 环境变量配置完成。"
sleep 1

# --- 结束 ---
echo ""
echo "-------------------------------------------"
echo "ROS1 Noetic 安装完成！"
echo "-------------------------------------------"
echo "重要提示:"
echo "  1. 请 **打开一个新的终端** 或运行 'source ${BASHRC_FILE}' 来加载 ROS 环境"
echo "  2. 验证安装:"
echo "     - 运行: printenv | grep ROS"
echo "     - 运行: roscore (测试 ROS 核心)"
echo "  3. 创建 catkin 工作空间（可选）:"
echo "     mkdir -p ~/catkin_ws/src"
echo "     cd ~/catkin_ws/src"
echo "     catkin_init_workspace"
echo "     cd ~/catkin_ws"
echo "     catkin_make"
echo "     source ~/catkin_ws/devel/setup.bash"
echo "  4. 如果 rosdep 更新失败，可以稍后手动运行:"
echo "     rosdep update"
echo ""
echo "常用 ROS 命令:"
echo "  - roscore: 启动 ROS 核心"
echo "  - rosrun: 运行 ROS 节点"
echo "  - rosnode: 查看和管理节点"
echo "  - rostopic: 查看和管理话题"
echo "  - rosservice: 查看和管理服务"
echo ""

exit 0

