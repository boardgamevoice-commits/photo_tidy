# 🚽 App Icon Update Guide

## 概述
这个指南将帮助您更新 PhotoTidy-Toilet Buddy 应用的图标。

## 准备工作

### 1. 安装 ImageMagick
首先需要安装 ImageMagick 来处理图像：

```bash
# 使用 Homebrew 安装
brew install imagemagick

# 或者使用 MacPorts
sudo port install ImageMagick
```

### 2. 准备源图像
- 推荐尺寸：至少 1024x1024 像素
- 格式：PNG 或 JPG
- 内容：根据您的马桶主题设计

## 使用方法

### 方法一：使用自动生成脚本（推荐）

1. 将您的源图像文件放在项目根目录
2. 运行生成脚本：

```bash
./generate_app_icons.sh your_icon_image.png
```

脚本会自动生成所有需要的图标尺寸。

### 方法二：手动生成

如果您想手动控制生成过程，可以使用以下 ImageMagick 命令：

```bash
# iPhone 图标
convert source.png -resize 40x40 icon-20@2x.png
convert source.png -resize 60x60 icon-20@3x.png
convert source.png -resize 58x58 icon-29@2x.png
convert source.png -resize 87x87 icon-29@3x.png
convert source.png -resize 80x80 icon-40@2x.png
convert source.png -resize 120x120 icon-40@3x.png
convert source.png -resize 120x120 icon-60@2x.png
convert source.png -resize 180x180 icon-60@3x.png

# iPad 图标
convert source.png -resize 20x20 icon-20.png
convert source.png -resize 40x40 icon-20@2x.png
convert source.png -resize 29x29 icon-29.png
convert source.png -resize 58x58 icon-29@2x.png
convert source.png -resize 40x40 icon-40.png
convert source.png -resize 80x80 icon-40@2x.png
convert source.png -resize 76x76 icon-76.png
convert source.png -resize 152x152 icon-76@2x.png
convert source.png -resize 167x167 icon-83.5@2x.png

# App Store 图标
convert source.png -resize 1024x1024 icon-1024.png
```

## 图标尺寸说明

### iPhone 图标
- `icon-20@2x.png` - 40x40 像素
- `icon-20@3x.png` - 60x60 像素
- `icon-29@2x.png` - 58x58 像素
- `icon-29@3x.png` - 87x87 像素
- `icon-40@2x.png` - 80x80 像素
- `icon-40@3x.png` - 120x120 像素
- `icon-60@2x.png` - 120x120 像素
- `icon-60@3x.png` - 180x180 像素

### iPad 图标
- `icon-20.png` - 20x20 像素
- `icon-20@2x.png` - 40x40 像素
- `icon-29.png` - 29x29 像素
- `icon-29@2x.png` - 58x58 像素
- `icon-40.png` - 40x40 像素
- `icon-40@2x.png` - 80x80 像素
- `icon-76.png` - 76x76 像素
- `icon-76@2x.png` - 152x152 像素
- `icon-83.5@2x.png` - 167x167 像素

### App Store 图标
- `icon-1024.png` - 1024x1024 像素

## 设计建议

### 马桶主题图标设计要点
1. **简洁明了**：在小尺寸下仍然清晰可辨
2. **色彩对比**：使用高对比度颜色
3. **圆角处理**：iOS 会自动添加圆角，设计时考虑这一点
4. **避免文字**：小尺寸下文字难以阅读
5. **主题一致性**：与应用的马桶清理主题保持一致

### 推荐设计元素
- 白色马桶轮廓
- 蓝色水流效果
- 简洁的几何形状
- 明亮的背景色

## 验证步骤

1. **在 Xcode 中检查**
   - 打开项目
   - 查看 Assets.xcassets > AppIcon
   - 确认所有图标都已正确加载

2. **构建测试**
   - 在模拟器中运行应用
   - 检查主屏幕上的图标显示

3. **设备测试**
   - 在实际设备上安装应用
   - 测试不同尺寸的图标显示效果

## 故障排除

### 常见问题

1. **图标显示为空白**
   - 检查文件路径是否正确
   - 确认图像格式为 PNG
   - 验证 Contents.json 配置

2. **图标模糊**
   - 使用更高分辨率的源图像
   - 检查图像质量设置

3. **ImageMagick 命令失败**
   - 确认 ImageMagick 已正确安装
   - 检查源图像文件是否存在

### 获取帮助

如果遇到问题，可以：
1. 检查 Xcode 的构建日志
2. 验证 Assets.xcassets 的配置
3. 重新生成图标文件

## 下一步

图标更新完成后：
1. 提交更改到版本控制
2. 更新应用商店的图标（如果需要）
3. 考虑创建不同主题的图标变体

---

*最后更新：$(date)*
