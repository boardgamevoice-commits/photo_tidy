//
//  Logger.swift
//  PhotoTidy-Toilet Buddy
//
//  Created on 2025-10-22.
//  统一的日志系统，使用 OSLog
//

import Foundation
import os.log

/// 统一的日志管理器
/// 使用 OSLog 提供高性能、结构化的日志记录
/// 支持日志级别：debug, info, warning, error
class AppLogger {
    
    // MARK: - Shared Instance
    
    static let shared = AppLogger()
    
    // MARK: - Log Categories
    
    /// 通用日志
    private let generalLogger: OSLog
    
    /// UI相关日志
    private let uiLogger: OSLog
    
    /// 网络相关日志
    private let networkLogger: OSLog
    
    /// 照片服务日志
    private let photoLogger: OSLog
    
    /// 媒体播放日志
    private let mediaLogger: OSLog
    
    /// 性能监控日志
    private let performanceLogger: OSLog
    
    // MARK: - Configuration
    
    /// 是否启用 debug 日志（生产环境应设为 false）
    private var isDebugEnabled: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    // MARK: - Initialization
    
    private init() {
        let subsystem = Bundle.main.bundleIdentifier ?? "com.phototidy.app"
        
        self.generalLogger = OSLog(subsystem: subsystem, category: "General")
        self.uiLogger = OSLog(subsystem: subsystem, category: "UI")
        self.networkLogger = OSLog(subsystem: subsystem, category: "Network")
        self.photoLogger = OSLog(subsystem: subsystem, category: "Photo")
        self.mediaLogger = OSLog(subsystem: subsystem, category: "Media")
        self.performanceLogger = OSLog(subsystem: subsystem, category: "Performance")
    }
    
    // MARK: - Public Logging Methods
    
    /// Debug 级别日志（仅在 DEBUG 模式下输出）
    /// - Parameters:
    ///   - message: 日志消息
    ///   - category: 日志分类
    ///   - file: 文件名（自动填充）
    ///   - function: 函数名（自动填充）
    ///   - line: 行号（自动填充）
    func debug(
        _ message: String,
        category: LogCategory = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        guard isDebugEnabled else { return }
        
        let fileName = (file as NSString).lastPathComponent
        let logMessage = "[\(fileName):\(line)] \(function) - \(message)"
        
        os_log("%{public}@", log: logger(for: category), type: .debug, logMessage)
    }
    
    /// Info 级别日志（一般信息）
    func info(
        _ message: String,
        category: LogCategory = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let fileName = (file as NSString).lastPathComponent
        let logMessage = "[\(fileName):\(line)] \(function) - \(message)"
        
        os_log("%{public}@", log: logger(for: category), type: .info, logMessage)
    }
    
    /// Warning 级别日志（警告信息）
    func warning(
        _ message: String,
        category: LogCategory = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let fileName = (file as NSString).lastPathComponent
        let logMessage = "⚠️ [\(fileName):\(line)] \(function) - \(message)"
        
        os_log("%{public}@", log: logger(for: category), type: .default, logMessage)
    }
    
    /// Error 级别日志（错误信息）
    func error(
        _ message: String,
        error: Error? = nil,
        category: LogCategory = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let fileName = (file as NSString).lastPathComponent
        var logMessage = "❌ [\(fileName):\(line)] \(function) - \(message)"
        
        if let error = error {
            logMessage += " | Error: \(error.localizedDescription)"
        }
        
        os_log("%{public}@", log: logger(for: category), type: .error, logMessage)
    }
    
    /// Fault 级别日志（严重错误，可能导致崩溃）
    func fault(
        _ message: String,
        error: Error? = nil,
        category: LogCategory = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let fileName = (file as NSString).lastPathComponent
        var logMessage = "🔥 [\(fileName):\(line)] \(function) - \(message)"
        
        if let error = error {
            logMessage += " | Error: \(error.localizedDescription)"
        }
        
        os_log("%{public}@", log: logger(for: category), type: .fault, logMessage)
    }
    
    // MARK: - Convenience Methods for Specific Categories
    
    /// UI 相关日志
    func ui(_ message: String, level: LogLevel = .info) {
        log(message, category: .ui, level: level)
    }
    
    /// 照片服务日志
    func photo(_ message: String, level: LogLevel = .info) {
        log(message, category: .photo, level: level)
    }
    
    /// 媒体播放日志
    func media(_ message: String, level: LogLevel = .info) {
        log(message, category: .media, level: level)
    }
    
    /// 性能监控日志
    func performance(_ message: String) {
        log(message, category: .performance, level: .info)
    }
    
    // MARK: - Private Helpers
    
    private func logger(for category: LogCategory) -> OSLog {
        switch category {
        case .general: return generalLogger
        case .ui: return uiLogger
        case .network: return networkLogger
        case .photo: return photoLogger
        case .media: return mediaLogger
        case .performance: return performanceLogger
        }
    }
    
    private func log(
        _ message: String,
        category: LogCategory,
        level: LogLevel,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        switch level {
        case .debug:
            debug(message, category: category, file: file, function: function, line: line)
        case .info:
            info(message, category: category, file: file, function: function, line: line)
        case .warning:
            warning(message, category: category, file: file, function: function, line: line)
        case .error:
            error(message, category: category, file: file, function: function, line: line)
        }
    }
}

// MARK: - Log Category

enum LogCategory {
    case general
    case ui
    case network
    case photo
    case media
    case performance
}

// MARK: - Log Level

enum LogLevel {
    case debug
    case info
    case warning
    case error
}

// MARK: - Global Convenience Functions

/// 全局 Debug 日志
func logDebug(_ message: String, category: LogCategory = .general) {
    AppLogger.shared.debug(message, category: category)
}

/// 全局 Info 日志
func logInfo(_ message: String, category: LogCategory = .general) {
    AppLogger.shared.info(message, category: category)
}

/// 全局 Warning 日志
func logWarning(_ message: String, category: LogCategory = .general) {
    AppLogger.shared.warning(message, category: category)
}

/// 全局 Error 日志
func logError(_ message: String, error: Error? = nil, category: LogCategory = .general) {
    AppLogger.shared.error(message, error: error, category: category)
}

