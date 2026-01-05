//
//  UDPManager.swift
//  Pong
//
//  Created by 张金琛 on 2025/12/12.
//

import Foundation
import Network
import Darwin
internal import Combine

@MainActor
class UDPManager: ObservableObject {
    static let shared = UDPManager()
    
    @Published var isTesting = false
    @Published var results: [UDPResult] = []
    @Published var currentHost = ""
    @Published var protocolPreference: IPProtocolPreference = .auto  // 用户选择的协议偏好
    private var actualUseIPv6: Bool = false  // 实际使用的 IP 版本（根据解析结果）
    
    private var testTask: Task<Void, Never>?
    private var startTime: Date?  // 记录开始时间
    
    private init() {}
    
    // MARK: - 网络状态检查
    
    /// 检查当前是否有网络连接
    /// 注意：如果状态是 unknown，我们假设网络可用（让实际的网络操作来判断）
    var isNetworkAvailable: Bool {
        let status = DeviceInfoManager.shared.networkStatus
        return status != .disconnected
    }
    
    func testUDP(host: String, port: UInt16, message: String = "ping") {
        stopTest()
        
        // 检查网络连接
        guard isNetworkAvailable else {
            results.removeAll()
            currentHost = host
            let errorResult = UDPResult(
                host: host,
                port: port,
                sent: false,
                received: false,
                latency: nil,
                error: "无网络连接，请检查网络设置后重试",
                timestamp: Date()
            )
            results.append(errorResult)
            return
        }
        
        // 检查是否是 IPv6 地址，如果是则检查本机是否有 IPv6
        let isIPv6Address = isIPv6(host)
        if isIPv6Address {
            let hasLocalIPv6 = DeviceInfoManager.shared.deviceInfo?.localIPv6Address != nil
            if !hasLocalIPv6 {
                results.removeAll()
                currentHost = host
                actualUseIPv6 = true
                let errorResult = UDPResult(
                    host: host,
                    port: port,
                    sent: false,
                    received: false,
                    latency: nil,
                    error: L10n.shared.noLocalIPv6ForUDP,
                    timestamp: Date()
                )
                results.append(errorResult)
                // 保存到历史记录
                saveToHistory(result: errorResult, port: port)
                return
            }
        }
        
        results.removeAll()
        currentHost = host
        isTesting = true
        startTime = Date()  // 记录开始时间
        
        testTask = Task {
            let result = await sendUDPPacket(host: host, port: port, message: message)
            results.append(result)
            
            await MainActor.run {
                self.isTesting = false
                // 保存历史记录
                self.saveToHistory(result: result, port: port)
            }
        }
    }
    
    /// 检查是否是 IPv6 地址
    private func isIPv6(_ host: String) -> Bool {
        var addr6 = in6_addr()
        return inet_pton(AF_INET6, host, &addr6) == 1
    }
    
    private func saveToHistory(result: UDPResult, port: UInt16) {
        let status: TaskStatus = result.sent ? (result.received ? .success : .partial) : .failure
        
        // 计算执行时长
        let duration = startTime.map { Date().timeIntervalSince($0) }
        
        // 检查是否有 IPv6 错误
        let isIPv6Error = result.error?.contains("IPv6") == true
        
        TaskHistoryManager.shared.addUDPRecord(
            target: result.host,
            port: Int(port),
            status: status,
            sent: result.sent,
            received: result.received,
            latency: result.latency.map { $0 * 1000 },  // 转换为毫秒
            duration: duration,
            useIPv6: actualUseIPv6,
            errorMessage: isIPv6Error ? result.error : nil
        )
    }
    
    func stopTest() {
        testTask?.cancel()
        testTask = nil
        isTesting = false
    }
    
    private func sendUDPPacket(host: String, port: UInt16, message: String) async -> UDPResult {
        let startTime = Date()
        
        // 先解析主机名，根据 protocolPreference 决定使用的 IP 版本
        let resolved = resolveHost(host)
        
        // 检查解析错误
        if let error = resolved.error {
            return UDPResult(
                host: host,
                port: port,
                sent: false,
                received: false,
                latency: nil,
                error: error,
                timestamp: Date()
            )
        }
        
        let targetHost = resolved.ip ?? host
        let isIPv6 = resolved.isIPv6
        
        // 保存实际使用的 IP 版本
        await MainActor.run {
            self.actualUseIPv6 = isIPv6
        }
        
        // 如果是 IPv6，检查本机是否有 IPv6 地址
        let hasLocalIPv6 = await MainActor.run {
            DeviceInfoManager.shared.deviceInfo?.localIPv6Address != nil
        }
        
        if isIPv6 && !hasLocalIPv6 {
            return UDPResult(
                host: host,
                port: port,
                sent: false,
                received: false,
                latency: nil,
                error: L10n.shared.noLocalIPv6ForUDP,
                timestamp: Date()
            )
        }
        
        let hostEndpoint = NWEndpoint.Host(targetHost)
        let portEndpoint = NWEndpoint.Port(rawValue: port)!
        let endpoint = NWEndpoint.hostPort(host: hostEndpoint, port: portEndpoint)
        let connection = NWConnection(to: endpoint, using: .udp)
        
        return await withCheckedContinuation { continuation in
            var hasResumed = false
            var didSend = false
            
            let timeout = DispatchWorkItem {
                guard !hasResumed else { return }
                hasResumed = true
                connection.cancel()
                
                // 根据情况提示用户
                var errorMsg: String
                if isIPv6 {
                    if !hasLocalIPv6 {
                        // 本机没有 IPv6 地址
                        errorMsg = didSend ? "无响应（\(L10n.shared.noLocalIPv6ForUDP)）" : L10n.shared.noLocalIPv6ForUDP
                    } else {
                        // 本机有 IPv6 但超时，可能是网络不支持 IPv6
                        errorMsg = didSend ? "无响应（\(L10n.shared.ipv6NetworkUnreachable)）" : L10n.shared.ipv6NetworkUnreachable
                    }
                } else {
                    errorMsg = didSend ? "无响应（UDP 无连接，可能正常）" : "发送超时"
                }
                
                let result = UDPResult(
                    host: host,
                    port: port,
                    sent: didSend,
                    received: false,
                    latency: nil,
                    error: errorMsg,
                    timestamp: Date()
                )
                continuation.resume(returning: result)
            }
            
            DispatchQueue.global().asyncAfter(deadline: .now() + 3, execute: timeout)
            
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    // UDP 连接就绪，发送数据
                    let data = message.data(using: .utf8)!
                    connection.send(content: data, completion: .contentProcessed { error in
                        if error == nil {
                            didSend = true
                        }
                    })
                    
                    // 尝试接收响应
                    connection.receive(minimumIncompleteLength: 1, maximumLength: 65535) { data, _, _, error in
                        guard !hasResumed else { return }
                        hasResumed = true
                        timeout.cancel()
                        connection.cancel()
                        
                        let latency = Date().timeIntervalSince(startTime)
                        let result = UDPResult(
                            host: host,
                            port: port,
                            sent: true,
                            received: data != nil,
                            latency: data != nil ? latency : nil,
                            error: error?.localizedDescription,
                            timestamp: Date()
                        )
                        continuation.resume(returning: result)
                    }
                    
                case .failed(let error):
                    guard !hasResumed else { return }
                    hasResumed = true
                    timeout.cancel()
                    connection.cancel()
                    
                    // 根据情况提示用户
                    var errorMsg = error.localizedDescription
                    if isIPv6 {
                        if !hasLocalIPv6 {
                            errorMsg = L10n.shared.noLocalIPv6ForUDP
                        } else {
                            errorMsg = L10n.shared.ipv6NetworkUnreachable
                        }
                    }
                    
                    let result = UDPResult(
                        host: host,
                        port: port,
                        sent: false,
                        received: false,
                        latency: nil,
                        error: errorMsg,
                        timestamp: Date()
                    )
                    continuation.resume(returning: result)
                    
                default:
                    break
                }
            }
            
            connection.start(queue: .global())
        }
    }
    
    // MARK: - DNS 解析
    
    /// 解析主机名，根据 protocolPreference 决定优先级，返回 (IP, 是否为IPv6, 错误信息)
    private func resolveHost(_ host: String) -> (ip: String?, isIPv6: Bool, error: String?) {
        // 检查是否已经是 IP 地址
        var addr6 = in6_addr()
        if inet_pton(AF_INET6, host, &addr6) == 1 {
            // 用户输入的是 IPv6 地址
            if protocolPreference == .ipv4Only {
                return (nil, true, L10n.shared.ipv6AddressNotAllowed)
            }
            return (host, true, nil)
        }
        var addr4 = in_addr()
        if inet_pton(AF_INET, host, &addr4) == 1 {
            // 用户输入的是 IPv4 地址
            if protocolPreference == .ipv6Only {
                return (nil, false, L10n.shared.ipv4AddressNotAllowed)
            }
            return (host, false, nil)
        }
        
        // DNS 解析
        var hints = addrinfo()
        hints.ai_socktype = SOCK_DGRAM
        var result: UnsafeMutablePointer<addrinfo>?
        
        switch protocolPreference {
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
                    return (String(cString: ipBuffer), true, nil)
                }
            }
            return (nil, true, L10n.shared.noAAAARecord)  // IPv6 解析失败
            
        case .ipv4Only:
            // 仅 IPv4
            hints.ai_family = AF_INET
            
        case .auto:
            // 系统默认（优先 IPv4）
            hints.ai_family = AF_INET
        }
        
        if getaddrinfo(host, nil, &hints, &result) == 0, let info = result {
            defer { freeaddrinfo(result) }
            if let sockaddr = info.pointee.ai_addr {
                let sockaddrIn = sockaddr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
                var ipBuffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                var addr = sockaddrIn.sin_addr
                inet_ntop(AF_INET, &addr, &ipBuffer, socklen_t(INET_ADDRSTRLEN))
                return (String(cString: ipBuffer), false, nil)
            }
        }
        
        return (nil, false, L10n.shared.dnsResolveFailed)
    }
    
    // 常用 UDP 端口
    static let commonPorts: [(UInt16, String)] = [
        (53, "DNS"),
        (67, "DHCP Server"),
        (68, "DHCP Client"),
        (69, "TFTP"),
        (123, "NTP"),
        (161, "SNMP"),
        (500, "IKE/IPSec"),
        (514, "Syslog"),
        (1194, "OpenVPN"),
        (5353, "mDNS")
    ]
}
