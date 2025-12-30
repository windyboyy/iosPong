//
//  CloudProbeManager.swift
//  Pong
//
//  Created by 张金琛 on 2025/12/14.
//

import Foundation
import UIKit

// MARK: - 云探测管理器
class CloudProbeManager {
    static let shared = CloudProbeManager()
    
    // API 配置
    private let apiURL = APIConfig.apiURL
    private let auth = APIConfig.defaultAuth
    
    private init() {}
    
    // MARK: - 获取当前设备平台标识
    /// 返回值: ios, ipados, macos, maccatalyst, watchos, tvos, visionos, unknown
    private var currentPlatform: String {
        #if os(iOS)
            #if targetEnvironment(macCatalyst)
            return "maccatalyst"
            #else
            if UIDevice.current.userInterfaceIdiom == .pad {
                return "ipados"
            } else {
                return "ios"
            }
            #endif
        #elseif os(macOS)
        return "macos"
        #elseif os(watchOS)
        return "watchos"
        #elseif os(tvOS)
        return "tvos"
        #elseif os(visionOS)
        return "visionos"
        #else
        return "unknown"
        #endif
    }
    
    // MARK: - 获取探测位置列表
    func fetchProbeLocations(userId: Int) async throws -> [ProbeLocation] {
        let request = CloudProbeRequest(
            Action: "Query",
            AppendInfo: CloudProbeRequest.AppendInfo(UserId: userId),
            Condition: CloudProbeRequest.Condition(AddressFamily: 4, IsPublic: 1),
            Method: "GetAgentGeo",
            SystemId: APIConfig.systemId
        )
        
        let rawData = try await NetworkService.shared.post(
            url: apiURL,
            json: request,
            auth: auth
        ) as Data
        
        let decoder = JSONDecoder()
        let response = try decoder.decode(CloudProbeResponse.self, from: rawData)
        
        if response.Return == 0, let data = response.Data {
            return data
        } else {
            throw CloudProbeError.apiError(response.Details ?? "请求失败")
        }
    }
    
    // MARK: - 创建探测任务
    func createTask(params: CreateTaskParams) async throws -> Int {
        let trimmedHost = params.targetHost.trimmingCharacters(in: .whitespaces)
        
        // 验证域名/IP 格式
        guard isValidHostOrIP(trimmedHost) else {
            throw CloudProbeError.invalidHost
        }
        
        let geoInfo = CreateTaskRequest.GeoInfo(
            AsId: params.selectedASId,
            Country: params.selectedCountry,
            DataSource: "public",
            ISP: params.selectedISP
        )
        
        // 根据探测类型构建不同的 Options
        let msmOptions: CreateTaskRequest.MsmOptions
        switch params.probeType {
        case .dns:
            msmOptions = CreateTaskRequest.MsmOptions(
                timeout_secs: 10,
                rtype: params.dnsRecordType,
                ns: ""
            )
        case .ping, .tcp, .udp:
            msmOptions = CreateTaskRequest.MsmOptions(
                count: 4,
                interval: 0.02,
                size: 64,
                timeout: 4
            )
        }
        
        // 根据探测类型构建目标地址
        let targetAddress: String
        let isIPv6Address = isIPv6(trimmedHost)
        switch params.probeType {
        case .tcp, .udp:
            let port = params.targetPort.trimmingCharacters(in: .whitespaces)
            let validPort = port.isEmpty ? "443" : port
            // IPv6 地址需要用方括号包裹
            if isIPv6Address {
                targetAddress = "[\(trimmedHost)]:\(validPort)"
            } else {
                targetAddress = "\(trimmedHost):\(validPort)"
            }
        case .ping, .dns:
            targetAddress = trimmedHost
        }
        
        // 判断地址族：IPv6 使用 6，其他使用 4
        let addressFamily = isIPv6Address ? 6 : 4
        
        let request = CreateTaskRequest(
            Action: "MsmCustomTask",
            AppendInfo: CreateTaskRequest.AppendInfo(UserId: params.userId),
            Data: CreateTaskRequest.TaskData(
                MainTaskName: "itango-app-\(currentPlatform)-\(params.probeType.msmType)-task",
                MsmSetting: CreateTaskRequest.MsmSetting(
                    Af: addressFamily,
                    MsmType: params.probeType.msmType,
                    Options: msmOptions
                ),
                SubTaskList: [
                    CreateTaskRequest.SubTask(
                        AgentScope: [
                            CreateTaskRequest.AgentScope(
                                GeoInfo: geoInfo,
                                type: "public"
                            )
                        ],
                        SubTaskName: "sub1",
                        TargetScope: [
                            CreateTaskRequest.TargetScope(
                                ExplicitTargetHostList: [targetAddress],
                                type: "public"
                            )
                        ]
                    )
                ]
            ),
            Method: "Create",
            SystemId: APIConfig.systemId
        )
        
        let rawData = try await NetworkService.shared.post(
            url: apiURL,
            json: request,
            auth: auth
        ) as Data
        
        let decoder = JSONDecoder()
        let response = try decoder.decode(CreateTaskResponse.self, from: rawData)
        
        if response.Return == 0, let mainTaskId = response.Data?.MainTaskId {
            return mainTaskId
        } else {
            throw CloudProbeError.apiError(response.Details ?? "创建失败")
        }
    }
    
    // MARK: - 查询任务结果
    func queryTaskResult(mainTaskId: Int, userId: Int, probeType: CloudProbeType) async throws -> CloudProbeResult {
        let request = QueryResultRequest(
            Action: "MsmTaskResult",
            AppendInfo: QueryResultRequest.AppendInfo(UserId: userId),
            Data: QueryResultRequest.QueryData(MainId: mainTaskId),
            Method: "RealTimeTaskResult",
            SystemId: APIConfig.systemIdInt
        )
        
        let rawData = try await NetworkService.shared.post(
            url: apiURL,
            json: request,
            auth: auth
        ) as Data
        
        let decoder = JSONDecoder()
        let response = try decoder.decode(QueryResultResponse.self, from: rawData)
        
        var result = CloudProbeResult()
        
        if response.Return == 0, let data = response.Data {
            if let details = data.Detail, !details.isEmpty {
                // 根据探测类型解析不同的结果
                if probeType == .dns {
                    let jsonData = try JSONSerialization.data(withJSONObject: details.map { $0.value })
                    result.dnsResults = try JSONDecoder().decode([CloudDNSResult].self, from: jsonData)
                } else {
                    let jsonData = try JSONSerialization.data(withJSONObject: details.map { $0.value })
                    result.pingResults = try JSONDecoder().decode([CloudPingResult].self, from: jsonData)
                }
            }
            result.isFinished = data.Finished == true
        }
        
        return result
    }
    
    // MARK: - 轮询查询任务结果
    func pollTaskResult(
        mainTaskId: Int,
        userId: Int,
        probeType: CloudProbeType,
        maxRetries: Int = 5,
        onProgress: @escaping (Int, CloudProbeResult) -> Void
    ) async throws -> CloudProbeResult {
        var queryCount = 0
        var finalResult = CloudProbeResult()
        
        while queryCount < maxRetries {
            queryCount += 1
            
            do {
                let result = try await queryTaskResult(mainTaskId: mainTaskId, userId: userId, probeType: probeType)
                finalResult = result
                onProgress(queryCount, result)
                
                if result.isFinished {
                    break
                }
            } catch {
                print("Query error: \(error)")
            }
            
            // 等待3秒后再次查询
            if queryCount < maxRetries {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
        
        return finalResult
    }
    
    // MARK: - 域名/IP 验证
    func isValidHostOrIP(_ host: String) -> Bool {
        let trimmed = host.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        
        // IPv4 验证
        if isIPv4(trimmed) {
            return true
        }
        
        // IPv6 验证
        if isIPv6(trimmed) {
            return true
        }
        
        // 域名验证
        let domainPattern = "^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\\.)+[a-zA-Z]{2,}$"
        if let domainRegex = try? NSRegularExpression(pattern: domainPattern),
           domainRegex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) != nil,
           trimmed.count <= 253 {
            return true
        }
        
        return false
    }
    
    // 判断是否为 IPv4 地址
    func isIPv4(_ host: String) -> Bool {
        let ipv4Pattern = "^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"
        if let ipv4Regex = try? NSRegularExpression(pattern: ipv4Pattern),
           ipv4Regex.firstMatch(in: host, range: NSRange(host.startIndex..., in: host)) != nil {
            return true
        }
        return false
    }
    
    // 判断是否为 IPv6 地址
    func isIPv6(_ host: String) -> Bool {
        let ipv6Pattern = "^([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}$|^::$|^(([0-9a-fA-F]{1,4}:)*[0-9a-fA-F]{1,4})?::(([0-9a-fA-F]{1,4}:)*[0-9a-fA-F]{1,4})?$"
        if let ipv6Regex = try? NSRegularExpression(pattern: ipv6Pattern),
           ipv6Regex.firstMatch(in: host, range: NSRange(host.startIndex..., in: host)) != nil {
            return true
        }
        return false
    }
}

// MARK: - 错误类型
enum CloudProbeError: LocalizedError {
    case invalidHost
    case apiError(String)
    case noResult
    
    var errorDescription: String? {
        switch self {
        case .invalidHost:
            return L10n.shared.invalidHostFormat
        case .apiError(let message):
            return message
        case .noResult:
            return L10n.shared.noProbeResult
        }
    }
}
