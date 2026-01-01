//
//  QuickDiagnosisManager.swift
//  Pong
//
//  Created by 张金琛 on 2025/12/15.
//

import Foundation
import UIKit
internal import Combine

// MARK: - 诊断任务类型
enum DiagnosisTaskType: String, Codable {
    case ping = "ping"
    case tcp = "tcp_port"
    case udp = "udp_port"
    case dns = "dns"
    case trace = "mtr"
    
    var displayName: String {
        let l10n = L10n.shared
        switch self {
        case .ping: return l10n.diagnosisPingTest
        case .tcp: return l10n.diagnosisTCPConnect
        case .udp: return l10n.diagnosisUDPTest
        case .dns: return l10n.diagnosisDNSQuery
        case .trace: return l10n.diagnosisTraceroute
        }
    }
    
    var icon: String {
        switch self {
        case .ping: return "network"
        case .tcp: return "arrow.left.arrow.right"
        case .udp: return "paperplane"
        case .dns: return "globe"
        case .trace: return "point.topleft.down.curvedto.point.bottomright.up"
        }
    }
}

// MARK: - 诊断任务选项
struct DiagnosisTaskOptions: Codable {
    var count: Int?
    var size: Int?
    var timeout: Int?
    var rtype: String?  // DNS 记录类型
    var ns: String?     // DNS 服务器
    
    enum CodingKeys: String, CodingKey {
        case count
        case size
        case timeout
        case rtype
        case ns
    }
}

// MARK: - 诊断任务详情
struct DiagnosisTaskDetail: Identifiable, Codable {
    let id: Int
    let msmType: String
    let target: String
    let port: String?  // 改为 String 类型
    let options: DiagnosisTaskOptions?
    let af: Int?  // 地址族: 4=IPv4, 6=IPv6，默认 IPv4
    
    enum CodingKeys: String, CodingKey {
        case id
        case msmType
        case target
        case port
        case options
        case af
    }
    
    var taskType: DiagnosisTaskType? {
        DiagnosisTaskType(rawValue: msmType.lowercased())
    }
    
    var portInt: Int? {
        guard let port = port else { return nil }
        return Int(port)
    }
    
    /// 是否使用 IPv6，默认为 false (IPv4)
    var useIPv6: Bool {
        return af == 6
    }
    
    var displayDescription: String {
        let l10n = L10n.shared
        var desc = target
        if let port = port {
            desc += ":\(port)"
        }
        if let options = options {
            var optParts: [String] = []
            if let count = options.count {
                optParts.append("\(l10n.diagnosisCount): \(count)")
            }
            if let size = options.size {
                optParts.append("\(l10n.diagnosisSize): \(size)B")
            }
            if !optParts.isEmpty {
                desc += " (\(optParts.joined(separator: ", ")))"
            }
        }
        return desc
    }
}

// MARK: - 单个任务执行结果
struct DiagnosisTaskResult: Identifiable {
    let id = UUID()
    let taskDetail: DiagnosisTaskDetail
    let status: TaskResultStatus
    let resultData: Any?
    let error: String?
    let startTime: Date
    let endTime: Date?
    
    var duration: TimeInterval? {
        guard let endTime = endTime else { return nil }
        return endTime.timeIntervalSince(startTime)
    }
    
    enum TaskResultStatus {
        case pending
        case running
        case success
        case failed
    }
}

// MARK: - 诊断状态
enum DiagnosisState: Equatable {
    case idle
    case running           // 正在执行探测
    case completed         // 所有探测完成
    case error(String)     // 出错
}

// MARK: - 诊断管理器
@MainActor
class QuickDiagnosisManager: ObservableObject {
    static let shared = QuickDiagnosisManager()
    
    // MARK: - Published 属性
    @Published var state: DiagnosisState = .idle
    @Published var targetAddress: String = ""
    @Published var taskResults: [UUID: DiagnosisTaskResult] = [:]
    @Published var currentTaskIndex: Int = 0
    @Published var progress: Double = 0
    @Published var totalTasks: Int = 0
    
    // 各类型探测的 Manager
    private let pingManager = PingManager.shared
    private let tcpManager = TCPManager.shared
    private let udpManager = UDPManager.shared
    private let dnsManager = DNSManager.shared
    private let traceManager = TraceManager.shared
    
    private init() {}
    
    // MARK: - 重置状态
    func reset() {
        state = .idle
        targetAddress = ""
        taskResults = [:]
        currentTaskIndex = 0
        progress = 0
        totalTasks = 0
    }
    
    // MARK: - 检查网络可达性
    private func checkNetworkReachability() async -> Bool {
        // 尝试连接一个可靠的服务器来验证网络
        guard let url = URL(string: "https://www.qq.com") else {
            return false
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 3
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode >= 200 && httpResponse.statusCode < 400
            }
            return false
        } catch {
            return false
        }
    }
    
    // MARK: - 生成诊断任务列表
    private func generateTasks(for target: String) -> [DiagnosisTaskDetail] {
        var tasks: [DiagnosisTaskDetail] = []
        var taskId = 1
        
        // 判断目标是否为 IP 地址
        let isIPAddress = isValidIPAddress(target)
        
        // 1. DNS 查询（仅当目标是域名时）
        if !isIPAddress {
            tasks.append(DiagnosisTaskDetail(
                id: taskId,
                msmType: "dns",
                target: target,
                port: nil,
                options: DiagnosisTaskOptions(count: nil, size: nil, timeout: nil, rtype: "A", ns: nil),
                af: 4
            ))
            taskId += 1
        }
        
        // 2. Ping 测试
        tasks.append(DiagnosisTaskDetail(
            id: taskId,
            msmType: "ping",
            target: target,
            port: nil,
            options: DiagnosisTaskOptions(count: 5, size: 56, timeout: nil, rtype: nil, ns: nil),
            af: 4
        ))
        taskId += 1
        
        // 3. TCP 端口测试 (80)
        tasks.append(DiagnosisTaskDetail(
            id: taskId,
            msmType: "tcp_port",
            target: target,
            port: "80",
            options: DiagnosisTaskOptions(count: 1, size: nil, timeout: nil, rtype: nil, ns: nil),
            af: 4
        ))
        taskId += 1
        
        // 4. TCP 端口测试 (443)
        tasks.append(DiagnosisTaskDetail(
            id: taskId,
            msmType: "tcp_port",
            target: target,
            port: "443",
            options: DiagnosisTaskOptions(count: 1, size: nil, timeout: nil, rtype: nil, ns: nil),
            af: 4
        ))
        taskId += 1
        
        // 5. Traceroute
        tasks.append(DiagnosisTaskDetail(
            id: taskId,
            msmType: "mtr",
            target: target,
            port: nil,
            options: DiagnosisTaskOptions(count: 3, size: nil, timeout: nil, rtype: nil, ns: nil),
            af: 4
        ))
        
        return tasks
    }
    
    // MARK: - 判断是否为有效 IP 地址
    private func isValidIPAddress(_ string: String) -> Bool {
        var sin = sockaddr_in()
        var sin6 = sockaddr_in6()
        
        if string.withCString({ inet_pton(AF_INET, $0, &sin.sin_addr) }) == 1 {
            return true
        }
        if string.withCString({ inet_pton(AF_INET6, $0, &sin6.sin6_addr) }) == 1 {
            return true
        }
        return false
    }
    
    // MARK: - 开始执行诊断
    func startDiagnosis(target: String) async {
        guard !target.isEmpty else {
            state = .error("请输入目标地址")
            return
        }
        
        // 检查网络连接，如果状态为 unknown，等待一小段时间让网络监控器初始化
        var networkStatus = DeviceInfoManager.shared.networkStatus
        if networkStatus == .unknown {
            // 等待最多 1 秒让网络状态更新
            for _ in 0..<10 {
                try? await Task.sleep(nanoseconds: 100_000_000)
                networkStatus = DeviceInfoManager.shared.networkStatus
                if networkStatus != .unknown {
                    break
                }
            }
        }
        
        // 如果等待后仍然是 unknown，尝试直接进行网络请求来验证
        if networkStatus == .unknown || networkStatus == .disconnected {
            // 尝试一个简单的网络请求来验证网络是否可用
            let isReachable = await checkNetworkReachability()
            if !isReachable {
                state = .error("无网络连接，请检查网络设置后重试")
                return
            }
        }
        
        // 保存目标地址
        targetAddress = target
        
        // 生成诊断任务
        let tasks = generateTasks(for: target)
        totalTasks = tasks.count
        
        // 清空之前的状态
        taskResults = [:]
        currentTaskIndex = 0
        progress = 0
        
        // 初始化任务结果
        for task in tasks {
            let result = DiagnosisTaskResult(
                taskDetail: task,
                status: .pending,
                resultData: nil,
                error: nil,
                startTime: Date(),
                endTime: nil
            )
            taskResults[result.id] = result
        }
        
        state = .running
        
        for (index, task) in tasks.enumerated() {
            currentTaskIndex = index
            progress = Double(index) / Double(totalTasks)
            
            await executeTask(task)
            
            progress = Double(index + 1) / Double(totalTasks)
        }
        
        state = .completed
    }
    
    // MARK: - 执行单个任务
    private func executeTask(_ task: DiagnosisTaskDetail) async {
        // 找到对应的结果记录
        guard let resultId = taskResults.first(where: { $0.value.taskDetail.id == task.id })?.key else {
            return
        }
        
        // 更新状态为运行中
        let startTime = Date()
        taskResults[resultId] = DiagnosisTaskResult(
            taskDetail: task,
            status: .running,
            resultData: nil,
            error: nil,
            startTime: startTime,
            endTime: nil
        )
        
        do {
            let resultData = try await performProbe(task)
            
            taskResults[resultId] = DiagnosisTaskResult(
                taskDetail: task,
                status: .success,
                resultData: resultData,
                error: nil,
                startTime: startTime,
                endTime: Date()
            )
        } catch {
            taskResults[resultId] = DiagnosisTaskResult(
                taskDetail: task,
                status: .failed,
                resultData: nil,
                error: error.localizedDescription,
                startTime: startTime,
                endTime: Date()
            )
        }
    }
    
    // MARK: - 执行探测
    private func performProbe(_ task: DiagnosisTaskDetail) async throws -> Any {
        guard let taskType = task.taskType else {
            throw DiagnosisError.unsupportedTaskType(task.msmType)
        }
        
        switch taskType {
        case .ping:
            return try await performPing(task)
        case .tcp:
            return try await performTCP(task)
        case .udp:
            return try await performUDP(task)
        case .dns:
            return try await performDNS(task)
        case .trace:
            return try await performTrace(task)
        }
    }
    
    // MARK: - Ping 探测
    private func performPing(_ task: DiagnosisTaskDetail) async throws -> PingProbeResult {
        let count = task.options?.count ?? 3
        let size = task.options?.size ?? 56
        
        // 使用 PingManager 执行 ping
        pingManager.packetSize = size
        pingManager.interval = 0.2  // 快速诊断使用 0.2s 间隔
        pingManager.preferIPv6 = task.useIPv6  // 设置 IPv6 偏好
        pingManager.startPing(host: task.target, count: count)
        
        // 等待 ping 完成
        while pingManager.isPinging {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        
        // 从 PingManager 获取结果
        let stats = pingManager.statistics
        let results = pingManager.results.map { result in
            var success = false
            var errorMsg: String? = nil
            switch result.status {
            case .success:
                success = true
            case .timeout:
                errorMsg = "超时"
            case .error(let msg):
                errorMsg = msg
            }
            return SinglePingResult(
                sequence: result.sequence,
                success: success,
                latency: result.latency,
                error: errorMsg
            )
        }
        
        return PingProbeResult(
            target: task.target,
            packetSize: size,
            count: count,
            successCount: stats.received,
            avgLatency: stats.avgLatency,
            minLatency: stats.minLatency == .infinity ? nil : stats.minLatency,
            maxLatency: stats.maxLatency == 0 ? nil : stats.maxLatency,
            lossRate: stats.lossRate,
            results: results,
            resolvedIP: pingManager.resolvedIP.isEmpty ? nil : pingManager.resolvedIP
        )
    }
    
    // MARK: - TCP 探测
    private func performTCP(_ task: DiagnosisTaskDetail) async throws -> TCPProbeResult {
        let port = UInt16(task.portInt ?? 80)
        let count = task.options?.count ?? 1
        
        // 设置 IPv6 偏好
        tcpManager.preferIPv6 = task.useIPv6
        
        var allResults: [TCPResult] = []
        
        // 执行多次 TCP 连接测试
        for _ in 0..<count {
            // 清空之前的结果
            tcpManager.results.removeAll()
            
            // 使用 TCPManager 执行测试
            tcpManager.testConnection(host: task.target, port: port)
            
            // 等待测试开始
            try? await Task.sleep(nanoseconds: 100_000_000)
            
            // 等待测试完成（最多等待 10 秒）
            var waitCount = 0
            while tcpManager.isScanning && waitCount < 100 {
                try? await Task.sleep(nanoseconds: 100_000_000)
                waitCount += 1
            }
            
            // 额外等待确保结果写入
            try? await Task.sleep(nanoseconds: 100_000_000)
            
            // 收集结果
            if let result = tcpManager.results.first {
                allResults.append(result)
            }
            
            // 如果不是最后一次，等待一小段时间再发下一个包
            if allResults.count < count {
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
        }
        
        // 汇总结果
        guard !allResults.isEmpty else {
            return TCPProbeResult(
                target: task.target,
                port: port,
                isOpen: false,
                latency: nil,
                error: "TCP 测试未返回结果",
                count: count,
                successCount: 0,
                failedCount: count
            )
        }
        
        // 统计：只要有一次成功就算端口开放
        let successResults = allResults.filter { $0.isOpen }
        let isOpen = !successResults.isEmpty
        let successCount = successResults.count
        let failedCount = allResults.count - successCount
        
        // 计算平均延迟（只统计成功的）
        let latencies = successResults.compactMap { $0.latency }
        let avgLatency: TimeInterval? = latencies.isEmpty ? nil : latencies.reduce(0, +) / Double(latencies.count)
        
        // 错误信息取第一个失败的
        let errorMsg = allResults.first(where: { !$0.isOpen })?.error
        
        return TCPProbeResult(
            target: task.target,
            port: port,
            isOpen: isOpen,
            latency: avgLatency,
            error: isOpen ? nil : errorMsg,
            count: allResults.count,
            successCount: successCount,
            failedCount: failedCount
        )
    }
    
    // MARK: - UDP 探测
    private func performUDP(_ task: DiagnosisTaskDetail) async throws -> UDPProbeResult {
        let port = UInt16(task.portInt ?? 53)
        let count = task.options?.count ?? 1
        
        // 设置 IPv6 偏好
        udpManager.preferIPv6 = task.useIPv6
        
        var allResults: [UDPResult] = []
        
        // 执行多次 UDP 测试
        for _ in 0..<count {
            // 清空之前的结果
            udpManager.results.removeAll()
            
            // 使用 UDPManager 执行测试
            udpManager.testUDP(host: task.target, port: port)
            
            // 等待测试开始
            try? await Task.sleep(nanoseconds: 100_000_000)
            
            // 等待测试完成（最多等待 5 秒）
            var waitCount = 0
            while udpManager.isTesting && waitCount < 50 {
                try? await Task.sleep(nanoseconds: 100_000_000)
                waitCount += 1
            }
            
            // 额外等待确保结果写入
            try? await Task.sleep(nanoseconds: 100_000_000)
            
            // 收集结果
            if let result = udpManager.results.first {
                allResults.append(result)
            }
            
            // 如果不是最后一次，等待一小段时间再发下一个包
            if allResults.count < count {
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
        }
        
        // 汇总结果
        guard !allResults.isEmpty else {
            return UDPProbeResult(
                target: task.target,
                port: port,
                sent: false,
                received: false,
                latency: nil,
                error: "UDP 测试未返回结果",
                count: count,
                successCount: 0,
                failedCount: count
            )
        }
        
        // 统计
        let sentCount = allResults.filter { $0.sent }.count
        let receivedCount = allResults.filter { $0.received }.count
        let sent = sentCount > 0
        let received = receivedCount > 0
        
        // 计算平均延迟（只统计收到响应的）
        let latencies = allResults.filter { $0.received }.compactMap { $0.latency }
        let avgLatency: TimeInterval? = latencies.isEmpty ? nil : latencies.reduce(0, +) / Double(latencies.count)
        
        // 错误信息取第一个失败的
        let errorMsg = allResults.first(where: { !$0.received })?.error
        
        return UDPProbeResult(
            target: task.target,
            port: port,
            sent: sent,
            received: received,
            latency: avgLatency,
            error: received ? nil : errorMsg,
            count: allResults.count,
            successCount: receivedCount,
            failedCount: allResults.count - receivedCount
        )
    }
    
    // MARK: - DNS 探测
    private func performDNS(_ task: DiagnosisTaskDetail) async throws -> DNSProbeResult {
        let recordTypeStr = task.options?.rtype?.uppercased() ?? "A"
        let recordType = DNSRecordType(rawValue: recordTypeStr) ?? .A
        let dnsServer = task.options?.ns  // 指定的 DNS 服务器
        
        let startTime = Date()
        
        // 清空之前的结果
        dnsManager.results.removeAll()
        
        // 根据是否指定 DNS 服务器选择查询方式
        if let server = dnsServer, !server.isEmpty {
            // 使用指定的 DNS 服务器查询
            dnsManager.queryWithServer(domain: task.target, recordType: recordType, server: server)
        } else {
            // 使用系统默认 DNS
            dnsManager.query(domain: task.target, recordType: recordType)
        }
        
        // 等待查询完成
        var waitCount = 0
        while dnsManager.isQuerying && waitCount < 20 {
            try? await Task.sleep(nanoseconds: 500_000_000)
            waitCount += 1
        }
        
        let latency = Date().timeIntervalSince(startTime)
        
        if let result = dnsManager.results.first {
            return DNSProbeResult(
                domain: task.target,
                recordType: recordTypeStr,
                records: result.records.map { $0.value },
                latency: latency,
                server: result.server,
                error: result.error,
                digOutput: result.digStyleOutput()
            )
        } else {
            return DNSProbeResult(
                domain: task.target,
                recordType: recordTypeStr,
                records: [],
                latency: latency,
                server: dnsServer,
                error: "查询失败",
                digOutput: ""
            )
        }
    }
    
    // MARK: - Traceroute 探测
    private func performTrace(_ task: DiagnosisTaskDetail) async throws -> TraceProbeResult {
        // 停止之前的追踪
        traceManager.stopTrace()
        
        // 设置每跳发包数量（从任务选项中读取，默认为 3）
        let probeCount = task.options?.count ?? 3
        traceManager.probesPerHop = probeCount
        
        // 设置 IPv6 偏好
        traceManager.protocolPreference = task.useIPv6 ? .ipv6Only : .ipv4Only
        
        // 开始新的追踪
        await traceManager.startTrace(host: task.target)
        
        // 等待追踪完成（最多 60 秒）
        var waitTime = 0
        while traceManager.isTracing && waitTime < 60 {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            waitTime += 1
        }
        
        // 检查是否有错误（如无 IPv6）
        if let errorMessage = traceManager.errorMessage {
            return TraceProbeResult(
                target: task.target,
                hops: [],
                reachedTarget: false,
                error: errorMessage
            )
        }
        
        // 等待归属地信息获取完成（最多 10 秒）
        var locationWaitTime = 0
        while traceManager.isFetchingLocation && locationWaitTime < 10 {
            try? await Task.sleep(nanoseconds: 500_000_000)
            locationWaitTime += 1
        }
        
        return TraceProbeResult(
            target: task.target,
            hops: traceManager.hops.map { hop in
                TraceHopResult(
                    hop: hop.hop,
                    ip: hop.ip,
                    hostname: hop.hostname,
                    avgLatency: hop.avgLatency,
                    lossRate: hop.lossRate,
                    sentCount: hop.sentCount,
                    receivedCount: hop.receivedCount,
                    location: hop.location
                )
            },
            reachedTarget: traceManager.isComplete,
            error: nil
        )
    }
}

// MARK: - 诊断错误
enum DiagnosisError: Error, LocalizedError {
    case unsupportedTaskType(String)
    case networkError(String)
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .unsupportedTaskType(let type):
            return "不支持的任务类型: \(type)"
        case .networkError(let msg):
            return "网络错误: \(msg)"
        case .timeout:
            return "操作超时"
        }
    }
}

// MARK: - 探测结果模型
struct SinglePingResult {
    let sequence: Int
    let success: Bool
    let latency: TimeInterval?
    let error: String?
}

struct PingProbeResult {
    let target: String
    let packetSize: Int
    let count: Int
    let successCount: Int
    let avgLatency: TimeInterval?
    let minLatency: TimeInterval?
    let maxLatency: TimeInterval?
    let lossRate: Double
    let results: [SinglePingResult]
    let resolvedIP: String?  // 解析后的 IP 地址
}

struct TCPProbeResult {
    let target: String
    let port: UInt16
    let isOpen: Bool
    let latency: TimeInterval?
    let error: String?
    let count: Int           // 测试次数
    let successCount: Int    // 成功次数
    let failedCount: Int     // 失败次数
}

struct UDPProbeResult {
    let target: String
    let port: UInt16
    let sent: Bool
    let received: Bool
    let latency: TimeInterval?
    let error: String?
    let count: Int           // 测试次数
    let successCount: Int    // 成功次数（收到响应）
    let failedCount: Int     // 失败次数
}

struct DNSProbeResult {
    let domain: String
    let recordType: String
    let records: [String]
    let latency: TimeInterval
    let server: String?
    let error: String?
    let digOutput: String  // dig 风格的完整输出
}

struct TraceHopResult {
    let hop: Int
    let ip: String
    let hostname: String?  // PTR 主机名
    let avgLatency: TimeInterval?
    let lossRate: Double
    let sentCount: Int
    let receivedCount: Int
    let location: String?  // IP 归属地
}

struct TraceProbeResult {
    let target: String
    let hops: [TraceHopResult]
    let reachedTarget: Bool
    let error: String?  // 错误信息（如无 IPv6）
}
