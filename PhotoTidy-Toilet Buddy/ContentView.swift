//
//  ContentView.swift
//  PhotoTidy-Toilet Buddy
//
//  Created on 2025-10-22.
//

import SwiftUI
import Photos
import UIKit
import Combine

struct ContentView: View {
    @StateObject private var viewModel = TidySessionViewModel()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    // 判断是否应该应用padding（CardReviewPage不需要padding）
    private var shouldApplyPadding: Bool {
        return !viewModel.isSessionActive
    }
    
    var body: some View {
        Group {
            if viewModel.isLoading {
                loadingView
            } else if viewModel.isSessionCompleted {
                // 会话完成界面
                SessionCompleteView(viewModel: viewModel)
            } else if !viewModel.isSessionActive {
                // 会话设置界面
                SessionSetupView(viewModel: viewModel)
            } else {
                // 会话进行中 - 使用卡片审阅视图（全屏模式）
                CardReviewView(viewModel: viewModel)
                    .ignoresSafeArea(.all, edges: .all) // 忽略所有安全区域，实现全屏
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, shouldApplyPadding ? (isIPad ? 40 : 16) : 0)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            // 当应用进入后台时，清理后台任务
            viewModel.cleanupBackgroundTasks()
        }
        .alert(L10n.Error.title, isPresented: Binding.constant(viewModel.errorMessage != nil)) {
            Button(L10n.Button.confirm) {
                viewModel.errorMessage = nil
            }
            // 如果是权限错误，提供前往设置的选项
            if let error = viewModel.errorMessage, error.contains(L10n.Error.permission) {
                Button(L10n.Button.goToSettings) {
                    openSettings()
                    viewModel.errorMessage = nil
                }
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        ZStack {
            // 使用系统背景色以适配浅色/深色模式
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: isIPad ? 30 : 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    .scaleEffect(isIPad ? 2.0 : 1.5)
                Text(L10n.Loading.general)
                    .font(.system(size: isIPad ? 22 : 18, weight: .semibold))
                    .foregroundColor(.primary)
            }
        }
    }
    
    // MARK: - Device Detection
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular && verticalSizeClass == .regular
    }
    
    // MARK: - Helper Methods
    
    /// 打开系统设置页面
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
}

#Preview {
    ContentView()
}

