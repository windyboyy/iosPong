//
//  QuickDiagnosisView.swift
//  Pong
//
//  Created by 张金琛 on 2025/12/15.
//

import SwiftUI

// MARK: - 蓝紫渐变色（与首页一致）
extension Color {
    static let gradientBlue = Color(red: 0.2, green: 0.4, blue: 0.9)
    static let gradientPurple = Color(red: 0.6, green: 0.3, blue: 0.9)
}

// MARK: - 一键诊断视图
struct QuickDiagnosisView: View {
    @EnvironmentObject var languageManager: LanguageManager
    @ObservedObject private var manager = QuickDiagnosisManager.shared
    @State private var targetAddress: String = ""
    @FocusState private var isInputFocused: Bool
    
    private var l10n: L10n { L10n.shared }
    
    var body: some View {
        Group {
            switch manager.state {
            case .idle:
                inputView
            case .running:
                executionView
            case .completed:
                resultView
            case .error(let message):
                errorView(message: message)
            }
        }
        .navigationTitle(l10n.quickDiagnosis)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // 每次页面出现时重置状态
            resetState()
        }
        .onDisappear {
            // 页面消失时也重置，确保下次进入是干净状态
            manager.reset()
        }
    }
    
    // MARK: - 输入地址视图
    private var inputView: some View {
        VStack(spacing: 32) {
            // 顶部说明
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.gradientBlue, .gradientPurple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 36))
                        .foregroundColor(.white)
                }
                
                Text(l10n.quickDiagnosis)
                    .font(.title)
                    .fontWeight(.bold)
                
                Text(l10n.enterTargetAddress)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 40)
            
            // 地址输入框
            VStack(spacing: 16) {
                TextField(l10n.targetAddressPlaceholder, text: $targetAddress)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isInputFocused ? Color.gradientBlue : Color(.systemGray4), lineWidth: isInputFocused ? 2 : 1)
                    )
                    .focused($isInputFocused)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .keyboardType(.URL)
                
                // 开始诊断按钮
                Button {
                    Task {
                        await manager.startDiagnosis(target: targetAddress.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                } label: {
                    HStack {
                        Image(systemName: "play.fill")
                        Text(l10n.startDiagnosis)
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: targetAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty 
                                ? [Color.gray, Color.gray] 
                                : [Color.gradientBlue, Color.gradientPurple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
                .disabled(targetAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal)
            
            // 提示信息
            VStack(spacing: 8) {
                Text(l10n.diagnosisAddressHint)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)
            
            Spacer()
        }
    }
    
    // MARK: - 执行中视图
    private var executionView: some View {
        VStack(spacing: 0) {
            // 进度头部
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(Color(.systemGray4), lineWidth: 8)
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .trim(from: 0, to: manager.progress)
                        .stroke(
                            LinearGradient(
                                colors: [.gradientBlue, .gradientPurple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut, value: manager.progress)
                    
                    Text("\(Int(manager.progress * 100))%")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                
                Text(l10n.executingDiagnosis)
                    .font(.headline)
                
                Text("\(l10n.task) \(manager.currentTaskIndex + 1) / \(manager.totalTasks)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(manager.targetAddress)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 32)
            .frame(maxWidth: .infinity)
            .background(Color(.systemBackground))
            
            // 任务状态列表
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(Array(manager.taskResults.values).sorted(by: { $0.taskDetail.id < $1.taskDetail.id })) { result in
                        TaskStatusCard(result: result)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
        }
    }
    
    // MARK: - 结果视图
    private var resultView: some View {
        VStack(spacing: 0) {
            // 完成头部
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 64, height: 64)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.green)
                }
                
                Text(l10n.diagnosisComplete)
                    .font(.title3)
                    .fontWeight(.bold)
                
                let successCount = manager.taskResults.values.filter { $0.status == .success }.count
                let totalCount = manager.taskResults.count
                
                Text("\(successCount) / \(totalCount) \(l10n.tasksSuccess)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(manager.targetAddress)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
            .background(Color(.systemBackground))
            
            // 结果列表
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(Array(manager.taskResults.values).sorted(by: { $0.taskDetail.id < $1.taskDetail.id })) { result in
                        TaskResultCard(result: result)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            
            // 底部操作
            VStack(spacing: 12) {
                Button {
                    manager.reset()
                    targetAddress = ""
                    isInputFocused = true
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text(l10n.reDiagnose)
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [.gradientBlue, .gradientPurple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
            }
            .padding()
            .background(Color(.systemBackground))
        }
    }
    
    // MARK: - 错误视图
    private func errorView(message: String) -> some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.15))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.red)
            }
            
            Text(l10n.diagnosisFailed)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button {
                manager.reset()
                targetAddress = ""
                isInputFocused = true
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text(l10n.retry)
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [.gradientBlue, .gradientPurple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(10)
            }
            
            Spacer()
        }
    }
    
    // MARK: - 辅助方法
    private func resetState() {
        manager.reset()
        targetAddress = ""
        isInputFocused = true
    }
}

// MARK: - 任务预览卡片
struct TaskPreviewCard: View {
    let task: DiagnosisTaskDetail
    
    var body: some View {
        HStack(spacing: 16) {
            // 图标
            ZStack {
                Circle()
                    .fill(taskColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: task.taskType?.icon ?? "questionmark")
                    .font(.title3)
                    .foregroundColor(taskColor)
            }
            
            // 任务信息
            VStack(alignment: .leading, spacing: 4) {
                Text(task.taskType?.displayName ?? task.msmType)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(task.displayDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var taskColor: Color {
        switch task.taskType {
        case .ping: return .blue
        case .tcp: return .orange
        case .udp: return .green
        case .dns: return .cyan
        case .trace: return .purple
        case .none: return .gray
        }
    }
}

// MARK: - 任务状态卡片
struct TaskStatusCard: View {
    @EnvironmentObject var languageManager: LanguageManager
    let result: DiagnosisTaskResult
    
    private var l10n: L10n { L10n.shared }
    
    var body: some View {
        HStack(spacing: 16) {
            // 状态图标
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                statusIcon
            }
            
            // 任务信息
            VStack(alignment: .leading, spacing: 4) {
                Text(result.taskDetail.taskType?.displayName ?? result.taskDetail.msmType)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(result.taskDetail.target)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 状态文字
            statusText
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var statusColor: Color {
        switch result.status {
        case .pending: return .gray
        case .running: return .blue
        case .success: return .green
        case .failed: return .red
        }
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        switch result.status {
        case .pending:
            Image(systemName: "clock")
                .foregroundColor(.gray)
        case .running:
            ProgressView()
                .scaleEffect(0.8)
        case .success:
            Image(systemName: "checkmark")
                .foregroundColor(.green)
        case .failed:
            Image(systemName: "xmark")
                .foregroundColor(.red)
        }
    }
    
    @ViewBuilder
    private var statusText: some View {
        switch result.status {
        case .pending:
            Text(l10n.pending)
                .font(.caption)
                .foregroundColor(.secondary)
        case .running:
            Text(l10n.running)
                .font(.caption)
                .foregroundColor(.blue)
        case .success:
            Text(l10n.success)
                .font(.caption)
                .foregroundColor(.green)
        case .failed:
            Text(l10n.failure)
                .font(.caption)
                .foregroundColor(.red)
        }
    }
}

// MARK: - 任务结果卡片
struct TaskResultCard: View {
    @EnvironmentObject var languageManager: LanguageManager
    let result: DiagnosisTaskResult
    @State private var isExpanded = false
    
    private var l10n: L10n { L10n.shared }
    
    var body: some View {
        VStack(spacing: 0) {
            // 头部
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 16) {
                    // 状态图标
                    ZStack {
                        Circle()
                            .fill(statusColor.opacity(0.15))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: result.status == .success ? "checkmark" : "xmark")
                            .foregroundColor(statusColor)
                    }
                    
                    // 任务信息
                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.taskDetail.taskType?.displayName ?? result.taskDetail.msmType)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(result.taskDetail.target)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // 耗时
                    if let duration = result.duration {
                        Text(String(format: "%.0fms", duration * 1000))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            .buttonStyle(.plain)
            
            // 展开的详情
            if isExpanded {
                Divider()
                    .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 8) {
                    if let error = result.error {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    } else {
                        resultDetailView
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var statusColor: Color {
        result.status == .success ? .green : .red
    }
    
    @ViewBuilder
    private var resultDetailView: some View {
        if let pingResult = result.resultData as? PingProbeResult {
            VStack(alignment: .leading, spacing: 4) {
                Text(l10n.pingResult)
                    .font(.caption)
                    .fontWeight(.medium)
                
                HStack(spacing: 16) {
                    VStack(alignment: .leading) {
                        Text(l10n.successRate)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(pingResult.successCount)/\(pingResult.count)")
                            .font(.caption)
                    }
                    
                    if let avg = pingResult.avgLatency {
                        VStack(alignment: .leading) {
                            Text(l10n.avgLatency)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.1fms", avg * 1000))
                                .font(.caption)
                        }
                    }
                    
                    VStack(alignment: .leading) {
                        Text(l10n.lossRate)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.1f%%", pingResult.lossRate))
                            .font(.caption)
                    }
                }
            }
        } else if let tcpResult = result.resultData as? TCPProbeResult {
            VStack(alignment: .leading, spacing: 4) {
                Text(l10n.tcpResult)
                    .font(.caption)
                    .fontWeight(.medium)
                
                HStack(spacing: 16) {
                    VStack(alignment: .leading) {
                        Text(l10n.portStatus)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(tcpResult.isOpen ? l10n.open : l10n.closed)
                            .font(.caption)
                            .foregroundColor(tcpResult.isOpen ? .green : .red)
                    }
                    
                    if let latency = tcpResult.latency {
                        VStack(alignment: .leading) {
                            Text(l10n.connectionTime)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.1fms", latency * 1000))
                                .font(.caption)
                        }
                    }
                }
            }
        } else if let udpResult = result.resultData as? UDPProbeResult {
            VStack(alignment: .leading, spacing: 4) {
                Text(l10n.udpResult)
                    .font(.caption)
                    .fontWeight(.medium)
                
                HStack(spacing: 16) {
                    VStack(alignment: .leading) {
                        Text(l10n.sendStatus)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(udpResult.sent ? l10n.sent : l10n.sendFailed)
                            .font(.caption)
                            .foregroundColor(udpResult.sent ? .green : .red)
                    }
                    
                    VStack(alignment: .leading) {
                        Text(l10n.receiveStatus)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(udpResult.received ? l10n.received : l10n.noResponse)
                            .font(.caption)
                            .foregroundColor(udpResult.received ? .green : .orange)
                    }
                    
                    if let latency = udpResult.latency {
                        VStack(alignment: .leading) {
                            Text(l10n.latency)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.1fms", latency * 1000))
                                .font(.caption)
                        }
                    }
                }
                
                if let error = udpResult.error {
                    Text(error)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        } else if let dnsResult = result.resultData as? DNSProbeResult {
            VStack(alignment: .leading, spacing: 4) {
                Text(l10n.dnsResult)
                    .font(.caption)
                    .fontWeight(.medium)
                
                if !dnsResult.records.isEmpty {
                    ForEach(dnsResult.records.prefix(3), id: \.self) { record in
                        Text(record)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if dnsResult.records.count > 3 {
                        Text("... \(l10n.moreRecords) \(dnsResult.records.count - 3) \(l10n.recordsText)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        } else if let traceResult = result.resultData as? TraceProbeResult {
            VStack(alignment: .leading, spacing: 8) {
                // 头部摘要
                HStack {
                    Text(l10n.tracerouteResult)
                        .font(.caption)
                        .fontWeight(.medium)
                    Spacer()
                    if let error = traceResult.error {
                        // 有错误时显示错误状态
                        Text(l10n.failure)
                            .font(.caption)
                            .foregroundColor(.red)
                    } else {
                        Text(traceResult.reachedTarget ? l10n.reachedTarget : l10n.notReachedTarget)
                            .font(.caption)
                            .foregroundColor(traceResult.reachedTarget ? .green : .orange)
                    }
                }
                
                // 如果有错误，显示错误信息
                if let error = traceResult.error {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.vertical, 4)
                } else if !traceResult.hops.isEmpty {
                    // 跳列表表头
                    HStack(spacing: 4) {
                        Text("#")
                            .frame(width: 24, alignment: .leading)
                        Text("IP")
                        Spacer()
                        Text(l10n.latency)
                            .frame(width: 60, alignment: .trailing)
                        Text(l10n.lossHeader)
                            .frame(width: 45, alignment: .trailing)
                    }
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
                    
                    Divider()
                    
                    // 跳列表
                    ForEach(traceResult.hops, id: \.hop) { hop in
                        TraceHopResultRow(hop: hop)
                    }
                }
            }
        } else {
            Text(l10n.probeComplete)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Traceroute 跳结果行
struct TraceHopResultRow: View {
    let hop: TraceHopResult
    
    private var lossColor: Color {
        if hop.lossRate == 0 {
            return .green
        } else if hop.lossRate < 50 {
            return .orange
        } else {
            return .red
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            // 跳数
            Text("\(hop.hop)")
                .frame(width: 24, alignment: .leading)
            
            // IP 地址
            if hop.ip == "*" {
                Text("*")
                    .foregroundColor(.orange)
            } else {
                VStack(alignment: .leading, spacing: 1) {
                    Text(hop.ip)
                    if let location = hop.location, !location.isEmpty {
                        Text(location)
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // 延迟
            if let latency = hop.avgLatency {
                Text(String(format: "%.1fms", latency * 1000))
                    .frame(width: 60, alignment: .trailing)
            } else {
                Text("-")
                    .foregroundColor(.secondary)
                    .frame(width: 60, alignment: .trailing)
            }
            
            // 丢包率
            Text(String(format: "%.0f%%", hop.lossRate))
                .foregroundColor(lossColor)
                .frame(width: 45, alignment: .trailing)
        }
        .font(.system(size: 10, design: .monospaced))
    }
}

#Preview {
    NavigationStack {
        QuickDiagnosisView()
            .environmentObject(LanguageManager.shared)
    }
}
