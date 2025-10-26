//
//  PhotoTidyToiletBuddyApp.swift
//  PhotoTidy-Toilet Buddy
//
//  Created on 2025-10-22.
//

import SwiftUI
import Photos
import UIKit

@main
struct PhotoTidyToiletBuddyApp: App {
    
    @StateObject private var settingsManager = SettingsManager.shared
    @State private var showSplashScreen = true
    
    init() {
        // 记录应用启动
        AppLogger.shared.info("Photo Tidy App 启动", category: .general)
        
        // 设置应用生命周期监听
        setupAppLifecycleObservers()
        
        // 初始化音频会话管理器
        _ = AudioSessionManager.shared
        
        // 延迟初始化 AdMob SDK，避免阻塞主线程和启动过程
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            AppLogger.shared.info("开始延迟初始化 AdMob SDK", category: .network)
            AdManager.shared.initializeAdMob()
        }
    }
    
    /// 设置应用生命周期监听器
    private func setupAppLifecycleObservers() {
        // 监听应用进入后台
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            AppLogger.shared.info("应用进入后台，清理后台任务和音频会话", category: .general)
            // 清理所有后台任务
            BackgroundTaskManager.shared.cleanupAllTasks()
            // 停用音频会话
            AudioSessionManager.shared.deactivateAudioSession()
        }
        
        // 监听应用即将终止
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            AppLogger.shared.info("应用即将终止，清理后台任务和音频会话", category: .general)
            // 清理所有后台任务
            BackgroundTaskManager.shared.cleanupAllTasks()
            // 停用音频会话
            AudioSessionManager.shared.deactivateAudioSession()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            if showSplashScreen {
                SplashScreenView(
                    extractedAssets: .constant([]),
                    extractionProgress: .constant(0.0)
                ) {
                    showSplashScreen = false
                }
            } else {
                ContentView()
                    .preferredColorScheme(settingsManager.currentColorScheme) // 根据用户设置应用主题
                    .environmentObject(settingsManager)
            }
        }
    }
}

