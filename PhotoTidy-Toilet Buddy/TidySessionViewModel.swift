//
//  TidySessionViewModel.swift
//  PhotoTidy-Toilet Buddy
//
//  Created on 2025-10-22.
//

import Foundation
import SwiftUI
import Photos
import Combine

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
    
    /// 最后一张被删除的照片资源（用于撤销）
    @Published var lastDeletedAsset: PHAsset?
    
    /// 最后一张被删除照片的索引（用于撤销后恢复位置）
    @Published private var lastDeletedIndex: Int?
    
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
        guard currentIndex >= 0 && currentIndex < photosToReview.count else {
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
        return lastDeletedAsset != nil
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
    
    /// 开始新的整理会话
    /// - Parameters:
    ///   - count: 需要审阅的照片数量
    ///   - contentSubtypes: 内容子类型过滤
    ///   - excludeHidden: 是否排除隐藏照片
    ///   - excludeFavorite: 是否排除收藏照片
    func startNewSession(
        count: Int = 10,
        contentSubtypes: [PHAssetMediaSubtype] = [],
        excludeHidden: Bool = true,
        excludeFavorite: Bool = false
    ) async {
        print("开始新会话，请求 \(count) 张照片")
        
        // 重置状态
        resetSession()
        
        isLoading = true
        errorMessage = nil
        
        // 检查权限
        let permissionStatus = await photoService.checkAndRequestPermissions()
        
        guard permissionStatus == .authorized || permissionStatus == .limited else {
            errorMessage = "需要照片库访问权限才能继续"
            isLoading = false
            print("权限被拒绝: \(permissionStatus.rawValue)")
            return
        }
        
        // 获取随机照片
        let assets = photoService.fetchRandomAssets(
            count: count,
            contentSubtypes: contentSubtypes,
            excludeHidden: excludeHidden,
            excludeFavorite: excludeFavorite
        )
        
        guard !assets.isEmpty else {
            errorMessage = "未找到符合条件的照片"
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
        
        // 记录删除信息用于撤销
        lastDeletedAsset = currentPhoto.asset
        lastDeletedIndex = currentIndex
        
        // 添加到待删除队列（延迟删除策略）
        pendingDeletions.append(currentPhoto.asset)
        
        // 增加删除计数（UI 显示）
        deletedCount += 1
        
        print("已添加到待删除队列，当前队列大小: \(pendingDeletions.count)")
        
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
        
        // 清除撤销信息（因为用户主动选择保留）
        lastDeletedAsset = nil
        lastDeletedIndex = nil
        
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
        
        // 清除撤销信息（导航时重置）
        lastDeletedAsset = nil
        lastDeletedIndex = nil
    }
    
    /// 移动到下一张照片（手势驱动）
    func moveToNextPhoto() {
        guard canMoveNext else {
            print("已经是最后一张照片")
            return
        }
        
        currentIndex += 1
        print("向后导航到索引: \(currentIndex)")
        
        // 清除撤销信息（导航时重置）
        lastDeletedAsset = nil
        lastDeletedIndex = nil
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
    func undoLastDeletion() {
        guard let deletedAsset = lastDeletedAsset,
              let deletedIndex = lastDeletedIndex else {
            print("没有可撤销的删除操作")
            return
        }
        
        print("撤销删除操作，恢复照片索引: \(deletedIndex)")
        
        // 从待删除队列中移除这张照片
        if let queueIndex = pendingDeletions.firstIndex(where: { $0.localIdentifier == deletedAsset.localIdentifier }) {
            pendingDeletions.remove(at: queueIndex)
            print("已从待删除队列中移除，剩余待删除: \(pendingDeletions.count)")
        }
        
        // 减少删除计数
        if deletedCount > 0 {
            deletedCount -= 1
        }
        
        // 跳回到被删除照片的位置
        jumpToIndex(deletedIndex)
        
        // 清除撤销信息
        lastDeletedAsset = nil
        lastDeletedIndex = nil
        
        print("撤销操作完成，当前索引: \(currentIndex)")
    }
    
    // MARK: - 会话管理
    
    /// 重置会话状态
    func resetSession() {
        print("重置会话状态")
        
        photosToReview = []
        currentIndex = 0
        deletedCount = 0
        keptCount = 0
        lastDeletedAsset = nil
        lastDeletedIndex = nil
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
        
        // 注意：实际删除操作移到 SessionCompleteView 中
        // 这样用户可以在完成总结界面看到统计后再确认删除
        print("待删除队列保留，共 \(pendingDeletions.count) 张照片待删除")
    }
    
    /// 执行待删除照片的批量删除
    /// 此方法应该在用户确认后调用（例如在 SessionCompleteView 中）
    func executePendingDeletions(completion: @escaping (Bool) -> Void) {
        guard !pendingDeletions.isEmpty else {
            print("没有待删除的照片")
            completion(true)
            return
        }
        
        print("开始批量删除 \(pendingDeletions.count) 张照片...")
        
        photoService.deleteAssets(assets: pendingDeletions) { [weak self] success, error in
            guard let self = self else { return }
            
            Task { @MainActor in
                if success {
                    print("批量删除成功！共 \(self.pendingDeletions.count) 张照片")
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
    
    /// 获取指定索引照片的缩略图
    func getThumbnail(at index: Int, targetSize: CGSize = CGSize(width: 400, height: 400), completion: @escaping (UIImage?) -> Void) {
        guard index >= 0 && index < photosToReview.count else {
            completion(nil)
            return
        }
        
        let photo = photosToReview[index]
        photoService.fetchThumbnail(for: photo.asset, targetSize: targetSize, completion: completion)
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
}

