//
//  MediaGestureModifiers.swift
//  PhotoTidy-Toilet Buddy
//
//  Created on 2025-10-22.
//  Extracted from CardReviewView.swift for better code organization
//

import SwiftUI

// MARK: - View Extensions for Media Transforms and Gestures

/// 应用媒体变换效果（优化版：纯水平移动，移除旋转和拖拽缩放）
extension View {
    func applyMediaTransforms(
        isZoomed: Bool,
        currentScale: CGFloat,
        finalScale: CGFloat,
        panOffset: CGSize,
        finalPanOffset: CGSize,
        dragOffset: CGSize,
        isDragging: Bool,
        isDeleting: Bool,
        deleteDirection: CGFloat,
        cardRotationFactor: Double
    ) -> some View {
        self
            // 缩放效果 - 只在缩放状态下应用
            .scaleEffect(
                isZoomed ? currentScale * finalScale : 1.0
            )
            // 平移偏移 - 优化为纯水平移动
            .offset(
                x: isZoomed 
                    ? panOffset.width + finalPanOffset.width
                    : (isDeleting ? deleteDirection * UIScreen.main.bounds.width * 1.2 : dragOffset.width),
                y: isZoomed 
                    ? panOffset.height + finalPanOffset.height
                    : 0  // 强制Y轴为0，确保纯水平移动
            )
            // 移除旋转效果 - 让过渡更自然
            // .rotationEffect(.degrees(isDragging && !isZoomed ? Double(dragOffset.width) * cardRotationFactor : 0))
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isZoomed)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: finalScale)
            .animation(
                isDeleting ? .spring(response: 0.5, dampingFraction: 0.8) : .spring(response: 0.3, dampingFraction: 0.7),
                value: isDeleting
            )
            .opacity(isDeleting ? 0 : max(0.3, 1 - Double(abs(dragOffset.width)) / 800))
    }
    
    func applyMediaGestures(
        isZoomed: Binding<Bool>,
        currentScale: Binding<CGFloat>,
        finalScale: Binding<CGFloat>,
        panOffset: Binding<CGSize>,
        finalPanOffset: Binding<CGSize>,
        dragOffset: Binding<CGSize>,
        isDragging: Binding<Bool>,
        onMagnificationEnd: @escaping (CGFloat) -> Void,
        onPanEnd: @escaping (CGSize) -> Void,
        onDragEnd: @escaping (CGSize) -> Void,
        onDoubleTap: @escaping () -> Void,
        onDragStart: @escaping (CGPoint) -> Void = { _ in },
        onDragChanged: @escaping (CGPoint) -> Void = { _ in }
    ) -> some View {
        self
            // 双击放大手势
            .onTapGesture(count: 2) {
                onDoubleTap()
            }
            // 捏合缩放手势
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        currentScale.wrappedValue = value
                    }
                    .onEnded { value in
                        onMagnificationEnd(value)
                    }
            )
            // 拖拽手势
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        if isZoomed.wrappedValue {
                            // 放大状态：平移查看
                            panOffset.wrappedValue = value.translation
                        } else {
                            // 正常状态：导航 - 只使用水平移动
                            isDragging.wrappedValue = true
                            dragOffset.wrappedValue = CGSize(width: value.translation.width, height: 0)
                            
                            // 通知位置变化用于速度计算
                            onDragChanged(value.location)
                        }
                    }
                    .onEnded { value in
                        if isZoomed.wrappedValue {
                            onPanEnd(value.translation)
                        } else {
                            onDragEnd(value.translation)
                        }
                    }
            )
    }
}

