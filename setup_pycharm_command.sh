#!/bin/bash

# ==============================================================================
# 脚本名称: install_pycharm_launcher.sh (一站式安装脚本)
# 描述    : - 创建一个智能的 PyCharm 启动器脚本 (~/launch_pycharm.sh)。
#           - 将该启动器链接到 /usr/local/bin/pycharm，从而创建全局命令。
# 运行方式: sudo ./install_pycharm_launcher.sh
# ==============================================================================

# --- 配置 ---
# 要创建的启动器脚本的名称和路径
LAUNCHER_SCRIPT_NAME="launch_pycharm.sh"
# 使用 'eval' 来正确处理 ~（即使用运行此脚本的用户的$HOME，而非root的）
# 即使在使用 sudo 时，也能确保脚本被创建在正确的用户主目录下
SUDO_USER_HOME=$(eval echo ~"$SUDO_USER")
LAUNCHER_SCRIPT_PATH="${SUDO_USER_HOME}/${LAUNCHER_SCRIPT_NAME}"

# 希望创建的全局命令的名称
TARGET_COMMAND_NAME="pycharm"
# 全局命令的安装目录
TARGET_DIR="/usr/local/bin"
# 全局命令的完整路径
TARGET_COMMAND_PATH="${TARGET_DIR}/${TARGET_COMMAND_NAME}"

# --- 启动器脚本的完整内容 ---
# 使用 cat <<'EOF' 的方式可以原封不动地将内容写入变量，
# 其中$HOME, $@等变量不会在此时被解析，而是在最终的启动器脚本运行时被解析。
LAUNCHER_CONTENT=$(cat <<'EOF'
#!/bin/bash

# ==============================================================================
# 脚本名称: launch_pycharm.sh (智能版)
# 描述    : 自动启动 PyCharm。
#           - 优先尝试从系统 PATH 直接运行 'pycharm' 命令 (推荐方式)。
#           - 如果失败，则回退到在指定目录中搜索 'pycharm.sh' (兼容旧版/手动安装)。
#           - 会将所有接收到的参数传递给 PyCharm (例如打开特定项目)。
# ==============================================================================

# --- 配置 (仅用于回退模式) ---
FALLBACK_SEARCH_DIR="$HOME/Frank"
FALLBACK_EXECUTABLE_NAME="pycharm.sh"
# 保存 PyCharm 路径的配置文件
PYCHARM_CONFIG_FILE="$HOME/.pycharm_path"

# --- 启动函数 ---
run_in_background() {
    local executable_path="$1"
    shift
    nohup "${executable_path}" "$@" >/dev/null 2>&1 &
}

# --- 主要逻辑 ---

# 优先：尝试直接使用 'pycharm' 命令 (通过JetBrains Toolbox安装的)
if command -v pycharm &> /dev/null; then
    PYCHARM_CMD=$(command -v pycharm)
    # 避免无限循环：检查找到的命令是否就是我们即将创建的这个链接本身
    if [ "$(readlink -f "$PYCHARM_CMD")" != "$(readlink -f "$0")" ]; then
        echo "模式 1: 在系统 PATH 中找到官方 'pycharm' 命令，正在启动..."
        echo "  -> ${PYCHARM_CMD}"
        run_in_background "${PYCHARM_CMD}" "$@"
        exit 0
    fi
fi

# 回退：如果 'pycharm' 命令不存在或是我们自己的链接，则搜索 pycharm.sh
echo "模式 2: 未找到官方 'pycharm' 命令，正在检查已保存的 PyCharm 路径..."

# 首先检查是否有保存的路径
if [[ -f "${PYCHARM_CONFIG_FILE}" ]]; then
    SAVED_PATH=$(cat "${PYCHARM_CONFIG_FILE}")
    if [[ -f "${SAVED_PATH}" && -x "${SAVED_PATH}" ]]; then
        LAUNCHER_TO_RUN="${SAVED_PATH}"
        echo "使用已保存的 PyCharm 路径:"
        echo "  -> ${LAUNCHER_TO_RUN}"
    else
        echo "已保存的路径无效，正在重新搜索..."
        rm -f "${PYCHARM_CONFIG_FILE}"
    fi
fi

# 如果没有保存的路径或路径无效，则搜索
if [[ -z "${LAUNCHER_TO_RUN}" ]]; then
    echo "正在递归搜索 '${FALLBACK_SEARCH_DIR}' 目录及其所有子目录..."
    
    # 使用 -L 参数让 find 跟随符号链接，-type f 查找文件，-executable 查找可执行文件
    mapfile -t PCHARM_PATHS < <(find -L "${FALLBACK_SEARCH_DIR}" -name "${FALLBACK_EXECUTABLE_NAME}" -type f -executable 2>/dev/null)
    NUM_FOUND=${#PCHARM_PATHS[@]}
    
    if [ ${NUM_FOUND} -eq 0 ]; then
        echo "错误: 回退失败。在 '${FALLBACK_SEARCH_DIR}' 目录下也未找到任何名为 '${FALLBACK_EXECUTABLE_NAME}' 的可执行文件。"
        exit 1
    elif [ ${NUM_FOUND} -eq 1 ]; then
        LAUNCHER_TO_RUN="${PCHARM_PATHS[0]}"
        echo "找到 1 个 PyCharm 启动器，将直接启动:"
        echo "  -> ${LAUNCHER_TO_RUN}"
        # 保存路径到配置文件
        echo "${LAUNCHER_TO_RUN}" > "${PYCHARM_CONFIG_FILE}"
        echo "已保存 PyCharm 路径到配置文件，下次启动将直接使用此路径。"
    else
        echo "找到 ${NUM_FOUND} 个 PyCharm 启动器，请选择一个来启动:"
        PS3="请输入数字选择 (按 Ctrl+C 退出): "
        select OPTION in "${PCHARM_PATHS[@]}"; do
            if [[ -n "${OPTION}" ]]; then
                LAUNCHER_TO_RUN="${OPTION}"
                echo "你选择了: ${LAUNCHER_TO_RUN}"
                # 保存路径到配置文件
                echo "${LAUNCHER_TO_RUN}" > "${PYCHARM_CONFIG_FILE}"
                echo "已保存 PyCharm 路径到配置文件，下次启动将直接使用此路径。"
                break
            else
                echo "无效的选择，请重新输入。"
            fi
        done
    fi
fi

if [[ -n "${LAUNCHER_TO_RUN}" ]]; then
    echo "正在启动 PyCharm..."
    run_in_background "${LAUNCHER_TO_RUN}" "$@"
    echo "PyCharm 已在后台启动！"
else
    echo "操作已取消，未启动任何程序。"
fi

exit 0
EOF
)


# --- 安装脚本的主逻辑 ---

# 1. 检查是否以 root/sudo 权限运行
if [ "$EUID" -ne 0 ]; then
  echo "错误: 此脚本需要管理员权限 (sudo) 来在 '${TARGET_DIR}' 中创建链接。"
  echo "请使用 'sudo ./install_pycharm_launcher.sh' 来运行。"
  exit 1
fi
echo "管理员权限检查通过。"

# 2. 创建启动器脚本文件
echo "--------------------------------------------------"
echo "步骤 1: 正在您的主目录中创建启动器脚本文件..."
echo "  -> ${LAUNCHER_SCRIPT_PATH}"
# 将LAUNCHER_CONTENT变量的内容写入到目标文件中
echo "${LAUNCHER_CONTENT}" > "${LAUNCHER_SCRIPT_PATH}"
if [ $? -ne 0 ]; then
    echo "错误: 创建启动器脚本失败！"
    exit 1
fi

# 设置所有者为运行 sudo 的用户，并赋予执行权限
chown "$SUDO_USER":"$SUDO_USER" "${LAUNCHER_SCRIPT_PATH}"
chmod +x "${LAUNCHER_SCRIPT_PATH}"
echo "启动器脚本创建成功并已设置为可执行。"

# 3. 创建或更新符号链接
echo "--------------------------------------------------"
echo "步骤 2: 正在设置 '${TARGET_COMMAND_NAME}' 全局命令..."
# 如果目标命令已存在，先移除旧的，避免 ln 报错
if [ -e "${TARGET_COMMAND_PATH}" ]; then
    echo "命令 '${TARGET_COMMAND_NAME}' 已存在，正在更新..."
    rm -f "${TARGET_COMMAND_PATH}"
fi

# 创建新的符号链接
ln -s "${LAUNCHER_SCRIPT_PATH}" "${TARGET_COMMAND_PATH}"

# 4. 验证是否成功
if [ -L "${TARGET_COMMAND_PATH}" ] && [ "$(readlink "${TARGET_COMMAND_PATH}")" = "${LAUNCHER_SCRIPT_PATH}" ]; then
    echo -e "\n\033[0;32m🎉 设置全部完成！\033[0m"
    echo "现在你可以关闭当前终端，打开一个新的终端，然后直接输入以下命令来启动程序:"
    echo "  - 启动 PyCharm: pycharm"
    echo "  - 打开当前目录为项目: pycharm ."
else
    echo -e "\n\033[0;31m错误: 创建符号链接失败。请检查 '${TARGET_DIR}' 目录的写入权限。${NC}"
    exit 1
fi

exit 0