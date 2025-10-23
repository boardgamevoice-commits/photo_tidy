//
//  AdFreeManager.swift
//  PhotoTidy-Toilet Buddy
//
//  Created on 2025-10-23.
//

import Foundation

/// AdFreeManager 负责管理用户的无广告状态
/// 用户观看激励广告后可获得24小时的无广告体验
class AdFreeManager {
    
    static let shared = AdFreeManager()
    
    // MARK: - Constants
    
    /// 无广告时长（24小时）
    private let adFreeDuration: TimeInterval = 24 * 60 * 60
    
    // MARK: - UserDefaults Keys
    
    private let adFreeExpiryKey = "adFree.expiryTimestamp"
    private let activationCountKey = "adFree.activationCount"
    private let lastActivationDateKey = "adFree.lastActivationDate"
    
    // MARK: - Private Init
    
    private init() {
        AppLogger.shared.info("AdFreeManager 初始化", category: .ui)
    }
    
    // MARK: - Public Methods
    
    /// 检查用户是否处于无广告期间
    /// - Returns: 如果当前时间在无广告有效期内返回 true，否则返回 false
    func isAdFree() -> Bool {
        guard let expiryDate = getAdFreeExpiry() else {
            return false
        }
        
        let isFree = Date() < expiryDate
        
        if isFree {
            AppLogger.shared.info("用户处于无广告期间，到期时间: \(expiryDate)", category: .ui)
        } else {
            AppLogger.shared.info("无广告已过期，过期时间: \(expiryDate)", category: .ui)
            // 清理过期数据
            clearExpiredAdFreeStatus()
        }
        
        return isFree
    }
    
    /// 激活24小时无广告体验
    /// 用户成功观看激励广告后调用此方法
    func activateAdFree() {
        let expiryDate = Date().addingTimeInterval(adFreeDuration)
        let defaults = UserDefaults.standard
        
        // 保存到期时间
        defaults.set(expiryDate.timeIntervalSince1970, forKey: adFreeExpiryKey)
        
        // 更新激活次数
        let currentCount = defaults.integer(forKey: activationCountKey)
        defaults.set(currentCount + 1, forKey: activationCountKey)
        
        // 保存最后激活日期
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        defaults.set(dateFormatter.string(from: Date()), forKey: lastActivationDateKey)
        
        AppLogger.shared.info("激活无广告模式成功！到期时间: \(expiryDate)", category: .ui)
        AppLogger.shared.info("累计激活次数: \(currentCount + 1)", category: .ui)
    }
    
    /// 获取无广告剩余时间（秒）
    /// - Returns: 如果处于无广告期间，返回剩余秒数；否则返回 nil
    func getRemainingAdFreeTime() -> TimeInterval? {
        guard let expiryDate = getAdFreeExpiry(), Date() < expiryDate else {
            return nil
        }
        return expiryDate.timeIntervalSince(Date())
    }
    
    /// 获取格式化的剩余时间字符串
    /// - Returns: 格式如 "23小时45分钟" 或 "2小时15分钟"，如果已过期返回 nil
    func getFormattedRemainingTime() -> String? {
        guard let remaining = getRemainingAdFreeTime() else {
            return nil
        }
        
        let hours = Int(remaining) / 3600
        let minutes = Int(remaining) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        } else {
            return "\(minutes)分钟"
        }
    }
    
    /// 获取无广告到期时间
    /// - Returns: 到期时间的 Date 对象，如果未激活返回 nil
    func getAdFreeExpiry() -> Date? {
        let timestamp = UserDefaults.standard.double(forKey: adFreeExpiryKey)
        guard timestamp > 0 else {
            return nil
        }
        return Date(timeIntervalSince1970: timestamp)
    }
    
    /// 获取累计激活次数（用于统计）
    /// - Returns: 用户累计观看激励广告的次数
    func getActivationCount() -> Int {
        return UserDefaults.standard.integer(forKey: activationCountKey)
    }
    
    /// 手动清除无广告状态（用于测试或特殊场景）
    func clearAdFreeStatus() {
        UserDefaults.standard.removeObject(forKey: adFreeExpiryKey)
        AppLogger.shared.warning("已手动清除无广告状态", category: .ui)
    }
    
    // MARK: - Private Methods
    
    /// 清理已过期的无广告状态数据
    private func clearExpiredAdFreeStatus() {
        UserDefaults.standard.removeObject(forKey: adFreeExpiryKey)
        AppLogger.shared.info("已清理过期的无广告状态", category: .ui)
    }
}

