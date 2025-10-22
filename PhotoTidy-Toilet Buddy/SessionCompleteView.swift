//
//  SessionCompleteView.swift
//  PhotoTidy-Toilet Buddy
//
//  Created on 2025-10-22.
//

import SwiftUI

/// 会话完成视图 - 显示任务总结
struct SessionCompleteView: View {
    @ObservedObject var viewModel: TidySessionViewModel
    
    @State private var showingAd = false
    @State private var animateStats = false
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    Spacer()
                        .frame(height: 40)
                    
                    // 成功图标
                    successIcon
                    
                    // 标题
                    VStack(spacing: 10) {
                        Text("会话完成！")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                        
                        Text("干得漂亮！")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    
                    // 统计卡片
                    statisticsCard
                        .padding(.horizontal, 20)
                    
                    // 详细信息
                    detailsSection
                        .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    // 开始新任务按钮
                    startNewSessionButton
                        .padding(.horizontal, 30)
                        .padding(.bottom, 30)
                }
            }
            .navigationBarHidden(true)
            .background(
                LinearGradient(
                    colors: [
                        Color(.systemBackground),
                        Color.blue.opacity(0.05)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) {
                animateStats = true
            }
        }
    }
    
    // MARK: - Success Icon
    
    private var successIcon: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.green, .green.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 120, height: 120)
                .shadow(color: .green.opacity(0.3), radius: 20, x: 0, y: 10)
            
            Image(systemName: "checkmark")
                .font(.system(size: 60, weight: .bold))
                .foregroundColor(.white)
        }
        .scaleEffect(animateStats ? 1.0 : 0.5)
        .opacity(animateStats ? 1.0 : 0)
    }
    
    // MARK: - Statistics Card
    
    private var statisticsCard: some View {
        VStack(spacing: 25) {
            // 删除统计
            StatRow(
                icon: "trash.fill",
                label: "已删除",
                value: viewModel.deletedCount,
                color: .red,
                isAnimated: animateStats
            )
            
            Divider()
            
            // 保留统计
            StatRow(
                icon: "hand.thumbsup.fill",
                label: "已保留",
                value: viewModel.keptCount,
                color: .green,
                isAnimated: animateStats
            )
            
            Divider()
            
            // 总计
            StatRow(
                icon: "photo.fill",
                label: "审阅总数",
                value: viewModel.totalPhotos,
                color: .blue,
                isAnimated: animateStats
            )
        }
        .padding(25)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }
    
    // MARK: - Details Section
    
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.purple)
                Text("会话详情")
                    .font(.headline)
            }
            
            VStack(spacing: 12) {
                DetailRow(
                    title: "删除率",
                    value: "\(deletionPercentage)%",
                    icon: "percent"
                )
                
                DetailRow(
                    title: "保留率",
                    value: "\(keepPercentage)%",
                    icon: "percent"
                )
                
                if viewModel.pendingDeletionCount > 0 {
                    DetailRow(
                        title: "待删除照片",
                        value: "\(viewModel.pendingDeletionCount) 张",
                        icon: "trash.circle"
                    )
                }
                
                DetailRow(
                    title: "完成会话次数",
                    value: "\(viewModel.sessionCounter)",
                    icon: "number"
                )
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.purple.opacity(0.05))
            )
        }
        .padding(.top, 10)
    }
    
    // MARK: - Start New Session Button
    
    private var startNewSessionButton: some View {
        VStack(spacing: 12) {
            // 如果有待删除照片，显示提示
            if viewModel.pendingDeletionCount > 0 {
                Text("将批量删除 \(viewModel.pendingDeletionCount) 张照片")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            
            Button(action: {
                handleStartNewSession()
            }) {
                HStack(spacing: 12) {
                    if viewModel.pendingDeletionCount > 0 {
                        Image(systemName: "trash.circle.fill")
                            .font(.title3)
                        Text("确认删除并开始新任务")
                            .font(.headline)
                    } else {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .font(.title2)
                        Text("开始新任务")
                            .font(.headline)
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(
                        colors: viewModel.pendingDeletionCount > 0 ? [.orange, .red] : [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(15)
                .shadow(color: (viewModel.pendingDeletionCount > 0 ? Color.orange : Color.blue).opacity(0.3), radius: 10, x: 0, y: 5)
            }
            .disabled(showingAd)
        }
    }
    
    // MARK: - Computed Properties
    
    private var deletionPercentage: Int {
        guard viewModel.totalPhotos > 0 else { return 0 }
        return Int((Double(viewModel.deletedCount) / Double(viewModel.totalPhotos)) * 100)
    }
    
    private var keepPercentage: Int {
        guard viewModel.totalPhotos > 0 else { return 0 }
        return Int((Double(viewModel.keptCount) / Double(viewModel.totalPhotos)) * 100)
    }
    
    // MARK: - Actions
    
    private func handleStartNewSession() {
        // 先执行待删除照片的批量删除
        print("准备执行批量删除...")
        
        viewModel.executePendingDeletions { [self] success in
            if success {
                print("批量删除完成")
            } else {
                print("批量删除失败，但继续流程")
            }
            
            // 删除完成后，检查是否需要显示广告
            if viewModel.shouldShowAd() {
                print("达到广告阈值，准备显示广告...")
                showingAd = true
                
                // 显示广告
                AdManager.shared.showInterstitialAd { [self] in
                    print("广告已关闭，准备开始新会话")
                    showingAd = false
                    
                    // 广告关闭后，重置会话并返回设置界面
                    DispatchQueue.main.async {
                        viewModel.resetSession()
                    }
                }
            } else {
                // 不需要广告，直接重置会话
                print("未达到广告阈值，直接开始新会话")
                viewModel.resetSession()
            }
        }
    }
}

// MARK: - Supporting Views

struct StatRow: View {
    let icon: String
    let label: String
    let value: Int
    let color: Color
    let isAnimated: Bool
    
    var body: some View {
        HStack {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
            }
            
            Text(label)
                .font(.headline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text("\(value)")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .scaleEffect(isAnimated ? 1.0 : 0.5)
                .opacity(isAnimated ? 1.0 : 0)
        }
    }
}

struct DetailRow: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Preview

#Preview {
    SessionCompleteView(viewModel: {
        let vm = TidySessionViewModel()
        vm.deletedCount = 15
        vm.keptCount = 35
        return vm
    }())
}

