//
//  TaskHistoryView.swift
//  Pong
//
//  Created by 张金琛 on 2025/12/16.
//

import SwiftUI

struct TaskHistoryView: View {
    @StateObject private var historyManager = TaskHistoryManager.shared
    @EnvironmentObject var languageManager: LanguageManager
    @State private var selectedFilter: TaskType?
    @State private var showClearAlert = false
    @State private var showSwipeHint = false
    
    private var l10n: L10n { L10n.shared }
    
    private var filteredRecords: [TaskHistoryRecord] {
        if let filter = selectedFilter {
            return historyManager.records.filter { $0.type == filter }
        }
        return historyManager.records
    }
    
    private var groupedRecords: [(String, [TaskHistoryRecord])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredRecords) { record -> String in
            if calendar.isDateInToday(record.timestamp) {
                return l10n.today
            } else if calendar.isDateInYesterday(record.timestamp) {
                return l10n.yesterday
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "MM-dd"
                return formatter.string(from: record.timestamp)
            }
        }
        
        return grouped.sorted { first, second in
            guard let firstDate = first.value.first?.timestamp,
                  let secondDate = second.value.first?.timestamp else {
                return false
            }
            return firstDate > secondDate
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 筛选器
            filterBar
            
            // 列表
            if filteredRecords.isEmpty {
                emptyView
            } else {
                recordsList
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(l10n.taskHistory)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                // 提示按钮
                Button {
                    showSwipeHint = true
                } label: {
                    Image(systemName: "questionmark.circle")
                        .foregroundColor(.secondary)
                }
            }
            if !historyManager.records.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    // 清空按钮
                    Button {
                        showClearAlert = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .alert(l10n.clearHistory, isPresented: $showClearAlert) {
            Button(l10n.cancel, role: .cancel) { }
            Button(l10n.confirm, role: .destructive) {
                withAnimation {
                    historyManager.clearAllRecords()
                }
            }
        } message: {
            Text(l10n.clearHistoryMessage)
        }
        .onAppear {
            historyManager.cleanExpiredRecords()
        }
        .alert(l10n.swipeHint, isPresented: $showSwipeHint) {
            Button(l10n.confirm, role: .cancel) { }
        }
    }
    
    // MARK: - 筛选栏
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                FilterChip(
                    title: l10n.all,
                    isSelected: selectedFilter == nil,
                    action: { selectedFilter = nil }
                )
                
                ForEach(TaskType.allCases, id: \.self) { type in
                    FilterChip(
                        title: type.displayName,
                        isSelected: selectedFilter == type,
                        action: { selectedFilter = type }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - 空状态
    private var emptyView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text(l10n.noHistoryData)
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(l10n.historyRetentionHint)
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
    
    // MARK: - 记录列表
    private var recordsList: some View {
        List {
            ForEach(groupedRecords, id: \.0) { section in
                Section {
                    ForEach(section.1) { record in
                        NavigationLink {
                            TaskHistoryDetailView(record: record)
                        } label: {
                            TaskHistoryRow(record: record)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            // 删除按钮（红色）
                            Button(role: .destructive) {
                                withAnimation {
                                    historyManager.deleteRecord(record)
                                }
                            } label: {
                                Label(l10n.delete, systemImage: "trash")
                            }
                            .tint(.red)
                        }
                    }
                } header: {
                    Text(section.0)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
            }
            
            // 底部提示
            Section {
                Text(l10n.historyRetentionHint)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - 历史记录详情视图
struct TaskHistoryDetailView: View {
    let record: TaskHistoryRecord
    @EnvironmentObject var languageManager: LanguageManager
    @State private var showCopyToast = false
    
    private var l10n: L10n { L10n.shared }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 头部信息
                headerSection
                
                // 详细结果
                detailSection
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(record.type.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .top) {
            if showCopyToast {
                CopySuccessToastView(message: l10n.copySuccess)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 60)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showCopyToast)
    }
    
    private func showCopyToastAnimation() {
        withAnimation {
            showCopyToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showCopyToast = false
            }
        }
    }
    
    // MARK: - 头部信息
    private var headerSection: some View {
        HStack(spacing: 12) {
            // 状态图标
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: record.type.iconName)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(statusColor)
            }
            
            // 目标和时间
            VStack(alignment: .leading, spacing: 2) {
                Text(targetText)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(formattedTime)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 状态标签
            Text(record.status.displayName)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(statusColor)
                )
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    // MARK: - 详细结果
    private var detailSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(l10n.result)
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            
            Divider()
            
            switch record.type {
            case .ping:
                pingDetailView
            case .traceroute:
                tracerouteDetailView
            case .dns:
                dnsDetailView
            case .tcp:
                tcpDetailView
            case .udp:
                udpDetailView
            case .speedTest:
                speedTestDetailView
            case .http:
                httpDetailView
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Ping 详情
    private var pingDetailView: some View {
        VStack(spacing: 0) {
            if let details = record.details {
                // IP 版本
                if record.useIPv6 != nil {
                    HistoryDetailRow(title: l10n.ipVersionLabel, value: record.useIPv6 == true ? "IPv6" : "IPv4")
                    Divider().padding(.leading, 16)
                }
                // 错误信息
                if let errorMessage = details.errorMessage {
                    HistoryDetailRow(title: l10n.error, value: errorMessage)
                    Divider().padding(.leading, 16)
                }
                // 解析后的 IP
                if let resolvedIP = details.pingResolvedIP, !resolvedIP.isEmpty {
                    HistoryDetailRow(title: l10n.resolvedIP, value: resolvedIP)
                    Divider().padding(.leading, 16)
                }
                HistoryDetailRow(title: l10n.avgLatency, value: details.pingAvgLatency.map { String(format: "%.2f ms", $0) } ?? "-")
                Divider().padding(.leading, 16)
                HistoryDetailRow(title: l10n.minLatency, value: details.pingMinLatency.map { String(format: "%.2f ms", $0) } ?? "-")
                Divider().padding(.leading, 16)
                HistoryDetailRow(title: l10n.maxLatency, value: details.pingMaxLatency.map { String(format: "%.2f ms", $0) } ?? "-")
                Divider().padding(.leading, 16)
                HistoryDetailRow(title: l10n.stdDevLatency, value: details.pingStdDev.map { String(format: "%.2f ms", $0) } ?? "-")
                Divider().padding(.leading, 16)
                HistoryDetailRow(title: l10n.lossRate, value: details.pingLossRate.map { String(format: "%.1f%%", $0) } ?? "-")
                Divider().padding(.leading, 16)
                HistoryDetailRow(title: l10n.sent, value: details.pingSent.map { "\($0)" } ?? "-")
                Divider().padding(.leading, 16)
                HistoryDetailRow(title: l10n.received, value: details.pingReceived.map { "\($0)" } ?? "-")
                
                // 原始记录
                if let pingResults = details.pingResults, !pingResults.isEmpty {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 0) {
                        // 标题和复制按钮
                        HStack {
                            Text(l10n.rawRecords)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button {
                                let text = buildPingRawText(details: details)
                                UIPasteboard.general.string = text
                                showCopyToastAnimation()
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        
                        Divider().padding(.leading, 16)
                        
                        // 原始记录列表
                        ForEach(pingResults, id: \.sequence) { result in
                            PingResultHistoryRow(result: result, target: record.target, resolvedIP: details.pingResolvedIP)
                            if result.sequence != pingResults.last?.sequence {
                                Divider().padding(.leading, 16)
                            }
                        }
                    }
                }
            } else {
                HistoryDetailRow(title: l10n.result, value: record.localizedSummary)
            }
        }
    }
    
    // MARK: - Traceroute 详情
    private var tracerouteDetailView: some View {
        VStack(spacing: 0) {
            if let details = record.details {
                // IP 版本
                if record.useIPv6 != nil {
                    HistoryDetailRow(title: l10n.ipVersionLabel, value: record.useIPv6 == true ? "IPv6" : "IPv4")
                    Divider().padding(.leading, 16)
                }
                // 如果有错误信息，优先显示错误
                if let errorMessage = details.errorMessage {
                    HistoryDetailRow(title: l10n.error, value: errorMessage)
                } else {
                    HistoryDetailRow(title: l10n.totalHops, value: details.traceHops.map { "\($0) \(l10n.hops)" } ?? "-")
                    Divider().padding(.leading, 16)
                    HistoryDetailRow(title: l10n.reachStatus, value: details.traceReachedTarget == true ? l10n.reachedTarget : l10n.notReachedTarget)
                }
                
                // 显示每一跳的详细信息
                if let hopDetails = details.traceHopDetails, !hopDetails.isEmpty {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 0) {
                        // 表头
                        HStack(spacing: 4) {
                            Text("#")
                                .frame(width: 20, alignment: .leading)
                            Text("IP")
                            Spacer()
                            Text(l10n.latency)
                                .frame(width: 60, alignment: .trailing)
                            Text(l10n.lossRate)
                                .frame(width: 45, alignment: .trailing)
                            // 复制按钮
                            Button {
                                let text = buildTraceRouteText(hopDetails: hopDetails, details: details)
                                UIPasteboard.general.string = text
                                showCopyToastAnimation()
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            .frame(width: 24)
                        }
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        
                        Divider().padding(.leading, 16)
                        
                        // 跳列表
                        ForEach(hopDetails, id: \.hop) { hop in
                            TraceHopHistoryRow(hop: hop)
                            if hop.hop != hopDetails.last?.hop {
                                Divider().padding(.leading, 16)
                            }
                        }
                    }
                }
            } else {
                HistoryDetailRow(title: l10n.result, value: record.localizedSummary)
            }
        }
    }
    
    /// 构建 Traceroute 文本用于复制
    private func buildTraceRouteText(hopDetails: [TraceHopDetail], details: TaskDetails) -> String {
        var lines: [String] = []
        lines.append("Traceroute to \(record.target)")
        lines.append("")
        lines.append("Hop\tIP\t\t\tLatency\t\tLoss")
        lines.append("-".padding(toLength: 60, withPad: "-", startingAt: 0))
        
        for hop in hopDetails {
            if hop.ip == "*" {
                lines.append("\(hop.hop)\t*")
            } else {
                let latencyStr = hop.avgLatency.map { String(format: "%.1f ms", $0) } ?? "*"
                let lossStr = String(format: "%.0f%%", hop.lossRate)
                let locationStr = hop.location ?? ""
                lines.append("\(hop.hop)\t\(hop.ip)\t\(latencyStr)\t\(lossStr)\t\(locationStr)")
            }
        }
        
        lines.append("")
        lines.append(details.traceReachedTarget == true ? l10n.reachedTarget : l10n.notReachedTarget)
        
        return lines.joined(separator: "\n")
    }
    
    /// 构建 Ping 原始记录文本用于复制
    private func buildPingRawText(details: TaskDetails) -> String {
        var lines: [String] = []
        let packetSize = details.pingPacketSize ?? 64
        let resolvedIP = details.pingResolvedIP ?? record.target
        
        lines.append("PING \(record.target) (\(resolvedIP)): \(packetSize) data bytes")
        lines.append("")
        
        // 添加每次 ping 的详细结果
        if let pingResults = details.pingResults {
            for result in pingResults {
                if result.success, let latency = result.latency {
                    lines.append("\(packetSize) bytes from \(resolvedIP): icmp_seq=\(result.sequence) time=\(String(format: "%.3f", latency)) ms")
                } else {
                    lines.append("Request timeout for icmp_seq \(result.sequence)")
                }
            }
        }
        
        lines.append("")
        lines.append("--- \(record.target) ping statistics ---")
        
        let sent = details.pingSent ?? 0
        let received = details.pingReceived ?? 0
        let lossRate = details.pingLossRate ?? 0
        lines.append("\(sent) packets transmitted, \(received) packets received, \(String(format: "%.1f", lossRate))% packet loss")
        
        if let avg = details.pingAvgLatency {
            let min = details.pingMinLatency ?? avg
            let max = details.pingMaxLatency ?? avg
            let stdDev = details.pingStdDev ?? 0
            lines.append("round-trip min/avg/max/stddev = \(String(format: "%.3f", min))/\(String(format: "%.3f", avg))/\(String(format: "%.3f", max))/\(String(format: "%.3f", stdDev)) ms")
        }
        
        return lines.joined(separator: "\n")
    }
    
    // MARK: - DNS 详情
    private var dnsDetailView: some View {
        VStack(spacing: 0) {
            if let details = record.details {
                // 记录类型
                if let recordType = details.dnsRecordType {
                    HistoryDetailRow(title: l10n.recordType, value: recordType)
                    Divider().padding(.leading, 16)
                }
                
                // 查询耗时
                if let queryTime = details.dnsQueryTime {
                    HistoryDetailRow(title: l10n.queryTime, value: String(format: "%.2f ms", queryTime))
                    Divider().padding(.leading, 16)
                }
                
                // DNS 服务器
                if let server = details.dnsServer, !server.isEmpty {
                    HistoryDetailRow(title: l10n.dnsServer, value: server)
                    Divider().padding(.leading, 16)
                }
                
                // DNS 解析记录列表
                if let recordDetails = details.dnsRecordDetails, !recordDetails.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text(l10n.resolveRecords)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button {
                                let text = recordDetails.map { "\($0.type)\t\($0.value)" }.joined(separator: "\n")
                                UIPasteboard.general.string = text
                                showCopyToastAnimation()
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        
                        Divider().padding(.leading, 16)
                        
                        ForEach(recordDetails.indices, id: \.self) { index in
                            DNSRecordHistoryRow(record: recordDetails[index])
                            if index != recordDetails.count - 1 {
                                Divider().padding(.leading, 16)
                            }
                        }
                    }
                    
                    Divider()
                } else if let records = details.dnsRecords, !records.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text(l10n.resolveRecords)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button {
                                UIPasteboard.general.string = records.joined(separator: "\n")
                                showCopyToastAnimation()
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        
                        Divider().padding(.leading, 16)
                        
                        ForEach(records.indices, id: \.self) { index in
                            HStack {
                                Text(records[index])
                                    .font(.system(size: 13, design: .monospaced))
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            
                            if index != records.count - 1 {
                                Divider().padding(.leading, 16)
                            }
                        }
                    }
                    
                    Divider()
                }
                
                // dig 风格完整输出
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text(l10n.digOutput)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button {
                            UIPasteboard.general.string = buildDigOutput(details: details)
                            showCopyToastAnimation()
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    
                    Divider().padding(.leading, 16)
                    
                    // dig 风格输出
                    ScrollView(.horizontal, showsIndicators: false) {
                        Text(buildDigOutput(details: details))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.primary)
                            .padding(16)
                    }
                    .background(Color(.systemBackground))
                }
            } else {
                HistoryDetailRow(title: l10n.result, value: record.localizedSummary)
            }
        }
    }
    
    /// 构建 dig 风格输出
    private func buildDigOutput(details: TaskDetails) -> String {
        var lines: [String] = []
        let recordType = details.dnsRecordType ?? "A"
        let records = details.dnsRecords ?? []
        
        // Header
        lines.append("; <<>> Pong DNS <<>> \(record.target)")
        lines.append(";; Got answer:")
        lines.append(";; ->>HEADER<<- opcode: QUERY, status: NOERROR")
        lines.append(";; flags: qr rd ra; QUERY: 1, ANSWER: \(records.count)")
        lines.append("")
        
        // Question Section
        lines.append(";; QUESTION SECTION:")
        lines.append(";\(record.target).\t\t\tIN\t\(recordType)")
        lines.append("")
        
        // Answer Section
        if let recordDetails = details.dnsRecordDetails, !recordDetails.isEmpty {
            lines.append(";; ANSWER SECTION:")
            for r in recordDetails {
                let name = (r.name ?? record.target) + (r.name?.hasSuffix(".") == true ? "" : ".")
                let ttl = r.ttl.map { String($0) } ?? "0"
                lines.append("\(name)\t\(ttl)\tIN\t\(r.type)\t\(r.value)")
            }
            lines.append("")
        } else if !records.isEmpty {
            lines.append(";; ANSWER SECTION:")
            for r in records {
                lines.append("\(record.target).\t0\tIN\t\(recordType)\t\(r)")
            }
            lines.append("")
        }
        
        // Footer
        if let queryTime = details.dnsQueryTime {
            lines.append(String(format: ";; Query time: %.0f msec", queryTime))
        }
        if let server = details.dnsServer, !server.isEmpty {
            lines.append(";; SERVER: \(server)")
        }
        
        return lines.joined(separator: "\n")
    }
    
    // MARK: - TCP 详情
    private var tcpDetailView: some View {
        VStack(spacing: 0) {
            if let details = record.details {
                // IP 版本
                if record.useIPv6 != nil {
                    HistoryDetailRow(title: l10n.ipVersionLabel, value: record.useIPv6 == true ? "IPv6" : "IPv4")
                    Divider().padding(.leading, 16)
                }
                // 错误信息
                if let errorMessage = details.errorMessage {
                    HistoryDetailRow(title: l10n.error, value: errorMessage)
                    Divider().padding(.leading, 16)
                }
                // 批量扫描模式
                if let portResults = details.tcpPortResults, portResults.count > 1 {
                    let openCount = details.tcpOpenCount ?? portResults.filter { $0.isOpen }.count
                    let totalCount = details.tcpTotalCount ?? portResults.count
                    
                    HistoryDetailRow(title: l10n.scanResult, value: "\(openCount)/\(totalCount) \(l10n.open)")
                    Divider().padding(.leading, 16)
                    
                    // 端口详情列表
                    VStack(alignment: .leading, spacing: 0) {
                        Text(l10n.portDetails)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        
                        ForEach(portResults, id: \.port) { portDetail in
                            tcpPortRow(portDetail: portDetail)
                            if portDetail.port != portResults.last?.port {
                                Divider().padding(.leading, 32)
                            }
                        }
                    }
                } else {
                    // 单端口模式
                    HistoryDetailRow(title: l10n.portStatus, value: details.tcpIsOpen == true ? l10n.open : l10n.closed)
                    Divider().padding(.leading, 16)
                    HistoryDetailRow(title: l10n.latency, value: details.tcpLatency.map { String(format: "%.2f ms", $0) } ?? "-")
                }
            } else {
                HistoryDetailRow(title: l10n.result, value: record.localizedSummary)
            }
        }
    }
    
    // TCP 端口行视图
    private func tcpPortRow(portDetail: TCPPortDetail) -> some View {
        HStack {
            // 端口号和服务名
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("\(l10n.portPrefix) \(portDetail.port)")
                        .font(.system(size: 14, weight: .medium))
                    if let serviceName = portDetail.serviceName, !serviceName.isEmpty {
                        Text("(\(serviceName))")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // 状态和延迟
            HStack(spacing: 8) {
                if let latency = portDetail.latency, portDetail.isOpen {
                    Text(String(format: "%.1fms", latency))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                // 状态指示器
                HStack(spacing: 4) {
                    Circle()
                        .fill(portDetail.isOpen ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(portDetail.isOpen ? l10n.open : l10n.closed)
                        .font(.system(size: 13))
                        .foregroundColor(portDetail.isOpen ? .green : .red)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
    
    // MARK: - UDP 详情
    private var udpDetailView: some View {
        VStack(spacing: 0) {
            if let details = record.details {
                // IP 版本
                if record.useIPv6 != nil {
                    HistoryDetailRow(title: l10n.ipVersionLabel, value: record.useIPv6 == true ? "IPv6" : "IPv4")
                    Divider().padding(.leading, 16)
                }
                // 错误信息
                if let errorMessage = details.errorMessage {
                    HistoryDetailRow(title: l10n.error, value: errorMessage)
                    Divider().padding(.leading, 16)
                }
                HistoryDetailRow(title: l10n.sendStatus, value: details.udpSent == true ? l10n.success : l10n.failure)
                Divider().padding(.leading, 16)
                HistoryDetailRow(title: l10n.receiveStatus, value: details.udpReceived == true ? l10n.success : l10n.noResponse)
            } else {
                HistoryDetailRow(title: l10n.result, value: record.localizedSummary)
            }
        }
    }
    
    // MARK: - 测速详情
    private var speedTestDetailView: some View {
        VStack(spacing: 0) {
            if let details = record.details {
                HistoryDetailRow(title: l10n.downloadSpeed, value: details.downloadSpeed.map { String(format: "%.2f Mbps", $0) } ?? "-")
                Divider().padding(.leading, 16)
                HistoryDetailRow(title: l10n.uploadSpeed, value: details.uploadSpeed.map { String(format: "%.2f Mbps", $0) } ?? "-")
                Divider().padding(.leading, 16)
                HistoryDetailRow(title: l10n.latency, value: details.latency.map { String(format: "%.0f ms", $0) } ?? "-")
            } else {
                HistoryDetailRow(title: l10n.result, value: record.localizedSummary)
            }
        }
    }
    
    // MARK: - HTTP 详情
    private var httpDetailView: some View {
        VStack(spacing: 0) {
            if let details = record.details {
                HistoryDetailRow(title: l10n.statusCode, value: details.httpStatusCode.map { "\($0)" } ?? "-")
                Divider().padding(.leading, 16)
                HistoryDetailRow(title: l10n.responseTime, value: details.httpResponseTime.map { String(format: "%.0f ms", $0) } ?? "-")
                if let error = details.httpError, !error.isEmpty {
                    Divider().padding(.leading, 16)
                    HistoryDetailRow(title: l10n.error, value: error)
                }
            } else {
                HistoryDetailRow(title: l10n.result, value: record.localizedSummary)
            }
        }
    }
    
    private var targetText: String {
        if let port = record.port {
            return "\(record.target):\(port)"
        }
        return record.target
    }
    
    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: record.timestamp)
    }
    
    private var statusColor: Color {
        switch record.status {
        case .success: return .green
        case .failure: return .red
        case .partial: return .orange
        }
    }
}

// MARK: - 历史详情行
struct HistoryDetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 220, alignment: .trailing)
        }
        .padding(16)
    }
}

// MARK: - Traceroute 跳历史行
struct TraceHopHistoryRow: View {
    let hop: TraceHopDetail
    
    private var lossColor: Color {
        if hop.lossRate == 0 {
            return .green
        } else if hop.lossRate < 50 {
            return .orange
        } else {
            return .red
        }
    }
    
    private var latencyColor: Color {
        guard let latency = hop.avgLatency else { return .orange }
        if latency < 50 {
            return .green
        } else if latency < 150 {
            return .orange
        } else {
            return .red
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            // 跳数
            Text("\(hop.hop)")
                .foregroundColor(.secondary)
                .frame(width: 20, alignment: .leading)
            
            // IP 地址
            VStack(alignment: .leading, spacing: 2) {
                Text(hop.ip)
                    .foregroundColor(hop.ip == "*" ? .orange : .primary)
                if let hostname = hop.hostname {
                    Text(hostname)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                if let location = hop.location {
                    Text(location)
                        .font(.system(size: 10))
                        .foregroundColor(.blue)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // 延迟
            if let latency = hop.avgLatency {
                Text(String(format: "%.1f ms", latency))
                    .foregroundColor(latencyColor)
                    .frame(width: 60, alignment: .trailing)
            } else {
                Text("*")
                    .foregroundColor(.orange)
                    .frame(width: 60, alignment: .trailing)
            }
            
            // 丢包率
            Text(String(format: "%.0f%%", hop.lossRate))
                .foregroundColor(lossColor)
                .frame(width: 45, alignment: .trailing)
        }
        .font(.system(size: 12, design: .monospaced))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - Ping 单次结果历史行
struct PingResultHistoryRow: View {
    let result: PingResultDetail
    let target: String
    var resolvedIP: String? = nil
    
    private var l10n: L10n { L10n.shared }
    
    private var latencyColor: Color {
        guard let latency = result.latency else { return .orange }
        if latency < 50 {
            return .green
        } else if latency < 150 {
            return .orange
        } else {
            return .red
        }
    }
    
    /// 显示的 IP 地址（优先使用解析后的 IP）
    private var displayIP: String {
        resolvedIP ?? target
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // 序号
            Text("#\(result.sequence)")
                .foregroundColor(.secondary)
                .frame(width: 30, alignment: .leading)
            
            // 解析后的 IP
            Text(displayIP)
                .foregroundColor(.primary)
                .lineLimit(1)
            
            Spacer()
            
            // 延迟或超时
            if result.success, let latency = result.latency {
                Text(String(format: "%.2f ms", latency))
                    .foregroundColor(latencyColor)
                    .fontWeight(.medium)
            } else {
                Text(l10n.timeout)
                    .foregroundColor(.red)
                    .fontWeight(.medium)
            }
        }
        .font(.system(size: 12, design: .monospaced))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - DNS 记录历史行
struct DNSRecordHistoryRow: View {
    let record: DNSRecordDetail
    
    var body: some View {
        HStack(spacing: 8) {
            // 类型
            Text(record.type)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(typeColor)
                )
            
            // 值
            Text(record.value)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.primary)
                .lineLimit(1)
            
            Spacer()
            
            // TTL
            if let ttl = record.ttl {
                Text("TTL: \(ttl)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    private var typeColor: Color {
        switch record.type {
        case "A": return .blue
        case "AAAA": return .purple
        case "CNAME": return .orange
        case "MX": return .green
        case "TXT": return .gray
        case "NS": return .cyan
        default: return .secondary
        }
    }
}

// MARK: - 筛选芯片
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.blue : Color(.systemGray5))
                )
        }
    }
}

// MARK: - 历史记录行
struct TaskHistoryRow: View {
    let record: TaskHistoryRecord
    @EnvironmentObject var languageManager: LanguageManager
    
    private var l10n: L10n { L10n.shared }
    
    var body: some View {
        HStack(spacing: 14) {
            // 类型图标
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: record.type.iconName)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(statusColor)
            }
            
            // 内容
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(record.type.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    statusBadge
                }
                
                Text(targetText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Text(record.localizedSummary)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // 时间
            Text(timeText)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    private var targetText: String {
        if let port = record.port {
            return "\(record.target):\(port)"
        }
        return record.target
    }
    
    private var timeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: record.timestamp)
    }
    
    private var statusColor: Color {
        switch record.status {
        case .success: return .green
        case .failure: return .red
        case .partial: return .orange
        }
    }
    
    private var statusBadge: some View {
        Text(record.status.displayName)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(statusColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(statusColor.opacity(0.12))
            )
    }
}

// MARK: - 复制成功 Toast 视图
struct CopySuccessToastView: View {
    let message: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.8))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    NavigationStack {
        TaskHistoryView()
            .environmentObject(LanguageManager.shared)
    }
}
