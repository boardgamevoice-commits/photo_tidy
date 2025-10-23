# 快速上传步骤 - PhotoTidy-Toilet Buddy

## 🚀 5步快速上传到App Store Connect

### 步骤1: 打开Xcode Organizer
```
Xcode → Window → Organizer (或 Shift+Cmd+O)
```

### 步骤2: 选择归档并分发
```
1. 左侧选择 "Archives"
2. 找到 "PhotoTidy-Toilet Buddy"
3. 点击 "Distribute App"
```

### 步骤3: 选择分发方式
```
选择: ⚪ App Store Connect
点击: Next
```

### 步骤4: 配置选项
```
✅ Upload symbols
✅ Manage Version and Build Number
签名: Automatic (推荐)
点击: Next → Next
```

### 步骤5: 上传
```
审查信息 → 点击 Upload → 等待完成
```

---

## 📱 在App Store Connect中选择构建

### 如果还没提交审核：

1. 访问: https://appstoreconnect.apple.com
2. My Apps → PhotoTidy-Toilet Buddy → App Store
3. 找到版本 1.0
4. Build 部分 → 点击选择构建
5. 选择新上传的构建 → Done
6. Save → Submit for Review

### 如果要替换构建：

```
已在TestFlight: 
  → 直接上传新构建即可

准备提交阶段:
  → 在Build部分重新选择新构建

审核中:
  → Cancel Submission → 重新选择构建 → 重新提交

已上线:
  → 创建新版本(如1.1) → 上传新构建 → 选择构建
```

---

## ⚠️ 注意事项

### 版本号规则
- Version: 1.0, 1.1, 2.0 (用户可见)
- Build: 1, 2, 3, 4... (必须递增，唯一)

### 签名要求
- TestFlight: Development 或 Distribution
- App Store: 必须 Distribution

### 当前状态
```
归档: PhotoTidy-Toilet Buddy.xcarchive
版本: 1.0
构建: 1
签名: Development ⚠️ (需要改为Distribution)
```

---

## 🔧 如果需要重新归档（使用Distribution签名）

```bash
# 在项目目录运行:
xcodebuild -workspace "PhotoTidy-Toilet Buddy.xcworkspace" \
  -scheme "PhotoTidy-Toilet Buddy" \
  -configuration Release \
  -destination generic/platform=iOS \
  archive \
  -archivePath "./PhotoTidy-Toilet Buddy.xcarchive"
```

然后在Xcode Organizer中选择 "Automatically manage signing" 来重新签名。

---

## 📧 处理后续邮件

上传后会收到邮件:

1. **"Your build is being processed"** - 正常，等待
2. **"Your build is ready"** - 可以在App Store Connect中使用
3. **"Missing Compliance"** - 登录回答加密问题
4. **"Invalid Binary"** - 检查错误信息，修复后重新上传

---

**提示**: 首次上传可能需要15-30分钟处理时间

