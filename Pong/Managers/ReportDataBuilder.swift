//
//  ReportDataBuilder.swift
//  Pong
//
//  Created by AI Assistant on 2025/12/25.
//
//  统一的上报数据构建器，用于一键诊断和历史记录上报

import Foundation
import UIKit

// MARK: - 上报数据构建器
struct ReportDataBuilder {
    
    // MARK: - 上报来源
    enum ReportSource {
        case diagnosis(uniqueKey: String, reportId: Int)  // 一键诊断
        case history                                       // 历史记录
        
        var localRecordType: String {
            switch self {
            case .diagnosis: return "diagnosis"
            case .history: return "history"
            }
        }
    }
    
    // MARK: - 构建基础字段
    static func buildBaseData(
        target: String,
        msmType: String,
        source: ReportSource,
        timestamp: Date,
        duration: TimeInterval?,
        errorMessage: String?,
        ipInfo: IPInfoResponse?,
        useIPv6: Bool = false
    ) -> [String: Any] {
        let localTimeStr = formatLocalTime(timestamp)
        
        let utcFormatter = ISO8601DateFormatter()
        utcFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        utcFormatter.timeZone = TimeZone(identifier: "UTC")
        let utcTimeStr = utcFormatter.string(from: timestamp)
        
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let userId = UserManager.shared.currentUser?.userId ?? 0
        let deviceInfo = DeviceInfoManager.shared.deviceInfo
        let networkStatus = DeviceInfoManager.shared.networkStatus
        
        // 计算执行时长
        let durationNano = Int64((duration ?? 0) * 1_000_000_000)
        let durationSeconds = Int(duration ?? 0)
        let durationStr = "\(durationSeconds)s"
        
        // 根据来源设置不同的字段
        let exampleUniqueKey: String
        let exampleReportId: Int
        let agentPublicIP: String
        
        switch source {
        case .diagnosis(let uniqueKey, let reportId):
            exampleUniqueKey = uniqueKey
            exampleReportId = reportId
            agentPublicIP = ipInfo?.ip ?? ""
        case .history:
            exampleUniqueKey = ""
            exampleReportId = 0
            agentPublicIP = ipInfo?.ip ?? ""
        }
        
        var data: [String: Any] = [
            "ExampleUniqueKey": exampleUniqueKey,
            "ExampleReportId": exampleReportId,
            "LocalDeviceType": "iOS",
            "LocalDeviceName": deviceInfo?.deviceName ?? "",
            "LocalDeviceModel": deviceInfo?.deviceModel ?? "",
            "LocalDeviceIdentifier": deviceInfo?.deviceIdentifier ?? "",
            "LocalSystemVersion": deviceInfo?.systemFullName ?? "",
            "LocalNetwork": networkStatus.displayName,
            "LocalRecordType": source.localRecordType,
            "LocalExecTime": localTimeStr,
            "Addr": target,
            "BuildinAf": useIPv6 ? "6" : "4",
            "BuildinAgentId": "",
            "BuildinAgentVersion": appVersion,
            "BuildinDurationNano": durationNano,
            "BuildinErrMessage": errorMessage ?? "",
            "BuildinExcMode": "once",
            "BuildinFinishTimestampMilli": Int64(timestamp.timeIntervalSince1970 * 1000),
            "BuildinId": -1,
            "BuildinIntervalDuration": durationStr,
            "BuildinLocalTime": localTimeStr,
            "BuildinMainTaskSetId": -1,
            "BuildinPeerIP": "",
            "BuildinSource": "app",
            "BuildinSubTaskSetId": -1,
            "BuildinTargetHost": target,
            "BuildinTaskKey": "",
            "BuildinTimestampMilli": Int64(timestamp.timeIntervalSince1970 * 1000),
            "BuildinUserId": userId,
            "BuildinUtcTime": utcTimeStr,
            "LocalIPAddress": deviceInfo?.localIPAddress ?? "",
            "LocalIPv6Address": deviceInfo?.localIPv6Address ?? "",
            "MsmType": msmType
        ]
        
        // 一键诊断额外字段
        if case .diagnosis = source {
            data["BuildinAgentRemoteIP"] = ""
            data["BuildinAgentPublicIP"] = agentPublicIP
        }
        
        return data
    }
    
    // MARK: - 格式化本地时间
    static func formatLocalTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }
    
    // MARK: - 判断是否为 IPv6 相关错误
    private static func isIPv6Error(_ error: String?) -> Bool {
        guard let error = error else { return false }
        return error.contains("IPv6") || error.contains("ipv6")
    }
    
    // MARK: - 构建 Ping 上报数据
    static func buildPingData(
        target: String,
        packetSize: Int,
        count: Int,
        successCount: Int,
        avgLatency: TimeInterval?,      // 秒
        minLatency: TimeInterval?,      // 秒
        maxLatency: TimeInterval?,      // 秒
        stdDev: TimeInterval?,          // 秒
        lossRate: Double,
        results: [(sequence: Int, success: Bool, latency: TimeInterval?)],
        resolvedIP: String?,
        source: ReportSource,
        timestamp: Date,
        duration: TimeInterval?,
        errorMessage: String?,
        ipInfo: IPInfoResponse?,
        useIPv6: Bool = false
    ) -> [String: Any] {
        var data = buildBaseData(
            target: target,
            msmType: "ping",
            source: source,
            timestamp: timestamp,
            duration: duration,
            errorMessage: errorMessage,
            ipInfo: ipInfo,
            useIPv6: useIPv6
        )
        
        // 延迟转换为微秒
        let avgMicro = (avgLatency ?? 0) * 1_000_000
        let minMicro = (minLatency ?? 0) * 1_000_000
        let maxMicro = (maxLatency ?? 0) * 1_000_000
        let stdDevMicro = (stdDev ?? 0) * 1_000_000
        
        // RTTs 数组
        let rttsMicro = results.map { result -> Double in
            if let latency = result.latency {
                return latency * 1_000_000
            }
            return -1
        }
        
        let rttsMilli = results.map { result -> Double in
            if let latency = result.latency {
                return latency * 1000
            }
            return -1
        }
        
        // 结果文本
        let resultText = buildPingResultText(
            target: target,
            packetSize: packetSize,
            count: count,
            successCount: successCount,
            avgLatency: avgLatency,
            minLatency: minLatency,
            maxLatency: maxLatency,
            lossRate: lossRate,
            results: results,
            resolvedIP: resolvedIP,
            errorMessage: errorMessage
        )
        
        let ip = resolvedIP ?? ""
        
        data["AvgRttMicro"] = avgMicro
        data["MaxRttMicro"] = maxMicro
        data["MinRttMicro"] = minMicro
        data["StdDevRttMicro"] = stdDevMicro
        data["PacketsSent"] = count
        data["PacketsRecv"] = successCount
        data["PacketLoss"] = lossRate
        data["RttsMicro"] = rttsMicro
        data["RttsMilli"] = rttsMilli
        data["Cname"] = ""
        data["IPAddr"] = ip
        data["BuildinPeerIP"] = ip
        data["Network"] = useIPv6 ? "ip6" : "ip"
        data["ResultToText"] = resultText
        
        return data
    }
    
    // MARK: - 构建 Ping 结果文本
    private static func buildPingResultText(
        target: String,
        packetSize: Int,
        count: Int,
        successCount: Int,
        avgLatency: TimeInterval?,
        minLatency: TimeInterval?,
        maxLatency: TimeInterval?,
        lossRate: Double,
        results: [(sequence: Int, success: Bool, latency: TimeInterval?)],
        resolvedIP: String?,
        errorMessage: String?
    ) -> String {
        var lines: [String] = []
        let ip = resolvedIP ?? target
        
        // 如果是 IPv6 错误，优先显示错误信息
        if isIPv6Error(errorMessage) {
            lines.append("PING \(target) (\(ip)): \(packetSize) data bytes")
            lines.append("")
            lines.append("错误: \(errorMessage!)")
            lines.append("")
            lines.append("--- \(target) ping statistics ---")
            lines.append("0 packets transmitted, 0 packets received, 100.0% packet loss")
            return lines.joined(separator: "\n")
        }
        
        lines.append("PING \(target) (\(ip)): \(packetSize) data bytes")
        
        for result in results {
            if result.success, let latency = result.latency {
                lines.append("\(packetSize) bytes from \(ip): icmp_seq=\(result.sequence) time=\(String(format: "%.3f", latency * 1000)) ms")
            } else {
                lines.append("Request timeout for icmp_seq \(result.sequence)")
            }
        }
        
        lines.append("")
        lines.append("--- \(target) ping statistics ---")
        lines.append("\(count) packets transmitted, \(successCount) packets received, \(String(format: "%.1f", lossRate))% packet loss")
        
        if let avg = avgLatency, let min = minLatency, let max = maxLatency {
            lines.append("round-trip min/avg/max = \(String(format: "%.3f", min * 1000))/\(String(format: "%.3f", avg * 1000))/\(String(format: "%.3f", max * 1000)) ms")
        }
        
        return lines.joined(separator: "\n")
    }
    
    // MARK: - 构建 TCP 上报数据（单端口）
    static func buildTCPData(
        target: String,
        port: UInt16,
        isOpen: Bool,
        latency: TimeInterval?,         // 秒（平均延迟）
        count: Int = 1,                 // 测试次数
        successCount: Int? = nil,       // 成功次数
        failedCount: Int? = nil,        // 失败次数
        source: ReportSource,
        timestamp: Date,
        duration: TimeInterval?,
        errorMessage: String?,
        ipInfo: IPInfoResponse?,
        useIPv6: Bool = false
    ) -> [String: Any] {
        let targetWithPort = "\(target):\(port)"
        var data = buildBaseData(
            target: targetWithPort,
            msmType: "tcp_port",
            source: source,
            timestamp: timestamp,
            duration: duration,
            errorMessage: errorMessage,
            ipInfo: ipInfo,
            useIPv6: useIPv6
        )
        
        let latencyMilli = (latency ?? 0) * 1000
        let latencyMicro = latencyMilli * 1000
        
        // 计算实际的成功/失败次数
        let actualSuccessCount = successCount ?? (isOpen ? 1 : 0)
        let actualFailedCount = failedCount ?? (isOpen ? 0 : 1)
        let packetLoss: Double = count > 0 ? Double(actualFailedCount) / Double(count) * 100 : (isOpen ? 0 : 100)
        
        // 构建结果文本
        var resultText: String
        
        // 如果是 IPv6 错误，优先显示错误信息
        if isIPv6Error(errorMessage) {
            resultText = "UDP Test to \(target):\(port)\n"
            resultText += "错误: \(errorMessage!)\n"
            resultText += "状态: 无法测试（当前网络无 IPv6）"
        } else if count > 1 {
            resultText = "TCP Connect to \(target):\(port)\n"
            resultText += "测试次数: \(count), 成功: \(actualSuccessCount), 失败: \(actualFailedCount)\n"
            if isOpen {
                resultText += "端口状态: 开放，平均延迟 \(String(format: "%.3f", latencyMilli)) ms\n"
            } else {
                resultText += "端口状态: 关闭\n"
            }
            resultText += "丢包率: \(String(format: "%.1f", packetLoss))%"
        } else {
            resultText = isOpen
                ? "端口 \(port) 开放，延迟 \(String(format: "%.3f", latencyMilli)) ms"
                : "端口 \(port) 关闭"
        }
        
        var rttsMicro: [Double] = []
        var rttsMilli: [Double] = []
        if isOpen, let lat = latency {
            rttsMicro.append(lat * 1_000_000)
            rttsMilli.append(lat * 1000)
        }
        
        data["AvgRttMicro"] = isOpen ? round(latencyMicro * 100) / 100 : 0
        data["AvgRttMilli"] = isOpen ? round(latencyMilli * 100) / 100 : 0
        data["MaxRttMicro"] = isOpen ? round(latencyMicro * 100) / 100 : 0
        data["MaxRttMilli"] = isOpen ? round(latencyMilli * 100) / 100 : 0
        data["MinRttMicro"] = isOpen ? round(latencyMicro * 100) / 100 : 0
        data["MinRttMilli"] = isOpen ? round(latencyMilli * 100) / 100 : 0
        data["Network"] = useIPv6 ? "tcp6" : "tcp4"
        data["PacketLoss"] = packetLoss
        data["PacketsRecv"] = actualSuccessCount
        data["PacketsSent"] = count
        data["RemotePort"] = "\(port)"
        data["RttsMicro"] = rttsMicro.map { round($0 * 100) / 100 }
        data["RttsMicroMilli"] = rttsMilli.map { round($0 * 100) / 100 }
        data["StdDevRttMicro"] = 0
        data["ResultToText"] = resultText
        data["BuildinPeerIP"] = target
        
        return data
    }
    
    // MARK: - 构建 TCP 批量扫描上报数据
    static func buildTCPBatchData(
        target: String,
        portResults: [(port: Int, serviceName: String?, isOpen: Bool, latency: Double?)],  // latency 毫秒
        source: ReportSource,
        timestamp: Date,
        duration: TimeInterval?,
        errorMessage: String?,
        ipInfo: IPInfoResponse?,
        useIPv6: Bool = false
    ) -> [String: Any] {
        var data = buildBaseData(
            target: target,
            msmType: "tcp_port",
            source: source,
            timestamp: timestamp,
            duration: duration,
            errorMessage: errorMessage,
            ipInfo: ipInfo,
            useIPv6: useIPv6
        )
        
        let openCount = portResults.filter { $0.isOpen }.count
        let totalCount = portResults.count
        
        // 构建详细的结果文本
        var resultLines: [String] = []
        resultLines.append("TCP Port Scan: \(target)")
        resultLines.append("")
        
        // 如果是 IPv6 错误，优先显示错误信息
        if isIPv6Error(errorMessage) {
            resultLines.append("错误: \(errorMessage!)")
            resultLines.append("")
            resultLines.append("无法进行端口扫描（当前网络无 IPv6）")
        } else {
            for portDetail in portResults {
                let serviceName = portDetail.serviceName ?? ""
                let status = portDetail.isOpen ? "开放" : "关闭"
                var line = "Port \(portDetail.port)"
                if !serviceName.isEmpty {
                    line += " (\(serviceName))"
                }
                line += ": \(status)"
                if let latency = portDetail.latency, portDetail.isOpen {
                    line += " - \(String(format: "%.1fms", latency))"
                }
                resultLines.append(line)
            }
            
            resultLines.append("")
            resultLines.append("Summary: \(openCount)/\(totalCount) ports open")
        }
        
        let resultText = resultLines.joined(separator: "\n")
        
        // 计算统计数据
        let openPorts = portResults.filter { $0.isOpen }
        let latencies = openPorts.compactMap { $0.latency }
        let avgLatency = latencies.isEmpty ? 0 : latencies.reduce(0, +) / Double(latencies.count)
        let minLatency = latencies.min() ?? 0
        let maxLatency = latencies.max() ?? 0
        
        // RTT 数组（仅开放端口）
        let rttsMilli = latencies
        let rttsMicro = rttsMilli.map { $0 * 1000 }
        
        // 端口列表
        let portList = portResults.map { "\($0.port)" }.joined(separator: ",")
        
        data["MaxRttMicro"] = round(maxLatency * 1000 * 100) / 100
        data["MaxRttMilli"] = round(maxLatency * 100) / 100
        data["MinRttMicro"] = round(minLatency * 1000 * 100) / 100
        data["MinRttMilli"] = round(minLatency * 100) / 100
        data["AvgRttMicro"] = round(avgLatency * 1000 * 100) / 100
        data["AvgRttMilli"] = round(avgLatency * 100) / 100
        data["Network"] = useIPv6 ? "tcp6" : "tcp4"
        data["PacketLoss"] = Double(totalCount - openCount) / Double(totalCount) * 100
        data["PacketsRecv"] = openCount
        data["PacketsSent"] = totalCount
        data["RemotePort"] = portList
        data["RttsMicro"] = rttsMicro.map { round($0 * 100) / 100 }
        data["RttsMicroMilli"] = rttsMilli.map { round($0 * 100) / 100 }
        data["StdDevRttMicro"] = 0
        data["ResultToText"] = resultText
        data["BuildinPeerIP"] = target
        data["ScanMode"] = "batch"
        data["OpenCount"] = openCount
        data["TotalCount"] = totalCount
        
        return data
    }
    
    // MARK: - 构建 UDP 上报数据
    static func buildUDPData(
        target: String,
        port: UInt16,
        sent: Bool,
        received: Bool,
        latency: TimeInterval?,         // 秒（平均延迟）
        count: Int = 1,                 // 测试次数
        successCount: Int? = nil,       // 成功次数（收到响应）
        failedCount: Int? = nil,        // 失败次数
        source: ReportSource,
        timestamp: Date,
        duration: TimeInterval?,
        errorMessage: String?,
        ipInfo: IPInfoResponse?,
        useIPv6: Bool = false
    ) -> [String: Any] {
        var data = buildBaseData(
            target: target,
            msmType: "udp_port",
            source: source,
            timestamp: timestamp,
            duration: duration,
            errorMessage: errorMessage,
            ipInfo: ipInfo,
            useIPv6: useIPv6
        )
        
        let latencyMilli = (latency ?? 0) * 1000
        let latencyMicro = latencyMilli * 1000
        
        // 计算实际的成功/失败次数
        let actualSuccessCount = successCount ?? (received ? 1 : 0)
        let actualFailedCount = failedCount ?? (received ? 0 : 1)
        let packetLoss: Double = count > 0 ? Double(actualFailedCount) / Double(count) * 100 : (received ? 0 : 100)
        
        // 构建结果文本
        var resultText: String
        
        // 如果是 IPv6 错误，优先显示错误信息
        if isIPv6Error(errorMessage) {
            resultText = "UDP Test to \(target):\(port)\n"
            resultText += "错误: \(errorMessage!)\n"
            resultText += "状态: 无法测试（当前网络无 IPv6）"
        } else if count > 1 {
            resultText = "UDP Test to \(target):\(port)\n"
            resultText += "测试次数: \(count), 成功: \(actualSuccessCount), 失败: \(actualFailedCount)\n"
            if received {
                resultText += "状态: 可达，平均延迟 \(String(format: "%.3f", latencyMilli)) ms\n"
            } else if sent {
                resultText += "状态: 已发送，无响应\n"
            } else {
                resultText += "状态: 发送失败\n"
            }
            resultText += "丢包率: \(String(format: "%.1f", packetLoss))%"
        } else {
            resultText = "UDP 端口 \(port): "
            if sent && received {
                resultText += "可达，延迟 \(String(format: "%.3f", latencyMilli)) ms"
            } else if sent {
                resultText += "已发送，无响应"
            } else {
                resultText += "发送失败"
            }
        }
        
        var rttsMicro: [Double] = []
        var rttsMilli: [Double] = []
        if received, latencyMilli > 0 {
            rttsMicro.append(latencyMicro)
            rttsMilli.append(latencyMilli)
        }
        
        data["AvgRttMicro"] = received ? round(latencyMicro * 100) / 100 : 0
        data["AvgRttMilli"] = received ? round(latencyMilli * 100) / 100 : 0
        data["MaxRttMicro"] = received ? round(latencyMicro * 100) / 100 : 0
        data["MaxRttMilli"] = received ? round(latencyMilli * 100) / 100 : 0
        data["MinRttMicro"] = received ? round(latencyMicro * 100) / 100 : 0
        data["MinRttMilli"] = received ? round(latencyMilli * 100) / 100 : 0
        data["Network"] = useIPv6 ? "udp6" : "udp4"
        data["PacketLoss"] = packetLoss
        data["PacketsRecv"] = actualSuccessCount
        data["PacketsSent"] = count
        data["RecvDataLen"] = received ? 1 : 0
        data["RemotePort"] = Int(port)
        data["RttsMicro"] = rttsMicro.map { round($0 * 100) / 100 }
        data["RttsMicroMilli"] = rttsMilli.map { round($0 * 100) / 100 }
        data["StdDevRttMicro"] = 0
        data["ResultToText"] = resultText
        data["BuildinPeerIP"] = target
        
        return data
    }
    
    // MARK: - 构建 DNS 上报数据
    static func buildDNSData(
        domain: String,
        recordType: String,
        records: [String],
        recordDetails: [(name: String?, type: String, ttl: UInt32?, value: String)]?,
        latency: TimeInterval,          // 秒
        server: String?,
        digOutput: String?,
        source: ReportSource,
        timestamp: Date,
        duration: TimeInterval?,
        errorMessage: String?,
        ipInfo: IPInfoResponse?
    ) -> [String: Any] {
        var data = buildBaseData(
            target: domain,
            msmType: "dns",
            source: source,
            timestamp: timestamp,
            duration: duration,
            errorMessage: errorMessage,
            ipInfo: ipInfo
        )
        
        let latencyMicro = latency * 1_000_000
        
        // 构建 dig 风格的详细结果文本
        let resultText: String
        if let output = digOutput, !output.isEmpty {
            resultText = output
        } else {
            resultText = buildDNSResultText(
                domain: domain,
                recordType: recordType,
                records: records,
                recordDetails: recordDetails,
                queryTime: latency * 1000,  // 转为毫秒
                server: server
            )
        }
        
        data["Domain"] = domain
        data["RecordType"] = recordType
        data["Records"] = records
        data["LatencyMicro"] = latencyMicro
        data["Server"] = server ?? ""
        data["ResultToText"] = resultText
        
        return data
    }
    
    // MARK: - 构建 DNS 结果文本
    private static func buildDNSResultText(
        domain: String,
        recordType: String,
        records: [String],
        recordDetails: [(name: String?, type: String, ttl: UInt32?, value: String)]?,
        queryTime: Double,              // 毫秒
        server: String?
    ) -> String {
        var resultText = "; <<>> Pong DNS <<>> \(domain)\n"
        resultText += ";; Got answer:\n"
        resultText += ";; ->>HEADER<<- opcode: QUERY, status: NOERROR\n"
        resultText += ";; flags: qr rd ra; QUERY: 1, ANSWER: \(records.count)\n\n"
        
        // Question Section
        resultText += ";; QUESTION SECTION:\n"
        resultText += ";\(domain).\t\t\tIN\t\(recordType)\n\n"
        
        // Answer Section
        if let details = recordDetails, !details.isEmpty {
            resultText += ";; ANSWER SECTION:\n"
            for r in details {
                let name = (r.name ?? domain) + "."
                let ttl = r.ttl.map { String($0) } ?? "0"
                resultText += "\(name)\t\(ttl)\tIN\t\(r.type)\t\(r.value)\n"
            }
            resultText += "\n"
        } else if !records.isEmpty {
            resultText += ";; ANSWER SECTION:\n"
            for r in records {
                resultText += "\(domain).\t0\tIN\t\(recordType)\t\(r)\n"
            }
            resultText += "\n"
        }
        
        // Footer
        resultText += String(format: ";; Query time: %.0f msec\n", queryTime)
        if let server = server {
            resultText += ";; SERVER: \(server)\n"
        }
        
        return resultText
    }
    
    // MARK: - 构建 Traceroute 上报数据
    static func buildTraceData(
        target: String,
        hops: [(hop: Int, ip: String, hostname: String?, avgLatency: TimeInterval?, lossRate: Double, sentCount: Int, receivedCount: Int, location: String?)],  // avgLatency 秒
        reachedTarget: Bool,
        source: ReportSource,
        timestamp: Date,
        duration: TimeInterval?,
        errorMessage: String?,
        ipInfo: IPInfoResponse?,
        useIPv6: Bool = false
    ) -> [String: Any] {
        var data = buildBaseData(
            target: target,
            msmType: "mtr",
            source: source,
            timestamp: timestamp,
            duration: duration,
            errorMessage: errorMessage,
            ipInfo: ipInfo,
            useIPv6: useIPv6
        )
        
        // 构建 hops 数组
        var hopsData: [[String: Any]] = []
        for hop in hops {
            var hopData: [String: Any] = [
                "Hop": hop.hop,
                "IP": hop.ip,
                "AvgLatencyMicro": (hop.avgLatency ?? 0) * 1_000_000,
                "LossRate": hop.lossRate,
                "SentCount": hop.sentCount,
                "ReceivedCount": hop.receivedCount
            ]
            if let hostname = hop.hostname {
                hopData["Hostname"] = hostname
            }
            if let location = hop.location {
                hopData["Location"] = location
            }
            hopsData.append(hopData)
        }
        
        // 结果文本 - 使用表格格式对齐
        let resultText = buildTraceResultText(
            target: target,
            hops: hops,
            reachedTarget: reachedTarget,
            errorMessage: errorMessage
        )
        
        data["Hops"] = hopsData
        data["HopCount"] = hops.count
        data["ReachedTarget"] = reachedTarget
        data["ResultToText"] = resultText
        
        return data
    }
    
    // MARK: - 构建 Traceroute 结果文本
    private static func buildTraceResultText(
        target: String,
        hops: [(hop: Int, ip: String, hostname: String?, avgLatency: TimeInterval?, lossRate: Double, sentCount: Int, receivedCount: Int, location: String?)],
        reachedTarget: Bool,
        errorMessage: String?
    ) -> String {
        let l10n = L10n.shared
        var lines: [String] = []
        
        lines.append("\(l10n.traceRouteToTarget) \(target)")
        lines.append("")
        
        if let error = errorMessage, !error.isEmpty {
            lines.append("\(l10n.error): \(error)")
        } else {
            // 纯文本报告使用英文表头，确保等宽字体下对齐
            // 动态计算 IP 列宽度，适配 IPv6（最长39字符）
            let ipHeaderWidth = 10  // "IP Address"
            let maxDataIPWidth = hops.map { $0.ip.count }.max() ?? 0
            let ipWidth = max(ipHeaderWidth, maxDataIPWidth)
            
            // 动态计算 Hostname 列宽度（无上限，完全适应实际数据）
            let hostnameHeaderWidth = 8  // "Hostname"
            let maxHostnameWidth = hops.compactMap { $0.hostname?.count }.max() ?? 0
            let hostnameWidth = max(hostnameHeaderWidth, maxHostnameWidth)
            
            // 固定列宽（基于英文字符宽度）
            let hopWidth = 4       // "Hop" + 数据最大2位
            let sentWidth = 4      // "Sent" 
            let recvWidth = 4      // "Recv"
            let lossWidth = 6      // "Loss%" + "100%"
            let avgWidth = 10      // "Avg" + "999.99ms"
            
            // 分隔线长度
            let separatorLength = hopWidth + 2 + ipWidth + 2 + hostnameWidth + 2 + sentWidth + 2 + recvWidth + 2 + lossWidth + 2 + avgWidth + 2 + 8
            
            // 表头 - 使用英文确保对齐，全部左对齐
            lines.append(
                "Hop".padding(toLength: hopWidth, withPad: " ", startingAt: 0) + "  " +
                "IP Address".padding(toLength: ipWidth, withPad: " ", startingAt: 0) + "  " +
                "Hostname".padding(toLength: hostnameWidth, withPad: " ", startingAt: 0) + "  " +
                "Sent".padding(toLength: sentWidth, withPad: " ", startingAt: 0) + "  " +
                "Recv".padding(toLength: recvWidth, withPad: " ", startingAt: 0) + "  " +
                "Loss%".padding(toLength: lossWidth, withPad: " ", startingAt: 0) + "  " +
                "Avg".padding(toLength: avgWidth, withPad: " ", startingAt: 0) + "  " +
                "Location"
            )
            lines.append(String(repeating: "-", count: separatorLength))
            
            for hop in hops {
                let hopStr = String(hop.hop).padding(toLength: hopWidth, withPad: " ", startingAt: 0)
                let ipStr = hop.ip.padding(toLength: ipWidth, withPad: " ", startingAt: 0)
                
                // Hostname 处理
                let hostnameStr = (hop.ip == "*" ? "-" : (hop.hostname ?? "-")).padding(toLength: hostnameWidth, withPad: " ", startingAt: 0)
                
                let sentStr = (hop.ip == "*" ? "-" : "\(hop.sentCount)").padding(toLength: sentWidth, withPad: " ", startingAt: 0)
                let recvStr = (hop.ip == "*" ? "-" : "\(hop.receivedCount)").padding(toLength: recvWidth, withPad: " ", startingAt: 0)
                let lossStr = (hop.ip == "*" ? "-" : String(format: "%.0f%%", hop.lossRate)).padding(toLength: lossWidth, withPad: " ", startingAt: 0)
                let avgStr = (hop.ip == "*" ? "-" : (hop.avgLatency.map { String(format: "%.2fms", $0 * 1000) } ?? "-")).padding(toLength: avgWidth, withPad: " ", startingAt: 0)
                let locationStr = hop.ip == "*" ? "-" : (hop.location ?? "-")
                
                lines.append("\(hopStr)  \(ipStr)  \(hostnameStr)  \(sentStr)  \(recvStr)  \(lossStr)  \(avgStr)  \(locationStr)")
            }
        }
        
        lines.append("")
        lines.append(reachedTarget ? l10n.traceReachedTarget : l10n.traceNotReached)
        
        return lines.joined(separator: "\n")
    }
}
