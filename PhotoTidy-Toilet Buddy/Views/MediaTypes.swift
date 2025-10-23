//
//  MediaTypes.swift
//  PhotoTidy-Toilet Buddy
//
//  Created on 2025-10-22.
//  Extracted from CardReviewView.swift for better code organization
//

import Foundation

// MARK: - Media Type Enum

/// 媒体类型枚举
enum MediaType {
    case image          // 普通照片
    case livePhoto      // Live Photo
    case video          // 视频
    case panorama       // 全景照片（暂时当作普通照片处理）
}

