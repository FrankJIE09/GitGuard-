#!/bin/bash

# ---
# Ubuntu 初始化配置脚本 (包含 清华源, 中文输入法, 免密sudo, MAX_JOBS, 常用组件, Pip/Conda源, Miniconda安装)
# ---

# 遇到错误立即退出
set -e
# 使用未定义的变量时报错
set -u
# 管道中任一命令失败则整个管道失败
set -o pipefail

# --- 配置 ---
# 你可以根据需要修改要安装的软件包列表
# Added wget for downloading miniconda
COMMON_PACKAGES="git cmake build-essential curl wget vim htop python3-pip python3-dev ninja-build net-tools software-properties-common"
CHINESE_INPUT_METHOD_PACKAGES="fcitx5 fcitx5-chinese-addons"
# Miniconda settings
MINICONDA_SCRIPT_URL="https://mirrors.tuna.tsinghua.edu.cn/anaconda/miniconda/Miniconda3-latest-Linux-x86_64.sh"
MINICONDA_SCRIPT_PATH="/tmp/miniconda_installer.sh" # Temporary download path


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
MINICONDA_INSTALL_PATH="${ORIGINAL_USER_HOME}/miniconda3" # Default Miniconda install path

echo "脚本将为用户 '$ORIGINAL_USER' 配置环境..."
echo "用户家目录: $ORIGINAL_USER_HOME"
echo "Miniconda 将安装在: $MINICONDA_INSTALL_PATH"
sleep 3

# --- 1. 更换 APT 源为清华大学镜像 ---
echo ">>> [1/7] 正在更换 APT 源为清华大学镜像..."
UBUNTU_CODENAME=$(lsb_release -cs)
SOURCES_LIST="/etc/apt/sources.list"
SOURCES_BACKUP="${SOURCES_LIST}.backup_$(date +%Y%m%d%H%M%S)"

echo "当前 Ubuntu 版本代号: $UBUNTU_CODENAME"
echo "备份原始源文件到: $SOURCES_BACKUP"
cp "$SOURCES_LIST" "$SOURCES_BACKUP"

echo "正在写入新的清华源配置..."
# Using printf for better control over file creation as root
printf '%s\n' \
    "# 默认注释了源码镜像以提高 apt update 速度，如有需要可自行取消注释" \
    "deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_CODENAME} main restricted universe multiverse" \
    "# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_CODENAME} main restricted universe multiverse" \
    "deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_CODENAME}-updates main restricted universe multiverse" \
    "# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_CODENAME}-updates main restricted universe multiverse" \
    "deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_CODENAME}-backports main restricted universe multiverse" \
    "# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_CODENAME}-backports main restricted universe multiverse" \
    "deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_CODENAME}-security main restricted universe multiverse" \
    "# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_CODENAME}-security main restricted universe multiverse" \
    > "$SOURCES_LIST"

echo "更新 APT 缓存..."
apt update
echo "<<< [1/7] APT 源更换完成。"
sleep 1

# --- 2. 安装常用组件 ---
echo ">>> [2/7] 正在安装常用组件 (包含 wget, python3-pip)..."
# 加上 -y 表示自动确认安装
apt install -y $COMMON_PACKAGES
echo "<<< [2/7] 常用组件安装完成。"
sleep 1

# --- 3. 配置 pip 使用清华源 (用户级别) ---
echo ">>> [3/7] 正在为用户 '$ORIGINAL_USER' 配置 pip 使用清华源..."
PIP_CONFIG_DIR="${ORIGINAL_USER_HOME}/.config/pip"
PIP_CONFIG_FILE="${PIP_CONFIG_DIR}/pip.conf"

# 以原始用户身份创建目录
sudo -u "$ORIGINAL_USER" mkdir -p "$PIP_CONFIG_DIR"
# 以原始用户身份创建或覆盖配置文件
sudo -u "$ORIGINAL_USER" bash -c "printf '%s\n' '[global]' 'index-url = https://pypi.tuna.tsinghua.edu.cn/simple' > '$PIP_CONFIG_FILE'"

echo "<<< [3/7] pip 源配置完成 (用户: $ORIGINAL_USER)。"
sleep 1

# --- 4. 下载并安装 Miniconda ---
echo ">>> [4/7] 正在下载并安装 Miniconda..."
if [ -d "$MINICONDA_INSTALL_PATH" ]; then
    echo "检测到 Miniconda 安装目录已存在: $MINICONDA_INSTALL_PATH，跳过下载和安装。"
    echo "如果需要重新安装，请先手动删除该目录。"
else
    echo "从清华源下载 Miniconda 安装脚本..."
    wget --no-verbose -O "$MINICONDA_SCRIPT_PATH" "$MINICONDA_SCRIPT_URL"
    chmod +x "$MINICONDA_SCRIPT_PATH"

    echo "为用户 '$ORIGINAL_USER' 安装 Miniconda 到 '$MINICONDA_INSTALL_PATH'..."
    # 使用 sudo -u 以原始用户身份运行安装脚本，-b 批处理模式，-p 指定路径
    sudo -u "$ORIGINAL_USER" "$MINICONDA_SCRIPT_PATH" -b -p "$MINICONDA_INSTALL_PATH"

    echo "清理 Miniconda 安装脚本..."
    rm -f "$MINICONDA_SCRIPT_PATH"

    # 初始化 Conda (修改用户的 .bashrc)
    CONDA_BIN_PATH="${MINICONDA_INSTALL_PATH}/bin/conda"
    if [ -f "$CONDA_BIN_PATH" ]; then
        echo "初始化 Conda for Bash..."
        # 以原始用户身份执行 conda init
        sudo -u "$ORIGINAL_USER" "$CONDA_BIN_PATH" init bash
        echo "Conda 初始化完成，需要打开新终端或 'source ${ORIGINAL_USER_HOME}/.bashrc' 来激活。"
    else
        echo "警告: 安装后未找到 Conda 可执行文件 '$CONDA_BIN_PATH'。初始化失败。" >&2
    fi
fi
echo "<<< [4/7] Miniconda 安装和初始化步骤完成。"
sleep 1


# --- 5. 配置 Conda 使用清华源 (用户级别) ---
echo ">>> [5/7] 正在为用户 '$ORIGINAL_USER' 配置 Conda 使用清华源..."
CONDARC_FILE="${ORIGINAL_USER_HOME}/.condarc"
CONDA_BIN_PATH="${MINICONDA_INSTALL_PATH}/bin/conda"

if [ -f "$CONDA_BIN_PATH" ]; then
     echo "设置 Conda channels..."
     # 以原始用户身份执行 conda config 命令
     # 先移除默认的 defaults channel (可选，但推荐)，避免速度慢或冲突
     sudo -u "$ORIGINAL_USER" "$CONDA_BIN_PATH" config --remove channels defaults || true # 忽略移除失败的错误
     # 添加清华源 channels
     sudo -u "$ORIGINAL_USER" "$CONDA_BIN_PATH" config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/main
     sudo -u "$ORIGINAL_USER" "$CONDA_BIN_PATH" config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/r
     sudo -u "$ORIGINAL_USER" "$CONDA_BIN_PATH" config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/msys2
     sudo -u "$ORIGINAL_USER" "$CONDA_BIN_PATH" config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud/conda-forge/ # 添加 conda-forge
     sudo -u "$ORIGINAL_USER" "$CONDA_BIN_PATH" config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud/pytorch/   # 添加 pytorch (可选)
     # 设置显示 channel URL
     sudo -u "$ORIGINAL_USER" "$CONDA_BIN_PATH" config --set show_channel_urls yes

     echo "Conda 源配置完成。当前 .condarc 内容:"
     # 以原始用户身份查看 .condarc
     sudo -u "$ORIGINAL_USER" cat "$CONDARC_FILE" || echo "(无法读取 .condarc)"

else
     echo "警告: Conda 可执行文件未找到 '$CONDA_BIN_PATH'。无法配置 Conda 源。" >&2
fi
echo "<<< [5/7] Conda 源配置完成。"
sleep 1


# --- 6. 安装中文输入法 (Fcitx5) ---
echo ">>> [6/7] 正在安装 Fcitx5 中文输入法..."
apt install -y $CHINESE_INPUT_METHOD_PACKAGES

echo "配置输入法环境变量 (写入 /etc/environment, 需要重新登录生效)..."
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

echo "<<< [6/7] 中文输入法安装完成。请 **重新登录** 系统后，在系统设置中配置 Fcitx5 添加中文输入引擎（如 Pinyin）。"
sleep 1


# --- 7. 设置当前用户 sudo 免密码 和 添加 MAX_JOBS 到 .bashrc ---
# 注意：conda init 可能已经修改了 .bashrc，我们在此之后添加 MAX_JOBS

echo ">>> [7/7] 配置 sudo 免密 和 添加 MAX_JOBS 到 .bashrc..."

# --- 设置 sudo 免密 ---
echo "为用户 '$ORIGINAL_USER' 设置 sudo 免密码..."
SUDOERS_FILE="/etc/sudoers.d/90-nopasswd-${ORIGINAL_USER}"
# 使用 printf 和 tee 写入文件
printf '%s\n' "${ORIGINAL_USER} ALL=(ALL) NOPASSWD: ALL" > "$SUDOERS_FILE"
chmod 440 "$SUDOERS_FILE"
echo "Sudo 免密码设置完成。"

# --- 添加 MAX_JOBS 到用户的 .bashrc ---
echo "将 'export MAX_JOBS=\$(nproc)' 添加到 '$ORIGINAL_USER' 的 ~/.bashrc 文件中..."
BASHRC_FILE="${ORIGINAL_USER_HOME}/.bashrc"
MAX_JOBS_LINE="export MAX_JOBS=\$(nproc)"

# 检查该行是否已存在于 .bashrc 文件中 (以用户身份执行)
# 这里使用 grep -q || echo ... | tee -a 的逻辑更安全，避免直接用 tee -a 重复添加
if ! sudo -u "$ORIGINAL_USER" grep -qxF "$MAX_JOBS_LINE" "$BASHRC_FILE"; then
    echo "添加 '$MAX_JOBS_LINE' 到 $BASHRC_FILE 末尾..."
    # 以原始用户身份追加内容
    printf '%s\n' "$MAX_JOBS_LINE" | sudo -u "$ORIGINAL_USER" tee -a "$BASHRC_FILE" > /dev/null
    echo "添加完成。"
else
    echo "'$MAX_JOBS_LINE' 已存在于 $BASHRC_FILE 中，跳过添加。"
fi
echo "<<< [7/7] Sudo 免密 和 MAX_JOBS 设置完成。"
sleep 1

# --- 结束 ---
echo ""
echo "-------------------------------------------"
echo "Ubuntu 初始化脚本执行完毕！"
echo "-------------------------------------------"
echo "重要提示:"
echo "  - Conda 环境已安装并初始化。你需要 **打开一个新的终端** 或运行 'source ${ORIGINAL_USER_HOME}/.bashrc' 来使用 'conda' 命令。"
echo "  - Pip 和 Conda 已配置使用清华镜像源。"
echo "  - 中文输入法需要您 **重新登录** 系统，然后在系统设置或 Fcitx5 配置工具中添加具体的中文输入引擎（如 Pinyin）。"
echo "  - Sudo 免密码设置已生效。"
echo "  - MAX_JOBS 环境变量将在您下次打开 **新的终端** 时生效。"
echo "建议运行 'sudo apt upgrade -y' 来升级所有已安装的软件包。"
echo "强烈建议现在 **重新启动** 系统以确保所有更改（特别是环境变量和输入法）完全生效: sudo reboot"
echo ""

exit 0
