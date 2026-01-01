//
//  ContentView.swift
//  Pong
//
//  Created by 张金琛 on 2025/12/12.
//

import SwiftUI

// MARK: - Tab 类型
enum AppTab: String, CaseIterable {
    case localProbe = "localProbe"
    case speedTest = "speedTest"
    case ipQuery = "ipQuery"
    case profile = "profile"
    
    var icon: String {
        switch self {
        case .localProbe: return "iphone.gen1"
        case .speedTest: return "speedometer"
        case .ipQuery: return "magnifyingglass"
        case .profile: return "person"
        }
    }
    
    func title(_ l10n: L10n) -> String {
        switch self {
        case .localProbe: return l10n.tabLocalProbe
        case .speedTest: return l10n.speedTest
        case .ipQuery: return l10n.tabIPQuery
        case .profile: return l10n.tabProfile
        }
    }
    
    /// 获取 Tab 对应的视图
    @ViewBuilder
    func view() -> some View {
        switch self {
        case .localProbe:
            HomeView()
        case .speedTest:
            NavigationStack {
                SpeedTestView()
            }
        case .ipQuery:
            IPQueryView()
        case .profile:
            ProfileView()
        }
    }
    
    /// 是否需要自定义 tabItem（不使用 Label）
    var needsCustomTabItem: Bool {
        switch self {
        case .profile:
            return true
        default:
            return false
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var languageManager: LanguageManager
    @State private var selectedTab: AppTab = .localProbe
    
    private var l10n: L10n { L10n.shared }
    
    /// 用于标识 TabView 的稳定 ID（只在语言变化时重建）
    private var tabViewId: String {
        languageManager.currentLanguage.rawValue
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                tab.view()
                    .tabItem {
                        if tab.needsCustomTabItem {
                            Image(systemName: "person")
                                .environment(\.symbolVariants, .none)
                            Text(tab.title(l10n))
                        } else {
                            Label(tab.title(l10n), systemImage: tab.icon)
                        }
                    }
                    .tag(tab)
            }
        }
        .tint(.blue)
        .id(tabViewId) // 只在语言变化时重建 TabView
    }
}

#Preview {
    ContentView()
        .environmentObject(LanguageManager.shared)
}
