//
//  LivePhotoView.swift
//  PhotoTidy-Toilet Buddy
//
//  Created on 2025-10-22.
//  Extracted from CardReviewView.swift for better code organization
//

import SwiftUI
import Photos
import PhotosUI

/// Live Photo 视图包装器
struct LivePhotoView: UIViewRepresentable {
    let livePhoto: PHLivePhoto
    @Binding var isPlaying: Bool
    
    func makeUIView(context: Context) -> PHLivePhotoView {
        let view = PHLivePhotoView()
        view.livePhoto = livePhoto
        view.contentMode = .scaleAspectFit
        
        // 设置代理监听播放状态
        view.delegate = context.coordinator
        
        return view
    }
    
    func updateUIView(_ uiView: PHLivePhotoView, context: Context) {
        uiView.livePhoto = livePhoto
        
        // 如果需要开始播放
        if isPlaying && !context.coordinator.isCurrentlyPlaying {
            uiView.startPlayback(with: .full)
            context.coordinator.isCurrentlyPlaying = true
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(isPlaying: $isPlaying)
    }
    
    class Coordinator: NSObject, PHLivePhotoViewDelegate {
        @Binding var isPlaying: Bool
        var isCurrentlyPlaying: Bool = false
        
        init(isPlaying: Binding<Bool>) {
            self._isPlaying = isPlaying
        }
        
        func livePhotoView(_ livePhotoView: PHLivePhotoView, didEndPlaybackWith playbackStyle: PHLivePhotoViewPlaybackStyle) {
            isPlaying = false
            isCurrentlyPlaying = false
        }
    }
}

