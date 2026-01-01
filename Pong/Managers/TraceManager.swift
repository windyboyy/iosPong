//
//  TraceManager.swift
//  Pong
//
//  Created by 张金琛 on 2025/12/12.
//

import Foundation
import Darwin
import UIKit
internal import Combine

// MARK: - ICMP 结构定义
struct ICMPHeader {
    var type: UInt8
    var code: UInt8
    var checksum: UInt16
    var identifier: UInt16
    var sequenceNumber: UInt16
}

// MARK: - IP 版本
enum IPVersion {
    case ipv4
    case ipv6
}

// MARK: - IP 协议偏好
enum IPProtocolPreference: String, CaseIterable {
    case auto = "auto"      // 系统默认（优先 IPv4）
    case ipv4Only = "ipv4"  // 仅 IPv4
    case ipv6Only = "ipv6"  // 仅 IPv6
    
    var displayName: String {
        switch self {
        case .auto: return L10n.shared.systemDefault
        case .ipv4Only: return "IPv4"
        case .ipv6Only: return "IPv6"
        }
    }
}

// MARK: - Traceroute 管理器
@MainActor
class TraceManager: ObservableObject {
    static let shared = TraceManager()
    
    @Published var isTracing = false
    @Published var hops: [TraceHop] = []
    @Published var currentHost = ""
    @Published var targetIP = ""  // 添加：显示解析后的目标 IP
    @Published var isComplete = false
    @Published var errorMessage: String?
    @Published var probesPerHop: Int = 3  // 可配置的每跳发包数
    @Published var isFetchingLocation = false  // 是否正在获取归属地
    @Published var ipVersion: IPVersion = .ipv4  // 当前使用的 IP 版本
    @Published var protocolPreference: IPProtocolPreference = .auto  // 用户选择的协议偏好
    
    private var traceTask: Task<Void, Never>?
    private let maxHops = 30
    private var startTime: Date?  // 记录开始时间
    
    // 后台任务标识符
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    
    private init() {}
    
    // MARK: - 网络状态检查
    
    /// 检查当前是否有网络连接
    /// 注意：如果状态是 unknown，我们假设网络可用（让实际的网络操作来判断）
    var isNetworkAvailable: Bool {
        let status = DeviceInfoManager.shared.networkStatus
        // unknown 状态时不阻止，让实际网络操作来判断
        return status != .disconnected
    }
    
    func startTrace(host: String) {
        stopTrace()
        
        // 检查网络连接
        guard isNetworkAvailable else {
            hops.removeAll()
            currentHost = host
            targetIP = ""
            isComplete = true
            errorMessage = L10n.shared.noNetworkConnection
            return
        }
        
        // 申请后台执行时间
        beginBackgroundTask()
        
        hops.removeAll()
        currentHost = host
        targetIP = ""
        isTracing = true
        isComplete = false
        errorMessage = nil
        isFetchingLocation = false
        startTime = Date()  // 记录开始时间
        
        traceTask = Task {
            await performTrace(host: host)
            
            // 如果有错误消息（如无 IPv6），保存失败记录后返回
            let hasError = await MainActor.run { self.errorMessage != nil }
            if hasError {
                await MainActor.run {
                    // 保存失败的历史记录
                    self.saveToHistory()
                    // 结束后台任务
                    self.endBackgroundTask()
                }
                return
            }
            
            await MainActor.run {
                self.isTracing = false
                self.isComplete = true
            }
            
            // trace 完成后获取 IP 归属地
            await fetchIPLocations()
            
            await MainActor.run {
                // 保存历史记录
                self.saveToHistory()
                // 结束后台任务
                self.endBackgroundTask()
            }
        }
    }
    
    private func saveToHistory() {
        // 根据实际解析结果判断是否为 IPv6
        let useIPv6 = ipVersion == .ipv6
        
        // 如果有错误消息，保存失败记录
        if let error = errorMessage {
            let duration = startTime.map { Date().timeIntervalSince($0) }
            TaskHistoryManager.shared.addTracerouteRecord(
                target: currentHost,
                status: .failure,
                hops: 0,
                reachedTarget: false,
                hopDetails: [],
                duration: duration,
                errorMessage: error,
                useIPv6: useIPv6
            )
            return
        }
        
        guard !hops.isEmpty else { return }
        
        let reachedTarget = hops.last?.ip == targetIP
        let status: TaskStatus = reachedTarget ? .success : .partial
        
        // 计算执行时长
        let duration = startTime.map { Date().timeIntervalSince($0) }
        
        // 转换跳数据为可存储的格式
        let hopDetails = hops.map { hop in
            TraceHopDetail(
                hop: hop.hop,
                ip: hop.ip,
                hostname: hop.hostname,
                avgLatency: hop.avgLatency.map { $0 * 1000 },  // 转换为毫秒
                lossRate: hop.lossRate,
                sentCount: hop.sentCount,
                receivedCount: hop.receivedCount,
                location: hop.location
            )
        }
        
        TaskHistoryManager.shared.addTracerouteRecord(
            target: currentHost,
            status: status,
            hops: hops.count,
            reachedTarget: reachedTarget,
            hopDetails: hopDetails,
            duration: duration,
            useIPv6: useIPv6
        )
    }
    
    func stopTrace() {
        traceTask?.cancel()
        traceTask = nil
        isTracing = false
        endBackgroundTask()
    }
    
    // MARK: - 后台任务管理
    private func beginBackgroundTask() {
        // 先结束之前的后台任务（如果有）
        endBackgroundTask()
        
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "Traceroute") { [weak self] in
            // 后台时间即将用尽
            Task { @MainActor in
                self?.handleBackgroundTaskExpiration()
            }
        }
        
        print("Traceroute 开始后台任务，ID: \(backgroundTaskID.rawValue)")
    }
    
    private func endBackgroundTask() {
        guard backgroundTaskID != .invalid else { return }
        
        print("Traceroute 结束后台任务，ID: \(backgroundTaskID.rawValue)")
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
    }
    
    private func handleBackgroundTaskExpiration() {
        print("Traceroute 后台任务时间即将用尽")
        
        // 停止追踪但保留已有结果
        traceTask?.cancel()
        traceTask = nil
        
        if isTracing {
            isTracing = false
            // 保存当前进度到历史记录
            saveToHistory()
        }
        
        endBackgroundTask()
    }
    
    // MARK: - 执行 Traceroute
    private func performTrace(host: String) async {
        // 解析目标 IP（根据用户选择的协议偏好）
        let resolved = resolveHost(host, preference: protocolPreference)
        guard let resolvedIP = resolved.ip else {
            await MainActor.run {
                switch self.protocolPreference {
                case .ipv4Only:
                    self.errorMessage = "无法解析 IPv4 地址: \(host)"
                case .ipv6Only:
                    self.errorMessage = "无法解析 IPv6 地址: \(host)"
                case .auto:
                    self.errorMessage = "无法解析主机名: \(host)"
                }
            }
            return
        }
        
        let version = resolved.version
        
        await MainActor.run {
            self.targetIP = resolvedIP
            self.ipVersion = version
        }
        
        // 如果是 IPv6 traceroute，检查本机是否有 IPv6 地址
        if version == .ipv6 {
            // 确保设备信息是最新的（网络状态变化时会自动刷新）
            let hasIPv6 = await MainActor.run {
                DeviceInfoManager.shared.deviceInfo?.localIPv6Address != nil
            }
            if !hasIPv6 {
                await MainActor.run {
                    self.errorMessage = L10n.shared.noLocalIPv6ForTrace
                    self.isTracing = false
                }
                return
            }
        }
        
        let probeCount = self.probesPerHop
        
        for ttl in 1...maxHops {
            guard !Task.isCancelled else { break }
            
            // 并发发送所有探测包
            let results = await sendProbesConcurrently(to: resolvedIP, ttl: ttl, count: probeCount, version: version)
            
            var latencies: [TimeInterval?] = []
            var hopIP: String? = nil
            var reachedTarget = false
            
            for result in results {
                latencies.append(result.latency)
                
                if let ip = result.ip {
                    hopIP = ip
                    if ip == resolvedIP {
                        reachedTarget = true
                    }
                }
                
                if result.reachedTarget {
                    reachedTarget = true
                }
            }
            
            // 先不解析 PTR，后面批量异步解析
            let hop = TraceHop(
                hop: ttl,
                ip: hopIP ?? "*",
                hostname: nil,
                latencies: latencies,
                status: hopIP != nil ? .success : .timeout
            )
            
            await MainActor.run {
                self.hops.append(hop)
            }
            
            // 到达目标，停止
            if reachedTarget {
                break
            }
            
            // 短暂延迟
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        
        // 探测完成后，批量异步解析 PTR
        await fetchHostnames(version: version)
    }
    
    // MARK: - 批量获取 PTR 主机名
    private func fetchHostnames(version: IPVersion) async {
        guard !Task.isCancelled else { return }
        
        // 收集所有有效的 IP 地址（排除 "*"）
        let validIPs = hops.enumerated().compactMap { (index, hop) -> (Int, String)? in
            hop.ip != "*" ? (index, hop.ip) : nil
        }
        
        guard !validIPs.isEmpty else { return }
        
        // 并发解析所有 PTR
        await withTaskGroup(of: (Int, String?).self) { group in
            for (index, ip) in validIPs {
                group.addTask {
                    let hostname = await self.resolveReverseAsync(ip, version: version)
                    return (index, hostname)
                }
            }
            
            // 收集结果并更新
            for await (index, hostname) in group {
                guard !Task.isCancelled else { break }
                if let hostname = hostname {
                    await MainActor.run {
                        if index < self.hops.count {
                            self.hops[index].hostname = hostname
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 并发发送探测包（发包和收包分离）
    private func sendProbesConcurrently(to targetIP: String, ttl: Int, count: Int, version: IPVersion) async -> [(ip: String?, latency: TimeInterval?, reachedTarget: Bool)] {
        
        return await withTaskGroup(of: (Int, String?, TimeInterval?, Bool).self) { group in
            for i in 0..<count {
                group.addTask {
                    let result = await self.sendICMPWithTTL(to: targetIP, ttl: ttl, probeIndex: i, version: version)
                    return (i, result.ip, result.latency, result.reachedTarget)
                }
            }
            
            var results = [(Int, String?, TimeInterval?, Bool)]()
            for await result in group {
                results.append(result)
            }
            
            // 按顺序排列结果
            results.sort { $0.0 < $1.0 }
            return results.map { ($0.1, $0.2, $0.3) }
        }
    }
    
    // MARK: - 发送带 TTL 的 ICMP 包
    private func sendICMPWithTTL(to targetIP: String, ttl: Int, probeIndex: Int = 0, version: IPVersion) async -> (ip: String?, latency: TimeInterval?, reachedTarget: Bool) {
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let result: (ip: String?, latency: TimeInterval?, reachedTarget: Bool)
                switch version {
                case .ipv4:
                    result = self.syncSendICMPv4(to: targetIP, ttl: ttl, probeIndex: probeIndex)
                case .ipv6:
                    result = self.syncSendICMPv6(to: targetIP, ttl: ttl, probeIndex: probeIndex)
                }
                continuation.resume(returning: result)
            }
        }
    }
    
    // MARK: - IPv4 ICMP 发送
    private func syncSendICMPv4(to targetIP: String, ttl: Int, probeIndex: Int = 0) -> (ip: String?, latency: TimeInterval?, reachedTarget: Bool) {
        // 创建 ICMP socket
        let sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP)
        guard sock >= 0 else {
            return (nil, nil, false)
        }
        defer { close(sock) }
        
        // 设置 TTL
        var ttlValue = Int32(ttl)
        if setsockopt(sock, IPPROTO_IP, IP_TTL, &ttlValue, socklen_t(MemoryLayout<Int32>.size)) < 0 {
            return (nil, nil, false)
        }
        
        // 设置接收超时为 300ms
        let timeoutMs: Int32 = 300
        var tv = timeval(tv_sec: 0, tv_usec: __darwin_suseconds_t(timeoutMs * 1000))
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        
        // 目标地址
        var destAddr = sockaddr_in()
        destAddr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        destAddr.sin_family = sa_family_t(AF_INET)
        destAddr.sin_port = 0
        inet_pton(AF_INET, targetIP, &destAddr.sin_addr)
        
        // 构建 ICMP Echo Request - 使用更独特的 identifier（包含 probeIndex）
        let identifier = UInt16((ProcessInfo.processInfo.processIdentifier & 0x7FFF) ^ Int32(ttl << 8) ^ Int32(probeIndex << 4))
        let sequence = UInt16(ttl * 10 + probeIndex)
        var icmpPacket = createICMPv4Packet(identifier: identifier, sequence: sequence)
        
        let startTime = Date()
        
        // 发送
        let sendResult = withUnsafePointer(to: &destAddr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                sendto(sock, &icmpPacket, icmpPacket.count, 0, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        
        guard sendResult > 0 else {
            return (nil, nil, false)
        }
        
        // 循环接收，直到收到匹配的响应或超时
        let deadline = Date().addingTimeInterval(Double(timeoutMs) / 1000.0)
        
        while Date() < deadline {
            var recvBuffer = [UInt8](repeating: 0, count: 1024)
            var srcAddr = sockaddr_in()
            var srcAddrLen = socklen_t(MemoryLayout<sockaddr_in>.size)
            
            let recvResult = withUnsafeMutablePointer(to: &srcAddr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                    recvfrom(sock, &recvBuffer, recvBuffer.count, 0, sockaddrPtr, &srcAddrLen)
                }
            }
            
            guard recvResult > 0 else {
                // 超时，无响应
                return (nil, nil, false)
            }
            
            let latency = Date().timeIntervalSince(startTime)
            
            // 解析外层 IP 头部长度
            let outerIPHeaderLength = Int((recvBuffer[0] & 0x0F)) * 4
            guard recvResult > outerIPHeaderLength + 8 else {
                continue
            }
            
            let icmpType = recvBuffer[outerIPHeaderLength]
            let icmpCode = recvBuffer[outerIPHeaderLength + 1]
            
            // 获取响应 IP
            var ipBuffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            inet_ntop(AF_INET, &srcAddr.sin_addr, &ipBuffer, socklen_t(INET_ADDRSTRLEN))
            let responseIP = String(cString: ipBuffer)
            
            if icmpType == 0 {
                // Echo Reply - 需要验证 identifier 和 sequence
                let recvIdentifier = (UInt16(recvBuffer[outerIPHeaderLength + 4]) << 8) | UInt16(recvBuffer[outerIPHeaderLength + 5])
                let recvSequence = (UInt16(recvBuffer[outerIPHeaderLength + 6]) << 8) | UInt16(recvBuffer[outerIPHeaderLength + 7])
                
                if recvIdentifier == identifier && recvSequence == sequence {
                    return (responseIP, latency, true)
                } else {
                    continue
                }
                
            } else if icmpType == 11 {
                // Time Exceeded - 需要从内嵌的原始 ICMP 包中验证
                let innerOffset = outerIPHeaderLength + 8 + 20
                guard recvResult > innerOffset + 8 else {
                    return (responseIP, latency, false)
                }
                
                let innerIdentifier = (UInt16(recvBuffer[innerOffset + 4]) << 8) | UInt16(recvBuffer[innerOffset + 5])
                let innerSequence = (UInt16(recvBuffer[innerOffset + 6]) << 8) | UInt16(recvBuffer[innerOffset + 7])
                
                if innerIdentifier == identifier && innerSequence == sequence {
                    return (responseIP, latency, false)
                } else {
                    continue
                }
                
            } else {
                return (responseIP, latency, false)
            }
        }
        
        return (nil, nil, false)
    }
    
    // MARK: - IPv6 ICMPv6 发送
    private func syncSendICMPv6(to targetIP: String, ttl: Int, probeIndex: Int = 0) -> (ip: String?, latency: TimeInterval?, reachedTarget: Bool) {
        // ICMPv6 类型常量
        let ICMPV6_ECHO_REQUEST: UInt8 = 128
        let ICMPV6_ECHO_REPLY: UInt8 = 129
        let ICMPV6_DST_UNREACH: UInt8 = 1
        let ICMPV6_TIME_EXCEEDED: UInt8 = 3
        
        // 创建 ICMPv6 socket
        let sock = socket(AF_INET6, SOCK_DGRAM, IPPROTO_ICMPV6)
        guard sock >= 0 else {
            print("[ICMPv6] 创建 socket 失败: \(errno)")
            return (nil, nil, false)
        }
        defer { close(sock) }
        
        // 设置 Hop Limit (IPv6 的 TTL)
        var hopLimit = Int32(ttl)
        if setsockopt(sock, IPPROTO_IPV6, IPV6_UNICAST_HOPS, &hopLimit, socklen_t(MemoryLayout<Int32>.size)) < 0 {
            print("[ICMPv6] 设置 hop limit 失败: \(errno)")
            return (nil, nil, false)
        }
        
        // 设置接收超时为 500ms（IPv6 可能需要更长时间）
        let timeoutMs: Int32 = 500
        var tv = timeval(tv_sec: 0, tv_usec: __darwin_suseconds_t(timeoutMs * 1000))
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        
        // 目标地址
        var destAddr = sockaddr_in6()
        destAddr.sin6_len = UInt8(MemoryLayout<sockaddr_in6>.size)
        destAddr.sin6_family = sa_family_t(AF_INET6)
        destAddr.sin6_port = 0
        destAddr.sin6_flowinfo = 0
        destAddr.sin6_scope_id = 0
        
        // 解析 IPv6 地址
        if inet_pton(AF_INET6, targetIP, &destAddr.sin6_addr) != 1 {
            print("[ICMPv6] 解析 IPv6 地址失败: \(targetIP)")
            return (nil, nil, false)
        }
        
        // 构建 ICMPv6 Echo Request
        let identifier = UInt16((ProcessInfo.processInfo.processIdentifier & 0x7FFF) ^ Int32(ttl << 8) ^ Int32(probeIndex << 4))
        let sequence = UInt16(ttl * 10 + probeIndex)
        var icmpPacket = createICMPv6Packet(identifier: identifier, sequence: sequence)
        
        let startTime = Date()
        
        // 发送
        let sendResult = withUnsafePointer(to: &destAddr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                sendto(sock, &icmpPacket, icmpPacket.count, 0, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in6>.size))
            }
        }
        
        guard sendResult > 0 else {
            let err = errno
            var errMsg = "未知错误"
            switch err {
            case 51: errMsg = "ENETUNREACH - 网络不可达（无 IPv6 网络）"
            case 65: errMsg = "EHOSTUNREACH - 主机不可达"
            case 64: errMsg = "EHOSTDOWN - 主机已关闭"
            case 61: errMsg = "ECONNREFUSED - 连接被拒绝"
            case 50: errMsg = "ENETDOWN - 网络已关闭"
            case 1: errMsg = "EPERM - 权限不足"
            case 13: errMsg = "EACCES - 权限被拒绝"
            default: errMsg = "errno=\(err)"
            }
            print("[ICMPv6] 发送失败: \(errMsg), ttl=\(ttl), target=\(targetIP)")
            return (nil, nil, false)
        }
        
        // 循环接收，直到收到匹配的响应或超时
        let deadline = Date().addingTimeInterval(Double(timeoutMs) / 1000.0)
        
        while Date() < deadline {
            var recvBuffer = [UInt8](repeating: 0, count: 1024)
            var srcAddr = sockaddr_in6()
            var srcAddrLen = socklen_t(MemoryLayout<sockaddr_in6>.size)
            
            let recvResult = withUnsafeMutablePointer(to: &srcAddr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                    recvfrom(sock, &recvBuffer, recvBuffer.count, 0, sockaddrPtr, &srcAddrLen)
                }
            }
            
            guard recvResult > 0 else {
                // 超时，无响应
                return (nil, nil, false)
            }
            
            let latency = Date().timeIntervalSince(startTime)
            
            // ICMPv6 没有 IP 头部，直接是 ICMPv6 头
            let icmpType = recvBuffer[0]
            let icmpCode = recvBuffer[1]
            
            // 获取响应 IP
            var ipBuffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
            var addr = srcAddr.sin6_addr
            inet_ntop(AF_INET6, &addr, &ipBuffer, socklen_t(INET6_ADDRSTRLEN))
            let responseIP = String(cString: ipBuffer)
            
            print("[ICMPv6] 收到响应: type=\(icmpType), code=\(icmpCode), from=\(responseIP), ttl=\(ttl)")
            
            if icmpType == ICMPV6_ECHO_REPLY {
                // ICMPv6 Echo Reply (type 129)
                let recvIdentifier = (UInt16(recvBuffer[4]) << 8) | UInt16(recvBuffer[5])
                let recvSequence = (UInt16(recvBuffer[6]) << 8) | UInt16(recvBuffer[7])
                
                if recvIdentifier == identifier && recvSequence == sequence {
                    return (responseIP, latency, true)
                } else {
                    continue
                }
                
            } else if icmpType == ICMPV6_TIME_EXCEEDED {
                // ICMPv6 Time Exceeded (type 3)
                // 结构: [ICMPv6头8字节][原始IPv6头40字节][原始ICMPv6头8字节]
                let innerOffset = 8 + 40  // 跳过 ICMPv6 头和原始 IPv6 头
                guard recvResult > innerOffset + 8 else {
                    return (responseIP, latency, false)
                }
                
                let innerIdentifier = (UInt16(recvBuffer[innerOffset + 4]) << 8) | UInt16(recvBuffer[innerOffset + 5])
                let innerSequence = (UInt16(recvBuffer[innerOffset + 6]) << 8) | UInt16(recvBuffer[innerOffset + 7])
                
                if innerIdentifier == identifier && innerSequence == sequence {
                    return (responseIP, latency, false)
                } else {
                    continue
                }
                
            } else if icmpType == ICMPV6_DST_UNREACH {
                // Destination Unreachable - 也返回 IP
                return (responseIP, latency, false)
                
            } else {
                // 其他类型，继续等待
                continue
            }
        }
        
        return (nil, nil, false)
    }
    
    // MARK: - 创建 ICMPv4 包
    private func createICMPv4Packet(identifier: UInt16, sequence: UInt16) -> [UInt8] {
        var packet = [UInt8](repeating: 0, count: 64)
        
        // Type: 8 (Echo Request)
        packet[0] = 8
        // Code: 0
        packet[1] = 0
        // Checksum: 先填 0
        packet[2] = 0
        packet[3] = 0
        // Identifier
        packet[4] = UInt8(identifier >> 8)
        packet[5] = UInt8(identifier & 0xFF)
        // Sequence
        packet[6] = UInt8(sequence >> 8)
        packet[7] = UInt8(sequence & 0xFF)
        
        // 填充数据
        for i in 8..<64 {
            packet[i] = UInt8(i & 0xFF)
        }
        
        // 计算校验和
        let checksum = icmpChecksum(packet)
        packet[2] = UInt8(checksum & 0xFF)
        packet[3] = UInt8(checksum >> 8)
        
        return packet
    }
    
    // MARK: - 创建 ICMPv6 包
    private func createICMPv6Packet(identifier: UInt16, sequence: UInt16) -> [UInt8] {
        var packet = [UInt8](repeating: 0, count: 64)
        
        // Type: 128 (ICMPv6 Echo Request)
        packet[0] = 128
        // Code: 0
        packet[1] = 0
        // Checksum: 内核会自动计算 ICMPv6 校验和
        packet[2] = 0
        packet[3] = 0
        // Identifier
        packet[4] = UInt8(identifier >> 8)
        packet[5] = UInt8(identifier & 0xFF)
        // Sequence
        packet[6] = UInt8(sequence >> 8)
        packet[7] = UInt8(sequence & 0xFF)
        
        // 填充数据
        for i in 8..<64 {
            packet[i] = UInt8(i & 0xFF)
        }
        
        return packet
    }
    
    // MARK: - ICMP 校验和
    private func icmpChecksum(_ data: [UInt8]) -> UInt16 {
        var sum: UInt32 = 0
        var i = 0
        
        while i < data.count - 1 {
            sum += UInt32(data[i]) | (UInt32(data[i + 1]) << 8)
            i += 2
        }
        
        if i < data.count {
            sum += UInt32(data[i])
        }
        
        while sum >> 16 != 0 {
            sum = (sum & 0xFFFF) + (sum >> 16)
        }
        
        return ~UInt16(sum & 0xFFFF)
    }
    
    // MARK: - DNS 解析（支持 IPv4 和 IPv6）
    private func resolveHost(_ host: String, preference: IPProtocolPreference = .auto) -> (ip: String?, version: IPVersion) {
        // 检查是否已经是 IPv6 地址
        var addr6 = in6_addr()
        if inet_pton(AF_INET6, host, &addr6) == 1 {
            // 如果用户选择仅 IPv4，但输入的是 IPv6 地址，返回失败
            if preference == .ipv4Only {
                return (nil, .ipv4)
            }
            return (host, .ipv6)
        }
        
        // 检查是否已经是 IPv4 地址
        var addr4 = in_addr()
        if inet_pton(AF_INET, host, &addr4) == 1 {
            // 如果用户选择仅 IPv6，但输入的是 IPv4 地址，返回失败
            if preference == .ipv6Only {
                return (nil, .ipv6)
            }
            return (host, .ipv4)
        }
        
        // DNS 解析 - 根据用户偏好决定解析顺序
        var hints = addrinfo()
        hints.ai_socktype = SOCK_DGRAM
        var result: UnsafeMutablePointer<addrinfo>?
        
        switch preference {
        case .ipv4Only:
            // 仅解析 IPv4
            hints.ai_family = AF_INET
            if getaddrinfo(host, nil, &hints, &result) == 0, let info = result {
                defer { freeaddrinfo(result) }
                if let sockaddr = info.pointee.ai_addr {
                    let sockaddrIn = sockaddr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
                    var ipBuffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                    var addr = sockaddrIn.sin_addr
                    inet_ntop(AF_INET, &addr, &ipBuffer, socklen_t(INET_ADDRSTRLEN))
                    return (String(cString: ipBuffer), .ipv4)
                }
            }
            return (nil, .ipv4)
            
        case .ipv6Only:
            // 仅解析 IPv6
            hints.ai_family = AF_INET6
            if getaddrinfo(host, nil, &hints, &result) == 0, let info = result {
                defer { freeaddrinfo(result) }
                if let sockaddr = info.pointee.ai_addr {
                    let sockaddrIn6 = sockaddr.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { $0.pointee }
                    var ipBuffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
                    var addr = sockaddrIn6.sin6_addr
                    inet_ntop(AF_INET6, &addr, &ipBuffer, socklen_t(INET6_ADDRSTRLEN))
                    return (String(cString: ipBuffer), .ipv6)
                }
            }
            return (nil, .ipv6)
            
        case .auto:
            // 系统默认：优先尝试 IPv4
            hints.ai_family = AF_INET
            if getaddrinfo(host, nil, &hints, &result) == 0, let info = result {
                defer { freeaddrinfo(result) }
                if let sockaddr = info.pointee.ai_addr {
                    let sockaddrIn = sockaddr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
                    var ipBuffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                    var addr = sockaddrIn.sin_addr
                    inet_ntop(AF_INET, &addr, &ipBuffer, socklen_t(INET_ADDRSTRLEN))
                    return (String(cString: ipBuffer), .ipv4)
                }
            }
            
            // 如果没有 IPv4，尝试 IPv6
            hints.ai_family = AF_INET6
            result = nil
            
            if getaddrinfo(host, nil, &hints, &result) == 0, let info = result {
                defer { freeaddrinfo(result) }
                if let sockaddr = info.pointee.ai_addr {
                    let sockaddrIn6 = sockaddr.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { $0.pointee }
                    var ipBuffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
                    var addr = sockaddrIn6.sin6_addr
                    inet_ntop(AF_INET6, &addr, &ipBuffer, socklen_t(INET6_ADDRSTRLEN))
                    return (String(cString: ipBuffer), .ipv6)
                }
            }
            
            return (nil, .ipv4)
        }
    }
    
    // MARK: - 反向 DNS 解析（支持 IPv4 和 IPv6）
    private func resolveReverseAsync(_ ip: String, version: IPVersion) async -> String? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let result = self.resolveReverse(ip, version: version)
                continuation.resume(returning: result)
            }
        }
    }
    
    private func resolveReverse(_ ip: String, version: IPVersion) -> String? {
        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        
        switch version {
        case .ipv4:
            var addr = sockaddr_in()
            addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            addr.sin_family = sa_family_t(AF_INET)
            inet_pton(AF_INET, ip, &addr.sin_addr)
            
            let result = withUnsafePointer(to: &addr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                    getnameinfo(sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size),
                               &hostname, socklen_t(hostname.count),
                               nil, 0, 0)
                }
            }
            
            if result == 0 {
                let name = String(cString: hostname)
                return name != ip ? name : nil
            }
            
        case .ipv6:
            var addr = sockaddr_in6()
            addr.sin6_len = UInt8(MemoryLayout<sockaddr_in6>.size)
            addr.sin6_family = sa_family_t(AF_INET6)
            inet_pton(AF_INET6, ip, &addr.sin6_addr)
            
            let result = withUnsafePointer(to: &addr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                    getnameinfo(sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in6>.size),
                               &hostname, socklen_t(hostname.count),
                               nil, 0, 0)
                }
            }
            
            if result == 0 {
                let name = String(cString: hostname)
                return name != ip ? name : nil
            }
        }
        
        return nil
    }
    
    // MARK: - 获取 IP 归属地
    private func fetchIPLocations() async {
        // 检查 Task 是否被取消
        guard !Task.isCancelled else { return }
        
        // 收集所有有效的 IP 地址（排除 "*"）
        let validIPs = hops.compactMap { hop -> String? in
            hop.ip != "*" ? hop.ip : nil
        }
        
        guard !validIPs.isEmpty else { return }
        
        await MainActor.run {
            self.isFetchingLocation = true
        }
        
        // 使用 IPLocationService 来获取归属地（会自动处理私有 IP）
        let locationMap = await IPLocationService.shared.fetchLocations(for: validIPs)
        
        // 再次检查是否被取消
        guard !Task.isCancelled else {
            await MainActor.run {
                self.isFetchingLocation = false
            }
            return
        }
        
        await MainActor.run {
            // 更新每个 hop 的归属地信息
            for i in 0..<self.hops.count {
                let ip = self.hops[i].ip
                if ip != "*", let location = locationMap[ip] {
                    self.hops[i].location = location
                }
            }
            self.isFetchingLocation = false
        }
    }
}
