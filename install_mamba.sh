#!/bin/bash

# 颜色定义
RED = '\033[0;31m'
GREEN = '\033[0;32m'
YELLOW = '\033[1;33m'
BLUE = '\033[0;34m'
NC = '\033[0m'  # No Color

# 打印带颜色的消息
print_message()
{
    echo - e
"${GREEN}[INFO]${NC} $1"
}

print_warning()
{
    echo - e
"${YELLOW}[WARNING]${NC} $1"
}

print_error()
{
    echo - e
"${RED}[ERROR]${NC} $1"
}

print_step()
{
    echo - e
"${BLUE}[STEP]${NC} $1"
}

# 检查是否为root用户
check_root()
{
if [[ $EUID - eq
0]]; then
print_error
"请不要使用root用户运行此脚本！"
exit
1
fi
}

# 检查系统架构
check_architecture()
{
    ARCH =$(uname - m)
if [["$ARCH" != "x86_64" & & "$ARCH" != "aarch64"]];
then
print_error
"不支持的架构: $ARCH"
exit
1
fi
print_message
"检测到系统架构: $ARCH"
}

# 下载并安装Miniconda
install_miniconda()
{
    print_step
"开始安装Miniconda..."

# 设置下载URL
if [["$(uname)" == "Linux"]];
then
if [["$(uname -m)" == "x86_64"]];
then
MINICONDA_URL = "https://mirrors.tuna.tsinghua.edu.cn/anaconda/miniconda/Miniconda3-latest-Linux-x86_64.sh"
elif [["$(uname -m)" == "aarch64"]];
then
MINICONDA_URL = "https://mirrors.tuna.tsinghua.edu.cn/anaconda/miniconda/Miniconda3-latest-Linux-aarch64.sh"
fi
elif [["$(uname)" == "Darwin"]];
then
if [["$(uname -m)" == "x86_64"]];
then
MINICONDA_URL = "https://mirrors.tuna.tsinghua.edu.cn/anaconda/miniconda/Miniconda3-latest-MacOSX-x86_64.sh"
elif [["$(uname -m)" == "arm64"]];
then
MINICONDA_URL = "https://mirrors.tuna.tsinghua.edu.cn/anaconda/miniconda/Miniconda3-latest-MacOSX-arm64.sh"
fi
fi

print_message
"下载Miniconda安装脚本..."
if wget - O
Miniconda3 - latest.sh
"$MINICONDA_URL";
then
print_message
"下载完成"
else
print_error
"下载失败，尝试使用curl..."
if curl - L - o
Miniconda3 - latest.sh
"$MINICONDA_URL";
then
print_message
"下载完成"
else
print_error
"下载失败，请检查网络连接"
exit
1
fi
fi

print_message
"安装Miniconda..."
if bash
Miniconda3 - latest.sh - b - p
"$HOME/miniconda3";
then
print_message
"Miniconda安装成功"
else
print_error
"Miniconda安装失败"
exit
1
fi

# 清理安装文件
rm - f
Miniconda3 - latest.sh
}

# 配置conda使用国内镜像源
configure_conda_mirrors()
{
    print_step
"配置conda使用国内镜像源..."

# 初始化conda
print_message
"初始化conda..."
"$HOME/miniconda3/bin/conda"
init
bash

# 重新加载bash配置
source
"$HOME/.bashrc"

# 添加清华大学镜像源
print_message
"添加清华大学镜像源..."
conda
config - -add
channels
https: // mirrors.tuna.tsinghua.edu.cn / anaconda / pkgs / main /
          conda
config - -add
channels
https: // mirrors.tuna.tsinghua.edu.cn / anaconda / pkgs / free /
          conda
config - -add
channels
https: // mirrors.tuna.tsinghua.edu.cn / anaconda / cloud / conda - forge /

          # 设置通道优先级
          conda
config - -set
channel_priority
strict

print_message
"conda镜像源配置完成"
}

# 安装mamba
install_mamba()
{
    print_step
"安装mamba..."

# 尝试使用conda安装mamba
print_message
"尝试使用conda安装mamba..."
if conda
install
mamba - n
base - c
conda - forge - y;
then
print_message
"mamba安装成功"
return 0
else
print_warning
"conda安装mamba失败，尝试使用pip安装..."

# 使用pip安装mamba
if pip install mamba; then
print_message
"mamba安装成功（通过pip）"
return 0
else
print_error
"mamba安装失败"
return 1
fi
fi
}

# 配置pip使用阿里云镜像源
configure_pip_mirrors()
{
print_step
"配置pip使用阿里云镜像源..."

# 创建pip配置目录
mkdir - p
"$HOME/.config/pip"

# 设置阿里云镜像源
print_message
"设置阿里云PyPI镜像源..."
pip
config
set
global.index - url
https: // mirrors.aliyun.com / pypi / simple /
pip
config
set
global.trusted - host
mirrors.aliyun.com

# 验证配置
print_message
"验证pip配置..."
pip
config
list

print_message
"pip镜像源配置完成"
}

# 验证安装
verify_installation()
{
print_step
"验证安装结果..."

# 检查conda
if command - v conda & > / dev / null; then
print_message
"✓ conda安装成功: $(conda --version)"
else
print_error
"✗ conda安装失败"
fi

# 检查mamba
if command - v mamba & > / dev / null; then
print_message
"✓ mamba安装成功: $(mamba --version)"
else
print_error
"✗ mamba安装失败"
fi

# 检查pip配置
if pip config list | grep -q "mirrors.aliyun.com"; then
print_message
"✓ pip镜像源配置成功"
else
print_error
"✗ pip镜像源配置失败"
fi
}

# 显示使用说明
show_usage()
{
print_message
"安装完成！使用说明："
echo
""
echo
"1. 重新打开终端或运行: source ~/.bashrc"
echo
"2. 使用conda管理环境: conda create -n myenv python=3.9"
echo
"3. 使用mamba安装包（更快）: mamba install numpy"
echo
"4. 使用pip安装Python包: pip install requests"
echo
""
echo
"镜像源配置："
echo
"- conda: 清华大学镜像源"
echo
"- pip: 阿里云镜像源"
echo
""
echo
"配置文件位置："
echo
"- conda: ~/.condarc"
echo
"- pip: ~/.config/pip/pip.conf"
}

# 主函数
main()
{
echo
"=========================================="
echo
"    Mamba安装和镜像源配置脚本"
echo
"=========================================="
echo
""

# 检查系统
check_root
check_architecture

# 安装和配置
install_miniconda
configure_conda_mirrors
install_mamba
configure_pip_mirrors

# 验证安装
verify_installation

# 显示使用说明
show_usage

echo
""
print_message
"脚本执行完成！"
}

# 执行主函数
main
"$@"
