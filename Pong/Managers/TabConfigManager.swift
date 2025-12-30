//
//  TabConfigManager.swift
//  Pong
//
//  Created by 张金琛 on 2025/12/26.
//

import Foundation
import SwiftUI
internal import Combine

// MARK: - Tab 配置模型
struct TabConfig: Codable, Identifiable, Equatable {
    let id: String           // Tab 标识符，对应 AppTab 的 rawValue
    let enabled: Bool        // 是否启用
    let order: Int           // 排序顺序
    let icon: String?        // 自定义图标（可选，为空则使用默认）
    let title: String?       // 自定义标题（可选，为空则使用默认）
    
    enum CodingKeys: String, CodingKey {
        case id
        case enabled
        case order
        case icon
        case title
    }
}

// MARK: - Tab 配置 API 响应
struct AppConfigResponse: Codable {
    let Return: Int?
    let Details: String?
    let ReqId: String?
    let Data: TabConfigData?
}

struct TabConfigData: Codable {
    let tabs: [TabConfig]
    let version: String?     // 配置版本号
    let updateTime: String?  // 更新时间
}

// MARK: - Tab 配置管理器
@MainActor
class TabConfigManager: ObservableObject {
    static let shared = TabConfigManager()
    
    // MARK: - Published 属性
    /// 是否已完成初始化（缓存加载完毕）
    @Published private(set) var isReady = false
    @Published private(set) var enabledTabs: [AppTab] = AppTab.allCases
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: String?
    @Published private(set) var configVersion: String?
    
    // MARK: - 私有属性
    private let userDefaults = UserDefaults.standard
    private let cachedConfigKey = "cachedTabConfig"
    private let configVersionKey = "tabConfigVersion"
    private let lastFetchTimeKey = "tabConfigLastFetchTime"
    private let lastBackgroundTimeKey = "tabConfigLastBackgroundTime"
    
    // 冷启动刷新间隔（秒）- 每次冷启动都刷新
    private let coldStartRefreshInterval: TimeInterval = 0
    // 从后台恢复刷新间隔（秒）- 5 分钟
    private let foregroundRefreshInterval: TimeInterval = 300
    
    // MARK: - 初始化
    private init() {
        // 同步从缓存加载配置，确保首次渲染时配置已就绪
        loadCachedConfig()
        isReady = true
        
        // 监听 App 进入后台/前台
        setupNotifications()
    }
    
    // MARK: - 通知监听
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // 记录进入后台的时间
            self?.userDefaults.set(Date().timeIntervalSince1970, forKey: self?.lastBackgroundTimeKey ?? "")
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshOnForeground()
            }
        }
    }
    
    /// 从后台恢复时刷新
    private func refreshOnForeground() async {
        let lastBackgroundTime = userDefaults.double(forKey: lastBackgroundTimeKey)
        guard lastBackgroundTime > 0 else { return }
        
        let elapsed = Date().timeIntervalSince1970 - lastBackgroundTime
        if elapsed >= foregroundRefreshInterval {
            print("📱 [TabConfig] 从后台恢复，已过 \(Int(elapsed)) 秒，刷新配置")
            await fetchTabConfig(forceRefresh: true)
        }
    }
    
    // MARK: - 公开方法
    
    /// 获取 Tab 配置
    /// - Parameter forceRefresh: 是否强制刷新（忽略缓存）
    func fetchTabConfig(forceRefresh: Bool = false) async {
        // 检查是否需要刷新
        if !forceRefresh && !shouldRefreshConfig() {
            return
        }
        
        isLoading = true
        lastError = nil
        
        // 记录当前配置，用于比较
        let previousTabs = enabledTabs
        
        do {
            let config = try await fetchConfigFromAPI()
            let newTabs = parseConfig(config)
            
            // 只有配置真正变化时才更新（避免不必要的 UI 刷新）
            if newTabs != previousTabs {
                enabledTabs = newTabs
            }
            
            cacheConfig(config)
            configVersion = config.version
        } catch {
            lastError = error.localizedDescription
            // 如果 API 请求失败，保持当前配置不变
            print("Tab 配置获取失败，保持当前配置: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    /// 检查 Tab 是否启用
    func isTabEnabled(_ tab: AppTab) -> Bool {
        return enabledTabs.contains(tab)
    }
    
    /// 获取默认选中的 Tab
    func getDefaultTab() -> AppTab {
        return enabledTabs.first ?? .localProbe
    }
    
    /// 清除缓存并重新加载
    func clearCacheAndReload() async {
        userDefaults.removeObject(forKey: cachedConfigKey)
        userDefaults.removeObject(forKey: configVersionKey)
        userDefaults.removeObject(forKey: lastFetchTimeKey)
        enabledTabs = AppTab.allCases
        await fetchTabConfig(forceRefresh: true)
    }
    
    // MARK: - 私有方法
    
    /// 获取当前平台标识
    private var currentPlatform: String {
        #if os(iOS)
            #if targetEnvironment(macCatalyst)
            return "macCatalyst"  // Mac Catalyst (iPad app on Mac)
            #else
            if UIDevice.current.userInterfaceIdiom == .pad {
                return "iPadOS"
            } else {
                return "iOS"
            }
            #endif
        #elseif os(macOS)
        return "macOS"
        #elseif os(watchOS)
        return "watchOS"
        #elseif os(tvOS)
        return "tvOS"
        #elseif os(visionOS)
        return "visionOS"
        #else
        return "unknown"
        #endif
    }
    
    /// 从 API 获取配置
    private func fetchConfigFromAPI() async throws -> TabConfigData {
        // 构建请求
        let request = AppConfigRequest(
            Action: "App",
            Method: "GetAppConfig",
            SystemId: APIConfig.systemIdInt,
            AppendInfo: AppConfigRequest.AppendInfo(UserId: UserManager.shared.currentUserId),
            Data: AppConfigRequest.RequestData(
                Platform: currentPlatform,
                AppVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
            )
        )
        
        let auth = APIConfig.defaultAuth
        
        let rawData = try await NetworkService.shared.post(
            url: APIConfig.apiURL,
            json: request,
            auth: auth
        )
        
        let decoder = JSONDecoder()
        let response = try decoder.decode(AppConfigResponse.self, from: rawData)
        
        guard response.Return == 0, let data = response.Data else {
            // 如果 API 返回错误或无数据，返回默认配置
            return getDefaultConfig()
        }
        
        return data
    }
    
    /// 获取默认配置
    private func getDefaultConfig() -> TabConfigData {
        let defaultTabs = AppTab.allCases.enumerated().map { index, tab in
            TabConfig(
                id: tab.rawValue,
                enabled: true,
                order: index,
                icon: nil,
                title: nil
            )
        }
        return TabConfigData(tabs: defaultTabs, version: "default", updateTime: nil)
    }
    
    /// 解析配置，返回排序后的 Tab 数组
    private func parseConfig(_ config: TabConfigData) -> [AppTab] {
        let sortedTabs = config.tabs
            .filter { $0.enabled }
            .sorted { $0.order < $1.order }
            .compactMap { tabConfig -> AppTab? in
                AppTab(rawValue: tabConfig.id)
            }
        
        // 如果配置为空，使用默认配置
        return sortedTabs.isEmpty ? AppTab.allCases : sortedTabs
    }
    
    /// 缓存配置
    private func cacheConfig(_ config: TabConfigData) {
        if let encoded = try? JSONEncoder().encode(config) {
            userDefaults.set(encoded, forKey: cachedConfigKey)
            userDefaults.set(config.version, forKey: configVersionKey)
            userDefaults.set(Date().timeIntervalSince1970, forKey: lastFetchTimeKey)
        }
    }
    
    /// 从缓存加载配置（同步方法，确保初始化时立即可用）
    private func loadCachedConfig() {
        guard let data = userDefaults.data(forKey: cachedConfigKey),
              let config = try? JSONDecoder().decode(TabConfigData.self, from: data) else {
            // 没有缓存，使用默认配置
            enabledTabs = AppTab.allCases
            return
        }
        
        enabledTabs = parseConfig(config)
        configVersion = config.version
    }
    
    /// 检查是否需要刷新配置（冷启动时调用）
    private func shouldRefreshConfig() -> Bool {
        // 冷启动：每次都刷新
        return true
    }
}

// MARK: - App 配置请求模型
private struct AppConfigRequest: Encodable {
    let Action: String
    let Method: String
    let SystemId: Int
    let AppendInfo: AppendInfo
    let Data: RequestData
    
    struct AppendInfo: Encodable {
        let UserId: Int
    }
    
    struct RequestData: Encodable {
        let Platform: String
        let AppVersion: String
    }
}
