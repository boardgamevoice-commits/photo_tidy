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
    @State private var combinedFilterCount: PhotoCountResult = .calculating
    @State private var countCalculationTask: Task<Void, Never>?
    
    // 自动修复相关状态
    @State private var lastValidConfig: FilterConfiguration
    @State private var showAutoResetNotification: Bool = false
    @State private var autoResetMessage: String = ""
    @State private var autoResetActions: [FilterConfiguration.AutoResetAction] = []
    
    // 各个条件的照片数量 - 使用字典来存储每个具体选项的数量
    @State private var contentTypeCounts: [ContentType: PhotoCountResult] = [:]
    @State private var dateRangeCounts: [DateRangeType?: PhotoCountResult] = [:]
    @State private var durationCounts: [DurationFilterType?: PhotoCountResult] = [:]
    
    // MARK: - Initialization
    
    init(filterConfig: Binding<FilterConfiguration>) {
        self._filterConfig = filterConfig
        self._tempConfig = State(initialValue: filterConfig.wrappedValue)
        self._lastValidConfig = State(initialValue: filterConfig.wrappedValue)
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            List {
                // 内容类型选择
                contentTypeSection
                
                // 日期范围选择
                dateRangeSection
                
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
        .onAppear {
            calculateCombinedFilterCount()
            calculateIndividualCounts()
        }
        .onDisappear {
            cancelCombinedFilterCountCalculation()
        }
        .onChange(of: tempConfig) { newConfig in
            // 检测冲突并自动修复
            let validation = newConfig.validate()
            
            if !validation.autoResetActions.isEmpty {
                // 有冲突需要自动修复
                let fixedConfig = newConfig.autoResolveConflicts()
                
                // 更新临时配置
                withAnimation(.spring(response: 0.3)) {
                    tempConfig = fixedConfig
                }
                
                // 显示自动修复通知
                showAutoResetNotification(with: validation.autoResetActions)
                
                AppLogger.shared.info("自动修复过滤器冲突: \(validation.autoResetActions.map { $0.description }.joined(separator: ", "))", category: .ui)
            } else {
                // 无冲突，更新最后有效配置
                lastValidConfig = newConfig
            }
            
            calculateCombinedFilterCount()
            calculateIndividualCounts()
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
                    isSelected: tempConfig.contentType == type,
                    photoCount: contentTypeCounts[type]
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        tempConfig.handleContentTypeSelection(type)
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
                isSelected: tempConfig.dateRange == nil,
                photoCount: dateRangeCounts[nil]
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
                    isSelected: tempConfig.dateRange == dateRange,
                    photoCount: dateRangeCounts[dateRange]
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
    
    // MARK: - Duration Section
    
    private var durationSection: some View {
        Section {
            // 不限选项
            FilterOptionRow(
                icon: "infinity",
                title: L10n.Filter.unlimited,
                description: L10n.Filter.unlimitedDuration,
                isSelected: tempConfig.durationFilter == nil,
                photoCount: durationCounts[nil]
            ) {
                withAnimation(.spring(response: 0.3)) {
                    tempConfig.handleDurationSelection(nil)
                }
            }
            
            ForEach(DurationFilterType.allCases) { duration in
                FilterOptionRow(
                    icon: duration.icon,
                    title: duration.localizedName,
                    description: "",
                    isSelected: tempConfig.durationFilter == duration,
                    photoCount: durationCounts[duration]
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        tempConfig.handleDurationSelection(duration)
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
                
                // 满足所有条件的照片数量
                HStack(spacing: 8) {
                    Image(systemName: "photo.stack.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 16))
                    
                    Text(NSLocalizedString("photo.count.meets_all_conditions", comment: ""))
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    switch combinedFilterCount {
                    case .calculating:
                        HStack(spacing: 4) {
                            ProgressView()
                                .scaleEffect(0.7)
                        Text(NSLocalizedString("photo.count.calculating", comment: ""))
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                    case .success(let count):
                        Text("\(count)" + NSLocalizedString("photo.count.photos", comment: ""))
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    case .error:
                        Text(NSLocalizedString("photo.count.error", comment: ""))
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.green.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.green.opacity(0.3), lineWidth: 1)
                        )
                )
                
                // 自动修复通知
                if showAutoResetNotification {
                    AutoResetNotificationView(
                        message: autoResetMessage,
                        onUndo: undoAutoReset,
                        onDismiss: {
                            withAnimation(.spring(response: 0.3)) {
                                showAutoResetNotification = false
                            }
                        }
                    )
                }
                
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
    
    // MARK: - Combined Filter Count Calculation
    
    /// 计算满足所有组合条件的照片数量
    private func calculateCombinedFilterCount() {
        // 取消之前的计算任务
        countCalculationTask?.cancel()
        
        countCalculationTask = Task {
            // 在后台线程开始计算
            await MainActor.run {
                combinedFilterCount = .calculating
            }
            
            do {
                // 在后台线程执行计算
                let count = try await performPhotoCountCalculation(filterConfig: tempConfig)
                if !Task.isCancelled {
                    // 在主线程更新UI
                    await MainActor.run {
                        combinedFilterCount = .success(count)
                        AppLogger.shared.debug("高级过滤页面照片数量计算完成: \(count)张", category: .ui)
                    }
                }
            } catch {
                if !Task.isCancelled {
                    // 在主线程更新UI
                    await MainActor.run {
                        combinedFilterCount = .error(error.localizedDescription)
                        AppLogger.shared.error("高级过滤页面照片数量计算失败: \(error)", category: .ui)
                    }
                }
            }
        }
    }
    
    /// 执行照片数量计算
    private func performPhotoCountCalculation(filterConfig: FilterConfiguration) async throws -> Int {
        // 检查权限
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            throw PhotoCountError.permissionDenied
        }
        
        // 构建查询条件
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = PredicateBuilder.buildCombinedPredicate(from: filterConfig)
        
        // 执行查询（不加载实际数据）
        let fetchResult = PHAsset.fetchAssets(with: fetchOptions)
        
        AppLogger.shared.debug("查询到 \(fetchResult.count) 个符合条件的资源", category: .photo)
        
        // 处理需要后置过滤的条件
        var finalCount = fetchResult.count
        
        
        // 处理位置信息过滤（需要后置过滤）
        if let locationFilter = filterConfig.locationFilter {
            finalCount = try await countWithLocationFilter(from: fetchResult, locationFilter: locationFilter)
        }
        
        return finalCount
    }
    
    
    /// 计算满足位置信息条件的照片数量（需要后置过滤）
    private func countWithLocationFilter(from fetchResult: PHFetchResult<PHAsset>, locationFilter: LocationFilterType) async throws -> Int {
        var count = 0
        
        // 由于PHAsset的location属性不支持在NSPredicate中直接使用，
        // 我们需要遍历所有资产来检查位置信息
        fetchResult.enumerateObjects { (asset, _, _) in
            let hasLocation = asset.location != nil
            
            switch locationFilter {
            case .withLocation:
                if hasLocation {
                    count += 1
                }
            case .withoutLocation:
                if !hasLocation {
                    count += 1
                }
            }
        }
        
        AppLogger.shared.debug("位置过滤后剩余 \(count) 张照片", category: .photo)
        return count
    }
    
    /// 计算各个条件的照片数量
    private func calculateIndividualCounts() {
        // 计算所有内容类型的数量
        calculateAllContentTypeCounts()
        // 计算所有日期范围的数量
        calculateAllDateRangeCounts()
        // 计算所有时长的数量
        calculateAllDurationCounts()
    }
    
    /// 计算所有内容类型的照片数量
    private func calculateAllContentTypeCounts() {
        for contentType in ContentType.allCases {
            Task {
                // 在后台线程开始计算
                await MainActor.run {
                    contentTypeCounts[contentType] = .calculating
                }
                
                do {
                    // 在后台线程执行计算
                    let count = try await performPhotoCountCalculation(filterConfig: FilterConfiguration(
                        contentType: contentType,
                        dateRange: nil,
                        durationFilter: nil,
                        excludeHidden: false,
                        excludeFavorite: false
                    ))
                    // 在主线程更新UI
                    await MainActor.run {
                        contentTypeCounts[contentType] = .success(count)
                    }
                } catch {
                    // 在主线程更新UI
                    await MainActor.run {
                        contentTypeCounts[contentType] = .error(error.localizedDescription)
                    }
                }
            }
        }
    }
    
    /// 计算所有日期范围的照片数量
    private func calculateAllDateRangeCounts() {
        // 计算不限选项
        Task {
            // 在后台线程开始计算
            await MainActor.run {
                dateRangeCounts[nil] = .calculating
            }
            
            do {
                // 在后台线程执行计算
                let count = try await performPhotoCountCalculation(filterConfig: FilterConfiguration(
                        contentType: .all,
                        dateRange: nil,
                        durationFilter: nil,
                        excludeHidden: false,
                        excludeFavorite: false
                ))
                // 在主线程更新UI
                await MainActor.run {
                    dateRangeCounts[nil] = .success(count)
                }
            } catch {
                // 在主线程更新UI
                await MainActor.run {
                    dateRangeCounts[nil] = .error(error.localizedDescription)
                }
            }
        }
        
        // 计算每个日期范围选项
        for dateRange in DateRangeType.allCases {
            Task {
                // 在后台线程开始计算
                await MainActor.run {
                    dateRangeCounts[dateRange] = .calculating
                }
                
                do {
                    // 在后台线程执行计算
                    let count = try await performPhotoCountCalculation(filterConfig: FilterConfiguration(
                        contentType: .all,
                        dateRange: dateRange,
                        durationFilter: nil,
                        excludeHidden: false,
                        excludeFavorite: false
                    ))
                    // 在主线程更新UI
                    await MainActor.run {
                        dateRangeCounts[dateRange] = .success(count)
                    }
                } catch {
                    // 在主线程更新UI
                    await MainActor.run {
                        dateRangeCounts[dateRange] = .error(error.localizedDescription)
                    }
                }
            }
        }
    }
    
    /// 计算所有时长的照片数量
    private func calculateAllDurationCounts() {
        // 计算不限选项
        Task {
            // 在后台线程开始计算
            await MainActor.run {
                durationCounts[nil] = .calculating
            }
            
            do {
                // 在后台线程执行计算
                let count = try await performPhotoCountCalculation(filterConfig: FilterConfiguration(
                        contentType: .all,
                        dateRange: nil,
                        durationFilter: nil,
                        excludeHidden: false,
                        excludeFavorite: false
                ))
                // 在主线程更新UI
                await MainActor.run {
                    durationCounts[nil] = .success(count)
                }
            } catch {
                // 在主线程更新UI
                await MainActor.run {
                    durationCounts[nil] = .error(error.localizedDescription)
                }
            }
        }
        
        // 计算每个时长选项
        for duration in DurationFilterType.allCases {
            Task {
                // 在后台线程开始计算
                await MainActor.run {
                    durationCounts[duration] = .calculating
                }
                
                do {
                    // 在后台线程执行计算
                    let count = try await performPhotoCountCalculation(filterConfig: FilterConfiguration(
                        contentType: .all,
                        dateRange: nil,
                        durationFilter: duration,
                        excludeHidden: false,
                        excludeFavorite: false
                    ))
                    // 在主线程更新UI
                    await MainActor.run {
                        durationCounts[duration] = .success(count)
                    }
                } catch {
                    // 在主线程更新UI
                    await MainActor.run {
                        durationCounts[duration] = .error(error.localizedDescription)
                    }
                }
            }
        }
    }
    
    /// 显示自动重置通知
    private func showAutoResetNotification(with actions: [FilterConfiguration.AutoResetAction]) {
        autoResetActions = actions
        let actionDescriptions = actions.map { $0.description }.joined(separator: ", ")
        autoResetMessage = String(format: NSLocalizedString("auto_reset.notification_message", comment: ""), actionDescriptions)
        
        withAnimation(.spring(response: 0.5)) {
            showAutoResetNotification = true
        }
        
        // 3秒后自动隐藏通知
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.spring(response: 0.3)) {
                showAutoResetNotification = false
            }
        }
    }
    
    /// 撤销自动修复
    private func undoAutoReset() {
        withAnimation(.spring(response: 0.3)) {
            tempConfig = lastValidConfig
        }
        
        withAnimation(.spring(response: 0.3)) {
            showAutoResetNotification = false
        }
        
        AppLogger.shared.info("用户撤销自动修复", category: .ui)
    }
    
    /// 取消组合条件数量计算
    private func cancelCombinedFilterCountCalculation() {
        countCalculationTask?.cancel()
        countCalculationTask = nil
    }
}

// MARK: - Supporting Views

struct AutoResetNotificationView: View {
    let message: String
    let onUndo: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // 图标
            Image(systemName: "arrow.counterclockwise")
                .foregroundColor(.blue)
                .font(.system(size: 16))
            
            // 消息
            Text(message)
                .font(.caption)
                .foregroundColor(.blue)
                .lineLimit(2)
            
            Spacer()
            
            // 撤销按钮
            Button(NSLocalizedString("auto_reset.undo_button", comment: "Undo")) {
                onUndo()
            }
            .font(.caption)
            .foregroundColor(.blue)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.blue.opacity(0.1))
            )
            
            // 关闭按钮
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12))
                    .foregroundColor(.blue)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
        )
        .transition(.asymmetric(
            insertion: .scale.combined(with: .opacity),
            removal: .scale.combined(with: .opacity)
        ))
    }
}

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
    let photoCount: PhotoCountResult?
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
                
                // 照片数量或选中标记
                if let photoCount = photoCount {
                    VStack(alignment: .trailing, spacing: 2) {
                        switch photoCount {
                        case .calculating:
                            HStack(spacing: 4) {
                                ProgressView()
                                    .scaleEffect(0.6)
                                        Text(NSLocalizedString("photo.count.calculating_short", comment: ""))
                                            .font(.caption2)
                                            .foregroundColor(.blue)
                            }
                        case .success(let count):
                            Text("\(count)" + NSLocalizedString("photo.count.photos_short", comment: ""))
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                        case .error:
                            Text(NSLocalizedString("photo.count.unknown", comment: ""))
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                                .font(.system(size: 16))
                        }
                    }
                } else if isSelected {
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
