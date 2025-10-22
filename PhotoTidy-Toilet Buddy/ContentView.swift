//
//  ContentView.swift
//  PhotoTidy-Toilet Buddy
//
//  Created on 2025-10-22.
//

import SwiftUI
import Photos

struct ContentView: View {
    @StateObject private var viewModel = TidySessionViewModel()
    
    var body: some View {
        Group {
            if viewModel.isLoading {
                ZStack {
                    // 使用系统背景色以适配浅色/深色模式
                    Color(.systemBackground).ignoresSafeArea()
                    VStack(spacing: 20) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            .scaleEffect(1.5)
                        Text("加载中...")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                }
            } else if viewModel.isSessionCompleted {
                // 会话完成界面
                SessionCompleteView(viewModel: viewModel)
            } else if !viewModel.isSessionActive {
                // 会话设置界面
                SessionSetupView(viewModel: viewModel)
            } else {
                // 会话进行中 - 使用卡片审阅视图
                CardReviewView(viewModel: viewModel)
            }
        }
        .alert("错误", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("确定") {
                viewModel.errorMessage = nil
            }
            // 如果是权限错误，提供前往设置的选项
            if let error = viewModel.errorMessage, error.contains("权限") {
                Button("前往设置") {
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

