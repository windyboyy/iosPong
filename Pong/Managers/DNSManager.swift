//
//  DNSManager.swift
//  Pong
//
//  Created by 张金琛 on 2025/12/12.
//

import Foundation
import dnssd
internal import Combine

@MainActor
class DNSManager: ObservableObject {
    static let shared = DNSManager()
    
    @Published var isQuerying = false
    @Published var results: [DNSResult] = []
    @Published var currentDomain = ""
    
    private var queryTask: Task<Void, Never>?
    private var startTime: Date?  // 记录开始时间
    
    private init() {}
    
    // MARK: - 网络状态检查
    
    /// 检查当前是否有网络连接
    /// 注意：如果状态是 unknown，我们假设网络可用（让实际的网络操作来判断）
    var isNetworkAvailable: Bool {
        let status = DeviceInfoManager.shared.networkStatus
        return status != .disconnected
    }
    
    /// 获取当前网络状态
    var currentNetworkStatus: NetworkStatus {
        DeviceInfoManager.shared.networkStatus
    }
    
    // MARK: - IP 转反向 DNS 域名
    
    /// 将 IPv4 地址转换为反向 DNS 域名
    /// 例如: 1.2.3.4 → 4.3.2.1.in-addr.arpa
    static func ipToReverseDomain(_ ip: String) -> String? {
        let parts = ip.split(separator: ".")
        if parts.count == 4, parts.allSatisfy({ UInt8($0) != nil }) {
            // IPv4
            return parts.reversed().joined(separator: ".") + ".in-addr.arpa"
        }
        
        // IPv6 处理
        if ip.contains(":") {
            // 展开 IPv6 地址
            var fullAddress = ip
            
            // 处理 :: 简写
            if ip.contains("::") {
                let sides = ip.split(separator: "::", omittingEmptySubsequences: false)
                let left = sides.first?.split(separator: ":") ?? []
                let right = sides.count > 1 ? sides[1].split(separator: ":") : []
                let missing = 8 - left.count - right.count
                let middle = Array(repeating: "0", count: missing)
                let allParts = left.map(String.init) + middle + right.map(String.init)
                fullAddress = allParts.joined(separator: ":")
            }
            
            let ipv6Parts = fullAddress.split(separator: ":")
            if ipv6Parts.count == 8 {
                // 每个部分补齐 4 位，然后逐字符反转
                let nibbles = ipv6Parts.flatMap { part -> [Character] in
                    let padded = String(repeating: "0", count: 4 - part.count) + part
                    return Array(padded)
                }
                return nibbles.reversed().map(String.init).joined(separator: ".") + ".ip6.arpa"
            }
        }
        
        return nil
    }
    
    /// 检测输入是否为 IP 地址
    static func isIPAddress(_ input: String) -> Bool {
        // IPv4
        let ipv4Parts = input.split(separator: ".")
        if ipv4Parts.count == 4, ipv4Parts.allSatisfy({ UInt8($0) != nil }) {
            return true
        }
        // IPv6
        if input.contains(":") {
            return true
        }
        return false
    }
    
    func query(domain: String, recordType: DNSRecordType = .A) {
        stopQuery()
        
        // 检查网络连接
        guard isNetworkAvailable else {
            let errorResult = DNSResult(
                domain: domain,
                recordType: recordType,
                records: [],
                latency: 0,
                server: "系统 DNS",
                error: "无网络连接，请检查网络设置后重试",
                timestamp: Date()
            )
            results.insert(errorResult, at: 0)
            saveToHistory(result: errorResult)
            return
        }
        
        // PTR 查询：如果输入是 IP 地址，自动转换为反向域名
        var queryDomain = domain
        if recordType == .PTR && DNSManager.isIPAddress(domain) {
            guard let reverseDomain = DNSManager.ipToReverseDomain(domain) else {
                let errorResult = DNSResult(
                    domain: domain,
                    recordType: recordType,
                    records: [],
                    latency: 0,
                    server: "系统 DNS",
                    error: "无效的 IP 地址格式",
                    timestamp: Date()
                )
                results.insert(errorResult, at: 0)
                saveToHistory(result: errorResult)
                return
            }
            queryDomain = reverseDomain
        }
        
        currentDomain = domain  // 显示原始输入
        isQuerying = true
        startTime = Date()  // 记录开始时间
        
        queryTask = Task {
            var result: DNSResult
            
            if recordType == .systemDefault {
                // 系统默认解析
                result = await performSystemDefaultQuery(domain: queryDomain)
            } else {
                result = await performDNSQuery(domain: queryDomain, recordType: recordType)
            }
            
            // PTR 查询结果中保留原始 IP
            if recordType == .PTR && domain != queryDomain {
                result = DNSResult(
                    domain: domain,  // 显示原始 IP
                    recordType: result.recordType,
                    records: result.records,
                    latency: result.latency,
                    server: result.server,
                    error: result.error,
                    timestamp: result.timestamp
                )
            }
            
            // 查询 IP 归属地
            result = await fetchIPLocationsForResult(result)
            
            results.insert(result, at: 0)
            
            if results.count > 50 {
                results.removeLast()
            }
            
            // 保存历史记录
            saveToHistory(result: result)
            
            isQuerying = false
        }
    }
    
    private func saveToHistory(result: DNSResult) {
        let status: TaskStatus = result.error == nil ? .success : .failure
        let records = result.records.map { $0.value }
        
        // 计算执行时长
        let duration = startTime.map { Date().timeIntervalSince($0) }
        
        // 构建完整的记录详情
        let recordDetails = result.records.map { record in
            DNSRecordDetail(
                name: record.name,
                type: record.typeString,
                ttl: record.ttl,
                value: record.value
            )
        }
        
        TaskHistoryManager.shared.addDNSRecord(
            target: result.domain,
            status: status,
            records: records,
            recordDetails: recordDetails,
            queryTime: result.latency * 1000,
            server: result.server,
            recordType: result.recordType.rawValue,
            duration: duration
        )
    }
    
    func queryAll(domain: String) {
        stopQuery()
        
        // 检查网络连接
        guard isNetworkAvailable else {
            let errorResult = DNSResult(
                domain: domain,
                recordType: .A,
                records: [],
                latency: 0,
                server: "系统 DNS",
                error: "无网络连接，请检查网络设置后重试",
                timestamp: Date()
            )
            results.insert(errorResult, at: 0)
            saveToHistory(result: errorResult)
            return
        }
        
        currentDomain = domain
        isQuerying = true
        
        queryTask = Task {
            for recordType in DNSRecordType.allCases {
                guard !Task.isCancelled else { break }
                
                // 跳过系统默认，因为它会返回混合记录
                if recordType == .systemDefault { continue }
                
                var result = await performDNSQuery(domain: domain, recordType: recordType)
                result = await fetchIPLocationsForResult(result)
                results.insert(result, at: 0)
            }
            
            isQuerying = false
        }
    }
    
    func stopQuery() {
        queryTask?.cancel()
        queryTask = nil
        isQuerying = false
    }
    
    func clearHistory() {
        results.removeAll()
    }
    
    // MARK: - DNS 查询实现
    
    /// 系统默认解析（使用 getaddrinfo）
    private func performSystemDefaultQuery(domain: String) async -> DNSResult {
        let startTime = Date()
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var records: [DNSRecord] = []
                var queryError: String? = nil
                
                var hints = addrinfo()
                hints.ai_family = AF_UNSPEC  // 同时获取 IPv4 和 IPv6
                hints.ai_socktype = SOCK_STREAM
                
                var result: UnsafeMutablePointer<addrinfo>?
                let status = getaddrinfo(domain, nil, &hints, &result)
                
                if status == 0, let addrInfo = result {
                    var current: UnsafeMutablePointer<addrinfo>? = addrInfo
                    var isFirst = true
                    
                    while let info = current {
                        let family = info.pointee.ai_family
                        
                        if family == AF_INET {
                            // IPv4
                            if let sockaddr = info.pointee.ai_addr {
                                sockaddr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { addr in
                                    var ip = addr.pointee.sin_addr
                                    var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                                    if inet_ntop(AF_INET, &ip, &buffer, socklen_t(INET_ADDRSTRLEN)) != nil {
                                        let ipString = String(cString: buffer)
                                        // 将 IP 地址转换为 Data
                                        var ipData = Data()
                                        let parts = ipString.split(separator: ".")
                                        for part in parts {
                                            if let byte = UInt8(part) {
                                                ipData.append(byte)
                                            }
                                        }
                                        let record = DNSRecord(
                                            name: domain,
                                            type: UInt16(kDNSServiceType_A),
                                            typeString: "A",
                                            ttl: nil,
                                            value: ipString,
                                            rawData: ipData,
                                            isPrimary: isFirst
                                        )
                                        records.append(record)
                                        isFirst = false
                                    }
                                }
                            }
                        } else if family == AF_INET6 {
                            // IPv6
                            if let sockaddr = info.pointee.ai_addr {
                                sockaddr.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { addr in
                                    var ip = addr.pointee.sin6_addr
                                    var buffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
                                    if inet_ntop(AF_INET6, &ip, &buffer, socklen_t(INET6_ADDRSTRLEN)) != nil {
                                        let ipString = String(cString: buffer)
                                        // 将 IPv6 地址转换为 Data
                                        let ipData = withUnsafeBytes(of: ip) { Data($0) }
                                        let record = DNSRecord(
                                            name: domain,
                                            type: UInt16(kDNSServiceType_AAAA),
                                            typeString: "AAAA",
                                            ttl: nil,
                                            value: ipString,
                                            rawData: ipData,
                                            isPrimary: isFirst
                                        )
                                        records.append(record)
                                        isFirst = false
                                    }
                                }
                            }
                        }
                        
                        current = info.pointee.ai_next
                    }
                    
                    freeaddrinfo(addrInfo)
                } else {
                    queryError = "DNS 解析失败: \(String(cString: gai_strerror(status)))"
                }
                
                if records.isEmpty && queryError == nil {
                    queryError = "未找到任何解析记录"
                }
                
                let latency = Date().timeIntervalSince(startTime)
                
                let dnsResult = DNSResult(
                    domain: domain,
                    recordType: .systemDefault,
                    records: records,
                    latency: latency,
                    server: "系统 DNS",
                    error: queryError,
                    timestamp: Date()
                )
                
                continuation.resume(returning: dnsResult)
            }
        }
    }
    
    private func performDNSQuery(domain: String, recordType: DNSRecordType) async -> DNSResult {
        let startTime = Date()
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var sdRef: DNSServiceRef?
                let rrType = recordType.dnssdType
                
                var records: [DNSRecord] = []
                var queryError: String? = nil
                
                // 用于存储原始数据：(fullname, rrtype, ttl, rdata)
                var rawDataList: [(String?, UInt16, UInt32, Data)] = []
                
                let callback: DNSServiceQueryRecordReply = { sdRef, flags, interfaceIndex, errorCode, fullname, rrtype, rrclass, rdlen, rdata, ttl, context in
                    guard let context = context else { return }
                    let dataListPtr = context.assumingMemoryBound(to: [(String?, UInt16, UInt32, Data)].self)
                    
                    if errorCode == kDNSServiceErr_NoError, let rdata = rdata, rdlen > 0 {
                        let data = Data(bytes: rdata, count: Int(rdlen))
                        let name = fullname.map { String(cString: $0) }
                        dataListPtr.pointee.append((name, rrtype, ttl, data))
                    }
                }
                
                let result = withUnsafeMutablePointer(to: &rawDataList) { ptr in
                    DNSServiceQueryRecord(
                        &sdRef,
                        0,
                        0,
                        domain,
                        rrType,
                        UInt16(kDNSServiceClass_IN),
                        callback,
                        ptr
                    )
                }
                
                if result == kDNSServiceErr_NoError, let sdRef = sdRef {
                    let fd = DNSServiceRefSockFD(sdRef)
                    
                    // 使用 poll 等待响应
                    var pollFd = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
                    let pollResult = poll(&pollFd, 1, 3000) // 3秒超时
                    
                    if pollResult > 0 {
                        DNSServiceProcessResult(sdRef)
                        
                        // 在回调外部解析数据
                        var isFirst = true
                        for (name, rrtype, ttl, data) in rawDataList {
                            let typeString = DNSManager.rrTypeToString(rrtype)
                            let value = DNSManager.parseRData(type: rrtype, data: data) ?? "(无法解析)"
                            
                            let record = DNSRecord(
                                name: name?.trimmingCharacters(in: CharacterSet(charactersIn: ".")),
                                type: rrtype,
                                typeString: typeString,
                                ttl: ttl,
                                value: value,
                                rawData: data,
                                isPrimary: isFirst
                            )
                            records.append(record)
                            isFirst = false
                        }
                    } else {
                        queryError = "查询超时"
                    }
                    
                    DNSServiceRefDeallocate(sdRef)
                } else {
                    queryError = "DNS 查询失败: \(result)"
                }
                
                if records.isEmpty && queryError == nil {
                    queryError = "未找到 \(recordType.rawValue) 记录"
                }
                
                let latency = Date().timeIntervalSince(startTime)
                
                let dnsResult = DNSResult(
                    domain: domain,
                    recordType: recordType,
                    records: records,
                    latency: latency,
                    server: "系统 DNS",
                    error: queryError,
                    timestamp: Date()
                )
                
                continuation.resume(returning: dnsResult)
            }
        }
    }
    
    // MARK: - 记录类型转字符串
    
    private static func rrTypeToString(_ type: UInt16) -> String {
        switch type {
        case UInt16(kDNSServiceType_A):     return "A"
        case UInt16(kDNSServiceType_AAAA):  return "AAAA"
        case UInt16(kDNSServiceType_CNAME): return "CNAME"
        case UInt16(kDNSServiceType_MX):    return "MX"
        case UInt16(kDNSServiceType_TXT):   return "TXT"
        case UInt16(kDNSServiceType_NS):    return "NS"
        case UInt16(kDNSServiceType_SOA):   return "SOA"
        case UInt16(kDNSServiceType_PTR):   return "PTR"
        case UInt16(kDNSServiceType_SRV):   return "SRV"
        default: return "TYPE\(type)"
        }
    }
    
    // MARK: - 解析 DNS 记录数据
    
    private static func parseRData(type: UInt16, data: Data) -> String? {
        switch type {
        case UInt16(kDNSServiceType_A):
            // IPv4 地址
            guard data.count >= 4 else { return nil }
            return data.prefix(4).map { String($0) }.joined(separator: ".")
            
        case UInt16(kDNSServiceType_AAAA):
            // IPv6 地址
            guard data.count >= 16 else { return nil }
            var parts: [String] = []
            for i in stride(from: 0, to: 16, by: 2) {
                let value = UInt16(data[i]) << 8 | UInt16(data[i + 1])
                parts.append(String(format: "%x", value))
            }
            return parts.joined(separator: ":")
            
        case UInt16(kDNSServiceType_CNAME), UInt16(kDNSServiceType_NS), UInt16(kDNSServiceType_PTR):
            // 域名格式
            return parseDomainName(from: data)
            
        case UInt16(kDNSServiceType_MX):
            // MX 记录: 2字节优先级 + 域名
            guard data.count > 2 else { return nil }
            let priority = UInt16(data[0]) << 8 | UInt16(data[1])
            let domainData = data.dropFirst(2)
            if let domain = parseDomainName(from: Data(domainData)) {
                return "\(priority) \(domain)"
            }
            return nil
            
        case UInt16(kDNSServiceType_TXT):
            // TXT 记录: 长度前缀的字符串
            return parseTXTRecord(from: data)
            
        case UInt16(kDNSServiceType_SOA):
            // SOA 记录
            return parseSOARecord(from: data)
            
        default:
            // 未知类型，返回十六进制
            return data.map { String(format: "%02x", $0) }.joined(separator: " ")
        }
    }
    
    private static func parseDomainName(from data: Data) -> String? {
        var parts: [String] = []
        var index = 0
        
        while index < data.count {
            let length = Int(data[index])
            if length == 0 { break }
            
            index += 1
            guard index + length <= data.count else { break }
            
            let partData = data[index..<(index + length)]
            if let part = String(data: partData, encoding: .utf8) {
                parts.append(part)
            }
            index += length
        }
        
        return parts.isEmpty ? nil : parts.joined(separator: ".")
    }
    
    private static func parseTXTRecord(from data: Data) -> String? {
        var texts: [String] = []
        var index = 0
        
        while index < data.count {
            let length = Int(data[index])
            index += 1
            
            guard index + length <= data.count else { break }
            
            let textData = data[index..<(index + length)]
            if let text = String(data: textData, encoding: .utf8) {
                texts.append(text)
            }
            index += length
        }
        
        return texts.isEmpty ? nil : texts.joined(separator: "; ")
    }
    
    private static func parseSOARecord(from data: Data) -> String? {
        // SOA 格式: mname, rname, serial, refresh, retry, expire, minimum
        var index = 0
        var parts: [String] = []
        
        // 解析 mname
        if let mname = parseDomainNameAt(data: data, startIndex: &index) {
            parts.append("mname=\(mname)")
        }
        
        // 解析 rname
        if let rname = parseDomainNameAt(data: data, startIndex: &index) {
            parts.append("rname=\(rname)")
        }
        
        // 解析数字字段
        if index + 20 <= data.count {
            let serial = readUInt32(from: data, at: index)
            let refresh = readUInt32(from: data, at: index + 4)
            let retry = readUInt32(from: data, at: index + 8)
            let expire = readUInt32(from: data, at: index + 12)
            let minimum = readUInt32(from: data, at: index + 16)
            
            parts.append("serial=\(serial)")
            parts.append("refresh=\(refresh)")
            parts.append("retry=\(retry)")
            parts.append("expire=\(expire)")
            parts.append("minimum=\(minimum)")
        }
        
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }
    
    private static func parseDomainNameAt(data: Data, startIndex: inout Int) -> String? {
        var parts: [String] = []
        
        while startIndex < data.count {
            let length = Int(data[startIndex])
            if length == 0 {
                startIndex += 1
                break
            }
            
            startIndex += 1
            guard startIndex + length <= data.count else { break }
            
            let partData = data[startIndex..<(startIndex + length)]
            if let part = String(data: partData, encoding: .utf8) {
                parts.append(part)
            }
            startIndex += length
        }
        
        return parts.isEmpty ? nil : parts.joined(separator: ".")
    }
    
    private static func readUInt32(from data: Data, at index: Int) -> UInt32 {
        return UInt32(data[index]) << 24 |
               UInt32(data[index + 1]) << 16 |
               UInt32(data[index + 2]) << 8 |
               UInt32(data[index + 3])
    }
    
    // MARK: - IP 归属地查询
    
    /// 为 DNS 结果中的 IP 记录查询归属地
    private func fetchIPLocationsForResult(_ result: DNSResult) async -> DNSResult {
        // 提取所有包含 IP 的记录值
        var ipList: [String] = []
        for record in result.records {
            // A 记录和 AAAA 记录的值就是 IP
            if record.typeString == "A" || record.typeString == "AAAA" {
                if IPLocationService.shared.isValidIP(record.value) {
                    ipList.append(record.value)
                }
            } else {
                // 其他记录类型，尝试从值中提取 IP
                if let ip = IPLocationService.shared.extractIP(from: record.value) {
                    ipList.append(ip)
                }
            }
        }
        
        guard !ipList.isEmpty else { return result }
        
        // 批量查询归属地
        let locations = await IPLocationService.shared.fetchLocations(for: ipList)
        
        // 更新记录的归属地信息
        var updatedRecords = result.records
        for i in 0..<updatedRecords.count {
            let record = updatedRecords[i]
            var ip: String? = nil
            
            if record.typeString == "A" || record.typeString == "AAAA" {
                ip = record.value
            } else {
                ip = IPLocationService.shared.extractIP(from: record.value)
            }
            
            if let ip = ip, let location = locations[ip] {
                updatedRecords[i].location = location
            }
        }
        
        return DNSResult(from: result, records: updatedRecords)
    }
    
    // MARK: - 常用 DNS 服务器
    
    static let commonDNSServers: [(String, String)] = [
        ("系统默认", "system"),
        ("Google", "8.8.8.8"),
        ("Cloudflare", "1.1.1.1"),
        ("阿里 DNS", "223.5.5.5"),
        ("腾讯 DNS", "119.29.29.29"),
        ("114 DNS", "114.114.114.114")
    ]
    
    // MARK: - 指定 DNS 服务器查询
    
    /// 使用指定的 DNS 服务器进行查询
    /// - Parameters:
    ///   - domain: 要查询的域名
    ///   - recordType: DNS 记录类型
    ///   - server: DNS 服务器地址（如 "8.8.8.8"）
    func queryWithServer(domain: String, recordType: DNSRecordType = .A, server: String) {
        stopQuery()
        
        // 检查网络连接
        guard isNetworkAvailable else {
            let errorResult = DNSResult(
                domain: domain,
                recordType: recordType,
                records: [],
                latency: 0,
                server: server,
                error: "无网络连接，请检查网络设置后重试",
                timestamp: Date()
            )
            results.insert(errorResult, at: 0)
            saveToHistory(result: errorResult)
            return
        }
        
        // PTR 查询：如果输入是 IP 地址，自动转换为反向域名
        var queryDomain = domain
        if recordType == .PTR && DNSManager.isIPAddress(domain) {
            guard let reverseDomain = DNSManager.ipToReverseDomain(domain) else {
                let errorResult = DNSResult(
                    domain: domain,
                    recordType: recordType,
                    records: [],
                    latency: 0,
                    server: server,
                    error: "无效的 IP 地址格式",
                    timestamp: Date()
                )
                results.insert(errorResult, at: 0)
                saveToHistory(result: errorResult)
                return
            }
            queryDomain = reverseDomain
        }
        
        currentDomain = domain  // 显示原始输入
        isQuerying = true
        startTime = Date()
        
        queryTask = Task {
            var result = await performDNSQueryWithServer(domain: queryDomain, recordType: recordType, server: server)
            
            // PTR 查询结果中保留原始 IP
            if recordType == .PTR && domain != queryDomain {
                result = DNSResult(
                    domain: domain,  // 显示原始 IP
                    recordType: result.recordType,
                    records: result.records,
                    latency: result.latency,
                    server: result.server,
                    error: result.error,
                    timestamp: result.timestamp
                )
            }
            
            result = await fetchIPLocationsForResult(result)
            
            results.insert(result, at: 0)
            
            if results.count > 50 {
                results.removeLast()
            }
            
            saveToHistory(result: result)
            isQuerying = false
        }
    }
    
    /// 使用 UDP 向指定 DNS 服务器发送查询
    private func performDNSQueryWithServer(domain: String, recordType: DNSRecordType, server: String) async -> DNSResult {
        let startTime = Date()
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var records: [DNSRecord] = []
                var queryError: String? = nil
                
                // 创建 UDP socket
                let sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
                guard sock >= 0 else {
                    let result = DNSResult(
                        domain: domain,
                        recordType: recordType,
                        records: [],
                        latency: Date().timeIntervalSince(startTime),
                        server: server,
                        error: "创建 socket 失败",
                        timestamp: Date()
                    )
                    continuation.resume(returning: result)
                    return
                }
                
                defer { close(sock) }
                
                // 设置超时
                var timeout = timeval(tv_sec: 5, tv_usec: 0)
                setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
                
                // 配置服务器地址
                var serverAddr = sockaddr_in()
                serverAddr.sin_family = sa_family_t(AF_INET)
                serverAddr.sin_port = UInt16(53).bigEndian
                inet_pton(AF_INET, server, &serverAddr.sin_addr)
                
                // 构建 DNS 查询包
                let queryPacket = DNSManager.buildDNSQuery(domain: domain, recordType: recordType)
                
                // 发送查询
                let sendResult = withUnsafePointer(to: &serverAddr) { ptr in
                    ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                        sendto(sock, queryPacket, queryPacket.count, 0, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
                    }
                }
                
                guard sendResult > 0 else {
                    let result = DNSResult(
                        domain: domain,
                        recordType: recordType,
                        records: [],
                        latency: Date().timeIntervalSince(startTime),
                        server: server,
                        error: "发送查询失败",
                        timestamp: Date()
                    )
                    continuation.resume(returning: result)
                    return
                }
                
                // 接收响应
                var buffer = [UInt8](repeating: 0, count: 512)
                let recvLen = recv(sock, &buffer, buffer.count, 0)
                
                if recvLen > 0 {
                    // 解析 DNS 响应
                    let responseData = Data(buffer[0..<recvLen])
                    records = DNSManager.parseDNSResponse(data: responseData, domain: domain, recordType: recordType)
                    
                    if records.isEmpty {
                        queryError = "未找到 \(recordType.rawValue) 记录"
                    }
                } else {
                    queryError = "查询超时"
                }
                
                let latency = Date().timeIntervalSince(startTime)
                
                let dnsResult = DNSResult(
                    domain: domain,
                    recordType: recordType,
                    records: records,
                    latency: latency,
                    server: server,
                    error: queryError,
                    timestamp: Date()
                )
                
                continuation.resume(returning: dnsResult)
            }
        }
    }
    
    // MARK: - DNS 包构建
    
    /// 构建 DNS 查询包
    private static func buildDNSQuery(domain: String, recordType: DNSRecordType) -> [UInt8] {
        var packet = [UInt8]()
        
        // Transaction ID (2 bytes) - 随机
        let transactionId = UInt16.random(in: 0...UInt16.max)
        packet.append(UInt8(transactionId >> 8))
        packet.append(UInt8(transactionId & 0xFF))
        
        // Flags (2 bytes) - 标准查询，递归请求
        packet.append(0x01)  // QR=0, Opcode=0, AA=0, TC=0, RD=1
        packet.append(0x00)  // RA=0, Z=0, RCODE=0
        
        // Questions (2 bytes) - 1 个问题
        packet.append(0x00)
        packet.append(0x01)
        
        // Answer RRs (2 bytes) - 0
        packet.append(0x00)
        packet.append(0x00)
        
        // Authority RRs (2 bytes) - 0
        packet.append(0x00)
        packet.append(0x00)
        
        // Additional RRs (2 bytes) - 0
        packet.append(0x00)
        packet.append(0x00)
        
        // Question section - 域名
        let labels = domain.split(separator: ".")
        for label in labels {
            packet.append(UInt8(label.count))
            packet.append(contentsOf: label.utf8)
        }
        packet.append(0x00)  // 域名结束
        
        // QTYPE (2 bytes)
        let qtype = recordType.dnssdType
        packet.append(UInt8(qtype >> 8))
        packet.append(UInt8(qtype & 0xFF))
        
        // QCLASS (2 bytes) - IN (Internet)
        packet.append(0x00)
        packet.append(0x01)
        
        return packet
    }
    
    // MARK: - DNS 响应解析
    
    /// 解析 DNS 响应包
    private static func parseDNSResponse(data: Data, domain: String, recordType: DNSRecordType) -> [DNSRecord] {
        var records: [DNSRecord] = []
        
        guard data.count >= 12 else { return records }
        
        // 解析头部
        let answerCount = UInt16(data[6]) << 8 | UInt16(data[7])
        
        guard answerCount > 0 else { return records }
        
        // 跳过头部 (12 bytes) 和问题部分
        var offset = 12
        
        // 跳过问题部分
        while offset < data.count && data[offset] != 0 {
            let labelLen = Int(data[offset])
            offset += 1 + labelLen
        }
        offset += 1  // 跳过结束的 0
        offset += 4  // 跳过 QTYPE 和 QCLASS
        
        // 解析答案部分
        var isFirst = true
        for _ in 0..<answerCount {
            guard offset + 12 <= data.count else { break }
            
            // 解析名称（可能是压缩指针）
            let (name, nameEndOffset) = parseName(data: data, offset: offset)
            offset = nameEndOffset
            
            guard offset + 10 <= data.count else { break }
            
            // TYPE (2 bytes)
            let rrType = UInt16(data[offset]) << 8 | UInt16(data[offset + 1])
            offset += 2
            
            // CLASS (2 bytes)
            offset += 2
            
            // TTL (4 bytes)
            let ttl = UInt32(data[offset]) << 24 | UInt32(data[offset + 1]) << 16 |
                      UInt32(data[offset + 2]) << 8 | UInt32(data[offset + 3])
            offset += 4
            
            // RDLENGTH (2 bytes)
            let rdLength = Int(UInt16(data[offset]) << 8 | UInt16(data[offset + 1]))
            offset += 2
            
            guard offset + rdLength <= data.count else { break }
            
            // RDATA
            let rdata = data[offset..<(offset + rdLength)]
            offset += rdLength
            
            // 解析记录值
            let typeString = rrTypeToString(rrType)
            var value: String
            
            switch rrType {
            case UInt16(kDNSServiceType_A):
                // IPv4
                guard rdata.count >= 4 else { continue }
                value = rdata.prefix(4).map { String($0) }.joined(separator: ".")
                
            case UInt16(kDNSServiceType_AAAA):
                // IPv6
                guard rdata.count >= 16 else { continue }
                var parts: [String] = []
                for i in stride(from: 0, to: 16, by: 2) {
                    let idx = rdata.startIndex.advanced(by: i)
                    let v = UInt16(rdata[idx]) << 8 | UInt16(rdata[idx.advanced(by: 1)])
                    parts.append(String(format: "%x", v))
                }
                value = parts.joined(separator: ":")
                
            case UInt16(kDNSServiceType_CNAME), UInt16(kDNSServiceType_NS), UInt16(kDNSServiceType_PTR):
                // 域名
                let (parsedName, _) = parseName(data: data, offset: offset - rdLength)
                value = parsedName ?? "(无法解析)"
                
            case UInt16(kDNSServiceType_MX):
                // MX: 优先级 + 域名
                guard rdata.count > 2 else { continue }
                let priority = UInt16(rdata[rdata.startIndex]) << 8 | UInt16(rdata[rdata.startIndex.advanced(by: 1)])
                let (mxName, _) = parseName(data: data, offset: offset - rdLength + 2)
                value = "\(priority) \(mxName ?? "(无法解析)")"
                
            case UInt16(kDNSServiceType_TXT):
                // TXT
                value = parseRData(type: rrType, data: Data(rdata)) ?? "(无法解析)"
                
            default:
                value = Data(rdata).map { String(format: "%02x", $0) }.joined(separator: " ")
            }
            
            let record = DNSRecord(
                name: name ?? domain,
                type: rrType,
                typeString: typeString,
                ttl: ttl,
                value: value,
                rawData: Data(rdata),
                isPrimary: isFirst
            )
            records.append(record)
            isFirst = false
        }
        
        return records
    }
    
    /// 解析 DNS 名称（支持压缩指针）
    private static func parseName(data: Data, offset: Int) -> (String?, Int) {
        var parts: [String] = []
        var currentOffset = offset
        var jumped = false
        var jumpOffset = offset
        
        while currentOffset < data.count {
            let length = Int(data[currentOffset])
            
            if length == 0 {
                if !jumped {
                    jumpOffset = currentOffset + 1
                }
                break
            }
            
            // 检查是否是压缩指针
            if (length & 0xC0) == 0xC0 {
                guard currentOffset + 1 < data.count else { break }
                let pointer = Int(length & 0x3F) << 8 | Int(data[currentOffset + 1])
                if !jumped {
                    jumpOffset = currentOffset + 2
                }
                jumped = true
                currentOffset = pointer
                continue
            }
            
            currentOffset += 1
            guard currentOffset + length <= data.count else { break }
            
            let labelData = data[currentOffset..<(currentOffset + length)]
            if let label = String(data: labelData, encoding: .utf8) {
                parts.append(label)
            }
            currentOffset += length
        }
        
        return (parts.isEmpty ? nil : parts.joined(separator: "."), jumped ? jumpOffset : currentOffset + 1)
    }

}

// MARK: - DNSRecordType 扩展

extension DNSRecordType {
    var dnssdType: UInt16 {
        switch self {
        case .systemDefault: return UInt16(kDNSServiceType_A)  // 系统默认不使用此值
        case .A:     return UInt16(kDNSServiceType_A)
        case .AAAA:  return UInt16(kDNSServiceType_AAAA)
        case .CNAME: return UInt16(kDNSServiceType_CNAME)
        case .MX:    return UInt16(kDNSServiceType_MX)
        case .TXT:   return UInt16(kDNSServiceType_TXT)
        case .NS:    return UInt16(kDNSServiceType_NS)
        case .PTR:   return UInt16(kDNSServiceType_PTR)
        }
    }
}
