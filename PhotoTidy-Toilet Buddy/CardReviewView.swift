//
//  CardReviewView.swift
//  PhotoTidy-Toilet Buddy
//
//  Created on 2025-10-22.
//

import SwiftUI
import Photos

/// 核心照片审阅视图 - 卡片式交互
struct CardReviewView: View {
    @ObservedObject var viewModel: TidySessionViewModel
    @Environment(\.dismiss) var dismiss
    
    // MARK: - State Properties
    
    // 手势状态
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging: Bool = false
    
    // 缩放状态 (A-01 双击放大)
    @State private var isZoomed: Bool = false
    @State private var zoomScale: CGFloat = 1.0
    
    // 动画状态
    @State private var isDeleting: Bool = false
    @State private var deleteDirection: CGFloat = -1 // -1 左飞出, 1 右飞出
    @State private var showRedFlash: Bool = false
    @State private var showGreenFlash: Bool = false
    
    // 照片加载
    @State private var currentImage: UIImage?
    @State private var isLoadingImage: Bool = true
    
    // MARK: - Constants
    
    private let dragThreshold: CGFloat = 100
    private let cardRotationFactor: Double = 0.05
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景
                Color.black.opacity(0.95)
                    .ignoresSafeArea()
                
                // 红色闪烁覆盖层
                if showRedFlash {
                    Color.red.opacity(0.3)
                        .ignoresSafeArea()
                        .transition(.opacity)
                }
                
                // 绿色闪烁覆盖层
                if showGreenFlash {
                    Color.green.opacity(0.2)
                        .ignoresSafeArea()
                        .transition(.opacity)
                }
                
                VStack(spacing: 0) {
                    // 顶部状态栏
                    topStatusBar
                        .padding(.top, 10)
                    
                    Spacer()
                    
                    // 照片卡片
                    photoCardView
                        .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    // 底部决策按钮 (F-06)
                    bottomActionButtons
                        .padding(.bottom, 30)
                }
            }
            .navigationBarHidden(true)
            .statusBar(hidden: false)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            loadCurrentPhoto()
        }
        .onChange(of: viewModel.currentIndex) { _ in
            loadCurrentPhoto()
            resetAnimationStates()
        }
    }
    
    // MARK: - Top Status Bar
    
    private var topStatusBar: some View {
        VStack(spacing: 12) {
            // 进度条和关闭按钮
            HStack {
                Button(action: {
                    viewModel.endSession()
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                // 进度指示器
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(viewModel.currentIndex + 1) / \(viewModel.totalPhotos)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // 背景
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white.opacity(0.2))
                            
                            // 进度
                            RoundedRectangle(cornerRadius: 2)
                                .fill(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * CGFloat(viewModel.progress))
                        }
                    }
                    .frame(height: 4)
                }
                .frame(width: 120)
            }
            .padding(.horizontal, 20)
            
            // 照片信息和撤销按钮
            HStack(spacing: 15) {
                // 照片信息
                if let photo = viewModel.currentPhoto {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(formatDate(photo.asset.creationDate))
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.9))
                        
                        HStack(spacing: 8) {
                            Text("\(photo.asset.pixelWidth) × \(photo.asset.pixelHeight)")
                                .font(.caption2)
                            
                            if photo.asset.mediaType == .video {
                                Image(systemName: "video.fill")
                                    .font(.caption2)
                                Text(formatDuration(photo.asset.duration))
                                    .font(.caption2)
                            }
                        }
                        .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                Spacer()
                
                // 统计信息
                HStack(spacing: 15) {
                    StatBadgeCompact(icon: "trash.fill", count: viewModel.deletedCount, color: .red)
                    StatBadgeCompact(icon: "hand.thumbsup.fill", count: viewModel.keptCount, color: .green)
                }
                
                // 撤销按钮 (A-03)
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        viewModel.undoLastDeletion()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.uturn.backward.circle.fill")
                            .font(.title3)
                        Text("撤销")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(viewModel.canUndo ? .orange : .gray)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(viewModel.canUndo ? 0.15 : 0.05))
                    )
                }
                .disabled(!viewModel.canUndo)
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Photo Card View
    
    private var photoCardView: some View {
        GeometryReader { geometry in
            ZStack {
                if let image = currentImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: Color.black.opacity(0.5), radius: 20, x: 0, y: 10)
                        .scaleEffect(isZoomed ? 2.0 : 1.0 + (abs(dragOffset.width) / 1000))
                        .rotationEffect(.degrees(isDragging ? Double(dragOffset.width) * cardRotationFactor : 0))
                        .offset(
                            x: isDeleting ? deleteDirection * geometry.size.width * 1.5 : dragOffset.width,
                            y: isDeleting ? -50 : dragOffset.height * 0.2
                        )
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isZoomed)
                        .animation(
                            isDeleting ? .spring(response: 0.5, dampingFraction: 0.8) : .spring(response: 0.3, dampingFraction: 0.7),
                            value: isDeleting
                        )
                        .opacity(isDeleting ? 0 : 1 - Double(abs(dragOffset.width)) / 500)
                        // 双击放大手势 (A-01)
                        .onTapGesture(count: 2) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                isZoomed.toggle()
                            }
                        }
                        // 拖拽手势用于导航
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    if !isZoomed {
                                        isDragging = true
                                        dragOffset = value.translation
                                    }
                                }
                                .onEnded { value in
                                    handleDragEnd(translation: value.translation)
                                }
                        )
                    
                    // 拖拽方向提示
                    if isDragging && !isZoomed {
                        VStack {
                            if dragOffset.width > 50 {
                                // 右滑提示 - 上一张
                                HStack {
                                    VStack {
                                        Image(systemName: "chevron.left")
                                            .font(.title)
                                            .foregroundColor(.blue)
                                        Text("上一张")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    }
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.blue.opacity(0.2))
                                    )
                                    Spacer()
                                }
                            } else if dragOffset.width < -50 {
                                // 左滑提示 - 下一张
                                HStack {
                                    Spacer()
                                    VStack {
                                        Image(systemName: "chevron.right")
                                            .font(.title)
                                            .foregroundColor(.purple)
                                        Text("下一张")
                                            .font(.caption)
                                            .foregroundColor(.purple)
                                    }
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.purple.opacity(0.2))
                                    )
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.opacity)
                    }
                    
                } else if isLoadingImage {
                    VStack(spacing: 20) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        Text("加载中...")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "photo.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.3))
                        Text("无法加载照片")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .aspectRatio(4/3, contentMode: .fit)
    }
    
    // MARK: - Bottom Action Buttons (F-06)
    
    private var bottomActionButtons: some View {
        HStack(spacing: 30) {
            // 删除按钮（左侧）
            Button(action: {
                handleDeleteAction()
            }) {
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.red, .red.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 70, height: 70)
                            .shadow(color: .red.opacity(0.4), radius: 10, x: 0, y: 5)
                        
                        Image(systemName: "trash.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                    }
                    
                    Text("删除")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(ScaleButtonStyle())
            
            Spacer()
            
            // 保留按钮（右侧）
            Button(action: {
                handleKeepAction()
            }) {
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.green, .green.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 70, height: 70)
                            .shadow(color: .green.opacity(0.4), radius: 10, x: 0, y: 5)
                        
                        Image(systemName: "hand.thumbsup.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                    }
                    
                    Text("保留")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 50)
    }
    
    // MARK: - Actions
    
    private func handleDragEnd(translation: CGSize) {
        isDragging = false
        
        // 左滑 - 下一张
        if translation.width < -dragThreshold {
            withAnimation(.spring(response: 0.3)) {
                viewModel.moveToNextPhoto()
            }
        }
        // 右滑 - 上一张
        else if translation.width > dragThreshold {
            withAnimation(.spring(response: 0.3)) {
                viewModel.moveToPreviousPhoto()
            }
        }
        
        // 重置偏移
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            dragOffset = .zero
        }
    }
    
    private func handleDeleteAction() {
        guard !isDeleting else { return }
        
        // 视觉反馈动画
        isDeleting = true
        deleteDirection = -1 // 向左飞出
        
        // 红色闪烁
        withAnimation(.easeOut(duration: 0.2)) {
            showRedFlash = true
        }
        
        // 震动反馈
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // 延迟执行删除
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            viewModel.deleteCurrentPhoto()
            
            // 重置动画状态
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation {
                    showRedFlash = false
                }
                resetAnimationStates()
            }
        }
    }
    
    private func handleKeepAction() {
        // 绿色闪烁
        withAnimation(.easeOut(duration: 0.2)) {
            showGreenFlash = true
        }
        
        // 震动反馈
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        // 延迟执行保留
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            viewModel.keepCurrentPhoto()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation {
                    showGreenFlash = false
                }
            }
        }
    }
    
    private func loadCurrentPhoto() {
        isLoadingImage = true
        currentImage = nil
        
        guard let photo = viewModel.currentPhoto else {
            isLoadingImage = false
            return
        }
        
        viewModel.getCurrentPhotoThumbnail(targetSize: CGSize(width: 1200, height: 1200)) { image in
            withAnimation(.easeIn(duration: 0.2)) {
                self.currentImage = image
                self.isLoadingImage = false
            }
        }
    }
    
    private func resetAnimationStates() {
        dragOffset = .zero
        isDragging = false
        isZoomed = false
        isDeleting = false
        showRedFlash = false
        showGreenFlash = false
    }
    
    // MARK: - Helper Methods
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "未知日期" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Supporting Views

struct StatBadgeCompact: View {
    let icon: String
    let count: Int
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text("\(count)")
                .font(.caption)
                .fontWeight(.semibold)
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.2))
        )
    }
}

// 按钮缩放样式
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    CardReviewView(viewModel: TidySessionViewModel())
}

