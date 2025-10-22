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
    @State private var filterConfig: FilterConfiguration = FilterConfiguration()
    @State private var showingAdvancedFilter = false
    @State private var showingError = false
    @State private var showingSettings = false
    
    // MARK: - UserDefaults Keys
    
    private let photoCountKey = "sessionSetup.photoCount"
    private let filterConfigKey = "sessionSetup.filterConfiguration"
    
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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gearshape")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                }
            }
            .sheet(isPresented: $showingAdvancedFilter) {
                AdvancedFilterView(filterConfig: $filterConfig)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .onChange(of: filterConfig) { _ in
                saveUserPreferences()
            }
            .alert("提示", isPresented: $showingError) {
                Button("确定", role: .cancel) {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "发生未知错误")
            }
            .onAppear {
                loadUserPreferences()
            }
            .onChange(of: viewModel.errorMessage) { newValue in
                showingError = newValue != nil
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
                Slider(value: $photoCount, in: 10...100, step: 5)
                    .accentColor(.blue)
                    .onChange(of: photoCount) { newValue in
                        saveUserPreferences()
                    }
                
                HStack {
                    Text("10")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("100")
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
                    isOn: Binding(
                        get: { filterConfig.excludeHidden },
                        set: { filterConfig.excludeHidden = $0 }
                    ),
                    color: .orange
                )
                
                FilterToggle(
                    icon: "heart.fill",
                    title: "排除已收藏的照片",
                    isOn: Binding(
                        get: { filterConfig.excludeFavorite },
                        set: { filterConfig.excludeFavorite = $0 }
                    ),
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
                    Text(filterConfig.summary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
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
            HStack(spacing: 12) {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                } else {
                    Image(systemName: "play.fill")
                        .font(.title3)
                }
                Text(viewModel.isLoading ? "加载中..." : (viewModel.isSessionCompleted ? "开始新会话" : "开始整理"))
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: viewModel.isLoading ? [.gray, .gray.opacity(0.8)] : [.blue, .purple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(15)
            .shadow(color: viewModel.isLoading ? Color.gray.opacity(0.2) : Color.blue.opacity(0.3), radius: 10, x: 0, y: 5)
            .animation(.easeInOut(duration: 0.3), value: viewModel.isLoading)
        }
        .disabled(viewModel.isLoading)
    }
    
    // MARK: - Actions
    
    private func startSession() {
        Task {
            await viewModel.startNewSession(
                count: Int(photoCount),
                filterConfig: filterConfig
            )
        }
    }
    
    // MARK: - UserDefaults Persistence
    
    /// 加载用户偏好设置（自动恢复上一次的选择）
    private func loadUserPreferences() {
        let defaults = UserDefaults.standard
        
        // 加载上一次的照片数量
        if defaults.object(forKey: photoCountKey) != nil {
            let savedCount = defaults.double(forKey: photoCountKey)
            photoCount = min(max(savedCount, 10), 100)
            print("已加载上次照片数量：\(Int(photoCount))")
        }
        
        // 加载上一次的过滤配置
        if let data = defaults.data(forKey: filterConfigKey),
           let decoded = try? JSONDecoder().decode(FilterConfiguration.self, from: data) {
            filterConfig = decoded
            print("已加载上次过滤配置：\(filterConfig.summary)")
        }
    }
    
    /// 保存用户偏好设置
    private func saveUserPreferences() {
        let defaults = UserDefaults.standard
        
        // 保存照片数量
        defaults.set(photoCount, forKey: photoCountKey)
        
        // 保存过滤配置（使用 Codable）
        if let encoded = try? JSONEncoder().encode(filterConfig) {
            defaults.set(encoded, forKey: filterConfigKey)
        }
        
        print("已保存用户偏好设置：photoCount=\(Int(photoCount)), filterConfig=\(filterConfig.summary)")
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
    // 基础类型
    case all = "所有媒体"
    case screenshots = "仅截图"
    case selfies = "仅自拍"
    case panoramas = "仅全景照片"
    case livePhotos = "仅 Live Photo"
    case portraits = "仅人像模式"
    case bursts = "仅连拍照片"
    case videos = "仅视频"
    
    // 高级媒体类型
    case hdrPhotos = "仅 HDR 照片"
    case slowMotionVideos = "仅慢动作视频"
    case timelapseVideos = "仅延时摄影"
    
    // 日期范围
    case recent7Days = "最近 7 天"
    case recent30Days = "最近 30 天"
    case thisYear = "今年拍摄"
    case lastYear = "去年拍摄"
    case older1Year = "1 年前"
    case older2Years = "2 年前"
    
    // 位置信息
    case photosWithLocation = "含位置信息"
    case photosWithoutLocation = "无位置信息"
    
    // 视频时长
    case shortVideos = "短视频 (<30秒)"
    case longVideos = "长视频 (>5分钟)"
    
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
        case .hdrPhotos:
            return "circle.lefthalf.filled"
        case .slowMotionVideos:
            return "slowmo"
        case .timelapseVideos:
            return "timelapse"
        case .recent7Days:
            return "calendar.badge.clock"
        case .recent30Days:
            return "calendar"
        case .thisYear:
            return "calendar.circle"
        case .lastYear:
            return "calendar.badge.minus"
        case .older1Year:
            return "clock.arrow.circlepath"
        case .older2Years:
            return "clock.badge.exclamationmark"
        case .photosWithLocation:
            return "location.fill"
        case .photosWithoutLocation:
            return "location.slash"
        case .shortVideos:
            return "film"
        case .longVideos:
            return "film.stack"
        }
    }
    
    var description: String {
        switch self {
        case .all:
            return "选择所有类型的照片和视频（含图片与视频）"
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
        case .hdrPhotos:
            return "只选择使用 HDR 模式拍摄的照片"
        case .slowMotionVideos:
            return "只选择慢动作视频（120fps/240fps）"
        case .timelapseVideos:
            return "只选择延时摄影视频"
        case .recent7Days:
            return "只选择最近 7 天内拍摄的照片和视频"
        case .recent30Days:
            return "只选择最近 30 天内拍摄的照片和视频"
        case .thisYear:
            return "只选择今年拍摄的照片和视频"
        case .lastYear:
            return "只选择去年拍摄的照片和视频"
        case .older1Year:
            return "只选择 1 年前拍摄的照片和视频"
        case .older2Years:
            return "只选择 2 年前拍摄的照片和视频"
        case .photosWithLocation:
            return "只选择带有 GPS 位置信息的照片和视频"
        case .photosWithoutLocation:
            return "只选择不含位置信息的照片和视频"
        case .shortVideos:
            return "只选择时长小于 30 秒的短视频"
        case .longVideos:
            return "只选择时长大于 5 分钟的长视频"
        }
    }
    
    func getSubtypes() -> [PHAssetMediaSubtype] {
        switch self {
        case .all:
            return []
        case .screenshots:
            return [.photoScreenshot]
        case .selfies:
            // 自拍通过 PhotoService 的特殊逻辑处理
            return []
        case .panoramas:
            return [.photoPanorama]
        case .livePhotos:
            return [.photoLive]
        case .portraits:
            return [.photoDepthEffect]
        case .bursts:
            // 连拍通过 PhotoService 的特殊逻辑处理
            return []
        case .videos:
            // 视频通过 PhotoService 的特殊逻辑处理
            return []
        case .hdrPhotos:
            return [.photoHDR]
        case .slowMotionVideos:
            return [.videoHighFrameRate]
        case .timelapseVideos:
            return [.videoTimelapse]
        case .recent7Days, .recent30Days, .thisYear, .lastYear, .older1Year, .older2Years:
            // 日期过滤通过 PhotoService 的特殊逻辑处理
            return []
        case .photosWithLocation, .photosWithoutLocation:
            // 位置过滤通过 PhotoService 的特殊逻辑处理
            return []
        case .shortVideos, .longVideos:
            // 时长过滤通过 PhotoService 的特殊逻辑处理
            return []
        }
    }
    
    /// 判断是否需要特殊的媒体类型过滤
    func requiresMediaTypeFilter() -> PHAssetMediaType? {
        switch self {
        case .videos, .slowMotionVideos, .timelapseVideos, .shortVideos, .longVideos:
            return .video
        default:
            return nil
        }
    }
    
    /// 判断是否需要自拍过滤
    var isSelfieFilter: Bool {
        return self == .selfies
    }
    
    /// 判断是否需要连拍过滤
    var isBurstFilter: Bool {
        return self == .bursts
    }
    
    /// 获取日期过滤范围
    /// - Returns: (startDate, endDate) 如果需要日期过滤，返回开始和结束日期；否则返回 nil
    func getDateFilter() -> (startDate: Date?, endDate: Date?)? {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .recent7Days:
            let startDate = calendar.date(byAdding: .day, value: -7, to: now)
            return (startDate, now)
            
        case .recent30Days:
            let startDate = calendar.date(byAdding: .day, value: -30, to: now)
            return (startDate, now)
            
        case .thisYear:
            let components = calendar.dateComponents([.year], from: now)
            let startOfYear = calendar.date(from: components)
            return (startOfYear, now)
            
        case .lastYear:
            let lastYearComponents = DateComponents(year: calendar.component(.year, from: now) - 1)
            let startOfLastYear = calendar.date(from: lastYearComponents)
            let endOfLastYear = calendar.date(byAdding: .year, value: 1, to: startOfLastYear!)
            return (startOfLastYear, endOfLastYear)
            
        case .older1Year:
            let oneYearAgo = calendar.date(byAdding: .year, value: -1, to: now)
            return (nil, oneYearAgo) // 结束于 1 年前
            
        case .older2Years:
            let twoYearsAgo = calendar.date(byAdding: .year, value: -2, to: now)
            return (nil, twoYearsAgo) // 结束于 2 年前
            
        default:
            return nil
        }
    }
    
    /// 判断是否需要位置过滤
    var locationFilterType: LocationFilterType? {
        switch self {
        case .photosWithLocation:
            return .withLocation
        case .photosWithoutLocation:
            return .withoutLocation
        default:
            return nil
        }
    }
    
    /// 获取视频时长过滤范围（秒）
    /// - Returns: (minDuration, maxDuration) 如果需要时长过滤，返回最小和最大时长；否则返回 nil
    func getDurationFilter() -> (minDuration: TimeInterval?, maxDuration: TimeInterval?)? {
        switch self {
        case .shortVideos:
            return (nil, 30.0) // 小于 30 秒
        case .longVideos:
            return (300.0, nil) // 大于 5 分钟（300 秒）
        default:
            return nil
        }
    }
    
    /// 判断是否需要日期过滤
    var needsDateFilter: Bool {
        return getDateFilter() != nil
    }
    
    /// 判断是否需要位置过滤
    var needsLocationFilter: Bool {
        return locationFilterType != nil
    }
    
    /// 判断是否需要时长过滤
    var needsDurationFilter: Bool {
        return getDurationFilter() != nil
    }
}

// MARK: - Location Filter Type

enum LocationFilterType: String, Codable, CaseIterable, Identifiable {
    case withLocation = "含位置信息"
    case withoutLocation = "无位置信息"
    
    var id: String { rawValue }
}

// MARK: - New Filter Structure (Multi-select Support)

/// 内容类型（单选）
enum ContentType: String, Codable, CaseIterable, Identifiable {
    case all = "所有媒体"
    case screenshots = "仅截图"
    case selfies = "仅自拍"
    case panoramas = "仅全景照片"
    case livePhotos = "仅 Live Photo"
    case portraits = "仅人像模式"
    case bursts = "仅连拍照片"
    case videos = "仅视频"
    case hdrPhotos = "仅 HDR 照片"
    case slowMotionVideos = "仅慢动作视频"
    case timelapseVideos = "仅延时摄影"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .all: return "photo.on.rectangle.angled"
        case .screenshots: return "camera.viewfinder"
        case .selfies: return "person.crop.circle"
        case .panoramas: return "pano"
        case .livePhotos: return "livephoto"
        case .portraits: return "person.fill"
        case .bursts: return "square.stack.3d.up"
        case .videos: return "video.fill"
        case .hdrPhotos: return "circle.lefthalf.filled"
        case .slowMotionVideos: return "slowmo"
        case .timelapseVideos: return "timelapse"
        }
    }
    
    var description: String {
        switch self {
        case .all: return "选择所有类型的照片和视频"
        case .screenshots: return "只选择截屏照片"
        case .selfies: return "只选择前置摄像头拍摄的照片"
        case .panoramas: return "只选择全景模式拍摄的照片"
        case .livePhotos: return "只选择 Live Photo"
        case .portraits: return "只选择人像模式拍摄的照片"
        case .bursts: return "只选择连拍模式的照片"
        case .videos: return "只选择视频文件"
        case .hdrPhotos: return "只选择使用 HDR 模式拍摄的照片"
        case .slowMotionVideos: return "只选择慢动作视频（120fps/240fps）"
        case .timelapseVideos: return "只选择延时摄影视频"
        }
    }
}

/// 日期范围（可选）
enum DateRangeType: String, Codable, CaseIterable, Identifiable {
    case recent7Days = "最近 7 天"
    case recent30Days = "最近 30 天"
    case thisYear = "今年拍摄"
    case lastYear = "去年拍摄"
    case older1Year = "1 年前"
    case older2Years = "2 年前"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .recent7Days: return "calendar.badge.clock"
        case .recent30Days: return "calendar"
        case .thisYear: return "calendar.circle"
        case .lastYear: return "calendar.badge.minus"
        case .older1Year: return "clock.arrow.circlepath"
        case .older2Years: return "clock.badge.exclamationmark"
        }
    }
}

/// 视频时长（可选）
enum DurationFilterType: String, Codable, CaseIterable, Identifiable {
    case shortVideos = "短视频 (<30秒)"
    case longVideos = "长视频 (>5分钟)"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .shortVideos: return "film"
        case .longVideos: return "film.stack"
        }
    }
}

/// 过滤配置（支持多维度组合）
struct FilterConfiguration: Codable, Equatable {
    var contentType: ContentType = .all
    var dateRange: DateRangeType? = nil
    var locationFilter: LocationFilterType? = nil
    var durationFilter: DurationFilterType? = nil
    var excludeHidden: Bool = true
    var excludeFavorite: Bool = true
    
    /// 获取配置摘要（用于显示）
    var summary: String {
        var parts: [String] = []
        
        if contentType != .all {
            parts.append(contentType.rawValue)
        }
        
        if let dateRange = dateRange {
            parts.append(dateRange.rawValue)
        }
        
        if let locationFilter = locationFilter {
            parts.append(locationFilter.rawValue)
        }
        
        if let durationFilter = durationFilter {
            parts.append(durationFilter.rawValue)
        }
        
        if excludeHidden {
            parts.append("排除隐藏")
        }
        
        if excludeFavorite {
            parts.append("排除收藏")
        }
        
        return parts.isEmpty ? "所有媒体" : parts.joined(separator: " 且 ")
    }
    
    /// 验证配置是否有效
    func validate() -> ValidationResult {
        var warnings: [String] = []
        var suggestions: [String] = []
        
        // 检测矛盾配置：图片类型 + 视频时长过滤
        let imageTypes: [ContentType] = [.screenshots, .selfies, .panoramas, .livePhotos, .portraits, .hdrPhotos, .bursts]
        if imageTypes.contains(contentType) && durationFilter != nil {
            warnings.append("⚠️ 图片类型不支持视频时长过滤")
            suggestions.append("移除时长过滤或选择视频类型")
        }
        
        // 检测：视频类型 + 非视频子类型
        let videoTypes: [ContentType] = [.videos, .slowMotionVideos, .timelapseVideos]
        if videoTypes.contains(contentType) && locationFilter == .withLocation {
            suggestions.append("💡 提示：视频的位置信息可能不如照片准确")
        }
        
        // 自拍检测准确度提示
        if contentType == .selfies {
            suggestions.append("💡 自拍检测使用启发式规则，准确度约 70%")
        }
        
        // 检测可能的空结果配置
        if contentType == .bursts && dateRange == .recent7Days {
            suggestions.append("💡 最近的连拍照片可能较少，建议扩大日期范围")
        }
        
        return ValidationResult(
            isValid: warnings.isEmpty,
            warnings: warnings,
            suggestions: suggestions
        )
    }
    
    /// 验证结果
    struct ValidationResult {
        let isValid: Bool
        let warnings: [String]
        let suggestions: [String]
    }
}

// MARK: - Preview

#Preview {
    SessionSetupView(viewModel: TidySessionViewModel())
}

