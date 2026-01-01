//
//  HostHistoryManager.swift
//  Pong
//
//  Created by 张金琛 on 2025/12/17.
//

import Foundation
import SwiftUI
internal import Combine

/// 主机历史记录管理器
/// 用于管理本地探测（Ping、DNS、TCP、UDP、Trace）的目标地址历史记录
class HostHistoryManager: ObservableObject {
    static let shared = HostHistoryManager()
    
    // 各探测类型的历史记录 key
    private let pingHistoryKey = "PingHostHistory"
    private let dnsHistoryKey = "DNSHostHistory"
    private let tcpHistoryKey = "TCPHostHistory"
    private let udpHistoryKey = "UDPHostHistory"
    private let traceHistoryKey = "TraceHostHistory"
    private let httpHistoryKey = "HTTPHostHistory"
    private let connectionTestHistoryKey = "ConnectionTestHostHistory"
    private let quickDiagnosisHistoryKey = "QuickDiagnosisHostHistory"
    
    // 最大历史记录数
    private let maxHistoryCount = 10
    
    // 历史记录
    @Published var pingHistory: [String] = []
    @Published var dnsHistory: [String] = []
    @Published var tcpHistory: [String] = []
    @Published var udpHistory: [String] = []
    @Published var traceHistory: [String] = []
    @Published var httpHistory: [String] = []
    @Published var connectionTestHistory: [String] = []
    @Published var quickDiagnosisHistory: [String] = []
    
    private init() {
        loadAllHistory()
    }
    
    // MARK: - 加载历史记录
    private func loadAllHistory() {
        pingHistory = UserDefaults.standard.stringArray(forKey: pingHistoryKey) ?? []
        dnsHistory = UserDefaults.standard.stringArray(forKey: dnsHistoryKey) ?? []
        tcpHistory = UserDefaults.standard.stringArray(forKey: tcpHistoryKey) ?? []
        udpHistory = UserDefaults.standard.stringArray(forKey: udpHistoryKey) ?? []
        traceHistory = UserDefaults.standard.stringArray(forKey: traceHistoryKey) ?? []
        httpHistory = UserDefaults.standard.stringArray(forKey: httpHistoryKey) ?? []
        connectionTestHistory = UserDefaults.standard.stringArray(forKey: connectionTestHistoryKey) ?? []
        quickDiagnosisHistory = UserDefaults.standard.stringArray(forKey: quickDiagnosisHistoryKey) ?? []
    }
    
    // MARK: - 添加历史记录
    func addPingHistory(_ host: String) {
        addHistory(host, to: &pingHistory, key: pingHistoryKey)
    }
    
    func addDNSHistory(_ host: String) {
        addHistory(host, to: &dnsHistory, key: dnsHistoryKey)
    }
    
    func addTCPHistory(_ host: String) {
        addHistory(host, to: &tcpHistory, key: tcpHistoryKey)
    }
    
    func addUDPHistory(_ host: String) {
        addHistory(host, to: &udpHistory, key: udpHistoryKey)
    }
    
    func addTraceHistory(_ host: String) {
        addHistory(host, to: &traceHistory, key: traceHistoryKey)
    }
    
    func addHTTPHistory(_ url: String) {
        addHistory(url, to: &httpHistory, key: httpHistoryKey)
    }
    
    func addConnectionTestHistory(_ host: String) {
        addHistory(host, to: &connectionTestHistory, key: connectionTestHistoryKey)
    }
    
    func addQuickDiagnosisHistory(_ host: String) {
        addHistory(host, to: &quickDiagnosisHistory, key: quickDiagnosisHistoryKey)
    }
    
    private func addHistory(_ host: String, to history: inout [String], key: String) {
        let trimmed = host.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        
        // 移除重复项
        history.removeAll { $0 == trimmed }
        // 插入到最前面
        history.insert(trimmed, at: 0)
        // 限制数量
        if history.count > maxHistoryCount {
            history = Array(history.prefix(maxHistoryCount))
        }
        
        UserDefaults.standard.set(history, forKey: key)
    }
    
    // MARK: - 删除历史记录
    func removePingHistory(_ host: String) {
        removeHistory(host, from: &pingHistory, key: pingHistoryKey)
    }
    
    func removeDNSHistory(_ host: String) {
        removeHistory(host, from: &dnsHistory, key: dnsHistoryKey)
    }
    
    func removeTCPHistory(_ host: String) {
        removeHistory(host, from: &tcpHistory, key: tcpHistoryKey)
    }
    
    func removeUDPHistory(_ host: String) {
        removeHistory(host, from: &udpHistory, key: udpHistoryKey)
    }
    
    func removeTraceHistory(_ host: String) {
        removeHistory(host, from: &traceHistory, key: traceHistoryKey)
    }
    
    func removeHTTPHistory(_ url: String) {
        removeHistory(url, from: &httpHistory, key: httpHistoryKey)
    }
    
    func removeConnectionTestHistory(_ host: String) {
        removeHistory(host, from: &connectionTestHistory, key: connectionTestHistoryKey)
    }
    
    func removeQuickDiagnosisHistory(_ host: String) {
        removeHistory(host, from: &quickDiagnosisHistory, key: quickDiagnosisHistoryKey)
    }
    
    private func removeHistory(_ host: String, from history: inout [String], key: String) {
        history.removeAll { $0 == host }
        UserDefaults.standard.set(history, forKey: key)
    }
    
    // MARK: - 清空历史记录
    func clearPingHistory() {
        pingHistory.removeAll()
        UserDefaults.standard.removeObject(forKey: pingHistoryKey)
    }
    
    func clearDNSHistory() {
        dnsHistory.removeAll()
        UserDefaults.standard.removeObject(forKey: dnsHistoryKey)
    }
    
    func clearTCPHistory() {
        tcpHistory.removeAll()
        UserDefaults.standard.removeObject(forKey: tcpHistoryKey)
    }
    
    func clearUDPHistory() {
        udpHistory.removeAll()
        UserDefaults.standard.removeObject(forKey: udpHistoryKey)
    }
    
    func clearTraceHistory() {
        traceHistory.removeAll()
        UserDefaults.standard.removeObject(forKey: traceHistoryKey)
    }
    
    func clearHTTPHistory() {
        httpHistory.removeAll()
        UserDefaults.standard.removeObject(forKey: httpHistoryKey)
    }
    
    func clearConnectionTestHistory() {
        connectionTestHistory.removeAll()
        UserDefaults.standard.removeObject(forKey: connectionTestHistoryKey)
    }
    
    func clearQuickDiagnosisHistory() {
        quickDiagnosisHistory.removeAll()
        UserDefaults.standard.removeObject(forKey: quickDiagnosisHistoryKey)
    }
}

// MARK: - 主机输入辅助视图
/// 带历史记录和快捷输入的主机输入组件
struct HostInputField: View {
    @Binding var text: String
    let placeholder: String
    let history: [String]
    let onHistorySelect: (String) -> Void
    let onHistoryDelete: (String) -> Void
    
    @State private var showHistory = false
    @FocusState private var isFocused: Bool
    
    // 快捷输入按钮
    private let quickInputs = ["www.", ".com", ".cn", ".net", ".org"]
    
    var body: some View {
        VStack(spacing: 8) {
            // 主输入框
            HStack {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .focused($isFocused)
                
                // 历史记录按钮
                if !history.isEmpty {
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
                    
                    // 清空按钮
                    if !text.isEmpty {
                        Button {
                            text = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            // 历史记录列表
            if showHistory && !history.isEmpty {
                VStack(spacing: 0) {
                    ForEach(history, id: \.self) { host in
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(.secondary)
                                .font(.caption)
                            Text(host)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            Spacer()
                            
                            // 删除按钮
                            Button {
                                onHistoryDelete(host)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            text = host
                            showHistory = false
                            onHistorySelect(host)
                        }
                        
                        if host != history.last {
                            Divider()
                                .padding(.leading, 36)
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
        }
    }
    
    private func insertQuickInput(_ input: String) {
        if input.hasPrefix(".") {
            // 后缀，追加到末尾
            text += input
        } else if input.hasSuffix(".") {
            // 前缀，插入到开头
            if !text.hasPrefix(input) {
                text = input + text
            }
        }
    }
}

// MARK: - 简化版历史记录选择器（用于快捷主机区域）
struct HostHistoryChips: View {
    let history: [String]
    @Binding var current: String
    let defaultHosts: [String]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // 历史记录（最多显示3条）
                ForEach(history.prefix(3), id: \.self) { host in
                    HistoryHostChip(host: host, current: $current, isHistory: true)
                }
                
                // 分隔线（如果有历史记录）
                if !history.isEmpty {
                    Divider()
                        .frame(height: 20)
                }
                
                // 默认主机
                ForEach(defaultHosts, id: \.self) { host in
                    if !history.prefix(3).contains(host) {
                        HistoryHostChip(host: host, current: $current, isHistory: false)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

struct HistoryHostChip: View {
    let host: String
    @Binding var current: String
    let isHistory: Bool
    
    var body: some View {
        Button {
            current = host
        } label: {
            HStack(spacing: 4) {
                if isHistory {
                    Image(systemName: "clock")
                        .font(.system(size: 9))
                }
                Text(host)
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(current == host ? Color.blue : Color(.systemGray5))
            .foregroundColor(current == host ? .white : .primary)
            .cornerRadius(16)
        }
    }
}

// MARK: - 复制成功提示视图
struct CopyToastView: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text("已复制到剪贴板")
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
