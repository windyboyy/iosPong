//
//  TCPManager.swift
//  Pong
//
//  Created by 张金琛 on 2025/12/12.
//

import Foundation
import Network
import Darwin
internal import Combine

@MainActor
class TCPManager: ObservableObject {
    static let shared = TCPManager()
    
    @Published var isScanning = false
    @Published var results: [TCPResult] = []
    @Published var currentHost = ""
    @Published var progress: Double = 0
    @Published var protocolPreference: IPProtocolPreference = .auto  // 用户选择的协议偏好
    private var actualUseIPv6: Bool = false  // 实际使用的 IP 版本（根据解析结果）
    
    private var scanTask: Task<Void, Never>?
    
    private init() {}
    
    // MARK: - 网络状态检查
    
    /// 检查当前是否有网络连接
    /// 注意：如果状态是 unknown，我们假设网络可用（让实际的网络操作来判断）
    var isNetworkAvailable: Bool {
        let status = DeviceInfoManager.shared.networkStatus
        return status != .disconnected
    }
    
    /// 检查是否是 IPv6 地址
    private func isIPv6(_ host: String) -> Bool {
        var addr6 = in6_addr()
        return inet_pton(AF_INET6, host, &addr6) == 1
    }
    
    func scanPorts(host: String, ports: [UInt16]) {
        stopScan()
        
        // 检查网络连接
        guard isNetworkAvailable else {
            results.removeAll()
            currentHost = host
            let errorResult = TCPResult(
                host: host,
                port: ports.first ?? 0,
                isOpen: false,
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
                let errorResult = TCPResult(
                    host: host,
                    port: ports.first ?? 0,
                    isOpen: false,
                    latency: nil,
                    error: L10n.shared.noLocalIPv6ForTCP,
                    timestamp: Date()
                )
                results.append(errorResult)
                return
            }
        }
        
        results.removeAll()
        currentHost = host
        isScanning = true
        progress = 0
        
        let startTime = Date()
        
        scanTask = Task {
            let total = ports.count
            
            for (index, port) in ports.enumerated() {
                guard !Task.isCancelled else { break }
                
                let result = await scanPort(host: host, port: port)
                results.append(result)
                progress = Double(index + 1) / Double(total)
            }
            
            await MainActor.run {
                self.isScanning = false
                // 保存批量扫描结果到历史记录
                self.saveScanToHistory(host: host, startTime: startTime)
            }
        }
    }
    
    private func saveScanToHistory(host: String, startTime: Date) {
        guard !results.isEmpty else { return }
        
        let duration = Date().timeIntervalSince(startTime)
        
        // 检查是否有 IPv6 错误（所有结果都是同一个错误）
        let ipv6Error = results.first?.error
        let isIPv6Error = ipv6Error?.contains("IPv6") == true
        
        // 转换为 TCPPortDetail 数组
        let portDetails = results.map { result -> TCPPortDetail in
            let serviceName = TCPManager.commonPorts.first { $0.0 == result.port }?.1
            return TCPPortDetail(
                port: Int(result.port),
                serviceName: serviceName,
                isOpen: result.isOpen,
                latency: result.latency.map { $0 * 1000 }  // 秒转毫秒
            )
        }
        
        TaskHistoryManager.shared.addTCPScanRecord(
            target: host,
            portResults: portDetails,
            duration: duration,
            useIPv6: actualUseIPv6,
            errorMessage: isIPv6Error ? ipv6Error : nil
        )
    }
    
    private func saveToHistory(result: TCPResult) {
        let status: TaskStatus = result.isOpen ? .success : .failure
        
        // 检查是否有 IPv6 错误
        let isIPv6Error = result.error?.contains("IPv6") == true
        
        TaskHistoryManager.shared.addTCPRecord(
            target: result.host,
            port: Int(result.port),
            status: status,
            isOpen: result.isOpen,
            latency: result.latency.map { $0 * 1000 },
            useIPv6: actualUseIPv6,
            errorMessage: isIPv6Error ? result.error : nil
        )
    }
    
    func testConnection(host: String, port: UInt16) {
        stopScan()
        
        // 检查网络连接
        guard isNetworkAvailable else {
            results.removeAll()
            currentHost = host
            let errorResult = TCPResult(
                host: host,
                port: port,
                isOpen: false,
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
                let errorResult = TCPResult(
                    host: host,
                    port: port,
                    isOpen: false,
                    latency: nil,
                    error: L10n.shared.noLocalIPv6ForTCP,
                    timestamp: Date()
                )
                results.append(errorResult)
                // 保存到历史记录
                saveToHistory(result: errorResult)
                return
            }
        }
        
        results.removeAll()
        currentHost = host
        isScanning = true
        
        scanTask = Task {
            let result = await scanPort(host: host, port: port)
            results.append(result)
            
            await MainActor.run {
                self.isScanning = false
                // 保存历史记录
                self.saveToHistory(result: result)
            }
        }
    }
    
    func stopScan() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
    }
    
    private func scanPort(host: String, port: UInt16) async -> TCPResult {
        let startTime = Date()
        
        // 先解析主机名，根据 protocolPreference 决定使用的 IP 版本
        let resolved = resolveHost(host)
        
        // 检查解析错误
        if let error = resolved.error {
            return TCPResult(
                host: host,
                port: port,
                isOpen: false,
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
            return TCPResult(
                host: host,
                port: port,
                isOpen: false,
                latency: nil,
                error: L10n.shared.noLocalIPv6ForTCP,
                timestamp: Date()
            )
        }
        
        let hostEndpoint = NWEndpoint.Host(targetHost)
        let portEndpoint = NWEndpoint.Port(rawValue: port)!
        let endpoint = NWEndpoint.hostPort(host: hostEndpoint, port: portEndpoint)
        
        // 创建 TCP 参数
        let tcpOptions = NWProtocolTCP.Options()
        let params = NWParameters(tls: nil, tcp: tcpOptions)
        
        let connection = NWConnection(to: endpoint, using: params)
        
        return await withCheckedContinuation { continuation in
            var hasResumed = false
            
            let timeout = DispatchWorkItem {
                guard !hasResumed else { return }
                hasResumed = true
                connection.cancel()
                
                // 根据情况提示用户
                var errorMsg: String
                if isIPv6 {
                    if !hasLocalIPv6 {
                        errorMsg = L10n.shared.noLocalIPv6ForTCP
                    } else {
                        errorMsg = L10n.shared.ipv6NetworkUnreachable
                    }
                } else {
                    errorMsg = "连接超时"
                }
                
                let result = TCPResult(
                    host: host,
                    port: port,
                    isOpen: false,
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
                    guard !hasResumed else { return }
                    hasResumed = true
                    timeout.cancel()
                    
                    let latency = Date().timeIntervalSince(startTime)
                    connection.cancel()
                    
                    let result = TCPResult(
                        host: host,
                        port: port,
                        isOpen: true,
                        latency: latency,
                        error: nil,
                        timestamp: Date()
                    )
                    continuation.resume(returning: result)
                    
                case .failed(let error):
                    guard !hasResumed else { return }
                    hasResumed = true
                    timeout.cancel()
                    connection.cancel()
                    
                    // 根据情况提示用户
                    var errorMsg: String
                    if isIPv6 {
                        if !hasLocalIPv6 {
                            errorMsg = L10n.shared.noLocalIPv6ForTCP
                        } else {
                            errorMsg = L10n.shared.ipv6NetworkUnreachable
                        }
                    } else {
                        errorMsg = error.localizedDescription
                    }
                    
                    let result = TCPResult(
                        host: host,
                        port: port,
                        isOpen: false,
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
        hints.ai_socktype = SOCK_STREAM
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
    
    // 常用端口列表
    static let commonPorts: [(UInt16, String)] = [
        (21, "FTP"),
        (22, "SSH"),
        (23, "Telnet"),
        (25, "SMTP"),
        (53, "DNS"),
        (80, "HTTP"),
        (110, "POP3"),
        (143, "IMAP"),
        (443, "HTTPS"),
        (993, "IMAPS"),
        (995, "POP3S"),
        (3306, "MySQL"),
        (3389, "RDP"),
        (5432, "PostgreSQL"),
        (6379, "Redis"),
        (8080, "HTTP-Alt"),
        (8443, "HTTPS-Alt"),
        (27017, "MongoDB")
    ]
}
