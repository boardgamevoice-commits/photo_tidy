//
//  SupportingViews.swift
//  PhotoTidy-Toilet Buddy
//
//  Created on 2025-10-22.
//  Extracted from CardReviewView.swift for better code organization
//

import SwiftUI

// MARK: - Supporting Views

/// 紧凑型统计徽章
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

/// 按钮缩放样式
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

