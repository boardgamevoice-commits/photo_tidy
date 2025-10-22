//
//  AdvancedFilterView.swift
//  PhotoTidy-Toilet Buddy
//
//  Created on 2025-10-22.
//

import SwiftUI
import Photos

/// 高级过滤视图 (F-03.1) - 详细的照片过滤选项
struct AdvancedFilterView: View {
    @Environment(\.dismiss) var dismiss
    
    // MARK: - Bindings
    
    @Binding var contentFilter: ContentFilterType
    @Binding var excludeHidden: Bool
    @Binding var excludeFavorite: Bool
    
    // MARK: - State
    
    @State private var selectedFilter: ContentFilterType
    @State private var tempExcludeHidden: Bool
    @State private var tempExcludeFavorite: Bool
    
    // MARK: - Initialization
    
    init(contentFilter: Binding<ContentFilterType>, excludeHidden: Binding<Bool>, excludeFavorite: Binding<Bool>) {
        self._contentFilter = contentFilter
        self._excludeHidden = excludeHidden
        self._excludeFavorite = excludeFavorite
        
        // 初始化临时状态
        self._selectedFilter = State(initialValue: contentFilter.wrappedValue)
        self._tempExcludeHidden = State(initialValue: excludeHidden.wrappedValue)
        self._tempExcludeFavorite = State(initialValue: excludeFavorite.wrappedValue)
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 25) {
                    // 内容类型选择
                    contentTypeSection
                    
                    // 排除选项
                    exclusionSection
                    
                    // 预览统计（可选）
                    previewSection
                }
                .padding()
            }
            .navigationTitle("高级过滤")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        applyFilters()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    // MARK: - Content Type Section
    
    private var contentTypeSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            SectionHeader(
                icon: "photo.stack",
                title: "内容类型",
                subtitle: "选择要整理的照片类型"
            )
            
            VStack(spacing: 10) {
                ForEach(ContentFilterType.allCases) { filter in
                    ContentFilterCard(
                        filter: filter,
                        isSelected: selectedFilter == filter,
                        action: {
                            withAnimation(.spring(response: 0.3)) {
                                selectedFilter = filter
                            }
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Exclusion Section
    
    private var exclusionSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            SectionHeader(
                icon: "eye.slash",
                title: "排除选项",
                subtitle: "设置要排除的照片"
            )
            
            VStack(spacing: 12) {
                ExclusionToggle(
                    icon: "eye.slash.fill",
                    title: "排除已隐藏的照片",
                    description: "不会选择您已经隐藏的照片",
                    isOn: $tempExcludeHidden,
                    color: .orange
                )
                
                Divider()
                    .padding(.horizontal)
                
                ExclusionToggle(
                    icon: "heart.fill",
                    title: "排除已收藏的照片",
                    description: "不会选择您标记为收藏的照片",
                    isOn: $tempExcludeFavorite,
                    color: .pink
                )
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            )
        }
    }
    
    // MARK: - Preview Section
    
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            SectionHeader(
                icon: "info.circle",
                title: "过滤预览",
                subtitle: "当前过滤条件"
            )
            
            VStack(spacing: 12) {
                PreviewRow(
                    title: "内容类型",
                    value: selectedFilter.displayName,
                    icon: selectedFilter.icon
                )
                
                Divider()
                
                PreviewRow(
                    title: "排除隐藏",
                    value: tempExcludeHidden ? "是" : "否",
                    icon: "eye.slash",
                    color: tempExcludeHidden ? .orange : .gray
                )
                
                Divider()
                
                PreviewRow(
                    title: "排除收藏",
                    value: tempExcludeFavorite ? "是" : "否",
                    icon: "heart",
                    color: tempExcludeFavorite ? .pink : .gray
                )
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.blue.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(Color.blue.opacity(0.2), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Actions
    
    private func applyFilters() {
        contentFilter = selectedFilter
        excludeHidden = tempExcludeHidden
        excludeFavorite = tempExcludeFavorite
    }
}

// MARK: - Supporting Views

struct SectionHeader: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.headline)
            }
            
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct ContentFilterCard: View {
    let filter: ContentFilterType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 15) {
                // 图标
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.blue : Color.gray.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: filter.icon)
                        .font(.title3)
                        .foregroundColor(isSelected ? .white : .gray)
                }
                
                // 文字信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(filter.displayName)
                        .font(.subheadline)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundColor(.primary)
                    
                    Text(filter.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // 选中标记
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(isSelected ? 0.15 : 0.08), radius: isSelected ? 8 : 4, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ExclusionToggle: View {
    let icon: String
    let title: String
    let description: String
    @Binding var isOn: Bool
    let color: Color
    
    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .toggleStyle(SwitchToggleStyle(tint: color))
    }
}

struct PreviewRow: View {
    let title: String
    let value: String
    let icon: String
    var color: Color = .blue
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Preview

#Preview {
    AdvancedFilterView(
        contentFilter: .constant(.all),
        excludeHidden: .constant(true),
        excludeFavorite: .constant(false)
    )
}

