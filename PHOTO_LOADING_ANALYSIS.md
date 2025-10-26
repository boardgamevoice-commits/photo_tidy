# 照片加载策略分析

## 当前实现

### 1. 预加载（`loadPhotoAsync`）
```swift
requestOptions.deliveryMode = .highQualityFormat
```
- 直接加载高质量版本
- 无缩略图中间步骤
- 预加载前2张照片

### 2. 前台加载（`loadRegularPhoto`）
```swift
requestOptions.deliveryMode = .opportunistic  // 渐进式加载
```
- 先显示缩略图
- 再加载高质量版本
- 支持 iCloud 照片

### 3. 逻辑流程
```
loadCurrentPhoto() 
  → 检查预加载缓存
    → 有缓存：直接使用（跳过加载）
    → 无缓存：调用 loadRegularPhoto()
      → 使用 opportunistic 模式
        → 先收到缩略图（degraded=true）
        → 再收到高质量版本（degraded=false）
```

## 问题分析

### 如果高质量版本已经存在，是否需要先加载缩略图？

**答案：不需要**

#### 原因
1. **本地照片**：高质量版本在设备上，可直接加载
2. **视觉体验**：缩略图→高质量版本有切换闪烁
3. **性能浪费**：两次加载、两次渲染

#### 何时需要渐进式加载？
- **iCloud 照片**：需要从网络下载
- **大型照片**：解码时间较长
- **优化首屏显示**：先显示预览，再替换为高质量版本

## 优化建议

### 方案1：按资源类型选择策略

```swift
private func loadRegularPhoto(asset: PHAsset) {
    // 检查照片是否在 iCloud
    let isInCloud = asset.mediaType == .image && 
                   !asset.localResources.count >= asset.resources.count
    
    if isInCloud || asset.fileSize > 10_000_000 { // 10MB
        // iCloud 或大文件：使用渐进式加载
        loadPhotoProgressive(...)
    } else {
        // 本地照片：直接加载高质量版本
        loadPhotoDirect(...)
    }
}
```

### 方案2：检查 PHImageResultRequestID

```swift
let options = PHImageRequestOptions()
options.deliveryMode = .opportunistic

let requestID = PHImageManager.default().requestImage(...) { image, info in
    if let degraded = info?[PHImageResultIsDegradedKey] as? Bool {
        if degraded {
            // 缩略图
        } else {
            // 高质量版本
        }
    }
}

// 可以取消请求
PHImageManager.default().cancelImageRequest(requestID)
```

### 方案3：用户偏好设置

```swift
enum PhotoLoadingMode: String {
    case fast      // 快速模式：优先显示缩略图
    case quality   // 质量模式：直接加载高质量版本
    case balanced  // 平衡模式：iCloud用渐进式，本地直接加载
}
```

## 最佳实践

### 当前实现已经很好了

1. **预加载缓存**：前2张照片已预加载高质量版本
2. **渐进式加载**：支持 iCloud 照片的平滑体验
3. **用户体验**：无论照片在哪，都能看到内容

### 可能的优化点

#### 1. 检测本地 vs iCloud
```swift
private func isPhotoLocallyAvailable(_ asset: PHAsset) -> Bool {
    // 检查是否在本地
    return !asset.mediaType.isVideo && asset.localResources.count > 0
}
```

#### 2. 针对本地照片使用 highQualityFormat
```swift
if isPhotoLocallyAvailable(asset) {
    requestOptions.deliveryMode = .highQualityFormat
} else {
    requestOptions.deliveryMode = .opportunistic
}
```

#### 3. 优化首屏显示
- 第一个加载的照片使用 highQualityFormat
- 后续照片使用 opportunistic（如果用户滚动很快）

## 结论

### 当前实现
✅ **正确**：预加载 + 渐进式加载是合理的设计

### 进一步优化
✅ **可选**：根据照片位置（本地/iCloud）选择加载策略
- 本地照片：直接用 highQualityFormat
- iCloud 照片：使用 opportunistic

### 用户体验
- 预加载缓存：几乎无延迟
- 渐进式加载：支持 iCloud 照片
- 视觉体验：稍有闪烁，但能先看到内容

**建议：保持当前实现，这是一个好的权衡。**
