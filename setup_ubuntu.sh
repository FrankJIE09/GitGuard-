#!/bin/bash

# ---
# Ubuntu 初始化配置脚本
# ---

# 遇到错误立即退出
set -e
# 使用未定义的变量时报错
set -u
# 管道中任一命令失败则整个管道失败
set -o pipefail

# --- 配置 ---
# 你可以根据需要修改要安装的软件包列表
COMMON_PACKAGES="git cmake build-essential curl wget vim htop python3-pip python3-dev ninja-build net-tools software-properties-common"
CHINESE_INPUT_METHOD_PACKAGES="fcitx5 fcitx5-chinese-addons"

# --- 检查是否以 root/sudo 权限运行 ---
if [ "$(id -u)" -ne 0 ]; then
  echo "错误：请使用 'sudo bash $0' 来运行此脚本。" >&2
  exit 1
fi

# 获取原始运行脚本的用户名 (非常重要，用于配置用户相关项)
if [ -z "${SUDO_USER}" ]; then
    echo "错误：无法获取原始用户名，请确保使用 'sudo bash' 而不是 'sudo su' 运行。" >&2
    exit 1
fi
ORIGINAL_USER="${SUDO_USER}"
ORIGINAL_USER_HOME=$(eval echo ~${ORIGINAL_USER})

echo "脚本将为用户 '$ORIGINAL_USER' 配置环境..."
sleep 2

# --- 1. 更换 APT 源为清华大学镜像 ---
echo ">>> [1/5] 正在更换 APT 源为清华大学镜像..."
UBUNTU_CODENAME=$(lsb_release -cs)
SOURCES_LIST="/etc/apt/sources.list"
SOURCES_BACKUP="${SOURCES_LIST}.backup_$(date +%Y%m%d%H%M%S)"

echo "当前 Ubuntu 版本代号: $UBUNTU_CODENAME"
echo "备份原始源文件到: $SOURCES_BACKUP"
cp "$SOURCES_LIST" "$SOURCES_BACKUP"

echo "正在写入新的清华源配置..."
cat << EOF > "$SOURCES_LIST"
# 默认注释了源码镜像以提高 apt update 速度，如有需要可自行取消注释
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_CODENAME} main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_CODENAME} main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_CODENAME}-updates main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_CODENAME}-updates main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_CODENAME}-backports main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_CODENAME}-backports main restricted universe multiverse

deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_CODENAME}-security main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_CODENAME}-security main restricted universe multiverse

# 预发布软件源，若不需要可注释掉
# deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_CODENAME}-proposed main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_CODENAME}-proposed main restricted universe multiverse
EOF

echo "更新 APT 缓存..."
apt update
echo "<<< [1/5] APT 源更换完成。"
sleep 1

# --- 2. 安装常用组件 ---
echo ">>> [2/5] 正在安装常用组件 (可能需要一些时间)..."
# 加上 -y 表示自动确认安装
apt install -y $COMMON_PACKAGES
echo "<<< [2/5] 常用组件安装完成。"
sleep 1

# --- 3. 安装中文输入法 (Fcitx5) ---
echo ">>> [3/5] 正在安装 Fcitx5 中文输入法..."
apt install -y $CHINESE_INPUT_METHOD_PACKAGES

echo "配置输入法环境变量 (需要重新登录生效)..."
# 将 Fcitx5 设置为默认输入法框架的环境变量写入 /etc/environment
# 检查是否已存在，避免重复添加
if ! grep -qxF 'GTK_IM_MODULE=fcitx' /etc/environment; then
    echo 'GTK_IM_MODULE=fcitx' >> /etc/environment
fi
if ! grep -qxF 'QT_IM_MODULE=fcitx' /etc/environment; then
    echo 'QT_IM_MODULE=fcitx' >> /etc/environment
fi
if ! grep -qxF 'XMODIFIERS=@im=fcitx' /etc/environment; then
    echo 'XMODIFIERS=@im=fcitx' >> /etc/environment
fi
# IM_CONFIG_DEFAULT_MODE=fcitx # 另一种可能需要的方式，取决于桌面环境

echo "<<< [3/5] 中文输入法安装完成。请重新登录系统后，在系统设置中配置 Fcitx5 添加中文输入引擎（如 Pinyin）。"
sleep 1

# --- 4. 设置当前用户 sudo 免密码 ---
echo ">>> [4/5] 正在为用户 '$ORIGINAL_USER' 设置 sudo 免密码..."
SUDOERS_FILE="/etc/sudoers.d/90-nopasswd-${ORIGINAL_USER}"
echo "创建 sudoers 配置文件: $SUDOERS_FILE"
# 使用 tee 来写入需要 root 权限的文件
echo "${ORIGINAL_USER} ALL=(ALL) NOPASSWD: ALL" > "$SUDOERS_FILE"
# 设置正确的文件权限
chmod 440 "$SUDOERS_FILE"
echo "<<< [4/5] sudo 免密码设置完成。下次 '$ORIGINAL_USER' 使用 sudo 时将不再需要密码。"
sleep 1

# --- 5. 将 MAX_JOBS 添加到用户的 .bashrc ---
echo ">>> [5/5] 正在将 'export MAX_JOBS=\$(nproc)' 添加到 '$ORIGINAL_USER' 的 ~/.bashrc 文件中..."
BASHRC_FILE="${ORIGINAL_USER_HOME}/.bashrc"
MAX_JOBS_LINE="export MAX_JOBS=\$(nproc)"

# 检查该行是否已存在于 .bashrc 文件中
# 使用 sudo -u $ORIGINAL_USER 来以该用户身份执行 grep 命令
if sudo -u "$ORIGINAL_USER" grep -qxF "$MAX_JOBS_LINE" "$BASHRC_FILE"; then
    echo "'$MAX_JOBS_LINE' 已存在于 $BASHRC_FILE 中，跳过添加。"
else
    echo "添加 '$MAX_JOBS_LINE' 到 $BASHRC_FILE 末尾..."
    # 使用 sudo -u $ORIGINAL_USER tee -a 来以该用户身份追加内容
    echo "$MAX_JOBS_LINE" | sudo -u "$ORIGINAL_USER" tee -a "$BASHRC_FILE" > /dev/null
    echo "添加完成。"
fi
echo "<<< [5/5] MAX_JOBS 设置完成。将在下次打开新的终端时生效。"
sleep 1

# --- 结束 ---
echo ""
echo "-------------------------------------------"
echo "Ubuntu 初始化脚本执行完毕！"
echo "-------------------------------------------"
echo "重要提示:"
echo "  - 中文输入法需要您 **重新登录** 系统，然后在系统设置或 Fcitx5 配置工具中添加具体的中文输入引擎（如 Pinyin）。"
echo "  - Sudo 免密码设置已生效。"
echo "  - MAX_JOBS 环境变量将在您下次打开 **新的终端** 时生效。"
echo "建议运行 'sudo apt upgrade -y' 来升级所有已安装的软件包。"
echo "建议现在重新启动系统以确保所有更改完全生效: sudo reboot"
echo ""

exit 0
