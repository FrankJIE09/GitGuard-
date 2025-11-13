#!/bin/bash

# ---
# NVIDIA 驱动安装脚本
# 适用于 Ubuntu 20.04+ (Focal 及更高版本)
# 支持自动检测并安装 NVIDIA Open Kernel Modules (open 版本)
# 适用于较新内核版本 (6.2+) 或出现驱动版本不匹配的情况
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

echo "脚本将为用户 '$ORIGINAL_USER' 安装 NVIDIA 驱动..."
echo "用户家目录: $ORIGINAL_USER_HOME"
sleep 2

# --- 1. 检测 NVIDIA 显卡 ---
echo ">>> [1/6] 正在检测 NVIDIA 显卡..."
if ! lspci | grep -i nvidia > /dev/null; then
    echo "警告: 未检测到 NVIDIA 显卡。"
    if [ -t 0 ]; then
        read -p "是否继续安装? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        echo "非交互式模式，继续安装..."
    fi
else
    echo "检测到 NVIDIA 显卡:"
    lspci | grep -i nvidia
fi
echo "<<< [1/6] 显卡检测完成。"
sleep 1

# --- 2. 更新 APT 缓存 ---
echo ">>> [2/6] 正在更新 APT 缓存..."
apt update
echo "<<< [2/6] APT 缓存更新完成。"
sleep 1

# --- 3. 安装必要的工具 ---
echo ">>> [3/6] 正在安装必要的工具..."
apt install -y \
    ubuntu-drivers-common \
    software-properties-common \
    build-essential \
    dkms
echo "<<< [3/6] 工具安装完成。"
sleep 1

# --- 4. 检测推荐的驱动 ---
echo ">>> [4/6] 正在检测推荐的 NVIDIA 驱动..."

# 检查是否需要 open 版本（通过检查内核版本，6.2+ 通常需要 open 版本）
KERNEL_MAJOR=$(uname -r | cut -d. -f1)
KERNEL_MINOR=$(uname -r | cut -d. -f2)
NEED_OPEN_VERSION=false

# 检查内核版本是否 >= 6.2（通常需要 open 版本）
if [ "$KERNEL_MAJOR" -gt 6 ] || ([ "$KERNEL_MAJOR" -eq 6 ] && [ "$KERNEL_MINOR" -ge 2 ]); then
    echo "检测到较新的内核版本 ($(uname -r))，可能需要使用 NVIDIA Open Kernel Modules"
    NEED_OPEN_VERSION=true
fi

# 获取推荐的驱动
RECOMMENDED_DRIVER=$(ubuntu-drivers devices 2>/dev/null | grep -i "recommended" | awk '{print $3}' | head -1)

if [ -z "$RECOMMENDED_DRIVER" ]; then
    echo "未找到推荐的驱动，将安装最新的稳定版本..."
    RECOMMENDED_DRIVER="nvidia-driver-535"
fi

# 检查是否有对应的 open 版本可用
DRIVER_VERSION=$(echo "$RECOMMENDED_DRIVER" | sed 's/nvidia-driver-//' | sed 's/-open$//')
OPEN_DRIVER="nvidia-driver-${DRIVER_VERSION}-open"

# 检查 open 版本是否可用
if apt-cache show "$OPEN_DRIVER" &>/dev/null; then
    echo "检测到可用的 Open Kernel Modules 版本: $OPEN_DRIVER"
    if [ "$NEED_OPEN_VERSION" = true ]; then
        echo "系统需要 Open Kernel Modules，将使用: $OPEN_DRIVER"
        RECOMMENDED_DRIVER="$OPEN_DRIVER"
    else
        # 检查是否已安装普通版本驱动但出现版本不匹配
        if dpkg -l | grep -q "^ii.*nvidia-driver-[0-9]" && ! dpkg -l | grep -q "nvidia-driver.*-open"; then
            echo "检测到已安装普通版本驱动，但可能需要 Open 版本以避免版本不匹配错误"
            echo "提示: 如果遇到 'Driver/library version mismatch' 错误，请使用 Open 版本"
        fi
    fi
else
    echo "未找到对应的 Open 版本 ($OPEN_DRIVER)，尝试查找其他可用的 Open 版本..."
    # 尝试查找其他可用的 open 版本
    AVAILABLE_OPEN=$(apt-cache search nvidia-driver 2>/dev/null | grep -E "nvidia-driver-[0-9]+-open" | awk '{print $1}' | sort -V | tail -1)
    if [ -n "$AVAILABLE_OPEN" ]; then
        echo "找到可用的 Open 版本: $AVAILABLE_OPEN"
        if [ "$NEED_OPEN_VERSION" = true ]; then
            RECOMMENDED_DRIVER="$AVAILABLE_OPEN"
        fi
    fi
fi

echo "推荐的驱动: $RECOMMENDED_DRIVER"
echo "可用的驱动:"
ubuntu-drivers devices 2>/dev/null | grep "driver" | grep -v "nouveau" || echo "无法列出可用驱动"

# 列出可用的 open 版本
echo ""
echo "可用的 Open Kernel Modules 版本:"
apt-cache search nvidia-driver 2>/dev/null | grep -E "nvidia-driver-[0-9]+-open" | awk '{print $1}' | sort -V | tail -5 || echo "未找到 Open 版本"

# 检查是否在交互式终端中
if [ -t 0 ]; then
    # 交互式模式：询问用户是否使用推荐驱动
    echo ""
    read -p "是否安装推荐的驱动 $RECOMMENDED_DRIVER? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        echo "请输入要安装的驱动名称（例如: nvidia-driver-535-open）:"
        read -r RECOMMENDED_DRIVER
    fi
else
    # 非交互式模式：自动使用推荐驱动
    echo "非交互式模式，将自动安装推荐的驱动: $RECOMMENDED_DRIVER"
fi

echo "<<< [4/6] 驱动选择完成。"
sleep 1

# --- 5. 安装 NVIDIA 驱动 ---
echo ">>> [5/6] 正在安装 NVIDIA 驱动: $RECOMMENDED_DRIVER..."
echo "这将安装驱动和所有依赖项，可能需要一些时间..."

# 如果安装的是 open 版本，先检查并卸载普通版本
if echo "$RECOMMENDED_DRIVER" | grep -q "-open$"; then
    echo "检测到将安装 Open Kernel Modules 版本"
    # 查找已安装的普通版本驱动
    INSTALLED_REGULAR=$(dpkg -l | grep "^ii.*nvidia-driver-[0-9]" | grep -v "-open" | awk '{print $2}' | head -1)
    if [ -n "$INSTALLED_REGULAR" ]; then
        echo "检测到已安装普通版本驱动: $INSTALLED_REGULAR"
        echo "需要先卸载普通版本，然后安装 Open 版本..."
        apt remove --purge -y "$INSTALLED_REGULAR" 2>/dev/null || true
        apt autoremove -y 2>/dev/null || true
        echo "普通版本驱动已卸载"
    fi
fi

# 自动安装推荐的驱动
if echo "$RECOMMENDED_DRIVER" | grep -q "-open$"; then
    # 对于 open 版本，直接使用 apt install
    apt install -y "$RECOMMENDED_DRIVER"
else
    # 对于普通版本，可以使用 ubuntu-drivers autoinstall
    ubuntu-drivers autoinstall || apt install -y "$RECOMMENDED_DRIVER"
fi

echo "<<< [5/6] 驱动安装完成。"
sleep 1

# --- 6. 验证安装 ---
echo ">>> [6/6] 正在验证安装..."
if command -v nvidia-smi &> /dev/null; then
    echo "nvidia-smi 命令已安装"
    echo "注意: 需要重启系统后 nvidia-smi 才能正常工作"
else
    echo "警告: nvidia-smi 命令未找到，可能需要重启后才会出现"
fi

# 检查驱动模块
if lsmod | grep -q nvidia; then
    echo "NVIDIA 驱动模块已加载"
else
    echo "NVIDIA 驱动模块未加载（需要重启系统）"
fi

echo "<<< [6/6] 验证完成。"
sleep 1

# --- 结束 ---
echo ""
echo "-------------------------------------------"
echo "NVIDIA 驱动安装完成！"
echo "-------------------------------------------"
echo "重要提示:"
echo "  1. **必须重启系统** 以使驱动生效:"
echo "     sudo reboot"
echo ""
echo "  2. 重启后验证安装:"
echo "     nvidia-smi"
echo ""
echo "  3. 如果遇到 'Driver/library version mismatch' 错误:"
echo "     - 可能需要使用 Open Kernel Modules 版本"
echo "     - 运行脚本并选择带 '-open' 后缀的驱动版本"
echo "     - 例如: nvidia-driver-535-open"
echo ""
echo "  4. 如果遇到其他问题，可以尝试:"
echo "     - 检查驱动状态: dkms status"
echo "     - 查看日志: dmesg | grep -i nvidia"
echo "     - 重新安装: sudo apt install --reinstall $RECOMMENDED_DRIVER"
echo ""
echo "  5. 如果需要卸载驱动:"
echo "     sudo apt autoremove --purge $RECOMMENDED_DRIVER"
echo ""

exit 0

