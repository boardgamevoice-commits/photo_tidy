//
//  PhotoTidyToiletBuddyApp.swift
//  PhotoTidy-Toilet Buddy
//
//  Created on 2025-10-22.
//

import SwiftUI

@main
struct PhotoTidyToiletBuddyApp: App {
    
    @StateObject private var settingsManager = SettingsManager.shared
    
    init() {
        // 初始化 AdMob SDK
        AppLogger.shared.info("Photo Tidy App 启动", category: .general)
        AdManager.shared.initializeAdMob()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(settingsManager.currentColorScheme) // 根据用户设置应用主题
                .environmentObject(settingsManager)
        }
    }
}

