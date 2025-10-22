//
//  SettingsManager.swift
//  PhotoTidy-Toilet Buddy
//
//  Created on 2025-10-22.
//

import Foundation
import Combine

/// 设置管理器 - 负责设置的保存和加载
class SettingsManager: ObservableObject {
    
    static let shared = SettingsManager()
    
    // MARK: - UserDefaults Keys
    
    private let settingsKey = "app.settings"
    private let totalReviewedPhotosKey = "stats.totalReviewedPhotos"
    private let totalDeletedPhotosKey = "stats.totalDeletedPhotos"
    private let totalFreedSpaceKey = "stats.totalFreedSpace"
    private let totalSessionsKey = "stats.totalSessions"
    
    // MARK: - Published Properties
    
    @Published var settings: Settings {
        didSet {
            saveSettings()
        }
    }
    
    // 触发器：当统计数据更新时，改变此值以触发 UI 刷新
    @Published private(set) var statisticsUpdateTrigger: Int = 0
    
    // MARK: - Statistics (只读)
    
    var totalReviewedPhotos: Int {
        get { 
            _ = statisticsUpdateTrigger // 触发依赖
            return UserDefaults.standard.integer(forKey: totalReviewedPhotosKey) 
        }
    }
    
    var totalDeletedPhotos: Int {
        get { 
            _ = statisticsUpdateTrigger // 触发依赖
            return UserDefaults.standard.integer(forKey: totalDeletedPhotosKey) 
        }
    }
    
    var totalFreedSpace: Int64 {
        get { 
            _ = statisticsUpdateTrigger // 触发依赖
            return Int64(UserDefaults.standard.integer(forKey: totalFreedSpaceKey)) 
        }
    }
    
    var totalSessions: Int {
        get { 
            _ = statisticsUpdateTrigger // 触发依赖
            return UserDefaults.standard.integer(forKey: totalSessionsKey) 
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        // 加载设置
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(Settings.self, from: data) {
            self.settings = decoded
            print("✅ 已加载用户设置")
        } else {
            self.settings = Settings()
            print("ℹ️ 使用默认设置")
        }
    }
    
    // MARK: - Settings Management
    
    /// 保存设置到 UserDefaults
    func saveSettings() {
        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: settingsKey)
            print("💾 设置已保存")
        }
    }
    
    /// 重置所有设置到默认值
    func resetSettings() {
        settings = Settings()
        print("🔄 设置已重置为默认值")
    }
    
    // MARK: - Statistics Management
    
    /// 更新统计数据（在会话完成时调用）
    func updateStatistics(reviewedCount: Int, deletedCount: Int, freedSpace: Int64) {
        let currentReviewed = totalReviewedPhotos
        let currentDeleted = totalDeletedPhotos
        let currentFreed = totalFreedSpace
        let currentSessions = totalSessions
        
        UserDefaults.standard.set(currentReviewed + reviewedCount, forKey: totalReviewedPhotosKey)
        UserDefaults.standard.set(currentDeleted + deletedCount, forKey: totalDeletedPhotosKey)
        UserDefaults.standard.set(Int(currentFreed + freedSpace), forKey: totalFreedSpaceKey)
        UserDefaults.standard.set(currentSessions + 1, forKey: totalSessionsKey)
        
        // 触发 UI 更新
        statisticsUpdateTrigger += 1
        
        print("📊 统计数据已更新：审阅 +\(reviewedCount), 删除 +\(deletedCount), 释放 +\(freedSpace) bytes")
    }
    
    /// 清除所有统计数据
    func clearStatistics() {
        UserDefaults.standard.removeObject(forKey: totalReviewedPhotosKey)
        UserDefaults.standard.removeObject(forKey: totalDeletedPhotosKey)
        UserDefaults.standard.removeObject(forKey: totalFreedSpaceKey)
        UserDefaults.standard.removeObject(forKey: totalSessionsKey)
        
        // 触发 UI 更新
        statisticsUpdateTrigger += 1
        
        print("🧹 统计数据已清除")
    }
    
    /// 格式化存储空间为可读字符串
    func formattedTotalFreedSpace() -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: totalFreedSpace)
    }
}

