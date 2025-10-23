//
//  MediaGestureModifiers.swift
//  PhotoTidy-Toilet Buddy
//
//  Created on 2025-10-22.
//  Extracted from CardReviewView.swift for better code organization
//

import SwiftUI

// MARK: - View Extensions for Media Transforms and Gestures

/// 应用媒体变换效果（缩放、平移、旋转等）
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
            // 缩放效果
            .scaleEffect(
                isZoomed 
                    ? currentScale * finalScale
                    : 1.0 + (abs(dragOffset.width) / 1000)
            )
            // 平移偏移
            .offset(
                x: isZoomed 
                    ? panOffset.width + finalPanOffset.width
                    : (isDeleting ? deleteDirection * UIScreen.main.bounds.width * 1.5 : dragOffset.width),
                y: isZoomed 
                    ? panOffset.height + finalPanOffset.height
                    : (isDeleting ? -50 : dragOffset.height * 0.2)
            )
            // 旋转效果
            .rotationEffect(.degrees(isDragging && !isZoomed ? Double(dragOffset.width) * cardRotationFactor : 0))
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isZoomed)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: finalScale)
            .animation(
                isDeleting ? .spring(response: 0.5, dampingFraction: 0.8) : .spring(response: 0.3, dampingFraction: 0.7),
                value: isDeleting
            )
            .opacity(isDeleting ? 0 : 1 - Double(abs(dragOffset.width)) / 500)
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
        onDoubleTap: @escaping () -> Void
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
                            // 正常状态：导航
                            isDragging.wrappedValue = true
                            dragOffset.wrappedValue = value.translation
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

