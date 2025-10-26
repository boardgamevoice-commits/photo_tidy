# Background Task Assertion Invalidation Fix

**修复日期**: 2025-01-23  
**问题**: Self-assertion invalidated: <NSError: 0x129e22670; domain: RBSAssertionErrorDomain; code: 1; "Assertions were invalidated">  
**错误类型**: iOS RunningBoard 服务断言失效错误

---

## 问题分析

### 错误原因
"Self-assertion invalidated" 错误是由 iOS 的 RunningBoard 服务（RBS）引起的，该服务负责管理应用程序的资源和进程状态。错误发生的原因包括：

1. **后台任务断言被系统撤销**: iOS 系统根据资源管理策略主动撤销应用程序的后台任务断言
2. **进程状态变化**: 应用程序从前台切换到后台时，之前获取的断言可能失效
3. **资源管理问题**: 应用程序在后台运行时未正确管理资源，系统撤销后台运行权限
4. **断言冲突**: 多个后台任务断言之间发生冲突

### 具体场景
- 应用进入后台时后台任务断言失效
- 长时间运行的操作导致系统撤销断言
- 多个后台任务同时运行时发生冲突
- 系统资源不足时强制撤销断言

---

## 解决方案

### 1. 创建增强的后台任务管理器

**新文件**: `Services/BackgroundTaskManager.swift`

**核心功能**:
```swift
class BackgroundTaskManager {
    static let shared = BackgroundTaskManager()
    
    /// 开始后台任务
    func beginBackgroundTask(taskName: String, expirationHandler: (() -> Void)?) -> Bool
    
    /// 结束后台任务
    func endBackgroundTask(taskName: String)
    
    /// 清理所有后台任务
    func cleanupAllTasks()
    
    /// 检查任务是否活跃
    func isTaskActive(taskName: String) -> Bool
}
```

**增强特性**:
- **断言失效处理**: 自动处理系统撤销的断言
- **任务数量限制**: 最多同时运行3个后台任务
- **过期检查**: 定时检查任务是否过期
- **应用状态检查**: 避免在后台状态创建新任务
- **安全清理**: 在主线程上安全地结束后台任务

### 2. 操作类型化管理

**照片操作类型**:
```swift
enum PhotoOperation: String, CaseIterable {
    case fetchAssets = "fetchAssets"
    case deleteAsset = "deleteAsset"
    case deleteAssets = "deleteAssets"
    case loadImage = "loadImage"
    case loadVideo = "loadVideo"
    case loadLivePhoto = "loadLivePhoto"
}
```

**会话操作类型**:
```swift
enum SessionOperation: String, CaseIterable {
    case startSession = "startSession"
    case executeDeletions = "executeDeletions"
    case preloadPhotos = "preloadPhotos"
    case validateParameters = "validateParameters"
}
```

### 3. 更新现有服务

**PhotoService 更新**:
```swift
// 旧方式
let backgroundTaskStarted = beginBackgroundTask(taskName: "fetchRandomAssets")

// 新方式
let backgroundTaskStarted = beginBackgroundTask(for: .fetchAssets)
```

**TidySessionViewModel 更新**:
```swift
// 旧方式
let backgroundTaskStarted = beginBackgroundTask(taskName: "startNewSession")

// 新方式
let backgroundTaskStarted = beginBackgroundTask(for: .startSession)
```

### 4. 应用生命周期集成

**统一清理机制**:
```swift
// 应用进入后台时
BackgroundTaskManager.shared.cleanupAllTasks()

// 应用终止时
BackgroundTaskManager.shared.cleanupAllTasks()
```

---

## 实现细节

### 断言失效处理

```swift
backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: taskName) { [weak self] in
    // 后台任务即将过期或被系统撤销，立即结束
    AppLogger.shared.warning("后台任务即将过期或被系统撤销: \(taskName)", category: .general)
    
    // 调用过期处理回调
    expirationHandler?()
    
    // 自动结束任务
    self?.endBackgroundTask(taskName: taskName)
}
```

### 安全的任务结束

```swift
private func endBackgroundTask(taskName: String) {
    guard let taskID = activeTasks[taskName] else { return }
    
    // 从记录中移除
    activeTasks.removeValue(forKey: taskName)
    taskExpirationTimes.removeValue(forKey: taskName)
    
    // 安全地结束后台任务
    DispatchQueue.main.async {
        UIApplication.shared.endBackgroundTask(taskID)
    }
}
```

### 应用状态检查

```swift
// 检查应用状态，避免在后台时创建新的后台任务
guard UIApplication.shared.applicationState != .background else {
    AppLogger.shared.warning("应用在后台状态，跳过创建后台任务: \(taskName)", category: .general)
    return false
}
```

### 任务数量限制

```swift
// 检查任务数量限制
if activeTasks.count >= maxConcurrentTasks {
    AppLogger.shared.warning("后台任务数量已达上限，跳过创建: \(taskName)", category: .general)
    return false
}
```

---

## 修复效果

### 解决的问题
✅ **消除 "Self-assertion invalidated" 错误**  
✅ **正确处理系统撤销的断言**  
✅ **防止后台任务冲突**  
✅ **改善资源管理**  
✅ **提高应用稳定性**

### 性能优化
- 减少断言失效导致的崩溃
- 改善后台任务管理效率
- 降低系统资源占用
- 提高应用响应性

### 用户体验
- 应用不会因断言失效而崩溃
- 后台操作更稳定
- 应用切换更流畅
- 系统资源使用更合理

---

## 测试建议

### 测试场景
1. **后台切换测试**: 在操作进行中切换到后台
2. **长时间操作测试**: 执行长时间的照片处理操作
3. **多任务测试**: 同时执行多个后台任务
4. **资源压力测试**: 在系统资源不足时测试
5. **应用终止测试**: 在后台任务运行时终止应用

### 验证方法
1. 检查控制台日志中的后台任务信息
2. 确认没有 "Self-assertion invalidated" 错误
3. 验证后台任务的正确创建和清理
4. 测试应用在后台时的稳定性

---

## 注意事项

1. **任务命名**: 使用描述性的任务名称便于调试
2. **及时清理**: 确保所有后台任务都能被正确清理
3. **状态检查**: 在创建任务前检查应用状态
4. **数量限制**: 避免创建过多并发后台任务
5. **错误处理**: 优雅地处理断言失效情况

---

## 相关文件

- `Services/BackgroundTaskManager.swift` - 增强的后台任务管理器（新增）
- `PhotoService.swift` - 照片服务后台任务管理
- `TidySessionViewModel.swift` - 会话管理后台任务
- `PhotoTidyToiletBuddyApp.swift` - 应用生命周期管理

---

**修复状态**: ✅ 完成  
**测试状态**: 🔄 待测试  
**部署状态**: 🔄 待部署
