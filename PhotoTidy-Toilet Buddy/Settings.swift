//
//  Settings.swift
//  PhotoTidy-Toilet Buddy
//
//  Created on 2025-10-22.
//

import Foundation
import SwiftUI

/// 应用语言枚举
enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case system
    case chinese
    case english
    
    var id: String { rawValue }
    
    var localizedName: String {
        switch self {
        case .system:
            return NSLocalizedString("settings.language.system", comment: "")
        case .chinese:
            return NSLocalizedString("settings.language.chinese", comment: "")
        case .english:
            return NSLocalizedString("settings.language.english", comment: "")
        }
    }
    
    var icon: String {
        switch self {
        case .system:
            return "globe"
        case .chinese:
            return "character.textbox"
        case .english:
            return "a.circle.fill"
        }
    }
    
    var description: String {
        switch self {
        case .system:
            return NSLocalizedString("settings.language.system.desc", comment: "")
        case .chinese:
            return NSLocalizedString("settings.language.chinese.desc", comment: "")
        case .english:
            return NSLocalizedString("settings.language.english.desc", comment: "")
        }
    }
    
    /// 转换为语言代码
    var languageCode: String? {
        switch self {
        case .system:
            return nil // nil 表示跟随系统
        case .chinese:
            return "zh-Hans"
        case .english:
            return "en"
        }
    }
}

/// 主题模式枚举
enum AppTheme: String, Codable, CaseIterable, Identifiable {
    case system
    case light
    case dark
    
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
    
    var localizedName: String {
        switch self {
        case .system:
            return NSLocalizedString("settings.theme.system", comment: "")
        case .light:
            return NSLocalizedString("settings.theme.light", comment: "")
        case .dark:
            return NSLocalizedString("settings.theme.dark", comment: "")
        }
    }
    
    var description: String {
        switch self {
        case .system:
            return NSLocalizedString("settings.theme.system.desc", comment: "")
        case .light:
            return NSLocalizedString("settings.theme.light.desc", comment: "")
        case .dark:
            return NSLocalizedString("settings.theme.dark.desc", comment: "")
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
    
    /// 语言设置
    var language: AppLanguage = .system
    
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

