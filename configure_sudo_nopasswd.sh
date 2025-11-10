#!/bin/bash
# 配置sudo免密码脚本
# 使用方法: sudo bash configure_sudo_nopasswd.sh

set -e

echo "=========================================="
echo "配置sudo免密码"
echo "=========================================="

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then 
    echo "请使用sudo运行此脚本: sudo bash $0"
    exit 1
fi

# 获取当前用户名（如果从sudo运行，获取SUDO_USER）
CURRENT_USER=${SUDO_USER:-$USER}
if [ "$CURRENT_USER" = "root" ]; then
    echo "错误: 无法确定要配置的用户名"
    echo "请直接运行: sudo bash $0"
    exit 1
fi

echo "当前用户: $CURRENT_USER"
echo ""

# 备份sudoers文件
echo "备份sudoers文件..."
cp /etc/sudoers /etc/sudoers.backup.$(date +%Y%m%d_%H%M%S)

# 检查用户是否已经在sudoers中
if grep -q "^${CURRENT_USER}.*ALL.*ALL" /etc/sudoers; then
    echo "用户 $CURRENT_USER 已在sudoers中，更新为NOPASSWD..."
    # 移除旧的行
    sed -i "/^${CURRENT_USER}.*ALL.*ALL/d" /etc/sudoers
fi

# 检查sudo组是否配置了NOPASSWD
if grep -q "^%sudo.*ALL.*ALL" /etc/sudoers && ! grep -q "^%sudo.*NOPASSWD" /etc/sudoers; then
    echo "sudo组已配置但需要密码，更新为NOPASSWD..."
    sed -i 's/^%sudo.*ALL=(ALL:ALL) ALL/%sudo ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers
    sed -i 's/^%sudo.*ALL=(ALL) ALL/%sudo ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers
fi

# 检查admin组是否配置了NOPASSWD
if grep -q "^%admin.*ALL.*ALL" /etc/sudoers && ! grep -q "^%admin.*NOPASSWD" /etc/sudoers; then
    echo "admin组已配置但需要密码，更新为NOPASSWD..."
    sed -i 's/^%admin.*ALL=(ALL:ALL) ALL/%admin ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers
    sed -i 's/^%admin.*ALL=(ALL) ALL/%admin ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers
fi

# 添加用户到sudoers（如果不存在）
if ! grep -q "^${CURRENT_USER}.*NOPASSWD" /etc/sudoers; then
    echo "添加用户 $CURRENT_USER 到sudoers（NOPASSWD）..."
    echo "${CURRENT_USER} ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
fi

# 验证sudoers文件语法
echo ""
echo "验证sudoers文件语法..."
if visudo -c; then
    echo "✓ sudoers文件语法正确"
else
    echo "✗ sudoers文件语法错误，恢复备份..."
    cp /etc/sudoers.backup.* /etc/sudoers
    exit 1
fi

echo ""
echo "=========================================="
echo "配置完成！"
echo "=========================================="
echo ""
echo "用户 $CURRENT_USER 现在可以免密码使用sudo"
echo ""
echo "测试: sudo -n true && echo '配置成功' || echo '配置失败'"
echo ""

