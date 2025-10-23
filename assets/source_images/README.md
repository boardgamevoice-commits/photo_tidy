# 📸 App Icon Source Images

这个目录用于存放app icon的源图像文件。

## 使用方法

1. **上传您的源图像**：
   - 将您的 `app_icon.png` 文件上传到这个目录
   - 推荐尺寸：至少 1024x1024 像素
   - 格式：PNG（推荐）或 JPG

2. **生成所有尺寸的图标**：
   ```bash
   # 从项目根目录运行
   ./generate_app_icons.sh assets/source_images/app_icon.png
   ```

3. **验证图标生成**：
   ```bash
   ./verify_icons.sh
   ```

## 文件命名建议

- `app_icon.png` - 主要的app图标
- `app_icon_light.png` - 浅色主题版本
- `app_icon_dark.png` - 深色主题版本
- `app_icon_alt.png` - 替代设计版本

## 设计要求

### 推荐规格
- **最小尺寸**: 1024x1024 像素
- **推荐尺寸**: 2048x2048 像素或更高
- **格式**: PNG（支持透明背景）
- **颜色模式**: RGB
- **文件大小**: 建议小于 5MB

### 设计要点
- 简洁明了，在小尺寸下仍然清晰
- 高对比度，确保在各种背景下可见
- 避免过于复杂的细节
- 考虑iOS的圆角效果
- 与应用的马桶清理主题保持一致

## 当前文件

请将您的源图像文件放在这个目录中。

---

*最后更新：$(date)*
