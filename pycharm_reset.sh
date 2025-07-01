#!/bin/bash
# PyCharm项目重置脚本

echo "开始重置PyCharm项目配置..."

# 1. 清理Python缓存
echo "清理Python缓存..."
find . -name "*.pyc" -delete
find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null

# 2. 清理PyCharm项目文件
echo "清理PyCharm项目文件..."
rm -rf .idea 2>/dev/null
rm -f *.iml 2>/dev/null

# 3. 清理其他缓存
echo "清理其他缓存文件..."
rm -rf .pytest_cache 2>/dev/null
rm -rf *.egg-info 2>/dev/null

# 4. 创建新的.gitignore（防止将来缓存问题）
echo "创建.gitignore..."
cat > .gitignore << 'EOF'
# Python缓存
__pycache__/
*.py[cod]
*$py.class
*.so

# PyCharm
.idea/
*.iml

# 其他
.pytest_cache/
*.egg-info/
.DS_Store
*~

# MuJoCo生成的文件
*.png
*.jpg
*.csv
EOF

echo "重置完成！"
echo ""
echo "现在请重新在PyCharm中打开项目："
echo "1. File → Open → 选择当前目录"  
echo "2. 选择正确的Python解释器"
echo "3. 运行诊断脚本验证: python pycharm_debug_check.py" 