//
//  DiagnosisReportView.swift
//  Pong
//
//  Created by 张金琛 on 2025/12/15.
//

import SwiftUI

// MARK: - 诊断报告视图
struct DiagnosisReportView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var languageManager: LanguageManager
    let targetAddress: String
    let taskResults: [UUID: DiagnosisTaskResult]
    
    private var l10n: L10n { L10n.shared }
    
    // 深色模式下调整渐变色透明度
    private var gradientOpacity: Double {
        colorScheme == .dark ? 0.3 : 0.2
    }
    
    // 卡片背景色 - 深色模式下使用更深的灰色增加层次感
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color(white: 0.15) : Color(.systemBackground)
    }
    
    // 统计区域背景色
    private var statsBackgroundColor: Color {
        colorScheme == .dark ? Color(white: 0.2) : Color(.secondarySystemBackground)
    }
    
    private var sortedResults: [DiagnosisTaskResult] {
        Array(taskResults.values).sorted { $0.taskDetail.id < $1.taskDetail.id }
    }
    
    private var successCount: Int {
        taskResults.values.filter { $0.status == .success }.count
    }
    
    private var failureCount: Int {
        taskResults.count - successCount
    }
    
    // 诊断总结
    private var diagnosisSummary: String {
        if taskResults.isEmpty {
            return l10n.noDiagnosisData
        }
        
        if failureCount == 0 {
            return l10n.diagnosisSummaryAllSuccess
        } else if successCount == 0 {
            return l10n.diagnosisSummaryAllFailed
        } else {
            return String(format: l10n.diagnosisSummaryPartial, failureCount)
        }
    }
    
    private var summaryColor: Color {
        if failureCount == 0 {
            return .green
        } else if successCount == 0 {
            return .red
        } else {
            return .orange
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 报告头部
                reportHeader
                
                // 详细结果
                ForEach(sortedResults) { result in
                    ReportTaskCard(result: result)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(l10n.quickDiagnosis)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - 报告头部
    private var reportHeader: some View {
        VStack(spacing: 12) {
            // 图标和目标地址在同一行
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.gradientBlue.opacity(gradientOpacity), .gradientPurple.opacity(gradientOpacity)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 22))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.gradientBlue, .gradientPurple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(l10n.diagnosisReport)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(targetAddress)
                        .font(.title3)
                        .fontWeight(.bold)
                }
                
                Spacer()
            }
            
            // 统计信息
            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text("\(taskResults.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Text(l10n.task)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                Divider()
                    .frame(height: 36)
                
                VStack(spacing: 4) {
                    Text("\(successCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    Text(l10n.success)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                Divider()
                    .frame(height: 36)
                
                VStack(spacing: 4) {
                    Text("\(failureCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                    Text(l10n.failure)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 12)
            .background(statsBackgroundColor)
            .cornerRadius(10)
            
            // 诊断总结
            HStack(spacing: 8) {
                Image(systemName: failureCount == 0 ? "checkmark.circle.fill" : (successCount == 0 ? "xmark.circle.fill" : "exclamationmark.circle.fill"))
                    .foregroundColor(summaryColor)
                
                Text(diagnosisSummary)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding(.top, 4)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(cardBackgroundColor)
        .cornerRadius(16)
    }
}

// MARK: - 报告任务卡片
struct ReportTaskCard: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var languageManager: LanguageManager
    let result: DiagnosisTaskResult
    
    private var l10n: L10n { L10n.shared }
    
    // 深色模式下调整状态图标背景透明度
    private var statusBgOpacity: Double {
        colorScheme == .dark ? 0.25 : 0.15
    }
    
    // 卡片背景色 - 深色模式下使用更深的灰色增加层次感
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color(white: 0.15) : Color(.systemBackground)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 头部
            HStack(spacing: 12) {
                // 状态图标
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(statusBgOpacity))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: result.status == .success ? "checkmark" : "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(statusColor)
                }
                
                // 任务信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.taskDetail.taskType?.displayName ?? result.taskDetail.msmType)
                        .font(.headline)
                    
                    Text(result.taskDetail.target)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 耗时
                if let duration = result.duration {
                    Text(String(format: "%.0fms", duration * 1000))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            // 详细结果
            if let error = result.error {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
            } else {
                resultDetailView
            }
        }
        .padding()
        .background(cardBackgroundColor)
        .cornerRadius(12)
    }
    
    private var statusColor: Color {
        result.status == .success ? .green : .red
    }
    
    @ViewBuilder
    private var resultDetailView: some View {
        if let pingResult = result.resultData as? PingProbeResult {
            pingResultView(pingResult)
        } else if let tcpResult = result.resultData as? TCPProbeResult {
            tcpResultView(tcpResult)
        } else if let udpResult = result.resultData as? UDPProbeResult {
            udpResultView(udpResult)
        } else if let dnsResult = result.resultData as? DNSProbeResult {
            dnsResultView(dnsResult)
        } else if let traceResult = result.resultData as? TraceProbeResult {
            traceResultView(traceResult)
        } else {
            Text(l10n.probeComplete)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Ping 结果
    private func pingResultView(_ result: PingProbeResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 20) {
                resultItem(title: l10n.successRate, value: "\(result.successCount)/\(result.count)")
                if let avg = result.avgLatency {
                    resultItem(title: l10n.avgLatency, value: String(format: "%.1fms", avg * 1000))
                }
                resultItem(title: l10n.lossRate, value: String(format: "%.1f%%", result.lossRate))
            }
            
            if let ip = result.resolvedIP {
                HStack {
                    Text(l10n.resolvedIP + ":")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(ip)
                        .font(.caption)
                        .foregroundColor(.primary)
                }
            }
        }
    }
    
    // MARK: - TCP 结果
    private func tcpResultView(_ result: TCPProbeResult) -> some View {
        HStack(spacing: 20) {
            resultItem(
                title: l10n.portStatus,
                value: result.isOpen ? l10n.open : l10n.closed,
                valueColor: result.isOpen ? .green : .red
            )
            if let latency = result.latency {
                resultItem(title: l10n.connectionTime, value: String(format: "%.1fms", latency * 1000))
            }
            resultItem(title: l10n.port, value: "\(result.port)")
        }
    }
    
    // MARK: - UDP 结果
    private func udpResultView(_ result: UDPProbeResult) -> some View {
        HStack(spacing: 20) {
            resultItem(
                title: l10n.sendStatus,
                value: result.sent ? l10n.sent : l10n.sendFailed,
                valueColor: result.sent ? .green : .red
            )
            resultItem(
                title: l10n.receiveStatus,
                value: result.received ? l10n.received : l10n.noResponse,
                valueColor: result.received ? .green : .orange
            )
            if let latency = result.latency {
                resultItem(title: l10n.latency, value: String(format: "%.1fms", latency * 1000))
            }
        }
    }
    
    // MARK: - DNS 结果
    private func dnsResultView(_ result: DNSProbeResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if !result.records.isEmpty {
                Text(l10n.resolveResult + ":")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ForEach(result.records, id: \.self) { record in
                    Text(record)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.primary)
                }
            }
            
            HStack {
                Text(l10n.queryTime + ":")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(String(format: "%.0fms", result.latency * 1000))
                    .font(.caption)
                    .foregroundColor(.primary)
            }
        }
    }
    
    // MARK: - Traceroute 结果
    private func traceResultView(_ result: TraceProbeResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // 状态
            HStack {
                Text(result.reachedTarget ? l10n.reachedTarget : l10n.notReachedTarget)
                    .font(.subheadline)
                    .foregroundColor(result.reachedTarget ? .green : .orange)
                
                Spacer()
                
                Text("\(result.hops.count) \(l10n.hops)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // 跳列表（显示前5跳和最后一跳）
            if !result.hops.isEmpty {
                Divider()
                
                let displayHops = getDisplayHops(result.hops)
                ForEach(displayHops, id: \.hop) { hop in
                    traceHopRow(hop)
                }
                
                if result.hops.count > 6 {
                    Text("...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
    }
    
    // 单跳显示行
    private func traceHopRow(_ hop: TraceHopResult) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            // 第一行：跳数、IP、延迟、丢包率
            HStack {
                Text("\(hop.hop)")
                    .font(.system(.caption, design: .monospaced))
                    .frame(width: 20, alignment: .leading)
                
                Text(hop.ip)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(hop.ip == "*" ? .orange : .primary)
                
                Spacer()
                
                // 延迟
                if let latency = hop.avgLatency {
                    Text(String(format: "%.1fms", latency * 1000))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                
                // 丢包率
                Text(String(format: "%.0f%%", hop.lossRate))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(lossRateColor(hop.lossRate))
                    .frame(width: 36, alignment: .trailing)
            }
            
            // 附加信息（PTR 和归属地分行显示）
            if hop.ip != "*" {
                VStack(alignment: .leading, spacing: 1) {
                    // PTR 主机名
                    if let hostname = hop.hostname, !hostname.isEmpty, hostname != hop.ip {
                        Text(hostname)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    // 归属地
                    if let location = hop.location, !location.isEmpty {
                        Text(location)
                            .font(.system(size: 10))
                            .foregroundColor(.cyan)
                    }
                }
                .padding(.leading, 20)
            }
        }
        .padding(.vertical, 2)
    }
    
    // 丢包率颜色
    private func lossRateColor(_ rate: Double) -> Color {
        if rate == 0 {
            return .green
        } else if rate < 50 {
            return .orange
        } else {
            return .red
        }
    }
    
    private func getDisplayHops(_ hops: [TraceHopResult]) -> [TraceHopResult] {
        if hops.count <= 6 {
            return hops
        }
        // 显示前5跳和最后一跳
        var display = Array(hops.prefix(5))
        display.append(hops.last!)
        return display
    }
    
    // MARK: - 结果项
    private func resultItem(title: String, value: String, valueColor: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(valueColor)
        }
    }
}

#Preview {
    NavigationStack {
        DiagnosisReportView(
            targetAddress: "baidu.com",
            taskResults: [:]
        )
        .environmentObject(LanguageManager.shared)
    }
}
