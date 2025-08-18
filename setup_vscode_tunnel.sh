#!/bin/bash

echo "=== VS Code Tunnel 管理脚本 ==="
echo "此脚本提供多种方式来管理 VS Code Tunnel"

# === 创建系统服务文件的函数 ===
create_service_file() {
    local SERVICE_FILE="/etc/systemd/system/vscode-tunnel.service"
    local USER_NAME=$(whoami)
    local USER_HOME=$(echo $HOME)
    
    echo "正在创建服务文件: $SERVICE_FILE"
    
    sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=VS Code Tunnel Service
After=network.target
Wants=network.target

[Service]
Type=simple
User=$USER_NAME
WorkingDirectory=$USER_HOME
ExecStart=/usr/bin/code tunnel --accept-server-license-terms --disable-telemetry
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    if [ $? -eq 0 ]; then
        echo "✓ 服务文件创建成功"
        sudo systemctl daemon-reload
        echo "✓ 系统服务配置已重新加载"
        return 0
    else
        echo "✗ 服务文件创建失败"
        return 1
    fi
}

# === 检查 code 命令是否可用 ===
if ! command -v code &> /dev/null; then
    echo "错误：未找到 code 命令"
    echo "请先安装 VS Code CLI："
    echo "sudo snap install code --classic"
    exit 1
fi

echo "✓ 找到 code 命令: $(which code)"

# === 显示当前状态 ===
echo ""
echo "=== 当前 Tunnel 状态 ==="
code tunnel status

echo ""
echo "=== 可用的管理选项 ==="
echo "1. 启动 tunnel 服务（后台运行）"
echo "2. 停止 tunnel 服务"
echo "3. 重启 tunnel 服务"
echo "4. 查看 tunnel 状态"
echo "5. 重命名机器"
echo "6. 清理未运行的服务器"
echo "7. 端口转发"
echo "8. 设置开机自启动"
echo "9. 管理系统服务"
echo "10. 查看内网穿透网址"
echo "11. VS Code 连接指南"
echo "12. 退出"

read -p "请选择操作 (1-12): " choice

case $choice in
    1)
        echo "正在启动 tunnel 服务..."
        code tunnel --accept-server-license-terms --disable-telemetry &
        echo "Tunnel 服务已在后台启动"
        echo "使用 'code tunnel status' 查看状态"
        ;;
    2)
        echo "正在停止 tunnel 服务..."
        code tunnel kill
        echo "Tunnel 服务已停止"
        ;;
    3)
        echo "正在重启 tunnel 服务..."
        code tunnel restart
        echo "Tunnel 服务已重启"
        ;;
    4)
        echo "当前 tunnel 状态："
        code tunnel status
        ;;
    5)
        read -p "请输入新的机器名称: " new_name
        code tunnel rename "$new_name"
        echo "机器名称已更改为: $new_name"
        ;;
    6)
        echo "正在清理未运行的服务器..."
        code tunnel prune
        echo "清理完成"
        ;;
    7)
        echo "=== 端口转发设置 ==="
        read -p "请输入要转发的端口号: " port
        if [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]; then
            echo "正在设置端口 $port 的转发..."
            echo "注意：VS Code Tunnel 的端口转发功能使用不同的语法"
            echo "将使用以下命令进行端口转发："
            echo "code tunnel --accept-server-license-terms --disable-telemetry"
            echo "然后在 VS Code 中使用 'Ports' 面板添加端口 $port"
            echo ""
            read -p "是否要启动 tunnel 服务？(y/n): " confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                echo "正在启动 tunnel 服务..."
                code tunnel --accept-server-license-terms --disable-telemetry &
                echo "Tunnel 服务已在后台启动"
                echo ""
                echo "=== 端口转发说明 ==="
                echo "1. 在 VS Code 中打开 'Ports' 面板 (Ctrl+Shift+P -> 'Ports: Focus on Ports View')"
                echo "2. 点击 '+' 按钮添加新端口"
                echo "3. 输入端口号: $port"
                echo "4. 选择 'Local' 或 'Remote' 转发类型"
                echo "5. 端口转发将自动建立"
                echo ""
                echo "使用 'code tunnel status' 查看 tunnel 状态"
            else
                echo "Tunnel 服务启动已取消"
            fi
        else
            echo "错误：请输入有效的端口号 (1-65535)"
        fi
        ;;
    8)
        echo "=== 设置开机自启动 ==="
        echo "此选项将创建一个系统服务文件，并启用服务"
        echo "请确保你有 sudo 权限"
        echo ""
        
        # 检查是否已经存在服务
        if systemctl list-unit-files | grep -q "vscode-tunnel.service"; then
            echo "检测到 vscode-tunnel 服务已存在"
            echo "当前服务状态："
            systemctl status vscode-tunnel.service --no-pager
            echo ""
            read -p "是否要重新配置服务？(y/n): " reconfirm
            if [[ "$reconfirm" =~ ^[Yy]$ ]]; then
                echo "正在重新配置服务..."
            else
                echo "跳过服务配置"
                break
            fi
        fi
        
        read -p "是否继续设置开机自启动？(y/n): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            echo "正在创建服务文件..."
            if create_service_file; then
                echo "正在启用服务..."
                sudo systemctl enable vscode-tunnel.service
                if [ $? -eq 0 ]; then
                    echo "✓ 服务已启用开机自启动"
                else
                    echo "✗ 服务启用失败"
                    break
                fi
                
                echo "正在启动服务..."
                sudo systemctl start vscode-tunnel.service
                if [ $? -eq 0 ]; then
                    echo "✓ 服务已启动"
                else
                    echo "✗ 服务启动失败"
                    break
                fi
                
                echo ""
                echo "=== 服务状态 ==="
                sudo systemctl status vscode-tunnel.service --no-pager
                echo ""
                echo "✓ 开机自启动设置完成！"
                echo "服务将在下次系统启动时自动运行"
                echo ""
                echo "常用命令："
                echo "• 查看状态: sudo systemctl status vscode-tunnel.service"
                echo "• 停止服务: sudo systemctl stop vscode-tunnel.service"
                echo "• 重启服务: sudo systemctl restart vscode-tunnel.service"
                echo "• 禁用自启: sudo systemctl disable vscode-tunnel.service"
            else
                echo "✗ 服务文件创建失败，请检查权限"
            fi
        else
            echo "取消设置开机自启动"
        fi
        ;;
    9)
        echo "=== 管理系统服务 ==="
        echo "1. 查看所有服务"
        echo "2. 查看特定服务状态"
        echo "3. 启用服务"
        echo "4. 禁用服务"
        echo "5. 重启服务"
        echo "6. 停止服务"
        echo "7. 删除服务"
        echo "8. 返回"

        read -p "请选择 (1-8): " service_choice

        case $service_choice in
            1)
                echo "所有服务："
                systemctl list-units --type=service --all
                ;;
            2)
                read -p "请输入服务名称 (例如 vscode-tunnel): " service_name
                if systemctl status "$service_name" &> /dev/null; then
                    systemctl status "$service_name" --no-pager
                else
                    echo "服务 '$service_name' 不存在"
                fi
                ;;
            3)
                read -p "请输入服务名称 (例如 vscode-tunnel): " service_name
                if systemctl status "$service_name" &> /dev/null; then
                    echo "正在启用服务 '$service_name'..."
                    sudo systemctl enable "$service_name"
                    if [ $? -eq 0 ]; then
                        echo "✓ 服务 '$service_name' 已启用"
                    else
                        echo "✗ 服务 '$service_name' 启用失败"
                    fi
                else
                    echo "服务 '$service_name' 不存在"
                fi
                ;;
            4)
                read -p "请输入服务名称 (例如 vscode-tunnel): " service_name
                if systemctl status "$service_name" &> /dev/null; then
                    echo "正在禁用服务 '$service_name'..."
                    sudo systemctl disable "$service_name"
                    if [ $? -eq 0 ]; then
                        echo "✓ 服务 '$service_name' 已禁用"
                    else
                        echo "✗ 服务 '$service_name' 禁用失败"
                    fi
                else
                    echo "服务 '$service_name' 不存在"
                fi
                ;;
            5)
                read -p "请输入服务名称 (例如 vscode-tunnel): " service_name
                if systemctl status "$service_name" &> /dev/null; then
                    echo "正在重启服务 '$service_name'..."
                    sudo systemctl restart "$service_name"
                    if [ $? -eq 0 ]; then
                        echo "✓ 服务 '$service_name' 已重启"
                    else
                        echo "✗ 服务 '$service_name' 重启失败"
                    fi
                else
                    echo "服务 '$service_name' 不存在"
                fi
                ;;
            6)
                read -p "请输入服务名称 (例如 vscode-tunnel): " service_name
                if systemctl status "$service_name" &> /dev/null; then
                    echo "正在停止服务 '$service_name'..."
                    sudo systemctl stop "$service_name"
                    if [ $? -eq 0 ]; then
                        echo "✓ 服务 '$service_name' 已停止"
                    else
                        echo "✗ 服务 '$service_name' 停止失败"
                    fi
                else
                    echo "服务 '$service_name' 不存在"
                fi
                ;;
            7)
                read -p "请输入服务名称 (例如 vscode-tunnel): " service_name
                if systemctl status "$service_name" &> /dev/null; then
                    echo "正在删除服务 '$service_name'..."
                    sudo systemctl stop "$service_name"
                    sudo systemctl disable "$service_name"
                    sudo rm -f "/etc/systemd/system/$service_name.service"
                    sudo systemctl daemon-reload
                    echo "✓ 服务 '$service_name' 已删除"
                else
                    echo "服务 '$service_name' 不存在"
                fi
                ;;
            8)
                echo "返回上级菜单"
                ;;
            *)
                echo "无效选择，请重新运行脚本"
                ;;
        esac
        ;;
    10)
        echo "=== 查看内网穿透网址 ==="
        echo "正在获取隧道信息..."
        echo ""
        
        # 检查 tunnel 服务是否运行
        if pgrep -f "code tunnel" > /dev/null; then
            echo "✓ VS Code Tunnel 服务正在运行"
            echo ""
            echo "=== 当前隧道信息 ==="
            code tunnel list
            
            echo ""
            echo "=== 隧道访问地址 ==="
            echo "• 在浏览器中直接访问："
            echo "  https://vscode.dev/tunnel/$(hostname)"
            echo ""
            echo "• 或者使用完整地址："
            code tunnel list | grep -o 'https://[^[:space:]]*vscode\.dev[^[:space:]]*' | head -1
            echo ""
            echo "=== 使用说明 ==="
            echo "• 直接在浏览器中打开上述地址即可使用"
            echo "• 无需 SSH 连接，完全通过 Web 界面访问"
            echo "• 支持完整的 VS Code 功能"
        else
            echo "✗ VS Code Tunnel 服务未运行"
            echo ""
            echo "请先启动 tunnel 服务："
            echo "1. 选择选项1启动服务"
            echo "2. 或者手动运行: code tunnel --accept-server-license-terms --disable-telemetry"
            echo ""
            echo "启动服务后，隧道地址将自动生成"
        fi
        ;;
    11)
        echo "=== VS Code 连接指南 ==="
        echo ""
        
        # 获取本机信息
        local_ip=$(hostname -I | awk '{print $1}')
        hostname_val=$(hostname)
        username=$(whoami)
        
        echo "=== 连接方式说明 ==="
        echo "⚠️  重要：VS Code Tunnel 和 SSH 是两种不同的连接方式！"
        echo ""
        echo "=== 方式1：VS Code Tunnel（推荐） ==="
        echo "• 直接使用隧道地址访问："
        echo "  https://vscode.dev/tunnel/$hostname_val"
        echo "• 无需 SSH，直接在浏览器中使用"
        echo "• 使用选项10查看具体的隧道地址"
        echo ""
        echo "=== 方式2：VS Code 中连接隧道 ==="
        echo "1. 通过命令面板连接："
        echo "   • 按 Ctrl+Shift+P 打开命令面板"
        echo "   • 输入 'Tunnels: Connect to Tunnel'"
        echo "   • 选择您的隧道: $hostname_val"
        echo ""
        echo "2. 通过侧边栏连接："
        echo "   • 点击左侧 'Remote Explorer' 图标"
        echo "   • 在 'Tunnels' 部分找到您的隧道"
        echo "   • 点击连接按钮"
        echo ""
        echo "3. 通过 URL 直接打开："
        echo "   • 复制隧道地址到剪贴板"
        echo "   • 在 VS Code 中按 Ctrl+Shift+P"
        echo "   • 输入 'File: Open Remote'"
        echo "   • 粘贴隧道地址"
        echo ""
        echo "=== 方式3：SSH 连接（用于管理） ==="
        echo "• 命令行连接：ssh $username@$local_ip"
        echo "• VS Code SSH 扩展：安装 'Remote - SSH' 扩展"
        echo ""
        echo "=== 快速开始 ==="
        echo "1. 确保 tunnel 服务运行（选项1）"
        echo "2. 获取隧道地址（选项10）"
        echo "3. 在浏览器中打开地址或通过 VS Code 连接"
        echo ""
        echo "=== 注意事项 ==="
        echo "• 隧道地址格式：https://vscode.dev/tunnel/机器名"
        echo "• 不要将隧道地址用作 SSH 连接地址！"
        echo "• 隧道和 SSH 可以同时使用，但用途不同"
        ;;
    12)
        echo "退出脚本"
        exit 0
        ;;
    *)
        echo "无效选择，请重新运行脚本"
        exit 1
        ;;
esac

echo ""
echo "=== 使用说明 ==="
echo "• 启动 tunnel: code tunnel --accept-server-license-terms --disable-telemetry"
echo "• 查看状态: code tunnel status"
echo "• 停止服务: code tunnel kill"
echo "• 重启服务: code tunnel restart"
echo "• 重命名机器: code tunnel rename <新名称>"
echo "• 清理服务器: code tunnel prune"
echo "• 端口转发: 在 VS Code 的 'Ports' 面板中添加端口"
echo "• 设置开机自启动: 创建并启用系统服务"
echo "• 管理系统服务: 查看、启用/禁用、重启、停止、删除服务"
echo "• 查看内网穿透网址: 显示隧道访问地址"
echo "• VS Code 连接指南: 多种连接隧道的方法"
echo ""
echo "=== 隧道连接功能 ==="
echo "• 自动检测隧道服务状态"
echo "• 显示隧道访问地址"
echo "• 提供多种连接方法"
echo "• 区分隧道和SSH连接方式"
echo ""
echo "=== 端口转发详细步骤 ==="
echo "1. 启动 tunnel 服务后，在 VS Code 中按 Ctrl+Shift+P"
echo "2. 输入 'Ports: Focus on Ports View' 打开端口面板"
echo "3. 点击 '+' 按钮添加新端口"
echo "4. 输入要转发的端口号"
echo "5. 选择转发类型（Local/Remote）"
echo ""
echo "注意：VS Code Tunnel 通过 'Ports' 面板管理端口转发，而不是命令行参数"
