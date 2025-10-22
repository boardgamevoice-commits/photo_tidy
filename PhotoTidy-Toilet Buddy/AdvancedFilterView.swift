//
//  AdvancedFilterView.swift
//  PhotoTidy-Toilet Buddy
//
//  Created on 2025-10-22.
//

import SwiftUI
import Photos

/// 高级过滤视图 (F-03.1) - 支持多维度过滤组合
struct AdvancedFilterView: View {
    @Environment(\.dismiss) var dismiss
    
    // MARK: - Bindings
    
    @Binding var filterConfig: FilterConfiguration
    
    // MARK: - State
    
    @State private var tempConfig: FilterConfiguration
    
    // MARK: - Initialization
    
    init(filterConfig: Binding<FilterConfiguration>) {
        self._filterConfig = filterConfig
        self._tempConfig = State(initialValue: filterConfig.wrappedValue)
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            List {
                // 内容类型选择
                contentTypeSection
                
                // 日期范围选择
                dateRangeSection
                
                // 位置信息选择
                locationSection
                
                // 视频时长选择
                durationSection
                
                // 其他选项
                otherOptionsSection
                
                // 预览摘要
                summarySection
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
        Section {
            ForEach(ContentType.allCases) { type in
                FilterOptionRow(
                    icon: type.icon,
                    title: type.rawValue,
                    description: type.description,
                    isSelected: tempConfig.contentType == type
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        tempConfig.contentType = type
                    }
                }
            }
        } header: {
            SectionHeaderView(icon: "photo.stack", title: "内容类型")
        } footer: {
            Text("选择要整理的照片或视频类型")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Date Range Section
    
    private var dateRangeSection: some View {
        Section {
            // 不限选项
            FilterOptionRow(
                icon: "infinity",
                title: "不限",
                description: "所有时间范围",
                isSelected: tempConfig.dateRange == nil
            ) {
                withAnimation(.spring(response: 0.3)) {
                    tempConfig.dateRange = nil
                }
            }
            
            ForEach(DateRangeType.allCases) { dateRange in
                FilterOptionRow(
                    icon: dateRange.icon,
                    title: dateRange.rawValue,
                    description: "",
                    isSelected: tempConfig.dateRange == dateRange
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        tempConfig.dateRange = dateRange
                    }
                }
            }
        } header: {
            SectionHeaderView(icon: "calendar", title: "日期范围")
        } footer: {
            Text("可选：按拍摄时间筛选照片")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Location Section
    
    private var locationSection: some View {
        Section {
            // 不限选项
            FilterOptionRow(
                icon: "infinity",
                title: "不限",
                description: "不限位置信息",
                isSelected: tempConfig.locationFilter == nil
            ) {
                withAnimation(.spring(response: 0.3)) {
                    tempConfig.locationFilter = nil
                }
            }
            
            ForEach(LocationFilterType.allCases) { location in
                FilterOptionRow(
                    icon: location == .withLocation ? "location.fill" : "location.slash",
                    title: location.rawValue,
                    description: location == .withLocation ? "带有 GPS 位置信息" : "不含位置信息",
                    isSelected: tempConfig.locationFilter == location
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        tempConfig.locationFilter = location
                    }
                }
            }
        } header: {
            SectionHeaderView(icon: "location", title: "位置信息")
        } footer: {
            Text("可选：按是否包含 GPS 位置筛选")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Duration Section
    
    private var durationSection: some View {
        Section {
            // 不限选项
            FilterOptionRow(
                icon: "infinity",
                title: "不限",
                description: "所有时长",
                isSelected: tempConfig.durationFilter == nil
            ) {
                withAnimation(.spring(response: 0.3)) {
                    tempConfig.durationFilter = nil
                }
            }
            
            ForEach(DurationFilterType.allCases) { duration in
                FilterOptionRow(
                    icon: duration.icon,
                    title: duration.rawValue,
                    description: "",
                    isSelected: tempConfig.durationFilter == duration
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        tempConfig.durationFilter = duration
                    }
                }
            }
        } header: {
            SectionHeaderView(icon: "film", title: "视频时长")
        } footer: {
            Text("可选：仅在选择视频相关类型时有效")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Other Options Section
    
    private var otherOptionsSection: some View {
        Section {
            Toggle(isOn: $tempConfig.excludeHidden) {
                HStack(spacing: 12) {
                    Image(systemName: "eye.slash.fill")
                        .foregroundColor(.orange)
                        .frame(width: 30)
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text("排除已隐藏")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("不选择已隐藏的照片")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: .orange))
            
            Toggle(isOn: $tempConfig.excludeFavorite) {
                HStack(spacing: 12) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.pink)
                        .frame(width: 30)
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text("排除已收藏")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("不选择标记为收藏的照片")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: .pink))
        } header: {
            SectionHeaderView(icon: "gearshape", title: "其他选项")
        }
    }
    
    // MARK: - Summary Section
    
    private var summarySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                // 过滤逻辑说明
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    Text("过滤逻辑")
                        .font(.headline)
                }
                
                Text("所有过滤条件将同时生效（AND 逻辑）")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                
                // 当前配置摘要
                Text(tempConfig.summary)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.1))
                    )
                
                // 验证警告和建议
                let validation = tempConfig.validate()
                
                if !validation.warnings.isEmpty {
                    ForEach(validation.warnings, id: \.self) { warning in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.system(size: 14))
                            Text(warning)
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.orange.opacity(0.1))
                        )
                    }
                }
                
                if !validation.suggestions.isEmpty {
                    ForEach(validation.suggestions, id: \.self) { suggestion in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.yellow)
                                .font(.system(size: 14))
                            Text(suggestion)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.yellow.opacity(0.1))
                        )
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Actions
    
    private func applyFilters() {
        filterConfig = tempConfig
    }
}

// MARK: - Supporting Views

struct SectionHeaderView: View {
    let icon: String
    let title: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(title)
        }
        .font(.subheadline)
        .fontWeight(.semibold)
        .foregroundColor(.blue)
        .textCase(nil)
    }
}

struct FilterOptionRow: View {
    let icon: String
    let title: String
    let description: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // 图标
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.blue : Color.gray.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(isSelected ? .white : .gray)
                }
                
                // 文字信息
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundColor(.primary)
                    
                    if !description.isEmpty {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // 选中标记
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 22))
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    AdvancedFilterView(filterConfig: .constant(FilterConfiguration()))
}
