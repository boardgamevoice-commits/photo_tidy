//
//  ReviewDeletionsView.swift
//  PhotoTidy-Toilet Buddy
//
//  Created on 2025-10-23.
//  Review待删除照片视图 - 提供最后确认机会，避免误删
//

import SwiftUI
import Photos

/// Review待删除照片视图
struct ReviewDeletionsView: View {
    @ObservedObject var viewModel: TidySessionViewModel
    @Environment(\.dismiss) var dismiss
    
    // MARK: - State Properties
    
    @State private var thumbnailCache: [String: UIImage] = [:]
    @State private var selectedPhotoForPreview: TidyPhoto?
    @State private var showPhotoPreview: Bool = false
    
    // MARK: - Layout
    
    private let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 150), spacing: 8)
    ]
    
    // MARK: - Computed Properties
    
    /// 待删除的照片列表
    private var deletedPhotos: [TidyPhoto] {
        viewModel.photosToReview.filter { $0.isMarkedForDeletion }
    }
    
    /// 待删除照片数量
    private var deletionCount: Int {
        deletedPhotos.count
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if deletionCount == 0 {
                    // 空状态
                    emptyStateView
                } else {
                    // 照片网格
                    ScrollView {
                        VStack(spacing: 20) {
                            // 顶部提示卡片
                            infoCard
                                .padding(.horizontal)
                                .padding(.top, 10)
                            
                            // 照片网格
                            LazyVGrid(columns: columns, spacing: 8) {
                                ForEach(deletedPhotos) { photo in
                                    PhotoThumbnailCell(
                                        photo: photo,
                                        thumbnail: thumbnailCache[photo.id],
                                        onTap: {
                                            cancelDeletion(for: photo)
                                        },
                                        onPreview: {
                                            selectedPhotoForPreview = photo
                                            showPhotoPreview = true
                                        }
                                    )
                                    .onAppear {
                                        loadThumbnail(for: photo)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 100) // 为底部按钮留空间
                        }
                    }
                }
            }
            .navigationTitle(L10n.ReviewDeletions.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.Button.cancel) {
                        dismiss()
                    }
                }
                
                if deletionCount > 0 {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(L10n.ReviewDeletions.cancelAll) {
                            cancelAllDeletions()
                        }
                        .foregroundColor(.orange)
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if deletionCount > 0 {
                    bottomActionBar
                }
            }
            .sheet(isPresented: $showPhotoPreview) {
                if let photo = selectedPhotoForPreview {
                    PhotoPreviewSheet(photo: photo, viewModel: viewModel)
                }
            }
        }
    }
    
    // MARK: - Info Card
    
    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.ReviewDeletions.willDeleteCount(deletionCount))
                        .font(.headline)
                    
                    if viewModel.estimatedStorageToFree > 0 {
                        Text(L10n.ReviewDeletions.storageToFree(viewModel.formattedStorageToFree))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            
            Divider()
            
            HStack {
                Image(systemName: "hand.tap.fill")
                    .foregroundColor(.blue)
                Text(L10n.ReviewDeletions.tapToRestore)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            Text(L10n.ReviewDeletions.noPhotos)
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(L10n.ReviewDeletions.allRestored)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: {
                dismiss()
            }) {
                Text(L10n.Button.done)
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: 200)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.top, 10)
        }
    }
    
    // MARK: - Bottom Action Bar
    
    private var bottomActionBar: some View {
        VStack(spacing: 0) {
            Divider()
            
            Button(action: {
                dismiss()
            }) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                    Text(L10n.ReviewDeletions.complete)
                        .font(.headline)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(15)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Actions
    
    /// 取消单张照片的删除标记
    private func cancelDeletion(for photo: TidyPhoto) {
        // 使用触觉反馈
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // 查找并更新照片的删除标记
        if let index = viewModel.photosToReview.firstIndex(where: { $0.id == photo.id }) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                viewModel.photosToReview[index].isMarkedForDeletion = false
            }
            AppLogger.shared.info("已取消删除: \(photo.id)", category: .ui)
        }
    }
    
    /// 取消所有删除标记
    private func cancelAllDeletions() {
        // 使用触觉反馈
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            for index in 0..<viewModel.photosToReview.count {
                if viewModel.photosToReview[index].isMarkedForDeletion {
                    viewModel.photosToReview[index].isMarkedForDeletion = false
                }
            }
        }
        AppLogger.shared.info("已取消所有删除标记", category: .ui)
    }
    
    /// 加载照片缩略图
    private func loadThumbnail(for photo: TidyPhoto) {
        // 如果已经缓存，跳过
        guard thumbnailCache[photo.id] == nil else { return }
        
        let targetSize = CGSize(width: 300, height: 300)
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        
        PHImageManager.default().requestImage(
            for: photo.asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            if let image = image {
                DispatchQueue.main.async {
                    self.thumbnailCache[photo.id] = image
                }
            }
        }
    }
}

// MARK: - Photo Thumbnail Cell

struct PhotoThumbnailCell: View {
    let photo: TidyPhoto
    let thumbnail: UIImage?
    let onTap: () -> Void
    let onPreview: () -> Void
    
    @State private var isPressed: Bool = false
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // 照片缩略图
            if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 100, height: 100)
                    .clipped()
                    .cornerRadius(12)
            } else {
                // 加载占位符
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray5))
                    .frame(width: 100, height: 100)
                    .overlay {
                        ProgressView()
                    }
            }
            
            // 删除标记角标
            Image(systemName: "trash.circle.fill")
                .font(.title3)
                .foregroundColor(.red)
                .background(
                    Circle()
                        .fill(Color.white)
                        .frame(width: 24, height: 24)
                )
                .offset(x: 5, y: -5)
            
            // 媒体类型图标
            if photo.asset.mediaType == .video {
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: "play.circle.fill")
                            .foregroundColor(.white)
                            .font(.title3)
                            .shadow(radius: 2)
                        Spacer()
                    }
                    .padding(6)
                }
            } else if photo.asset.mediaSubtypes.contains(.photoLive) {
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: "livephoto")
                            .foregroundColor(.white)
                            .font(.caption)
                            .shadow(radius: 2)
                        Spacer()
                    }
                    .padding(6)
                }
            }
        }
        .frame(width: 100, height: 100)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
        .onTapGesture {
            onTap()
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            onPreview()
        } onPressingChanged: { pressing in
            isPressed = pressing
        }
    }
}

// MARK: - Photo Preview Sheet

struct PhotoPreviewSheet: View {
    let photo: TidyPhoto
    let viewModel: TidySessionViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var fullImage: UIImage?
    @State private var isLoading: Bool = true
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else if let fullImage = fullImage {
                    Image(uiImage: fullImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Text("加载失败")
                        .foregroundColor(.white)
                }
            }
            .navigationTitle(formatDate(photo.asset.creationDate))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(photo.asset.pixelWidth) × \(photo.asset.pixelHeight)")
                            .font(.caption2)
                        if let fileSize = getFileSize(for: photo.asset) {
                            Text(fileSize)
                                .font(.caption2)
                        }
                    }
                    .foregroundColor(.white)
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black.opacity(0.8), for: .navigationBar)
        }
        .onAppear {
            loadFullImage()
        }
    }
    
    private func loadFullImage() {
        let targetSize = CGSize(width: 2000, height: 2000)
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        
        PHImageManager.default().requestImage(
            for: photo.asset,
            targetSize: targetSize,
            contentMode: .aspectFit,
            options: options
        ) { image, _ in
            DispatchQueue.main.async {
                self.fullImage = image
                self.isLoading = false
            }
        }
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "未知日期" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func getFileSize(for asset: PHAsset) -> String? {
        let resources = PHAssetResource.assetResources(for: asset)
        guard let resource = resources.first,
              let fileSize = resource.value(forKey: "fileSize") as? Int64 else {
            return nil
        }
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
}

// MARK: - Preview

#Preview {
    let vm = TidySessionViewModel()
    // 模拟一些待删除的照片
    return ReviewDeletionsView(viewModel: vm)
}

