//
//  ConnectionTestView.swift
//  Pong
//
//  Created by 张金琛 on 2025/12/31.
//

import SwiftUI

struct ConnectionTestView: View {
    @EnvironmentObject var languageManager: LanguageManager
    @StateObject private var manager = ConnectionTestManager.shared
    @StateObject private var historyManager = HostHistoryManager.shared
    @State private var domainInput = "www.qq.com"
    @State private var portInput = "443"
    @State private var showHistory = false
    @FocusState private var isInputFocused: Bool
    
    private var l10n: L10n { L10n.shared }
    
    // 默认快捷域名
    private let defaultDomains = ["www.qq.com", "www.baidu.com", "www.google.com", "github.com", "apple.com"]
    
    var body: some View {
        VStack(spacing: 16) {
            // 输入区域
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    // 域名输入
                    ZStack(alignment: .trailing) {
                        TextField(l10n.enterDomain, text: $domainInput)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.asciiCapable)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .focused($isInputFocused)
                            .onSubmit {
                                startTest()
                            }
                        
                        if !domainInput.isEmpty {
                            Button {
                                domainInput = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .padding(.trailing, 8)
                        }
                    }
                    
                    // 端口输入
                    TextField("443", text: $portInput)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                        .frame(width: 60)
                    
                    // 历史记录按钮
                    if !historyManager.connectionTestHistory.isEmpty {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showHistory.toggle()
                            }
                        } label: {
                            Image(systemName: showHistory ? "chevron.up" : "clock.arrow.circlepath")
                                .foregroundColor(.cyan)
                                .frame(width: 32, height: 32)
                        }
                    }
                }
                
                // 历史记录列表
                if showHistory && !historyManager.connectionTestHistory.isEmpty {
                    historyListView
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
                    HStack {
                        Image(systemName: manager.isTesting ? "stop.fill" : "bolt.fill")
                        Text(manager.isTesting ? l10n.stop : l10n.startTest)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(manager.isTesting ? Color.red : Color.cyan)
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal)
            
            // 当前测试状态
            if manager.isTesting || manager.currentResult != nil {
                currentTestView
            }
            
            // 结果列表
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(l10n.testResults)
                        .font(.headline)
                    Spacer()
                    
                    if !manager.results.isEmpty {
                        Button(action: {
                            manager.clearHistory()
                        }) {
                            Text(l10n.clear)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(manager.results) { result in
                            ConnectionTestResultCard(result: result)
                        }
                        
                        if manager.results.isEmpty && manager.currentResult == nil {
                            Text(l10n.enterDomainToTest)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 40)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .background(Color(.systemGroupedBackground))
            .cornerRadius(12)
            .padding(.horizontal)
            
            // 快捷域名
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // 历史记录（最多3条）
                    ForEach(historyManager.connectionTestHistory.prefix(3), id: \.self) { host in
                        HistoryHostChip(host: host, current: $domainInput, isHistory: true)
                    }
                    
                    // 分隔线
                    if !historyManager.connectionTestHistory.isEmpty {
                        Divider().frame(height: 20)
                    }
                    
                    // 默认域名
                    ForEach(defaultDomains, id: \.self) { domain in
                        if !historyManager.connectionTestHistory.prefix(3).contains(domain) {
                            QuickDomainChip(domain: domain, current: $domainInput)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .navigationTitle(l10n.connectionTest)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - 当前测试视图
    private var currentTestView: some View {
        VStack(spacing: 12) {
            if manager.isTesting {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(manager.currentPhase.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            if let result = manager.currentResult,
               !result.ipv4Addresses.isEmpty || !result.ipv6Addresses.isEmpty {
                // DNS 结果预览
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("DNS", systemImage: "server.rack")
                            .font(.caption)
                            .foregroundColor(.cyan)
                        Spacer()
                        Text(String(format: "%.0fms", result.dnsLatency * 1000))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if !result.ipv4Addresses.isEmpty {
                        Text("IPv4: \(result.ipv4Addresses.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if !result.ipv6Addresses.isEmpty {
                        Text("IPv6: \(result.ipv6Addresses.first ?? "")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - 历史记录列表
    private var historyListView: some View {
        VStack(spacing: 0) {
            ForEach(historyManager.connectionTestHistory, id: \.self) { host in
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Text(host)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Spacer()
                    
                    Button {
                        historyManager.removeConnectionTestHistory(host)
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
                    domainInput = host
                    showHistory = false
                }
                
                if host != historyManager.connectionTestHistory.last {
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
    
    private func startTest() {
        guard !domainInput.isEmpty else { return }
        historyManager.addConnectionTestHistory(domainInput)
        let port = Int(portInput) ?? 443
        manager.startTest(domain: domainInput, port: port)
    }
}

// MARK: - 结果卡片
struct ConnectionTestResultCard: View {
    let result: ConnectionTestResult
    @Environment(\.colorScheme) private var colorScheme
    
    private var l10n: L10n { L10n.shared }
    
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 头部
            HStack {
                Text(result.domain)
                    .font(.headline)
                Spacer()
                Text(Self.timeFormatter.string(from: result.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // DNS 解析结果
            VStack(alignment: .leading, spacing: 6) {
                Label("DNS " + l10n.resolution, systemImage: "server.rack")
                    .font(.subheadline)
                    .foregroundColor(.cyan)
                
                if !result.cnameRecords.isEmpty {
                    ForEach(result.cnameRecords, id: \.self) { cname in
                        HStack {
                            Text("CNAME")
                                .font(.caption)
                                .foregroundColor(.orange)
                                .frame(width: 50, alignment: .leading)
                            Text(cname)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if !result.ipv4Addresses.isEmpty {
                    ForEach(result.ipv4Addresses, id: \.self) { ip in
                        HStack {
                            Text("A")
                                .font(.caption)
                                .foregroundColor(.green)
                                .frame(width: 50, alignment: .leading)
                            Text(ip)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if !result.ipv6Addresses.isEmpty {
                    ForEach(result.ipv6Addresses, id: \.self) { ip in
                        HStack {
                            Text("AAAA")
                                .font(.caption)
                                .foregroundColor(.purple)
                                .frame(width: 50, alignment: .leading)
                            Text(ip)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            
            Divider()
            
            // 连接测试结果
            VStack(alignment: .leading, spacing: 6) {
                Label(l10n.connectionTest, systemImage: "bolt.fill")
                    .font(.subheadline)
                    .foregroundColor(.cyan)
                
                HStack(spacing: 16) {
                    // IPv4
                    VStack(alignment: .leading, spacing: 4) {
                        Text("IPv4")
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        if result.ipv4Addresses.isEmpty {
                            Text(l10n.noRecord)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else if let latency = result.ipv4Latency {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                Text(String(format: "%.0fms", latency * 1000))
                                    .font(.caption)
                            }
                        } else if let error = result.ipv4Error {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                    .font(.caption)
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // IPv6
                    VStack(alignment: .leading, spacing: 4) {
                        Text("IPv6")
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        if result.ipv6Addresses.isEmpty {
                            Text(l10n.noRecord)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else if let latency = result.ipv6Latency {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                Text(String(format: "%.0fms", latency * 1000))
                                    .font(.caption)
                            }
                        } else if let error = result.ipv6Error {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                    .font(.caption)
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            
            Divider()
            
            // 结论
            HStack {
                Image(systemName: result.preferredProtocol != nil ? "hand.point.right.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(result.preferredProtocol != nil ? .cyan : .orange)
                Text(l10n.conclusion + ": ")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(result.conclusion)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(result.preferredProtocol == .ipv6 ? .purple : (result.preferredProtocol == .ipv4 ? .green : .orange))
            }
        }
        .padding()
        .background(colorScheme == .dark ? Color(.secondarySystemBackground) : Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    NavigationStack {
        ConnectionTestView()
            .environmentObject(LanguageManager.shared)
    }
}
