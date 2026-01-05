//
//  TCPView.swift
//  Pong
//
//  Created by 张金琛 on 2025/12/12.
//

import SwiftUI

struct TCPView: View {
    @StateObject private var tcpManager = TCPManager.shared
    @StateObject private var historyManager = HostHistoryManager.shared
    @State private var hostInput = "www.qq.com"
    @State private var portInput = "443"
    @State private var scanMode = false
    @State private var showHistory = false
    @State private var showCopyToast = false
    @FocusState private var isInputFocused: Bool
    
    private var l10n: L10n { L10n.shared }
    
    // 快捷输入按钮
    private let quickInputs = ["www.", ".com", ".cn", ".net"]
    
    var body: some View {
        VStack(spacing: 16) {
            // 输入区域
            VStack(spacing: 12) {
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
                    if !historyManager.tcpHistory.isEmpty {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showHistory.toggle()
                            }
                        } label: {
                            Image(systemName: showHistory ? "chevron.up" : "clock.arrow.circlepath")
                                .foregroundColor(.orange)
                                .frame(width: 32, height: 32)
                        }
                    }
                    
                    TextField(l10n.port, text: $portInput)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                        .frame(width: 80)
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
                                    .foregroundColor(.orange)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.orange.opacity(0.1))
                                    .cornerRadius(6)
                            }
                        }
                    }
                }
                
                // 历史记录列表
                if showHistory && !historyManager.tcpHistory.isEmpty {
                    tcpHistoryListView
                }
                
                // IP 协议选择
                HStack {
                    Text(l10n.ipProtocol)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Picker("", selection: $tcpManager.protocolPreference) {
                        ForEach(IPProtocolPreference.allCases, id: \.self) { preference in
                            Text(preference.displayName).tag(preference)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                    Spacer()
                }
                
                HStack {
                    Toggle(l10n.scanCommonPorts, isOn: $scanMode)
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Button(action: {
                        isInputFocused = false
                        if tcpManager.isScanning {
                            tcpManager.stopScan()
                        } else {
                            startTest()
                        }
                    }) {
                        HStack {
                            Image(systemName: tcpManager.isScanning ? "stop.fill" : "play.fill")
                            Text(tcpManager.isScanning ? l10n.stop : l10n.test)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(tcpManager.isScanning ? Color.red : Color.orange)
                        .cornerRadius(8)
                    }
                }
            }
            .padding(.horizontal)
            
            // 进度条
            if tcpManager.isScanning && scanMode {
                VStack(spacing: 4) {
                    ProgressView(value: tcpManager.progress)
                        .progressViewStyle(.linear)
                    Text("\(Int(tcpManager.progress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            }
            
            // 结果列表
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("$ nc -zv \(tcpManager.isScanning || !tcpManager.results.isEmpty ? tcpManager.currentHost : hostInput) \(portInput)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.green)
                    Spacer()
                    
                    // 统计
                    let openCount = tcpManager.results.filter { $0.isOpen }.count
                    if !tcpManager.results.isEmpty {
                        Text("\(openCount)/\(tcpManager.results.count) \(l10n.open)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        // 一键复制按钮
                        Button {
                            copyTCPResults()
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.9))
                
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(tcpManager.results) { result in
                            TCPResultRow(result: result)
                        }
                        
                        // 空状态提示
                        if tcpManager.results.isEmpty && !tcpManager.isScanning {
                            Text(l10n.tcpHint)
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
            
            // 常用端口快捷按钮
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(TCPManager.commonPorts.prefix(8), id: \.0) { port, name in
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
                            .background(portInput == "\(port)" ? Color.orange : Color(.systemGray5))
                            .foregroundColor(portInput == "\(port)" ? .white : .primary)
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .navigationTitle(l10n.tcpTitle)
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
    
    // TCP 历史记录列表视图
    private var tcpHistoryListView: some View {
        VStack(spacing: 0) {
            ForEach(historyManager.tcpHistory, id: \.self) { host in
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Text(host)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Spacer()
                    
                    Button {
                        historyManager.removeTCPHistory(host)
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
                
                if host != historyManager.tcpHistory.last {
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
        guard !hostInput.isEmpty else { return }
        historyManager.addTCPHistory(hostInput)
        
        if scanMode {
            let ports = TCPManager.commonPorts.map { $0.0 }
            tcpManager.scanPorts(host: hostInput, ports: ports)
        } else if let port = UInt16(portInput) {
            tcpManager.testConnection(host: hostInput, port: port)
        }
    }
    
    private func copyTCPResults() {
        var lines: [String] = []
        lines.append("TCP Connection Test: \(tcpManager.currentHost)")
        lines.append("")
        
        for result in tcpManager.results {
            let portName = TCPManager.commonPorts.first { $0.0 == result.port }?.1 ?? ""
            let status = result.isOpen ? L10n.shared.open : L10n.shared.closed
            var line = "Port \(result.port)"
            if !portName.isEmpty {
                line += " (\(portName))"
            }
            line += ": \(status)"
            if let latency = result.latency {
                line += " - \(String(format: "%.0fms", latency * 1000))"
            }
            lines.append(line)
        }
        
        let openCount = tcpManager.results.filter { $0.isOpen }.count
        lines.append("")
        lines.append("Summary: \(openCount)/\(tcpManager.results.count) ports open")
        
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

// MARK: - TCP 结果行
struct TCPResultRow: View {
    let result: TCPResult
    
    private var l10n: L10n { L10n.shared }
    
    private var portName: String {
        TCPManager.commonPorts.first { $0.0 == result.port }?.1 ?? ""
    }
    
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
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                // 状态图标
                if isIPv6NetworkError {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                } else {
                    Image(systemName: result.isOpen ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(result.isOpen ? .green : .red)
                }
                
                // 端口
                Text("\(result.port)")
                    .foregroundColor(.cyan)
                    .frame(width: 50, alignment: .leading)
                
                // 服务名
                if !portName.isEmpty {
                    Text(portName)
                        .foregroundColor(.gray)
                        .frame(width: 60, alignment: .leading)
                }
                
                // 状态：IPv6 错误时不显示"关闭"
                if isIPv6NetworkError {
                    Text(l10n.noIPv6)
                        .foregroundColor(.yellow)
                } else {
                    Text(result.isOpen ? l10n.open : l10n.closed)
                        .foregroundColor(result.isOpen ? .green : .red)
                }
                
                // 延迟
                if let latency = result.latency {
                    Text(String(format: "%.0fms", latency * 1000))
                        .foregroundColor(.yellow)
                }
                
                Spacer()
            }
            .font(.system(size: 12, design: .monospaced))
            
            // 错误原因（小字显示）- IPv6 错误不再重复显示
            if let error = result.error, !result.isOpen, !isIPv6NetworkError {
                Text("  ↳ \(error)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.orange)
            }
        }
        .id(result.id)
    }
}

#Preview {
    NavigationStack {
        TCPView()
    }
}
