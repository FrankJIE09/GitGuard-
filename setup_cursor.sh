#!/bin/bash

# ==============================================================================
# Cursor 启动命令设置脚本 (setup_cursor.sh)
# 版本: v2.2 - 静默启动优化版
# 功能: 自动查找并为 Cursor AppImage 创建一个全局启动命令，启动时完全静默。
# 要求: 此脚本必须通过 sudo 运行。
# ==============================================================================

# --- 样式 ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# ------------------------------------------------------------------------------
# 1. 权限检查：必须以 root/sudo 身份运行
# ------------------------------------------------------------------------------
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}错误：权限不足。${NC}"
  echo "此脚本必须以管理员权限 (root) 运行。"
  echo -e "请使用以下命令运行: ${GREEN}sudo ./setup_cursor.sh${NC}"
  exit 1
fi

echo -e "${GREEN}✓ 管理员权限检查通过。${NC}"

# ------------------------------------------------------------------------------
# 2. 查找 AppImage 文件
# ------------------------------------------------------------------------------
APPIMAGE_PATTERN="Cursor-*.AppImage"
FOUND_APPIMAGE=""

# 智能获取发起 sudo 命令的用户的 Home 目录
if [ -n "$SUDO_USER" ]; then
    USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else
    USER_HOME=$HOME
fi

SEARCH_DIRS=("./" "$USER_HOME/Frank/")

echo "正在搜索 AppImage 文件 ($APPIMAGE_PATTERN)..."
for dir in "${SEARCH_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo "  -> 正在搜索目录: $dir"
        CANDIDATE=$(find "$dir" -maxdepth 1 -iname "$APPIMAGE_PATTERN" 2>/dev/null | sort -V | tail -n 1)
        if [ -n "$CANDIDATE" ]; then
            FOUND_APPIMAGE="$CANDIDATE"
            echo -e "${GREEN}  ✓ 找到 AppImage: $FOUND_APPIMAGE${NC}"
            break
        fi
    fi
done

if [ -z "$FOUND_APPIMAGE" ]; then
    echo -e "\n${RED}错误：在以下目录中均未找到匹配 '$APPIMAGE_PATTERN' 的文件:${NC}"
    echo "  - 当前目录 (./)"
    echo "  - $USER_HOME/Frank/"
    exit 1
fi

# ------------------------------------------------------------------------------
# 3. 创建并安装启动器
# ------------------------------------------------------------------------------
LAUNCHER_PATH="/usr/local/bin/cursor"
APPIMAGE_ABSOLUTE_PATH=$(readlink -f "$FOUND_APPIMAGE")

echo "AppImage 绝对路径为: $APPIMAGE_ABSOLUTE_PATH"

# 【优化版】完全静默启动，确保终端没有任何输出信息
SCRIPT_CONTENT=$(cat <<EOF
#!/bin/bash
# 该文件由 setup_cursor.sh 脚本自动生成于 $(date)
# 优化版：完全静默启动

# Cursor AppImage 的绝对路径
APPIMAGE_PATH="${APPIMAGE_ABSOLUTE_PATH}"

# 完全静默启动：关闭所有输出，立即返回控制权给终端
exec setsid "\$APPIMAGE_PATH" "\$@" </dev/null >/dev/null 2>&1 &
disown

# 确保脚本立即退出，不等待任何进程
exit 0
EOF
)

echo "正在创建启动命令: $LAUNCHER_PATH ..."
echo -e "$SCRIPT_CONTENT" > "$LAUNCHER_PATH"

echo "正在为命令设置执行权限..."
chmod +x "$LAUNCHER_PATH"

echo "正在为 Cursor AppImage 设置 777 权限..."
chmod 777 "$APPIMAGE_ABSOLUTE_PATH"

# ------------------------------------------------------------------------------
# 4. 完成
# ------------------------------------------------------------------------------
echo -e "\n${GREEN}🎉 设置成功！'cursor' 命令已更新并优化为完全静默启动。${NC}"
echo "--------------------------------------------------"
echo "现在你可以使用:"
echo "1. 打开一个【新的终端窗口】。"
echo "2. 输入 ${YELLOW}cursor .${NC} 来在当前目录打开 Cursor。"
echo "3. Cursor 会静默启动，终端不会显示任何运行信息。"
echo "--------------------------------------------------"
