//
//  BackgroundTaskManager.swift
//  PhotoTidy-Toilet Buddy
//
//  Created on 2025-01-23.
//  Enhanced background task management with assertion invalidation handling
//

import Foundation
import UIKit

/// 后台任务管理器
/// 负责管理后台任务，处理断言失效和系统资源管理
class BackgroundTaskManager {
    
    static let shared = BackgroundTaskManager()
    
    // MARK: - Properties
    
    /// 活跃的后台任务
    private var activeTasks: [String: UIBackgroundTaskIdentifier] = [:]
    
    /// 任务过期时间
    private var taskExpirationTimes: [String: Date] = [:]
    
    /// 最大后台任务数量
    private let maxConcurrentTasks = 3
    
    /// 任务过期检查定时器
    private var expirationTimer: Timer?
    
    private init() {
        setupAppLifecycleObservers()
        startExpirationTimer()
    }
    
    deinit {
        cleanupAllTasks()
        expirationTimer?.invalidate()
    }
    
    // MARK: - Public Methods
    
    /// 开始后台任务
    /// - Parameters:
    ///   - taskName: 任务名称
    ///   - expirationHandler: 过期处理回调
    /// - Returns: 是否成功开始任务
    @discardableResult
    func beginBackgroundTask(
        taskName: String,
        expirationHandler: (() -> Void)? = nil
    ) -> Bool {
        
        // 检查应用状态（必须在主线程执行）
        var isInBackground = false
        if Thread.isMainThread {
            isInBackground = UIApplication.shared.applicationState == .background
        } else {
            DispatchQueue.main.sync {
                isInBackground = UIApplication.shared.applicationState == .background
            }
        }
        
        guard !isInBackground else {
            AppLogger.shared.warning("应用在后台状态，跳过创建后台任务: \(taskName)", category: .general)
            return false
        }
        
        // 检查任务数量限制
        if activeTasks.count >= maxConcurrentTasks {
            AppLogger.shared.warning("后台任务数量已达上限，跳过创建: \(taskName)", category: .general)
            return false
        }
        
        // 如果任务已存在，先结束它
        if activeTasks[taskName] != nil {
            endBackgroundTask(taskName: taskName)
        }
        
        // 创建新的后台任务
        let taskID = UIApplication.shared.beginBackgroundTask(withName: taskName) { [weak self] in
            AppLogger.shared.warning("后台任务即将过期或被系统撤销: \(taskName)", category: .general)
            
            // 调用过期处理回调
            expirationHandler?()
            
            // 自动结束任务
            self?.endBackgroundTask(taskName: taskName)
        }
        
        if taskID == .invalid {
            AppLogger.shared.error("无法开始后台任务: \(taskName)", category: .general)
            return false
        }
        
        // 记录任务信息
        activeTasks[taskName] = taskID
        taskExpirationTimes[taskName] = Date().addingTimeInterval(30) // 30秒后过期
        
        AppLogger.shared.debug("开始后台任务: \(taskName), ID: \(taskID.rawValue)", category: .general)
        return true
    }
    
    /// 结束后台任务
    /// - Parameter taskName: 任务名称
    func endBackgroundTask(taskName: String) {
        guard let taskID = activeTasks[taskName] else {
            AppLogger.shared.debug("后台任务不存在: \(taskName)", category: .general)
            return
        }
        
        AppLogger.shared.debug("结束后台任务: \(taskName), ID: \(taskID.rawValue)", category: .general)
        
        // 从记录中移除
        activeTasks.removeValue(forKey: taskName)
        taskExpirationTimes.removeValue(forKey: taskName)
        
        // 安全地结束后台任务
        DispatchQueue.main.async {
            UIApplication.shared.endBackgroundTask(taskID)
        }
    }
    
    /// 清理所有后台任务
    func cleanupAllTasks() {
        AppLogger.shared.info("清理所有后台任务，共 \(activeTasks.count) 个", category: .general)
        
        let taskNames = Array(activeTasks.keys)
        for taskName in taskNames {
            endBackgroundTask(taskName: taskName)
        }
        
        activeTasks.removeAll()
        taskExpirationTimes.removeAll()
    }
    
    /// 检查任务是否活跃
    /// - Parameter taskName: 任务名称
    /// - Returns: 是否活跃
    func isTaskActive(taskName: String) -> Bool {
        return activeTasks[taskName] != nil
    }
    
    /// 获取活跃任务数量
    var activeTaskCount: Int {
        return activeTasks.count
    }
    
    /// 获取活跃任务列表
    var activeTaskNames: [String] {
        return Array(activeTasks.keys)
    }
    
    // MARK: - Private Methods
    
    /// 设置应用生命周期监听器
    private func setupAppLifecycleObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
    }
    
    /// 启动过期检查定时器
    private func startExpirationTimer() {
        expirationTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.checkTaskExpiration()
        }
    }
    
    /// 检查任务过期
    private func checkTaskExpiration() {
        let now = Date()
        let expiredTasks = taskExpirationTimes.compactMap { (taskName, expirationTime) in
            expirationTime < now ? taskName : nil
        }
        
        for taskName in expiredTasks {
            AppLogger.shared.warning("后台任务已过期，自动结束: \(taskName)", category: .general)
            endBackgroundTask(taskName: taskName)
        }
    }
    
    // MARK: - Notification Handlers
    
    @objc private func appDidEnterBackground() {
        AppLogger.shared.info("应用进入后台，清理所有后台任务", category: .general)
        cleanupAllTasks()
    }
    
    @objc private func appWillEnterForeground() {
        AppLogger.shared.info("应用即将进入前台", category: .general)
        // 不自动重新创建任务，等待需要时再创建
    }
    
    @objc private func appWillTerminate() {
        AppLogger.shared.info("应用即将终止，清理所有后台任务", category: .general)
        cleanupAllTasks()
    }
}

// MARK: - Background Task Extensions

extension BackgroundTaskManager {
    
    /// 为照片操作创建后台任务
    /// - Parameter operation: 操作类型
    /// - Returns: 是否成功创建
    @discardableResult
    func beginPhotoOperation(_ operation: PhotoOperation) -> Bool {
        return beginBackgroundTask(taskName: "PhotoOperation_\(operation.rawValue)")
    }
    
    /// 为会话操作创建后台任务
    /// - Parameter operation: 操作类型
    /// - Returns: 是否成功创建
    @discardableResult
    func beginSessionOperation(_ operation: SessionOperation) -> Bool {
        return beginBackgroundTask(taskName: "SessionOperation_\(operation.rawValue)")
    }
    
    /// 结束照片操作后台任务
    /// - Parameter operation: 操作类型
    func endPhotoOperation(_ operation: PhotoOperation) {
        endBackgroundTask(taskName: "PhotoOperation_\(operation.rawValue)")
    }
    
    /// 结束会话操作后台任务
    /// - Parameter operation: 操作类型
    func endSessionOperation(_ operation: SessionOperation) {
        endBackgroundTask(taskName: "SessionOperation_\(operation.rawValue)")
    }
}

// MARK: - Operation Types

enum PhotoOperation: String, CaseIterable {
    case fetchAssets = "fetchAssets"
    case deleteAsset = "deleteAsset"
    case deleteAssets = "deleteAssets"
    case loadImage = "loadImage"
    case loadVideo = "loadVideo"
    case loadLivePhoto = "loadLivePhoto"
}

enum SessionOperation: String, CaseIterable {
    case startSession = "startSession"
    case executeDeletions = "executeDeletions"
    case preloadPhotos = "preloadPhotos"
    case validateParameters = "validateParameters"
}
