//
//  HTTPGetView.swift
//  Pong
//
//  Created by Claude on 2025/12/19.
//

import SwiftUI

// MARK: - HTTP GET 视图
struct HTTPGetView: View {
    @StateObject private var httpManager = HTTPManager.shared
    @StateObject private var historyManager = HostHistoryManager.shared
    @State private var urlInput = "https://www.qq.com"
    @State private var showHistory = false
    @State private var showCopyToast = false
    @State private var showTiming = true
    @State private var showHeaders = true
    @State private var showBody = false
    @State private var timeoutSeconds: Double = 10
    @FocusState private var isInputFocused: Bool
    
    private var l10n: L10n { L10n.shared }
    
    // 快捷输入按钮
    private let quickInputs = ["https://", "http://", ".com", ".cn"]
    
    var body: some View {
        VStack(spacing: 16) {
            // 输入区域
            VStack(spacing: 12) {
                HStack {
                    ZStack(alignment: .trailing) {
                        TextField(l10n.enterURL, text: $urlInput)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .keyboardType(.URL)
                            .focused($isInputFocused)
                        
                        if !urlInput.isEmpty {
                            Button {
                                urlInput = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .padding(.trailing, 8)
                        }
                    }
                    
                    // 历史记录按钮
                    if !historyManager.httpHistory.isEmpty {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showHistory.toggle()
                            }
                        } label: {
                            Image(systemName: showHistory ? "chevron.up" : "clock.arrow.circlepath")
                                .foregroundColor(.teal)
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
                                    .foregroundColor(.teal)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.teal.opacity(0.1))
                                    .cornerRadius(6)
                            }
                        }
                    }
                }
                
                // 历史记录列表
                if showHistory && !historyManager.httpHistory.isEmpty {
                    httpHistoryListView
                }
                
                // 超时设置和发送按钮
                HStack {
                    Text(l10n.timeoutLabel)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Picker("", selection: $timeoutSeconds) {
                        Text("10s").tag(10.0)
                        Text("30s").tag(30.0)
                        Text("60s").tag(60.0)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                    
                    Spacer()
                    
                    Button(action: {
                        isInputFocused = false
                        if httpManager.isLoading {
                            httpManager.stop()
                        } else {
                            sendRequest()
                        }
                    }) {
                        HStack {
                            if httpManager.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "paperplane.fill")
                            }
                            Text(httpManager.isLoading ? l10n.requesting : l10n.send)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(httpManager.isLoading ? Color.red : Color.teal)
                        .cornerRadius(8)
                    }
                }
            }
            .padding(.horizontal)
            
            // 结果区域
            VStack(alignment: .leading, spacing: 0) {
                // 命令行样式头部
                HStack {
                    let displayURL = httpManager.isLoading || httpManager.result != nil ? httpManager.currentURL : urlInput
                    Text("$ curl -X GET \(displayURL.prefix(30))\(displayURL.count > 30 ? "..." : "")")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.green)
                        .lineLimit(1)
                    Spacer()
                    
                    if httpManager.result != nil {
                        // 一键复制按钮
                        Button {
                            copyResponse()
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.caption)
                                .foregroundColor(.teal)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.9))
                
                // 响应内容
                ScrollView {
                    if let resp = httpManager.result {
                        VStack(alignment: .leading, spacing: 12) {
                            // 状态行
                            HStack(spacing: 8) {
                                Image(systemName: resp.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(resp.isSuccess ? .green : .red)
                                
                                if let code = resp.statusCode {
                                    Text("HTTP \(code)")
                                        .foregroundColor(resp.isSuccess ? .green : .red)
                                        .fontWeight(.bold)
                                }
                                
                                Text(resp.statusMessage)
                                    .foregroundColor(.gray)
                                
                                Spacer()
                                
                                HStack(spacing: 4) {
                                    Text(String(format: "%.0fms", resp.responseTime * 1000))
                                        .foregroundColor(.yellow)
                                    Text(l10n.pureNetwork)
                                        .foregroundColor(.gray)
                                        .font(.system(size: 10, design: .monospaced))
                                }
                            }
                            .font(.system(size: 14, design: .monospaced))
                            
                            // 错误信息
                            if let error = resp.error {
                                Text("Error: \(error)")
                                    .foregroundColor(.red)
                                    .font(.system(size: 12, design: .monospaced))
                            }
                            
                            // Timing 折叠区域
                            if resp.timing.hasData {
                                DisclosureGroup(isExpanded: $showTiming) {
                                    HTTPTimingView(timing: resp.timing)
                                        .padding(.top, 4)
                                } label: {
                                    HStack(spacing: 4) {
                                        Text("Timing")
                                        Image(systemName: showTiming ? "chevron.down" : "chevron.right")
                                            .font(.system(size: 10))
                                    }
                                    .foregroundColor(.orange)
                                    .font(.system(size: 12, design: .monospaced))
                                }
                            }
                            
                            // Headers 折叠区域
                            if !resp.headers.isEmpty {
                                DisclosureGroup(isExpanded: $showHeaders) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        ForEach(Array(resp.headers.keys.sorted()), id: \.self) { key in
                                            HStack(alignment: .top, spacing: 4) {
                                                Text("\(key):")
                                                    .foregroundColor(.cyan)
                                                Text(resp.headers[key] ?? "")
                                                    .foregroundColor(.white)
                                                Spacer()
                                            }
                                            .font(.system(size: 11, design: .monospaced))
                                        }
                                    }
                                    .padding(.top, 4)
                                } label: {
                                    HStack(spacing: 4) {
                                        Text("Headers (\(resp.headers.count))")
                                        Image(systemName: showHeaders ? "chevron.down" : "chevron.right")
                                            .font(.system(size: 10))
                                    }
                                    .foregroundColor(.orange)
                                    .font(.system(size: 12, design: .monospaced))
                                }
                            }
                            
                            // Body 折叠区域
                            if !resp.body.isEmpty {
                                DisclosureGroup(isExpanded: $showBody) {
                                    Text(resp.body)
                                        .foregroundColor(.white)
                                        .font(.system(size: 11, design: .monospaced))
                                        .textSelection(.enabled)
                                        .padding(.top, 4)
                                } label: {
                                    HStack(spacing: 4) {
                                        Text("Body (\(formatBytes(resp.body.utf8.count)))")
                                        Image(systemName: showBody ? "chevron.down" : "chevron.right")
                                            .font(.system(size: 10))
                                    }
                                    .foregroundColor(.orange)
                                    .font(.system(size: 12, design: .monospaced))
                                }
                            }
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text(l10n.httpHint)
                            .foregroundColor(.gray)
                            .font(.system(size: 12, design: .monospaced))
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
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
            
            // 常用 URL 快捷按钮
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(HTTPManager.commonURLs, id: \.0) { name, url in
                        Button(action: {
                            urlInput = url
                        }) {
                            Text(name)
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(urlInput == url ? Color.teal : Color(.systemGray5))
                                .foregroundColor(urlInput == url ? .white : .primary)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .navigationTitle(l10n.httpTitle)
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
        if input.hasPrefix("http") {
            if !urlInput.hasPrefix("http") {
                urlInput = input + urlInput
            }
        } else if input.hasPrefix(".") {
            urlInput += input
        }
    }
    
    // HTTP 历史记录列表视图
    private var httpHistoryListView: some View {
        VStack(spacing: 0) {
            ForEach(historyManager.httpHistory, id: \.self) { url in
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Text(url)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Spacer()
                    
                    Button {
                        historyManager.removeHTTPHistory(url)
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
                    urlInput = url
                    showHistory = false
                }
                
                if url != historyManager.httpHistory.last {
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
    
    private func sendRequest() {
        guard !urlInput.isEmpty else { return }
        historyManager.addHTTPHistory(urlInput)
        httpManager.sendGetRequest(urlString: urlInput, timeout: timeoutSeconds)
    }
    
    private func formatBytes(_ bytes: Int) -> String {
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024)
        } else {
            return String(format: "%.1f MB", Double(bytes) / 1024 / 1024)
        }
    }
    
    private func copyResponse() {
        guard let resp = httpManager.result else { return }
        
        var lines: [String] = []
        lines.append("HTTP GET: \(resp.url)")
        lines.append("")
        
        if let code = resp.statusCode {
            lines.append("Status: HTTP \(code) \(resp.statusMessage)")
        }
        lines.append("Response Time: \(String(format: "%.0fms", resp.responseTime * 1000))")
        
        if let error = resp.error {
            lines.append("Error: \(error)")
        }
        
        if !resp.headers.isEmpty {
            lines.append("")
            lines.append("Headers:")
            for key in resp.headers.keys.sorted() {
                lines.append("  \(key): \(resp.headers[key] ?? "")")
            }
        }
        
        if !resp.body.isEmpty {
            lines.append("")
            lines.append("Body:")
            lines.append(resp.body)
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

// MARK: - HTTP Timing 可视化视图
struct HTTPTimingView: View {
    let timing: HTTPTimingMetrics
    
    private var l10n: L10n { L10n.shared }
    
    // 各阶段数据
    private var phases: [(String, TimeInterval, Color)] {
        [
            ("DNS", timing.dnsLookup, .cyan),
            ("TCP", timing.tcpConnection, .green),
            ("TLS", timing.tlsHandshake, .orange),
            ("Request", timing.requestSent, .blue),
            ("TTFB", timing.serverResponse, .purple),
            ("Download", timing.contentDownload, .pink)
        ].filter { $0.1 > 0 }
    }
    
    private let tagColor = Color.gray
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 瀑布图
            ForEach(phases, id: \.0) { name, duration, barColor in
                HStack(spacing: 8) {
                    // Tag 样式的名称（统一颜色）
                    Text(name)
                        .font(.system(size: 9, design: .monospaced))
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .frame(width: 56)
                        .padding(.vertical, 3)
                        .background(tagColor.opacity(0.8))
                        .cornerRadius(4)
                    
                    // 进度条（不同颜色）
                    GeometryReader { geo in
                        let width = timing.total > 0 ? CGFloat(duration / timing.total) * geo.size.width : 0
                        RoundedRectangle(cornerRadius: 2)
                            .fill(barColor)
                            .frame(width: max(width, 2))
                    }
                    .frame(height: 12)
                    
                    // 时间（不同颜色）
                    Text(formatMs(duration))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(barColor)
                        .frame(width: 50, alignment: .trailing)
                }
            }
            
            // 总计
            HStack(spacing: 8) {
                Text("Total")
                    .font(.system(size: 9, design: .monospaced))
                    .fontWeight(.medium)
                    .foregroundColor(.black)
                    .frame(width: 56)
                    .padding(.vertical, 3)
                    .background(Color.yellow.opacity(0.9))
                    .cornerRadius(4)
                
                Spacer()
                
                Text(formatMs(timing.total))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.yellow)
                    .fontWeight(.bold)
                    .frame(width: 50, alignment: .trailing)
            }
        }
    }
    
    private func formatMs(_ interval: TimeInterval) -> String {
        let ms = interval * 1000
        if ms < 1 {
            return String(format: "%.2fms", ms)
        } else if ms < 10 {
            return String(format: "%.1fms", ms)
        } else {
            return String(format: "%.0fms", ms)
        }
    }
}

#Preview {
    NavigationStack {
        HTTPGetView()
    }
}
