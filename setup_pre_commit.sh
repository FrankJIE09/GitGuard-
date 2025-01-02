#!/bin/bash

# 检查是否在 Git 仓库目录中
if [ ! -d ".git" ]; then
  echo "Error: 当前目录不是 Git 仓库，请进入正确的 Git 仓库目录后再运行此脚本。"
  exit 1
fi

# 设置 pre-commit 文件路径
PRE_COMMIT_FILE=".git/hooks/pre-commit"

# 创建 pre-commit 文件内容
echo "创建或覆盖 pre-commit 钩子文件..."
cat <<'EOF' > "$PRE_COMMIT_FILE"
#!/bin/sh

# 设置最大文件大小（例如：50MB）
max_size=52428800  # 50MB，单位是字节

# 遍历所有将被提交的文件
for file in $(git diff --cached --name-only); do
    if [ -f "$file" ]; then
        file_size=$(stat -c %s "$file")
        if [ $file_size -gt $max_size ]; then
            echo "Error: File $file is larger than 50MB and will not be committed."
            exit 1
        fi
    fi
done

exit 0
EOF

# 赋予 pre-commit 文件可执行权限
echo "设置 pre-commit 文件可执行权限..."
chmod +x "$PRE_COMMIT_FILE"

# 提示用户完成配置
echo "pre-commit 钩子已成功配置！将会阻止超过 50MB 的文件提交。"

# 测试部分（可选）
echo "是否测试配置？输入 'y' 进行测试，其他任意键跳过测试。"
read -r TEST_CHOICE
if [ "$TEST_CHOICE" = "y" ]; then
  echo "创建一个 60MB 的测试文件..."
  dd if=/dev/zero of=large_file.txt bs=1M count=60

  echo "尝试添加和提交大文件以验证钩子效果..."
  git add large_file.txt
  if git commit -m "Test large file"; then
    echo "Error: 提交成功，pre-commit 钩子未正确配置，请检查。"
  else
    echo "测试成功：提交被阻止，大文件无法提交！"
  fi

  # 清理测试文件
  echo "清理测试文件..."
  git reset HEAD large_file.txt
  rm large_file.txt
  echo "测试完成，配置正确！"
else
  echo "跳过测试。配置已完成，请在实际提交时验证效果。"
fi

echo "完成！"
