//
//  Settings.swift
//  PhotoTidy-Toilet Buddy
//
//  Created on 2025-10-22.
//

import Foundation
import SwiftUI

/// 主题模式枚举
enum AppTheme: String, Codable, CaseIterable, Identifiable {
    case system = "跟随系统"
    case light = "浅色模式"
    case dark = "深色模式"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .system:
            return "circle.lefthalf.filled"
        case .light:
            return "sun.max.fill"
        case .dark:
            return "moon.fill"
        }
    }
    
    var description: String {
        switch self {
        case .system:
            return "自动跟随系统外观设置"
        case .light:
            return "始终使用浅色模式"
        case .dark:
            return "始终使用深色模式"
        }
    }
    
    /// 转换为 SwiftUI 的 ColorScheme
    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil // nil 表示跟随系统
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

/// 应用设置数据模型
struct Settings: Codable, Equatable {
    
    // MARK: - 外观设置
    
    /// 主题模式
    var theme: AppTheme = .system
    
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

