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
            .navigationTitle(L10n.Filter.advanced)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.Button.cancel) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button(action: resetAllFilters) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 14))
                                Text(L10n.Button.reset)
                                    .font(.subheadline)
                            }
                            .foregroundColor(.orange)
                        }
                        
                        Button(L10n.Button.done) {
                            applyFilters()
                            dismiss()
                        }
                        .fontWeight(.semibold)
                    }
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
                    title: type.localizedName,
                    description: type.description,
                    isSelected: tempConfig.contentType == type
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        tempConfig.contentType = type
                    }
                }
            }
        } header: {
            SectionHeaderView(icon: "photo.stack", title: L10n.Filter.contentType)
        } footer: {
            Text(L10n.Filter.selectContentType)
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
                title: L10n.Filter.unlimited,
                description: L10n.Filter.unlimitedTime,
                isSelected: tempConfig.dateRange == nil
            ) {
                withAnimation(.spring(response: 0.3)) {
                    tempConfig.dateRange = nil
                }
            }
            
            ForEach(DateRangeType.allCases) { dateRange in
                FilterOptionRow(
                    icon: dateRange.icon,
                    title: dateRange.localizedName,
                    description: "",
                    isSelected: tempConfig.dateRange == dateRange
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        tempConfig.dateRange = dateRange
                    }
                }
            }
        } header: {
            SectionHeaderView(icon: "calendar", title: L10n.Filter.dateRange)
        } footer: {
            Text(L10n.Filter.selectDateRange)
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
                title: L10n.Filter.unlimited,
                description: L10n.Filter.unlimitedLocation,
                isSelected: tempConfig.locationFilter == nil
            ) {
                withAnimation(.spring(response: 0.3)) {
                    tempConfig.locationFilter = nil
                }
            }
            
            ForEach(LocationFilterType.allCases) { location in
                FilterOptionRow(
                    icon: location == .withLocation ? "location.fill" : "location.slash",
                    title: location.localizedName,
                    description: location == .withLocation ? NSLocalizedString("location.with_location.desc", comment: "") : NSLocalizedString("location.without_location.desc", comment: ""),
                    isSelected: tempConfig.locationFilter == location
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        tempConfig.locationFilter = location
                    }
                }
            }
        } header: {
            SectionHeaderView(icon: "location", title: L10n.Filter.location)
        } footer: {
            Text(L10n.Filter.selectLocation)
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
                title: L10n.Filter.unlimited,
                description: L10n.Filter.unlimitedDuration,
                isSelected: tempConfig.durationFilter == nil
            ) {
                withAnimation(.spring(response: 0.3)) {
                    tempConfig.durationFilter = nil
                }
            }
            
            ForEach(DurationFilterType.allCases) { duration in
                FilterOptionRow(
                    icon: duration.icon,
                    title: duration.localizedName,
                    description: "",
                    isSelected: tempConfig.durationFilter == duration
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        tempConfig.durationFilter = duration
                    }
                }
            }
        } header: {
            SectionHeaderView(icon: "film", title: L10n.Filter.duration)
        } footer: {
            Text(L10n.Filter.selectDuration)
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
                        Text(L10n.Filter.excludeHidden)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(L10n.Filter.excludeHiddenDesc)
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
                        Text(L10n.Filter.excludeFavorite)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(L10n.Filter.excludeFavoriteDesc)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: .pink))
        } header: {
            SectionHeaderView(icon: "gearshape", title: L10n.Filter.otherOptions)
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
                    Text(L10n.Filter.logic)
                        .font(.headline)
                }
                
                Text(L10n.Filter.logicAnd)
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
    
    private func resetAllFilters() {
        withAnimation(.spring(response: 0.3)) {
            // 重置所有过滤选项到默认值
            tempConfig = FilterConfiguration()
        }
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
