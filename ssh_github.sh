#!/bin/bash

# === 配置 ===
# 使用推荐的 ed25519 算法
KEY_NAME="id_ed25519"
SSH_DIR="$HOME/.ssh"
KEY_PATH="$SSH_DIR/$KEY_NAME"
PUB_KEY_PATH="$KEY_PATH.pub"

echo "--- GitHub SSH 密钥设置脚本 ---"
echo "本脚本将帮助你生成 SSH 密钥，并将其添加到 ssh-agent。"
echo "你需要手动将生成的【公钥】复制并添加到你的 GitHub 账户中。"
echo "-----------------------------------------------------"

# --- 步骤 1: 确保 .ssh 目录存在且权限正确 ---
if [ ! -d "$SSH_DIR" ]; then
    echo "创建 SSH 目录: $SSH_DIR"
    mkdir -p "$SSH_DIR"
    if [ $? -ne 0 ]; then
        echo "错误: 创建 SSH 目录失败。请检查权限。"
        exit 1
    fi
    chmod 700 "$SSH_DIR"
    echo "设置 $SSH_DIR 权限为 700。"
else
    # 确保权限是正确的 (仅所有者可读写执行)
    chmod 700 "$SSH_DIR"
fi

# --- 步骤 2: 检查或生成 SSH 密钥 ---
generate_new_key=false
if [ -f "$KEY_PATH" ]; then
    echo "发现已存在的 SSH 密钥: $KEY_PATH"
    # 询问用户是否使用现有密钥
    read -p "是否使用此现有密钥？(Y/n): " use_existing_key
    # 如果用户输入 'n' 或 'N'
    if [[ "$use_existing_key" =~ ^[Nn]$ ]]; then
        echo "操作取消。请手动管理你的 SSH 密钥，或备份/移除现有密钥后重新运行脚本。"
        exit 0
    # 否则 (输入 Y, y 或直接回车)，默认使用现有密钥
    else
        echo "将使用现有密钥: $KEY_PATH"
        # 确保现有密钥文件可读
        if [ ! -r "$KEY_PATH" ]; then
            echo "错误: 无法读取现有密钥文件 $KEY_PATH。请检查文件权限。"
            exit 1
        fi
    fi
else
    # 文件不存在，需要生成
    generate_new_key=true
fi

# 如果需要生成新密钥
if [ "$generate_new_key" = true ]; then
    echo "未找到 SSH 密钥 $KEY_PATH，将生成新的密钥..."
    # 获取 GitHub 邮箱地址
    read -p "请输入你的 GitHub 邮箱地址: " github_email
    # 检查邮箱是否为空
    if [ -z "$github_email" ]; then
        echo "错误: 邮箱地址不能为空。"
        exit 1
    fi

    echo "正在生成 $KEY_NAME 类型的 SSH 密钥..."
    # ssh-keygen 会提示输入保存路径(直接回车使用默认)和密码(建议输入)
    ssh-keygen -t ed25519 -C "$github_email" -f "$KEY_PATH"

    # 检查 ssh-keygen 是否成功执行
    if [ $? -ne 0 ]; then
        echo "错误: SSH 密钥生成失败。"
        exit 1
    fi
    echo "SSH 密钥已成功生成: $KEY_PATH 和 $PUB_KEY_PATH"
fi

# --- 步骤 3: 启动 ssh-agent ---
echo "检查并启动 ssh-agent..."
# 尝试列出现有 agent 中的 key，如果失败则认为 agent 未运行或无 key
ssh-add -l &>/dev/null
if [ $? -ne 0 ]; then
    echo "未检测到正在运行的 ssh-agent 或 agent 中无密钥，尝试启动新的 agent..."
    # 启动 agent 并将环境变量导出到当前 shell
    eval "$(ssh-agent -s)"
    if [ $? -ne 0 ]; then
        echo "错误: 启动 ssh-agent 失败。"
        # 即使 agent 启动失败，用户仍可手动复制密钥，所以不一定退出
        # exit 1
    fi
else
    echo "ssh-agent 已在运行中。"
fi

# --- 步骤 4: 将 SSH 私钥添加到 ssh-agent ---
echo "尝试将私钥添加到 ssh-agent: $KEY_PATH"
# 添加私钥，如果密钥有密码，这里会提示输入密码
ssh-add "$KEY_PATH"
if [ $? -ne 0 ]; then
    echo "警告: 添加私钥到 ssh-agent 失败。"
    echo "      如果你为密钥设置了密码，可能是密码输入错误。"
    echo "      你可以稍后手动尝试添加: ssh-add $KEY_PATH"
    # 不退出，因为公钥仍然可以被复制和使用
fi

# --- 步骤 5: 显示公钥并提供指示 ---
echo ""
echo "======================= 重要步骤 ======================="
echo "请复制下面的【公钥】内容 (以 'ssh-ed25519' 开头):"
echo "-----------------------------------------------------"
# 确保公钥文件存在且可读
if [ -r "$PUB_KEY_PATH" ]; then
    cat "$PUB_KEY_PATH"
else
    echo "错误: 无法读取公钥文件 $PUB_KEY_PATH。无法显示公钥。"
    exit 1
fi
echo "-----------------------------------------------------"
echo "复制完成后，请手动执行以下操作："
echo "1. 登录你的 GitHub 账户。"
echo "2. 进入设置 (Settings)。"
echo "3. 在左侧菜单找到 'SSH and GPG keys' (或访问 https://github.com/settings/keys)。"
echo "4. 点击 'New SSH key' 或 'Add SSH key' 按钮。"
echo "5. 在 'Title' 字段输入一个描述性标题 (例如 '我的 Ubuntu 电脑 - $(date +"%Y-%m-%d")')。"
echo "6. 将刚才复制的【完整公钥】粘贴到 'Key' 字段中。"
echo "7. 点击 'Add SSH key' 按钮保存。"
echo "======================================================"
echo ""

# --- 步骤 6: 测试连接 ---
echo "将密钥添加到 GitHub 后，你可以在终端运行以下命令测试连接："
echo "  ssh -T git@github.com"
echo "如果看到类似 'Hi <你的用户名>! You've successfully authenticated...' 的消息，则表示设置成功。"
echo "(首次连接可能会询问是否信任 GitHub 的主机密钥，输入 'yes' 即可)"
echo ""

# --- 步骤 7: 使用 SSH URL ---
echo "最后，请确保你的本地 Git 仓库使用 SSH URL (git@github.com:...) 而不是 HTTPS URL。"
echo "克隆新仓库示例: git clone git@github.com:用户名/仓库名.git"
echo "修改现有仓库 URL 示例: git remote set-url origin git@github.com:用户名/仓库名.git"
echo ""
echo "脚本执行完毕。"

exit 0
