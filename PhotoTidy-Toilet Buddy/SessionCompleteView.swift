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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    @State private var showingAd = false
    @State private var animateStats = false
    
    // 删除进度状态
    @State private var isDeletingPhotos = false
    @State private var deleteProgress: Int = 0
    @State private var deleteTotalCount: Int = 0
    
    // Review待删除照片状态
    @State private var showReviewDeletions = false
    
    // MARK: - Device Detection
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular && verticalSizeClass == .regular
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: isIPad ? 40 : 30) {
                    Spacer()
                        .frame(height: isIPad ? 60 : 40)
                    
                    // 成功图标
                    successIcon
                    
                    // 标题
                    VStack(spacing: isIPad ? 15 : 10) {
                        Text(L10n.SessionComplete.title)
                            .font(.system(size: isIPad ? 48 : 36, weight: .bold, design: .rounded))
                        
                        Text(L10n.SessionComplete.subtitle)
                            .font(.system(size: isIPad ? 22 : 18))
                            .foregroundColor(.secondary)
                    }
                    
                    // 开始新任务按钮
                    startNewSessionButton
                        .padding(.horizontal, isIPad ? 50 : 30)
                    
                    // 统计卡片
                    statisticsCard
                        .padding(.horizontal, isIPad ? 40 : 20)
                    
                    // Review待删除照片卡片
                    if viewModel.pendingDeletionCount > 0 {
                        reviewDeletionsCard
                            .padding(.horizontal, isIPad ? 40 : 20)
                    }
                    
                    // 详细信息
                    detailsSection
                        .padding(.horizontal, isIPad ? 40 : 20)
                    
                    Spacer()
                        .frame(height: isIPad ? 50 : 30)
                }
            }
            .navigationBarHidden(true)
            .overlay {
                // 删除进度覆盖层
                if isDeletingPhotos {
                    deletionProgressOverlay
                }
            }
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
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $showReviewDeletions) {
            ReviewDeletionsView(viewModel: viewModel)
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
                .frame(width: isIPad ? 160 : 120, height: isIPad ? 160 : 120)
                .shadow(color: .green.opacity(0.3), radius: isIPad ? 25 : 20, x: 0, y: isIPad ? 12 : 10)
            
            Image(systemName: "checkmark")
                .font(.system(size: isIPad ? 80 : 60, weight: .bold))
                .foregroundColor(.white)
        }
        .scaleEffect(animateStats ? 1.0 : 0.5)
        .opacity(animateStats ? 1.0 : 0)
    }
    
    // MARK: - Statistics Card
    
    private var statisticsCard: some View {
        VStack(spacing: isIPad ? 35 : 25) {
            // 删除统计
            StatRow(
                icon: "trash.fill",
                label: L10n.SessionComplete.deleted,
                value: viewModel.deletedCount,
                color: .red,
                isAnimated: animateStats
            )
            
            Divider()
            
            // 保留统计
            StatRow(
                icon: "hand.thumbsup.fill",
                label: L10n.SessionComplete.kept,
                value: viewModel.keptCount,
                color: .green,
                isAnimated: animateStats
            )
            
            Divider()
            
            // 总计
            StatRow(
                icon: "photo.fill",
                label: L10n.SessionComplete.total,
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
    
    // MARK: - Review Deletions Card
    
    private var reviewDeletionsCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.title3)
                Text(L10n.ReviewDeletions.cardTitle)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.ReviewDeletions.willDeleteCount(viewModel.pendingDeletionCount))
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        if viewModel.estimatedStorageToFree > 0 {
                            Text(L10n.ReviewDeletions.storageToFree(viewModel.formattedStorageToFree))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                }
                
                Button(action: {
                    showReviewDeletions = true
                }) {
                    HStack {
                        Image(systemName: "eye.fill")
                            .font(.body)
                        Text(L10n.Button.reviewDeletions)
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.orange.opacity(0.05))
            )
        }
        .padding(.top, 5)
    }
    
    // MARK: - Details Section
    
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.purple)
                Text(L10n.SessionComplete.details)
                    .font(.headline)
            }
            
            VStack(spacing: 12) {
                DetailRow(
                    title: L10n.SessionComplete.deletionRate,
                    value: "\(deletionPercentage)%",
                    icon: "percent"
                )
                
                DetailRow(
                    title: L10n.SessionComplete.keepRate,
                    value: "\(keepPercentage)%",
                    icon: "percent"
                )
                
                if viewModel.pendingDeletionCount > 0 {
                    DetailRow(
                        title: L10n.SessionComplete.pendingDeletion,
                        value: L10n.SessionComplete.pendingDeletionCount(viewModel.pendingDeletionCount),
                        icon: "trash.circle"
                    )
                    
                    // 存储空间估算
                    if viewModel.estimatedStorageToFree > 0 {
                        DetailRow(
                            title: L10n.SessionComplete.estimatedSpace,
                            value: viewModel.formattedStorageToFree,
                            icon: "arrow.down.circle"
                        )
                    }
                }
                
                DetailRow(
                    title: L10n.SessionComplete.sessionCount,
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
                Text(L10n.SessionComplete.willDeleteCount(viewModel.pendingDeletionCount))
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
                        Text(L10n.Button.confirmDeleteAndStart)
                            .font(.headline)
                    } else {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .font(.title2)
                        Text(L10n.Button.startNew)
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
            .disabled(showingAd || isDeletingPhotos)
        }
    }
    
    // MARK: - Deletion Progress Overlay
    
    private var deletionProgressOverlay: some View {
        ZStack {
            // 半透明背景
            Color.black.opacity(0.6)
                .ignoresSafeArea()
            
            // 进度卡片
            VStack(spacing: 25) {
                // 图标
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.orange, .red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "trash.fill")
                        .font(.system(size: 35))
                        .foregroundColor(.white)
                }
                
                // 标题
                Text(L10n.Loading.deleting)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                // 进度信息
                VStack(spacing: 12) {
                    Text("\(deleteProgress) / \(deleteTotalCount)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    // 进度条
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // 背景
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.3))
                            
                            // 进度
                            RoundedRectangle(cornerRadius: 10)
                                .fill(
                                    LinearGradient(
                                        colors: [.orange, .red],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * CGFloat(deleteProgress) / CGFloat(max(deleteTotalCount, 1)))
                        }
                    }
                    .frame(height: 20)
                    
                    // 百分比
                    Text("\(Int((Double(deleteProgress) / Double(max(deleteTotalCount, 1))) * 100))%")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                // 提示文字
                Text(L10n.Loading.pleaseWait)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(Color(.systemBackground).opacity(0.95))
                    .shadow(color: .black.opacity(0.3), radius: 30, x: 0, y: 15)
            )
            .padding(30)
        }
        .transition(.opacity)
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
        
        // 显示删除进度
        if viewModel.pendingDeletionCount > 0 {
            withAnimation(.easeInOut(duration: 0.3)) {
                isDeletingPhotos = true
                deleteProgress = 0
                deleteTotalCount = viewModel.pendingDeletionCount
            }
        }
        
        viewModel.executePendingDeletions(
            progressHandler: { current, total in
                // 更新进度
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.deleteProgress = current
                    self.deleteTotalCount = total
                }
            },
            completion: { [self] success in
                // 隐藏删除进度
                withAnimation(.easeInOut(duration: 0.3)) {
                    isDeletingPhotos = false
                }
                
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
        )
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
    let vm = TidySessionViewModel()
    // 注意：在 Preview 中，deletedCount 和 keptCount 基于 photosToReview 的状态计算
    // 如果需要测试特定数值，需要在实际设备上运行
    return SessionCompleteView(viewModel: vm)
}

