//
//  SessionSetupView.swift
//  PhotoTidy-Toilet Buddy
//
//  Created on 2025-10-22.
//

import SwiftUI
import Photos

/// 会话设置视图 - 用户配置整理会话的界面
struct SessionSetupView: View {
    @ObservedObject var viewModel: TidySessionViewModel
    
    // MARK: - State Properties
    
    @State private var photoCount: Double = 10
    @State private var contentFilter: ContentFilterType = .all
    @State private var excludeHidden: Bool = true
    @State private var excludeFavorite: Bool = true
    @State private var showingAdvancedFilter = false
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    // 标题区域
                    headerSection
                    
                    // 统计卡片（如果有完成的会话）
                    if viewModel.isSessionCompleted {
                        sessionCompletedCard
                    }
                    
                    // 数量选择区域 (F-02)
                    photoCountSection
                    
                    // 快速过滤选项
                    quickFiltersSection
                    
                    // 高级过滤入口 (F-03.1)
                    advancedFilterButton
                    
                    Spacer(minLength: 20)
                    
                    // 启动按钮
                    startButton
                }
                .padding()
            }
            .navigationTitle("设置会话")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingAdvancedFilter) {
                AdvancedFilterView(
                    contentFilter: $contentFilter,
                    excludeHidden: $excludeHidden,
                    excludeFavorite: $excludeFavorite
                )
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 15) {
            Image(systemName: "photo.stack.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("Photo Tidy")
                .font(.system(size: 34, weight: .bold, design: .rounded))
            
            Text("马桶伴侣")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Text("随机选取照片，轻松整理您的相册")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.top, 20)
    }
    
    // MARK: - Session Completed Card
    
    private var sessionCompletedCard: some View {
        VStack(spacing: 15) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
                
                Text("上次会话已完成")
                    .font(.headline)
                
                Spacer()
            }
            
            HStack(spacing: 30) {
                StatItem(
                    icon: "trash.fill",
                    label: "已删除",
                    value: viewModel.deletedCount,
                    color: .red
                )
                
                Divider()
                    .frame(height: 40)
                
                StatItem(
                    icon: "hand.thumbsup.fill",
                    label: "已保留",
                    value: viewModel.keptCount,
                    color: .green
                )
            }
            .padding(.horizontal)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.green.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Photo Count Section (F-02)
    
    private var photoCountSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "photo.on.rectangle.angled")
                    .foregroundColor(.blue)
                Text("选择照片数量")
                    .font(.headline)
                Spacer()
            }
            
            // 当前选中的数量显示
            HStack {
                Spacer()
                Text("\(Int(photoCount))")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Text("张")
                    .font(.title2)
                    .foregroundColor(.secondary)
                    .padding(.leading, 5)
                Spacer()
            }
            .padding(.vertical, 10)
            
            // Slider
            VStack(spacing: 8) {
                Slider(value: $photoCount, in: 10...500, step: 5)
                    .accentColor(.blue)
                
                HStack {
                    Text("10")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("500")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // 预设按钮
            HStack(spacing: 12) {
                PresetButton(value: 10, currentValue: $photoCount, label: "快速")
                PresetButton(value: 30, currentValue: $photoCount, label: "标准")
                PresetButton(value: 50, currentValue: $photoCount, label: "深度")
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
    
    // MARK: - Quick Filters Section
    
    private var quickFiltersSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .foregroundColor(.purple)
                Text("快速过滤")
                    .font(.headline)
                Spacer()
            }
            
            VStack(spacing: 12) {
                FilterToggle(
                    icon: "eye.slash.fill",
                    title: "排除已隐藏的照片",
                    isOn: $excludeHidden,
                    color: .orange
                )
                
                FilterToggle(
                    icon: "heart.fill",
                    title: "排除已收藏的照片",
                    isOn: $excludeFavorite,
                    color: .pink
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
    
    // MARK: - Advanced Filter Button (F-03.1)
    
    private var advancedFilterButton: some View {
        Button(action: {
            showingAdvancedFilter = true
        }) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("高级过滤选项")
                        .font(.headline)
                    Text(contentFilter.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Start Button
    
    private var startButton: some View {
        Button(action: {
            startSession()
        }) {
            HStack {
                Image(systemName: "play.fill")
                    .font(.title3)
                Text(viewModel.isSessionCompleted ? "开始新会话" : "开始整理")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(15)
            .shadow(color: Color.blue.opacity(0.3), radius: 10, x: 0, y: 5)
        }
        .disabled(viewModel.isLoading)
    }
    
    // MARK: - Actions
    
    private func startSession() {
        Task {
            let subtypes = contentFilter.getSubtypes()
            await viewModel.startNewSession(
                count: Int(photoCount),
                contentSubtypes: subtypes,
                excludeHidden: excludeHidden,
                excludeFavorite: excludeFavorite
            )
        }
    }
}

// MARK: - Supporting Views

struct PresetButton: View {
    let value: Double
    @Binding var currentValue: Double
    let label: String
    
    var isSelected: Bool {
        currentValue == value
    }
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3)) {
                currentValue = value
            }
        }) {
            VStack(spacing: 6) {
                Text("\(Int(value))")
                    .font(.title3)
                    .fontWeight(.bold)
                Text(label)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.blue : Color.gray.opacity(0.15))
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct FilterToggle: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool
    let color: Color
    
    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 24)
                
                Text(title)
                    .font(.subheadline)
            }
        }
        .toggleStyle(SwitchToggleStyle(tint: color))
    }
}

struct StatItem: View {
    let icon: String
    let label: String
    let value: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text("\(value)")
                    .font(.title)
                    .fontWeight(.bold)
            }
            .foregroundColor(color)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Content Filter Type

enum ContentFilterType: String, CaseIterable, Identifiable {
    case all = "所有照片"
    case screenshots = "仅截图"
    case selfies = "仅自拍"
    case panoramas = "仅全景照片"
    case livePhotos = "仅 Live Photo"
    case portraits = "仅人像模式"
    case bursts = "仅连拍照片"
    case videos = "仅视频"
    
    var id: String { rawValue }
    
    var displayName: String {
        rawValue
    }
    
    var icon: String {
        switch self {
        case .all:
            return "photo.on.rectangle.angled"
        case .screenshots:
            return "camera.viewfinder"
        case .selfies:
            return "person.crop.circle"
        case .panoramas:
            return "pano"
        case .livePhotos:
            return "livephoto"
        case .portraits:
            return "person.fill"
        case .bursts:
            return "square.stack.3d.up"
        case .videos:
            return "video.fill"
        }
    }
    
    var description: String {
        switch self {
        case .all:
            return "选择所有类型的照片和视频"
        case .screenshots:
            return "只选择截屏照片"
        case .selfies:
            return "只选择前置摄像头拍摄的照片"
        case .panoramas:
            return "只选择全景模式拍摄的照片"
        case .livePhotos:
            return "只选择 Live Photo"
        case .portraits:
            return "只选择人像模式拍摄的照片"
        case .bursts:
            return "只选择连拍模式的照片"
        case .videos:
            return "只选择视频文件"
        }
    }
    
    func getSubtypes() -> [PHAssetMediaSubtype] {
        switch self {
        case .all:
            return []
        case .screenshots:
            return [.photoScreenshot]
        case .selfies:
            // 注意：PHAsset 没有直接的 selfie 子类型，需要通过其他方式判断
            // 这里返回空数组，实际使用时可能需要额外逻辑
            return []
        case .panoramas:
            return [.photoPanorama]
        case .livePhotos:
            return [.photoLive]
        case .portraits:
            return [.photoDepthEffect]
        case .bursts:
            // 连拍照片通常没有特定的子类型标记
            return []
        case .videos:
            // 视频会通过 mediaType 过滤，而不是子类型
            return []
        }
    }
}

// MARK: - Preview

#Preview {
    SessionSetupView(viewModel: TidySessionViewModel())
}

