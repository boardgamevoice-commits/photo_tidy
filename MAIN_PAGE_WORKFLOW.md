# 主页进入工作流程详细分析

## 概述
本文档详细描述 Photo Tidy - Toilet Buddy 应用从启动到进入主页的完整工作流程。

---

## 第一阶段：应用启动（PhotoTidyToiletBuddyApp.swift）

### 1.1 App 初始化
```swift
init() {
    // 1. 记录应用启动日志
    AppLogger.shared.info("Photo Tidy App 启动", category: .general)
    
    // 2. 设置应用生命周期监听
    setupAppLifecycleObservers()
    
    // 3. 初始化音频会话管理器
    _ = AudioSessionManager.shared
    
    // 4. 延迟初始化 AdMob SDK (延迟0.1秒，避免阻塞主线程)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        AppLogger.shared.info("开始延迟初始化 AdMob SDK", category: .network)
        AdManager.shared.initializeAdMob()
    }
}
```

### 1.2 工作内容：
- ✅ 启动日志记录
- ✅ 注册生命周期监听器（后台/前台/终止）
- ✅ 初始化 AudioSessionManager（单例，管理视频播放音频会话）
- ✅ 延迟初始化 AdMob SDK（非阻塞式）

### 1.3 应用生命周期监听设置
```swift
private func setupAppLifecycleObservers() {
    // 监听应用进入后台
    NotificationCenter.default.addObserver(
        forName: UIApplication.didEnterBackgroundNotification,
        object: nil,
        queue: .main
    ) { _ in
        AppLogger.shared.info("应用进入后台，清理后台任务和音频会话", category: .general)
        BackgroundTaskManager.shared.cleanupAllTasks()
        AudioSessionManager.shared.deactivateAudioSession()
    }
    
    // 监听应用即将终止
    NotificationCenter.default.addObserver(
        forName: UIApplication.willTerminateNotification,
        object: nil,
        queue: .main
    ) { _ in
        AppLogger.shared.info("应用即将终止，清理后台任务和音频会话", category: .general)
        BackgroundTaskManager.shared.cleanupAllTasks()
        AudioSessionManager.shared.deactivateAudioSession()
    }
}
```

---

## 第二阶段：启动屏幕（SplashScreenView.swift）

### 2.1 启动屏幕显示条件
```swift
var body: some Scene {
    WindowGroup {
        if showSplashScreen {
            SplashScreenView(...) {
                showSplashScreen = false
            }
        } else {
            ContentView()
                .preferredColorScheme(settingsManager.currentColorScheme)
                .environmentObject(settingsManager)
        }
    }
}
```

### 2.2 启动屏幕加载步骤

#### 步骤 1-3：模拟初始化（每次0.8秒）
```swift
private let loadingSteps = [
    "正在初始化...",           // 0
    "正在检查权限...",          // 1
    "正在准备照片库...",        // 2
    "正在初始化服务...",        // 3
    "正在加载界面..."           // 4
]
```

**进度更新：**
- 每步开始：进度 = step / 5
- 进行中：进度 = (step + 0.5) / 5（0.3秒后）
- 步骤完成：进度 = (step + 1) / 5（0.7秒后）

#### 步骤 4：权限检查（真实操作）
```swift
// 执行异步权限检查
let photoService = PhotoService.shared
let permissionStatus = await photoService.checkAndRequestPermissions()
let hasPermission = permissionStatus == .authorized || permissionStatus == .limited

await MainActor.run {
    self.extractionProgress = hasPermission ? 1.0 : 0.0
    self.progress = 4.0 / 5.0  // 80%
    self.extractedAssets = []  // 设置空数组，预提取将在主页进行
}
```

**PhotoService.checkAndRequestPermissions() 执行内容：**
```swift
func checkAndRequestPermissions() async -> PHAuthorizationStatus {
    let currentStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    
    switch currentStatus {
    case .authorized, .limited:
        // 已授权，直接返回
        return currentStatus
        
    case .notDetermined:
        // 未确定，请求权限
        let newStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        return newStatus
        
    case .denied, .restricted:
        // 被拒绝或受限
        return currentStatus
        
    @unknown default:
        return currentStatus
    }
}
```

#### 步骤 5：完成
```swift
// 进度到 100%
await MainActor.run {
    withAnimation(.easeInOut(duration: 0.5)) {
        progress = 1.0
        currentStep = 4
    }
}

// 等待 0.5 秒
try? await Task.sleep(nanoseconds: UInt64(0.5 * 1_000_000_000))

// 隐藏启动屏幕
await MainActor.run {
    isLoading = false
}

// 等待 0.3 秒后调用完成回调
try? await Task.sleep(nanoseconds: UInt64(0.3 * 1_000_000_000))
onComplete()  // showSplashScreen = false
```

### 2.3 启动屏幕总时长
- 步骤 1-3：0.8秒 × 3 = 2.4秒
- 步骤 4：~0.5秒（权限检查）
- 步骤 5：0.5秒 + 0.3秒 = 0.8秒
- **总计：约 3.7秒**

---

## 第三阶段：主界面加载（ContentView.swift）

### 3.1 ContentView 结构
```swift
struct ContentView: View {
    @StateObject private var viewModel = TidySessionViewModel()
    
    var body: some View {
        Group {
            if viewModel.isLoading {
                loadingView  // 加载中视图
            } else if viewModel.isSessionCompleted {
                SessionCompleteView(viewModel: viewModel)
            } else if !viewModel.isSessionActive {
                SessionSetupView(viewModel: viewModel)  // ✅ 主页设置界面
            } else {
                CardReviewView(viewModel: viewModel)  // 会话进行中
            }
        }
        .onReceive(UIApplication.didEnterBackgroundNotification) { _ in
            viewModel.cleanupBackgroundTasks()
        }
    }
}
```

**初始状态：**
- `isSessionActive = false`
- `isSessionCompleted = false`
- **显示 SessionSetupView（主页）**

---

## 第四阶段：主页设置界面（SessionSetupView.swift）

### 4.1 onAppear 执行流程（分层次优化）

#### 第一层：立即执行（0ms）
```swift
.onAppear {
    let startTime = Date()
    
    // 第一层：立即执行的关键操作（UI渲染必需）
    loadUserPreferences()       // 加载用户偏好
    updateAdFreeStatus()        // 更新广告状态
```

**loadUserPreferences()：**
```swift
private func loadUserPreferences() {
    let defaults = UserDefaults.standard
    
    // 加载上一次的照片数量
    if defaults.object(forKey: photoCountKey) != nil {
        photoCount = min(max(defaults.double(forKey: photoCountKey), 10), 100)
    }
    
    // 加载上一次的过滤配置
    if let data = defaults.data(forKey: filterConfigKey),
       let decoded = try? JSONDecoder().decode(FilterConfiguration.self, from: data) {
        filterConfig = decoded
    }
}
```

**updateAdFreeStatus()：**
```swift
private func updateAdFreeStatus() {
    isAdFree = AdFreeManager.shared.isAdFree()
    remainingAdFreeTime = AdFreeManager.shared.getFormattedRemainingTime()
}
```

#### 第二层：延迟 100ms 执行
```swift
DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
    startAdStatusCheck()  // 开始广告状态检查
}
```

**startAdStatusCheck()：**
```swift
private func startAdStatusCheck() {
    // 每10秒检查一次广告和无广告状态
    adCheckTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
        updateAdFreeStatus()
    }
}
```

#### 第三层：延迟 300ms 执行
```swift
DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
    startPreloading()  // 开始预加载照片
}
```

**startPreloading()：**
```swift
private func startPreloading() {
    AppLogger.shared.performance("开始预加载流程")
    
    Task {
        // 在后台线程执行预加载检查
        await performPreloadingCheck()
    }
}

private func performPreloadingCheck() async {
    // 使用异步权限检查
    let status = await PhotoService.shared.checkPermissionStatusAsync()
    guard status == .authorized || status == .limited else {
        AppLogger.shared.debug("权限不足，跳过预加载", category: .photo)
        return
    }
    
    // 回到主线程执行UI相关操作
    await MainActor.run {
        restartPreloading()
    }
}

private func restartPreloading() {
    // 取消之前的防抖任务
    preloadDebounceTask?.cancel()
    
    // 创建新的防抖任务（0.5秒防抖）
    preloadDebounceTask = Task {
        try await Task.sleep(nanoseconds: 500_000_000)
        
        if !Task.isCancelled {
            let currentCount = Int(photoCount)
            let needsPreload = !isPreloadCacheValid || 
                             lastPreloadCount != currentCount || 
                             lastPreloadConfig != filterConfig
            
            if needsPreload {
                AppLogger.shared.info("开始预提取：数量=\(currentCount)", category: .photo)
                
                viewModel.startPreloading(
                    count: currentCount,
                    filterConfig: filterConfig
                )
                
                // 更新缓存状态
                lastPreloadConfig = filterConfig
                lastPreloadCount = currentCount
                isPreloadCacheValid = true
            }
        }
    }
}
```

**viewModel.startPreloading()：**
```swift
func startPreloading(count: Int, filterConfig: FilterConfiguration) {
    cancelPreloading()
    
    preloadTask = Task {
        await performPreloading(count: count, filterConfig: filterConfig)
    }
}

private func performPreloading(count: Int, filterConfig: FilterConfiguration) async {
    isPreloading = true
    preloadProgress = 0.0
    preloadedPhotos = []
    
    do {
        // 1. 获取照片列表
        let assets = try await preloadPhotoSelection(count: count, filterConfig: filterConfig)
        
        // 2. 预加载前两张照片
        let loadedPhotos = await preloadFirstTwoPhotos(
            from: assets,
            progressHandler: { progress in
                Task { @MainActor in
                    self.preloadProgress = progress
                }
            }
        )
        
        // 3. 更新状态
        preloadedPhotos = loadedPhotos
        isPreloading = false
        
    } catch {
        isPreloading = false
        preloadProgress = 0.0
    }
}
```

#### 第四层：延迟 500ms 执行
```swift
DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
    calculateTotalPhotoCount()  // 照片数量计算
}
```

**calculateTotalPhotoCount()：**
```swift
private func calculateTotalPhotoCount() {
    // 取消之前的计算任务
    countCalculationTask?.cancel()
    
    countCalculationTask = Task {
        // 先检查缓存
        let cacheKey = PhotoCountCacheManager.generateCacheKey(from: filterConfig)
        if let cachedCount = PhotoCountCacheManager.shared.getCachedCount(for: cacheKey) {
            await MainActor.run {
                photoCountResult = .success(cachedCount)
                calculationProgress = 1.0
            }
            return
        }
        
        // 检查权限
        let status = await PhotoService.shared.checkPermissionStatusAsync()
        guard status == .authorized || status == .limited else {
            await MainActor.run {
                photoCountResult = .error("权限不足")
            }
            return
        }
        
        // 开始计算
        await MainActor.run {
            photoCountResult = .calculating
            calculationProgress = 0.0
        }
        
        do {
            let count = try await performPhotoCountCalculation(filterConfig: filterConfig)
            if !Task.isCancelled {
                await MainActor.run {
                    photoCountResult = .success(count)
                    calculationProgress = 1.0
                }
            }
        } catch {
            if !Task.isCancelled {
                await MainActor.run {
                    photoCountResult = .error(error.localizedDescription)
                }
            }
        }
    }
}
```

### 4.2 onAppear 总耗时记录
```swift
let duration = Date().timeIntervalSince(startTime)
AppLogger.shared.performance("SessionSetupView onAppear 完成，耗时: \(String(format: "%.3f", duration))秒")
```

---

## 完整时间线

```
时间轴（毫秒）

0ms     应用启动
         ├─ 初始化日志
         ├─ 注册生命周期监听
         ├─ 初始化 AudioSessionManager
         └─ 延迟初始化 AdMob (100ms)

100ms   延迟初始化 AdMob
        └─ AdManager.shared.initializeAdMob()

0-50ms  启动屏幕显示
         ├─ 显示 SplashScreenView
         └─ 开始加载动画

50ms    步骤1：正在初始化... (0%)
150ms   步骤1进度更新 (10%)
850ms   步骤2：正在检查权限... (20%)
1050ms  步骤2进度更新 (30%)
1650ms  步骤3：正在准备照片库... (40%)
1850ms  步骤3进度更新 (50%)
2450ms  步骤4：正在初始化服务... (60%)
        └─ 权限检查（真实操作）
            └─ PhotoService.checkAndRequestPermissions()

2950ms  步骤4完成 (80%)
        └─ extractedAssets = []

3450ms  步骤5：正在加载界面... (100%)

3950ms  启动屏幕隐藏
        └─ onComplete() → showSplashScreen = false

4000ms  ContentView 显示
        └─ 显示 SessionSetupView（主页）

4000ms  SessionSetupView.onAppear (第一层)
        ├─ loadUserPreferences() (0ms)
        └─ updateAdFreeStatus() (0ms)

4100ms  SessionSetupView.onAppear (第二层)
        └─ startAdStatusCheck()

4300ms  SessionSetupView.onAppear (第三层)
        └─ startPreloading()
            └─ performPreloadingCheck()
                ├─ 检查权限
                └─ restartPreloading()
                    └─ 防抖0.5秒 → 最终预加载

4500ms  SessionSetupView.onAppear (第四层)
        └─ calculateTotalPhotoCount()
            ├─ 检查缓存
            └─ 执行照片数量计算

4800ms  预加载开始执行（如果有权限且缓存无效）

5000ms  主页完全就绪
        ├─ 用户偏好已加载
        ├─ 广告状态已更新
        ├─ 照片数量计算进行中/已完成
        └─ 预加载进行中/已完成
```

---

## 关键组件说明

### AudioSessionManager
- **职责**：管理 AVFoundation 音频会话
- **初始化时机**：应用启动时
- **用途**：视频播放时的音频会话管理

### BackgroundTaskManager
- **职责**：管理后台任务
- **用途**：防止应用在后台被系统终止

### PhotoService
- **职责**：处理所有 Photos 框架操作
- **主要功能**：
  - 权限管理
  - 照片获取
  - 照片删除

### TidySessionViewModel
- **职责**：会话状态管理
- **主要功能**：
  - 会话状态控制
  - 照片预加载
  - 删除操作管理

### AdFreeManager
- **职责**：广告状态管理
- **主要功能**：
  - 24小时无广告状态
  - 剩余时间计算

### SettingsManager
- **职责**：应用设置管理
- **主要功能**：
  - 主题设置
  - 统计信息

---

## 性能优化要点

1. **分层加载**：将加载任务分为4层，避免阻塞主线程
2. **防抖机制**：预加载使用0.5秒防抖，避免频繁触发
3. **缓存机制**：照片数量计算结果缓存，避免重复计算
4. **异步操作**：所有耗时操作使用异步执行
5. **延迟初始化**：AdMob SDK 延迟0.1秒初始化
6. **预加载优化**：只预加载前2张照片的数据

---

## 总结

从应用启动到主页完全就绪，总计约 **5秒**：

1. **0-4秒**：启动屏幕显示和权限检查
2. **4秒**：主页视图显示
3. **4-5秒**：后台任务完成（预加载、照片数量计算）

主页进入过程中：
- ✅ 所有关键操作已异步化
- ✅ UI 渲染不阻塞
- ✅ 权限检查已优化
- ✅ 预加载使用防抖和缓存
- ✅ 照片数量计算支持缓存
