//
//  UDPView.swift
//  Pong
//
//  Created by 张金琛 on 2025/12/12.
//

import SwiftUI

struct UDPView: View {
    @StateObject private var udpManager = UDPManager.shared
    @StateObject private var historyManager = HostHistoryManager.shared
    @State private var hostInput = "8.8.8.8"
    @State private var portInput = "53"
    @State private var showHistory = false
    @State private var showCopyToast = false
    @FocusState private var isInputFocused: Bool
    
    private var l10n: L10n { L10n.shared }
    
    // 快捷输入按钮
    private let quickInputs = ["www.", ".com", ".cn", ".net"]
    
    var body: some View {
        VStack(spacing: 16) {
            // 输入区域
            VStack(spacing: 8) {
                HStack {
                    ZStack(alignment: .trailing) {
                        TextField(l10n.hostOrIP, text: $hostInput)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.asciiCapable)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .focused($isInputFocused)
                        
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
                    if !historyManager.udpHistory.isEmpty {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showHistory.toggle()
                            }
                        } label: {
                            Image(systemName: showHistory ? "chevron.up" : "clock.arrow.circlepath")
                                .foregroundColor(.green)
                                .frame(width: 32, height: 32)
                        }
                    }
                    
                    TextField(l10n.port, text: $portInput)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                        .frame(width: 80)
                    
                    Button(action: {
                        isInputFocused = false
                        if udpManager.isTesting {
                            udpManager.stopTest()
                        } else {
                            startTest()
                        }
                    }) {
                        HStack {
                            Image(systemName: udpManager.isTesting ? "stop.fill" : "paperplane.fill")
                            Text(udpManager.isTesting ? l10n.stop : l10n.send)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(udpManager.isTesting ? Color.red : Color.green)
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
                                    .foregroundColor(.green)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.green.opacity(0.1))
                                    .cornerRadius(6)
                            }
                        }
                    }
                }
                
                // 历史记录列表
                if showHistory && !historyManager.udpHistory.isEmpty {
                    udpHistoryListView
                }
            }
            .padding(.horizontal)
            
            // 说明
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                Text(l10n.udpNote)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal)
            
            // 结果列表
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("$ nc -u \(udpManager.isTesting || !udpManager.results.isEmpty ? udpManager.currentHost : hostInput) \(portInput)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.green)
                    Spacer()
                    
                    // 一键复制按钮
                    if !udpManager.results.isEmpty {
                        Button {
                            copyUDPResults()
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.9))
                
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(udpManager.results) { result in
                            UDPResultRow(result: result)
                        }
                        
                        if udpManager.results.isEmpty {
                            Text(l10n.udpHint)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.gray)
                                .padding()
                        }
                    }
                    .padding(8)
                }
                .background(Color.black)
            }
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(.systemGray3), lineWidth: 1)
            )
            .padding(.horizontal)
            
            // 常用端口
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(UDPManager.commonPorts, id: \.0) { port, name in
                        Button(action: {
                            portInput = "\(port)"
                        }) {
                            VStack(spacing: 2) {
                                Text("\(port)")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Text(name)
                                    .font(.caption2)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(portInput == "\(port)" ? Color.green : Color(.systemGray5))
                            .foregroundColor(portInput == "\(port)" ? .white : .primary)
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .navigationTitle(l10n.udpTitle)
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
    
    // UDP 历史记录列表视图
    private var udpHistoryListView: some View {
        VStack(spacing: 0) {
            ForEach(historyManager.udpHistory, id: \.self) { host in
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Text(host)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Spacer()
                    
                    Button {
                        historyManager.removeUDPHistory(host)
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
                
                if host != historyManager.udpHistory.last {
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
        guard !hostInput.isEmpty, let port = UInt16(portInput) else { return }
        historyManager.addUDPHistory(hostInput)
        udpManager.testUDP(host: hostInput, port: port)
    }
    
    private func copyUDPResults() {
        var lines: [String] = []
        lines.append("UDP Test Results: \(udpManager.currentHost)")
        lines.append("")
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        
        for result in udpManager.results {
            var line = "[\(timeFormatter.string(from: result.timestamp))] \(result.host):\(result.port)"
            line += " - \(L10n.shared.sendLabel):\(result.sent ? "✓" : "✗") \(L10n.shared.responseLabel):\(result.received ? "✓" : "✗")"
            if let latency = result.latency {
                line += " \(L10n.shared.latencyLabel)\(String(format: "%.1fms", latency * 1000))"
            } else if let error = result.error {
                line += " \(L10n.shared.errorLabel)\(error)"
            }
            lines.append(line)
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

// MARK: - UDP 结果行
struct UDPResultRow: View {
    let result: UDPResult
    
    private var l10n: L10n { L10n.shared }
    
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()
    
    // 判断是否为 IPv6 相关错误
    private func isIPv6Error(_ error: String) -> Bool {
        error.contains("IPv6") || error.contains("ipv6")
    }
    
    // 是否为 IPv6 网络不可用错误
    private var isIPv6NetworkError: Bool {
        if let error = result.error {
            return isIPv6Error(error)
        }
        return false
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // IPv6 网络错误时显示简化的警告信息
            if isIPv6NetworkError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                    Text(l10n.noIPv6)
                        .foregroundColor(.yellow)
                    Spacer()
                    Text(Self.timeFormatter.string(from: result.timestamp))
                        .foregroundColor(.gray)
                }
                
                // 目标
                Text("\(result.host):\(result.port)")
                    .foregroundColor(.cyan)
            } else {
                HStack(spacing: 8) {
                    // 发送状态
                    HStack(spacing: 4) {
                        Image(systemName: result.sent ? "arrow.up.circle.fill" : "arrow.up.circle")
                            .foregroundColor(result.sent ? .green : .red)
                        Text(l10n.sendLabel)
                            .foregroundColor(result.sent ? .green : .red)
                    }
                    
                    // 接收状态
                    HStack(spacing: 4) {
                        Image(systemName: result.received ? "arrow.down.circle.fill" : "arrow.down.circle")
                            .foregroundColor(result.received ? .green : .orange)
                        Text(l10n.responseLabel)
                            .foregroundColor(result.received ? .green : .orange)
                    }
                    
                    Spacer()
                    
                    // 时间
                    Text(Self.timeFormatter.string(from: result.timestamp))
                        .foregroundColor(.gray)
                }
                
                // 目标
                Text("\(result.host):\(result.port)")
                    .foregroundColor(.cyan)
                
                // 延迟或错误
                if let latency = result.latency {
                    Text(String(format: "\(l10n.latencyLabel) %.1fms", latency * 1000))
                        .foregroundColor(.yellow)
                } else if let error = result.error {
                    Text(error)
                        .foregroundColor(.orange)
                }
            }
        }
        .font(.system(size: 12, design: .monospaced))
        .padding(.vertical, 4)
        .id(result.id)
    }
}

#Preview {
    NavigationStack {
        UDPView()
    }
}
