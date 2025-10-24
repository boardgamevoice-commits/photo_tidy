//
//  PhotoTidyToiletBuddyApp.swift
//  PhotoTidy-Toilet Buddy
//
//  Created on 2025-10-22.
//

import SwiftUI
import Photos

@main
struct PhotoTidyToiletBuddyApp: App {
    
    @StateObject private var settingsManager = SettingsManager.shared
    @State private var showSplashScreen = true
    
    init() {
        // 记录应用启动
        AppLogger.shared.info("Photo Tidy App 启动", category: .general)
        
        // 延迟初始化 AdMob SDK，避免阻塞主线程和启动过程
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            AppLogger.shared.info("开始延迟初始化 AdMob SDK", category: .network)
            AdManager.shared.initializeAdMob()
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

