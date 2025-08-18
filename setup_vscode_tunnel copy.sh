#!/bin/bash
set -e

echo "=== VS Code Tunnel 简化设置脚本 ==="
echo "此脚本将帮助您设置 VS Code Tunnel 服务"

# === 检查是否 root ===
if [ "$EUID" -ne 0 ]; then
  echo "请使用 root 权限运行：sudo ./setup_vscode_tunnel.sh"
  exit 1
fi

# === 检查 code 命令是否可用 ===
if ! command -v code &> /dev/null; then
    echo "错误：未找到 code 命令"
    echo "请先安装 VS Code CLI："
    echo "sudo snap install code --classic"
    exit 1
fi

echo "✓ 找到 code 命令: $(which code)"

# === 停止并清理之前的服务 ===
echo "=== 1. 清理之前的服务 ==="
systemctl stop vscode-tunnel 2>/dev/null || true
systemctl disable vscode-tunnel 2>/dev/null || true
rm -f /etc/systemd/system/vscode-tunnel.service

# === 创建简单的 systemd 服务 ===
echo "=== 2. 创建 systemd 服务 ==="
SERVICE_FILE="/etc/systemd/system/vscode-tunnel.service"

cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=VS Code Tunnel Service
After=network.target

[Service]
Type=simple
ExecStart=/snap/bin/code tunnel --accept-server-license-terms --disable-telemetry
Restart=always
RestartSec=10
User=frank
WorkingDirectory=/home/frank
Environment=HOME=/home/frank
Environment=DISPLAY=:0

[Install]
WantedBy=multi-user.target
EOF

echo "✓ 服务文件已创建: $SERVICE_FILE"

# === 启动服务 ===
echo "=== 3. 启动服务 ==="
systemctl daemon-reload
systemctl enable vscode-tunnel
systemctl start vscode-tunnel

# === 检查服务状态 ===
echo "=== 4. 服务状态 ==="
systemctl status vscode-tunnel --no-pager

echo ""
echo "=== 5. 下一步操作说明 ==="
echo "1. 服务已启动，现在需要登录您的账户："
echo "   code tunnel user login"
echo ""
echo "2. 登录成功后，可以手动转发端口："
echo "   code tunnel --cli tunnel forward --port 3000 --name port3000"
echo "   code tunnel --cli tunnel forward --port 5000 --name port5000"
echo "   code tunnel --cli tunnel forward --port 8080 --name port8080"
echo ""
echo "3. 查看服务状态："
echo "   sudo systemctl status vscode-tunnel"
echo ""
echo "4. 查看服务日志："
echo "   sudo journalctl -u vscode-tunnel -f"
echo ""
echo "5. 停止服务："
echo "   sudo systemctl stop vscode-tunnel"
echo ""
echo "6. 卸载服务："
echo "   sudo systemctl disable vscode-tunnel"
echo "   sudo rm /etc/systemd/system/vscode-tunnel.service"
