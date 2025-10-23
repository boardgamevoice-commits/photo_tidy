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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    // MARK: - State Properties
    
    @State private var photoCount: Double = 10
    @State private var filterConfig: FilterConfiguration = FilterConfiguration()
    @State private var showingAdvancedFilter = false
    @State private var showingError = false
    @State private var showingSettings = false
    
    // 激励广告相关状态
    @State private var isAdFree = false
    @State private var remainingAdFreeTime: String?
    @State private var isLoadingRewardedAd = false
    @State private var showingRewardedAdResult = false
    @State private var rewardedAdResultMessage = ""
    @State private var adCheckTimer: Timer?
    
    // 预加载防抖任务
    @State private var preloadDebounceTask: Task<Void, Error>?
    
    // 照片数量计算状态
    @State private var photoCountResult: PhotoCountResult = .calculating
    @State private var countCalculationTask: Task<Void, Never>?
    
    // MARK: - UserDefaults Keys
    
    private let photoCountKey = "sessionSetup.photoCount"
    private let filterConfigKey = "sessionSetup.filterConfiguration"
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            ScrollView {
                if isIPad {
                    iPadLayout
                } else {
                    iPhoneLayout
                }
            }
            .navigationTitle(L10n.SessionSetup.title)
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
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $showingAdvancedFilter) {
            AdvancedFilterView(filterConfig: $filterConfig)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .onChange(of: filterConfig) { _ in
            saveUserPreferences()
            restartPreloading() // 新增：配置变化时重新预加载
            calculateTotalPhotoCount() // 新增：重新计算照片总数
        }
        .alert(L10n.Alert.hint, isPresented: $showingError) {
            Button(L10n.Button.confirm, role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? L10n.Error.general)
        }
        .onAppear {
            loadUserPreferences()
            updateAdFreeStatus()
            startAdStatusCheck()
            startPreloading() // 新增：开始预加载
            calculateTotalPhotoCount() // 新增：计算照片总数
        }
        .onDisappear {
            stopAdStatusCheck()
            stopPreloading() // 新增：停止预加载
            cancelPhotoCountCalculation() // 新增：取消照片数量计算
        }
        .onChange(of: viewModel.errorMessage) { newValue in
            showingError = newValue != nil
        }
        .alert(rewardedAdResultMessage, isPresented: $showingRewardedAdResult) {
            Button(L10n.Button.confirm, role: .cancel) { }
        }
    }
    
    // MARK: - Device Detection
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular && verticalSizeClass == .regular
    }
    
    // MARK: - Layout Variants
    
    private var iPhoneLayout: some View {
        VStack(spacing: 22) {
            // 标题区域
            headerSection
            
            // 激励广告卡片
            rewardedAdSection
            
            // 统计卡片（如果有完成的会话）
            if viewModel.isSessionCompleted {
                sessionCompletedCard
            }
            
            // 数量选择区域 (F-02)
            photoCountSection
            
            // 启动按钮
            startButton
            
            // 快速过滤选项
            quickFiltersSection
            
            // 高级过滤入口 (F-03.1)
            advancedFilterButton
            
            Spacer(minLength: 20)
        }
        .padding()
    }
    
    private var iPadLayout: some View {
        VStack(spacing: 30) {
            // 标题区域
            headerSection
            
            // 激励广告卡片
            rewardedAdSection
            
            // 统计卡片（如果有完成的会话）
            if viewModel.isSessionCompleted {
                sessionCompletedCard
            }
            
            // iPad 双列布局
            HStack(alignment: .top, spacing: 30) {
                // 左列：数量选择和启动按钮
                VStack(spacing: 25) {
                    photoCountSection
                    startButton
                }
                .frame(maxWidth: .infinity)
                
                // 右列：过滤选项
                VStack(spacing: 25) {
                    quickFiltersSection
                    advancedFilterButton
                }
                .frame(maxWidth: .infinity)
            }
            
            Spacer(minLength: 40)
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 20)
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack(spacing: isIPad ? 30 : 20) {
            // 左侧图标
            Image(systemName: "photo.stack.fill")
                .resizable()
                .scaledToFit()
                .frame(width: isIPad ? 90 : 70, height: isIPad ? 90 : 70)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // 右侧文本（垂直排列）
            VStack(alignment: .leading, spacing: isIPad ? 12 : 8) {
                Text(L10n.App.name)
                    .font(.system(size: isIPad ? 40 : 32, weight: .bold, design: .rounded))
                
                Text(L10n.App.tagline)
                    .font(.system(size: isIPad ? 18 : 16))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(.top, isIPad ? 30 : 20)
        .padding(.horizontal, isIPad ? 10 : 5)
    }
    
    // MARK: - Rewarded Ad Section
    
    private var rewardedAdSection: some View {
        Group {
            if isAdFree {
                // 显示无广告状态
                adFreeStatusCard
            } else {
                // 显示观看广告按钮
                watchAdCard
            }
        }
        .padding(.horizontal, 20)
    }
    
    private var adFreeStatusCard: some View {
        HStack(spacing: 12) {
            // 图标
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.green, .green.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 42, height: 42)
                
                Image(systemName: "checkmark.shield.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .medium))
            }
            
            // 文字内容
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.RewardedAd.statusActive)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.green)
                
                if let timeString = remainingAdFreeTime {
                    Text(L10n.RewardedAd.statusRemainingTime(timeString))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.green.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var watchAdCard: some View {
        let adReady = AdManager.shared.isRewardedAdReady()
        
        return HStack(spacing: 12) {
            // 图标
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: adReady ? [.yellow, .orange] : [.gray, .gray.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 42, height: 42)
                
                Image(systemName: "gift.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .medium))
            }
            
            // 文字内容
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.RewardedAd.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(adReady ? .primary : .secondary)
                
                Text(adReady ? L10n.RewardedAd.description : L10n.RewardedAd.loading)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 观看按钮
            Button(action: {
                handleWatchRewardedAd()
            }) {
                Group {
                    if isLoadingRewardedAd {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.7)
                    } else {
                        Text(L10n.RewardedAd.buttonWatch)
                            .font(.system(size: 13, weight: .semibold))
                    }
                }
                .frame(minWidth: 65)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    LinearGradient(
                        colors: adReady ? [.yellow, .orange] : [.gray, .gray.opacity(0.7)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(8)
                .opacity(adReady ? 1.0 : 0.6)
            }
            .disabled(isLoadingRewardedAd || !adReady)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(adReady ? Color.yellow.opacity(0.1) : Color.gray.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(adReady ? Color.yellow.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Session Completed Card
    
    private var sessionCompletedCard: some View {
        VStack(spacing: 15) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
                
                Text(L10n.SessionSetup.lastCompleted)
                    .font(.headline)
                
                Spacer()
            }
            
            HStack(spacing: 30) {
                StatItem(
                    icon: "trash.fill",
                    label: L10n.SessionComplete.deleted,
                    value: viewModel.deletedCount,
                    color: .red
                )
                
                Divider()
                    .frame(height: 40)
                
                StatItem(
                    icon: "hand.thumbsup.fill",
                    label: L10n.SessionComplete.kept,
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
        VStack(alignment: .leading, spacing: isIPad ? 20 : 15) {
            HStack {
                Image(systemName: "photo.on.rectangle.angled")
                    .foregroundColor(.blue)
                    .font(.title2)
                Text(L10n.SessionSetup.photoCount)
                    .font(.system(size: isIPad ? 20 : 18, weight: .semibold))
                Spacer()
                
                // 总数量显示
                HStack(spacing: 4) {
                    Text("(total:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
            switch photoCountResult {
            case .calculating:
                Text(NSLocalizedString("photo.count.calculating", comment: ""))
                    .font(.caption)
                    .foregroundColor(.blue)
            case .success(let count):
                Text("\(count)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
            case .error:
                Text(NSLocalizedString("photo.count.unknown", comment: ""))
                    .font(.caption)
                    .foregroundColor(.red)
            }
                    
                    Text(")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // 当前选中的数量显示
            HStack {
                Spacer()
                Text("\(Int(photoCount))")
                    .font(.system(size: isIPad ? 60 : 48, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Text(L10n.SessionSetup.unitPhoto)
                    .font(.system(size: isIPad ? 24 : 20))
                    .foregroundColor(.secondary)
                    .padding(.leading, 5)
                Spacer()
            }
            .padding(.vertical, isIPad ? 15 : 10)
            
            // Slider
            VStack(spacing: isIPad ? 12 : 8) {
                Slider(value: $photoCount, in: 10...100, step: 5)
                    .accentColor(.blue)
                    .onChange(of: photoCount) { newValue in
                        saveUserPreferences()
                        restartPreloading() // 新增：数量变化时重新预加载
                    }
                
                HStack {
                    Text("10")
                        .font(.system(size: isIPad ? 14 : 12))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("100")
                        .font(.system(size: isIPad ? 14 : 12))
                        .foregroundColor(.secondary)
                }
            }
            
            // 预设按钮
            HStack(spacing: isIPad ? 16 : 12) {
                PresetButton(value: 10, currentValue: $photoCount, label: L10n.SessionSetup.Preset.quick)
                PresetButton(value: 30, currentValue: $photoCount, label: L10n.SessionSetup.Preset.standard)
                PresetButton(value: 50, currentValue: $photoCount, label: L10n.SessionSetup.Preset.deep)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: isIPad ? 20 : 15)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: isIPad ? 8 : 5, x: 0, y: isIPad ? 4 : 2)
        )
    }
    
    // MARK: - Quick Filters Section
    
    private var quickFiltersSection: some View {
        VStack(alignment: .leading, spacing: isIPad ? 20 : 15) {
            HStack {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .foregroundColor(.purple)
                    .font(.title2)
                Text(L10n.SessionSetup.quickFilters)
                    .font(.system(size: isIPad ? 20 : 18, weight: .semibold))
                Spacer()
            }
            
            VStack(spacing: isIPad ? 16 : 12) {
                FilterToggle(
                    icon: "eye.slash.fill",
                    title: L10n.Filter.excludeHiddenPhotos,
                    isOn: Binding(
                        get: { filterConfig.excludeHidden },
                        set: { filterConfig.excludeHidden = $0 }
                    ),
                    color: .orange
                )
                
                FilterToggle(
                    icon: "heart.fill",
                    title: L10n.Filter.excludeFavoritePhotos,
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
            RoundedRectangle(cornerRadius: isIPad ? 20 : 15)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: isIPad ? 8 : 5, x: 0, y: isIPad ? 4 : 2)
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
                    Text(L10n.SessionSetup.advancedFilters)
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
            HStack(spacing: isIPad ? 16 : 12) {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(isIPad ? 1.1 : 0.9)
                } else {
                    Image(systemName: "play.fill")
                        .font(isIPad ? .title2 : .title3)
                }
                Text(getStartButtonText())
                    .font(.system(size: isIPad ? 20 : 18, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(isIPad ? EdgeInsets(top: 20, leading: 30, bottom: 20, trailing: 30) : EdgeInsets(top: 16, leading: 24, bottom: 16, trailing: 24))
            .background(
                LinearGradient(
                    colors: viewModel.isLoading ? [.gray, .gray.opacity(0.8)] : [.blue, .purple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(isIPad ? 16 : 12)
        }
        .disabled(viewModel.isLoading)
        .shadow(color: viewModel.isLoading ? Color.gray.opacity(0.2) : Color.blue.opacity(0.3), radius: isIPad ? 12 : 10, x: 0, y: isIPad ? 6 : 5)
        .animation(.easeInOut(duration: 0.3), value: viewModel.isLoading)
    }
    
    // MARK: - Actions
    
    /// 获取启动按钮文本
    private func getStartButtonText() -> String {
        if viewModel.isLoading {
            return L10n.Loading.general
        } else if viewModel.isSessionCompleted {
            return L10n.Button.startNewSession
        } else {
            return L10n.Button.start
        }
    }
    
    private func startSession() {
        Task {
            if viewModel.hasPreloadedPhotos {
                // 使用预加载的照片启动会话
                await viewModel.startNewSessionWithPreloadedPhotos()
            } else {
                // 回退到原有逻辑
                await viewModel.startNewSession(
                    count: Int(photoCount),
                    filterConfig: filterConfig
                )
            }
        }
    }
    
    // MARK: - Rewarded Ad Actions
    
    /// 更新无广告状态
    private func updateAdFreeStatus() {
        isAdFree = AdFreeManager.shared.isAdFree()
        remainingAdFreeTime = AdFreeManager.shared.getFormattedRemainingTime()
        
        AppLogger.shared.debug("无广告状态更新: isAdFree=\(isAdFree), remaining=\(remainingAdFreeTime ?? "nil")", category: .ui)
    }
    
    /// 开始定期检查广告状态（用于UI更新）
    private func startAdStatusCheck() {
        // 每10秒检查一次广告和无广告状态
        adCheckTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            updateAdFreeStatus()
        }
    }
    
    /// 停止广告状态检查
    private func stopAdStatusCheck() {
        adCheckTimer?.invalidate()
        adCheckTimer = nil
    }
    
    /// 处理观看激励广告
    private func handleWatchRewardedAd() {
        // 检查广告是否准备好
        if !AdManager.shared.isRewardedAdReady() {
            // 静默处理：不显示错误提示，只在控制台记录
            AppLogger.shared.warning("激励广告未准备好，静默跳过", category: .ui)
            // 尝试重新加载广告
            AdManager.shared.loadRewardedAd()
            return
        }
        
        AppLogger.shared.info("用户点击观看激励广告", category: .ui)
        isLoadingRewardedAd = true
        
        // 展示激励广告
        AdManager.shared.showRewardedAd { [self] rewardGranted in
            // 广告关闭后的回调
            DispatchQueue.main.async {
                self.isLoadingRewardedAd = false
                
                if rewardGranted {
                    // 用户看完广告，激活无广告模式
                    AppLogger.shared.info("用户获得奖励，激活24小时无广告", category: .ui)
                    AdFreeManager.shared.activateAdFree()
                    
                    // 更新UI状态
                    self.updateAdFreeStatus()
                    
                    // 显示成功提示
                    self.rewardedAdResultMessage = L10n.RewardedAd.rewardReceived
                    self.showingRewardedAdResult = true
                } else {
                    // 用户中途退出，未获得奖励
                    AppLogger.shared.info("用户未完成广告，未获得奖励", category: .ui)
                    // 静默处理：不显示"需要看完广告"的提示
                    // 用户主动关闭广告，不需要额外提醒
                    AppLogger.shared.info("用户选择不观看广告，静默返回", category: .ui)
                }
            }
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
            AppLogger.shared.debug("已加载上次照片数量：\(Int(photoCount))", category: .ui)
        }
        
        // 加载上一次的过滤配置
        if let data = defaults.data(forKey: filterConfigKey),
           let decoded = try? JSONDecoder().decode(FilterConfiguration.self, from: data) {
            filterConfig = decoded
            AppLogger.shared.debug("已加载上次过滤配置：\(filterConfig.summary)", category: .ui)
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
        
        AppLogger.shared.debug("已保存用户偏好设置：photoCount=\(Int(photoCount)), filterConfig=\(filterConfig.summary)", category: .ui)
    }
    
    // MARK: - Preload Methods (预加载方法)
    
    /// 开始预加载
    private func startPreloading() {
        // 使用防抖处理，避免频繁重新加载
        restartPreloading()
    }
    
    /// 重新开始预加载（带防抖）
    private func restartPreloading() {
        // 取消之前的防抖任务
        preloadDebounceTask?.cancel()
        
        // 创建新的防抖任务
        preloadDebounceTask = Task {
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5秒防抖
            if !Task.isCancelled {
                viewModel.startPreloading(
                    count: Int(photoCount),
                    filterConfig: filterConfig
                )
            }
        }
    }
    
    /// 停止预加载
    private func stopPreloading() {
        preloadDebounceTask?.cancel()
        preloadDebounceTask = nil
        viewModel.cancelPreloading()
    }
    
    // MARK: - Photo Count Calculation
    
    /// 计算满足过滤条件的照片总数
    private func calculateTotalPhotoCount() {
        // 取消之前的计算任务
        countCalculationTask?.cancel()
        
        countCalculationTask = Task {
            // 在后台线程开始计算
            await MainActor.run {
                photoCountResult = .calculating
            }
            
            do {
                // 在后台线程执行计算
                let count = try await performPhotoCountCalculation(filterConfig: filterConfig)
                if !Task.isCancelled {
                    // 在主线程更新UI
                    await MainActor.run {
                        photoCountResult = .success(count)
                        AppLogger.shared.debug("主页照片数量计算完成: \(count)张", category: .ui)
                    }
                }
            } catch {
                if !Task.isCancelled {
                    // 在主线程更新UI
                    await MainActor.run {
                        photoCountResult = .error(error.localizedDescription)
                        AppLogger.shared.error("主页照片数量计算失败: \(error)", category: .ui)
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
        
        // 处理自拍特殊逻辑（需要后置过滤）
        if filterConfig.contentType == .selfies {
            finalCount = try await countSelfies(from: fetchResult)
        }
        
        // 处理位置信息过滤（需要后置过滤）
        if let locationFilter = filterConfig.locationFilter {
            finalCount = try await countWithLocationFilter(from: fetchResult, locationFilter: locationFilter)
        }
        
        return finalCount
    }
    
    /// 计算自拍照片数量（需要后置过滤）
    private func countSelfies(from fetchResult: PHFetchResult<PHAsset>) async throws -> Int {
        var selfieCount = 0
        
        // 简化实现：直接返回总数，不进行复杂的自拍检测
        // 在实际应用中，自拍检测需要更复杂的逻辑
        selfieCount = fetchResult.count
        
        AppLogger.shared.debug("自拍过滤后剩余 \(selfieCount) 张照片", category: .photo)
        return selfieCount
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
    
    /// 取消照片数量计算
    private func cancelPhotoCountCalculation() {
        countCalculationTask?.cancel()
        countCalculationTask = nil
    }
}

// MARK: - Supporting Views

struct PresetButton: View {
    let value: Double
    @Binding var currentValue: Double
    let label: String
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    var isSelected: Bool {
        currentValue == value
    }
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular && verticalSizeClass == .regular
    }
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3)) {
                currentValue = value
            }
        }) {
            VStack(spacing: isIPad ? 8 : 6) {
                Text("\(Int(value))")
                    .font(.system(size: isIPad ? 20 : 18, weight: .bold))
                Text(label)
                    .font(.system(size: isIPad ? 14 : 12))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, isIPad ? 16 : 12)
            .background(
                RoundedRectangle(cornerRadius: isIPad ? 12 : 10)
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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular && verticalSizeClass == .regular
    }
    
    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: isIPad ? 16 : 12) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: isIPad ? 28 : 24)
                    .font(isIPad ? .title3 : .body)
                
                Text(title)
                    .font(.system(size: isIPad ? 18 : 16))
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
    case withLocation
    case withoutLocation
    
    var id: String { rawValue }
    
    var localizedName: String {
        switch self {
        case .withLocation: return NSLocalizedString("location.with_location", comment: "")
        case .withoutLocation: return NSLocalizedString("location.without_location", comment: "")
        }
    }
}

// MARK: - New Filter Structure (Multi-select Support)

/// 内容类型（单选）
enum ContentType: String, Codable, CaseIterable, Identifiable {
    case all
    case screenshots
    case selfies
    case panoramas
    case livePhotos
    case portraits
    case bursts
    case videos
    case hdrPhotos
    case slowMotionVideos
    case timelapseVideos
    
    var id: String { rawValue }
    
    var localizedName: String {
        switch self {
        case .all: return NSLocalizedString("content.all", comment: "")
        case .screenshots: return NSLocalizedString("content.screenshots", comment: "")
        case .selfies: return NSLocalizedString("content.selfies", comment: "")
        case .panoramas: return NSLocalizedString("content.panoramas", comment: "")
        case .livePhotos: return NSLocalizedString("content.live_photos", comment: "")
        case .portraits: return NSLocalizedString("content.portraits", comment: "")
        case .bursts: return NSLocalizedString("content.bursts", comment: "")
        case .videos: return NSLocalizedString("content.videos", comment: "")
        case .hdrPhotos: return NSLocalizedString("content.hdr_photos", comment: "")
        case .slowMotionVideos: return NSLocalizedString("content.slow_motion_videos", comment: "")
        case .timelapseVideos: return NSLocalizedString("content.timelapse_videos", comment: "")
        }
    }
    
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
        case .all: return NSLocalizedString("content.all.desc", comment: "")
        case .screenshots: return NSLocalizedString("content.screenshots.desc", comment: "")
        case .selfies: return NSLocalizedString("content.selfies.desc", comment: "")
        case .panoramas: return NSLocalizedString("content.panoramas.desc", comment: "")
        case .livePhotos: return NSLocalizedString("content.live_photos.desc", comment: "")
        case .portraits: return NSLocalizedString("content.portraits.desc", comment: "")
        case .bursts: return NSLocalizedString("content.bursts.desc", comment: "")
        case .videos: return NSLocalizedString("content.videos.desc", comment: "")
        case .hdrPhotos: return NSLocalizedString("content.hdr_photos.desc", comment: "")
        case .slowMotionVideos: return NSLocalizedString("content.slow_motion_videos.desc", comment: "")
        case .timelapseVideos: return NSLocalizedString("content.timelapse_videos.desc", comment: "")
        }
    }
}

/// 日期范围（可选）
enum DateRangeType: String, Codable, CaseIterable, Identifiable {
    case recent7Days
    case recent30Days
    case thisYear
    case lastYear
    case older1Year
    case older2Years
    
    var id: String { rawValue }
    
    var localizedName: String {
        switch self {
        case .recent7Days: return NSLocalizedString("date.recent_7_days", comment: "")
        case .recent30Days: return NSLocalizedString("date.recent_30_days", comment: "")
        case .thisYear: return NSLocalizedString("date.this_year", comment: "")
        case .lastYear: return NSLocalizedString("date.last_year", comment: "")
        case .older1Year: return NSLocalizedString("date.older_1_year", comment: "")
        case .older2Years: return NSLocalizedString("date.older_2_years", comment: "")
        }
    }
    
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
    case shortVideos
    case longVideos
    
    var id: String { rawValue }
    
    var localizedName: String {
        switch self {
        case .shortVideos: return NSLocalizedString("duration.short_videos", comment: "")
        case .longVideos: return NSLocalizedString("duration.long_videos", comment: "")
        }
    }
    
    var icon: String {
        switch self {
        case .shortVideos: return "film"
        case .longVideos: return "film.stack"
        }
    }
}

/// 照片数量计算错误类型
enum PhotoCountError: LocalizedError {
    case permissionDenied
    case calculationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return NSLocalizedString("photo.count.permission_denied", comment: "")
        case .calculationFailed(let reason):
            return String(format: NSLocalizedString("photo.count.calculation_failed", comment: ""), reason)
        }
    }
}

/// 照片数量计算结果状态
enum PhotoCountResult {
    case calculating
    case success(Int)
    case error(String)
    
    var displayText: String {
        switch self {
        case .calculating:
            return "计算中..."
        case .success(let count):
            return "\(count)"
        case .error:
            return "未知"
        }
    }
    
    var isCalculating: Bool {
        if case .calculating = self {
            return true
        }
        return false
    }
    
    var count: Int? {
        if case .success(let count) = self {
            return count
        }
        return nil
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
            parts.append(contentType.localizedName)
        }
        
        if let dateRange = dateRange {
            parts.append(dateRange.localizedName)
        }
        
        if let locationFilter = locationFilter {
            parts.append(locationFilter.localizedName)
        }
        
        if let durationFilter = durationFilter {
            parts.append(durationFilter.localizedName)
        }
        
        if excludeHidden {
            parts.append(NSLocalizedString("filter.summary.exclude_hidden", comment: ""))
        }
        
        if excludeFavorite {
            parts.append(NSLocalizedString("filter.summary.exclude_favorite", comment: ""))
        }
        
        return parts.isEmpty ? NSLocalizedString("filter.summary.all_media", comment: "") : parts.joined(separator: NSLocalizedString("filter.summary.and", comment: ""))
    }
    
    /// 验证配置是否有效
    func validate() -> ValidationResult {
        var warnings: [String] = []
        var suggestions: [String] = []
        
        // 检测矛盾配置：图片类型 + 视频时长过滤
        let imageTypes: [ContentType] = [.screenshots, .selfies, .panoramas, .livePhotos, .portraits, .hdrPhotos, .bursts]
        if imageTypes.contains(contentType) && durationFilter != nil {
            warnings.append(NSLocalizedString("validation.warning.image_with_duration", comment: ""))
            suggestions.append(NSLocalizedString("validation.suggestion.remove_duration", comment: ""))
        }
        
        // 检测：视频类型 + 非视频子类型
        let videoTypes: [ContentType] = [.videos, .slowMotionVideos, .timelapseVideos]
        if videoTypes.contains(contentType) && locationFilter == .withLocation {
            suggestions.append(NSLocalizedString("validation.suggestion.video_location", comment: ""))
        }
        
        // 自拍检测准确度提示
        if contentType == .selfies {
            suggestions.append(NSLocalizedString("validation.suggestion.selfie_accuracy", comment: ""))
        }
        
        // 检测可能的空结果配置
        if contentType == .bursts && dateRange == .recent7Days {
            suggestions.append(NSLocalizedString("validation.suggestion.burst_date_range", comment: ""))
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

