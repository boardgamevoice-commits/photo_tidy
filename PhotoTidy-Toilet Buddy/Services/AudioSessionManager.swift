//
//  AudioSessionManager.swift
//  PhotoTidy-Toilet Buddy
//
//  Created on 2025-01-23.
//  Audio session management for video playback
//

import Foundation
import AVFoundation
import UIKit

/// 音频会话管理器
/// 负责管理 AVFoundation 音频会话，防止 "Failed to change to usage state 0" 错误
class AudioSessionManager {
    
    static let shared = AudioSessionManager()
    
    // MARK: - Properties
    
    /// 音频会话是否已激活
    private var isAudioSessionActive = false
    
    /// 当前音频会话类别
    private var currentCategory: AVAudioSession.Category = .playback
    
    /// 当前音频会话模式
    private var currentMode: AVAudioSession.Mode = .default
    
    private init() {
        setupAudioSession()
    }
    
    deinit {
        deactivateAudioSession()
    }
    
    // MARK: - Public Methods
    
    /// 为视频播放配置音频会话
    /// - Parameters:
    ///   - category: 音频会话类别，默认为 .playback
    ///   - mode: 音频会话模式，默认为 .moviePlayback
    /// - Returns: 是否配置成功
    @discardableResult
    func configureForVideoPlayback(
        category: AVAudioSession.Category = .playback,
        mode: AVAudioSession.Mode = .moviePlayback
    ) -> Bool {
        
        AppLogger.shared.media("配置音频会话用于视频播放: category=\(category.rawValue), mode=\(mode.rawValue)", level: .debug)
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // 先检查当前状态，如果已经是目标状态则跳过
            if isAudioSessionActive && currentCategory == category && currentMode == mode {
                AppLogger.shared.media("音频会话已经是目标状态，跳过配置", level: .debug)
                return true
            }
            
            // 先停用当前会话（避免状态冲突）
            if isAudioSessionActive {
                try? audioSession.setActive(false, options: [])
            }
            
            // 设置音频会话类别和模式
            // 移除不兼容的选项，只使用兼容的选项
            try audioSession.setCategory(category, mode: mode, options: [.allowAirPlay])
            
            // 激活音频会话
            try audioSession.setActive(true, options: [.notifyOthersOnDeactivation])
            
            isAudioSessionActive = true
            currentCategory = category
            currentMode = mode
            
            AppLogger.shared.media("音频会话配置成功: category=\(category.rawValue), mode=\(mode.rawValue)", level: .info)
            return true
            
        } catch {
            AppLogger.shared.error("音频会话配置失败", error: error, category: .media)
            // 配置失败时重置状态
            isAudioSessionActive = false
            return false
        }
    }
    
    /// 为静音播放配置音频会话
    /// - Returns: 是否配置成功
    @discardableResult
    func configureForSilentPlayback() -> Bool {
        
        AppLogger.shared.media("配置音频会话用于静音播放", level: .debug)
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // 设置为静音播放模式
            try audioSession.setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers])
            
            // 激活音频会话
            try audioSession.setActive(true, options: [])
            
            isAudioSessionActive = true
            currentCategory = .playback
            currentMode = .moviePlayback
            
            AppLogger.shared.media("静音播放音频会话配置成功", level: .info)
            return true
            
        } catch {
            AppLogger.shared.error("静音播放音频会话配置失败", error: error, category: .media)
            return false
        }
    }
    
    /// 停用音频会话
    func deactivateAudioSession() {
        guard isAudioSessionActive else { return }
        
        AppLogger.shared.media("停用音频会话", level: .debug)
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            
            isAudioSessionActive = false
            
            AppLogger.shared.media("音频会话已停用", level: .info)
            
        } catch {
            AppLogger.shared.error("停用音频会话失败", error: error, category: .media)
        }
    }
    
    /// 重置音频会话到默认状态
    func resetToDefault() {
        AppLogger.shared.media("重置音频会话到默认状态", level: .debug)
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // 设置为默认类别和模式
            try audioSession.setCategory(.soloAmbient, mode: .default)
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            
            isAudioSessionActive = false
            currentCategory = .soloAmbient
            currentMode = .default
            
            AppLogger.shared.media("音频会话已重置到默认状态", level: .info)
            
        } catch {
            AppLogger.shared.error("重置音频会话失败", error: error, category: .media)
        }
    }
    
    /// 检查音频会话状态
    func checkAudioSessionStatus() -> (isActive: Bool, category: String, mode: String) {
        let audioSession = AVAudioSession.sharedInstance()
        return (
            isActive: audioSession.isOtherAudioPlaying,
            category: audioSession.category.rawValue,
            mode: audioSession.mode.rawValue
        )
    }
    
    // MARK: - Private Methods
    
    /// 初始化音频会话设置
    private func setupAudioSession() {
        AppLogger.shared.media("初始化音频会话管理器", level: .debug)
        
        // 监听应用生命周期事件
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
    
    // MARK: - Notification Handlers
    
    @objc private func appDidEnterBackground() {
        AppLogger.shared.media("应用进入后台，停用音频会话", level: .debug)
        deactivateAudioSession()
    }
    
    @objc private func appWillEnterForeground() {
        AppLogger.shared.media("应用即将进入前台", level: .debug)
        // 不自动重新激活，等待需要时再激活
    }
    
    @objc private func appWillTerminate() {
        AppLogger.shared.media("应用即将终止，清理音频会话", level: .debug)
        deactivateAudioSession()
    }
}

// MARK: - Audio Session Category Extensions

extension AVAudioSession.Category {
    var description: String {
        return self.rawValue
    }
}

extension AVAudioSession.Mode {
    var description: String {
        return self.rawValue
    }
}
