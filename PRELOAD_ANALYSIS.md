# 预加载和照片数量计算功能分析

## 问题1：预加载照片的使用情况

### 当前实现

**预加载执行流程：**
1. 主页 `onAppear` 时，延迟300ms后启动预加载
2. 预加载调用 `viewModel.startPreloading(count, filterConfig)`
3. 获取照片列表后，**只预加载前2张照片的数据**
4. 将结果存储在 `viewModel.preloadedPhotos`

**启动会话时的判断：**
```swift
// SessionSetupView.swift - startSession()
private func startSession() {
    Task {
        if viewModel.hasPreloadedPhotos {  // 检查是否有预加载
            // 使用预加载的照片启动会话
            await viewModel.startNewSessionWithPreloadedPhotos()
        } else {
            // 回退到原有逻辑
            await viewModel.startNewSession(
                count: Int(photoCount),
                filterConfig: filterConfig
            )
        }
    }
}
```

**使用预加载启动会话：**
```swift
// TidySessionViewModel.swift
func startNewSessionWithPreloadedPhotos() async {
    // 使用预加载的照片列表
    photosToReview = preloadedPhotos  // ✅ 直接使用预加载的结果
    currentIndex = 0
    isSessionActive = true
}
```

### 结论

✅ **预加载的照片会被使用**，不是被丢弃。

**优点：**
- 启动会话时速度更快（无需重新获取照片列表）
- 前2张照片已预加载数据，减少等待时间

**缺点：**
- 如果用户修改了过滤条件，预加载的结果可能不匹配
- 需要检查 `hasPreloadedPhotos` 状态

---

## 问题2：移除照片数量计算功能

### 需要删除的内容

1. **SessionSetupView.swift**：
   - `PhotoCountResult` 枚举（第13-56行）
   - `photoCountResult` 状态变量（第94行）
   - `calculateTotalPhotoCount()` 方法（第898-962行）
   - `performPhotoCountCalculation()` 方法（第966-1034行）
   - `countWithLocationFilterWithPagination()` 方法（第1036-1067行）
   - `cancelPhotoCountCalculation()` 方法（第1089-1092行）
   - UI中显示总数的代码（第497-524行）

2. **AdvancedFilterView.swift**：
   - `PhotoCountResult` 枚举的引用
   - `combinedFilterCount` 状态变量（第22行）
   - `contentTypeCounts`、`dateRangeCounts`、`durationCounts` 字典（第32-34行）
   - `calculateCombinedFilterCount()` 方法
   - `calculateIndividualCounts()` 方法
   - 所有显示数量的UI代码

3. **相关服务：**
   - `PhotoCountCacheManager.swift`（整个文件）

---

## 修改方案

### 方案1：完全移除预加载（推荐）

**原因：**
- 预加载增加了复杂性
- 如果用户修改过滤条件，预加载结果会失效
- 主页加载已经有防抖机制
- 实际使用中，大部分用户不会立即点击开始

**实施步骤：**
1. 移除 `SessionSetupView` 中的所有预加载代码
2. 移除 `TidySessionViewModel` 中的预加载方法
3. `startSession()` 始终使用 `startNewSession()`

### 方案2：保留预加载但移除照片数量计算

**实施步骤：**
1. 保留预加载功能
2. 移除所有 `PhotoCountResult` 相关代码
3. 移除 UI 中的总数显示
4. 移除 `PhotoCountCacheManager`

---

## 推荐方案：方案1 + 方案2

完全移除预加载和照片数量计算功能，简化代码。
