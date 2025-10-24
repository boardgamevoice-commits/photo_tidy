//
//  PhotoCountCacheManager.swift
//  PhotoTidy-Toilet Buddy
//
//  Created on 2025-10-23.
//

import Foundation
import Photos

/// 照片数量缓存管理器
/// 负责缓存照片数量计算结果，避免重复计算
class PhotoCountCacheManager {
    
    static let shared = PhotoCountCacheManager()
    
    // MARK: - Properties
    
    /// 缓存存储
    private var cache: [String: PhotoCountCacheEntry] = [:]
    
    /// 缓存过期时间（秒）
    private let cacheExpirationTime: TimeInterval = 300 // 5分钟
    
    /// 最大缓存条目数
    private let maxCacheEntries = 50
    
    /// 线程安全队列
    private let queue = DispatchQueue(label: "com.phototidy.photocountcache", attributes: .concurrent)
    
    // MARK: - Initialization
    
    private init() {
        AppLogger.shared.info("PhotoCountCacheManager 初始化", category: .photo)
    }
    
    // MARK: - Public Methods
    
    /// 获取缓存的照片数量
    /// - Parameter key: 缓存键
    /// - Returns: 缓存的结果，如果不存在或已过期则返回nil
    func getCachedCount(for key: String) -> Int? {
        return queue.sync {
            guard let entry = cache[key] else {
                return nil
            }
            
            // 检查是否过期
            if Date().timeIntervalSince(entry.timestamp) > cacheExpirationTime {
                cache.removeValue(forKey: key)
                AppLogger.shared.debug("缓存已过期，移除: \(key)", category: .photo)
                return nil
            }
            
            AppLogger.shared.debug("命中缓存: \(key) = \(entry.count)", category: .photo)
            return entry.count
        }
    }
    
    /// 缓存照片数量结果
    /// - Parameters:
    ///   - key: 缓存键
    ///   - count: 照片数量
    func cacheCount(_ count: Int, for key: String) {
        queue.async(flags: .barrier) {
            // 清理过期缓存
            self.cleanExpiredCache()
            
            // 限制缓存大小
            if self.cache.count >= self.maxCacheEntries {
                self.removeOldestCache()
            }
            
            let entry = PhotoCountCacheEntry(count: count, timestamp: Date())
            self.cache[key] = entry
            
            AppLogger.shared.debug("缓存照片数量: \(key) = \(count)", category: .photo)
        }
    }
    
    /// 清除所有缓存
    func clearCache() {
        queue.async(flags: .barrier) {
            self.cache.removeAll()
            AppLogger.shared.info("清除所有照片数量缓存", category: .photo)
        }
    }
    
    /// 清除特定缓存
    /// - Parameter key: 缓存键
    func clearCache(for key: String) {
        queue.async(flags: .barrier) {
            self.cache.removeValue(forKey: key)
            AppLogger.shared.debug("清除缓存: \(key)", category: .photo)
        }
    }
    
    /// 生成缓存键
    /// - Parameter filterConfig: 过滤配置
    /// - Returns: 缓存键
    static func generateCacheKey(from filterConfig: FilterConfiguration) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys // 确保键的一致性
        
        do {
            let data = try encoder.encode(filterConfig)
            let hash = data.hashValue
            return "photocount_\(hash)"
        } catch {
            AppLogger.shared.error("生成缓存键失败: \(error)", category: .photo)
            return "photocount_\(filterConfig.hashValue)"
        }
    }
    
    // MARK: - Private Methods
    
    /// 清理过期缓存
    private func cleanExpiredCache() {
        let now = Date()
        let expiredKeys = cache.compactMap { (key, entry) in
            now.timeIntervalSince(entry.timestamp) > cacheExpirationTime ? key : nil
        }
        
        for key in expiredKeys {
            cache.removeValue(forKey: key)
        }
        
        if !expiredKeys.isEmpty {
            AppLogger.shared.debug("清理过期缓存: \(expiredKeys.count) 个条目", category: .photo)
        }
    }
    
    /// 移除最旧的缓存条目
    private func removeOldestCache() {
        guard let oldestKey = cache.min(by: { $0.value.timestamp < $1.value.timestamp })?.key else {
            return
        }
        
        cache.removeValue(forKey: oldestKey)
        AppLogger.shared.debug("移除最旧缓存: \(oldestKey)", category: .photo)
    }
}

// MARK: - Supporting Types

/// 照片数量缓存条目
private struct PhotoCountCacheEntry {
    let count: Int
    let timestamp: Date
}

// MARK: - FilterConfiguration Extension

extension FilterConfiguration {
    /// 生成哈希值用于缓存键
    var hashValue: Int {
        var hasher = Hasher()
        hasher.combine(contentType)
        hasher.combine(dateRange)
        hasher.combine(locationFilter)
        hasher.combine(durationFilter)
        hasher.combine(excludeHidden)
        hasher.combine(excludeFavorite)
        return hasher.finalize()
    }
}
