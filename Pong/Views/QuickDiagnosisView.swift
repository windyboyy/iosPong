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
    @ObservedObject private var hostHistoryManager = HostHistoryManager.shared
    @State private var targetAddress: String = ""
    @FocusState private var isInputFocused: Bool
    @State private var showReportView = false
    
    private var l10n: L10n { L10n.shared }
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 24) {
                    // 顶部输入区域（idle 状态）或诊断进度卡片（运行/完成状态）
                    if manager.state == .idle {
                        inputSection
                            .id("top")
                    } else {
                        diagnosisProgressCard
                            .id("top")
                            .transition(.opacity)
                    }
                    
                    // 诊断任务列表（运行中或完成时显示）
                    if case .running = manager.state {
                        taskListSection
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else if case .completed = manager.state {
                        taskListSection
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
                    // 功能说明（仅在 idle 状态显示）
                    if manager.state == .idle {
                        featureDescriptionSection
                            .transition(.opacity)
                    }
                    
                    // 底部操作按钮（完成时显示）
                    if case .completed = manager.state {
                        bottomActionSection
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
                    // 错误状态
                    if case .error(let message) = manager.state {
                        errorSection(message: message)
                            .transition(.opacity)
                    }
                }
                .padding()
                .animation(.easeInOut(duration: 0.3), value: manager.state)
            }
            .onChange(of: manager.state) { newState in
                if case .running = newState {
                    withAnimation {
                        proxy.scrollTo("top", anchor: .top)
                    }
                }
            }
        }
        .navigationTitle(l10n.quickDiagnosis)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showReportView) {
            DiagnosisReportView(
                targetAddress: manager.targetAddress,
                taskResults: manager.taskResults
            )
            .environmentObject(languageManager)
        }
        .onAppear {
            // 只有在 idle 状态时才重置，避免从报告页面返回时重置数据
            if manager.state == .idle {
                resetState()
            } else {
                // 如果是从报告页面返回，同步 manager 的地址到本地变量
                targetAddress = manager.targetAddress
            }
        }
    }
    
    // MARK: - 诊断进度卡片（运行/完成状态显示）
    private var diagnosisProgressCard: some View {
        VStack(spacing: 16) {
            // 目标地址显示
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.gradientBlue.opacity(0.15), .gradientPurple.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "globe")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.gradientBlue, .gradientPurple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(l10n.targetAddress)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(manager.targetAddress)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // 状态标签
                statusLabel
            }
            
            // 分隔线
            Rectangle()
                .fill(Color(.separator).opacity(0.2))
                .frame(height: 1)
            
            // 进度信息
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(manager.state == .running ? l10n.executingDiagnosis : l10n.diagnosisComplete)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text("\(l10n.task) \(manager.currentTaskIndex + 1) / \(manager.totalTasks)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 百分比
                Text("\(Int(manager.progress * 100))%")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.gradientBlue, .gradientPurple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            
            // 进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 5)
                        .fill(
                            LinearGradient(
                                colors: [.gradientBlue, .gradientPurple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(geometry.size.width * manager.progress, 8), height: 8)
                        .shadow(color: .gradientBlue.opacity(0.3), radius: 3, x: 0, y: 1)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: manager.progress)
                }
            }
            .frame(height: 8)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    // 状态标签
    private var statusLabel: some View {
        Group {
            if manager.state == .running {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 14, height: 14)
                        .tint(.white)
                    Text(l10n.running)
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.gradientBlue, .gradientPurple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                    Text(l10n.success)
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.green)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.green.opacity(0.12))
                )
            }
        }
    }
    
    // MARK: - 输入区域
    private var inputSection: some View {
        VStack(spacing: 16) {
            // 顶部图标和标题（仅在 idle 状态显示完整版）
            if manager.state == .idle {
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
                .padding(.top, 20)
            }
            
            // 地址输入框
            VStack(spacing: 12) {
                HStack {
                    TextField(l10n.targetAddressPlaceholder, text: $targetAddress)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .focused($isInputFocused)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(.URL)
                        .disabled(manager.state == .running)
                    
                    if manager.state == .running {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isInputFocused ? Color.gradientBlue : Color(.systemGray4), lineWidth: isInputFocused ? 2 : 1)
                )
                
                // 开始诊断按钮（仅在 idle 状态显示）
                if manager.state == .idle {
                    Button {
                        let trimmedAddress = targetAddress.trimmingCharacters(in: .whitespacesAndNewlines)
                        hostHistoryManager.addQuickDiagnosisHistory(trimmedAddress)
                        isInputFocused = false
                        Task {
                            await manager.startDiagnosis(target: trimmedAddress)
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
            }
            
            // 快捷诊断选择（仅在 idle 状态显示）
            if manager.state == .idle && !hostHistoryManager.quickDiagnosisHistory.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(hostHistoryManager.quickDiagnosisHistory, id: \.self) { host in
                            Button {
                                targetAddress = host
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "clock")
                                        .font(.system(size: 10))
                                    Text(host)
                                        .font(.caption)
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(targetAddress == host ? Color.gradientBlue : Color(.systemGray5))
                                .foregroundColor(targetAddress == host ? .white : .primary)
                                .cornerRadius(16)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 任务列表区域
    private var taskListSection: some View {
        VStack(spacing: 10) {
            ForEach(Array(manager.taskResults.values).sorted(by: { $0.taskDetail.id < $1.taskDetail.id })) { result in
                TaskStatusCard(result: result)
            }
        }
    }
    
    // MARK: - 功能说明区域
    private var featureDescriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.gradientBlue)
                Text(l10n.quickDiagnosisFeatureTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            Text(l10n.quickDiagnosisFeatureDesc)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - 底部操作区域
    private var bottomActionSection: some View {
        VStack(spacing: 12) {
            // 查看诊断报告按钮
            Button {
                showReportView = true
            } label: {
                HStack {
                    Image(systemName: "doc.text.magnifyingglass")
                    Text(l10n.viewDiagnosisReport)
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
            
            // 重新诊断按钮
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
                .foregroundColor(.gradientBlue)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gradientBlue, lineWidth: 2)
                )
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - 错误区域
    private func errorSection(message: String) -> some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.15))
                    .frame(width: 64, height: 64)
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.red)
            }
            
            Text(l10n.diagnosisFailed)
                .font(.headline)
                .fontWeight(.bold)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
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
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - 辅助方法
    private func resetState() {
        // 如果当前状态不是 idle，才执行重置，避免重复重置
        if manager.state != .idle {
            manager.reset()
        }
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
        HStack(spacing: 14) {
            // 左侧状态指示条
            RoundedRectangle(cornerRadius: 2)
                .fill(statusGradient)
                .frame(width: 4, height: 40)
            
            // 任务类型图标
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(taskTypeColor.opacity(0.12))
                    .frame(width: 40, height: 40)
                
                Image(systemName: result.taskDetail.taskType?.icon ?? "questionmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(taskTypeColor)
            }
            
            // 任务信息
            VStack(alignment: .leading, spacing: 3) {
                Text(result.taskDetail.taskType?.displayName ?? result.taskDetail.msmType)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(result.taskDetail.target)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // 右侧状态
            HStack(spacing: 8) {
                statusBadge
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
                .shadow(color: Color.primary.opacity(0.06), radius: 2, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(statusBorderColor, lineWidth: result.status == .running ? 1.5 : 1)
        )
    }
    
    private var taskTypeColor: Color {
        switch result.taskDetail.taskType {
        case .ping: return .blue
        case .tcp: return .orange
        case .udp: return .green
        case .dns: return .cyan
        case .trace: return .purple
        case .none: return .gray
        }
    }
    
    private var statusGradient: LinearGradient {
        switch result.status {
        case .pending:
            return LinearGradient(colors: [.gray.opacity(0.4), .gray.opacity(0.2)], startPoint: .top, endPoint: .bottom)
        case .running:
            return LinearGradient(colors: [.gradientBlue, .gradientPurple], startPoint: .top, endPoint: .bottom)
        case .success:
            return LinearGradient(colors: [.green, .green.opacity(0.7)], startPoint: .top, endPoint: .bottom)
        case .failed:
            return LinearGradient(colors: [.red, .red.opacity(0.7)], startPoint: .top, endPoint: .bottom)
        }
    }
    
    private var statusBorderColor: Color {
        switch result.status {
        case .pending: return Color(.systemGray3)
        case .running: return .gradientBlue.opacity(0.7)
        case .success: return .green.opacity(0.4)
        case .failed: return .red.opacity(0.4)
        }
    }
    
    @ViewBuilder
    private var statusBadge: some View {
        switch result.status {
        case .pending:
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.system(size: 10))
                Text(l10n.pending)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color(.tertiarySystemFill))
            )
            
        case .running:
            HStack(spacing: 6) {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 12, height: 12)
                    .tint(.white)
                Text(l10n.running)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.gradientBlue, .gradientPurple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            
        case .success:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11))
                Text(l10n.success)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(.green)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color.green.opacity(0.15))
            )
            
        case .failed:
            HStack(spacing: 4) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 11))
                Text(l10n.failure)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(.red)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color.red.opacity(0.15))
            )
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
