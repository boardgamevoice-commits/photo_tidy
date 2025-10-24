//
//  SplashScreenView.swift
//  PhotoTidy-Toilet Buddy
//
//  Created on 2025-10-23.
//

import SwiftUI
import Photos

/// 启动屏幕视图
struct SplashScreenView: View {
    @State private var isLoading = true
    @State private var progress: Double = 0.0
    @State private var currentStep = 0
    
    @Binding var extractedAssets: [PHAsset]
    @Binding var extractionProgress: Double
    
    let onComplete: () -> Void
    
    private let loadingSteps = [
        NSLocalizedString("splash.step.initializing", comment: ""),
        NSLocalizedString("splash.step.checking_permissions", comment: ""),
        NSLocalizedString("splash.step.preparing_library", comment: ""),
        NSLocalizedString("splash.step.extracting_assets", comment: ""),
        NSLocalizedString("splash.step.loading_interface", comment: "")
    ]
    
    var body: some View {
        ZStack {
            // 背景渐变
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.blue.opacity(0.1),
                    Color.purple.opacity(0.1)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                // 应用图标和标题
                VStack(spacing: 20) {
                    // 应用图标占位符
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [.blue, .purple]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                        .overlay(
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 50, weight: .light))
                                .foregroundColor(.white)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    
                    VStack(spacing: 8) {
                        Text(NSLocalizedString("splash.app_title", comment: ""))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text(NSLocalizedString("splash.app_subtitle", comment: ""))
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                
                // 加载进度
                VStack(spacing: 20) {
                    // 进度条
                    VStack(spacing: 12) {
                        ProgressView(value: progress, total: 1.0)
                            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                            .scaleEffect(y: 2.0)
                            .frame(width: 200)
                        
                        Text("\(Int(progress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // 当前步骤
                    Text(loadingSteps[currentStep])
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .animation(.easeInOut(duration: 0.3), value: currentStep)
                }
                
                // 说明文字
                VStack(spacing: 12) {
                    Text(NSLocalizedString("splash.description.main", comment: ""))
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Text(NSLocalizedString("splash.description.subtitle", comment: ""))
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 40)
        }
        .onAppear {
            startLoadingAnimation()
        }
    }
    
    private func startLoadingAnimation() {
        // 模拟加载步骤
        let stepDuration: TimeInterval = 0.8
        let totalSteps = loadingSteps.count
        
        Task {
            // 步骤 1-3: 模拟初始化
            for step in 0..<3 {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        progress = Double(step + 1) / Double(totalSteps)
                        currentStep = step
                    }
                }
                try? await Task.sleep(nanoseconds: UInt64(stepDuration * 1_000_000_000))
            }
            
            // 步骤 4: 实际资源提取
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.5)) {
                    currentStep = 3
                }
            }
            
            // 执行实际的资源提取
            let photoService = PhotoService.shared
            let defaultConfig = FilterConfiguration()
            
            let assets = await photoService.fetchRandomAssetsAsync(
                count: 50, // 预提取一些照片
                filterConfig: defaultConfig
            ) { progress in
                Task { @MainActor in
                    // 更新资源提取进度
                    self.extractionProgress = progress
                    // 更新总进度（步骤3 + 资源提取进度）
                    self.progress = (3.0 + progress) / Double(totalSteps)
                }
            }
            
            await MainActor.run {
                self.extractedAssets = assets
            }
            
            // 步骤 5: 完成
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.5)) {
                    progress = 1.0
                    currentStep = 4
                }
            }
            
            try? await Task.sleep(nanoseconds: UInt64(0.5 * 1_000_000_000))
            
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.5)) {
                    isLoading = false
                }
            }
            
            try? await Task.sleep(nanoseconds: UInt64(0.3 * 1_000_000_000))
            
            await MainActor.run {
                onComplete()
            }
        }
    }
}

#Preview {
    SplashScreenView(
        extractedAssets: .constant([]),
        extractionProgress: .constant(0.0)
    ) {
        print("Loading complete")
    }
}
