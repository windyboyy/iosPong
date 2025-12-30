//
//  TaskHistoryManager.swift
//  Pong
//
//  Created by 张金琛 on 2025/12/16.
//

import Foundation
internal import Combine

// MARK: - 任务类型
enum TaskType: String, Codable, CaseIterable {
    case ping = "ping"
    case traceroute = "traceroute"
    case dns = "dns"
    case tcp = "tcp"
    case udp = "udp"
    case speedTest = "speedTest"
    case http = "http"
    
    var displayName: String {
        switch self {
        case .ping: return "Ping"
        case .traceroute: return "Traceroute"
        case .dns: return "DNS"
        case .tcp: return "TCP"
        case .udp: return "UDP"
        case .speedTest: return L10n.shared.speedTest
        case .http: return "HTTP"
        }
    }
    
    var iconName: String {
        switch self {
        case .ping: return "network"
        case .traceroute: return "point.topleft.down.curvedto.point.bottomright.up"
        case .dns: return "globe"
        case .tcp: return "arrow.left.arrow.right"
        case .udp: return "paperplane"
        case .speedTest: return "speedometer"
        case .http: return "globe"
        }
    }
}

// MARK: - 任务状态
enum TaskStatus: String, Codable {
    case success = "success"
    case failure = "failure"
    case partial = "partial"
    
    var displayName: String {
        let l10n = L10n.shared
        switch self {
        case .success: return l10n.success
        case .failure: return l10n.failure
        case .partial: return l10n.unknown
        }
    }
}

// MARK: - 历史任务记录
struct TaskHistoryRecord: Identifiable, Codable {
    let id: String
    let type: TaskType
    let target: String
    let port: Int?
    let status: TaskStatus
    let resultSummary: String  // 保留用于兼容，但优先使用 localizedSummary
    let timestamp: Date
    let details: TaskDetails?
    let useIPv6: Bool?  // 用户选择的 IP 版本：nil=默认, false=IPv4, true=IPv6
    
    init(id: String = UUID().uuidString, type: TaskType, target: String, port: Int? = nil, status: TaskStatus, resultSummary: String, timestamp: Date = Date(), details: TaskDetails? = nil, useIPv6: Bool? = nil) {
        self.id = id
        self.type = type
        self.target = target
        self.port = port
        self.status = status
        self.resultSummary = resultSummary
        self.timestamp = timestamp
        self.details = details
        self.useIPv6 = useIPv6
    }
    
    /// 根据当前语言动态生成摘要
    var localizedSummary: String {
        let l10n = L10n.shared
        
        guard let details = details else {
            return resultSummary
        }
        
        switch type {
        case .ping:
            if status == .success, let avg = details.pingAvgLatency {
                return String(format: "%@ %.1fms, %@ %.1f%%", l10n.avgLatency, avg, l10n.lossRate, details.pingLossRate ?? 0)
            } else {
                return l10n.failure
            }
            
        case .traceroute:
            if let hops = details.traceHops {
                let reached = details.traceReachedTarget == true
                return "\(l10n.totalHops) \(hops) \(l10n.hops), \(reached ? l10n.reachedTarget : l10n.notReachedTarget)"
            }
            return resultSummary
            
        case .dns:
            if status == .success {
                if let records = details.dnsRecords, !records.isEmpty {
                    var summary = records.first ?? ""
                    if records.count > 1 {
                        summary += " (+\(records.count - 1))"
                    }
                    return summary
                } else {
                    return l10n.noData
                }
            } else {
                return l10n.failure
            }
            
        case .tcp:
            // 批量扫描模式
            if let portResults = details.tcpPortResults, portResults.count > 1 {
                let openCount = details.tcpOpenCount ?? portResults.filter { $0.isOpen }.count
                let totalCount = details.tcpTotalCount ?? portResults.count
                return "\(openCount)/\(totalCount) \(l10n.open)"
            }
            // 单端口模式
            if details.tcpIsOpen == true {
                if let lat = details.tcpLatency {
                    return "\(l10n.open), \(String(format: "%.1fms", lat))"
                } else {
                    return l10n.open
                }
            } else {
                return l10n.closed
            }
            
        case .udp:
            let sent = details.udpSent == true
            let received = details.udpReceived == true
            if sent && received {
                return l10n.success
            } else if sent {
                return l10n.noResponse
            } else {
                return l10n.sendFailed
            }
            
        case .speedTest:
            if status == .success, let down = details.downloadSpeed, let up = details.uploadSpeed {
                return String(format: "↓%.1f Mbps ↑%.1f Mbps", down, up)
            } else {
                return l10n.failure
            }
            
        case .http:
            if status == .success, let code = details.httpStatusCode {
                if let time = details.httpResponseTime {
                    return "HTTP \(code), \(String(format: "%.0fms", time))"
                } else {
                    return "HTTP \(code)"
                }
            } else {
                return details.httpError ?? l10n.failure
            }
        }
    }
}

// MARK: - 任务详情
struct TaskDetails: Codable {
    // 通用字段
    var duration: Double?  // 执行时长（秒）
    var errorMessage: String?  // 错误信息
    
    // Ping 详情
    var pingAvgLatency: Double?
    var pingMinLatency: Double?
    var pingMaxLatency: Double?
    var pingStdDev: Double?  // 标准差
    var pingLossRate: Double?
    var pingSent: Int?
    var pingReceived: Int?
    var pingPacketSize: Int?
    var pingResolvedIP: String?  // 解析后的 IP 地址
    var pingResults: [PingResultDetail]?  // 每次 ping 的详细结果
    
    // Traceroute 详情
    var traceHops: Int?
    var traceReachedTarget: Bool?
    var traceHopDetails: [TraceHopDetail]?  // 每一跳的详细信息
    
    // DNS 详情
    var dnsRecords: [String]?
    var dnsRecordDetails: [DNSRecordDetail]?  // 完整的 DNS 记录详情
    var dnsQueryTime: Double?
    var dnsServer: String?
    var dnsRecordType: String?
    
    // TCP 详情
    var tcpIsOpen: Bool?
    var tcpLatency: Double?
    var tcpPortResults: [TCPPortDetail]?  // 批量端口扫描结果
    var tcpOpenCount: Int?    // 开放端口数
    var tcpTotalCount: Int?   // 总扫描端口数
    
    // UDP 详情
    var udpSent: Bool?
    var udpReceived: Bool?
    var udpLatency: Double?  // UDP 延迟（毫秒）
    
    // 测速详情
    var downloadSpeed: Double?
    var uploadSpeed: Double?
    var latency: Double?
    
    // HTTP 详情
    var httpStatusCode: Int?
    var httpResponseTime: Double?  // 毫秒
    var httpError: String?
}

// MARK: - Ping 单次结果详情
struct PingResultDetail: Codable {
    let sequence: Int
    let success: Bool
    let latency: Double?  // 毫秒
}

// MARK: - Traceroute 跳详情
struct TraceHopDetail: Codable {
    let hop: Int
    let ip: String
    let hostname: String?
    let avgLatency: Double?  // 毫秒
    let lossRate: Double     // 0-100
    let sentCount: Int
    let receivedCount: Int
    let location: String?    // IP 归属地
}

// MARK: - DNS 记录详情
struct DNSRecordDetail: Codable {
    let name: String?
    let type: String
    let ttl: UInt32?
    let value: String
}

// MARK: - TCP 端口扫描结果详情
struct TCPPortDetail: Codable {
    let port: Int
    let serviceName: String?
    let isOpen: Bool
    let latency: Double?  // 毫秒
}

// MARK: - 历史任务管理器
class TaskHistoryManager: ObservableObject {
    static let shared = TaskHistoryManager()
    
    private let storageKey = "com.pong.taskHistory"
    private let expirationDays: Int = 14
    
    @Published var records: [TaskHistoryRecord] = []
    
    private init() {
        loadRecords()
        cleanExpiredRecords()
    }
    
    // MARK: - 添加记录
    func addRecord(_ record: TaskHistoryRecord) {
        records.insert(record, at: 0)
        saveRecords()
    }
    
    // MARK: - 添加 Ping 记录
    func addPingRecord(target: String, status: TaskStatus, avgLatency: Double?, minLatency: Double? = nil, maxLatency: Double? = nil, stdDev: Double? = nil, lossRate: Double?, sent: Int, received: Int, packetSize: Int = 64, resolvedIP: String? = nil, pingResults: [PingResultDetail]? = nil, duration: Double? = nil, useIPv6: Bool? = nil, errorMessage: String? = nil) {
        let l10n = L10n.shared
        var summary: String
        if let error = errorMessage {
            summary = error
        } else if status == .success, let avg = avgLatency {
            summary = String(format: "%@ %.1fms, %@ %.1f%%", l10n.avgLatency, avg, l10n.lossRate, lossRate ?? 0)
        } else {
            summary = l10n.failure
        }
        
        let details = TaskDetails(
            duration: duration,
            errorMessage: errorMessage,
            pingAvgLatency: avgLatency,
            pingMinLatency: minLatency,
            pingMaxLatency: maxLatency,
            pingStdDev: stdDev,
            pingLossRate: lossRate,
            pingSent: sent,
            pingReceived: received,
            pingPacketSize: packetSize,
            pingResolvedIP: resolvedIP,
            pingResults: pingResults
        )
        
        let record = TaskHistoryRecord(
            type: .ping,
            target: target,
            status: status,
            resultSummary: summary,
            details: details,
            useIPv6: useIPv6
        )
        addRecord(record)
    }
    
    // MARK: - 添加 Traceroute 记录
    func addTracerouteRecord(target: String, status: TaskStatus, hops: Int, reachedTarget: Bool, hopDetails: [TraceHopDetail]? = nil, duration: Double? = nil, errorMessage: String? = nil, useIPv6: Bool? = nil) {
        let l10n = L10n.shared
        let summary: String
        if let error = errorMessage {
            summary = error
        } else {
            summary = "\(l10n.totalHops) \(hops) \(l10n.hops), \(reachedTarget ? l10n.reachedTarget : l10n.notReachedTarget)"
        }
        
        let details = TaskDetails(
            duration: duration,
            errorMessage: errorMessage,
            traceHops: hops,
            traceReachedTarget: reachedTarget,
            traceHopDetails: hopDetails
        )
        
        let record = TaskHistoryRecord(
            type: .traceroute,
            target: target,
            status: status,
            resultSummary: summary,
            details: details,
            useIPv6: useIPv6
        )
        addRecord(record)
    }
    
    // MARK: - 添加 DNS 记录
    func addDNSRecord(target: String, status: TaskStatus, records: [String], recordDetails: [DNSRecordDetail]? = nil, queryTime: Double?, server: String? = nil, recordType: String? = nil, duration: Double? = nil) {
        let l10n = L10n.shared
        var summary: String
        if status == .success {
            if records.isEmpty {
                summary = l10n.noData
            } else {
                summary = records.first ?? ""
                if records.count > 1 {
                    summary += " (+\(records.count - 1))"
                }
            }
        } else {
            summary = l10n.failure
        }
        
        let details = TaskDetails(
            duration: duration,
            dnsRecords: records,
            dnsRecordDetails: recordDetails,
            dnsQueryTime: queryTime,
            dnsServer: server,
            dnsRecordType: recordType
        )
        
        let record = TaskHistoryRecord(
            type: .dns,
            target: target,
            status: status,
            resultSummary: summary,
            details: details
        )
        addRecord(record)
    }
    
    // MARK: - 添加 TCP 记录（单端口）
    func addTCPRecord(target: String, port: Int, status: TaskStatus, isOpen: Bool, latency: Double?, useIPv6: Bool? = nil, errorMessage: String? = nil) {
        let l10n = L10n.shared
        var summary: String
        if let error = errorMessage {
            summary = error
        } else if isOpen {
            if let lat = latency {
                summary = "\(l10n.open), \(String(format: "%.1fms", lat))"
            } else {
                summary = l10n.open
            }
        } else {
            summary = l10n.closed
        }
        
        let details = TaskDetails(
            errorMessage: errorMessage,
            tcpIsOpen: isOpen,
            tcpLatency: latency
        )
        
        let record = TaskHistoryRecord(
            type: .tcp,
            target: target,
            port: port,
            status: status,
            resultSummary: summary,
            details: details,
            useIPv6: useIPv6
        )
        addRecord(record)
    }
    
    // MARK: - 添加 TCP 批量扫描记录
    func addTCPScanRecord(target: String, portResults: [TCPPortDetail], duration: Double? = nil, useIPv6: Bool? = nil, errorMessage: String? = nil) {
        let l10n = L10n.shared
        let openCount = portResults.filter { $0.isOpen }.count
        let totalCount = portResults.count
        
        // 确定状态
        let status: TaskStatus
        if let _ = errorMessage {
            status = .failure
        } else if openCount == 0 {
            status = .failure
        } else if openCount == totalCount {
            status = .success
        } else {
            status = .partial
        }
        
        let summary: String
        if let error = errorMessage {
            summary = error
        } else {
            summary = "\(openCount)/\(totalCount) \(l10n.open)"
        }
        
        // 找第一个开放端口的延迟作为代表
        let firstOpenLatency = portResults.first { $0.isOpen }?.latency
        
        let details = TaskDetails(
            duration: duration,
            errorMessage: errorMessage,
            tcpIsOpen: openCount > 0,
            tcpLatency: firstOpenLatency,
            tcpPortResults: portResults,
            tcpOpenCount: openCount,
            tcpTotalCount: totalCount
        )
        
        let record = TaskHistoryRecord(
            type: .tcp,
            target: target,
            port: nil,  // 批量扫描不指定单一端口
            status: status,
            resultSummary: summary,
            details: details,
            useIPv6: useIPv6
        )
        addRecord(record)
    }
    
    // MARK: - 添加 UDP 记录
    func addUDPRecord(target: String, port: Int, status: TaskStatus, sent: Bool, received: Bool, latency: Double? = nil, duration: Double? = nil, useIPv6: Bool? = nil, errorMessage: String? = nil) {
        let l10n = L10n.shared
        var summary: String
        if let error = errorMessage {
            summary = error
        } else if sent && received {
            summary = l10n.success
        } else if sent {
            summary = l10n.noResponse
        } else {
            summary = l10n.sendFailed
        }
        
        let details = TaskDetails(
            duration: duration,
            errorMessage: errorMessage,
            udpSent: sent,
            udpReceived: received,
            udpLatency: latency
        )
        
        let record = TaskHistoryRecord(
            type: .udp,
            target: target,
            port: port,
            status: status,
            resultSummary: summary,
            details: details,
            useIPv6: useIPv6
        )
        addRecord(record)
    }
    
    // MARK: - 添加测速记录
    func addSpeedTestRecord(status: TaskStatus, downloadSpeed: Double?, uploadSpeed: Double?, latency: Double?) {
        let l10n = L10n.shared
        var summary: String
        if status == .success, let down = downloadSpeed, let up = uploadSpeed {
            summary = String(format: "↓%.1f Mbps ↑%.1f Mbps", down, up)
        } else {
            summary = l10n.failure
        }
        
        let details = TaskDetails(
            downloadSpeed: downloadSpeed,
            uploadSpeed: uploadSpeed,
            latency: latency
        )
        
        let record = TaskHistoryRecord(
            type: .speedTest,
            target: "Cloudflare",
            status: status,
            resultSummary: summary,
            details: details
        )
        addRecord(record)
    }
    
    // MARK: - 添加 HTTP 记录
    func addHTTPRecord(url: String, status: TaskStatus, statusCode: Int?, responseTime: Double?, error: String?) {
        let l10n = L10n.shared
        var summary: String
        if status == .success, let code = statusCode {
            if let time = responseTime {
                summary = "HTTP \(code), \(String(format: "%.0fms", time))"
            } else {
                summary = "HTTP \(code)"
            }
        } else {
            summary = error ?? l10n.failure
        }
        
        let details = TaskDetails(
            httpStatusCode: statusCode,
            httpResponseTime: responseTime,
            httpError: error
        )
        
        let record = TaskHistoryRecord(
            type: .http,
            target: url,
            status: status,
            resultSummary: summary,
            details: details
        )
        addRecord(record)
    }
    
    // MARK: - 删除记录
    func deleteRecord(_ record: TaskHistoryRecord) {
        records.removeAll { $0.id == record.id }
        saveRecords()
    }
    
    // MARK: - 清空所有记录
    func clearAllRecords() {
        records.removeAll()
        saveRecords()
    }
    
    // MARK: - 清理过期记录
    func cleanExpiredRecords() {
        let expirationDate = Calendar.current.date(byAdding: .day, value: -expirationDays, to: Date()) ?? Date()
        let originalCount = records.count
        records = records.filter { $0.timestamp > expirationDate }
        
        if records.count != originalCount {
            saveRecords()
        }
    }
    
    // MARK: - 按类型筛选记录
    func records(ofType type: TaskType) -> [TaskHistoryRecord] {
        records.filter { $0.type == type }
    }
    
    // MARK: - 持久化
    private func loadRecords() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([TaskHistoryRecord].self, from: data) else {
            return
        }
        records = decoded
    }
    
    private func saveRecords() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
    
    // MARK: - 上传历史记录
    private let apiURL = APIConfig.apiURL
    
    /// 检查是否可以上传（需要登录且非游客）
    func canUpload() -> Bool {
        guard let user = UserManager.shared.currentUser else {
            return false
        }
        return UserManager.shared.isLoggedIn && !user.isGuest
    }
    
    /// 上传单条历史记录
    func uploadRecord(_ record: TaskHistoryRecord) async -> Bool {
        // 检查登录状态
        guard canUpload() else {
            print("未登录或游客状态，无法上传")
            return false
        }
        
        guard let msmData = buildReportData(record: record) else {
            print("无法构建上报数据")
            return false
        }
        
        let requestBody: [String: Any] = [
            "Action": "MsmReceive",
            "Method": "BatchRun",
            "SystemId": APIConfig.systemId,
            "AppendInfo": [
                "UserId": UserManager.shared.currentUserId
            ],
            "Data": [msmData]
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
            
            let auth = APIConfig.defaultAuth
            
            let responseData = try await NetworkService.shared.post(
                url: apiURL,
                body: jsonData,
                headers: ["Content-Type": "application/json"],
                auth: auth
            )
            
            return true
        } catch {
            print("历史记录上报失败: \(error.localizedDescription)")
            return false
        }
    }
    
    /// 批量上传历史记录
    func uploadRecords(_ records: [TaskHistoryRecord]) async -> (success: Int, failed: Int) {
        // 检查登录状态
        guard canUpload() else {
            print("未登录或游客状态，无法上传")
            return (0, records.count)
        }
        
        var msmDataList: [[String: Any]] = []
        for record in records {
            if let msmData = buildReportData(record: record) {
                msmDataList.append(msmData)
            }
        }
        
        guard !msmDataList.isEmpty else {
            return (0, records.count)
        }
        
        let requestBody: [String: Any] = [
            "Action": "MsmReceive",
            "Method": "BatchRun",
            "SystemId": APIConfig.systemId,
            "AppendInfo": [
                "UserId": UserManager.shared.currentUserId
            ],
            "Data": msmDataList
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
            
            let auth = APIConfig.defaultAuth
            
            let responseData = try await NetworkService.shared.post(
                url: apiURL,
                body: jsonData,
                headers: ["Content-Type": "application/json"],
                auth: auth
            )
            
            if let responseStr = String(data: responseData, encoding: .utf8) {
                print("批量上报响应: \(responseStr)")
            }
            return (msmDataList.count, 0)
        } catch {
            print("批量上报失败: \(error.localizedDescription)")
            return (0, msmDataList.count)
        }
    }
    
    /// 构建上报数据
    private func buildReportData(record: TaskHistoryRecord) -> [String: Any]? {
        let source = ReportDataBuilder.ReportSource.history
        let errorMsg = record.status == .failure ? (record.details?.errorMessage ?? "执行失败") : nil
        
        // 使用记录中保存的 useIPv6（执行时已根据实际解析结果判断）
        let useIPv6 = record.useIPv6 ?? false
        
        switch record.type {
        case .ping:
            guard let details = record.details else { return nil }
            
            // 构建 results 数组
            let results: [(sequence: Int, success: Bool, latency: TimeInterval?)]
            if let pingResults = details.pingResults {
                results = pingResults.map { ($0.sequence, $0.success, $0.latency.map { $0 / 1000 }) }  // ms -> 秒
            } else {
                results = []
            }
            
            let data = ReportDataBuilder.buildPingData(
                target: record.target,
                packetSize: details.pingPacketSize ?? 64,
                count: details.pingSent ?? 0,
                successCount: details.pingReceived ?? 0,
                avgLatency: details.pingAvgLatency.map { $0 / 1000 },      // ms -> 秒
                minLatency: details.pingMinLatency.map { $0 / 1000 },
                maxLatency: details.pingMaxLatency.map { $0 / 1000 },
                stdDev: details.pingStdDev.map { $0 / 1000 },
                lossRate: details.pingLossRate ?? 0,
                results: results,
                resolvedIP: details.pingResolvedIP,
                source: source,
                timestamp: record.timestamp,
                duration: details.duration,
                errorMessage: errorMsg,
                ipInfo: nil,
                useIPv6: useIPv6
            )
            return ["MsmType": "ping", "MsmDatas": data]
            
        case .tcp:
            guard let details = record.details else { return nil }
            
            // 批量扫描模式
            if let portResults = details.tcpPortResults, portResults.count > 1 {
                let data = ReportDataBuilder.buildTCPBatchData(
                    target: record.target,
                    portResults: portResults.map { ($0.port, $0.serviceName, $0.isOpen, $0.latency) },
                    source: source,
                    timestamp: record.timestamp,
                    duration: details.duration,
                    errorMessage: errorMsg,
                    ipInfo: nil,
                    useIPv6: useIPv6
                )
                return ["MsmType": "tcp_port", "MsmDatas": data]
            } else {
                // 单端口模式
                let data = ReportDataBuilder.buildTCPData(
                    target: record.target,
                    port: UInt16(record.port ?? 0),
                    isOpen: details.tcpIsOpen ?? false,
                    latency: details.tcpLatency.map { $0 / 1000 },  // ms -> 秒
                    source: source,
                    timestamp: record.timestamp,
                    duration: details.duration,
                    errorMessage: errorMsg,
                    ipInfo: nil,
                    useIPv6: useIPv6
                )
                return ["MsmType": "tcp_port", "MsmDatas": data]
            }
            
        case .udp:
            guard let details = record.details else { return nil }
            
            let data = ReportDataBuilder.buildUDPData(
                target: record.target,
                port: UInt16(record.port ?? 0),
                sent: details.udpSent ?? false,
                received: details.udpReceived ?? false,
                latency: details.udpLatency.map { $0 / 1000 },  // ms -> 秒
                source: source,
                timestamp: record.timestamp,
                duration: details.duration,
                errorMessage: errorMsg,
                ipInfo: nil,
                useIPv6: useIPv6
            )
            return ["MsmType": "udp_port", "MsmDatas": data]
            
        case .dns:
            guard let details = record.details else { return nil }
            
            // 构建 recordDetails
            let recordDetails: [(name: String?, type: String, ttl: UInt32?, value: String)]?
            if let dnsDetails = details.dnsRecordDetails {
                recordDetails = dnsDetails.map { ($0.name, $0.type, $0.ttl, $0.value) }
            } else {
                recordDetails = nil
            }
            
            let data = ReportDataBuilder.buildDNSData(
                domain: record.target,
                recordType: details.dnsRecordType ?? "A",
                records: details.dnsRecords ?? [],
                recordDetails: recordDetails,
                latency: (details.dnsQueryTime ?? 0) / 1000,  // ms -> 秒
                server: details.dnsServer,
                digOutput: nil,
                source: source,
                timestamp: record.timestamp,
                duration: details.duration,
                errorMessage: errorMsg,
                ipInfo: nil
            )
            return ["MsmType": "dns", "MsmDatas": data]
            
        case .traceroute:
            guard let details = record.details else { return nil }
            
            // 构建 hops 数组（包含 hostname）
            let hops: [(hop: Int, ip: String, hostname: String?, avgLatency: TimeInterval?, lossRate: Double, sentCount: Int, receivedCount: Int, location: String?)]
            if let hopDetails = details.traceHopDetails {
                hops = hopDetails.map { ($0.hop, $0.ip, $0.hostname, $0.avgLatency.map { $0 / 1000 }, $0.lossRate, $0.sentCount, $0.receivedCount, $0.location) }  // ms -> 秒
            } else {
                hops = []
            }
            
            let data = ReportDataBuilder.buildTraceData(
                target: record.target,
                hops: hops,
                reachedTarget: details.traceReachedTarget ?? false,
                source: source,
                timestamp: record.timestamp,
                duration: details.duration,
                errorMessage: errorMsg,
                ipInfo: nil,
                useIPv6: useIPv6
            )
            return ["MsmType": "mtr", "MsmDatas": data]
            
        case .speedTest, .http:
            // 测速和 HTTP 暂不支持上传
            return nil
        }
    }
}
