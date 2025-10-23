//
//  SettingsView.swift
//  PhotoTidy-Toilet Buddy
//
//  Created on 2025-10-22.
//

import SwiftUI

/// 设置页面 - P0 核心功能
struct SettingsView: View {
    
    @Environment(\.dismiss) var dismiss
    @ObservedObject var settingsManager = SettingsManager.shared
    
    // MARK: - State
    
    @State private var showingResetAlert = false
    @State private var showingClearStatsAlert = false
    @State private var showingSuccessToast = false
    @State private var toastMessage = ""
    @State private var showingLanguageChangeAlert = false
    @State private var previousLanguage: AppLanguage?
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            List {
                // Section 1: 外观设置
                appearanceSection
                
                // Section 2: 语言设置
                languageSection
                
                // Section 3: 数据和统计
                dataAndStatsSection
                
                // Section 4: 关于应用
                aboutSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle(L10n.Settings.title)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.Button.done) {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .overlay(alignment: .top) {
                if showingSuccessToast {
                    ToastView(message: toastMessage)
                        .padding(.top, 60)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .alert(L10n.Alert.ResetSettings.title, isPresented: $showingResetAlert) {
                Button(L10n.Button.cancel, role: .cancel) {}
                Button(L10n.Button.reset, role: .destructive) {
                    resetAllSettings()
                }
            } message: {
                Text(L10n.Alert.ResetSettings.message)
            }
            .alert(L10n.Alert.ClearStats.title, isPresented: $showingClearStatsAlert) {
                Button(L10n.Button.cancel, role: .cancel) {}
                Button(L10n.Button.clear, role: .destructive) {
                    clearStatistics()
                }
            } message: {
                Text(L10n.Alert.ClearStats.message)
            }
            .alert(L10n.Alert.hint, isPresented: $showingLanguageChangeAlert) {
                Button(L10n.Button.confirm) {
                    showingLanguageChangeAlert = false
                }
            } message: {
                Text(L10n.Settings.restartRequired)
            }
        }
    }
    
    // MARK: - Section 1: 外观设置
    
    private var appearanceSection: some View {
        Section {
            // 主题选择
            ForEach(AppTheme.allCases) { theme in
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        settingsManager.settings.theme = theme
                    }
                }) {
                    HStack(spacing: 12) {
                        // 主题图标
                        ZStack {
                            Circle()
                                .fill(settingsManager.settings.theme == theme ? Color.blue : Color.gray.opacity(0.2))
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: theme.icon)
                                .font(.system(size: 18))
                                .foregroundColor(settingsManager.settings.theme == theme ? .white : .gray)
                        }
                        
                        // 主题信息
                        VStack(alignment: .leading, spacing: 3) {
                            Text(theme.localizedName)
                                .font(.subheadline)
                                .fontWeight(settingsManager.settings.theme == theme ? .semibold : .regular)
                                .foregroundColor(.primary)
                            
                            Text(theme.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // 选中标记
                        if settingsManager.settings.theme == theme {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                                .font(.system(size: 22))
                        }
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
        } header: {
            SettingsSectionHeader(icon: "paintbrush.fill", title: L10n.Settings.appearance)
        } footer: {
            Text(L10n.Settings.themeDescription)
                .font(.caption)
        }
    }
    
    // MARK: - Section 2: 语言设置
    
    private var languageSection: some View {
        Section {
            ForEach(AppLanguage.allCases) { language in
                Button(action: {
                    if settingsManager.settings.language != language {
                        previousLanguage = settingsManager.settings.language
                        withAnimation(.spring(response: 0.3)) {
                            settingsManager.settings.language = language
                        }
                        // 应用语言变更
                        applyLanguageChange(language)
                        // 显示重启提示
                        showingLanguageChangeAlert = true
                    }
                }) {
                    HStack(spacing: 12) {
                        // 语言图标
                        ZStack {
                            Circle()
                                .fill(settingsManager.settings.language == language ? Color.blue : Color.gray.opacity(0.2))
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: language.icon)
                                .font(.system(size: 18))
                                .foregroundColor(settingsManager.settings.language == language ? .white : .gray)
                        }
                        
                        // 语言信息
                        VStack(alignment: .leading, spacing: 3) {
                            Text(language.localizedName)
                                .font(.subheadline)
                                .fontWeight(settingsManager.settings.language == language ? .semibold : .regular)
                                .foregroundColor(.primary)
                            
                            Text(language.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // 选中标记
                        if settingsManager.settings.language == language {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                                .font(.system(size: 22))
                        }
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
        } header: {
            SettingsSectionHeader(icon: "globe", title: L10n.Settings.language)
        } footer: {
            Text(L10n.Settings.languageDescription)
                .font(.caption)
        }
    }
    
    // MARK: - Section 3: 数据和统计
    
    private var dataAndStatsSection: some View {
        Section {
            // 统计数据展示
            StatisticRow(
                icon: "photo.fill",
                label: L10n.Settings.totalReviewed,
                value: "\(settingsManager.totalReviewedPhotos)",
                color: .blue
            )
            
            StatisticRow(
                icon: "trash.fill",
                label: L10n.Settings.totalDeleted,
                value: "\(settingsManager.totalDeletedPhotos)",
                color: .red
            )
            
            StatisticRow(
                icon: "arrow.down.circle.fill",
                label: L10n.Settings.totalFreedSpace,
                value: settingsManager.formattedTotalFreedSpace(),
                color: .green
            )
            
            StatisticRow(
                icon: "checkmark.circle.fill",
                label: L10n.Settings.totalSessions,
                value: "\(settingsManager.totalSessions)",
                color: .purple
            )
            
            // 清除统计数据按钮
            Button(action: {
                showingClearStatsAlert = true
            }) {
                HStack {
                    Image(systemName: "trash.circle.fill")
                        .foregroundColor(.red)
                        .frame(width: 30)
                    Text(L10n.Settings.clearStats)
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
            }
            
            // 重置所有设置按钮
            Button(action: {
                showingResetAlert = true
            }) {
                HStack {
                    Image(systemName: "arrow.counterclockwise.circle.fill")
                        .foregroundColor(.orange)
                        .frame(width: 30)
                    Text(L10n.Settings.resetSettings)
                        .font(.subheadline)
                        .foregroundColor(.orange)
                }
            }
            
            // 照片库权限
            Button(action: {
                openSettings()
            }) {
                HStack {
                    Image(systemName: "photo.badge.plus")
                        .foregroundColor(.blue)
                        .frame(width: 30)
                    Text(L10n.Settings.photoPermission)
                        .font(.subheadline)
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
        } header: {
            SettingsSectionHeader(icon: "chart.bar.fill", title: L10n.Settings.dataAndStats)
        } footer: {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.Settings.dataLocalOnly)
                    .font(.caption)
                Text(L10n.Settings.statsHelp)
                    .font(.caption)
            }
        }
    }
    
    // MARK: - Section 4: 关于应用
    
    private var aboutSection: some View {
        Section {
            // 应用版本
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                    .frame(width: 30)
                Text(L10n.Settings.appVersion)
                    .font(.subheadline)
                Spacer()
                Text(appVersion)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // 开发者
            HStack {
                Image(systemName: "person.circle")
                    .foregroundColor(.blue)
                    .frame(width: 30)
                Text(L10n.Settings.developer)
                    .font(.subheadline)
                Spacer()
                Text(L10n.Settings.developerName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // 反馈和建议
            Button(action: {
                openFeedback()
            }) {
                HStack {
                    Image(systemName: "envelope.fill")
                        .foregroundColor(.blue)
                        .frame(width: 30)
                    Text(L10n.Settings.feedback)
                        .font(.subheadline)
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // 隐私政策
            Button(action: {
                openPrivacyPolicy()
            }) {
                HStack {
                    Image(systemName: "hand.raised.fill")
                        .foregroundColor(.blue)
                        .frame(width: 30)
                    Text(L10n.Settings.privacyPolicy)
                        .font(.subheadline)
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
        } header: {
            SettingsSectionHeader(icon: "info.circle", title: L10n.Settings.about)
        }
    }
    
    // MARK: - Actions
    
    private func resetAllSettings() {
        settingsManager.resetSettings()
        showToast(L10n.Toast.settingsReset)
    }
    
    private func clearStatistics() {
        settingsManager.clearStatistics()
        showToast(L10n.Toast.statsCleared)
    }
    
    private func applyLanguageChange(_ language: AppLanguage) {
        // 设置应用语言偏好（通过 UserDefaults 持久化）
        if let languageCode = language.languageCode {
            UserDefaults.standard.set([languageCode], forKey: "AppleLanguages")
            AppLogger.shared.info("已设置应用语言为: \(languageCode)", category: .ui)
        } else {
            // 清除设置，跟随系统
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
            AppLogger.shared.info("已设置应用语言为：跟随系统", category: .ui)
        }
        UserDefaults.standard.synchronize()
    }
    
    private func showToast(_ message: String) {
        toastMessage = message
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            showingSuccessToast = true
        }
        
        // 2秒后自动隐藏
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                showingSuccessToast = false
            }
        }
    }
    
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    private func openFeedback() {
        // TODO: 实现反馈功能（邮件或者反馈表单）
        let email = "fangdev1063@gmail.com"
        if let url = URL(string: "mailto:\(email)") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openPrivacyPolicy() {
        // TODO: 实现隐私政策页面
        if let url = URL(string: "https://www.phototidy.app/privacy") {
            UIApplication.shared.open(url)
        }
    }
    
    // MARK: - Computed Properties
    
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (Build \(build))"
    }
}

// MARK: - Supporting Views

struct SettingsSectionHeader: View {
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

struct StatisticRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 30)
            
            Text(label)
                .font(.subheadline)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

struct ToastView: View {
    let message: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.white)
                .font(.title3)
            
            Text(message)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(Color.green)
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        )
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
}

