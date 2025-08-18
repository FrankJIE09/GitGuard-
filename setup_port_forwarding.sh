#!/bin/bash

echo "=== 端口转发设置脚本 ==="
echo "此脚本帮助您设置端口转发服务"

# === 检查是否 root ===
if [ "$EUID" -ne 0 ]; then
  echo "请使用 root 权限运行：sudo ./setup_port_forwarding.sh"
  exit 1
fi

echo "=== 1. 安装 ngrok（端口转发工具） ==="
if ! command -v ngrok &> /dev/null; then
    echo "正在安装 ngrok..."
    
    # 下载 ngrok
    wget -O ngrok.zip https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip
    
    if [ $? -eq 0 ]; then
        # 解压并安装
        unzip ngrok.zip
        sudo mv ngrok /usr/local/bin/
        chmod +x /usr/local/bin/ngrok
        rm ngrok.zip
        
        echo "✓ ngrok 安装成功"
    else
        echo "✗ ngrok 下载失败，请手动安装"
        echo "访问 https://ngrok.com/download 下载"
        exit 1
    fi
else
    echo "✓ ngrok 已安装: $(which ngrok)"
fi

echo ""
echo "=== 2. 创建端口转发服务 ==="
SERVICE_FILE="/etc/systemd/system/port-forwarding.service"

cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Port Forwarding Service with ngrok
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/ngrok start --all
Restart=always
RestartSec=10
User=frank
WorkingDirectory=/home/frank

[Install]
WantedBy=multi-user.target
EOF

echo "✓ 服务文件已创建: $SERVICE_FILE"

echo ""
echo "=== 3. 启动服务 ==="
systemctl daemon-reload
systemctl enable port-forwarding
systemctl start port-forwarding

echo ""
echo "=== 4. 服务状态 ==="
systemctl status port-forwarding --no-pager

echo ""
echo "=== 5. 下一步操作说明 ==="
echo "1. 您需要注册 ngrok 账户并获取 authtoken："
echo "   - 访问 https://ngrok.com/ 注册账户"
echo "   - 获取 authtoken"
echo "   - 运行: ngrok config add-authtoken <YOUR_TOKEN>"
echo ""
echo "2. 配置完成后，服务将自动启动"
echo ""
echo "3. 查看 ngrok 状态："
echo "   ngrok status"
echo ""
echo "4. 手动启动端口转发："
echo "   ngrok http 3000  # 转发端口 3000"
echo "   ngrok http 5000  # 转发端口 5000"
echo "   ngrok http 8080  # 转发端口 8080"
echo ""
echo "5. 停止服务："
echo "   sudo systemctl stop port-forwarding"
echo ""
echo "注意：ngrok 免费版本有一些限制，付费版本提供更多功能"
