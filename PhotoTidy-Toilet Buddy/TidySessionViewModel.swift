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

// MARK: - 错误分类

/// 照片加载错误类型
enum PhotoLoadError: Error, LocalizedError {
    case networkError(Error)
    case permissionError
    case fileCorrupted
    case timeout
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .permissionError:
            return "照片库权限不足"
        case .fileCorrupted:
            return "照片文件损坏"
        case .timeout:
            return "加载超时"
        case .unknown(let error):
            return "未知错误: \(error.localizedDescription)"
        }
    }
    
    /// 判断是否应该重试
    var shouldRetry: Bool {
        switch self {
        case .networkError, .timeout:
            return true
        case .permissionError, .fileCorrupted:
            return false
        case .unknown:
            return true
        }
    }
    
    /// 获取重试延迟时间（秒）
    var retryDelay: TimeInterval {
        switch self {
        case .networkError:
            return 2.0
        case .timeout:
            return 1.0
        case .unknown:
            return 1.5
        default:
            return 0
        }
    }
}

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
    
    // MARK: - Preload Properties (预加载相关属性)
    
    /// 是否正在预加载
    @Published var isPreloading: Bool = false
    
    /// 预加载的照片列表
    @Published var preloadedPhotos: [TidyPhoto] = []
    
    /// 预加载进度 (0.0 到 1.0)
    @Published var preloadProgress: Double = 0.0
    
    // MARK: - Ad Configuration
    
    /// 广告显示阈值（每完成N次会话显示一次广告）
    private let adFrequency: Int = 3
    
    // MARK: - Background Task Management
    
    /// 开始后台任务
    /// - Parameter operation: 会话操作类型
    /// - Returns: 是否成功开始后台任务
    @discardableResult
    private func beginBackgroundTask(for operation: SessionOperation) -> Bool {
        return BackgroundTaskManager.shared.beginSessionOperation(operation)
    }
    
    /// 结束后台任务
    /// - Parameter operation: 会话操作类型
    private func endBackgroundTask(for operation: SessionOperation) {
        BackgroundTaskManager.shared.endSessionOperation(operation)
    }
    
    /// 清理所有后台任务（在应用进入后台或对象销毁时调用）
    func cleanupBackgroundTasks() {
        // 清理所有会话操作相关的后台任务
        for operation in SessionOperation.allCases {
            endBackgroundTask(for: operation)
        }
    }
    
    // MARK: - Computed Properties
    
    /// 当前照片对象
    var currentPhoto: TidyPhoto? {
        guard currentIndex >= 0,
              currentIndex < photosToReview.count,
              !photosToReview.isEmpty else {
            AppLogger.shared.warning("currentPhoto 访问越界: index=\(currentIndex), count=\(photosToReview.count)", category: .ui)
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
    
    // 预加载任务管理
    private var preloadTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    init() {
        AppLogger.shared.info("TidySessionViewModel 初始化", category: .ui)
        
        // 设置权限状态变化监听
        photoService.setPermissionChangeHandler { [weak self] status in
            Task { @MainActor in
                self?.handlePermissionStatusChange(status)
            }
        }
    }
    
    /// 处理权限状态变化
    private func handlePermissionStatusChange(_ status: PHAuthorizationStatus) {
        AppLogger.shared.info("权限状态变化: \(status.rawValue)", category: .photo)
        
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
        
        // 注意：位置信息过滤需要在后台线程中进行以避免主线程阻塞
        
        // 获取所有符合条件的资源
        let allAssets = PHAsset.fetchAssets(with: fetchOptions)
        
        // 获取符合条件的资源数量
        let availableCount = allAssets.count
        
        AppLogger.shared.debug("验证参数：请求 \(count) 张，可用 \(availableCount) 张", category: .photo)
        
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
        AppLogger.shared.info("开始新会话，请求 \(count) 张照片", category: .photo)
        
        // 开始后台任务以保护会话启动过程
        _ = beginBackgroundTask(for: .startSession)
        
        defer {
            // 确保在方法结束时结束后台任务
            endBackgroundTask(for: .startSession)
        }
        
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
            AppLogger.shared.error("权限被拒绝: \(permissionStatus.rawValue)", category: .photo)
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
            AppLogger.shared.error("参数验证失败: \(validation.errorMessage ?? "")", category: .photo)
            return
        }
        
        // 获取随机照片
        let assets = await photoService.fetchRandomAssetsAsync(
            count: count,
            filterConfig: filterConfig
        )
        
        guard !assets.isEmpty else {
            errorMessage = L10n.Error.noPhotosFound
            isLoading = false
            AppLogger.shared.warning("未找到照片", category: .photo)
            return
        }
        
        // 如果实际获取的照片数量少于请求数量，记录日志（不阻止）
        if assets.count < count {
            AppLogger.shared.info("找到 \(assets.count) 张符合条件的照片，少于请求的 \(count) 张，将使用所有可用照片", category: .photo)
        }
        
        // 转换为 TidyPhoto
        photosToReview = assets.map { TidyPhoto(asset: $0) }
        currentIndex = 0
        isSessionActive = true
        isLoading = false
        isSessionCompleted = false
        
        AppLogger.shared.info("会话开始成功，共 \(photosToReview.count) 张照片", category: .photo)
    }
    
    /// 切换当前照片的删除标记
    /// - 如果未标记删除，则标记并自动前进到下一张
    /// - 如果已标记删除，则取消标记（停留在当前位置）
    func toggleDeletionMark() {
        guard currentIndex >= 0 && currentIndex < photosToReview.count else {
            AppLogger.shared.warning("toggleDeletionMark: 索引越界", category: .ui)
            return
        }
        
        let wasMarked = photosToReview[currentIndex].isMarkedForDeletion
        
        // 切换删除标记
        photosToReview[currentIndex].isMarkedForDeletion.toggle()
        
        let newState = photosToReview[currentIndex].isMarkedForDeletion
        AppLogger.shared.debug("切换删除标记，索引: \(currentIndex), 新状态: \(newState ? "已标记删除" : "未删除")", category: .ui)
        
        // 如果是标记删除（而不是取消删除），自动前进到下一张
        if newState && !wasMarked {
            moveToNextPhotoIfPossible()
        }
    }
    
    /// 移动到下一张照片（如果可能）
    private func moveToNextPhotoIfPossible() {
        if currentIndex < totalPhotos - 1 {
            currentIndex += 1
            AppLogger.shared.debug("自动移动到下一张照片，当前索引: \(currentIndex)", category: .ui)
        } else {
            AppLogger.shared.info("已到达最后一张照片", category: .ui)
        }
    }
    
    // MARK: - 手势导航
    
    /// 移动到上一张照片（手势驱动）
    func moveToPreviousPhoto() {
        guard canMovePrevious else {
            AppLogger.shared.debug("已经是第一张照片", category: .ui)
            return
        }
        
        currentIndex -= 1
        AppLogger.shared.debug("向前导航到索引: \(currentIndex)", category: .ui)
    }
    
    /// 移动到下一张照片（手势驱动）
    func moveToNextPhoto() {
        guard canMoveNext else {
            AppLogger.shared.debug("已经是最后一张照片", category: .ui)
            return
        }
        
        currentIndex += 1
        AppLogger.shared.debug("向后导航到索引: \(currentIndex)", category: .ui)
    }
    
    /// 跳转到指定索引
    func jumpToIndex(_ index: Int) {
        guard index >= 0 && index < totalPhotos else {
            AppLogger.shared.warning("索引越界: \(index)", category: .ui)
            return
        }
        
        currentIndex = index
        AppLogger.shared.debug("跳转到索引: \(currentIndex)", category: .ui)
    }
    
    
    // MARK: - 会话管理
    
    /// 重置会话状态
    func resetSession() {
        AppLogger.shared.info("重置会话状态", category: .ui)
        
        photosToReview = []
        currentIndex = 0
        isSessionActive = false
        isSessionCompleted = false
        errorMessage = nil
    }
    
    /// 暂停会话
    func pauseSession() {
        AppLogger.shared.info("暂停会话", category: .ui)
        isSessionActive = false
    }
    
    /// 恢复会话
    func resumeSession() {
        guard !photosToReview.isEmpty else {
            AppLogger.shared.warning("没有可恢复的会话", category: .ui)
            return
        }
        
        AppLogger.shared.info("恢复会话", category: .ui)
        isSessionActive = true
        isSessionCompleted = false
    }
    
    /// 结束会话
    /// 注意：此时会批量删除所有待删除的照片（只弹出一次系统确认框）
    func endSession() {
        AppLogger.shared.info("结束会话，删除: \(deletedCount), 保留: \(keptCount)", category: .ui)
        
        // 标记会话已完成（先更新 UI）
        isSessionActive = false
        isSessionCompleted = true
        
        // 增加会话计数器
        sessionCounter += 1
        AppLogger.shared.debug("会话计数器更新: \(sessionCounter)", category: .ui)
        
        // 更新统计数据到 SettingsManager
        SettingsManager.shared.updateStatistics(
            reviewedCount: totalPhotos,
            deletedCount: deletedCount,
            freedSpace: estimatedStorageToFree
        )
        
        // 注意：实际删除操作移到 SessionCompleteView 中
        // 这样用户可以在完成总结界面看到统计后再确认删除
        AppLogger.shared.info("待删除队列保留，共 \(pendingDeletions.count) 张照片待删除", category: .photo)
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
            AppLogger.shared.info("没有待删除的照片", category: .photo)
            completion(true)
            return
        }
        
        let totalCount = assetsToDelete.count
        AppLogger.shared.info("开始批量删除 \(totalCount) 张照片...", category: .photo)
        
        // 开始后台任务以保护批量删除操作
        _ = beginBackgroundTask(for: .executeDeletions)
        
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
            
            // 结束后台任务
            self.endBackgroundTask(for: .executeDeletions)
            
            Task { @MainActor in
                if success {
                    AppLogger.shared.info("批量删除成功！共 \(totalCount) 张照片", category: .photo)
                    // 清空所有删除标记（删除成功后）
                    for index in 0..<self.photosToReview.count {
                        self.photosToReview[index].isMarkedForDeletion = false
                    }
                    completion(true)
                } else {
                    AppLogger.shared.error("批量删除失败", error: error, category: .photo)
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
                AppLogger.shared.info("用户处于无广告期间，剩余时间: \(remainingTime)，跳过广告", category: .ui)
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
            AppLogger.shared.info("广告显示条件满足: sessionCounter=\(sessionCounter), adFrequency=\(adFrequency), 记录显示历史", category: .ui)
            return true
        } else if shouldShow {
            AppLogger.shared.debug("广告显示条件满足但已显示过: sessionCounter=\(sessionCounter), lastShown=\(lastShownSession)", category: .ui)
            return false
        }
        
        AppLogger.shared.debug("检查广告显示条件: sessionCounter=\(sessionCounter), adFrequency=\(adFrequency), shouldShow=\(shouldShow)", category: .ui)
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
            AppLogger.shared.warning("loadCurrentPhotoAsync: 当前照片为空", category: .photo)
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
                    AppLogger.shared.error("图片加载失败", error: error, category: .photo)
                    continuation.resume(throwing: error)
                    return
                }
                
                if let image = image {
                    continuation.resume(returning: image)
                } else {
                    AppLogger.shared.warning("图片加载返回 nil", category: .photo)
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    /// 渐进式加载照片（支持缩略图到高质量的平滑过渡）
    /// - Parameters:
    ///   - asset: PHAsset
    ///   - targetSize: 目标尺寸
    ///   - onThumbnail: 缩略图加载完成回调
    ///   - onFinal: 最终高质量版本加载完成回调
    func loadPhotoProgressive(
        asset: PHAsset,
        targetSize: CGSize,
        onThumbnail: @escaping (UIImage?) -> Void,
        onFinal: @escaping (UIImage?, Error?) -> Void
    ) {
        let requestOptions = PHImageRequestOptions()
        requestOptions.deliveryMode = .opportunistic  // 支持渐进式加载
        requestOptions.isNetworkAccessAllowed = true
        requestOptions.isSynchronous = false
        
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFit,
            options: requestOptions
        ) { image, info in
            // 检查错误
            if let error = info?[PHImageErrorKey] as? Error {
                AppLogger.shared.error("图片加载失败", error: error, category: .photo)
                onFinal(nil, error)
                return
            }
            
            // 检查是否被取消
            if let cancelled = info?[PHImageCancelledKey] as? Bool, cancelled {
                let error = NSError(domain: "PhotoLoad", code: -1, userInfo: [NSLocalizedDescriptionKey: "加载被取消"])
                onFinal(nil, error)
                return
            }
            
            // 判断是缩略图还是最终高质量版本
            if let degraded = info?[PHImageResultIsDegradedKey] as? Bool, degraded {
                // 缩略图版本
                AppLogger.shared.debug("收到缩略图", category: .photo)
                onThumbnail(image)
            } else {
                // 最终高质量版本
                AppLogger.shared.debug("收到高质量版本", category: .photo)
                onFinal(image, nil)
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
        return await loadPhotoWithRetry(at: index, targetSize: targetSize, maxRetries: 3)
    }
    
    /// 带重试机制的照片加载
    private func loadPhotoWithRetry(at index: Int, targetSize: CGSize, maxRetries: Int) async -> UIImage? {
        guard index >= 0 && index < photosToReview.count else {
            return nil
        }
        
        let photo = photosToReview[index]
        var retryCount = 0
        
        while retryCount <= maxRetries {
            do {
                let image = try await loadSinglePhoto(photo: photo, targetSize: targetSize)
                if let image = image {
                    AppLogger.shared.debug("预加载成功，索引: \(index), 重试次数: \(retryCount)", category: .photo)
                    return image
                } else {
                    // 图片为nil，可能是文件损坏
                    let error = PhotoLoadError.fileCorrupted
                    if error.shouldRetry && retryCount < maxRetries {
                        retryCount += 1
                        AppLogger.shared.warning("预加载返回nil，重试 \(retryCount)/\(maxRetries)", category: .photo)
                        try await Task.sleep(nanoseconds: UInt64(error.retryDelay * 1_000_000_000))
                        continue
                    } else {
                        AppLogger.shared.error("预加载最终失败，索引: \(index)", category: .photo)
                        return nil
                    }
                }
            } catch {
                let photoError = classifyError(error)
                AppLogger.shared.warning("预加载失败: \(photoError.errorDescription ?? "未知错误"), 重试 \(retryCount)/\(maxRetries)", category: .photo)
                
                if photoError.shouldRetry && retryCount < maxRetries {
                    retryCount += 1
                    try? await Task.sleep(nanoseconds: UInt64(photoError.retryDelay * 1_000_000_000))
                    continue
                } else {
                    AppLogger.shared.error("预加载最终失败，索引: \(index): \(photoError.errorDescription ?? "未知错误")", category: .photo)
                    return nil
                }
            }
        }
        
        return nil
    }
    
    /// 单次照片加载
    private func loadSinglePhoto(photo: TidyPhoto, targetSize: CGSize) async throws -> UIImage? {
        return try await withCheckedThrowingContinuation { continuation in
            let requestOptions = PHImageRequestOptions()
            requestOptions.deliveryMode = .highQualityFormat
            requestOptions.isNetworkAccessAllowed = true
            requestOptions.isSynchronous = false
            
               // 注意：PHImageRequestOptions 没有 timeoutInterval 属性
               // 超时通过 PHImageManager 的 requestImage 方法自动处理
            
            // 添加进度监听
            requestOptions.progressHandler = { progress, error, stop, info in
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
                // 检查错误信息
                if let error = info?[PHImageErrorKey] as? Error {
                    let photoError = self.classifyError(error)
                    continuation.resume(throwing: photoError)
                    return
                }
                
                // 检查是否被取消
                if let cancelled = info?[PHImageCancelledKey] as? Bool, cancelled {
                    continuation.resume(throwing: PhotoLoadError.unknown(NSError(domain: "PhotoLoad", code: -1, userInfo: [NSLocalizedDescriptionKey: "加载被取消"])))
                    return
                }
                
                continuation.resume(returning: image)
            }
        }
    }
    
    /// 错误分类
    private func classifyError(_ error: Error) -> PhotoLoadError {
        let nsError = error as NSError
        
        // 网络相关错误
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet,
                 NSURLErrorNetworkConnectionLost,
                 NSURLErrorCannotConnectToHost,
                 NSURLErrorTimedOut:
                return .networkError(error)
            default:
                return .networkError(error)
            }
        }
        
        // Photos框架相关错误
        if nsError.domain == "Photos" {
            switch nsError.code {
            case 1: // PHPhotosErrorUserCancelled
                return .unknown(error)
            case 2: // PHPhotosErrorLibraryVolumeOffline
                return .networkError(error)
            case 3: // PHPhotosErrorRelinquishingLibraryBundleToWriter
                return .unknown(error)
            case 4: // PHPhotosErrorSwitchingSystemPhotoLibrary
                return .permissionError
            default:
                return .unknown(error)
            }
        }
        
        // 权限相关错误
        if nsError.domain == "NSCocoaErrorDomain" && nsError.code == 257 {
            return .permissionError
        }
        
        return .unknown(error)
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
                    AppLogger.shared.error("Live Photo 加载失败", error: error, category: .media)
                    continuation.resume(throwing: error)
                    return
                }
                
                if let livePhoto = livePhoto {
                    AppLogger.shared.info("Live Photo 加载成功", category: .media)
                    continuation.resume(returning: livePhoto)
                } else {
                    AppLogger.shared.warning("Live Photo 加载返回 nil", category: .media)
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
                    AppLogger.shared.error("视频加载失败", error: error, category: .media)
                    continuation.resume(throwing: error)
                    return
                }
                
                if let playerItem = playerItem {
                    AppLogger.shared.info("视频加载成功，时长: \(CMTimeGetSeconds(playerItem.duration))s", category: .media)
                    continuation.resume(returning: playerItem)
                } else {
                    AppLogger.shared.warning("视频加载返回 nil", category: .media)
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
    
    // MARK: - Preload Methods (预加载方法)
    
    /// 预加载照片选择（不启动会话）
    /// - Parameters:
    ///   - count: 需要预加载的照片数量
    ///   - filterConfig: 过滤配置
    /// - Returns: 预加载的照片资源数组
    func preloadPhotoSelection(
        count: Int,
        filterConfig: FilterConfiguration
    ) async throws -> [PHAsset] {
        AppLogger.shared.info("开始预加载照片选择，请求 \(count) 张", category: .photo)
        
        // 检查权限
        let permissionStatus = await photoService.checkAndRequestPermissions()
        guard permissionStatus == .authorized || permissionStatus == .limited else {
            throw PhotoLoadError.permissionError
        }
        
        // 获取照片
        let assets = await photoService.fetchRandomAssetsAsync(
            count: count,
            filterConfig: filterConfig
        )
        
        AppLogger.shared.info("预加载选择完成，获得 \(assets.count) 张照片", category: .photo)
        return assets
    }
    
    /// 预加载照片（获取所有照片，但只预加载前两张的照片数据）
    /// - Parameters:
    ///   - assets: 要预加载的资源数组
    ///   - progressHandler: 进度回调 (0.0 到 1.0)
    /// - Returns: 所有照片数组（前两张已预加载数据）
    func preloadFirstTwoPhotos(
        from assets: [PHAsset],
        progressHandler: ((Double) -> Void)? = nil
    ) async -> [TidyPhoto] {
        let maxPreloadCount = 2
        var allPhotos: [TidyPhoto] = []
        
        AppLogger.shared.info("开始预加载，总共 \(assets.count) 张照片，预加载前 \(maxPreloadCount) 张", category: .photo)
        
        // 创建所有照片对象
        for asset in assets {
            let photo = TidyPhoto(asset: asset)
            allPhotos.append(photo)
        }
        
        // 只预加载前两张照片的数据
        for index in 0..<min(maxPreloadCount, allPhotos.count) {
            // 更新进度
            let progress = Double(index) / Double(maxPreloadCount)
            progressHandler?(progress)
            
            let photo = allPhotos[index]
            
            // 预加载照片数据
            do {
                let image = try await loadSinglePhoto(photo: photo, targetSize: CGSize(width: 1200, height: 1200))
                if image != nil {
                    AppLogger.shared.debug("预加载成功: 索引 \(index)", category: .photo)
                } else {
                    AppLogger.shared.warning("预加载返回nil: 索引 \(index)", category: .photo)
                }
            } catch {
                AppLogger.shared.warning("预加载失败: 索引 \(index), 错误: \(error)", category: .photo)
            }
        }
        
        progressHandler?(1.0)
        AppLogger.shared.info("预加载完成，共 \(allPhotos.count) 张照片（前 \(min(maxPreloadCount, allPhotos.count)) 张已预加载数据）", category: .photo)
        return allPhotos
    }
    
    /// 使用预加载的照片启动会话
    func startNewSessionWithPreloadedPhotos() async {
        AppLogger.shared.info("使用预加载照片启动会话", category: .photo)
        
        // 重置状态
        resetSession()
        
        // 使用预加载的照片列表（应该包含用户选择数量的所有照片）
        photosToReview = preloadedPhotos
        currentIndex = 0
        isSessionActive = true
        isLoading = false
        isSessionCompleted = false
        
        AppLogger.shared.info("会话启动成功，共 \(photosToReview.count) 张照片", category: .photo)
    }
    
    /// 开始预加载流程
    /// - Parameters:
    ///   - count: 照片数量
    ///   - filterConfig: 过滤配置
    func startPreloading(count: Int, filterConfig: FilterConfiguration) {
        // 取消之前的预加载任务
        cancelPreloading()
        
        preloadTask = Task {
            await performPreloading(count: count, filterConfig: filterConfig)
        }
    }
    
    /// 执行预加载流程
    private func performPreloading(count: Int, filterConfig: FilterConfiguration) async {
        isPreloading = true
        preloadProgress = 0.0
        preloadedPhotos = []
        
        do {
            // 1. 获取照片列表
            let assets = try await preloadPhotoSelection(count: count, filterConfig: filterConfig)
            
            // 2. 预加载前两张照片
            let loadedPhotos = await preloadFirstTwoPhotos(
                from: assets,
                progressHandler: { progress in
                    Task { @MainActor in
                        self.preloadProgress = progress
                    }
                }
            )
            
            // 3. 更新状态
            preloadedPhotos = loadedPhotos
            isPreloading = false
            
            AppLogger.shared.info("预加载流程完成，共 \(preloadedPhotos.count) 张照片", category: .photo)
            
        } catch {
            isPreloading = false
            preloadProgress = 0.0
            AppLogger.shared.error("预加载流程失败", error: error, category: .photo)
        }
    }
    
    /// 取消预加载
    func cancelPreloading() {
        preloadTask?.cancel()
        preloadTask = nil
        preloadedPhotos = []
        isPreloading = false
        preloadProgress = 0.0
        AppLogger.shared.debug("取消预加载", category: .photo)
    }
    
    /// 检查是否有预加载的照片可用
    var hasPreloadedPhotos: Bool {
        return !preloadedPhotos.isEmpty
    }
    
    // MARK: - Note: Predicate构建逻辑已移至 PredicateBuilder
    // 所有 predicate 构建方法已被统一的 PredicateBuilder 替代
    // 这样可以消除代码重复，确保逻辑一致性
}

