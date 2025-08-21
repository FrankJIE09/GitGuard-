# 钉钉桌面图标安装说明

## 文件说明

- `dingtalk.desktop` - 钉钉的桌面图标配置文件
- `install_dingtalk_icon.sh` - 自动安装脚本
- `README_dingtalk_icon.md` - 本说明文档

## 安装方法

### 方法1: 使用自动安装脚本（推荐）

1. 确保您在包含这些文件的目录中
2. 运行安装脚本：
   ```bash
   ./install_dingtalk_icon.sh
   ```

### 方法2: 手动安装

1. 将 `dingtalk.desktop` 文件复制到桌面图标目录：
   ```bash
   cp dingtalk.desktop ~/.local/share/applications/
   ```

2. 设置执行权限：
   ```bash
   chmod +x ~/.local/share/applications/dingtalk.desktop
   ```

3. 更新桌面数据库（可选）：
   ```bash
   update-desktop-database ~/.local/share/applications
   ```

## 启动方式

桌面图标使用以下命令启动钉钉：
```bash
cd /usr/share/applications/ && gtk-launch com.alibabainc.dingtalk.desktop
```

## 图标设置

桌面图标使用钉钉官方图标：
- 图标路径：`/opt/apps/com.alibabainc.dingtalk/files/logo.ico`
- 图标类型：ICO格式
- 图标大小：约67KB

## 注意事项

- 安装后，钉钉图标会出现在应用程序菜单中
- 如果没有立即显示，请尝试注销后重新登录
- 确保系统中已经安装了钉钉应用程序
- 图标文件安装在用户目录下，不需要管理员权限

## 卸载方法

要卸载钉钉桌面图标，只需删除文件：
```bash
rm ~/.local/share/applications/dingtalk.desktop
```

## 故障排除

如果图标不显示：
1. 检查文件权限是否正确
2. 确认钉钉应用程序是否已安装
3. 尝试重新启动桌面环境
4. 检查桌面图标目录是否存在
