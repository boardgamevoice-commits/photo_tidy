//
//  Settings.swift
//  PhotoTidy-Toilet Buddy
//
//  Created on 2025-10-22.
//

import Foundation
import SwiftUI

/// 应用设置数据模型
struct Settings: Codable, Equatable {
    
    // MARK: - 审阅体验设置 (P1 - 预留)
    
    /// 最大撤销步数
    var maxUndoSteps: Int = 10
    
    /// 是否自动预加载
    var autoPreload: Bool = true
    
    /// 预加载数量
    var preloadCount: Int = 2
    
    // MARK: - 统计数据（只读，不存储在设置中）
    
    // 这些数据通过 UserDefaults 单独管理
    // var totalReviewedPhotos: Int
    // var totalDeletedPhotos: Int
    // var totalFreedSpace: Int64
}

