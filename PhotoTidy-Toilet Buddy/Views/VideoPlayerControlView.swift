//
//  VideoPlayerControlView.swift
//  PhotoTidy-Toilet Buddy
//
//  Created on 2025-10-22.
//  Extracted from CardReviewView.swift for better code organization
//

import SwiftUI
import AVFoundation
import AVKit

/// 视频播放器包装器
/// 包含完整的资源管理：观察者、播放器状态等
struct VideoPlayerControlView: View {
    let player: AVPlayer
    @Binding var isPlaying: Bool
    
    // 用于存储观察者token，以便在视图消失时移除
    @State private var playbackObserver: NSObjectProtocol?
    
    var body: some View {
        ZStack {
            // 视频播放器
            VideoPlayer(player: player)
                .onAppear {
                    setupVideoPlayer()
                }
                .onDisappear {
                    cleanupVideoPlayer()
                }
            
            // 播放/暂停控制
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    
                    Button(action: {
                        if isPlaying {
                            player.pause()
                            isPlaying = false
                        } else {
                            player.play()
                            isPlaying = true
                        }
                    }) {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 5)
                    }
                    
                    Spacer()
                }
                Spacer()
            }
            .opacity(isPlaying ? 0.0 : 1.0)
            .animation(.easeInOut(duration: 0.3), value: isPlaying)
        }
    }
    
    // MARK: - Resource Management
    
    /// 设置视频播放器
    private func setupVideoPlayer() {
        // 配置音频会话用于视频播放
        let audioSessionConfigured = AudioSessionManager.shared.configureForVideoPlayback()
        if !audioSessionConfigured {
            AppLogger.shared.warning("音频会话配置失败，视频播放可能有问题", category: .media)
        }
        
        // 监听播放结束
        playbackObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            isPlaying = false
            player.seek(to: .zero)
        }
        AppLogger.shared.media("视频播放观察者已添加", level: .debug)
    }
    
    /// 清理视频播放器资源
    /// 包括：暂停播放、移除观察者、清空播放项、停用音频会话
    private func cleanupVideoPlayer() {
        // 1. 暂停播放
        if isPlaying {
            player.pause()
            isPlaying = false
        }
        
        // 2. 移除观察者
        if let observer = playbackObserver {
            NotificationCenter.default.removeObserver(observer)
            playbackObserver = nil
        }
        
        // 3. 清空当前播放项，释放解码器和缓冲区
        player.replaceCurrentItem(with: nil)
        
        // 4. 停用音频会话
        AudioSessionManager.shared.deactivateAudioSession()
        
        AppLogger.shared.media("视频播放器资源已完全释放", level: .debug)
    }
}

