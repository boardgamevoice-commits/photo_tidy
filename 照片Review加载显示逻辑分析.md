
# 照片 Review 加载显示逻辑分析

## 重要发现：iCloud 照片加载问题

### 问题描述

经过详细检查，**发现当前实现存在一个严重的用户体验问题**：

**当照片存储在 iCloud 且未完全下载时，用户会看到长时间的 Loading 动画，而不是先显示缩略图。**

### 根本原因

代码中所有照片加载都使用了 `deliveryMode = .highQualityFormat`：

```swift
// TidySessionViewModel.swift: 635
let requestOptions = PHImageRequestOptions()
requestOptions.deliveryMode = .highQualityFormat  // ❌ 问题所在
requestOptions.isNetworkAccessAllowed = true
requestOptions.isSynchronous = false
```

### deliveryMode 三种模式对比

| 模式 | 行为 | 适用场景 | 当前使用 |
|------|------|---------|---------|
| `.opportunistic` | 先用可用资源（缩略图/部分数据），后续升级到高质量 | **列表视图、预览** | ❌ 未使用 |
| `.fastFormat` | 尽可能快返回低质量图片，不升级 | 快速预览 | ❌ 未使用 |
| `.highQualityFormat` | 等待高质量完全加载才返回 | 详情查看、编辑 | ✅ **全部使用** |

### 问题影响

当用户查看 iCloud 照片时：

1. **没有缩略图先显示** - 用户只能看到 Loading
2. **长时间等待** - 必须等待完整照片从 iCloud 下载
3. **糟糕体验** - 如果网络慢，体验非常差

### 现有代码中的不一致

令人意外的是，`ReviewDeletionsView.swift` 中**已经正确使用了** `.opportunistic`：

```swift
// ReviewDeletionsView.swift: 266
let options = PHImageRequestOptions()
options.deliveryMode = .opportunistic  // ✅ 正确
options.isNetworkAccessAllowed = true
```

**这说明项目已经知道正确做法，但在 CardReviewView 中没有应用！**

### 解决方案

#### 方案 1：使用 `.opportunistic`（推荐）

在 `CardReviewView` 的加载方法中改为 `.opportunistic`：

```swift
// TidySessionViewModel.swift
private func loadSinglePhoto(photo: TidyPhoto, targetSize: CGSize) async throws -> UIImage? {
    return try await withCheckedThrowingContinuation { continuation in
        let requestOptions = PHImageRequestOptions()
        requestOptions.deliveryMode = .opportunistic  // ✅ 改为 opportunistic
        requestOptions.isNetworkAccessAllowed = true
        requestOptions.isSynchronous = false
        
        requestOptions.progressHandler = { progress, error, stop, info in
            // ✅ opportunistic 模式会触发多次回调：
            // 第一次：低质量可用时（立即）
            // 后续：高质量下载进度更新
            if let error = error {
                AppLogger.shared.debug("加载进度中发生错误: \(error.localizedDescription)", category: .photo)
            }
        }
        
        PHImageManager.default().requestImage(
            for: photo.asset,
            targetSize: targetSize,
            contentMode: .aspectFit,
            options: requestOptions
        ) { image, info in
            // ✅ 在 opportunistic 模式下，这个回调会被调用多次：
            // 第1次：image 可能是低质量缩略图
            // 第2次：image 是高质量版本
            
            if let degraded = info?[PHImageResultIsDegradedKey] as? Bool {
                if degraded {
                    // ✅ 这是降级版本（缩略图），可以立即显示
                    AppLogger.shared.debug("收到降级图片（缩略图），先显示", category: .photo)
                    continuation.resume(returning: image)
                } else {
                    // ✅ 这是高质量版本，更新显示
                    AppLogger.shared.debug("收到高质量图片", category: .photo)
                    continuation.resume(returning: image)
                }
            } else {
                // 兼容处理：如果没有 degraded 信息，直接返回
                continuation.resume(returning: image)
            }
        }
    }
}
```

**关键点**：
- `.opportunistic` 会**立即**返回低质量缩略图（如果可用）
- 然后**异步升级**到高质量版本
- 通过 `PHImageResultIsDegradedKey` 可以判断是低质量还是高质量

#### 方案 2：两阶段加载（更复杂但更精细）

```swift
// 阶段1：快速加载低质量缩略图
func loadThumbnailFast(asset: PHAsset) async -> UIImage? {
    // 使用 .fastFormat 或 .opportunistic
}

// 阶段2：加载高质量版本
func loadHighQuality(asset: PHAsset) async -> UIImage? {
    // 使用 .highQualityFormat
}
```

### 修改位置清单

需要修改以下文件中的加载方法：

1. **TidySessionViewModel.swift**
   - `loadCurrentPhotoAsync()` (line 635)
   - `loadSinglePhoto()` (line 737)
   - `loadLivePhotoAsync()` (line 831)
   - 可能有其他加载方法

2. **PhotoService.swift**
   - `fetchThumbnail()` (line 459)

3. **CardReviewView.swift**
   - 分享相关的加载方法 (lines 281, 302, 322)

### 预期改进效果

修改后的用户体验：

```
iCloud 照片加载场景：

当前（.highQualityFormat）：
Loading... (5-10秒) → 完整照片

修改后（.opportunistic）：
缩略图 (0.5秒) → Loading... → 完整照片
         ↑                    ↑
      立即显示            背景升级
```

### 注意事项

1. **多次回调处理**：`.opportunistic` 会多次调用完成回调，需要正确处理
2. **UI 更新**：第一次回调时就要更新 UI 显示缩略图
3. **动画优化**：可以在缩略图和高质量之间添加淡入动画
4. **预加载影响**：预加载逻辑也需要同样的修改

### 测试建议

修改后需要测试以下场景：

1. ✅ 本地照片：快速显示（不受影响）
2. ✅ iCloud 照片（已缓存）：快速显示
3. ✅ iCloud 照片（未下载）：先显示缩略图，然后升级
4. ✅ 网络慢的情况：至少能看到缩略图
5. ✅ 切换到下一张时：预加载的缩略图应该已经加载好

### 总结

这是当前实现中最影响用户体验的问题之一。建议**立即修复**，因为：

1. **问题明确**：代码中已经在 `ReviewDeletionsView` 中使用了正确做法
2. **影响面广**：影响所有 iCloud 照片用户
3. **修复简单**：主要是改一行配置
4. **收益明显**：用户体验显著提升
