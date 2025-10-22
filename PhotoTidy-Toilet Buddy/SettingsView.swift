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
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            List {
                // Section 1: 数据和统计
                dataAndStatsSection
                
                // Section 2: 关于应用
                aboutSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
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
            .alert("重置所有设置", isPresented: $showingResetAlert) {
                Button("取消", role: .cancel) {}
                Button("重置", role: .destructive) {
                    resetAllSettings()
                }
            } message: {
                Text("这将恢复所有设置为默认值，但不会影响统计数据。")
            }
            .alert("清除统计数据", isPresented: $showingClearStatsAlert) {
                Button("取消", role: .cancel) {}
                Button("清除", role: .destructive) {
                    clearStatistics()
                }
            } message: {
                Text("这将永久删除所有统计数据，此操作无法撤销。")
            }
        }
    }
    
    // MARK: - Section 1: 数据和统计
    
    private var dataAndStatsSection: some View {
        Section {
            // 统计数据展示
            StatisticRow(
                icon: "photo.fill",
                label: "已审阅照片总数",
                value: "\(settingsManager.totalReviewedPhotos)",
                color: .blue
            )
            
            StatisticRow(
                icon: "trash.fill",
                label: "已删除照片总数",
                value: "\(settingsManager.totalDeletedPhotos)",
                color: .red
            )
            
            StatisticRow(
                icon: "arrow.down.circle.fill",
                label: "累计释放空间",
                value: settingsManager.formattedTotalFreedSpace(),
                color: .green
            )
            
            StatisticRow(
                icon: "checkmark.circle.fill",
                label: "完成会话次数",
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
                    Text("清除统计数据")
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
                    Text("重置所有设置")
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
                    Text("查看照片库权限")
                        .font(.subheadline)
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
        } header: {
            SettingsSectionHeader(icon: "chart.bar.fill", title: "数据和统计")
        } footer: {
            VStack(alignment: .leading, spacing: 8) {
                Text("所有操作均在本地进行，不会上传任何数据")
                    .font(.caption)
                Text("统计数据用于帮助您了解使用情况")
                    .font(.caption)
            }
        }
    }
    
    // MARK: - Section 2: 关于应用
    
    private var aboutSection: some View {
        Section {
            // 应用版本
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                    .frame(width: 30)
                Text("应用版本")
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
                Text("开发者")
                    .font(.subheadline)
                Spacer()
                Text("Photo Tidy Team")
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
                    Text("反馈和建议")
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
                    Text("隐私政策")
                        .font(.subheadline)
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
        } header: {
            SettingsSectionHeader(icon: "info.circle", title: "关于")
        }
    }
    
    // MARK: - Actions
    
    private func resetAllSettings() {
        settingsManager.resetSettings()
        showToast("设置已重置为默认值")
    }
    
    private func clearStatistics() {
        settingsManager.clearStatistics()
        showToast("统计数据已清除")
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
        let email = "feedback@phototidy.app"
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

