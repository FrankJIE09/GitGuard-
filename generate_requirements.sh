#!/bin/bash

# 设置根目录为当前目录
ROOT_DIR="."

# 检查 pipreqs 是否安装
if ! command -v pipreqs &> /dev/null; then
    echo "📦 pipreqs 未安装，正在安装..."
    pip install pipreqs
else
    echo "📦 pipreqs 已安装"
fi

echo "🔍 正在递归扫描项目目录：$ROOT_DIR"

# 强制生成 requirements.txt 到当前目录（即使代码在子目录）
pipreqs "$ROOT_DIR" --force --encoding=utf-8 --savepath "./requirements.txt"

if [ $? -eq 0 ]; then
    echo "✅ requirements.txt 已生成到当前目录！"
else
    echo "❌ 生成失败，请检查项目结构或依赖"
fi

