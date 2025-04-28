#!/bin/bash

# --- 配置 ---
CREDENTIAL_HELPER="libsecret"
HELPER_COMMAND="$CREDENTIAL_HELPER"

# --- 脚本逻辑 ---

echo "正在配置 Git 全局凭证助手为: $HELPER_COMMAND"

# 检查 Git 是否安装并可执行 (修改后的检查)
if ! git --version &> /dev/null; then
    echo "错误: 无法执行 'git --version' 命令。"
    if [[ -x "/usr/bin/git" ]]; then
        echo "Git 存在于 /usr/bin/git，但似乎无法在当前环境直接调用 'git'。"
        echo "请检查你的 PATH 环境变量是否包含 /usr/bin (运行: echo \$PATH)"
    else
        echo "请确保 Git 已正确安装。"
    fi
    exit 1
fi

# 根据选择的助手进行配置 (保持不变)
# ... (省略之前的 cache/store 配置逻辑，假设只用 libsecret) ...
git config --global credential.helper "$HELPER_COMMAND"
echo "已配置 '$HELPER_COMMAND' 助手。"

# 检查配置结果
echo ""
echo "检查当前 Git 全局凭证助手配置:"
CURRENT_CONFIG=$(git config --global --get credential.helper)
echo "credential.helper = $CURRENT_CONFIG"

echo ""
echo "配置完成。"
echo "重要提示:"
echo "1. 此脚本已设置 Git 如何存储凭证。"
echo "2. 你仍然需要在【第一次】通过 HTTPS 执行 git push/pull 等操作时，"
echo "   输入你的 GitHub 用户名和【Personal Access Token (PAT)】。"
echo "3. 之后 '$HELPER_COMMAND' 助手应该会自动处理认证。"
if [[ "$CREDENTIAL_HELPER" == "libsecret" ]]; then
    echo "4. 请确保 'libsecret' 相关包已安装 (例如，在 Ubuntu 上执行: sudo apt update && sudo apt install libsecret-1-0 git)"
fi

exit 0
