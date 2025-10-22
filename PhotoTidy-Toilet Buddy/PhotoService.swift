//
//  PhotoService.swift
//  PhotoTidy-Toilet Buddy
//
//  Created on 2025-10-22.
//

import Foundation
import Photos
import UIKit

/// PhotoService 负责处理所有与 Photos 框架相关的操作
class PhotoService: NSObject {
    
    static let shared = PhotoService()
    
    // MARK: - Properties
    
    /// 存储最近删除的资源信息，用于撤销操作
    private var deletedAssetsCache: [String: PHAsset] = [:]
    
    private override init() {
        super.init()
    }
    
    // MARK: - 权限管理
    
    /// 检查并请求照片库访问权限
    /// - Returns: 返回权限状态
    @MainActor
    func checkAndRequestPermissions() async -> PHAuthorizationStatus {
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        
        switch currentStatus {
        case .authorized, .limited:
            print("照片库权限已授予")
            return currentStatus
            
        case .notDetermined:
            print("请求照片库权限...")
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            print("权限请求结果: \(newStatus.rawValue)")
            return newStatus
            
        case .denied, .restricted:
            print("照片库权限被拒绝或受限")
            return currentStatus
            
        @unknown default:
            print("未知的权限状态")
            return currentStatus
        }
    }
    
    /// 检查是否有照片库访问权限
    func hasPhotoLibraryAccess() -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        return status == .authorized || status == .limited
    }
    
    // MARK: - 随机选取照片
    
    /// 随机选取符合条件的照片资源
    /// - Parameters:
    ///   - count: 需要选取的照片数量
    ///   - filterConfig: 过滤配置
    /// - Returns: 随机选取的 PHAsset 数组
    func fetchRandomAssets(
        count: Int,
        filterConfig: FilterConfiguration
    ) -> [PHAsset] {
        
        // 1. 构造 PHFetchOptions 和 NSPredicate（直接从 FilterConfiguration）
        let fetchOptions = PHFetchOptions()
        var predicates: [NSPredicate] = []
        
        print("🔍 开始构建过滤条件：\(filterConfig.summary)")
        
        // ===== 维度 1: 内容类型过滤 =====
        let contentTypePredicates = buildContentTypePredicates(filterConfig.contentType)
        predicates.append(contentsOf: contentTypePredicates)
        
        // ===== 维度 2: 日期范围过滤 =====
        if let datePredicates = buildDateRangePredicates(filterConfig.dateRange) {
            predicates.append(contentsOf: datePredicates)
        }
        
        // ===== 维度 3: 位置信息过滤 =====
        if let locationPredicate = buildLocationPredicate(filterConfig.locationFilter) {
            predicates.append(locationPredicate)
        }
        
        // ===== 维度 4: 视频时长过滤 =====
        if let durationPredicates = buildDurationPredicates(filterConfig.durationFilter) {
            predicates.append(contentsOf: durationPredicates)
        }
        
        // ===== 维度 5: 其他过滤（排除隐藏/收藏）=====
        if filterConfig.excludeHidden {
            let notHiddenPredicate = NSPredicate(format: "isHidden == NO")
            predicates.append(notHiddenPredicate)
            print("  ✓ 排除隐藏")
        }
        
        if filterConfig.excludeFavorite {
            let notFavoritePredicate = NSPredicate(format: "isFavorite == NO")
            predicates.append(notFavoritePredicate)
            print("  ✓ 排除收藏")
        }
        
        // 合并所有 predicate（使用 AND 连接所有维度）
        let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        fetchOptions.predicate = compoundPredicate
        
        // 按创建日期降序排列（可选，用于调试）
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        print("📊 总共应用了 \(predicates.count) 个过滤条件")
        
        // 2. 获取所有符合条件的资源
        let fetchResult = PHAsset.fetchAssets(with: fetchOptions)
        
        print("✅ 找到 \(fetchResult.count) 个符合条件的照片")
        
        // 如果没有资源，直接返回空数组
        guard fetchResult.count > 0 else {
            print("❌ 没有找到符合条件的照片")
            return []
        }
        
        // 3. 提取所有 localIdentifier 到数组中
        var allIdentifiers: [String] = []
        var assetMap: [String: PHAsset] = [:]
        
        // 判断是否需要自拍后置过滤
        let needsSelfieFilter = filterConfig.contentType == .selfies
        
        fetchResult.enumerateObjects { asset, _, _ in
            // 自拍后置过滤
            if needsSelfieFilter {
                if !self.isSelfie(asset: asset) {
                    return // 跳过非自拍照片
                }
            }
            
            let identifier = asset.localIdentifier
            allIdentifiers.append(identifier)
            assetMap[identifier] = asset
        }
        
        print("提取了 \(allIdentifiers.count) 个资源 ID\(needsSelfieFilter ? "（已应用自拍过滤）" : "")")
        
        // 4. 执行 Fisher-Yates 洗牌算法
        let shuffledIdentifiers = fisherYatesShuffle(array: allIdentifiers)
        
        print("Fisher-Yates 洗牌完成")
        
        // 5. 取前 N 个 ID
        let selectedCount = min(count, shuffledIdentifiers.count)
        let selectedIdentifiers = Array(shuffledIdentifiers.prefix(selectedCount))
        
        print("选取了 \(selectedIdentifiers.count) 个随机照片")
        
        // 6. 根据 ID 获取对应的 PHAsset
        let selectedAssets = selectedIdentifiers.compactMap { assetMap[$0] }
        
        return selectedAssets
    }
    
    /// Fisher-Yates 洗牌算法实现（真正的随机洗牌）
    /// - Parameter array: 需要洗牌的数组
    /// - Returns: 洗牌后的数组
    private func fisherYatesShuffle<T>(array: [T]) -> [T] {
        var shuffled = array
        
        // 从后往前遍历
        for i in stride(from: shuffled.count - 1, through: 1, by: -1) {
            // 生成 0 到 i 之间的随机索引
            let j = Int.random(in: 0...i)
            // 交换元素
            if i != j {
                shuffled.swapAt(i, j)
            }
        }
        
        return shuffled
    }
    
    // MARK: - 删除操作
    
    /// 删除指定的照片资源
    /// - Parameters:
    ///   - asset: 要删除的 PHAsset
    ///   - completion: 删除完成后的回调，返回是否成功和错误信息
    func deleteAsset(asset: PHAsset, completion: @escaping (Bool, Error?) -> Void) {
        // 在删除前，缓存资源信息用于可能的恢复操作
        let identifier = asset.localIdentifier
        deletedAssetsCache[identifier] = asset
        
        print("准备删除照片，ID: \(identifier)")
        
        PHPhotoLibrary.shared().performChanges {
            // 执行删除操作
            PHAssetChangeRequest.deleteAssets([asset] as NSArray)
            
        } completionHandler: { success, error in
            DispatchQueue.main.async {
                if success {
                    print("照片删除成功，ID: \(identifier)")
                    completion(true, nil)
                } else {
                    print("照片删除失败，错误: \(error?.localizedDescription ?? "未知错误")")
                    // 删除失败，从缓存中移除
                    self.deletedAssetsCache.removeValue(forKey: identifier)
                    completion(false, error)
                }
            }
        }
    }
    
    /// 批量删除照片资源
    /// - Parameters:
    ///   - assets: 要删除的 PHAsset 数组
    ///   - progressHandler: 进度回调 (当前数量, 总数量)
    ///   - completion: 删除完成后的回调
    func deleteAssets(
        assets: [PHAsset],
        progressHandler: ((Int, Int) -> Void)? = nil,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        guard !assets.isEmpty else {
            completion(true, nil)
            return
        }
        
        // 缓存所有要删除的资源
        for asset in assets {
            let identifier = asset.localIdentifier
            deletedAssetsCache[identifier] = asset
        }
        
        let totalCount = assets.count
        print("准备批量删除 \(totalCount) 张照片")
        
        // 模拟进度（因为 PHPhotoLibrary.performChanges 是原子操作）
        // 在删除前显示进度更新，让用户感觉到进度
        var simulatedProgress = 0
        let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if simulatedProgress < totalCount {
                simulatedProgress += max(1, totalCount / 20) // 分20步完成
                let current = min(simulatedProgress, totalCount - 1)
                progressHandler?(current, totalCount)
            }
        }
        
        PHPhotoLibrary.shared().performChanges {
            // 批量删除
            PHAssetChangeRequest.deleteAssets(assets as NSArray)
            
        } completionHandler: { success, error in
            // 停止进度定时器
            progressTimer.invalidate()
            
            DispatchQueue.main.async {
                if success {
                    print("批量删除成功，共 \(totalCount) 张照片")
                    // 报告完成进度
                    progressHandler?(totalCount, totalCount)
                    completion(true, nil)
                } else {
                    print("批量删除失败，错误: \(error?.localizedDescription ?? "未知错误")")
                    // 删除失败，从缓存中移除
                    for asset in assets {
                        self.deletedAssetsCache.removeValue(forKey: asset.localIdentifier)
                    }
                    completion(false, error)
                }
            }
        }
    }
    
    // MARK: - 数据恢复/撤销
    
    /// 尝试恢复已删除的照片资源
    /// 注意：iOS 的 Photos 框架不支持直接恢复已删除的照片
    /// 这个方法会尝试从 "最近删除" 相册中恢复照片
    /// - Parameters:
    ///   - asset: 要恢复的 PHAsset（已删除的）
    ///   - completion: 恢复完成后的回调
    func restoreAsset(asset: PHAsset, completion: @escaping (Bool, Error?) -> Void) {
        let identifier = asset.localIdentifier
        
        print("尝试恢复照片，ID: \(identifier)")
        
        // 获取 "最近删除" 相册
        // 注意：iOS 不提供直接访问 "最近删除" 相册的 API
        let _ = PHAssetCollection.fetchAssetCollections(
            with: .smartAlbum,
            subtype: .smartAlbumRecentlyAdded,
            options: nil
        )
        
        // 备注：以上代码仅用于演示，实际上 iOS 不提供直接访问 "最近删除" 相册的 API
        // 实际上，PHAssetCollection.Subtype 中没有 .smartAlbumRecentlyDeleted
        // 这是 iOS 系统的限制，第三方 App 无法直接操作 "最近删除" 相册
        
        // 另一种方法：如果照片只是从某个自定义相册中移除，我们可以重新添加回去
        // 但如果照片已经被彻底删除（进入系统的 "最近删除"），则无法通过 API 恢复
        
        print("警告：iOS Photos 框架不支持直接从 '最近删除' 恢复照片")
        print("用户需要手动在照片 App 中从 '最近删除' 相册恢复")
        
        // 返回失败，因为 API 不支持此操作
        let error = NSError(
            domain: "PhotoService",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "iOS 不支持通过 API 恢复已删除的照片。用户需要在照片 App 中手动恢复。"]
        )
        
        DispatchQueue.main.async {
            completion(false, error)
        }
    }
    
    /// 从缓存中获取已删除的资源信息
    /// - Parameter identifier: 资源的 localIdentifier
    /// - Returns: 缓存的 PHAsset，如果不存在则返回 nil
    func getCachedDeletedAsset(identifier: String) -> PHAsset? {
        return deletedAssetsCache[identifier]
    }
    
    /// 清除已删除资源的缓存
    func clearDeletedAssetsCache() {
        deletedAssetsCache.removeAll()
        print("已清除删除缓存")
    }
    
    // MARK: - 辅助方法
    
    /// 获取照片的缩略图
    /// - Parameters:
    ///   - asset: PHAsset
    ///   - targetSize: 目标尺寸
    ///   - completion: 完成回调，返回 UIImage
    func fetchThumbnail(
        for asset: PHAsset,
        targetSize: CGSize = CGSize(width: 300, height: 300),
        completion: @escaping (UIImage?) -> Void
    ) {
        let imageManager = PHImageManager.default()
        let requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = false
        requestOptions.deliveryMode = .highQualityFormat
        requestOptions.isNetworkAccessAllowed = true
        
        imageManager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: requestOptions
        ) { image, info in
            DispatchQueue.main.async {
                completion(image)
            }
        }
    }
    
    /// 获取资源的详细信息
    /// - Parameter asset: PHAsset
    /// - Returns: 格式化的资源信息字符串
    func getAssetInfo(asset: PHAsset) -> String {
        let mediaType = asset.mediaType == .image ? "图片" : "视频"
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        
        var info = """
        类型: \(mediaType)
        创建日期: \(dateFormatter.string(from: asset.creationDate ?? Date()))
        """
        
        if asset.mediaType == .image {
            info += "\n尺寸: \(asset.pixelWidth) x \(asset.pixelHeight)"
        } else if asset.mediaType == .video {
            let duration = Int(asset.duration)
            info += "\n时长: \(duration) 秒"
        }
        
        if asset.isFavorite {
            info += "\n⭐️ 收藏"
        }
        
        return info
    }
    
    /// 获取照片库统计信息
    /// - Returns: 统计信息字典
    func getLibraryStatistics() -> [String: Int] {
        let allPhotosOptions = PHFetchOptions()
        allPhotosOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        let allPhotos = PHAsset.fetchAssets(with: allPhotosOptions)
        
        let allVideosOptions = PHFetchOptions()
        allVideosOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
        let allVideos = PHAsset.fetchAssets(with: allVideosOptions)
        
        let favoritesOptions = PHFetchOptions()
        favoritesOptions.predicate = NSPredicate(format: "isFavorite == YES")
        let favorites = PHAsset.fetchAssets(with: favoritesOptions)
        
        return [
            "totalPhotos": allPhotos.count,
            "totalVideos": allVideos.count,
            "favorites": favorites.count,
            "total": allPhotos.count + allVideos.count
        ]
    }
    
    // MARK: - 私有辅助方法 - Predicate 构建器
    
    /// 构建内容类型过滤 Predicates
    private func buildContentTypePredicates(_ contentType: ContentType) -> [NSPredicate] {
        var predicates: [NSPredicate] = []
        
        switch contentType {
        case .all:
            // 所有媒体：图片和视频
            let mediaTypePredicate = NSPredicate(format: "mediaType == %d OR mediaType == %d",
                                                PHAssetMediaType.image.rawValue,
                                                PHAssetMediaType.video.rawValue)
            predicates.append(mediaTypePredicate)
            print("  ✓ 内容类型：所有媒体")
            
        case .videos, .slowMotionVideos, .timelapseVideos:
            // 视频类型
            let videoPredicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
            predicates.append(videoPredicate)
            
            // 视频子类型
            if contentType == .slowMotionVideos {
                let slowMoPredicate = NSPredicate(format: "(mediaSubtypes & %d) != 0", PHAssetMediaSubtype.videoHighFrameRate.rawValue)
                predicates.append(slowMoPredicate)
                print("  ✓ 内容类型：慢动作视频")
            } else if contentType == .timelapseVideos {
                let timelapsePredicate = NSPredicate(format: "(mediaSubtypes & %d) != 0", PHAssetMediaSubtype.videoTimelapse.rawValue)
                predicates.append(timelapsePredicate)
                print("  ✓ 内容类型：延时摄影")
            } else {
                print("  ✓ 内容类型：所有视频")
            }
            
        case .screenshots:
            let imagePredicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
            let screenshotPredicate = NSPredicate(format: "(mediaSubtypes & %d) != 0", PHAssetMediaSubtype.photoScreenshot.rawValue)
            predicates.append(contentsOf: [imagePredicate, screenshotPredicate])
            print("  ✓ 内容类型：截图")
            
        case .panoramas:
            let imagePredicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
            let panoramaPredicate = NSPredicate(format: "(mediaSubtypes & %d) != 0", PHAssetMediaSubtype.photoPanorama.rawValue)
            predicates.append(contentsOf: [imagePredicate, panoramaPredicate])
            print("  ✓ 内容类型：全景照片")
            
        case .livePhotos:
            let imagePredicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
            let livePredicate = NSPredicate(format: "(mediaSubtypes & %d) != 0", PHAssetMediaSubtype.photoLive.rawValue)
            predicates.append(contentsOf: [imagePredicate, livePredicate])
            print("  ✓ 内容类型：Live Photo")
            
        case .portraits:
            let imagePredicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
            let portraitPredicate = NSPredicate(format: "(mediaSubtypes & %d) != 0", PHAssetMediaSubtype.photoDepthEffect.rawValue)
            predicates.append(contentsOf: [imagePredicate, portraitPredicate])
            print("  ✓ 内容类型：人像模式")
            
        case .hdrPhotos:
            let imagePredicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
            let hdrPredicate = NSPredicate(format: "(mediaSubtypes & %d) != 0", PHAssetMediaSubtype.photoHDR.rawValue)
            predicates.append(contentsOf: [imagePredicate, hdrPredicate])
            print("  ✓ 内容类型：HDR 照片")
            
        case .bursts:
            let imagePredicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
            // 修复：使用 burstIdentifier 而不是 representsBurst，包含所有连拍照片
            let burstPredicate = NSPredicate(format: "burstIdentifier != nil")
            predicates.append(contentsOf: [imagePredicate, burstPredicate])
            print("  ✓ 内容类型：连拍照片（所有连拍）")
            
        case .selfies:
            // 自拍需要图片类型 + 后置过滤
            let imagePredicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
            predicates.append(imagePredicate)
            print("  ✓ 内容类型：自拍（需后置过滤）")
        }
        
        return predicates
    }
    
    /// 构建日期范围过滤 Predicates
    private func buildDateRangePredicates(_ dateRange: DateRangeType?) -> [NSPredicate]? {
        guard let dateRange = dateRange else { return nil }
        
        var predicates: [NSPredicate] = []
        let calendar = Calendar.current
        let now = Date()
        let currentYear = calendar.component(.year, from: now)
        
        switch dateRange {
        case .recent7Days:
            if let startDate = calendar.date(byAdding: .day, value: -7, to: now) {
                let predicate = NSPredicate(format: "creationDate >= %@", startDate as NSDate)
                predicates.append(predicate)
                print("  ✓ 日期范围：最近 7 天")
            }
            
        case .recent30Days:
            if let startDate = calendar.date(byAdding: .day, value: -30, to: now) {
                let predicate = NSPredicate(format: "creationDate >= %@", startDate as NSDate)
                predicates.append(predicate)
                print("  ✓ 日期范围：最近 30 天")
            }
            
        case .thisYear:
            // 修复：明确指定年月日
            if let startOfYear = calendar.date(from: DateComponents(year: currentYear, month: 1, day: 1)) {
                let predicate = NSPredicate(format: "creationDate >= %@", startOfYear as NSDate)
                predicates.append(predicate)
                print("  ✓ 日期范围：今年")
            }
            
        case .lastYear:
            // 修复：使用明确的边界，避免包含今年第一天
            let lastYearStart = calendar.date(from: DateComponents(year: currentYear - 1, month: 1, day: 1))
            let lastYearEnd = calendar.date(from: DateComponents(year: currentYear, month: 1, day: 1))?.addingTimeInterval(-1)
            
            if let start = lastYearStart {
                predicates.append(NSPredicate(format: "creationDate >= %@", start as NSDate))
            }
            if let end = lastYearEnd {
                predicates.append(NSPredicate(format: "creationDate <= %@", end as NSDate))
            }
            print("  ✓ 日期范围：去年")
            
        case .older1Year:
            if let oneYearAgo = calendar.date(byAdding: .year, value: -1, to: now) {
                let predicate = NSPredicate(format: "creationDate < %@", oneYearAgo as NSDate)
                predicates.append(predicate)
                print("  ✓ 日期范围：1 年前")
            }
            
        case .older2Years:
            if let twoYearsAgo = calendar.date(byAdding: .year, value: -2, to: now) {
                let predicate = NSPredicate(format: "creationDate < %@", twoYearsAgo as NSDate)
                predicates.append(predicate)
                print("  ✓ 日期范围：2 年前")
            }
        }
        
        return predicates.isEmpty ? nil : predicates
    }
    
    /// 构建位置信息过滤 Predicate
    private func buildLocationPredicate(_ locationFilter: LocationFilterType?) -> NSPredicate? {
        guard let locationFilter = locationFilter else { return nil }
        
        switch locationFilter {
        case .withLocation:
            print("  ✓ 位置信息：含位置信息")
            return NSPredicate(format: "location != nil")
        case .withoutLocation:
            print("  ✓ 位置信息：无位置信息")
            return NSPredicate(format: "location == nil")
        }
    }
    
    /// 构建视频时长过滤 Predicates
    private func buildDurationPredicates(_ durationFilter: DurationFilterType?) -> [NSPredicate]? {
        guard let durationFilter = durationFilter else { return nil }
        
        var predicates: [NSPredicate] = []
        
        switch durationFilter {
        case .shortVideos:
            let predicate = NSPredicate(format: "duration > 0 AND duration <= %f", 30.0)
            predicates.append(predicate)
            print("  ✓ 视频时长：短视频 (<30秒)")
            
        case .longVideos:
            let predicate = NSPredicate(format: "duration >= %f", 300.0)
            predicates.append(predicate)
            print("  ✓ 视频时长：长视频 (>5分钟)")
        }
        
        return predicates.isEmpty ? nil : predicates
    }
    
    // MARK: - 自拍检测
    
    /// 判断是否为自拍照片
    /// - Parameter asset: PHAsset 对象
    /// - Returns: 如果是自拍则返回 true
    private func isSelfie(asset: PHAsset) -> Bool {
        // 只处理图片类型
        guard asset.mediaType == .image else {
            return false
        }
        
        // 方法1: 检查照片尺寸比例（前置摄像头通常拍摄较小的照片）
        // 注意：这种方法不是100%准确，但可以覆盖大部分情况
        let width = asset.pixelWidth
        let height = asset.pixelHeight
        
        // 前置摄像头拍摄的照片通常分辨率较低
        // iPhone 前置摄像头常见分辨率：
        // - iPhone X 及以后: 7MP (约 3088x2316)
        // - iPhone 8 及之前: 1.2MP (约 960x1280) 到 5MP
        let totalPixels = width * height
        let isLowerResolution = totalPixels < 10_000_000 // 10MP 以下
        
        // 方法2: 检查是否有人脸信息（自拍通常有人脸）
        // 注意：需要照片库有分析权限
        // 这里我们使用启发式规则
        
        // 方法3: 通过元数据判断（最可靠的方法）
        // 获取资源的元数据
        let resources = PHAssetResource.assetResources(for: asset)
        for resource in resources {
            // 检查文件名是否包含 IMG_开头（相机拍摄）
            let filename = resource.originalFilename.uppercased()
            
            // 前置摄像头拍摄的照片文件名模式
            // iOS 通常不会在文件名中标记是否为自拍
            // 但我们可以通过其他特征判断
            
            // 如果是 Live Photo，检查视频资源
            if resource.type == .pairedVideo {
                // Live Photo 的自拍通常也是前置摄像头
                continue
            }
        }
        
        // 综合判断：分辨率 + 宽高比
        // 前置摄像头拍摄的照片通常是竖屏且分辨率较低
        let isPortrait = height > width
        let aspectRatio = Double(max(width, height)) / Double(min(width, height))
        let isPhoneAspect = aspectRatio >= 1.3 && aspectRatio <= 1.8 // 常见手机拍照比例
        
        // 启发式规则：低分辨率 + 竖屏 + 手机比例 = 可能是自拍
        let isSelfieCandidate = isLowerResolution && isPortrait && isPhoneAspect
        
        // 注意：由于 iOS Photos API 限制，无法 100% 准确识别自拍
        // 这里采用保守策略，可能会有误判
        return isSelfieCandidate
    }
}

