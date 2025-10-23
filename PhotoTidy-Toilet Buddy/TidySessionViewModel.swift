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
    
    init(asset: PHAsset) {
        self.id = asset.localIdentifier
        self.asset = asset
    }
    
    static func == (lhs: TidyPhoto, rhs: TidyPhoto) -> Bool {
        return lhs.id == rhs.id
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
    
    /// 已删除的照片数量
    @Published var deletedCount: Int = 0
    
    /// 已保留的照片数量
    @Published var keptCount: Int = 0
    
    /// 删除历史记录（用于多次撤销）
    @Published private var deletionHistory: [(asset: PHAsset, index: Int)] = []
    
    /// 最大撤销步数
    private let maxUndoSteps: Int = 10
    
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
    
    /// 是否可以撤销删除
    var canUndo: Bool {
        return !deletionHistory.isEmpty
    }
    
    /// 可撤销的次数
    var undoCount: Int {
        return deletionHistory.count
    }
    
    /// 是否可以向前导航
    var canMovePrevious: Bool {
        return currentIndex > 0
    }
    
    /// 是否可以向后导航
    var canMoveNext: Bool {
        return currentIndex < totalPhotos - 1
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
    
    // 待删除队列（延迟删除策略）
    private var pendingDeletions: [PHAsset] = []
    
    // MARK: - Initialization
    
    init() {
        print("TidySessionViewModel 初始化")
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
        
        // 验证是否有足够的照片
        if availableCount == 0 {
            return (false, "没有符合条件的照片。\n请调整过滤设置或检查相册权限。")
        }
        
        if count > availableCount {
            return (false, "相册中只有 \(availableCount) 张符合条件的照片。\n请减少选择数量或调整过滤条件。")
        }
        
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
                errorMessage = "需要照片库访问权限才能使用此功能。\n\n请前往「设置」>「隐私」>「照片」中授予权限。"
            } else {
                errorMessage = "无法访问照片库，请稍后重试。"
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
            errorMessage = "未找到符合条件的照片。\n请尝试调整过滤设置。"
            isLoading = false
            print("未找到照片")
            return
        }
        
        // 转换为 TidyPhoto
        photosToReview = assets.map { TidyPhoto(asset: $0) }
        currentIndex = 0
        isSessionActive = true
        isLoading = false
        isSessionCompleted = false
        
        print("会话开始成功，共 \(photosToReview.count) 张照片")
    }
    
    /// 删除当前照片并移动到下一张
    /// 注意：使用延迟删除策略，照片会在会话结束时批量删除
    func deleteCurrentPhoto() {
        guard let currentPhoto = currentPhoto else {
            print("没有当前照片可删除")
            return
        }
        
        print("标记删除当前照片，索引: \(currentIndex) (延迟删除)")
        
        // 记录删除历史用于撤销（支持多次撤销）
        let historyItem = (asset: currentPhoto.asset, index: currentIndex)
        deletionHistory.append(historyItem)
        
        // 限制历史记录大小
        if deletionHistory.count > maxUndoSteps {
            deletionHistory.removeFirst()
        }
        
        // 添加到待删除队列（延迟删除策略）
        pendingDeletions.append(currentPhoto.asset)
        
        // 增加删除计数（UI 显示）
        deletedCount += 1
        
        print("已添加到待删除队列，当前队列大小: \(pendingDeletions.count)，历史记录: \(deletionHistory.count)")
        
        // 移动到下一张
        moveToNextPhotoAfterAction()
    }
    
    /// 保留当前照片并移动到下一张
    func keepCurrentPhoto() {
        guard currentPhoto != nil else {
            print("没有当前照片可保留")
            return
        }
        
        print("保留当前照片，索引: \(currentIndex)")
        
        keptCount += 1
        
        // 注意：保留操作不清除删除历史，允许用户撤销之前的删除操作
        
        // 移动到下一张
        moveToNextPhotoAfterAction()
    }
    
    /// 在执行操作后移动到下一张照片
    private func moveToNextPhotoAfterAction() {
        if currentIndex < totalPhotos - 1 {
            // 还有照片未审阅，移动到下一张
            currentIndex += 1
            print("移动到下一张照片，当前索引: \(currentIndex)")
        } else {
            // 所有照片已审阅完毕
            isSessionCompleted = true
            isSessionActive = false
            print("会话完成！删除: \(deletedCount), 保留: \(keptCount)")
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
    
    // MARK: - 撤销操作
    
    /// 撤销最后一次删除操作
    /// 使用延迟删除策略时，可以真正恢复照片（从待删除队列中移除）
    /// 支持多次撤销（最多 maxUndoSteps 次）
    func undoLastDeletion() {
        guard !deletionHistory.isEmpty else {
            print("没有可撤销的删除操作")
            return
        }
        
        // 获取最后一次删除记录
        let lastDeletion = deletionHistory.removeLast()
        
        print("撤销删除操作，恢复照片索引: \(lastDeletion.index)")
        
        // 从待删除队列中移除这张照片
        if let queueIndex = pendingDeletions.firstIndex(where: { $0.localIdentifier == lastDeletion.asset.localIdentifier }) {
            pendingDeletions.remove(at: queueIndex)
            print("已从待删除队列中移除，剩余待删除: \(pendingDeletions.count)")
        }
        
        // 减少删除计数
        if deletedCount > 0 {
            deletedCount -= 1
        }
        
        // 跳回到被删除照片的位置
        jumpToIndex(lastDeletion.index)
        
        print("撤销操作完成，当前索引: \(currentIndex)，剩余可撤销: \(deletionHistory.count)")
    }
    
    // MARK: - 会话管理
    
    /// 重置会话状态
    func resetSession() {
        print("重置会话状态")
        
        photosToReview = []
        currentIndex = 0
        deletedCount = 0
        keptCount = 0
        deletionHistory.removeAll()
        isSessionActive = false
        isSessionCompleted = false
        errorMessage = nil
        pendingDeletions.removeAll()
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
        guard !pendingDeletions.isEmpty else {
            print("没有待删除的照片")
            completion(true)
            return
        }
        
        let totalCount = pendingDeletions.count
        print("开始批量删除 \(totalCount) 张照片...")
        
        // 报告初始进度
        progressHandler?(0, totalCount)
        
        photoService.deleteAssets(
            assets: pendingDeletions,
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
                    self.pendingDeletions.removeAll()
                    completion(true)
                } else {
                    print("批量删除失败: \(error?.localizedDescription ?? "未知错误")")
                    self.errorMessage = "批量删除失败: \(error?.localizedDescription ?? "未知错误")"
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
        print("检查广告显示条件: sessionCounter=\(sessionCounter), adFrequency=\(adFrequency), shouldShow=\(shouldShow)")
        return shouldShow
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
    
    /// 计算待删除照片的估算存储空间
    private func calculateEstimatedStorage() -> Int64 {
        var totalBytes: Int64 = 0
        
        for asset in pendingDeletions {
            // 获取资源信息
            let resources = PHAssetResource.assetResources(for: asset)
            
            for resource in resources {
                if let size = resource.value(forKey: "fileSize") as? Int64 {
                    totalBytes += size
                } else {
                    // 如果无法获取实际大小，使用估算值
                    // 照片平均 3MB，视频平均按时长估算
                    if asset.mediaType == .video {
                        // 视频：按 10MB/分钟估算
                        let minutes = asset.duration / 60.0
                        totalBytes += Int64(minutes * 10 * 1024 * 1024)
                    } else {
                        // 照片：按分辨率估算
                        let pixels = Int64(asset.pixelWidth * asset.pixelHeight)
                        // 假设 1MP ≈ 0.5MB (考虑JPEG压缩)
                        let megapixels = Double(pixels) / 1_000_000.0
                        totalBytes += Int64(megapixels * 0.5 * 1024 * 1024)
                    }
                }
            }
        }
        
        return totalBytes
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

