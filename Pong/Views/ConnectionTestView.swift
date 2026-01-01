//
//  ConnectionTestView.swift
//  Pong
//
//  Created by 张金琛 on 2025/12/31.
//

import SwiftUI

struct ConnectionTestView: View {
    @EnvironmentObject var languageManager: LanguageManager
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var manager = ConnectionTestManager.shared
    @StateObject private var historyManager = HostHistoryManager.shared
    @State private var domainInput = "www.qq.com"
    @State private var portInput = "443"
    @State private var showHistory = false
    @FocusState private var isInputFocused: Bool
    
    private var l10n: L10n { L10n.shared }
    
    // 默认快捷域名
    private let defaultDomains = ["www.qq.com", "www.baidu.com", "www.google.com", "github.com", "apple.com"]
    
    // 渐变色
    private var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [Color.cyan, Color.blue],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 输入区域卡片
                inputCard
                
                // 功能说明（仅在没有测试结果时显示）
                if manager.results.isEmpty && !manager.isTesting {
                    featureIntroCard
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
                
                // 快捷域名
                quickDomainsSection
                
                // 结果列表
                resultsSection
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(l10n.connectionTest)
        .navigationBarTitleDisplayMode(.inline)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: manager.isTesting)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: manager.currentResult != nil)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: manager.results.isEmpty)
    }
    
    // MARK: - 功能说明卡片
    private var featureIntroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "info.circle.fill")
                    .font(.title2)
                    .foregroundColor(.cyan)
                Text(l10n.connectionTestIntro)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(icon: "network", color: .blue, text: l10n.connectionTestFeature1)
                FeatureRow(icon: "bolt.horizontal", color: .green, text: l10n.connectionTestFeature2)
                FeatureRow(icon: "chart.bar.fill", color: .purple, text: l10n.connectionTestFeature3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(colorScheme == .dark ? Color(.secondarySystemBackground) : Color(.systemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 10, x: 0, y: 4)
        .padding(.horizontal)
    }
    
    // MARK: - 输入卡片
    private var inputCard: some View {
        VStack(spacing: 16) {
            // 域名输入
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "globe")
                        .foregroundColor(domainInput.isEmpty ? .secondary : .cyan)
                    Text(l10n.targetDomain)
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
                HStack(spacing: 12) {
                    // 域名输入框
                    HStack {
                        TextField(l10n.enterDomain, text: $domainInput)
                            .keyboardType(.asciiCapable)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .focused($isInputFocused)
                            .onSubmit { startTest() }
                        
                        if !domainInput.isEmpty {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    domainInput = ""
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .font(.subheadline)
                            }
                        }
                    }
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isInputFocused ? Color.cyan : Color.clear, lineWidth: 1.5)
                    )
                    
                    // 端口输入
                    TextField("443", text: $portInput)
                        .keyboardType(.numberPad)
                        .frame(width: 50)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 12)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    
                    // 历史记录按钮
                    if !historyManager.connectionTestHistory.isEmpty {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showHistory.toggle()
                            }
                        } label: {
                            Image(systemName: showHistory ? "chevron.up.circle.fill" : "clock.arrow.circlepath")
                                .font(.title3)
                                .foregroundColor(.cyan)
                                .frame(width: 44, height: 44)
                                .background(Color.cyan.opacity(0.1))
                                .cornerRadius(10)
                        }
                    }
                }
            }
            
            // 历史记录列表
            if showHistory && !historyManager.connectionTestHistory.isEmpty {
                historyListView
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
            
            // 测试按钮
            Button(action: {
                isInputFocused = false
                if manager.isTesting {
                    manager.stopTest()
                } else {
                    startTest()
                }
            }) {
                HStack(spacing: 10) {
                    Image(systemName: manager.isTesting ? "stop.fill" : "bolt.horizontal.fill")
                        .font(.headline)
                    Text(manager.isTesting ? l10n.stop : l10n.startTest)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    Group {
                        if manager.isTesting {
                            Color.red
                        } else {
                            primaryGradient
                        }
                    }
                )
                .cornerRadius(12)
                .shadow(color: (manager.isTesting ? Color.red : Color.cyan).opacity(0.4), radius: 8, x: 0, y: 4)
            }
            .scaleEffect(manager.isTesting ? 0.98 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: manager.isTesting)
        }
        .padding(16)
        .background(colorScheme == .dark ? Color(.secondarySystemBackground) : Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 10, x: 0, y: 4)
        .padding(.horizontal)
    }
    
    // MARK: - 快捷域名
    private var quickDomainsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(l10n.quickAccess)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    // 历史记录（最多3条）
                    ForEach(historyManager.connectionTestHistory.prefix(3), id: \.self) { host in
                        QuickDomainButton(
                            domain: host,
                            isHistory: true,
                            isSelected: domainInput == host
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                domainInput = host
                            }
                        }
                    }
                    
                    // 分隔线
                    if !historyManager.connectionTestHistory.isEmpty {
                        Rectangle()
                            .fill(Color(.systemGray4))
                            .frame(width: 1, height: 24)
                    }
                    
                    // 默认域名
                    ForEach(defaultDomains, id: \.self) { domain in
                        if !historyManager.connectionTestHistory.prefix(3).contains(domain) {
                            QuickDomainButton(
                                domain: domain,
                                isHistory: false,
                                isSelected: domainInput == domain
                            ) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    domainInput = domain
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - 结果列表
    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "list.bullet.rectangle.portrait")
                        .foregroundColor(.cyan)
                    Text(l10n.testResults)
                        .font(.headline)
                }
                
                Spacer()
                
                if !manager.results.isEmpty {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            manager.clearHistory()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                                .font(.caption)
                            Text(l10n.clear)
                                .font(.caption)
                        }
                        .foregroundColor(.red)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(6)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            if manager.results.isEmpty && manager.currentResult == nil {
                // 空状态
                VStack(spacing: 16) {
                    Image(systemName: "bolt.horizontal.circle")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary.opacity(0.4))
                    
                    Text(l10n.enterDomainToTest)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 50)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(manager.results) { result in
                        ConnectionTestResultCard(result: result)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.95).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .background(colorScheme == .dark ? Color(.secondarySystemBackground) : Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.05), radius: 8, x: 0, y: 2)
        .padding(.horizontal)
    }
    
    // MARK: - 历史记录列表
    private var historyListView: some View {
        VStack(spacing: 0) {
            ForEach(historyManager.connectionTestHistory, id: \.self) { host in
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.cyan.opacity(0.7))
                        .font(.caption)
                    Text(host)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Spacer()
                    
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            historyManager.removeConnectionTestHistory(host)
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary.opacity(0.6))
                            .font(.subheadline)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        domainInput = host
                        showHistory = false
                    }
                }
                
                if host != historyManager.connectionTestHistory.last {
                    Divider().padding(.leading, 40)
                }
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    private func startTest() {
        guard !domainInput.isEmpty else { return }
        historyManager.addConnectionTestHistory(domainInput)
        let port = Int(portInput) ?? 443
        manager.startTest(domain: domainInput, port: port)
    }
}

// MARK: - 快捷域名按钮
struct QuickDomainButton: View {
    let domain: String
    let isHistory: Bool
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isHistory {
                    Image(systemName: "clock.fill")
                        .font(.caption2)
                }
                Text(domain)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .white : (isHistory ? .cyan : .primary))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Group {
                    if isSelected {
                        LinearGradient(
                            colors: [Color.cyan, Color.blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else {
                        Color(.systemGray6)
                    }
                }
            )
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(!isSelected ? Color(.systemGray4) : Color.clear, lineWidth: 1)
            )
        }
    }
}

// MARK: - 结果卡片
struct ConnectionTestResultCard: View {
    let result: ConnectionTestResult
    @Environment(\.colorScheme) private var colorScheme
    @State private var isExpanded = true
    
    private var l10n: L10n { L10n.shared }
    
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()
    
    // DNS 是否正在解析
    private var isDNSLoading: Bool {
        result.dnsLatency == 0 && result.ipv4Addresses.isEmpty && result.ipv6Addresses.isEmpty
    }
    
    // 是否正在测试中（整体）
    private var isTesting: Bool {
        isDNSLoading || (result.ipv4Latency == nil && result.ipv4Error == nil && !result.ipv4Addresses.isEmpty) ||
        (result.ipv6Latency == nil && result.ipv6Error == nil && !result.ipv6Addresses.isEmpty)
    }
    
    // 状态颜色
    private var statusColor: Color {
        if isTesting {
            // 测试中 - 蓝色
            return .cyan
        } else if result.preferredProtocol != nil {
            // 有可用协议 - 绿色
            return .green
        } else if result.ipv4Latency == nil && result.ipv6Latency == nil &&
                  (result.ipv4Error != nil || result.ipv6Error != nil) {
            // 完全不通 - 红色
            return .red
        } else {
            // 部分问题 - 橙色
            return .orange
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 头部 - 可点击展开/收起
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    // 状态指示条
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [statusColor, statusColor.opacity(0.6)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 4, height: 40)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.domain)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 8) {
                            // 结论标签
                            if isTesting {
                                HStack(spacing: 4) {
                                    ProgressView()
                                        .scaleEffect(0.6)
                                    Text(l10n.connecting)
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(statusColor))
                            } else {
                                Text(result.conclusion)
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(statusColor))
                            }
                            
                            // DNS 延迟（仅在解析完成后显示）
                            if !isDNSLoading {
                                HStack(spacing: 3) {
                                    Image(systemName: "server.rack")
                                        .font(.caption2)
                                    Text(String(format: "%.0fms", result.dnsLatency * 1000))
                                        .font(.caption2)
                                }
                                .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(Self.timeFormatter.string(from: result.timestamp))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .rotationEffect(.degrees(isExpanded ? 0 : -90))
                    }
                }
                .padding(14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                VStack(spacing: 0) {
                    Divider().padding(.leading, 16)
                    
                    // DNS 解析结果
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("DNS " + l10n.resolution, systemImage: "server.rack")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.cyan)
                            
                            Text(l10n.systemDNS)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(.systemGray5))
                                .cornerRadius(4)
                            
                            Spacer()
                            
                            // DNS 解析中显示 loading
                            if isDNSLoading {
                                ProgressView()
                                    .scaleEffect(0.7)
                            }
                        }
                        
                        // DNS 记录
                        if isDNSLoading {
                            HStack {
                                Text(l10n.resolvingDNS)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 6) {
                                if !result.cnameRecords.isEmpty {
                                    ForEach(result.cnameRecords, id: \.self) { cname in
                                        DNSRecordRow(type: "CNAME", value: cname, color: .orange)
                                    }
                                }
                                
                                if !result.ipv4Addresses.isEmpty {
                                    ForEach(result.ipv4Addresses, id: \.self) { ip in
                                        DNSRecordRow(type: "A", value: ip, color: .green)
                                    }
                                }
                                
                                if !result.ipv6Addresses.isEmpty {
                                    ForEach(result.ipv6Addresses, id: \.self) { ip in
                                        DNSRecordRow(type: "AAAA", value: ip, color: .purple)
                                    }
                                }
                                
                                // 如果没有任何记录
                                if result.cnameRecords.isEmpty && result.ipv4Addresses.isEmpty && result.ipv6Addresses.isEmpty {
                                    Text(l10n.noRecord)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding(14)
                    .background(Color(.systemGray6).opacity(0.5))
                    
                    Divider().padding(.leading, 16)
                    
                    // 连接测试结果
                    HStack(spacing: 0) {
                        // IPv4 结果
                        ConnectionResultCell(
                            title: "IPv4",
                            latency: result.ipv4Latency,
                            error: result.ipv4Error,
                            hasRecord: !result.ipv4Addresses.isEmpty,
                            isPreferred: result.preferredProtocol == .ipv4
                        )
                        
                        Rectangle()
                            .fill(Color(.systemGray4))
                            .frame(width: 1)
                            .padding(.vertical, 8)
                        
                        // IPv6 结果
                        ConnectionResultCell(
                            title: "IPv6",
                            latency: result.ipv6Latency,
                            error: result.ipv6Error,
                            hasRecord: !result.ipv6Addresses.isEmpty,
                            isPreferred: result.preferredProtocol == .ipv6
                        )
                    }
                    .frame(height: 70)
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity
                ))
            }
        }
        .background(colorScheme == .dark ? Color(.secondarySystemBackground) : Color(.systemBackground))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    LinearGradient(
                        colors: [statusColor.opacity(0.4), statusColor.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: statusColor.opacity(colorScheme == .dark ? 0.2 : 0.15), radius: 8, x: 0, y: 4)
    }
}

// MARK: - DNS 记录行
struct DNSRecordRow: View {
    let type: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Text(type)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 44)
                .padding(.vertical, 3)
                .background(color.opacity(0.8))
                .cornerRadius(4)
            
            Text(value)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
}

// MARK: - 连接结果单元格
struct ConnectionResultCell: View {
    let title: String
    let latency: TimeInterval?
    let error: String?
    let hasRecord: Bool
    let isPreferred: Bool
    
    private var l10n: L10n { L10n.shared }
    
    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                
                if isPreferred {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundColor(.yellow)
                }
            }
            
            if !hasRecord {
                Text(l10n.noRecord)
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if let latency = latency {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.subheadline)
                    Text(String(format: "%.0fms", latency * 1000))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(latencyColor(latency))
                }
            } else if let error = error {
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                    Text(error)
                        .font(.caption2)
                        .foregroundColor(.red)
                        .lineLimit(1)
                }
            } else {
                ProgressView()
                    .scaleEffect(0.7)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
    
    private func latencyColor(_ latency: TimeInterval) -> Color {
        let ms = latency * 1000
        if ms < 50 {
            return .green
        } else if ms < 150 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - 功能说明行
struct FeatureRow: View {
    let icon: String
    let color: Color
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.8))
                .cornerRadius(6)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        ConnectionTestView()
            .environmentObject(LanguageManager.shared)
    }
}
