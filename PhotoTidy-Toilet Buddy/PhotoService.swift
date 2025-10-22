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
    ///   - contentSubtypes: 内容子类型过滤（例如：全景照片、截图等）
    ///   - excludeHidden: 是否排除隐藏的照片
    ///   - excludeFavorite: 是否排除收藏的照片
    /// - Returns: 随机选取的 PHAsset 数组
    func fetchRandomAssets(
        count: Int,
        contentSubtypes: [PHAssetMediaSubtype] = [],
        excludeHidden: Bool = true,
        excludeFavorite: Bool = false
    ) -> [PHAsset] {
        
        // 1. 构造 PHFetchOptions 和 NSPredicate
        let fetchOptions = PHFetchOptions()
        var predicates: [NSPredicate] = []
        
        // 基础过滤：只获取图片和视频
        let mediaTypePredicate = NSPredicate(format: "mediaType == %d OR mediaType == %d",
                                            PHAssetMediaType.image.rawValue,
                                            PHAssetMediaType.video.rawValue)
        predicates.append(mediaTypePredicate)
        
        // 排除隐藏的照片
        if excludeHidden {
            let notHiddenPredicate = NSPredicate(format: "isHidden == NO")
            predicates.append(notHiddenPredicate)
        }
        
        // 排除收藏的照片
        if excludeFavorite {
            let notFavoritePredicate = NSPredicate(format: "isFavorite == NO")
            predicates.append(notFavoritePredicate)
        }
        
        // 内容子类型过滤
        if !contentSubtypes.isEmpty {
            var subtypePredicates: [NSPredicate] = []
            for subtype in contentSubtypes {
                // 使用位掩码匹配子类型
                let subtypePredicate = NSPredicate(format: "(mediaSubtypes & %d) != 0", subtype.rawValue)
                subtypePredicates.append(subtypePredicate)
            }
            // 如果有多个子类型，使用 OR 连接
            if subtypePredicates.count > 1 {
                let combinedSubtypePredicate = NSCompoundPredicate(orPredicateWithSubpredicates: subtypePredicates)
                predicates.append(combinedSubtypePredicate)
            } else if let firstPredicate = subtypePredicates.first {
                predicates.append(firstPredicate)
            }
        }
        
        // 合并所有 predicate
        let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        fetchOptions.predicate = compoundPredicate
        
        // 按创建日期降序排列（可选，用于调试）
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        print("开始获取照片资源，过滤条件：excludeHidden=\(excludeHidden), excludeFavorite=\(excludeFavorite)")
        
        // 2. 获取所有符合条件的资源
        let fetchResult = PHAsset.fetchAssets(with: fetchOptions)
        
        print("找到 \(fetchResult.count) 个符合条件的照片")
        
        // 如果没有资源，直接返回空数组
        guard fetchResult.count > 0 else {
            print("没有找到符合条件的照片")
            return []
        }
        
        // 3. 提取所有 localIdentifier 到数组中
        var allIdentifiers: [String] = []
        var assetMap: [String: PHAsset] = [:]
        
        fetchResult.enumerateObjects { asset, _, _ in
            let identifier = asset.localIdentifier
            allIdentifiers.append(identifier)
            assetMap[identifier] = asset
        }
        
        print("提取了 \(allIdentifiers.count) 个资源 ID")
        
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
    ///   - completion: 删除完成后的回调
    func deleteAssets(assets: [PHAsset], completion: @escaping (Bool, Error?) -> Void) {
        guard !assets.isEmpty else {
            completion(true, nil)
            return
        }
        
        // 缓存所有要删除的资源
        for asset in assets {
            let identifier = asset.localIdentifier
            deletedAssetsCache[identifier] = asset
        }
        
        print("准备批量删除 \(assets.count) 张照片")
        
        PHPhotoLibrary.shared().performChanges {
            // 批量删除
            PHAssetChangeRequest.deleteAssets(assets as NSArray)
            
        } completionHandler: { success, error in
            DispatchQueue.main.async {
                if success {
                    print("批量删除成功，共 \(assets.count) 张照片")
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
        let recentlyDeletedFetchResult = PHAssetCollection.fetchAssetCollections(
            with: .smartAlbum,
            subtype: .smartAlbumRecentlyAdded,
            options: nil
        )
        
        // 注意：iOS 不提供直接访问 "最近删除" 相册的 API
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
}

