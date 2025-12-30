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
    case cloudProbe = "cloudProbe"
    case ipQuery = "ipQuery"
    case profile = "profile"
    
    var icon: String {
        switch self {
        case .localProbe: return "iphone.gen1"
        case .cloudProbe: return "icloud"
        case .ipQuery: return "magnifyingglass"
        case .profile: return "person"
        }
    }
    
    func title(_ l10n: L10n) -> String {
        switch self {
        case .localProbe: return l10n.tabLocalProbe
        case .cloudProbe: return l10n.tabCloudProbe
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
        case .cloudProbe:
            CloudProbeView()
        case .ipQuery:
            IPQueryView()
        case .profile:
            ProfileView()
        }
    }
    
    /// 是否需要自定义 tabItem（不使用 Label）
    var needsCustomTabItem: Bool {
        switch self {
        case .cloudProbe, .profile:
            return true
        default:
            return false
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var languageManager: LanguageManager
    @StateObject private var updateManager = AppUpdateManager.shared
    @StateObject private var tabConfigManager = TabConfigManager.shared
    @State private var selectedTab: AppTab = .localProbe
    
    private var l10n: L10n { L10n.shared }
    
    /// 用于标识 TabView 的稳定 ID（只在语言变化时重建）
    private var tabViewId: String {
        languageManager.currentLanguage.rawValue
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(tabConfigManager.enabledTabs, id: \.self) { tab in
                tab.view()
                    .tabItem {
                        if tab.needsCustomTabItem {
                            Image(systemName: tab == .cloudProbe ? "cloud" : "person")
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
        .task {
            // 后台静默获取 Tab 配置（不阻塞 UI）
            await tabConfigManager.fetchTabConfig()
        }
        .task {
            // 启动时检查更新
            await updateManager.checkUpdateOnLaunch()
        }
        .alert(l10n.newVersionAvailable, isPresented: $updateManager.showUpdateAlert) {
            if updateManager.isForceUpdate {
                Button(l10n.updateNow) {
                    updateManager.openAppStore()
                }
            } else {
                Button(l10n.updateLater, role: .cancel) {
                    updateManager.dismissUpdate()
                }
                Button(l10n.ignoreThisVersion) {
                    updateManager.ignoreCurrentUpdate()
                }
                Button(l10n.updateNow) {
                    updateManager.openAppStore()
                }
            }
        } message: {
            if let data = updateManager.updateData {
                Text("\(l10n.currentVersion): \(updateManager.currentVersion) → \(l10n.latestVersion): \(data.latestVersion)\n\n\(data.updateContent)")
            }
        }
        .onChange(of: tabConfigManager.enabledTabs) { _, newTabs in
            // 当配置变化时，确保选中的 Tab 仍然有效
            if !newTabs.contains(selectedTab) {
                selectedTab = tabConfigManager.getDefaultTab()
            }
        }
        .onAppear {
            // 确保初始选中的 Tab 是有效的
            if !tabConfigManager.enabledTabs.contains(selectedTab) {
                selectedTab = tabConfigManager.getDefaultTab()
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(LanguageManager.shared)
}
