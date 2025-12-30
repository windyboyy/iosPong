//
//  AppUpdateManager.swift
//  Pong
//
//  Created by 张金琛 on 2025/12/23.
//

import Foundation
import UIKit
internal import Combine

// MARK: - 版本信息响应
struct AppVersionResponse: Codable {
    let `return`: Int
    let details: String
    let reqId: String
    let data: AppVersionData?
    
    enum CodingKeys: String, CodingKey {
        case `return` = "Return"
        case details = "Details"
        case reqId = "ReqId"
        case data = "Data"
    }
    
    var isSuccess: Bool {
        `return` == 0
    }
}

struct AppVersionData: Codable {
    let latestVersion: String       // 最新版本号，如 "1.2.0"
    let minVersion: String          // 最低支持版本，低于此版本强制更新
    let updateTitle: String         // 更新标题
    let updateContent: String       // 更新内容（支持换行符 \n）
    let downloadUrl: String         // 下载地址（App Store 链接）
    let forceUpdate: Bool           // 是否强制更新
    let publishTime: String         // 发布时间
    
    enum CodingKeys: String, CodingKey {
        case latestVersion = "LatestVersion"
        case minVersion = "MinVersion"
        case updateTitle = "UpdateTitle"
        case updateContent = "UpdateContent"
        case downloadUrl = "DownloadUrl"
        case forceUpdate = "ForceUpdate"
        case publishTime = "PublishTime"
    }
}

// MARK: - 更新检查结果
enum UpdateCheckResult {
    case noUpdate                           // 无更新
    case optionalUpdate(AppVersionData)     // 可选更新
    case forceUpdate(AppVersionData)        // 强制更新
    case error(String)                      // 检查失败
}

// MARK: - 应用更新管理器
@MainActor
class AppUpdateManager: ObservableObject {
    static let shared = AppUpdateManager()
    
    // MARK: - Published 属性
    @Published var isChecking = false
    @Published var showUpdateAlert = false
    @Published var updateData: AppVersionData?
    @Published var isForceUpdate = false
    
    private let apiURL = APIConfig.apiURL
    private let auth = APIConfig.defaultAuth
    
    // 记录上次检查时间，避免频繁检查
    private let lastCheckKey = "LastUpdateCheckTime"
    private let checkInterval: TimeInterval = 86400 // 24小时检查一次
    
    // 记录用户忽略的版本
    private let ignoredVersionKey = "IgnoredAppVersion"
    
    private init() {}
    
    // MARK: - 获取当前版本号
    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    // MARK: - 获取 Build 号
    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    // MARK: - 检查更新（启动时调用）
    func checkUpdateOnLaunch() async {
        // 检查是否需要检查更新
        if let lastCheck = UserDefaults.standard.object(forKey: lastCheckKey) as? Date {
            let timeSinceLastCheck = Date().timeIntervalSince(lastCheck)
            if timeSinceLastCheck < checkInterval {
                let hoursRemaining = Int((checkInterval - timeSinceLastCheck) / 3600)
                print("距离上次检查不足24小时，跳过检查（剩余 \(hoursRemaining) 小时）")
                return
            }
        }
        
        await checkUpdate(showAlertIfNoUpdate: false)
    }
    
    // MARK: - 检查更新
    func checkUpdate(showAlertIfNoUpdate: Bool = false) async -> UpdateCheckResult {
        isChecking = true
        defer { isChecking = false }
        
        do {
            let requestBody: [String: Any] = [
                "Action": "App",
                "Method": "CheckVersion",
                "SystemId": auth.systemId,
                "AppendInfo": [
                    "UserId": UserManager.shared.currentUserId
                ],
                "Data": [
                    "Platform": "iOS",
                    "CurrentVersion": currentVersion,
                    "DeviceModel": DeviceInfoManager.shared.deviceInfo?.deviceModel ?? "",
                    "SystemVersion": UIDevice.current.systemVersion
                ]
            ]
            
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
            
            let responseData = try await NetworkService.shared.post(
                url: apiURL,
                body: jsonData,
                headers: ["Content-Type": "application/json"],
                auth: auth
            )
            
            let response = try JSONDecoder().decode(AppVersionResponse.self, from: responseData)
            
            // 记录检查时间
            UserDefaults.standard.set(Date(), forKey: lastCheckKey)
            
            guard response.isSuccess, let data = response.data else {
                return .noUpdate
            }
            
            // 比较版本号
            let comparison = compareVersions(currentVersion, data.latestVersion)
            
            if comparison >= 0 {
                // 当前版本 >= 最新版本，无需更新
                return .noUpdate
            }
            
            // 检查是否低于最低支持版本（强制更新）
            let minComparison = compareVersions(currentVersion, data.minVersion)
            if minComparison < 0 || data.forceUpdate {
                // 强制更新
                updateData = data
                isForceUpdate = true
                showUpdateAlert = true
                return .forceUpdate(data)
            }
            
            // 检查用户是否已忽略此版本（仅在自动检查时生效，手动检查时忽略此设置）
            if !showAlertIfNoUpdate,
               let ignoredVersion = UserDefaults.standard.string(forKey: ignoredVersionKey),
               ignoredVersion == data.latestVersion {
                return .noUpdate
            }
            
            // 可选更新
            updateData = data
            isForceUpdate = false
            showUpdateAlert = true
            return .optionalUpdate(data)
            
        } catch {
            print("检查更新失败: \(error.localizedDescription)")
            return .error(error.localizedDescription)
        }
    }
    
    // MARK: - 比较版本号
    /// 返回值: -1 表示 v1 < v2, 0 表示相等, 1 表示 v1 > v2
    private func compareVersions(_ v1: String, _ v2: String) -> Int {
        let parts1 = v1.split(separator: ".").compactMap { Int($0) }
        let parts2 = v2.split(separator: ".").compactMap { Int($0) }
        
        let maxLength = max(parts1.count, parts2.count)
        
        for i in 0..<maxLength {
            let p1 = i < parts1.count ? parts1[i] : 0
            let p2 = i < parts2.count ? parts2[i] : 0
            
            if p1 < p2 { return -1 }
            if p1 > p2 { return 1 }
        }
        
        return 0
    }
    
    // MARK: - 忽略此版本
    func ignoreCurrentUpdate() {
        if let version = updateData?.latestVersion {
            UserDefaults.standard.set(version, forKey: ignoredVersionKey)
        }
        showUpdateAlert = false
    }
    
    // MARK: - 打开 App Store
    func openAppStore() {
        guard let urlString = updateData?.downloadUrl,
              let url = URL(string: urlString) else {
            // 默认打开 App Store（需要替换为实际的 App ID）
            if let url = URL(string: "https://apps.apple.com/app/id123456789") {
                UIApplication.shared.open(url)
            }
            return
        }
        UIApplication.shared.open(url)
    }
    
    // MARK: - 关闭更新弹窗
    func dismissUpdate() {
        if !isForceUpdate {
            showUpdateAlert = false
        }
    }
}
