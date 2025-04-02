#!/bin/bash

# 设置项目路径（默认为当前目录）
PROJECT_DIR="."

# 安装 pipreqs（如果尚未安装）
if ! command -v pipreqs &> /dev/null; then
    echo "📦 pipreqs 未安装，正在安装..."
    pip install pipreqs
fi

# 生成 requirements.txt（覆盖原文件）
echo "🔍 正在使用 pipreqs 生成 requirements.txt..."
pipreqs "$PROJECT_DIR" --force

echo "✅ requirements.txt 已生成！"

