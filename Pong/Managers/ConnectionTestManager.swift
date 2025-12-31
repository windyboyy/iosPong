//
//  ConnectionTestManager.swift
//  Pong
//
//  Created by 张金琛 on 2025/12/31.
//

import Foundation
import Network
internal import Combine

// MARK: - 连接测试结果
struct ConnectionTestResult: Identifiable {
    let id: UUID
    let domain: String
    let timestamp: Date
    
    // DNS 解析结果
    var ipv4Addresses: [String]
    var ipv6Addresses: [String]
    var cnameRecords: [String]
    var dnsLatency: TimeInterval
    
    // 连接测试结果
    var ipv4Latency: TimeInterval?
    var ipv6Latency: TimeInterval?
    var ipv4Error: String?
    var ipv6Error: String?
    
    init(domain: String, timestamp: Date) {
        self.id = UUID()
        self.domain = domain
        self.timestamp = timestamp
        self.ipv4Addresses = []
        self.ipv6Addresses = []
        self.cnameRecords = []
        self.dnsLatency = 0
        self.ipv4Latency = nil
        self.ipv6Latency = nil
        self.ipv4Error = nil
        self.ipv6Error = nil
    }
    
    // 最终结论
    var preferredProtocol: IPProtocol? {
        let v4Ok = ipv4Latency != nil && ipv4Error == nil
        let v6Ok = ipv6Latency != nil && ipv6Error == nil
        
        if v4Ok && v6Ok {
            // 两个都成功，选延迟低的
            if let v4 = ipv4Latency, let v6 = ipv6Latency {
                return v6 <= v4 ? .ipv6 : .ipv4
            }
        } else if v6Ok {
            return .ipv6
        } else if v4Ok {
            return .ipv4
        }
        return nil
    }
    
    var conclusion: String {
        guard let preferred = preferredProtocol else {
            return LanguageManager.shared.isChinese ? "无法连接" : "Unable to connect"
        }
        let l10n = L10n.shared
        return preferred == .ipv6 ? l10n.useIPv6 : l10n.useIPv4
    }
}

enum IPProtocol: String {
    case ipv4 = "IPv4"
    case ipv6 = "IPv6"
}

// MARK: - 连接测试管理器
@MainActor
class ConnectionTestManager: ObservableObject {
    static let shared = ConnectionTestManager()
    
    @Published var isTesting = false
    @Published var currentPhase: TestPhase = .idle
    @Published var results: [ConnectionTestResult] = []
    @Published var currentResult: ConnectionTestResult?
    
    private var testTask: Task<Void, Never>?
    
    enum TestPhase: Equatable {
        case idle
        case resolvingDNS
        case testingIPv4
        case testingIPv6
        case completed
        
        var description: String {
            let l10n = L10n.shared
            switch self {
            case .idle: return ""
            case .resolvingDNS: return l10n.resolvingDNS
            case .testingIPv4: return l10n.testingIPv4
            case .testingIPv6: return l10n.testingIPv6
            case .completed: return l10n.testCompleted
            }
        }
    }
    
    private init() {}
    
    // MARK: - 开始测试
    func startTest(domain: String, port: Int = 443) {
        stopTest()
        
        isTesting = true
        currentPhase = .resolvingDNS
        currentResult = ConnectionTestResult(domain: domain, timestamp: Date())
        
        testTask = Task {
            var result = ConnectionTestResult(domain: domain, timestamp: Date())
            
            // 1. DNS 解析
            let dnsStart = Date()
            let (ipv4s, ipv6s, cnames) = await resolveDNS(domain: domain)
            result.dnsLatency = Date().timeIntervalSince(dnsStart)
            result.ipv4Addresses = ipv4s
            result.ipv6Addresses = ipv6s
            result.cnameRecords = cnames
            
            currentResult = result
            
            // 2. 并行测试 IPv4 和 IPv6 连接
            await withTaskGroup(of: Void.self) { group in
                // IPv4 测试
                if !ipv4s.isEmpty {
                    group.addTask {
                        await MainActor.run { self.currentPhase = .testingIPv4 }
                        let (latency, error) = await self.testConnection(host: ipv4s[0], port: port, isIPv6: false)
                        await MainActor.run {
                            self.currentResult?.ipv4Latency = latency
                            self.currentResult?.ipv4Error = error
                        }
                    }
                }
                
                // IPv6 测试
                if !ipv6s.isEmpty {
                    group.addTask {
                        await MainActor.run { 
                            if self.currentPhase != .testingIPv4 {
                                self.currentPhase = .testingIPv6 
                            }
                        }
                        let (latency, error) = await self.testConnection(host: ipv6s[0], port: port, isIPv6: true)
                        await MainActor.run {
                            self.currentResult?.ipv6Latency = latency
                            self.currentResult?.ipv6Error = error
                        }
                    }
                }
            }
            
            // 3. 完成
            if let finalResult = currentResult {
                results.insert(finalResult, at: 0)
                if results.count > 20 {
                    results.removeLast()
                }
            }
            
            currentPhase = .completed
            isTesting = false
        }
    }
    
    func stopTest() {
        testTask?.cancel()
        testTask = nil
        isTesting = false
        currentPhase = .idle
    }
    
    func clearHistory() {
        results.removeAll()
        currentResult = nil
    }
    
    // MARK: - DNS 解析（使用系统 DNS）
    private func resolveDNS(domain: String) async -> ([String], [String], [String]) {
        var ipv4s: [String] = []
        var ipv6s: [String] = []
        let cnames: [String] = [] // 系统 DNS 不返回 CNAME
        
        // 使用 getaddrinfo 进行系统 DNS 解析
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                var hints = addrinfo()
                hints.ai_family = AF_UNSPEC // 同时查询 IPv4 和 IPv6
                hints.ai_socktype = SOCK_STREAM
                
                var result: UnsafeMutablePointer<addrinfo>?
                let status = getaddrinfo(domain, nil, &hints, &result)
                
                defer {
                    if result != nil {
                        freeaddrinfo(result)
                    }
                }
                
                guard status == 0, let addrList = result else {
                    continuation.resume()
                    return
                }
                
                var current: UnsafeMutablePointer<addrinfo>? = addrList
                while let addr = current {
                    if addr.pointee.ai_family == AF_INET {
                        // IPv4
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        if getnameinfo(addr.pointee.ai_addr, addr.pointee.ai_addrlen,
                                      &hostname, socklen_t(hostname.count),
                                      nil, 0, NI_NUMERICHOST) == 0 {
                            let ip = String(cString: hostname)
                            if !ipv4s.contains(ip) {
                                ipv4s.append(ip)
                            }
                        }
                    } else if addr.pointee.ai_family == AF_INET6 {
                        // IPv6
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        if getnameinfo(addr.pointee.ai_addr, addr.pointee.ai_addrlen,
                                      &hostname, socklen_t(hostname.count),
                                      nil, 0, NI_NUMERICHOST) == 0 {
                            let ip = String(cString: hostname)
                            // 过滤掉 link-local 地址
                            if !ip.hasPrefix("fe80:") && !ipv6s.contains(ip) {
                                ipv6s.append(ip)
                            }
                        }
                    }
                    current = addr.pointee.ai_next
                }
                
                continuation.resume()
            }
        }
        
        return (ipv4s, ipv6s, cnames)
    }
    
    // MARK: - 连接测试
    private func testConnection(host: String, port: Int, isIPv6: Bool) async -> (TimeInterval?, String?) {
        return await withCheckedContinuation { continuation in
            let hostType: NWEndpoint.Host
            if isIPv6 {
                guard let ipv6 = IPv6Address(host) else {
                    continuation.resume(returning: (nil, LanguageManager.shared.isChinese ? "无效的 IPv6 地址" : "Invalid IPv6 address"))
                    return
                }
                hostType = .ipv6(ipv6)
            } else {
                guard let ipv4 = IPv4Address(host) else {
                    continuation.resume(returning: (nil, LanguageManager.shared.isChinese ? "无效的 IPv4 地址" : "Invalid IPv4 address"))
                    return
                }
                hostType = .ipv4(ipv4)
            }
            
            let endpoint = NWEndpoint.hostPort(host: hostType, port: NWEndpoint.Port(integerLiteral: UInt16(port)))
            
            let parameters = NWParameters.tcp
            parameters.requiredInterfaceType = .other
            
            let connection = NWConnection(to: endpoint, using: parameters)
            let startTime = Date()
            var hasResumed = false
            
            // 超时处理
            let timeoutWorkItem = DispatchWorkItem {
                if !hasResumed {
                    hasResumed = true
                    connection.cancel()
                    continuation.resume(returning: (nil, L10n.shared.connectionTimeout))
                }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 5, execute: timeoutWorkItem)
            
            connection.stateUpdateHandler = { state in
                guard !hasResumed else { return }
                
                switch state {
                case .ready:
                    hasResumed = true
                    timeoutWorkItem.cancel()
                    let latency = Date().timeIntervalSince(startTime)
                    connection.cancel()
                    continuation.resume(returning: (latency, nil))
                    
                case .failed(let error):
                    hasResumed = true
                    timeoutWorkItem.cancel()
                    connection.cancel()
                    continuation.resume(returning: (nil, error.localizedDescription))
                    
                case .cancelled:
                    if !hasResumed {
                        hasResumed = true
                        timeoutWorkItem.cancel()
                        continuation.resume(returning: (nil, L10n.shared.connectionCancelled))
                    }
                    
                default:
                    break
                }
            }
            
            connection.start(queue: .global())
        }
    }
}
