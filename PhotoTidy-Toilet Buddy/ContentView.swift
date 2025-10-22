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
                    Color.black.ignoresSafeArea()
                    VStack(spacing: 20) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        Text("加载中...")
                            .font(.headline)
                            .foregroundColor(.white)
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
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }
    
}

#Preview {
    ContentView()
}

