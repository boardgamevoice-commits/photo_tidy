# PhotoTidy 开发者网站

这个文件夹包含 PhotoTidy 应用的开发者网站文件，用于托管在 GitHub Pages 上。

## 文件说明

- `index.html` - 应用主页，包含功能介绍和应用概览
- `privacy.html` - 隐私政策页面，详细说明数据处理和隐私保护措施
- `support.html` - 帮助与支持页面，包含使用指南和常见问题解答

## 部署到 GitHub Pages

### 方法 1：通过仓库设置启用 GitHub Pages

1. 将 `docs` 文件夹推送到 GitHub 仓库
2. 进入仓库的 Settings → Pages
3. 在 "Source" 下选择 "Deploy from a branch"
4. 在 "Branch" 下选择 `main` 分支和 `/docs` 文件夹
5. 点击 Save

几分钟后，您的网站将在以下地址可用：
```
https://boardgamevoice-commits.github.io/photo_tidy/
```

### 方法 2：推送步骤

```bash
# 在项目根目录执行
git add docs/
git commit -m "Add developer website with privacy policy"
git push origin main
```

## 网站链接

部署后，您的网站链接将是：

- 主页：`https://boardgamevoice-commits.github.io/photo_tidy/`
- 隐私政策：`https://boardgamevoice-commits.github.io/photo_tidy/privacy.html`
- 帮助支持：`https://boardgamevoice-commits.github.io/photo_tidy/support.html`

## App Store 配置

在提交应用到 App Store 时，您需要提供隐私政策链接。请使用：

```
https://boardgamevoice-commits.github.io/photo_tidy/privacy.html
```

## 联系信息

开发者邮箱：fangdev1063@gmail.com

## 自定义

您可以根据需要修改 HTML 文件中的：
- 样式和布局
- 应用功能描述
- 隐私政策内容
- 常见问题解答

所有页面都使用响应式设计，在移动设备和桌面设备上都能良好显示。

