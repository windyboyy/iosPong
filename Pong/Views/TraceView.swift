//
//  TraceView.swift
//  Pong
//
//  Created by 张金琛 on 2025/12/12.
//

import SwiftUI

struct TraceView: View {
    @StateObject private var traceManager = TraceManager.shared
    @StateObject private var historyManager = HostHistoryManager.shared
    @StateObject private var languageManager = LanguageManager.shared
    @State private var hostInput = "www.qq.com"
    @State private var probeCount: Int = 3
    @State private var showHistory = false
    @State private var showCopyToast = false
    @FocusState private var isInputFocused: Bool
    
    private var l10n: L10n { L10n.shared }
    
    // 判断是否为 IPv6 相关错误
    private func isIPv6Error(_ error: String) -> Bool {
        error.contains("IPv6") || error.contains("ipv6")
    }
    
    // 快捷输入按钮
    private let quickInputs = ["www.", ".com", ".cn", ".net"]
    // 默认快捷主机
    private let defaultHosts = ["www.qq.com", "www.baidu.com", "www.google.com", "www.apple.com", "2001:4860:4860::8888"]
    
    // 计算 IP 列的动态宽度（基于最长的 IP 地址）
    private var ipColumnWidth: CGFloat {
        let minWidth: CGFloat = 120
        let maxIP = traceManager.hops.map { $0.ip }.max(by: { $0.count < $1.count }) ?? ""
        // 等宽字体每个字符约 7pt（11号字体）
        let calculatedWidth = CGFloat(maxIP.count) * 7 + 8
        return max(minWidth, calculatedWidth)
    }
    
    // 计算总最小宽度
    private var totalMinWidth: CGFloat {
        // #(24) + IP(动态) + 延迟(60) + 丢包(40) + 归属地(150) + spacing(8*4) + padding
        return 24 + ipColumnWidth + 60 + 40 + 150 + 32 + 16
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // 输入框
            VStack(spacing: 8) {
                HStack {
                    ZStack(alignment: .trailing) {
                        TextField(l10n.enterHostOrIPPlaceholder, text: $hostInput)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.asciiCapable)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .focused($isInputFocused)
                            .onSubmit {
                                startTrace()
                            }
                        
                        if !hostInput.isEmpty {
                            Button {
                                hostInput = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .padding(.trailing, 8)
                        }
                    }
                    
                    // 历史记录按钮
                    if !historyManager.traceHistory.isEmpty {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showHistory.toggle()
                            }
                        } label: {
                            Image(systemName: showHistory ? "chevron.up" : "clock.arrow.circlepath")
                                .foregroundColor(.purple)
                                .frame(width: 32, height: 32)
                        }
                    }
                    
                    Button(action: {
                        isInputFocused = false
                        if traceManager.isTracing {
                            traceManager.stopTrace()
                        } else {
                            startTrace()
                        }
                    }) {
                        Image(systemName: traceManager.isTracing ? "stop.fill" : "play.fill")
                            .foregroundColor(.white)
                            .frame(width: 44, height: 36)
                            .background(traceManager.isTracing ? Color.red : Color.purple)
                            .cornerRadius(8)
                    }
                }
                
                // 快捷输入按钮
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(quickInputs, id: \.self) { input in
                            Button {
                                insertQuickInput(input)
                            } label: {
                                Text(input)
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                    .foregroundColor(.purple)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.purple.opacity(0.1))
                                    .cornerRadius(6)
                            }
                        }
                    }
                }
                
                // 历史记录列表
                if showHistory && !historyManager.traceHistory.isEmpty {
                    traceHistoryListView
                }
            }
            .padding(.horizontal)
            
            // 探测次数配置
            HStack {
                Text(l10n.probesPerHop)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Picker("", selection: $probeCount) {
                    Text("3").tag(3)
                    Text("5").tag(5)
                    Text("10").tag(10)
                    Text("20").tag(20)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                .onChange(of: probeCount) { _, newValue in
                    traceManager.probesPerHop = newValue
                }
                Spacer()
            }
            .padding(.horizontal)
            
            // IP 协议选择
            HStack {
                Text(l10n.ipProtocol)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Picker("", selection: $traceManager.protocolPreference) {
                    ForEach(IPProtocolPreference.allCases, id: \.self) { preference in
                        Text(preference.displayName).tag(preference)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                Spacer()
            }
            .padding(.horizontal)
            
            // 状态指示
            if traceManager.isTracing || traceManager.isComplete || !traceManager.targetIP.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    // 目标 IP
                    if !traceManager.targetIP.isEmpty {
                        HStack {
                            Text(l10n.targetIPLabel)
                                .foregroundColor(.secondary)
                            Text(traceManager.targetIP)
                                .foregroundColor(.blue)
                                .fontWeight(.medium)
                        }
                        .font(.caption)
                    }
                    
                    HStack {
                        if traceManager.isTracing {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text(l10n.tracingRoute)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else if traceManager.isComplete {
                            if traceManager.isFetchingLocation {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text(l10n.fetchingLocation)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("\(l10n.traceComplete) - \(traceManager.hops.count) \(l10n.hops)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal)
            }
            
            // 结果列表
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("$ traceroute \(traceManager.isTracing || traceManager.isComplete ? traceManager.currentHost : hostInput)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.green)
                    Spacer()
                    
                    // 一键复制按钮
                    if !traceManager.hops.isEmpty {
                        Button {
                            copyTraceResults()
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.caption)
                                .foregroundColor(.purple)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.9))
                
                // 表头（固定在顶部）
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Text("#")
                            .frame(width: 24, alignment: .trailing)
                        Text("IP")
                            .frame(width: ipColumnWidth, alignment: .leading)
                        Text(l10n.delayHeader)
                            .frame(width: 60, alignment: .leading)
                        Text(l10n.lossHeader)
                            .frame(width: 40, alignment: .leading)
                        Text(l10n.locationHeader)
                            .frame(width: 150, alignment: .leading)
                    }
                    .frame(minWidth: totalMinWidth)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.gray.opacity(0.7))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                .background(Color.black.opacity(0.8))
                
                // 支持水平滚动的内容区域
                GeometryReader { geometry in
                    ScrollView([.horizontal, .vertical], showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(traceManager.hops) { hop in
                                TraceHopRow(hop: hop, ipWidth: ipColumnWidth)
                            }
                            
                            // 错误信息显示在终端中
                            if let error = traceManager.errorMessage {
                                Text(error)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(isIPv6Error(error) ? .yellow : .red)
                                    .padding(.horizontal)
                                    .padding(.bottom)
                            }
                            // 空状态提示
                            else if traceManager.hops.isEmpty && !traceManager.isTracing {
                                Text(l10n.traceHint)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.gray)
                                    .padding()
                            }
                        }
                        .frame(minWidth: max(totalMinWidth, geometry.size.width), minHeight: geometry.size.height, alignment: .topLeading)
                        .padding(8)
                    }
                }
                .background(Color.black)
            }
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(.systemGray3), lineWidth: 1)
            )
            .padding(.horizontal)
            
            // 快捷主机
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // 历史记录（最多3条）
                    ForEach(historyManager.traceHistory.prefix(3), id: \.self) { host in
                        HistoryHostChip(host: host, current: $hostInput, isHistory: true)
                    }
                    
                    // 分隔线
                    if !historyManager.traceHistory.isEmpty {
                        Divider().frame(height: 20)
                    }
                    
                    // 默认主机
                    ForEach(defaultHosts, id: \.self) { host in
                        if !historyManager.traceHistory.prefix(3).contains(host) {
                            QuickHostChip(host: host, current: $hostInput)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .navigationTitle("Traceroute")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(
            Group {
                if showCopyToast {
                    CopyToastView()
                        .transition(.opacity.combined(with: .scale))
                }
            }
        )
    }
    
    private func insertQuickInput(_ input: String) {
        if input.hasPrefix(".") {
            hostInput += input
        } else if input.hasSuffix(".") {
            if !hostInput.hasPrefix(input) {
                hostInput = input + hostInput
            }
        }
    }
    
    // Trace 历史记录列表视图
    private var traceHistoryListView: some View {
        VStack(spacing: 0) {
            ForEach(historyManager.traceHistory, id: \.self) { host in
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Text(host)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Spacer()
                    
                    Button {
                        historyManager.removeTraceHistory(host)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
                .onTapGesture {
                    hostInput = host
                    showHistory = false
                }
                
                if host != historyManager.traceHistory.last {
                    Divider().padding(.leading, 36)
                }
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private func startTrace() {
        guard !hostInput.isEmpty else { return }
        historyManager.addTraceHistory(hostInput)
        traceManager.startTrace(host: hostInput)
    }
    
    private func copyTraceResults() {
        // 转换 hops 数据格式（包含 hostname）
        let hopsData = traceManager.hops.map { hop in
            (
                hop: hop.hop,
                ip: hop.ip,
                hostname: hop.hostname,
                avgLatency: hop.avgLatency,
                lossRate: hop.lossRate,
                sentCount: hop.sentCount,
                receivedCount: hop.receivedCount,
                location: hop.location
            )
        }
        
        // 使用 ReportDataBuilder 构建格式化文本
        let data = ReportDataBuilder.buildTraceData(
            target: traceManager.currentHost,
            hops: hopsData,
            reachedTarget: traceManager.isComplete,
            source: .history,
            timestamp: Date(),
            duration: nil,
            errorMessage: traceManager.errorMessage,
            ipInfo: nil
        )
        
        if let resultText = data["ResultToText"] as? String {
            UIPasteboard.general.string = resultText
        }
        showCopyToastAnimation()
    }
    
    private func showCopyToastAnimation() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showCopyToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showCopyToast = false
            }
        }
    }
}

// MARK: - 跳点行视图
struct TraceHopRow: View {
    let hop: TraceHop
    let ipWidth: CGFloat
    
    private var statusColor: Color {
        switch hop.status {
        case .success: return .green
        case .timeout: return .orange
        case .error: return .red
        }
    }
    
    private var lossColor: Color {
        if hop.lossRate == 0 {
            return .green
        } else if hop.lossRate < 50 {
            return .yellow
        } else {
            return .red
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // 跳数
            Text(String(format: "%2d", hop.hop))
                .foregroundColor(.gray)
                .frame(width: 24, alignment: .trailing)
            
            // IP 地址和主机名
            VStack(alignment: .leading, spacing: 1) {
                Text(hop.ip)
                    .foregroundColor(hop.ip == "*" ? .orange : .cyan)
                    .lineLimit(1)
                
                // 显示主机名（如果有且与 IP 不同）
                if let hostname = hop.hostname, !hostname.isEmpty {
                    Text(hostname)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
            }
            .frame(width: ipWidth, alignment: .leading)
            
            // 延迟
            if let latency = hop.avgLatency {
                Text(String(format: "%.1fms", latency * 1000))
                    .foregroundColor(statusColor)
                    .frame(width: 60, alignment: .leading)
            } else {
                Text("*")
                    .foregroundColor(.orange)
                    .frame(width: 60, alignment: .leading)
            }
            
            // 丢包率
            Text(String(format: "%.0f%%", hop.lossRate))
                .foregroundColor(lossColor)
                .frame(width: 40, alignment: .leading)
            
            // 归属地（放在最后）
            if let location = hop.location, !location.isEmpty {
                Text(location)
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 150, alignment: .leading)
            } else {
                Text(hop.ip == "*" ? "-" : "...")
                    .foregroundColor(.gray)
                    .frame(width: 150, alignment: .leading)
            }
        }
        .font(.system(size: 11, design: .monospaced))
        .id(hop.id)
    }
}

#Preview {
    NavigationStack {
        TraceView()
    }
}
