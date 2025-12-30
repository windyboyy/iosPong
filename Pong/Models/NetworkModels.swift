//
//  NetworkModels.swift
//  Pong
//
//  Created by 张金琛 on 2025/12/12.
//

import Foundation

// MARK: - Ping 结果模型
struct PingResult: Identifiable {
    let id = UUID()
    let sequence: Int
    let host: String
    let ip: String
    let latency: TimeInterval?
    let status: PingStatus
    let timestamp: Date
    
    enum PingStatus {
        case success
        case timeout
        case error(String)
    }
    
    var statusText: String {
        switch status {
        case .success:
            if let latency = latency {
                return String(format: "%.1f ms", latency * 1000)
            }
            return "成功"
        case .timeout:
            return "超时"
        case .error(let msg):
            return msg
        }
    }
}

// MARK: - Ping 统计
struct PingStatistics {
    var sent: Int = 0
    var received: Int = 0
    var lost: Int = 0
    var minLatency: TimeInterval = .infinity
    var maxLatency: TimeInterval = 0
    var totalLatency: TimeInterval = 0
    var latencies: [TimeInterval] = []  // 保存所有延迟用于计算 stddev
    
    var lossRate: Double {
        sent > 0 ? Double(lost) / Double(sent) * 100 : 0
    }
    
    var avgLatency: TimeInterval {
        received > 0 ? totalLatency / Double(received) : 0
    }
    
    var stddevLatency: TimeInterval {
        guard latencies.count > 1 else { return 0 }
        let avg = avgLatency
        let variance = latencies.reduce(0) { $0 + pow($1 - avg, 2) } / Double(latencies.count)
        return sqrt(variance)
    }
}

// MARK: - Traceroute 跳点模型
struct TraceHop: Identifiable {
    let id = UUID()
    let hop: Int
    let ip: String
    var hostname: String?  // PTR 主机名（批量异步解析）
    let latencies: [TimeInterval?]  // 所有探测的延迟
    let status: HopStatus
    var location: String?  // IP 归属地
    
    enum HopStatus {
        case success
        case timeout
        case error(String)
    }
    
    // 成功收到响应的次数
    var receivedCount: Int {
        latencies.compactMap { $0 }.count
    }
    
    // 发送的包数
    var sentCount: Int {
        latencies.count
    }
    
    // 丢包率 (0-100)
    var lossRate: Double {
        guard sentCount > 0 else { return 0 }
        return Double(sentCount - receivedCount) / Double(sentCount) * 100
    }
    
    var avgLatency: TimeInterval? {
        let validLatencies = latencies.compactMap { $0 }
        guard !validLatencies.isEmpty else { return nil }
        return validLatencies.reduce(0, +) / Double(validLatencies.count)
    }
    
    var minLatency: TimeInterval? {
        latencies.compactMap { $0 }.min()
    }
    
    var maxLatency: TimeInterval? {
        latencies.compactMap { $0 }.max()
    }
}

// MARK: - TCP 连接结果
struct TCPResult: Identifiable {
    let id = UUID()
    let host: String
    let port: UInt16
    let isOpen: Bool
    let latency: TimeInterval?
    let error: String?
    let timestamp: Date
}

// MARK: - UDP 测试结果
struct UDPResult: Identifiable {
    let id = UUID()
    let host: String
    let port: UInt16
    let sent: Bool
    let received: Bool
    let latency: TimeInterval?
    let error: String?
    let timestamp: Date
}

// MARK: - DNS 查询结果
struct DNSResult: Identifiable {
    let id: UUID
    let domain: String
    let recordType: DNSRecordType
    let records: [DNSRecord]
    let latency: TimeInterval
    let server: String?
    let error: String?
    let timestamp: Date
    
    init(domain: String, recordType: DNSRecordType, records: [DNSRecord], latency: TimeInterval, server: String?, error: String?, timestamp: Date) {
        self.id = UUID()
        self.domain = domain
        self.recordType = recordType
        self.records = records
        self.latency = latency
        self.server = server
        self.error = error
        self.timestamp = timestamp
    }
    
    /// 创建带有更新记录的新结果（保持原始 ID）
    init(from original: DNSResult, records: [DNSRecord]) {
        self.id = original.id
        self.domain = original.domain
        self.recordType = original.recordType
        self.records = records
        self.latency = original.latency
        self.server = original.server
        self.error = original.error
        self.timestamp = original.timestamp
    }
    
    // dig 风格的完整输出
    func digStyleOutput() -> String {
        var lines: [String] = []
        
        // Header
        lines.append("; <<>> Pong DNS <<>> \(domain)")
        lines.append(";; Got answer:")
        
        let status = error == nil ? "NOERROR" : "ERROR"
        let answerCount = records.count
        lines.append(";; ->>HEADER<<- opcode: QUERY, status: \(status), id: \(id.hashValue & 0xFFFF)")
        lines.append(";; flags: qr rd ra; QUERY: 1, ANSWER: \(answerCount), AUTHORITY: 0, ADDITIONAL: 0")
        lines.append("")
        
        // Question Section
        lines.append(";; QUESTION SECTION:")
        lines.append(";\(domain).\t\t\tIN\t\(recordType.displayName)")
        lines.append("")
        
        // Answer Section
        if !records.isEmpty {
            lines.append(";; ANSWER SECTION:")
            for record in records {
                lines.append(record.digLine)
            }
            lines.append("")
        }
        
        // Footer
        lines.append(String(format: ";; Query time: %.0f msec", latency * 1000))
        lines.append(";; SERVER: \(server ?? "unknown")")
        
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE MMM dd HH:mm:ss zzz yyyy"
        lines.append(";; WHEN: \(formatter.string(from: timestamp))")
        
        return lines.joined(separator: "\n")
    }
}

// DNS 单条记录
struct DNSRecord: Identifiable {
    let id = UUID()
    let name: String?         // 记录名称
    let type: UInt16          // 记录类型（原始值）
    let typeString: String    // 记录类型（字符串）
    let ttl: UInt32?          // TTL
    let rdclass: String       // 类别 (IN)
    let value: String         // 解析后的值
    let rawData: Data         // 原始 rdata
    var location: String?     // IP 归属地
    var isPrimary: Bool       // 是否为优先解析（第一条记录）
    
    init(name: String?, type: UInt16, typeString: String, ttl: UInt32?, value: String, rawData: Data, location: String? = nil, isPrimary: Bool = false) {
        self.name = name
        self.type = type
        self.typeString = typeString
        self.ttl = ttl
        self.rdclass = "IN"
        self.value = value
        self.rawData = rawData
        self.location = location
        self.isPrimary = isPrimary
    }
    
    // dig 风格的单行输出: name. TTL IN TYPE value
    var digLine: String {
        let nameStr = (name ?? ".") + (name?.hasSuffix(".") == true ? "" : ".")
        let ttlStr = ttl.map { String($0) } ?? "0"
        return "\(nameStr)\t\(ttlStr)\t\(rdclass)\t\(typeString)\t\(value)"
    }
    
    /// 带归属地的显示值
    var displayValue: String {
        var result = value
        if let loc = location, !loc.isEmpty {
            result += " (\(loc))"
        }
        return result
    }
    
    /// 带优先标记和归属地的完整显示值
    var fullDisplayValue: String {
        var result = value
        if isPrimary {
            result += " *优先"
        }
        if let loc = location, !loc.isEmpty {
            result += " (\(loc))"
        }
        return result
    }
    
    // 原始数据的十六进制表示
    var rawDataHex: String {
        rawData.map { String(format: "%02x", $0) }.joined(separator: " ")
    }
}

enum DNSRecordType: String, CaseIterable {
    case systemDefault = "系统默认"  // 系统默认解析（返回所有记录）
    case A = "A"
    case AAAA = "AAAA"
    case CNAME = "CNAME"
    case MX = "MX"
    case TXT = "TXT"
    case NS = "NS"
    case PTR = "PTR"  // 反向 DNS 查询
    
    /// 显示名称
    var displayName: String {
        switch self {
        case .systemDefault:
            return L10n.shared.systemDefault
        default:
            return self.rawValue
        }
    }
}

// MARK: - 网络请求记录模型
struct NetworkLog: Identifiable {
    let id = UUID()
    let timestamp: Date
    let method: String
    let url: String
    let statusCode: Int?
    let responseSize: Int?
    let duration: TimeInterval?
}
