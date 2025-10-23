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
    
    // Note: deletedAssetsCache 已移除
    // 撤销功能现在通过 TidySessionViewModel 的延迟删除策略实现
    
    // 权限状态变化监听
    private var permissionChangeHandler: ((PHAuthorizationStatus) -> Void)?
    
    private override init() {
        super.init()
        // 注册权限变化监听
        PHPhotoLibrary.shared().register(self)
    }
    
    deinit {
        // 取消注册
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
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
    
    /// 设置权限状态变化监听器
    /// - Parameter handler: 权限状态变化时的回调
    func setPermissionChangeHandler(_ handler: @escaping (PHAuthorizationStatus) -> Void) {
        permissionChangeHandler = handler
    }
    
    /// 移除权限状态变化监听器
    func removePermissionChangeHandler() {
        permissionChangeHandler = nil
    }
    
    /// 获取当前权限状态的详细描述
    func getPermissionStatusDescription() -> String {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        
        switch status {
        case .authorized:
            return "permission.status_authorized".localized
        case .limited:
            return "permission.status_limited".localized
        case .denied:
            return "permission.status_denied".localized
        case .restricted:
            return "permission.status_restricted".localized
        case .notDetermined:
            return "permission.status_not_determined".localized
        @unknown default:
            return "permission.status_unknown".localized
        }
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
        
        // 1. 使用 PredicateBuilder 构造 PHFetchOptions
        let fetchOptions = PHFetchOptions()
        
        // 使用统一的 PredicateBuilder
        fetchOptions.predicate = PredicateBuilder.buildCombinedPredicate(from: filterConfig)
        
        // 按创建日期降序排列（可选，用于调试）
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
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
        let identifier = asset.localIdentifier
        
        AppLogger.shared.photo("准备删除照片，ID: \(identifier)")
        
        PHPhotoLibrary.shared().performChanges {
            // 执行删除操作
            PHAssetChangeRequest.deleteAssets([asset] as NSArray)
            
        } completionHandler: { success, error in
            DispatchQueue.main.async {
                if success {
                    AppLogger.shared.photo("照片删除成功，ID: \(identifier)")
                    completion(true, nil)
                } else {
                    AppLogger.shared.error("照片删除失败", error: error, category: .photo)
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
        
        let totalCount = assets.count
        AppLogger.shared.photo("准备批量删除 \(totalCount) 张照片")
        
        // 报告初始进度
        progressHandler?(0, totalCount)
        
        // 对于大量照片，使用分批删除策略
        if totalCount > 50 {
            deleteAssetsInBatches(
                assets: assets,
                batchSize: 20,
                progressHandler: progressHandler,
                completion: completion
            )
        } else {
            // 少量照片直接删除
            deleteAssetsDirectly(
                assets: assets,
                progressHandler: progressHandler,
                completion: completion
            )
        }
    }
    
    /// 分批删除照片（用于大量照片）
    private func deleteAssetsInBatches(
        assets: [PHAsset],
        batchSize: Int,
        progressHandler: ((Int, Int) -> Void)?,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        let totalCount = assets.count
        var completedCount = 0
        var hasError = false
        
        func deleteNextBatch() {
            let startIndex = completedCount
            let endIndex = min(startIndex + batchSize, totalCount)
            let batch = Array(assets[startIndex..<endIndex])
            
            AppLogger.shared.photo("删除批次 \(startIndex/batchSize + 1): \(batch.count) 张照片")
            
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(batch as NSArray)
            } completionHandler: { success, error in
                DispatchQueue.main.async {
                    if success {
                        completedCount += batch.count
                        progressHandler?(completedCount, totalCount)
                        
                        if completedCount < totalCount {
                            // 继续下一批
                            deleteNextBatch()
                        } else {
                            // 全部完成
                            AppLogger.shared.photo("分批删除完成，共 \(totalCount) 张照片")
                            completion(true, nil)
                        }
                    } else {
                        AppLogger.shared.error("批次删除失败", error: error, category: .photo)
                        hasError = true
                        completion(false, error)
                    }
                }
            }
        }
        
        deleteNextBatch()
    }
    
    /// 直接删除照片（用于少量照片）
    private func deleteAssetsDirectly(
        assets: [PHAsset],
        progressHandler: ((Int, Int) -> Void)?,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        let totalCount = assets.count
        
        // 显示"正在删除..."状态
        progressHandler?(0, totalCount)
        
        // 短暂延迟以显示进度
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            progressHandler?(totalCount / 2, totalCount)
        }
        
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets as NSArray)
        } completionHandler: { success, error in
            DispatchQueue.main.async {
                if success {
                    AppLogger.shared.photo("直接删除成功，共 \(totalCount) 张照片")
                    progressHandler?(totalCount, totalCount)
                    completion(true, nil)
                } else {
                    AppLogger.shared.error("直接删除失败", error: error, category: .photo)
                    completion(false, error)
                }
            }
        }
    }
    
    // MARK: - Note: 照片恢复功能已移除
    // iOS Photos 框架不支持直接恢复已删除的照片
    // 用户需要在系统照片 App 的"最近删除"相册中手动恢复
    // 
    // 撤销功能通过延迟删除策略实现：
    // - 照片标记为删除但暂不执行
    // - 会话结束前可以撤销
    // - 会话结束后才批量删除
    
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

// MARK: - PHPhotoLibraryChangeObserver

extension PhotoService: PHPhotoLibraryChangeObserver {
    
    /// 照片库发生变化时的回调
    /// - Parameter changeInstance: 变化实例
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        // 检查权限状态是否发生变化
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        
        DispatchQueue.main.async { [weak self] in
            self?.permissionChangeHandler?(currentStatus)
        }
        
        AppLogger.shared.photo("照片库权限状态变化: \(currentStatus.rawValue)")
    }
}

