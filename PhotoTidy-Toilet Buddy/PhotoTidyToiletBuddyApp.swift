//
//  PhotoTidyToiletBuddyApp.swift
//  PhotoTidy-Toilet Buddy
//
//  Created on 2025-10-22.
//

import SwiftUI

@main
struct PhotoTidyToiletBuddyApp: App {
    
    init() {
        // 初始化 AdMob SDK
        print("Photo Tidy App 启动")
        AdManager.shared.initializeAdMob()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light) // 可选：设置默认配色方案
        }
    }
}

