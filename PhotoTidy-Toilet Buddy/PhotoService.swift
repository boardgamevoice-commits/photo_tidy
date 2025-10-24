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
            AppLogger.shared.info("照片库权限已授予", category: .photo)
            return currentStatus
            
        case .notDetermined:
            AppLogger.shared.info("请求照片库权限...", category: .photo)
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            AppLogger.shared.info("权限请求结果: \(newStatus.rawValue)", category: .photo)
            return newStatus
            
        case .denied, .restricted:
            AppLogger.shared.warning("照片库权限被拒绝或受限", category: .photo)
            return currentStatus
            
        @unknown default:
            AppLogger.shared.warning("未知的权限状态", category: .photo)
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
    
    /// 异步随机选取符合条件的照片资源
    /// - Parameters:
    ///   - count: 需要选取的照片数量
    ///   - filterConfig: 过滤配置
    ///   - progressHandler: 进度回调 (当前进度, 总数)
    /// - Returns: 随机选取的 PHAsset 数组
    func fetchRandomAssetsAsync(
        count: Int,
        filterConfig: FilterConfiguration,
        progressHandler: @escaping (Double) -> Void = { _ in }
    ) async -> [PHAsset] {
        
        return await withCheckedContinuation { continuation in
            Task {
                // 1. 使用 PredicateBuilder 构造 PHFetchOptions
                let fetchOptions = PHFetchOptions()
                
                // 使用统一的 PredicateBuilder
                fetchOptions.predicate = PredicateBuilder.buildCombinedPredicate(from: filterConfig)
                
                // 按创建日期降序排列（可选，用于调试）
                fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                
                // 2. 获取所有符合条件的资源
                let fetchResult = PHAsset.fetchAssets(with: fetchOptions)
                
                AppLogger.shared.info("找到 \(fetchResult.count) 个符合条件的照片", category: .photo)
                
                // 如果没有资源，直接返回空数组
                guard fetchResult.count > 0 else {
                    AppLogger.shared.warning("没有找到符合条件的照片", category: .photo)
                    continuation.resume(returning: [])
                    return
                }
                
                // 3. 使用异步分页处理提取资源
                let assets = await fetchAssetsWithPaginationAsync(
                    from: fetchResult,
                    count: count,
                    filterConfig: filterConfig,
                    progressHandler: progressHandler
                )
                
                continuation.resume(returning: assets)
            }
        }
    }
    
    /// 异步使用分页处理提取资源
    private func fetchAssetsWithPaginationAsync(
        from fetchResult: PHFetchResult<PHAsset>,
        count: Int,
        filterConfig: FilterConfiguration,
        progressHandler: @escaping (Double) -> Void
    ) async -> [PHAsset] {
        
        AppLogger.shared.debug("开始异步提取资源，总数: \(fetchResult.count)", category: .photo)
        
        var allAssets: [PHAsset] = []
        let totalCount = fetchResult.count
        let batchSize = 100
        
        // 分批处理
        for batchIndex in 0..<Int(ceil(Double(totalCount) / Double(batchSize))) {
            let startIndex = batchIndex * batchSize
            let endIndex = min(startIndex + batchSize, totalCount)
            
            AppLogger.shared.debug("异步处理批次 \(batchIndex + 1): 索引 \(startIndex) 到 \(endIndex - 1)", category: .photo)
            
            // 处理当前批次
            for index in startIndex..<endIndex {
                let asset = fetchResult.object(at: index)
                
                
                allAssets.append(asset)
            }
            
            // 更新进度
            let progress = Double(batchIndex + 1) / Double(Int(ceil(Double(totalCount) / Double(batchSize))))
            progressHandler(progress)
            
            // 让出主线程，避免阻塞UI
            await Task.yield()
        }
        
        AppLogger.shared.debug("异步分页处理完成，提取了 \(allAssets.count) 个资源", category: .photo)
        
        // 执行 Fisher-Yates 洗牌算法
        let shuffledAssets = fisherYatesShuffle(array: allAssets)
        
        AppLogger.shared.debug("Fisher-Yates 洗牌完成", category: .photo)
        
        // 取前 N 个
        let selectedCount = min(count, shuffledAssets.count)
        let selectedAssets = Array(shuffledAssets.prefix(selectedCount))
        
        AppLogger.shared.info("选取了 \(selectedAssets.count) 个随机照片", category: .photo)
        
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

