# 如何上传和替换App Store Connect中的构建版本

## 📋 概述

本指南将帮助你上传新的构建版本到App Store Connect，以及如何替换现有的构建版本。

---

## 方法一：使用Xcode Organizer上传（推荐）

### 第1步：打开Xcode Organizer

1. 打开Xcode应用
2. 在菜单栏选择：**Window → Organizer**
   - 或使用快捷键：`Shift + Command + O`

### 第2步：找到你的归档

1. 在Organizer窗口左侧，选择 **Archives** 标签
2. 找到 **PhotoTidy-Toilet Buddy** 应用
3. 你应该能看到刚才创建的归档（日期：Oct 22, 2025）

### 第3步：分发应用

1. 选择你想要上传的归档
2. 点击右侧的 **Distribute App** 按钮
3. 选择分发方式：

   ```
   ⚪ App Store Connect
      - 用于提交到App Store审核
      - 用于TestFlight测试
   
   ⚪ Ad Hoc
      - 用于在注册设备上测试
   
   ⚪ Enterprise
      - 用于企业内部分发
   
   ⚪ Development
      - 用于开发测试
   ```

4. 选择 **App Store Connect**，点击 **Next**

### 第4步：配置上传选项

1. **App Store Connect distribution options**:
   - ☑️ Upload your app's symbols to receive symbolicated crash logs
   - ☑️ Manage Version and Build Number
   - ☐ Strip Swift symbols (通常不勾选)

2. 点击 **Next**

### 第5步：重新签名（如果需要）

1. **Select a distribution certificate and provisioning profile**:
   - Distribution Certificate: 选择你的 **Apple Distribution** 证书
   - Provisioning Profile: 
     - **Automatic** (推荐) - Xcode会自动选择
     - **Manual** - 手动选择配置文件

2. 点击 **Next**

### 第6步：审查并上传

1. 审查应用信息：
   ```
   Name: PhotoTidy-Toilet Buddy
   Bundle ID: com.phototidy.toiletbuddy
   Version: 1.0
   Build: 1
   Size: ~3.5 MB
   ```

2. 点击 **Upload** 开始上传

3. 等待上传完成（通常需要几分钟）

### 第7步：等待处理

- 上传完成后，显示 **Upload Successful** ✅
- 构建版本会在App Store Connect中处理（通常需要5-15分钟）
- 你会收到邮件通知处理状态

---

## 方法二：使用命令行工具（高级用户）

### 使用 `altool` 上传

⚠️ **注意**: `altool` 已被弃用，推荐使用 `notarytool` 或 Xcode Organizer

```bash
# 导出IPA文件（使用exportOptions.plist）
xcodebuild -exportArchive \
  -archivePath "PhotoTidy-Toilet Buddy.xcarchive" \
  -exportPath "./build" \
  -exportOptionsPlist "exportOptions.plist"

# 使用xcrun altool上传（已弃用）
xcrun altool --upload-app \
  --type ios \
  --file "./build/PhotoTidy-Toilet Buddy.ipa" \
  --username "your-apple-id@email.com" \
  --password "@keychain:AC_PASSWORD"
```

### 使用 Transporter 应用

1. 下载并打开 **Transporter** 应用（从Mac App Store）
2. 登录你的Apple ID
3. 点击 **+** 按钮或拖拽IPA文件
4. 点击 **Deliver** 上传

---

## 📱 在App Store Connect中替换构建版本

### 情况1：TestFlight测试阶段

如果你只是在TestFlight测试，不需要特别操作：

1. 上传新的构建版本（使用上述方法）
2. 登录 [App Store Connect](https://appstoreconnect.apple.com)
3. 进入 **My Apps → PhotoTidy-Toilet Buddy → TestFlight**
4. 新构建处理完成后会自动出现在列表中
5. 选择新构建版本进行测试

### 情况2：准备提交审核（未提交）

如果你还没有提交应用到审核：

1. 上传新的构建版本
2. 进入 **App Store Connect**
3. 选择 **My Apps → PhotoTidy-Toilet Buddy**
4. 点击左侧的 **App Store** 标签
5. 找到准备提交的版本（例如 1.0）
6. 在 **Build** 部分：
   - 点击当前选择的构建版本
   - 会弹出构建版本选择器
   - 选择新上传的构建版本
   - 点击 **Done**

### 情况3：已提交审核但未批准

⚠️ **重要**: 如果应用已经在审核中，你需要：

1. **取消当前审核**:
   - 进入 **App Store Connect**
   - 选择应用和版本
   - 点击 **Cancel This Submission**

2. **等待状态变回 "Prepare for Submission"**

3. **选择新构建**:
   - 按照"情况2"的步骤选择新构建

4. **重新提交审核**

### 情况4：应用已上线，提交新版本

如果你要更新已上线的应用：

1. **创建新版本**:
   - 进入 App Store Connect
   - 点击左侧的 **App Store** 标签
   - 点击版本号旁的 **+** 按钮
   - 选择 **iOS** 并输入新版本号（例如 1.1）

2. **上传新构建**:
   - 确保新构建的 `CFBundleShortVersionString` 与新版本号匹配
   - 构建号 `CFBundleVersion` 必须比之前的大

3. **选择构建并提交**:
   - 在新版本中选择新上传的构建
   - 填写更新说明（What's New）
   - 提交审核

---

## 🔄 版本号和构建号规则

### 版本号 (CFBundleShortVersionString)

- 格式: `主版本.次版本.修订版本` (例如: 1.0, 1.1, 2.0)
- 用户可见的版本号
- 每次功能更新或修复时递增

### 构建号 (CFBundleVersion)

- 格式: 整数或点分隔的整数 (例如: 1, 2, 100, 1.0.1)
- 用户不可见
- **每次上传必须唯一且递增**
- 同一个版本号可以有多个构建号

### 示例版本进展

```
Version 1.0, Build 1   ← 第一次提交
Version 1.0, Build 2   ← 修复bug，重新上传
Version 1.0, Build 3   ← 再次修复，重新上传
Version 1.1, Build 4   ← 新功能，新版本
Version 1.1, Build 5   ← 修复新版本的bug
Version 2.0, Build 6   ← 重大更新
```

---

## 📋 上传前检查清单

在上传之前，确保：

- ✅ 已经创建归档文件 (`.xcarchive`)
- ✅ 应用已正确签名（Distribution证书）
- ✅ Bundle ID 正确
- ✅ 版本号和构建号设置正确
- ✅ 构建号比之前的所有上传都大
- ✅ 所有必要的权限和隐私说明已添加到 Info.plist
- ✅ 应用图标齐全（包括iPad版本）
- ✅ 已在真机或模拟器上测试
- ✅ 没有编译警告或错误

---

## 🚨 常见问题和解决方案

### 问题1: "Missing Compliance" 邮件

**解决方案**: 
- 登录App Store Connect
- 进入构建版本详情
- 回答加密合规性问题
- 大多数应用选择 "No"（如果只使用标准的HTTPS）

### 问题2: "Invalid Binary" 或 "ITMS-90xxx" 错误

**解决方案**:
- 检查 Info.plist 中的所有必需字段
- 确保隐私权限描述完整
- 验证应用图标完整性
- 检查 minimum deployment target

### 问题3: 构建版本不出现在App Store Connect中

**解决方案**:
- 等待15-30分钟（处理需要时间）
- 检查邮件是否有错误通知
- 确保构建号是新的、唯一的
- 验证 Bundle ID 匹配

### 问题4: "An error occurred uploading to the App Store"

**解决方案**:
- 检查网络连接
- 确认Apple ID账号权限
- 使用 Application Specific Password
- 尝试重新登录Xcode

---

## 🎯 当前项目状态

### 归档信息
```
归档路径: PhotoTidy-Toilet Buddy.xcarchive
Bundle ID: com.phototidy.toiletbuddy
版本: 1.0
构建: 1
签名: Apple Development (需要改为 Distribution)
```

### ⚠️ 重要提醒

当前归档使用的是 **Development** 签名。要上传到App Store，你需要：

1. **创建 Distribution 证书**（如果还没有）
2. **创建 App Store Provisioning Profile**
3. **使用 Distribution 配置重新归档**

或者在Xcode Organizer的分发过程中，选择 **Automatically manage signing**，Xcode会自动重新签名。

---

## 📞 需要帮助？

如果遇到问题：

1. 查看 [App Store Connect Help](https://developer.apple.com/help/app-store-connect/)
2. 检查 [Apple Developer Forums](https://developer.apple.com/forums/)
3. 联系 [Apple Developer Support](https://developer.apple.com/contact/)

---

**最后更新**: 2025-10-22
**适用版本**: Xcode 17.0+, iOS 16.0+

