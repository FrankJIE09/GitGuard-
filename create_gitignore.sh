#!/bin/bash

# 检查是否在 Git 仓库目录中
if [ ! -d ".git" ]; then
  echo "Error: 当前目录不是 Git 仓库，请进入正确的 Git 仓库目录后再运行此脚本。"
  exit 1
fi

# .gitignore 文件路径
GITIGNORE_FILE=".gitignore"

# 常见的忽略规则
IGNORE_CONTENT="

# 忽略日志文件
*.log

# 忽略临时文件
*.tmp
*.swp
*.bak

# 忽略操作系统生成的文件
.DS_Store
Thumbs.db

# 忽略编译生成的文件
*.o
*.obj
*.class
*.pyc
*.pyo
*.exe

# 忽略依赖文件夹
node_modules/
vendor/
__pycache__/

# 忽略环境文件
.env
.env.local
*.env

# 忽略 IDE 和编辑器配置文件
.idea/
.vscode/
*.sublime-*

"

# 如果 .gitignore 文件不存在，则创建
if [ ! -f "$GITIGNORE_FILE" ]; then
  echo "创建 .gitignore 文件..."
  touch "$GITIGNORE_FILE"
else
  echo ".gitignore 文件已存在，将添加常见忽略规则..."
fi

# 将忽略规则添加到 .gitignore 文件（避免重复添加）
echo "$IGNORE_CONTENT" | while read -r line; do
  if ! grep -Fxq "$line" "$GITIGNORE_FILE"; then
    echo "$line" >> "$GITIGNORE_FILE"
  fi
done

echo ".gitignore 文件已更新！以下为当前内容："
cat "$GITIGNORE_FILE"
