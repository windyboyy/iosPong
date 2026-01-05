//
//  PingView.swift
//  Pong
//
//  Created by 张金琛 on 2025/12/12.
//

import SwiftUI

struct PingView: View {
    @EnvironmentObject var languageManager: LanguageManager
    @StateObject private var pingManager = PingManager.shared
    @StateObject private var historyManager = HostHistoryManager.shared
    @State private var hostInput = "www.qq.com"
    @State private var packetSize: Int = 56
    @State private var interval: Double = 0.2
    @State private var showHistory = false
    @State private var showCopyToast = false
    @State private var showInfoAlert = false
    @FocusState private var isInputFocused: Bool
    
    // 最大 Ping 次数
    private let maxPingCount = 200
    
    private var l10n: L10n { L10n.shared }
    
    // 快捷输入按钮
    private let quickInputs = ["www.", ".com", ".cn", ".net"]
    // 默认快捷主机
    private let defaultHosts = ["www.qq.com", "www.baidu.com", "8.8.8.8", "www.apple.com", "2001:4860:4860::8888"]
    
    var body: some View {
        VStack(spacing: 16) {
            // 输入框
            VStack(spacing: 8) {
                HStack {
                    ZStack(alignment: .trailing) {
                        TextField(l10n.enterHostOrIP, text: $hostInput)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.asciiCapable)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .focused($isInputFocused)
                            .onSubmit {
                                startPing()
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
                    if !historyManager.pingHistory.isEmpty {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showHistory.toggle()
                            }
                        } label: {
                            Image(systemName: showHistory ? "chevron.up" : "clock.arrow.circlepath")
                                .foregroundColor(.blue)
                                .frame(width: 32, height: 32)
                        }
                    }
                    
                    Button(action: {
                        isInputFocused = false
                        if pingManager.isPinging {
                            pingManager.stopPing()
                        } else {
                            startPing()
                        }
                    }) {
                        Image(systemName: pingManager.isPinging ? "stop.fill" : "play.fill")
                            .foregroundColor(.white)
                            .frame(width: 44, height: 36)
                            .background(pingManager.isPinging ? Color.red : Color.blue)
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
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(6)
                            }
                        }
                    }
                }
                
                // 历史记录列表
                if showHistory && !historyManager.pingHistory.isEmpty {
                    historyListView
                }
            }
            .padding(.horizontal)
            
            // 设置选项
            VStack(spacing: 8) {
                HStack(spacing: 16) {
                    // 发包大小
                    HStack(spacing: 4) {
                        Text(l10n.packetSize)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("", selection: $packetSize) {
                            Text("56").tag(56)
                            Text("128").tag(128)
                            Text("512").tag(512)
                            Text("1024").tag(1024)
                        }
                        .pickerStyle(.menu)
                        .onChange(of: packetSize) { _, newValue in
                            pingManager.packetSize = newValue
                        }
                    }
                    
                    // 发包间隔
                    HStack(spacing: 4) {
                        Text(l10n.interval)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("", selection: $interval) {
                            Text("0.2s").tag(0.2)
                            Text("0.5s").tag(0.5)
                            Text("1s").tag(1.0)
                            Text("2s").tag(2.0)
                        }
                        .pickerStyle(.menu)
                        .onChange(of: interval) { _, newValue in
                            pingManager.interval = newValue
                        }
                    }
                    
                    Spacer()
                }
                
                // IP 协议选择
                HStack {
                    Text(l10n.ipProtocol)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Picker("", selection: $pingManager.protocolPreference) {
                        ForEach(IPProtocolPreference.allCases, id: \.self) { preference in
                            Text(preference.displayName).tag(preference)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                    Spacer()
                }
            }
            .padding(.horizontal)
            
            // 统计信息
            if pingManager.statistics.sent > 0 {
                PingStatisticsView(stats: pingManager.statistics)
                    .padding(.horizontal)
            }
            
            // 结果列表
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("$ ping \(pingManager.isPinging ? pingManager.currentHost : hostInput)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.green)
                    Spacer()
                    if pingManager.isPinging {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                    
                    // 一键复制按钮
                    if !pingManager.results.isEmpty {
                        Button {
                            copyPingResults()
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.9))
                
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(pingManager.results) { result in
                                PingResultRow(result: result)
                            }
                            
                            // 统计摘要（停止后显示完整终端风格输出）
                            if !pingManager.isPinging && pingManager.statistics.sent > 0 {
                                PingSummaryView(
                                    host: pingManager.currentHost,
                                    ip: pingManager.resolvedIP.isEmpty ? pingManager.currentHost : pingManager.resolvedIP,
                                    packetSize: pingManager.packetSize,
                                    results: pingManager.results,
                                    stats: pingManager.statistics
                                )
                                .id("summary")
                            }
                            
                            // 空状态提示
                            if pingManager.results.isEmpty && !pingManager.isPinging {
                                Text(l10n.pingHint)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.gray)
                                    .padding()
                            }
                        }
                        .padding(8)
                    }
                    .onChange(of: pingManager.results.count) { _ in
                        if let last = pingManager.results.last {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: pingManager.isPinging) { _, isPinging in
                        if !isPinging {
                            withAnimation {
                                proxy.scrollTo("summary", anchor: .bottom)
                            }
                        }
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
                    ForEach(historyManager.pingHistory.prefix(3), id: \.self) { host in
                        HistoryHostChip(host: host, current: $hostInput, isHistory: true)
                    }
                    
                    // 分隔线
                    if !historyManager.pingHistory.isEmpty {
                        Divider().frame(height: 20)
                    }
                    
                    // 默认主机
                    ForEach(defaultHosts, id: \.self) { host in
                        if !historyManager.pingHistory.prefix(3).contains(host) {
                            QuickHostChip(host: host, current: $hostInput)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .navigationTitle("Ping")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showInfoAlert = true
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                }
            }
        }
        .alert(l10n.pingInfoTitle, isPresented: $showInfoAlert) {
            Button(l10n.gotIt, role: .cancel) { }
        } message: {
            Text(l10n.pingInfoMessage)
        }
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
    
    // 历史记录列表视图
    private var historyListView: some View {
        VStack(spacing: 0) {
            ForEach(historyManager.pingHistory, id: \.self) { host in
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Text(host)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Spacer()
                    
                    Button {
                        historyManager.removePingHistory(host)
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
                
                if host != historyManager.pingHistory.last {
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
    
    private func startPing() {
        guard !hostInput.isEmpty else { return }
        historyManager.addPingHistory(hostInput)
        pingManager.startPing(host: hostInput, count: maxPingCount)
    }
    
    private func copyPingResults() {
        var lines: [String] = []
        let ip = pingManager.resolvedIP.isEmpty ? pingManager.currentHost : pingManager.resolvedIP
        
        lines.append("PING \(pingManager.currentHost) (\(ip)): \(pingManager.packetSize) data bytes")
        
        for result in pingManager.results {
            switch result.status {
            case .success:
                if let latency = result.latency {
                    lines.append("\(pingManager.packetSize + 8) bytes from \(result.ip): icmp_seq=\(result.sequence) ttl=64 time=\(String(format: "%.3f", latency * 1000)) ms")
                } else {
                    lines.append("\(pingManager.packetSize + 8) bytes from \(result.ip): icmp_seq=\(result.sequence) ttl=64")
                }
            case .timeout:
                lines.append("Request timeout for icmp_seq \(result.sequence)")
            case .error(let msg):
                lines.append("Error: \(msg)")
            }
        }
        
        let stats = pingManager.statistics
        if stats.sent > 0 {
            lines.append("--- \(pingManager.currentHost) ping statistics ---")
            lines.append("\(stats.sent) packets transmitted, \(stats.received) packets received, \(String(format: "%.1f", stats.lossRate))% packet loss")
            if stats.received > 0 {
                lines.append("round-trip min/avg/max/stddev = \(String(format: "%.3f", stats.minLatency * 1000))/\(String(format: "%.3f", stats.avgLatency * 1000))/\(String(format: "%.3f", stats.maxLatency * 1000))/\(String(format: "%.3f", stats.stddevLatency * 1000)) ms")
            }
        }
        
        UIPasteboard.general.string = lines.joined(separator: "\n")
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

// MARK: - Ping 统计视图
struct PingStatisticsView: View {
    @EnvironmentObject var languageManager: LanguageManager
    let stats: PingStatistics
    
    private var l10n: L10n { L10n.shared }
    
    var body: some View {
        HStack(spacing: 12) {
            StatItem(title: l10n.sent, value: "\(stats.sent)", color: .blue)
            StatItem(title: l10n.received, value: "\(stats.received)", color: .green)
            StatItem(title: l10n.lost, value: String(format: "%.0f%%", stats.lossRate), color: stats.lost > 0 ? .red : .gray)
            StatItem(title: l10n.average, value: String(format: "%.1fms", stats.avgLatency * 1000), color: .orange)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct StatItem: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.headline, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Ping 结果行
struct PingResultRow: View {
    let result: PingResult
    
    // 判断是否为 IPv6 相关错误
    private func isIPv6Error(_ msg: String) -> Bool {
        msg.contains("IPv6") || msg.contains("ipv6")
    }
    
    private var statusColor: Color {
        switch result.status {
        case .success: return .green
        case .timeout: return .orange
        case .error(let msg): return isIPv6Error(msg) ? .yellow : .red
        }
    }
    
    var body: some View {
        HStack {
            Text("[\(result.sequence)]")
                .foregroundColor(.gray)
            
            Text(result.ip)
                .foregroundColor(.cyan)
            
            Text(":")
                .foregroundColor(.gray)
            
            Text(result.statusText)
                .foregroundColor(statusColor)
            
            Spacer()
        }
        .font(.system(size: 12, design: .monospaced))
        .id(result.id)
    }
}

// MARK: - Ping 统计摘要视图（完整终端风格输出）
struct PingSummaryView: View {
    let host: String
    let ip: String
    let packetSize: Int
    let results: [PingResult]
    let stats: PingStatistics
    
    private var responseSize: Int {
        packetSize + 8  // ICMP header 8 bytes
    }
    
    // 判断是否为 IPv6 相关错误
    private func isIPv6Error(_ msg: String) -> Bool {
        msg.contains("IPv6") || msg.contains("ipv6")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Divider()
                .background(Color.gray)
                .padding(.vertical, 8)
            
            // 完整的终端风格输出
            Text("PING \(host) (\(ip)): \(packetSize) data bytes")
                .foregroundColor(.white)
            
            ForEach(results) { result in
                resultLine(result)
            }
            
            Text("^C")
                .foregroundColor(.white)
            Text("--- \(host) ping statistics ---")
                .foregroundColor(.white)
            Text("\(stats.sent) packets transmitted, \(stats.received) packets received, \(String(format: "%.1f", stats.lossRate))% packet loss")
                .foregroundColor(.white)
            
            if stats.received > 0 {
                let minMs = stats.minLatency * 1000
                let avgMs = stats.avgLatency * 1000
                let maxMs = stats.maxLatency * 1000
                let stddevMs = stats.stddevLatency * 1000
                Text("round-trip min/avg/max/stddev = \(String(format: "%.3f", minMs))/\(String(format: "%.3f", avgMs))/\(String(format: "%.3f", maxMs))/\(String(format: "%.3f", stddevMs)) ms")
                    .foregroundColor(.white)
            }
        }
        .font(.system(size: 12, design: .monospaced))
    }
    
    @ViewBuilder
    private func resultLine(_ result: PingResult) -> some View {
        switch result.status {
        case .success:
            if let latency = result.latency {
                Text("\(responseSize) bytes from \(result.ip): icmp_seq=\(result.sequence) ttl=64 time=\(String(format: "%.3f", latency * 1000)) ms")
                    .foregroundColor(.white)
            } else {
                Text("\(responseSize) bytes from \(result.ip): icmp_seq=\(result.sequence) ttl=64")
                    .foregroundColor(.white)
            }
        case .timeout:
            Text("Request timeout for icmp_seq \(result.sequence)")
                .foregroundColor(.orange)
        case .error(let msg):
            Text("Error: \(msg)")
                .foregroundColor(isIPv6Error(msg) ? .yellow : .red)
        }
    }
}

// MARK: - 快捷主机标签
struct QuickHostChip: View {
    let host: String
    @Binding var current: String
    
    var body: some View {
        Button(action: {
            current = host
        }) {
            Text(host)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(current == host ? Color.blue : Color(.systemGray5))
                .foregroundColor(current == host ? .white : .primary)
                .cornerRadius(16)
        }
    }
}

#Preview {
    NavigationStack {
        PingView()
            .environmentObject(LanguageManager.shared)
    }
}
