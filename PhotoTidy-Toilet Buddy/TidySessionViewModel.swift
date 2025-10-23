//
//  TidySessionViewModel.swift
//  PhotoTidy-Toilet Buddy
//
//  Created on 2025-10-22.
//

import Foundation
import SwiftUI
import Photos
import PhotosUI
import Combine
import AVFoundation

/// 单张待审阅照片的数据模型
struct TidyPhoto: Identifiable, Equatable {
    let id: String
    let asset: PHAsset
    var isMarkedForDeletion: Bool = false  // 是否标记为删除
    
    init(asset: PHAsset) {
        self.id = asset.localIdentifier
        self.asset = asset
        self.isMarkedForDeletion = false
    }
    
    static func == (lhs: TidyPhoto, rhs: TidyPhoto) -> Bool {
        return lhs.id == rhs.id && lhs.isMarkedForDeletion == rhs.isMarkedForDeletion
    }
}

/// 照片审阅会话的核心状态管理器
@MainActor
class TidySessionViewModel: ObservableObject {
    
    // MARK: - Published Properties (状态属性)
    
    /// 待审阅的照片列表
    @Published var photosToReview: [TidyPhoto] = []
    
    /// 当前正在查看的照片索引
    @Published var currentIndex: Int = 0
    
    /// 会话是否正在进行中
    @Published var isSessionActive: Bool = false
    
    /// 是否正在加载
    @Published var isLoading: Bool = false
    
    /// 错误消息
    @Published var errorMessage: String?
    
    /// 会话是否已完成（所有照片都已审阅）
    @Published var isSessionCompleted: Bool = false
    
    /// 会话计数器（用于控制广告显示频率）
    @Published var sessionCounter: Int = 0
    
    // MARK: - Ad Configuration
    
    /// 广告显示阈值（每完成N次会话显示一次广告）
    private let adFrequency: Int = 3
    
    // MARK: - Computed Properties
    
    /// 当前照片对象
    var currentPhoto: TidyPhoto? {
        guard currentIndex >= 0,
              currentIndex < photosToReview.count,
              !photosToReview.isEmpty else {
            print("⚠️ currentPhoto 访问越界: index=\(currentIndex), count=\(photosToReview.count)")
            return nil
        }
        return photosToReview[currentIndex]
    }
    
    /// 已标记删除的照片数量（基于状态计算）
    var deletedCount: Int {
        return photosToReview.filter { $0.isMarkedForDeletion }.count
    }
    
    /// 已保留的照片数量（基于状态计算）
    var keptCount: Int {
        return photosToReview.count - deletedCount
    }
    
    /// 总照片数量
    var totalPhotos: Int {
        return photosToReview.count
    }
    
    /// 剩余未审阅的照片数量
    var remainingPhotos: Int {
        return totalPhotos - currentIndex
    }
    
    /// 审阅进度（0.0 到 1.0）
    var progress: Double {
        guard totalPhotos > 0 else { return 0 }
        return Double(currentIndex) / Double(totalPhotos)
    }
    
    /// 是否可以向前导航
    var canMovePrevious: Bool {
        return currentIndex > 0
    }
    
    /// 是否可以向后导航
    var canMoveNext: Bool {
        return currentIndex < totalPhotos - 1
    }
    
    /// 待删除照片列表（基于状态计算）
    var pendingDeletions: [PHAsset] {
        return photosToReview.filter { $0.isMarkedForDeletion }.map { $0.asset }
    }
    
    /// 待删除照片数量
    var pendingDeletionCount: Int {
        return pendingDeletions.count
    }
    
    /// 估算的待删除照片占用的存储空间（字节）
    var estimatedStorageToFree: Int64 {
        return calculateEstimatedStorage()
    }
    
    /// 格式化的存储空间字符串
    var formattedStorageToFree: String {
        return formatBytes(estimatedStorageToFree)
    }
    
    // MARK: - Private Properties
    
    private let photoService = PhotoService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        print("TidySessionViewModel 初始化")
        
        // 设置权限状态变化监听
        photoService.setPermissionChangeHandler { [weak self] status in
            Task { @MainActor in
                self?.handlePermissionStatusChange(status)
            }
        }
    }
    
    /// 处理权限状态变化
    private func handlePermissionStatusChange(_ status: PHAuthorizationStatus) {
        print("权限状态变化: \(status.rawValue)")
        
        switch status {
        case .denied, .restricted:
            // 权限被拒绝或受限，停止当前会话
            if isSessionActive {
                errorMessage = L10n.Error.permissionRevoked
                isSessionActive = false
                isLoading = false
            }
        case .authorized, .limited:
            // 权限恢复，可以继续使用
            if errorMessage?.contains("权限") == true {
                errorMessage = nil
            }
        case .notDetermined:
            // 权限未确定，等待用户操作
            break
        @unknown default:
            break
        }
    }
    
    // MARK: - 核心方法
    
    /// 验证会话设置参数
    /// - Parameters:
    ///   - count: 需要审阅的照片数量
    ///   - filterConfig: 过滤配置
    /// - Returns: (isValid, errorMessage)
    func validateSessionParameters(
        count: Int,
        filterConfig: FilterConfiguration
    ) -> (isValid: Bool, errorMessage: String?) {
        
        // 先进行配置验证
        let configValidation = filterConfig.validate()
        if !configValidation.isValid {
            let warningText = configValidation.warnings.joined(separator: "\n")
            return (false, "过滤配置有问题：\n\(warningText)")
        }
        
        // 使用统一的 PredicateBuilder 构建预检查选项
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = PredicateBuilder.buildCombinedPredicate(from: filterConfig)
        
        // 获取所有符合条件的资源
        let allAssets = PHAsset.fetchAssets(with: fetchOptions)
        
        // 自拍需要后置过滤（因为无法通过 predicate 直接查询）
        var availableCount = allAssets.count
        if filterConfig.contentType == .selfies {
            // 自拍需要逐个检查，这里只做粗略估算
            availableCount = Int(Double(availableCount) * 0.3) // 假设 30% 是自拍
        }
        
        print("验证参数：请求 \(count) 张，可用 \(availableCount) 张")
        
        // 验证是否有照片可用
        if availableCount == 0 {
            return (false, "没有符合条件的照片。\n请调整过滤设置或检查相册权限。")
        }
        
        // 如果可用照片数量少于请求数量，不阻止会话开始
        // PhotoService 会自动使用所有可用的照片
        // 在 startNewSession 中会显示友好提示
        
        return (true, nil)
    }
    
    /// 开始新的整理会话
    /// - Parameters:
    ///   - count: 需要审阅的照片数量
    ///   - filterConfig: 过滤配置
    func startNewSession(
        count: Int = 10,
        filterConfig: FilterConfiguration = FilterConfiguration()
    ) async {
        print("开始新会话，请求 \(count) 张照片")
        
        // 重置状态
        resetSession()
        
        isLoading = true
        errorMessage = nil
        
        // 检查权限
        let permissionStatus = await photoService.checkAndRequestPermissions()
        
        guard permissionStatus == .authorized || permissionStatus == .limited else {
            if permissionStatus == .denied || permissionStatus == .restricted {
                errorMessage = L10n.Error.permissionDenied
            } else {
                errorMessage = L10n.Error.photoLibraryUnavailable
            }
            isLoading = false
            print("权限被拒绝: \(permissionStatus.rawValue)")
            return
        }
        
        // 验证参数
        let validation = validateSessionParameters(
            count: count,
            filterConfig: filterConfig
        )
        
        guard validation.isValid else {
            errorMessage = validation.errorMessage
            isLoading = false
            print("参数验证失败: \(validation.errorMessage ?? "")")
            return
        }
        
        // 获取随机照片
        let assets = photoService.fetchRandomAssets(
            count: count,
            filterConfig: filterConfig
        )
        
        guard !assets.isEmpty else {
            errorMessage = L10n.Error.noPhotosFound
            isLoading = false
            print("未找到照片")
            return
        }
        
        // 如果实际获取的照片数量少于请求数量，记录日志（不阻止）
        if assets.count < count {
            print("📌 找到 \(assets.count) 张符合条件的照片，少于请求的 \(count) 张，将使用所有可用照片")
        }
        
        // 转换为 TidyPhoto
        photosToReview = assets.map { TidyPhoto(asset: $0) }
        currentIndex = 0
        isSessionActive = true
        isLoading = false
        isSessionCompleted = false
        
        print("会话开始成功，共 \(photosToReview.count) 张照片")
    }
    
    /// 切换当前照片的删除标记
    /// - 如果未标记删除，则标记并自动前进到下一张
    /// - 如果已标记删除，则取消标记（停留在当前位置）
    func toggleDeletionMark() {
        guard currentIndex >= 0 && currentIndex < photosToReview.count else {
            print("⚠️ toggleDeletionMark: 索引越界")
            return
        }
        
        let wasMarked = photosToReview[currentIndex].isMarkedForDeletion
        
        // 切换删除标记
        photosToReview[currentIndex].isMarkedForDeletion.toggle()
        
        let newState = photosToReview[currentIndex].isMarkedForDeletion
        print("切换删除标记，索引: \(currentIndex), 新状态: \(newState ? "已标记删除" : "未删除")")
        
        // 如果是标记删除（而不是取消删除），自动前进到下一张
        if newState && !wasMarked {
            moveToNextPhotoIfPossible()
        }
    }
    
    /// 移动到下一张照片（如果可能）
    private func moveToNextPhotoIfPossible() {
        if currentIndex < totalPhotos - 1 {
            currentIndex += 1
            print("自动移动到下一张照片，当前索引: \(currentIndex)")
        } else {
            print("已到达最后一张照片")
        }
    }
    
    // MARK: - 手势导航
    
    /// 移动到上一张照片（手势驱动）
    func moveToPreviousPhoto() {
        guard canMovePrevious else {
            print("已经是第一张照片")
            return
        }
        
        currentIndex -= 1
        print("向前导航到索引: \(currentIndex)")
    }
    
    /// 移动到下一张照片（手势驱动）
    func moveToNextPhoto() {
        guard canMoveNext else {
            print("已经是最后一张照片")
            return
        }
        
        currentIndex += 1
        print("向后导航到索引: \(currentIndex)")
    }
    
    /// 跳转到指定索引
    func jumpToIndex(_ index: Int) {
        guard index >= 0 && index < totalPhotos else {
            print("索引越界: \(index)")
            return
        }
        
        currentIndex = index
        print("跳转到索引: \(currentIndex)")
    }
    
    
    // MARK: - 会话管理
    
    /// 重置会话状态
    func resetSession() {
        print("重置会话状态")
        
        photosToReview = []
        currentIndex = 0
        isSessionActive = false
        isSessionCompleted = false
        errorMessage = nil
    }
    
    /// 暂停会话
    func pauseSession() {
        print("暂停会话")
        isSessionActive = false
    }
    
    /// 恢复会话
    func resumeSession() {
        guard !photosToReview.isEmpty else {
            print("没有可恢复的会话")
            return
        }
        
        print("恢复会话")
        isSessionActive = true
        isSessionCompleted = false
    }
    
    /// 结束会话
    /// 注意：此时会批量删除所有待删除的照片（只弹出一次系统确认框）
    func endSession() {
        print("结束会话，删除: \(deletedCount), 保留: \(keptCount)")
        
        // 标记会话已完成（先更新 UI）
        isSessionActive = false
        isSessionCompleted = true
        
        // 增加会话计数器
        sessionCounter += 1
        print("会话计数器更新: \(sessionCounter)")
        
        // 更新统计数据到 SettingsManager
        SettingsManager.shared.updateStatistics(
            reviewedCount: totalPhotos,
            deletedCount: deletedCount,
            freedSpace: estimatedStorageToFree
        )
        
        // 注意：实际删除操作移到 SessionCompleteView 中
        // 这样用户可以在完成总结界面看到统计后再确认删除
        print("待删除队列保留，共 \(pendingDeletions.count) 张照片待删除")
    }
    
    /// 执行待删除照片的批量删除
    /// 此方法应该在用户确认后调用（例如在 SessionCompleteView 中）
    /// - Parameters:
    ///   - progressHandler: 进度回调 (当前进度, 总数)
    ///   - completion: 完成回调
    func executePendingDeletions(
        progressHandler: ((Int, Int) -> Void)? = nil,
        completion: @escaping (Bool) -> Void
    ) {
        let assetsToDelete = pendingDeletions  // 获取快照
        
        guard !assetsToDelete.isEmpty else {
            print("没有待删除的照片")
            completion(true)
            return
        }
        
        let totalCount = assetsToDelete.count
        print("开始批量删除 \(totalCount) 张照片...")
        
        // 报告初始进度
        progressHandler?(0, totalCount)
        
        photoService.deleteAssets(
            assets: assetsToDelete,
            progressHandler: { current, total in
                // 更新进度
                Task { @MainActor in
                    progressHandler?(current, total)
                }
            }
        ) { [weak self] success, error in
            guard let self = self else { return }
            
            Task { @MainActor in
                if success {
                    print("批量删除成功！共 \(totalCount) 张照片")
                    // 清空所有删除标记（删除成功后）
                    for index in 0..<self.photosToReview.count {
                        self.photosToReview[index].isMarkedForDeletion = false
                    }
                    completion(true)
                } else {
                    print("批量删除失败: \(error?.localizedDescription ?? "未知错误")")
                    self.errorMessage = L10n.Error.batchDeleteFailedMessage(error?.localizedDescription ?? L10n.Error.general)
                    completion(false)
                }
            }
        }
    }
    
    /// 检查是否应该显示广告
    /// - Returns: 如果达到广告显示阈值则返回 true
    func shouldShowAd() -> Bool {
        // 1. 检查用户是否处于无广告期间
        if AdFreeManager.shared.isAdFree() {
            if let remainingTime = AdFreeManager.shared.getFormattedRemainingTime() {
                print("✓ 用户处于无广告期间，剩余时间: \(remainingTime)，跳过广告")
            }
            return false
        }
        
        // 2. 检查会话计数器是否达到广告显示阈值
        let shouldShow = sessionCounter % adFrequency == 0 && sessionCounter > 0
        
        // 3. 检查是否已经显示过广告（防止重复显示）
        let lastAdShownKey = "lastAdShownSession"
        let lastShownSession = UserDefaults.standard.integer(forKey: lastAdShownKey)
        
        if shouldShow && sessionCounter > lastShownSession {
            // 记录本次广告显示
            UserDefaults.standard.set(sessionCounter, forKey: lastAdShownKey)
            print("✓ 广告显示条件满足: sessionCounter=\(sessionCounter), adFrequency=\(adFrequency), 记录显示历史")
            return true
        } else if shouldShow {
            print("⚠️ 广告显示条件满足但已显示过: sessionCounter=\(sessionCounter), lastShown=\(lastShownSession)")
            return false
        }
        
        print("检查广告显示条件: sessionCounter=\(sessionCounter), adFrequency=\(adFrequency), shouldShow=\(shouldShow)")
        return false
    }
    
    // MARK: - 辅助方法
    
    /// 获取当前照片的缩略图
    func getCurrentPhotoThumbnail(targetSize: CGSize = CGSize(width: 400, height: 400), completion: @escaping (UIImage?) -> Void) {
        guard let currentPhoto = currentPhoto else {
            completion(nil)
            return
        }
        
        photoService.fetchThumbnail(for: currentPhoto.asset, targetSize: targetSize, completion: completion)
    }
    
    /// 异步获取当前照片的缩略图（支持 Task 取消）
    /// - Parameters:
    ///   - targetSize: 目标尺寸
    ///   - progressHandler: 进度回调 (0.0 到 1.0)
    /// - Returns: UIImage 或 nil
    func loadCurrentPhotoAsync(
        targetSize: CGSize = CGSize(width: 1200, height: 1200),
        progressHandler: ((Double) -> Void)? = nil
    ) async throws -> UIImage? {
        guard let currentPhoto = currentPhoto else {
            print("⚠️ loadCurrentPhotoAsync: 当前照片为空")
            return nil
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            // 报告初始进度
            progressHandler?(0.0)
            
            let requestOptions = PHImageRequestOptions()
            requestOptions.deliveryMode = .highQualityFormat
            requestOptions.isNetworkAccessAllowed = true
            requestOptions.isSynchronous = false
            
            // 监听下载进度（如果照片在 iCloud）
            requestOptions.progressHandler = { progress, error, stop, info in
                Task { @MainActor in
                    progressHandler?(progress)
                }
            }
            
            PHImageManager.default().requestImage(
                for: currentPhoto.asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: requestOptions
            ) { image, info in
                // 报告完成
                progressHandler?(1.0)
                
                if let error = info?[PHImageErrorKey] as? Error {
                    print("⚠️ 图片加载失败: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                    return
                }
                
                if let image = image {
                    continuation.resume(returning: image)
                } else {
                    print("⚠️ 图片加载返回 nil")
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    /// 获取指定索引照片的缩略图
    func getThumbnail(at index: Int, targetSize: CGSize = CGSize(width: 400, height: 400), completion: @escaping (UIImage?) -> Void) {
        guard index >= 0 && index < photosToReview.count else {
            completion(nil)
            return
        }
        
        let photo = photosToReview[index]
        photoService.fetchThumbnail(for: photo.asset, targetSize: targetSize, completion: completion)
    }
    
    /// 异步获取指定索引照片的缩略图（用于预加载）
    func loadPhotoAsync(at index: Int, targetSize: CGSize) async -> UIImage? {
        guard index >= 0 && index < photosToReview.count else {
            return nil
        }
        
        let photo = photosToReview[index]
        
        return await withCheckedContinuation { continuation in
            let requestOptions = PHImageRequestOptions()
            requestOptions.deliveryMode = .highQualityFormat
            requestOptions.isNetworkAccessAllowed = false // 预加载不从 iCloud 下载
            requestOptions.isSynchronous = false
            
            PHImageManager.default().requestImage(
                for: photo.asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: requestOptions
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
    
    /// 异步加载 Live Photo
    /// - Parameters:
    ///   - asset: PHAsset
    ///   - targetSize: 目标尺寸
    ///   - progressHandler: 进度回调
    /// - Returns: PHLivePhoto 或 nil
    func loadLivePhotoAsync(
        asset: PHAsset,
        targetSize: CGSize,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws -> PHLivePhoto? {
        return try await withCheckedThrowingContinuation { continuation in
            progressHandler?(0.0)
            
            let requestOptions = PHLivePhotoRequestOptions()
            requestOptions.deliveryMode = .highQualityFormat
            requestOptions.isNetworkAccessAllowed = true
            
            // 监听下载进度
            requestOptions.progressHandler = { progress, error, stop, info in
                Task { @MainActor in
                    progressHandler?(progress)
                }
            }
            
            PHImageManager.default().requestLivePhoto(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: requestOptions
            ) { livePhoto, info in
                progressHandler?(1.0)
                
                if let error = info?[PHImageErrorKey] as? Error {
                    print("⚠️ Live Photo 加载失败: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                    return
                }
                
                if let livePhoto = livePhoto {
                    print("✅ Live Photo 加载成功")
                    continuation.resume(returning: livePhoto)
                } else {
                    print("⚠️ Live Photo 加载返回 nil")
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    /// 异步加载视频
    /// - Parameter asset: PHAsset
    /// - Returns: AVPlayerItem 或 nil
    func loadVideoAsync(asset: PHAsset) async throws -> AVPlayerItem? {
        return try await withCheckedThrowingContinuation { continuation in
            let requestOptions = PHVideoRequestOptions()
            requestOptions.deliveryMode = .highQualityFormat
            requestOptions.isNetworkAccessAllowed = true
            
            PHImageManager.default().requestPlayerItem(
                forVideo: asset,
                options: requestOptions
            ) { playerItem, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    print("⚠️ 视频加载失败: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                    return
                }
                
                if let playerItem = playerItem {
                    print("✅ 视频加载成功，时长: \(CMTimeGetSeconds(playerItem.duration))s")
                    continuation.resume(returning: playerItem)
                } else {
                    print("⚠️ 视频加载返回 nil")
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    /// 获取当前照片的详细信息
    func getCurrentPhotoInfo() -> String {
        guard let currentPhoto = currentPhoto else {
            return "无照片信息"
        }
        
        return photoService.getAssetInfo(asset: currentPhoto.asset)
    }
    
    /// 获取会话统计信息
    func getSessionStats() -> String {
        return """
        会话统计：
        - 总照片数: \(totalPhotos)
        - 当前进度: \(currentIndex + 1) / \(totalPhotos)
        - 已删除: \(deletedCount)
        - 已保留: \(keptCount)
        - 剩余: \(remainingPhotos)
        """
    }
    
    // MARK: - 存储空间估算
    
    /// 计算待删除照片的实际存储空间
    private func calculateEstimatedStorage() -> Int64 {
        var totalBytes: Int64 = 0
        
        for asset in pendingDeletions {
            // 获取资源信息
            let resources = PHAssetResource.assetResources(for: asset)
            
            var assetSize: Int64 = 0
            var hasActualSize = false
            
            for resource in resources {
                // 优先获取实际文件大小
                if let size = resource.value(forKey: "fileSize") as? Int64, size > 0 {
                    assetSize += size
                    hasActualSize = true
                }
            }
            
            // 如果没有获取到实际大小，使用改进的估算方法
            if !hasActualSize || assetSize == 0 {
                assetSize = estimateAssetSize(asset: asset)
            }
            
            totalBytes += assetSize
        }
        
        return totalBytes
    }
    
    /// 改进的资源大小估算方法
    private func estimateAssetSize(asset: PHAsset) -> Int64 {
        if asset.mediaType == .video {
            return estimateVideoSize(asset: asset)
        } else {
            return estimateImageSize(asset: asset)
        }
    }
    
    /// 视频大小估算
    private func estimateVideoSize(asset: PHAsset) -> Int64 {
        let duration = asset.duration
        let pixels = Int64(asset.pixelWidth * asset.pixelHeight)
        
        // 根据分辨率和时长估算
        let megapixels = Double(pixels) / 1_000_000.0
        
        // 不同分辨率的码率估算 (MB/分钟)
        let bitratePerMinute: Double
        if megapixels <= 1.0 {
            bitratePerMinute = 5.0  // 720p 及以下
        } else if megapixels <= 4.0 {
            bitratePerMinute = 15.0 // 1080p
        } else if megapixels <= 8.0 {
            bitratePerMinute = 30.0 // 4K
        } else {
            bitratePerMinute = 50.0 // 8K 及以上
        }
        
        let minutes = duration / 60.0
        return Int64(minutes * bitratePerMinute * 1024 * 1024)
    }
    
    /// 图片大小估算
    private func estimateImageSize(asset: PHAsset) -> Int64 {
        let pixels = Int64(asset.pixelWidth * asset.pixelHeight)
        let megapixels = Double(pixels) / 1_000_000.0
        
        // 根据图片类型和分辨率估算
        let bytesPerMegapixel: Double
        
        // 检查是否为特殊类型
        let subtypes = asset.mediaSubtypes
        if subtypes.contains(.photoHDR) {
            bytesPerMegapixel = 2.0  // HDR 图片更大
        } else if subtypes.contains(.photoLive) {
            bytesPerMegapixel = 1.5  // Live Photo 包含额外数据
        } else if subtypes.contains(.photoPanorama) {
            bytesPerMegapixel = 1.2  // 全景图通常压缩较好
        } else {
            bytesPerMegapixel = 0.8  // 普通 JPEG
        }
        
        return Int64(megapixels * bytesPerMegapixel * 1024 * 1024)
    }
    
    /// 格式化字节数为可读字符串
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: bytes)
    }
    
    // MARK: - Note: Predicate构建逻辑已移至 PredicateBuilder
    // 所有 predicate 构建方法已被统一的 PredicateBuilder 替代
    // 这样可以消除代码重复，确保逻辑一致性
}

