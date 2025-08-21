#!/bin/bash

# 钉钉桌面图标安装脚本
# 作者: 自动生成
# 描述: 安装钉钉桌面图标到系统中

echo "正在安装钉钉桌面图标..."

# 检查是否为root用户
if [ "$EUID" -eq 0 ]; then
    echo "错误: 请不要使用root用户运行此脚本"
    exit 1
fi

# 检查桌面图标目录是否存在
DESKTOP_DIR="$HOME/.local/share/applications"
if [ ! -d "$DESKTOP_DIR" ]; then
    echo "创建桌面图标目录: $DESKTOP_DIR"
    mkdir -p "$DESKTOP_DIR"
fi

# 复制桌面图标文件
if [ -f "dingtalk.desktop" ]; then
    cp dingtalk.desktop "$DESKTOP_DIR/"
    echo "已复制钉钉桌面图标到: $DESKTOP_DIR/dingtalk.desktop"
    
    # 设置执行权限
    chmod +x "$DESKTOP_DIR/dingtalk.desktop"
    echo "已设置执行权限"
    
    # 更新桌面数据库
    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$DESKTOP_DIR"
        echo "已更新桌面数据库"
    fi
    
    # 刷新桌面环境
    echo "正在刷新桌面环境..."
    if command -v xdg-desktop-menu >/dev/null 2>&1; then
        xdg-desktop-menu forceupdate
        echo "桌面菜单已刷新"
    fi
    
    echo ""
    echo "安装完成！"
    echo "钉钉图标应该会出现在您的应用程序菜单中"
    echo "如果没有立即显示，请尝试注销后重新登录"
    echo ""
    echo "图标文件位置: $DESKTOP_DIR/dingtalk.desktop"
    
else
    echo "错误: 找不到 dingtalk.desktop 文件"
    echo "请确保在运行此脚本的目录中存在该文件"
    exit 1
fi
