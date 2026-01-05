//
//  PingManager.swift
//  Pong
//
//  Created by 张金琛 on 2025/12/12.
//

import Foundation
import Darwin
import UIKit
internal import Combine

@MainActor
class PingManager: ObservableObject {
    static let shared = PingManager()
    
    @Published var isPinging = false
    @Published var results: [PingResult] = []
    @Published var statistics = PingStatistics()
    @Published var currentHost = ""
    @Published var resolvedIP = ""  // 解析后的 IP
    @Published var packetSize: Int = 56  // 发包大小（字节）
    @Published var interval: Double = 0.2  // 发包间隔（秒）
    @Published var ipVersion: IPVersion = .ipv4  // 当前使用的 IP 版本
    @Published var protocolPreference: IPProtocolPreference = .auto  // 用户选择的协议偏好
    
    private var pingTask: Task<Void, Never>?
    private var sequence: UInt16 = 0
    private var startTime: Date?  // 记录开始时间
    private let timeout: TimeInterval = 2.0  // 超时时间（秒）
    
    // 后台任务标识符
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    
    private init() {}
    
    // MARK: - 网络状态检查
    
    /// 检查当前是否有网络连接
    /// 注意：如果状态是 unknown，我们假设网络可用（让实际的网络操作来判断）
    var isNetworkAvailable: Bool {
        let status = DeviceInfoManager.shared.networkStatus
        return status != .disconnected
    }
    
    func startPing(host: String, count: Int = 0) {
        stopPing()
        
        // 检查网络连接
        guard isNetworkAvailable else {
            results.removeAll()
            statistics = PingStatistics()
            currentHost = host
            let errorResult = PingResult(
                sequence: 0,
                host: host,
                ip: host,
                latency: nil,
                status: .error("无网络连接，请检查网络设置后重试"),
                timestamp: Date()
            )
            results.append(errorResult)
            return
        }
        
        // 申请后台执行时间
        beginBackgroundTask()
        
        results.removeAll()
        statistics = PingStatistics()
        sequence = 0
        currentHost = host
        resolvedIP = ""
        isPinging = true
        startTime = Date()  // 记录开始时间
        
        pingTask = Task {
            // 先解析主机名
            let resolved = self.resolveHost(host)
            guard let targetIP = resolved.ip else {
                await MainActor.run {
                    let errorResult = PingResult(
                        sequence: 0,
                        host: host,
                        ip: host,
                        latency: nil,
                        status: .error("无法解析主机名: \(host)"),
                        timestamp: Date()
                    )
                    self.results.append(errorResult)
                    self.isPinging = false
                    self.endBackgroundTask()
                }
                return
            }
            
            await MainActor.run {
                self.resolvedIP = targetIP
                self.ipVersion = resolved.version
            }
            
            // 如果是 IPv6 Ping，检查本机是否有 IPv6 地址
            if resolved.version == .ipv6 {
                let hasIPv6 = await MainActor.run {
                    DeviceInfoManager.shared.deviceInfo?.localIPv6Address != nil
                }
                if !hasIPv6 {
                    await MainActor.run {
                        let errorResult = PingResult(
                            sequence: 0,
                            host: host,
                            ip: targetIP,
                            latency: nil,
                            status: .error(L10n.shared.noLocalIPv6ForPing),
                            timestamp: Date()
                        )
                        self.results.append(errorResult)
                        self.isPinging = false
                        // 保存错误到历史记录
                        self.saveIPv6ErrorToHistory(host: host, errorMessage: L10n.shared.noLocalIPv6ForPing)
                        self.endBackgroundTask()
                    }
                    return
                }
            }
            
            let intervalNs = UInt64(self.interval * 1_000_000_000)
            var pingCount = 0
            
            while !Task.isCancelled && (count == 0 || pingCount < count) {
                await self.pingICMP(targetIP: targetIP, host: host, version: resolved.version)
                pingCount += 1
                
                if !Task.isCancelled && (count == 0 || pingCount < count) {
                    try? await Task.sleep(nanoseconds: intervalNs)
                }
            }
            
            await MainActor.run {
                self.isPinging = false
                // 保存历史记录
                self.saveToHistory()
                // 结束后台任务
                self.endBackgroundTask()
            }
        }
    }
    
    private func saveToHistory() {
        guard statistics.sent > 0 else { return }
        
        let status: TaskStatus = statistics.received > 0 ? 
            (statistics.lossRate < 50 ? .success : .partial) : .failure
        
        // 计算执行时长
        let duration = startTime.map { Date().timeIntervalSince($0) }
        
        // 转换单次 ping 结果
        let pingResultDetails: [PingResultDetail] = results.map { result in
            let success: Bool
            switch result.status {
            case .success:
                success = true
            default:
                success = false
            }
            return PingResultDetail(
                sequence: result.sequence,
                success: success,
                latency: result.latency.map { $0 * 1000 }  // 转换为毫秒
            )
        }
        
        TaskHistoryManager.shared.addPingRecord(
            target: currentHost,
            status: status,
            avgLatency: statistics.received > 0 ? statistics.avgLatency * 1000 : nil,
            minLatency: statistics.received > 0 ? statistics.minLatency * 1000 : nil,
            maxLatency: statistics.received > 0 ? statistics.maxLatency * 1000 : nil,
            stdDev: statistics.received > 0 ? statistics.stddevLatency * 1000 : nil,
            lossRate: statistics.lossRate,
            sent: statistics.sent,
            received: statistics.received,
            packetSize: packetSize,
            resolvedIP: resolvedIP.isEmpty ? nil : resolvedIP,
            pingResults: pingResultDetails,
            duration: duration,
            useIPv6: ipVersion == .ipv6  // 根据实际解析结果判断
        )
    }
    
    /// 保存 IPv6 检查失败的错误到历史记录
    private func saveIPv6ErrorToHistory(host: String, errorMessage: String) {
        let duration = startTime.map { Date().timeIntervalSince($0) }
        
        TaskHistoryManager.shared.addPingRecord(
            target: host,
            status: .failure,
            avgLatency: nil,
            minLatency: nil,
            maxLatency: nil,
            stdDev: nil,
            lossRate: 100,
            sent: 0,
            received: 0,
            packetSize: packetSize,
            resolvedIP: resolvedIP.isEmpty ? nil : resolvedIP,
            pingResults: nil,
            duration: duration,
            useIPv6: true,
            errorMessage: errorMessage
        )
    }
    
    func stopPing() {
        pingTask?.cancel()
        pingTask = nil
        isPinging = false
        endBackgroundTask()
    }
    
    // MARK: - 后台任务管理
    private func beginBackgroundTask() {
        endBackgroundTask()
        
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "Ping") { [weak self] in
            Task { @MainActor in
                self?.handleBackgroundTaskExpiration()
            }
        }
    }
    
    private func endBackgroundTask() {
        guard backgroundTaskID != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
    }
    
    private func handleBackgroundTaskExpiration() {
        // 后台时间即将用尽，停止 ping 但保留已有结果
        pingTask?.cancel()
        pingTask = nil
        
        if isPinging {
            isPinging = false
            saveToHistory()
        }
        
        endBackgroundTask()
    }
    
    // MARK: - ICMP Ping 实现
    
    private func pingICMP(targetIP: String, host: String, version: IPVersion) async {
        sequence += 1
        let seq = sequence
        statistics.sent += 1
        
        let result = await withCheckedContinuation { (continuation: CheckedContinuation<PingResult, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let pingResult: (success: Bool, latency: TimeInterval?, errorMsg: String?)
                
                switch version {
                case .ipv4:
                    pingResult = self.syncPingICMPv4(to: targetIP, sequence: seq)
                case .ipv6:
                    pingResult = self.syncPingICMPv6(to: targetIP, sequence: seq)
                }
                
                let result: PingResult
                if pingResult.success, let latency = pingResult.latency {
                    result = PingResult(
                        sequence: Int(seq),
                        host: host,
                        ip: targetIP,
                        latency: latency,
                        status: .success,
                        timestamp: Date()
                    )
                } else if let errorMsg = pingResult.errorMsg {
                    result = PingResult(
                        sequence: Int(seq),
                        host: host,
                        ip: targetIP,
                        latency: nil,
                        status: .error(errorMsg),
                        timestamp: Date()
                    )
                } else {
                    result = PingResult(
                        sequence: Int(seq),
                        host: host,
                        ip: targetIP,
                        latency: nil,
                        status: .timeout,
                        timestamp: Date()
                    )
                }
                
                continuation.resume(returning: result)
            }
        }
        
        switch result.status {
        case .success:
            statistics.received += 1
            if let latency = result.latency {
                statistics.totalLatency += latency
                statistics.latencies.append(latency)
                statistics.minLatency = min(statistics.minLatency, latency)
                statistics.maxLatency = max(statistics.maxLatency, latency)
            }
        case .timeout, .error:
            statistics.lost += 1
        }
        
        results.append(result)
        
        if results.count > 100 {
            results.removeFirst()
        }
    }
    
    // MARK: - IPv4 ICMP Ping
    
    private func syncPingICMPv4(to targetIP: String, sequence: UInt16) -> (success: Bool, latency: TimeInterval?, errorMsg: String?) {
        // 创建 ICMP socket
        let sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP)
        guard sock >= 0 else {
            return (false, nil, "创建 socket 失败")
        }
        defer { close(sock) }
        
        // 设置接收超时
        let timeoutMs: Int32 = Int32(timeout * 1000)
        var tv = timeval(tv_sec: Int(timeout), tv_usec: 0)
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        
        // 目标地址
        var destAddr = sockaddr_in()
        destAddr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        destAddr.sin_family = sa_family_t(AF_INET)
        destAddr.sin_port = 0
        inet_pton(AF_INET, targetIP, &destAddr.sin_addr)
        
        // 构建 ICMP Echo Request
        let identifier = UInt16(ProcessInfo.processInfo.processIdentifier & 0xFFFF)
        var icmpPacket = createICMPv4Packet(identifier: identifier, sequence: sequence, payloadSize: packetSize)
        
        let startTime = Date()
        
        // 发送
        let sendResult = withUnsafePointer(to: &destAddr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                sendto(sock, &icmpPacket, icmpPacket.count, 0, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        
        guard sendResult > 0 else {
            return (false, nil, "发送失败: errno=\(errno)")
        }
        
        // 接收响应
        let deadline = Date().addingTimeInterval(timeout)
        
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
                // 超时
                return (false, nil, nil)
            }
            
            let latency = Date().timeIntervalSince(startTime)
            
            // 解析 IP 头部长度
            let ipHeaderLength = Int((recvBuffer[0] & 0x0F)) * 4
            guard recvResult > ipHeaderLength + 8 else {
                continue
            }
            
            let icmpType = recvBuffer[ipHeaderLength]
            
            if icmpType == 0 {
                // Echo Reply - 验证 identifier 和 sequence
                let recvIdentifier = (UInt16(recvBuffer[ipHeaderLength + 4]) << 8) | UInt16(recvBuffer[ipHeaderLength + 5])
                let recvSequence = (UInt16(recvBuffer[ipHeaderLength + 6]) << 8) | UInt16(recvBuffer[ipHeaderLength + 7])
                
                if recvIdentifier == identifier && recvSequence == sequence {
                    return (true, latency, nil)
                } else {
                    // 不是我们的包，继续等待
                    continue
                }
            } else if icmpType == 3 {
                // Destination Unreachable
                return (false, nil, "目标不可达")
            } else {
                // 其他类型，继续等待
                continue
            }
        }
        
        return (false, nil, nil)
    }
    
    // MARK: - IPv6 ICMPv6 Ping
    
    private func syncPingICMPv6(to targetIP: String, sequence: UInt16) -> (success: Bool, latency: TimeInterval?, errorMsg: String?) {
        let ICMPV6_ECHO_REPLY: UInt8 = 129
        let ICMPV6_DST_UNREACH: UInt8 = 1
        
        // 创建 ICMPv6 socket
        let sock = socket(AF_INET6, SOCK_DGRAM, IPPROTO_ICMPV6)
        guard sock >= 0 else {
            return (false, nil, "创建 socket 失败")
        }
        defer { close(sock) }
        
        // 设置接收超时
        var tv = timeval(tv_sec: Int(timeout), tv_usec: 0)
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        
        // 目标地址
        var destAddr = sockaddr_in6()
        destAddr.sin6_len = UInt8(MemoryLayout<sockaddr_in6>.size)
        destAddr.sin6_family = sa_family_t(AF_INET6)
        destAddr.sin6_port = 0
        destAddr.sin6_flowinfo = 0
        destAddr.sin6_scope_id = 0
        
        if inet_pton(AF_INET6, targetIP, &destAddr.sin6_addr) != 1 {
            return (false, nil, "无效的 IPv6 地址")
        }
        
        // 构建 ICMPv6 Echo Request
        let identifier = UInt16(ProcessInfo.processInfo.processIdentifier & 0xFFFF)
        var icmpPacket = createICMPv6Packet(identifier: identifier, sequence: sequence, payloadSize: packetSize)
        
        let startTime = Date()
        
        // 发送
        let sendResult = withUnsafePointer(to: &destAddr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                sendto(sock, &icmpPacket, icmpPacket.count, 0, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in6>.size))
            }
        }
        
        guard sendResult > 0 else {
            let err = errno
            var errMsg = "发送失败"
            switch err {
            case 51: errMsg = "网络不可达（无 IPv6 网络）"
            case 65: errMsg = "主机不可达"
            case 64: errMsg = "主机已关闭"
            case 61: errMsg = "连接被拒绝"
            default: errMsg = "发送失败: errno=\(err)"
            }
            return (false, nil, errMsg)
        }
        
        // 接收响应
        let deadline = Date().addingTimeInterval(timeout)
        
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
                return (false, nil, nil)
            }
            
            let latency = Date().timeIntervalSince(startTime)
            
            // ICMPv6 没有 IP 头部
            let icmpType = recvBuffer[0]
            
            if icmpType == ICMPV6_ECHO_REPLY {
                let recvIdentifier = (UInt16(recvBuffer[4]) << 8) | UInt16(recvBuffer[5])
                let recvSequence = (UInt16(recvBuffer[6]) << 8) | UInt16(recvBuffer[7])
                
                if recvIdentifier == identifier && recvSequence == sequence {
                    return (true, latency, nil)
                } else {
                    continue
                }
            } else if icmpType == ICMPV6_DST_UNREACH {
                return (false, nil, "目标不可达")
            } else {
                continue
            }
        }
        
        return (false, nil, nil)
    }
    
    // MARK: - 创建 ICMPv4 包
    
    private func createICMPv4Packet(identifier: UInt16, sequence: UInt16, payloadSize: Int) -> [UInt8] {
        let headerSize = 8
        let totalSize = headerSize + payloadSize
        var packet = [UInt8](repeating: 0, count: totalSize)
        
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
        for i in headerSize..<totalSize {
            packet[i] = UInt8(i & 0xFF)
        }
        
        // 计算校验和
        let checksum = icmpChecksum(packet)
        packet[2] = UInt8(checksum & 0xFF)
        packet[3] = UInt8(checksum >> 8)
        
        return packet
    }
    
    // MARK: - 创建 ICMPv6 包
    
    private func createICMPv6Packet(identifier: UInt16, sequence: UInt16, payloadSize: Int) -> [UInt8] {
        let headerSize = 8
        let totalSize = headerSize + payloadSize
        var packet = [UInt8](repeating: 0, count: totalSize)
        
        // Type: 128 (ICMPv6 Echo Request)
        packet[0] = 128
        // Code: 0
        packet[1] = 0
        // Checksum: 内核会自动计算
        packet[2] = 0
        packet[3] = 0
        // Identifier
        packet[4] = UInt8(identifier >> 8)
        packet[5] = UInt8(identifier & 0xFF)
        // Sequence
        packet[6] = UInt8(sequence >> 8)
        packet[7] = UInt8(sequence & 0xFF)
        
        // 填充数据
        for i in headerSize..<totalSize {
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
    
    // MARK: - DNS 解析
    
    private func resolveHost(_ host: String) -> (ip: String?, version: IPVersion) {
        // 检查是否已经是 IPv6 地址
        var addr6 = in6_addr()
        if inet_pton(AF_INET6, host, &addr6) == 1 {
            // 如果用户指定仅 IPv4，但输入的是 IPv6 地址，返回失败
            if protocolPreference == .ipv4Only {
                return (nil, .ipv4)
            }
            return (host, .ipv6)
        }
        
        // 检查是否已经是 IPv4 地址
        var addr4 = in_addr()
        if inet_pton(AF_INET, host, &addr4) == 1 {
            // 如果用户指定仅 IPv6，但输入的是 IPv4 地址，返回失败
            if protocolPreference == .ipv6Only {
                return (nil, .ipv6)
            }
            return (host, .ipv4)
        }
        
        // DNS 解析 - 根据 protocolPreference 决定解析策略
        var hints = addrinfo()
        hints.ai_socktype = SOCK_DGRAM
        var result: UnsafeMutablePointer<addrinfo>?
        
        switch protocolPreference {
        case .ipv4Only:
            // 仅 IPv4
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
            // 仅 IPv6
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
            // 默认行为：让系统自动选择（不指定 ai_family）
            hints.ai_family = AF_UNSPEC
            if getaddrinfo(host, nil, &hints, &result) == 0, let info = result {
                defer { freeaddrinfo(result) }
                if let sockaddr = info.pointee.ai_addr {
                    let family = Int32(sockaddr.pointee.sa_family)
                    if family == AF_INET {
                        let sockaddrIn = sockaddr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
                        var ipBuffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                        var addr = sockaddrIn.sin_addr
                        inet_ntop(AF_INET, &addr, &ipBuffer, socklen_t(INET_ADDRSTRLEN))
                        return (String(cString: ipBuffer), .ipv4)
                    } else if family == AF_INET6 {
                        let sockaddrIn6 = sockaddr.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { $0.pointee }
                        var ipBuffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
                        var addr = sockaddrIn6.sin6_addr
                        inet_ntop(AF_INET6, &addr, &ipBuffer, socklen_t(INET6_ADDRSTRLEN))
                        return (String(cString: ipBuffer), .ipv6)
                    }
                }
            }
        }
        
        return (nil, .ipv4)
    }
}
