//
//  CardReviewView.swift
//  PhotoTidy-Toilet Buddy
//
//  Created on 2025-10-22.
//

import SwiftUI
import Photos
import PhotosUI
import AVFoundation
import AVKit

/// 分享结果处理
class ShareResultHandler: ObservableObject {
    @Published var showSuccessToast: Bool = false
    @Published var showErrorAlert: Bool = false
    @Published var errorMessage: String = ""
    
    func handleShareResult(completed: Bool, error: Error?) {
        if let error = error {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        } else if completed {
            showSuccessToast = true
        }
    }
}

/// 系统分享面板的SwiftUI封装
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    let excludedActivityTypes: [UIActivity.ActivityType]?
    
    init(items: [Any], excludedActivityTypes: [UIActivity.ActivityType]? = nil) {
        self.items = items
        self.excludedActivityTypes = excludedActivityTypes
    }
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let activityViewController = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        
        if let excludedActivityTypes = excludedActivityTypes {
            activityViewController.excludedActivityTypes = excludedActivityTypes
        }
        
        // 设置完成回调
        activityViewController.completionWithItemsHandler = { activityType, completed, returnedItems, error in
            if let error = error {
                print("❌ 分享失败: \(error.localizedDescription)")
            } else if completed {
                print("✅ 分享成功: \(activityType?.rawValue ?? "未知")")
            } else {
                print("ℹ️ 分享已取消")
            }
        }
        
        return activityViewController
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // 不需要更新
    }
}

/// 分享数据准备器
class ShareDataPreparer {
    
    /// 准备当前照片的分享数据
    /// - Parameter photo: 当前照片对象
    /// - Returns: 分享数据数组
    static func prepareShareData(from photo: TidyPhoto) async -> [Any] {
        var shareItems: [Any] = []
        
        let asset = photo.asset
        
        switch asset.mediaType {
        case .image:
            if asset.mediaSubtypes.contains(.photoLive) {
                // Live Photo
                if let livePhoto = await loadLivePhotoForSharing(asset: asset) {
                    shareItems.append(livePhoto)
                    print("📤 准备分享 Live Photo")
                }
            } else {
                // 普通照片
                if let image = await loadImageForSharing(asset: asset) {
                    shareItems.append(image)
                    print("📤 准备分享普通照片")
                }
            }
            
        case .video:
            // 视频
            if let videoURL = await loadVideoForSharing(asset: asset) {
                shareItems.append(videoURL)
                print("📤 准备分享视频文件")
            }
            
        default:
            print("⚠️ 不支持的媒体类型: \(asset.mediaType.rawValue)")
        }
        
        return shareItems
    }
    
    /// 为分享加载图片
    private static func loadImageForSharing(asset: PHAsset) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false
            
            let targetSize = CGSize(width: 2000, height: 2000)
            
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
    
    /// 为分享加载 Live Photo
    private static func loadLivePhotoForSharing(asset: PHAsset) async -> PHLivePhoto? {
        return await withCheckedContinuation { continuation in
            let options = PHLivePhotoRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            
            let targetSize = CGSize(width: 2000, height: 2000)
            
            PHImageManager.default().requestLivePhoto(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { livePhoto, _ in
                continuation.resume(returning: livePhoto)
            }
        }
    }
    
    /// 为分享加载视频
    private static func loadVideoForSharing(asset: PHAsset) async -> URL? {
        return await withCheckedContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            
            PHImageManager.default().requestAVAsset(
                forVideo: asset,
                options: options
            ) { avAsset, _, _ in
                if let urlAsset = avAsset as? AVURLAsset {
                    continuation.resume(returning: urlAsset.url)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

/// 核心照片审阅视图 - 卡片式交互
struct CardReviewView: View {
    @ObservedObject var viewModel: TidySessionViewModel
    @Environment(\.dismiss) var dismiss
    
    // MARK: - State Properties
    
    // 手势状态
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging: Bool = false
    
    // 缩放状态 (A-01 双击放大 + 捏合缩放)
    @State private var isZoomed: Bool = false
    @State private var currentScale: CGFloat = 1.0
    @State private var finalScale: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero
    @State private var finalPanOffset: CGSize = .zero
    
    // 动画状态
    @State private var isDeleting: Bool = false
    @State private var deleteDirection: CGFloat = -1 // -1 左飞出, 1 右飞出
    @State private var showRedFlash: Bool = false
    @State private var showGreenFlash: Bool = false
    
    // 照片加载
    @State private var currentImage: UIImage?
    @State private var isLoadingImage: Bool = true
    @State private var loadProgress: Double = 0.0
    @State private var loadTask: Task<Void, Never>?
    
    // Live Photo 支持
    @State private var currentLivePhoto: PHLivePhoto?
    @State private var isPlayingLive: Bool = false
    
    // 视频支持
    @State private var videoPlayer: AVPlayer?
    @State private var isPlayingVideo: Bool = false
    
    // 媒体类型
    @State private var currentMediaType: MediaType = .image
    
    // 预加载缓存
    @State private var preloadedImages: [Int: UIImage] = [:]
    @State private var preloadTasks: [Int: Task<Void, Never>] = [:]
    
    // 错误处理
    @State private var consecutiveFailures: Int = 0
    @State private var showBatchSkipAlert: Bool = false
    
    // 动画任务管理
    @State private var animationTask: Task<Void, Never>?
    
    // 分享功能
    @State private var showShareSheet: Bool = false
    @State private var shareItems: [Any] = []
    
    // MARK: - Constants
    
    private let dragThreshold: CGFloat = 100
    private let cardRotationFactor: Double = 0.05
    
    // 动态计算最优缩略图尺寸（根据屏幕）
    private var optimalThumbnailSize: CGSize {
        let scale = UIScreen.main.scale
        let screenWidth = UIScreen.main.bounds.width
        let maxSize: CGFloat = 1200
        let targetWidth = min(screenWidth * scale, maxSize)
        return CGSize(width: targetWidth, height: targetWidth)
    }
    
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
                    
                    // 照片卡片 - 占据主要空间
                    photoCardView
                        .padding(.horizontal, 5)
                        .padding(.vertical, 15)
                    
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
            preloadNextPhotos()
        }
        .onChange(of: viewModel.currentIndex) { _ in
            loadCurrentPhoto()
            preloadNextPhotos()
            resetAnimationStates()
        }
        .onDisappear {
            // 清理所有任务
            cleanupTasks()
        }
        .alert(L10n.Error.consecutiveFailures, isPresented: $showBatchSkipAlert) {
            Button(L10n.Button.continueTrying, role: .cancel) {
                consecutiveFailures = 0
            }
            Button(L10n.Button.skipAllFailed) {
                skipFailedPhotos()
            }
        } message: {
            Text(L10n.Error.consecutiveFailuresMessage(consecutiveFailures))
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: shareItems)
        }
    }
    
    // MARK: - Top Status Bar
    
    private var topStatusBar: some View {
        VStack(spacing: 12) {
            // 进度条和智能按钮（关闭/完成）
            HStack {
                // 智能按钮：最后一张显示"完成"，否则显示"关闭"
                Button(action: {
                    viewModel.endSession()
                    dismiss()
                }) {
                    if isLastPhoto {
                        // 完成按钮（绿色，大号）
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title)
                            Text(L10n.Button.done)
                                .font(.headline)
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.green)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.green.opacity(0.2))
                        )
                    } else {
                        // 关闭按钮（灰色，带文字）
                        HStack(spacing: 8) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                            Text(L10n.Button.cancel)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.15))
                        )
                    }
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
                            // 分辨率信息
                            HStack(spacing: 2) {
                                Image(systemName: "photo")
                                    .font(.caption2)
                                Text("\(photo.asset.pixelWidth) × \(photo.asset.pixelHeight)")
                                    .font(.caption2)
                            }
                            
                            // 文件大小信息（如果是视频）
                            if photo.asset.mediaType == .video {
                                Divider()
                                    .frame(height: 12)
                                HStack(spacing: 2) {
                                    Image(systemName: "video.fill")
                                        .font(.caption2)
                                    Text(formatDuration(photo.asset.duration))
                                        .font(.caption2)
                                }
                            }
                            
                            // 媒体类型标记
                            if photo.asset.mediaSubtypes.contains(.photoScreenshot) {
                                Divider()
                                    .frame(height: 12)
                                HStack(spacing: 2) {
                                    Image(systemName: "camera.viewfinder")
                                        .font(.caption2)
                                    Text(L10n.Review.screenshot)
                                        .font(.caption2)
                                }
                            } else if photo.asset.mediaSubtypes.contains(.photoLive) {
                                Divider()
                                    .frame(height: 12)
                                HStack(spacing: 2) {
                                    Image(systemName: "livephoto")
                                        .font(.caption2)
                                    Text(L10n.Review.live)
                                        .font(.caption2)
                                }
                            } else if photo.asset.mediaSubtypes.contains(.photoPanorama) {
                                Divider()
                                    .frame(height: 12)
                                HStack(spacing: 2) {
                                    Image(systemName: "pano")
                                        .font(.caption2)
                                    Text(L10n.Review.panorama)
                                        .font(.caption2)
                                }
                            }
                        }
                        .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                Spacer()
                
                // 统计信息 - 只显示已标记删除的数量
                HStack(spacing: 8) {
                    Image(systemName: "trash.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                    Text("\(viewModel.deletedCount)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Photo Card View
    
    private var photoCardView: some View {
        GeometryReader { geometry in
            ZStack {
                // 根据媒体类型渲染不同的内容
                mediaContentView(geometry: geometry)
                
                // 已删除照片的视觉反馈
                if isCurrentPhotoMarked && !isLoadingImage {
                    deletedPhotoOverlay
                }
                
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
                                    Text(L10n.Review.previous)
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
                                    Text(L10n.Review.next)
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
                
                // 放大模式提示
                if isZoomed {
                    VStack {
                        HStack {
                            Spacer()
                            VStack(spacing: 4) {
                                HStack(spacing: 4) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.caption2)
                                    Text(L10n.Review.zoomLevel(finalScale * currentScale))
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.black.opacity(0.6))
                                )
                                
                                Text(L10n.Review.doubleTapToExit)
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .padding()
                        }
                        Spacer()
                    }
                    .transition(.opacity)
                    .allowsHitTesting(false)
                }
                
                if isLoadingImage {
                    VStack(spacing: 20) {
                        ProgressView(value: loadProgress, total: 1.0)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        
                        VStack(spacing: 8) {
                            Text(L10n.Loading.general)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                            
                            if loadProgress > 0 && loadProgress < 1.0 {
                                Text("\(Int(loadProgress * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                    }
                } else if currentImage == nil && currentLivePhoto == nil && videoPlayer == nil {
                    // 加载失败，显示错误和重试（只有真的没有任何内容时才显示）
                    VStack(spacing: 25) {
                        ZStack {
                            Circle()
                                .fill(Color.red.opacity(0.2))
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.red.opacity(0.8))
                        }
                        
                        VStack(spacing: 10) {
                            Text(L10n.Error.photoLoad)
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text(L10n.Error.photoDeletedOrCorrupted)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                        
                        HStack(spacing: 15) {
                            // 重试按钮
                            Button(action: {
                                loadCurrentPhoto()
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.subheadline)
                                    Text(L10n.Button.retry)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.orange)
                                )
                            }
                            
                            // 跳过按钮
                            Button(action: {
                                viewModel.moveToNextPhoto()
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "forward.fill")
                                        .font(.subheadline)
                                    Text(L10n.Button.skip)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.gray)
                                )
                            }
                        }
                    }
                    .padding()
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Media Content View
    
    /// 根据媒体类型渲染不同的内容视图
    @ViewBuilder
    private func mediaContentView(geometry: GeometryProxy) -> some View {
        Group {
            switch currentMediaType {
            case .livePhoto:
                // Live Photo 渲染
                if let livePhoto = currentLivePhoto {
                    LivePhotoView(livePhoto: livePhoto, isPlaying: $isPlayingLive)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: Color.black.opacity(0.5), radius: 20, x: 0, y: 10)
                        .overlay(
                            // Live Photo 长按提示
                            VStack {
                                HStack {
                                    Spacer()
                                    HStack(spacing: 4) {
                                        Image(systemName: "livephoto")
                                            .font(.caption2)
                                        Text(isPlayingLive ? L10n.Review.playing : L10n.Review.longPressToPlay)
                                            .font(.caption2)
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(isPlayingLive ? Color.green.opacity(0.8) : Color.black.opacity(0.6))
                                    )
                                    .padding()
                                }
                                Spacer()
                            }
                        )
                        .onLongPressGesture(minimumDuration: 0.1) {
                            isPlayingLive = true
                        }
                        .applyMediaTransforms(
                            isZoomed: isZoomed,
                            currentScale: currentScale,
                            finalScale: finalScale,
                            panOffset: panOffset,
                            finalPanOffset: finalPanOffset,
                            dragOffset: dragOffset,
                            isDragging: isDragging,
                            isDeleting: isDeleting,
                            deleteDirection: deleteDirection,
                            cardRotationFactor: cardRotationFactor
                        )
                        .applyMediaGestures(
                            isZoomed: $isZoomed,
                            currentScale: $currentScale,
                            finalScale: $finalScale,
                            panOffset: $panOffset,
                            finalPanOffset: $finalPanOffset,
                            dragOffset: $dragOffset,
                            isDragging: $isDragging,
                            onMagnificationEnd: handleMagnificationEnd,
                            onPanEnd: handlePanEnd,
                            onDragEnd: handleDragEnd,
                            onDoubleTap: handleDoubleTap
                        )
                }
                
            case .video:
                // 视频渲染
                if let player = videoPlayer {
                    VideoPlayerControlView(player: player, isPlaying: $isPlayingVideo)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: Color.black.opacity(0.5), radius: 20, x: 0, y: 10)
                        .applyMediaTransforms(
                            isZoomed: false, // 视频不支持缩放
                            currentScale: 1.0,
                            finalScale: 1.0,
                            panOffset: .zero,
                            finalPanOffset: .zero,
                            dragOffset: dragOffset,
                            isDragging: isDragging,
                            isDeleting: isDeleting,
                            deleteDirection: deleteDirection,
                            cardRotationFactor: cardRotationFactor
                        )
                        .gesture(
                            // 视频只支持导航拖拽，不支持缩放
                            DragGesture()
                                .onChanged { value in
                                    if !isPlayingVideo { // 播放时禁用导航
                                        isDragging = true
                                        dragOffset = value.translation
                                    }
                                }
                                .onEnded { value in
                                    if !isPlayingVideo {
                                        handleDragEnd(translation: value.translation)
                                    }
                                }
                        )
                }
                
            case .image, .panorama:
                // 普通照片/全景照片渲染
                if let image = currentImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: Color.black.opacity(0.5), radius: 20, x: 0, y: 10)
                        .applyMediaTransforms(
                            isZoomed: isZoomed,
                            currentScale: currentScale,
                            finalScale: finalScale,
                            panOffset: panOffset,
                            finalPanOffset: finalPanOffset,
                            dragOffset: dragOffset,
                            isDragging: isDragging,
                            isDeleting: isDeleting,
                            deleteDirection: deleteDirection,
                            cardRotationFactor: cardRotationFactor
                        )
                        .applyMediaGestures(
                            isZoomed: $isZoomed,
                            currentScale: $currentScale,
                            finalScale: $finalScale,
                            panOffset: $panOffset,
                            finalPanOffset: $finalPanOffset,
                            dragOffset: $dragOffset,
                            isDragging: $isDragging,
                            onMagnificationEnd: handleMagnificationEnd,
                            onPanEnd: handlePanEnd,
                            onDragEnd: handleDragEnd,
                            onDoubleTap: handleDoubleTap
                        )
                }
            }
        }
    }
    
    // MARK: - Bottom Action Buttons (导航 + 删除/恢复)
    
    private var bottomActionButtons: some View {
        HStack(spacing: 20) {
            // 上一张按钮（左侧）
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    viewModel.moveToPreviousPhoto()
                }
            }) {
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .blue.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 60, height: 60)
                            .shadow(color: .blue.opacity(0.4), radius: 10, x: 0, y: 5)
                        
                        Image(systemName: "chevron.left")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    Text(L10n.Button.previous)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(!viewModel.canMovePrevious)
            .opacity(viewModel.canMovePrevious ? 1.0 : 0.4)
            
            // 删除/恢复按钮（左中）
            Button(action: {
                handleToggleDeletion()
            }) {
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: isCurrentPhotoMarked ? [.orange, .orange.opacity(0.8)] : [.red, .red.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 70, height: 70)
                            .shadow(color: (isCurrentPhotoMarked ? Color.orange : Color.red).opacity(0.4), radius: 10, x: 0, y: 5)
                        
                        Image(systemName: isCurrentPhotoMarked ? "arrow.uturn.backward" : "trash.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                    }
                    
                    Text(isCurrentPhotoMarked ? L10n.Button.restore : L10n.Button.delete)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(ScaleButtonStyle())
            
            // 分享按钮（右中）
            Button(action: {
                handleShareAction()
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
                            .frame(width: 60, height: 60)
                            .shadow(color: .green.opacity(0.4), radius: 10, x: 0, y: 5)
                        
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    Text(L10n.Button.share)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(ScaleButtonStyle())
            
            // 下一张按钮（右侧）
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    viewModel.moveToNextPhoto()
                }
            }) {
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.purple, .purple.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 60, height: 60)
                            .shadow(color: .purple.opacity(0.4), radius: 10, x: 0, y: 5)
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    Text(L10n.Button.next)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(!viewModel.canMoveNext)
            .opacity(viewModel.canMoveNext ? 1.0 : 0.4)
        }
        .padding(.horizontal, 15)
    }
    
    /// 当前照片是否已标记删除
    private var isCurrentPhotoMarked: Bool {
        return viewModel.currentPhoto?.isMarkedForDeletion ?? false
    }
    
    /// 是否到达最后一张照片
    private var isLastPhoto: Bool {
        return viewModel.currentIndex == viewModel.totalPhotos - 1
    }
    
    // MARK: - Deleted Photo Overlay
    
    /// 已删除照片的覆盖层视觉效果
    private var deletedPhotoOverlay: some View {
        ZStack {
            // 半透明红色遮罩
            Color.red.opacity(0.35)
                .clipShape(RoundedRectangle(cornerRadius: 20))
            
            // 删除图标和文字
            VStack(spacing: 20) {
                // 大删除图标
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 120, height: 120)
                    
                    Circle()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "trash.fill")
                        .font(.system(size: 50, weight: .bold))
                        .foregroundColor(.red)
                }
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                
                // 状态文本
                VStack(spacing: 8) {
                    Text(L10n.Review.markedForDeletion)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text(L10n.Review.markedForDeletionHint)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .shadow(color: .black.opacity(0.5), radius: 5, x: 0, y: 2)
            }
        }
        .transition(.opacity)
        .allowsHitTesting(false)  // 不阻止手势交互
    }
    
    // MARK: - Actions
    
    /// 处理分享操作
    private func handleShareAction() {
        guard let currentPhoto = viewModel.currentPhoto else {
            print("⚠️ 没有当前照片可以分享")
            return
        }
        
        // 触觉反馈
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // 异步准备分享数据
        Task { @MainActor in
            let items = await ShareDataPreparer.prepareShareData(from: currentPhoto)
            
            if items.isEmpty {
                print("❌ 无法准备分享数据")
                return
            }
            
            shareItems = items
            showShareSheet = true
            print("✅ 分享数据准备完成，项目数量: \(items.count)")
        }
    }
    
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
    
    // MARK: - 缩放手势处理
    
    /// 双击放大/缩小
    private func handleDoubleTap() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if isZoomed {
                // 缩小到原始大小
                resetZoom()
            } else {
                // 放大到 2 倍
                isZoomed = true
                finalScale = 2.0
                currentScale = 1.0
            }
        }
    }
    
    /// 捏合缩放结束处理
    private func handleMagnificationEnd(scale: CGFloat) {
        // 合并缩放值
        let newScale = finalScale * scale
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            // 限制缩放范围：1.0 - 5.0
            if newScale < 1.0 {
                // 缩小到小于 1.0，恢复原始状态
                resetZoom()
            } else if newScale > 5.0 {
                // 超过最大值，限制到 5.0
                finalScale = 5.0
                currentScale = 1.0
                isZoomed = true
            } else {
                // 正常范围
                finalScale = newScale
                currentScale = 1.0
                isZoomed = newScale > 1.0
            }
        }
    }
    
    /// 平移结束处理（仅在放大状态）
    private func handlePanEnd(translation: CGSize) {
        // 合并平移偏移
        finalPanOffset.width += panOffset.width
        finalPanOffset.height += panOffset.height
        
        // 重置临时偏移
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            panOffset = .zero
            
            // 可选：限制平移范围，防止拖动太远
            // 这里允许自由平移，用户可以通过双击重置
        }
    }
    
    /// 重置缩放和平移
    private func resetZoom() {
        isZoomed = false
        currentScale = 1.0
        finalScale = 1.0
        panOffset = .zero
        finalPanOffset = .zero
    }
    
    /// 切换删除标记（删除或恢复）
    private func handleToggleDeletion() {
        // 取消之前的动画任务
        animationTask?.cancel()
        
        let isMarked = viewModel.currentPhoto?.isMarkedForDeletion ?? false
        
        if isMarked {
            // 当前已标记删除，点击恢复
            animationTask = Task { @MainActor in
                // 绿色闪烁（恢复反馈）
                withAnimation(.easeOut(duration: 0.15)) {
                    showGreenFlash = true
                }
                
                // 震动反馈
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                
                // 切换状态
                viewModel.toggleDeletionMark()
                
                // 等待动画
                try? await Task.sleep(nanoseconds: 150_000_000) // 0.15s
                
                guard !Task.isCancelled else { return }
                
                withAnimation {
                    showGreenFlash = false
                }
            }
        } else {
            // 当前未标记删除，点击删除
            animationTask = Task { @MainActor in
                // 红色闪烁（删除反馈）
                withAnimation(.easeOut(duration: 0.2)) {
                    showRedFlash = true
                }
                
                // 震动反馈
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                
                // 等待动画
                try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s
                
                guard !Task.isCancelled else { return }
                
                // 切换状态（会自动前进到下一张）
                viewModel.toggleDeletionMark()
                
                // 等待过渡
                try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s
                
                guard !Task.isCancelled else { return }
                
                withAnimation {
                    showRedFlash = false
                }
                resetAnimationStates()
            }
        }
    }
    
    private func loadCurrentPhoto() {
        // 取消之前的加载任务
        loadTask?.cancel()
        
        // ✅ 立即设置为加载中状态，避免在清空内容时误判为加载失败
        isLoadingImage = true
        
        // 重置进度
        loadProgress = 0.0
        
        // 重置媒体状态
        currentImage = nil
        currentLivePhoto = nil
        videoPlayer?.pause()
        videoPlayer = nil
        isPlayingVideo = false
        isPlayingLive = false
        
        guard let currentPhoto = viewModel.currentPhoto else {
            isLoadingImage = false
            return
        }
        
        // 确定媒体类型
        let asset = currentPhoto.asset
        if asset.mediaType == .video {
            currentMediaType = .video
            loadVideo(asset: asset)
        } else if asset.mediaSubtypes.contains(.photoLive) {
            currentMediaType = .livePhoto
            loadLivePhoto(asset: asset)
        } else {
            currentMediaType = .image
            loadRegularPhoto(asset: asset)
        }
    }
    
    /// 加载普通照片
    private func loadRegularPhoto(asset: PHAsset) {
        // 检查是否已经预加载
        if let cachedImage = preloadedImages[viewModel.currentIndex] {
            print("📸 使用预加载缓存，索引: \(viewModel.currentIndex)")
            withAnimation(.easeIn(duration: 0.2)) {
                self.currentImage = cachedImage
                self.isLoadingImage = false
                self.consecutiveFailures = 0
            }
            return
        }
        
        isLoadingImage = true
        
        // 启动加载任务
        loadTask = Task { @MainActor in
            do {
                let image = try await viewModel.loadCurrentPhotoAsync(
                    targetSize: optimalThumbnailSize,
                    progressHandler: { progress in
                        Task { @MainActor in
                            self.loadProgress = progress
                        }
                    }
                )
                
                guard !Task.isCancelled else {
                    print("⚠️ 加载任务已取消")
                    return
                }
                
                if let image = image {
                    withAnimation(.easeIn(duration: 0.2)) {
                        self.currentImage = image
                        self.isLoadingImage = false
                        self.consecutiveFailures = 0
                    }
                    print("✅ 照片加载成功，索引: \(viewModel.currentIndex)")
                } else {
                    handleLoadFailure()
                }
            } catch {
                guard !Task.isCancelled else { return }
                print("❌ 照片加载失败: \(error.localizedDescription)")
                handleLoadFailure()
            }
        }
    }
    
    /// 加载 Live Photo
    private func loadLivePhoto(asset: PHAsset) {
        isLoadingImage = true
        
        loadTask = Task { @MainActor in
            do {
                let livePhoto = try await viewModel.loadLivePhotoAsync(
                    asset: asset,
                    targetSize: optimalThumbnailSize,
                    progressHandler: { progress in
                        Task { @MainActor in
                            self.loadProgress = progress
                        }
                    }
                )
                
                guard !Task.isCancelled else {
                    print("⚠️ Live Photo 加载任务已取消")
                    return
                }
                
                if let livePhoto = livePhoto {
                    withAnimation(.easeIn(duration: 0.2)) {
                        self.currentLivePhoto = livePhoto
                        self.isLoadingImage = false
                        self.consecutiveFailures = 0
                    }
                    print("✅ Live Photo 加载成功，索引: \(viewModel.currentIndex)")
                } else {
                    handleLoadFailure()
                }
            } catch {
                guard !Task.isCancelled else { return }
                print("❌ Live Photo 加载失败: \(error.localizedDescription)")
                handleLoadFailure()
            }
        }
    }
    
    /// 加载视频
    private func loadVideo(asset: PHAsset) {
        isLoadingImage = true
        
        // 先清理旧的视频播放器资源
        if let oldPlayer = videoPlayer {
            oldPlayer.pause()
            oldPlayer.replaceCurrentItem(with: nil)
            print("🎬 已清理旧视频播放器")
        }
        
        loadTask = Task { @MainActor in
            do {
                let playerItem = try await viewModel.loadVideoAsync(asset: asset)
                
                guard !Task.isCancelled else {
                    print("⚠️ 视频加载任务已取消")
                    return
                }
                
                if let playerItem = playerItem {
                    let player = AVPlayer(playerItem: playerItem)
                    withAnimation(.easeIn(duration: 0.2)) {
                        self.videoPlayer = player
                        self.isLoadingImage = false
                        self.consecutiveFailures = 0
                    }
                    print("✅ 视频加载成功，索引: \(viewModel.currentIndex)")
                } else {
                    handleLoadFailure()
                }
            } catch {
                guard !Task.isCancelled else { return }
                print("❌ 视频加载失败: \(error.localizedDescription)")
                handleLoadFailure()
            }
        }
    }
    
    private func resetAnimationStates() {
        dragOffset = .zero
        isDragging = false
        isDeleting = false
        showRedFlash = false
        showGreenFlash = false
        
        // 重置缩放和平移状态
        resetZoom()
    }
    
    // MARK: - 预加载与缓存管理
    
    /// 预加载后续照片
    private func preloadNextPhotos() {
        let currentIndex = viewModel.currentIndex
        let totalPhotos = viewModel.totalPhotos
        
        // 预加载后面 2 张照片
        let indicesToPreload = [currentIndex + 1, currentIndex + 2]
        
        for index in indicesToPreload {
            guard index < totalPhotos,
                  preloadedImages[index] == nil,
                  preloadTasks[index] == nil else {
                continue
            }
            
            // 启动预加载任务
            let task = Task { @MainActor in
                if let image = await viewModel.loadPhotoAsync(at: index, targetSize: optimalThumbnailSize) {
                    guard !Task.isCancelled else { return }
                    preloadedImages[index] = image
                    print("📦 预加载完成，索引: \(index)")
                }
                preloadTasks[index] = nil
            }
            
            preloadTasks[index] = task
        }
        
        // 清理过期的缓存（距离当前位置超过 3 张）
        cleanupOldCache(currentIndex: currentIndex)
    }
    
    /// 清理过期的缓存
    private func cleanupOldCache(currentIndex: Int) {
        let keysToRemove = preloadedImages.keys.filter { abs($0 - currentIndex) > 3 }
        for key in keysToRemove {
            preloadedImages.removeValue(forKey: key)
            preloadTasks[key]?.cancel()
            preloadTasks.removeValue(forKey: key)
        }
        
        if !keysToRemove.isEmpty {
            print("🧹 清理过期缓存: \(keysToRemove.count) 张")
        }
    }
    
    /// 清理所有任务和资源
    private func cleanupTasks() {
        print("🧹 清理所有加载任务和资源")
        
        // 取消所有异步任务
        loadTask?.cancel()
        animationTask?.cancel()
        
        for (_, task) in preloadTasks {
            task.cancel()
        }
        preloadTasks.removeAll()
        preloadedImages.removeAll()
        
        // 清理视频播放器资源
        if let player = videoPlayer {
            player.pause()
            player.replaceCurrentItem(with: nil)
            videoPlayer = nil
            print("🎬 已清理视频播放器资源")
        }
        
        // 清理其他媒体资源
        currentImage = nil
        currentLivePhoto = nil
    }
    
    // MARK: - 错误处理
    
    /// 处理加载失败
    private func handleLoadFailure() {
        isLoadingImage = false
        consecutiveFailures += 1
        
        print("⚠️ 加载失败次数: \(consecutiveFailures)")
        
        // 连续失败 3 次，显示批量跳过选项
        if consecutiveFailures >= 3 {
            showBatchSkipAlert = true
        }
    }
    
    /// 跳过所有失败的照片
    private func skipFailedPhotos() {
        print("⏭️ 跳过所有加载失败的照片")
        
        // 简单策略：连续尝试加载下几张照片，直到成功
        Task { @MainActor in
            var attempts = 0
            let maxAttempts = 10
            
            while attempts < maxAttempts && viewModel.canMoveNext {
                viewModel.moveToNextPhoto()
                
                // 尝试加载
                if let _ = try? await viewModel.loadCurrentPhotoAsync(targetSize: optimalThumbnailSize) {
                    print("✅ 找到可加载的照片，索引: \(viewModel.currentIndex)")
                    consecutiveFailures = 0
                    break
                }
                
                attempts += 1
            }
            
            if attempts >= maxAttempts {
                print("❌ 跳过失败，可能所有照片都无法加载")
                viewModel.errorMessage = "无法加载更多照片，请检查相册权限。"
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return L10n.Review.unknownDate }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale.current  // 使用当前语言环境
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Supporting Views
// 注意：支持视图已提取到独立文件：
// - LivePhotoView.swift
// - VideoPlayerControlView.swift
// - MediaGestureModifiers.swift
// - MediaTypes.swift
// - SupportingViews.swift

// MARK: - Preview

#Preview {
    CardReviewView(viewModel: TidySessionViewModel())
}


