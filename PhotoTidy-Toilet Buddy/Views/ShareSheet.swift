//
//  ShareSheet.swift
//  PhotoTidy-Toilet Buddy
//
//  Created on 2025-01-27.
//  ShareSheet - 系统分享面板封装
//

import SwiftUI
import UIKit
import Photos
import AVFoundation

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
        
        // 排除不需要的分享选项
        if let excludedTypes = excludedActivityTypes {
            activityViewController.excludedActivityTypes = excludedTypes
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
    /// - Parameters:
    ///   - photo: 当前照片对象
    ///   - currentImage: 当前加载的图片
    ///   - currentLivePhoto: 当前Live Photo
    ///   - videoPlayer: 当前视频播放器
    /// - Returns: 分享数据数组
    static func prepareShareData(
        for photo: TidyPhoto,
        currentImage: UIImage?,
        currentLivePhoto: PHLivePhoto?,
        videoPlayer: AVPlayer?
    ) async -> [Any] {
        var shareItems: [Any] = []
        
        let asset = photo.asset
        
        switch asset.mediaType {
        case .image:
            if asset.mediaSubtypes.contains(.photoLive), let livePhoto = currentLivePhoto {
                // Live Photo
                shareItems.append(livePhoto)
                print("📤 准备分享 Live Photo")
            } else if let image = currentImage {
                // 普通照片
                shareItems.append(image)
                print("📤 准备分享普通照片")
            } else {
                // 如果当前没有加载图片，尝试重新加载
                if let loadedImage = await loadImageForSharing(asset: asset) {
                    shareItems.append(loadedImage)
                    print("📤 重新加载并准备分享照片")
                }
            }
            
        case .video:
            if let player = videoPlayer, let playerItem = player.currentItem {
                // 使用当前播放器的资源
                if let asset = playerItem.asset as? AVURLAsset {
                    shareItems.append(asset.url)
                    print("📤 准备分享视频文件")
                }
            } else {
                // 重新加载视频资源
                if let videoURL = await loadVideoForSharing(asset: asset) {
                    shareItems.append(videoURL)
                    print("📤 重新加载并准备分享视频")
                }
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
