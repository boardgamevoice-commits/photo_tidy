# AdMob 广告集成文档

## 概览

Photo Tidy App 使用 Google AdMob 插页式广告实现变现。广告在用户完成多次会话后智能展示，不影响核心体验。

## 实现架构

### 1. AdManager.swift - 广告管理器

**职责**: 
- AdMob SDK 初始化
- 插页式广告加载
- 广告展示控制
- 生命周期回调处理

**关键方法**:

```swift
class AdManager: NSObject {
    static let shared = AdManager()
    
    // 初始化 AdMob SDK
    func initializeAdMob() {
        GADMobileAds.sharedInstance().start { status in
            // 自动预加载第一个广告
            self.loadInterstitialAd()
        }
    }
    
    // 加载插页式广告
    func loadInterstitialAd() {
        GADInterstitialAd.load(...)
    }
    
    // 展示广告（带完成回调）
    func showInterstitialAd(completion: @escaping () -> Void) {
        // 展示广告
        // 关闭后执行 completion
    }
}
```

**广告 ID (测试)**:
- App ID: `ca-app-pub-3940256099942544~1458002511`
- Interstitial Unit ID: `ca-app-pub-3940256099942544/4411468910`

**⚠️ 重要**: 发布前必须替换为真实的 Ad Unit ID！

---

### 2. TidySessionViewModel - 会话计数器

**职责**:
- 追踪完成的会话数量
- 判断是否应该展示广告
- 控制广告展示频率

**关键属性**:

```swift
@Published var sessionCounter: Int = 0
private let adFrequency: Int = 3  // 每3次会话展示一次广告
```

**关键方法**:

```swift
// 结束会话时增加计数器
func endSession() {
    sessionCounter += 1
    isSessionCompleted = true
}

// 检查是否应该显示广告
func shouldShowAd() -> Bool {
    return sessionCounter % adFrequency == 0 && sessionCounter > 0
}
```

**逻辑说明**:
- 每次完成会话，`sessionCounter` 自增
- `sessionCounter % 3 == 0` 时返回 true
- 第 3、6、9... 次会话后显示广告

---

### 3. SessionCompleteView - 广告触发点

**职责**:
- 显示会话统计
- 触发广告检查逻辑
- 处理广告展示流程

**关键代码**:

```swift
private func handleStartNewSession() {
    // 1. 检查是否需要显示广告
    if viewModel.shouldShowAd() {
        showingAd = true
        
        // 2. 展示广告
        AdManager.shared.showInterstitialAd { [self] in
            // 3. 广告关闭后的回调
            showingAd = false
            
            // 4. 重置会话，返回设置界面
            DispatchQueue.main.async {
                viewModel.resetSession()
            }
        }
    } else {
        // 不需要广告，直接重置
        viewModel.resetSession()
    }
}
```

**用户体验**:
1. 用户点击"开始新任务"
2. 系统检查计数器
3. 如需展示 → 显示广告 → 等待关闭 → 进入设置界面
4. 无需展示 → 直接进入设置界面

---

### 4. PhotoTidyToiletBuddyApp - App 入口

**职责**:
- App 启动时初始化 AdMob

**实现**:

```swift
@main
struct PhotoTidyToiletBuddyApp: App {
    init() {
        // 初始化 AdMob SDK
        AdManager.shared.initializeAdMob()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

---

## 广告展示流程图

```
User completes session (CardReviewView)
    ↓
sessionCounter++ (TidySessionViewModel.endSession())
    ↓
Show SessionCompleteView
    ↓
User taps "Start New Session"
    ↓
Check sessionCounter % 3 == 0?
    ├─ YES (3rd, 6th, 9th... session)
    │   ↓
    │   AdManager.showInterstitialAd()
    │   ↓
    │   [User views ad]
    │   ↓
    │   Ad dismissed → Completion callback
    │   ↓
    │   viewModel.resetSession()
    │   ↓
    │   → SessionSetupView
    │
    └─ NO
        ↓
        viewModel.resetSession()
        ↓
        → SessionSetupView
```

---

## 配置参数

### 可调整参数

在 `TidySessionViewModel.swift` 中:

```swift
private let adFrequency: Int = 3  // 广告频率
```

**推荐值**:
- `3`: 每3次会话（平衡）
- `2`: 每2次会话（激进）
- `5`: 每5次会话（保守）

### Ad Unit ID 配置

在 `AdManager.swift` 和 `Info.plist` 中:

**AdManager.swift**:
```swift
private let interstitialAdUnitID = "ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX"
```

**Info.plist**:
```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX</string>
```

---

## 测试指南

### 1. 测试广告展示

```
1. 启动 App
2. 完成第一次会话 (sessionCounter = 1)
   → 不显示广告
3. 完成第二次会话 (sessionCounter = 2)
   → 不显示广告
4. 完成第三次会话 (sessionCounter = 3)
   → ✓ 显示广告
5. 完成第四次会话 (sessionCounter = 4)
   → 不显示广告
6. 完成第五次会话 (sessionCounter = 5)
   → 不显示广告
7. 完成第六次会话 (sessionCounter = 6)
   → ✓ 显示广告
```

### 2. 查看日志

启用 Console 查看广告日志:

```
AdMob SDK 初始化完成
开始加载插页式广告...
插页式广告加载成功 ✓
检查广告显示条件: sessionCounter=3, adFrequency=3, shouldShow=true
准备展示插页式广告...
插页式广告即将展示
插页式广告已关闭
执行广告关闭回调
```

### 3. 测试广告失败场景

- 无网络连接
- 广告未加载完成
- Ad Unit ID 错误

App 应该优雅降级，不阻塞用户流程。

---

## 生产环境配置

### 上线前检查清单

- [ ] **替换 Ad Unit ID**
  - AdManager.swift → 真实 Interstitial ID
  - Info.plist → 真实 App ID
  
- [ ] **调整广告频率**
  - 根据用户反馈和收益数据调整 `adFrequency`
  
- [ ] **移除测试日志**
  - 删除或禁用 `print()` 语句
  
- [ ] **测试真实广告**
  - 使用真实 Ad Unit ID 进行测试
  - 确认广告正确展示和关闭
  
- [ ] **隐私政策**
  - 更新隐私政策说明 AdMob 数据收集
  - 添加 App Store 隐私标签

### 获取真实 Ad Unit ID

1. 访问 [AdMob 控制台](https://apps.admob.com/)
2. 创建新应用或选择现有应用
3. 添加"插页式广告"单元
4. 复制 App ID 和 Ad Unit ID
5. 替换代码中的占位符 ID

---

## 性能优化

### 1. 预加载策略

- ✅ App 启动时预加载第一个广告
- ✅ 广告关闭后立即加载下一个
- ✅ 减少用户等待时间

### 2. 错误处理

- ✅ 广告加载失败 → 继续流程
- ✅ 广告展示失败 → 执行回调
- ✅ 无网络 → 跳过广告

### 3. 用户体验

- ✅ 不在审阅过程中打断
- ✅ 只在会话完成后展示
- ✅ 合理的展示频率（每3次）
- ✅ 无缝的流程过渡

---

## 常见问题

### Q: 广告不显示怎么办？

A: 检查以下几点:
1. 确认使用测试 Ad Unit ID
2. 检查网络连接
3. 查看控制台日志
4. 确认 AdMob SDK 已初始化

### Q: 如何修改广告频率？

A: 修改 `TidySessionViewModel.swift` 中的 `adFrequency` 值。

### Q: 如何禁用广告（测试用）？

A: 在 `SessionCompleteView.handleStartNewSession()` 中注释掉广告检查:

```swift
// if viewModel.shouldShowAd() { ... }
viewModel.resetSession()  // 直接重置
```

### Q: 广告 ID 在哪里配置？

A: 两个位置:
1. `AdManager.swift` → `interstitialAdUnitID`
2. `Info.plist` → `GADApplicationIdentifier`

---

## 收益优化建议

1. **频率测试**: A/B 测试不同的 `adFrequency` 值
2. **用户分组**: 考虑为付费用户提供无广告体验
3. **展示时机**: 当前在会话完成后，可考虑其他时机
4. **广告格式**: 可添加横幅广告或激励视频广告

---

## 合规性

### App Store 审核

- ✅ 广告不影响核心功能
- ✅ 广告有明确关闭方式
- ✅ 不在权限请求时展示广告
- ✅ 隐私政策包含 AdMob 说明

### GDPR / CCPA

- 在 AdMob 控制台配置同意选项
- 考虑使用 Google UMP SDK
- 更新隐私政策

---

## 监控和分析

### 推荐监控指标

- **展示率** (Fill Rate): 广告成功展示 / 请求次数
- **点击率** (CTR): 点击 / 展示
- **eCPM**: 每千次展示收益
- **用户留存**: 观察广告对留存的影响

### AdMob 报告

定期检查 AdMob 控制台的:
- 收益报告
- 性能报告
- 用户指标

---

## 技术支持

- [AdMob iOS 集成指南](https://developers.google.com/admob/ios/quick-start)
- [插页式广告文档](https://developers.google.com/admob/ios/interstitial)
- [AdMob 政策中心](https://support.google.com/admob/answer/6128543)

---

## 版本历史

- **v1.0**: 初始实现
  - 插页式广告集成
  - 每3次会话展示
  - 测试 Ad Unit ID

---

**最后更新**: 2025-10-22

