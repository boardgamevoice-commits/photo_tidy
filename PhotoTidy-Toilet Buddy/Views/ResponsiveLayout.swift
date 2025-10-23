//
//  ResponsiveLayout.swift
//  PhotoTidy-Toilet Buddy
//
//  Created on 2025-10-22.
//

import SwiftUI

// MARK: - 响应式布局组件

/// 响应式容器视图 - 根据设备类型和尺寸类别自动调整布局
struct ResponsiveContainer<Content: View>: View {
    let content: Content
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        Group {
            if isIPad {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
    }
    
    // MARK: - 设备检测
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular && verticalSizeClass == .regular
    }
    
    // MARK: - 布局变体
    
    private var iPhoneLayout: some View {
        content
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
    }
    
    private var iPadLayout: some View {
        content
            .frame(maxWidth: 800) // 限制最大宽度，避免在大屏幕上过度拉伸
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 40)
    }
}

// MARK: - 响应式网格布局

/// 响应式网格容器 - 根据设备类型调整列数
struct ResponsiveGrid<Content: View>: View {
    let content: Content
    let iPhoneColumns: Int
    let iPadColumns: Int
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    init(
        iPhoneColumns: Int = 1,
        iPadColumns: Int = 2,
        @ViewBuilder content: () -> Content
    ) {
        self.iPhoneColumns = iPhoneColumns
        self.iPadColumns = iPadColumns
        self.content = content()
    }
    
    var body: some View {
        let columns = isIPad ? iPadColumns : iPhoneColumns
        
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: columns),
            spacing: 16
        ) {
            content
        }
    }
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular && verticalSizeClass == .regular
    }
}

// MARK: - 响应式卡片布局

/// 响应式卡片容器 - 根据设备类型调整卡片样式和间距
struct ResponsiveCard<Content: View>: View {
    let content: Content
    let backgroundColor: Color
    let cornerRadius: CGFloat
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    init(
        backgroundColor: Color = Color(.systemBackground),
        cornerRadius: CGFloat = 15,
        @ViewBuilder content: () -> Content
    ) {
        self.backgroundColor = backgroundColor
        self.cornerRadius = cornerRadius
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(backgroundColor)
                    .shadow(
                        color: Color.black.opacity(0.1),
                        radius: shadowRadius,
                        x: 0,
                        y: shadowOffset
                    )
            )
    }
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular && verticalSizeClass == .regular
    }
    
    private var padding: EdgeInsets {
        if isIPad {
            return EdgeInsets(top: 24, leading: 24, bottom: 24, trailing: 24)
        } else {
            return EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        }
    }
    
    private var shadowRadius: CGFloat {
        isIPad ? 8 : 5
    }
    
    private var shadowOffset: CGFloat {
        isIPad ? 4 : 2
    }
}

// MARK: - 响应式间距

/// 响应式间距 - 根据设备类型调整间距
struct ResponsiveSpacing: View {
    let iPhoneSpacing: CGFloat
    let iPadSpacing: CGFloat
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    init(iPhone: CGFloat, iPad: CGFloat) {
        self.iPhoneSpacing = iPhone
        self.iPadSpacing = iPad
    }
    
    var body: some View {
        Spacer()
            .frame(height: isIPad ? iPadSpacing : iPhoneSpacing)
    }
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular && verticalSizeClass == .regular
    }
}

// MARK: - 响应式字体

/// 响应式字体修饰符
struct ResponsiveFont: ViewModifier {
    let iPhoneSize: CGFloat
    let iPadSize: CGFloat
    let weight: Font.Weight
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    init(size: CGFloat, iPadSize: CGFloat? = nil, weight: Font.Weight = .regular) {
        self.iPhoneSize = size
        self.iPadSize = iPadSize ?? size * 1.2
        self.weight = weight
    }
    
    func body(content: Content) -> some View {
        content
            .font(.system(size: isIPad ? iPadSize : iPhoneSize, weight: weight))
    }
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular && verticalSizeClass == .regular
    }
}

// MARK: - 响应式按钮

/// 响应式按钮 - 根据设备类型调整按钮大小
struct ResponsiveButton<Label: View>: View {
    let action: () -> Void
    let label: Label
    let style: ButtonStyle
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    enum ButtonStyle {
        case primary
        case secondary
        case preset
    }
    
    init(
        style: ButtonStyle = .primary,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) {
        self.style = style
        self.action = action
        self.label = label()
    }
    
    var body: some View {
        Button(action: action) {
            label
                .padding(buttonPadding)
                .frame(minHeight: buttonMinHeight)
                .background(buttonBackground)
                .foregroundColor(buttonForegroundColor)
                .cornerRadius(buttonCornerRadius)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular && verticalSizeClass == .regular
    }
    
    private var buttonPadding: EdgeInsets {
        let basePadding: CGFloat = isIPad ? 20 : 16
        switch style {
        case .primary:
            return EdgeInsets(top: basePadding, leading: basePadding * 1.5, bottom: basePadding, trailing: basePadding * 1.5)
        case .secondary:
            return EdgeInsets(top: basePadding * 0.75, leading: basePadding, bottom: basePadding * 0.75, trailing: basePadding)
        case .preset:
            return EdgeInsets(top: basePadding * 0.5, leading: basePadding * 0.75, bottom: basePadding * 0.5, trailing: basePadding * 0.75)
        }
    }
    
    private var buttonMinHeight: CGFloat {
        isIPad ? 60 : 44
    }
    
    private var buttonCornerRadius: CGFloat {
        isIPad ? 16 : 12
    }
    
    @ViewBuilder
    private var buttonBackground: some View {
        switch style {
        case .primary:
            LinearGradient(
                colors: [.blue, .purple],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .secondary:
            Color.gray.opacity(0.15)
        case .preset:
            Color.blue
        }
    }
    
    private var buttonForegroundColor: Color {
        switch style {
        case .primary, .preset:
            return .white
        case .secondary:
            return .primary
        }
    }
}

// MARK: - 响应式导航视图

/// 响应式导航视图 - 在iPad上使用NavigationSplitView，iPhone上使用NavigationView
struct ResponsiveNavigationView<Sidebar: View, Detail: View>: View {
    let sidebar: Sidebar
    let detail: Detail
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    init(
        @ViewBuilder sidebar: () -> Sidebar,
        @ViewBuilder detail: () -> Detail
    ) {
        self.sidebar = sidebar()
        self.detail = detail()
    }
    
    var body: some View {
        if isIPad {
            NavigationSplitView {
                sidebar
            } detail: {
                detail
            }
        } else {
            NavigationView {
                detail
            }
        }
    }
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular && verticalSizeClass == .regular
    }
}

// MARK: - 扩展方法

extension View {
    /// 应用响应式字体
    func responsiveFont(size: CGFloat, iPadSize: CGFloat? = nil, weight: Font.Weight = .regular) -> some View {
        self.modifier(ResponsiveFont(size: size, iPadSize: iPadSize, weight: weight))
    }
    
    /// 应用响应式容器
    func responsiveContainer() -> some View {
        ResponsiveContainer {
            self
        }
    }
    
    /// 应用响应式卡片
    func responsiveCard(backgroundColor: Color = Color(.systemBackground), cornerRadius: CGFloat = 15) -> some View {
        ResponsiveCard(backgroundColor: backgroundColor, cornerRadius: cornerRadius) {
            self
        }
    }
}

// MARK: - 预览

#Preview("iPhone Layout") {
    ResponsiveContainer {
        VStack(spacing: 20) {
            Text("iPhone Layout")
                .responsiveFont(size: 24, weight: .bold)
            
            ResponsiveCard {
                VStack {
                    Text("Card Content")
                    Text("This is optimized for iPhone")
                }
            }
            
            ResponsiveButton(style: .primary) {
                print("Button tapped")
            } label: {
                Text("Primary Button")
            }
        }
    }
    .environment(\.horizontalSizeClass, .compact)
    .environment(\.verticalSizeClass, .regular)
}

#Preview("iPad Layout") {
    ResponsiveContainer {
        VStack(spacing: 20) {
            Text("iPad Layout")
                .responsiveFont(size: 24, weight: .bold)
            
            ResponsiveCard {
                VStack {
                    Text("Card Content")
                    Text("This is optimized for iPad")
                }
            }
            
            ResponsiveButton(style: .primary) {
                print("Button tapped")
            } label: {
                Text("Primary Button")
            }
        }
    }
    .environment(\.horizontalSizeClass, .regular)
    .environment(\.verticalSizeClass, .regular)
}
