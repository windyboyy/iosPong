//
//  DNSView.swift
//  Pong
//
//  Created by 张金琛 on 2025/12/12.
//

import SwiftUI

struct DNSView: View {
    @EnvironmentObject var languageManager: LanguageManager
    @StateObject private var dnsManager = DNSManager.shared
    @StateObject private var historyManager = HostHistoryManager.shared
    @State private var domainInput = "www.qq.com"
    @State private var selectedRecordType: DNSRecordType = .systemDefault
    @State private var showHistory = false
    @State private var showCopyToast = false
    @State private var showMoreRecordTypes = false
    @FocusState private var isInputFocused: Bool
    
    private var l10n: L10n { L10n.shared }
    
    // 主要记录类型
    private let primaryRecordTypes: [DNSRecordType] = [.systemDefault, .A, .AAAA, .CNAME]
    // 更多记录类型
    private let moreRecordTypes: [DNSRecordType] = [.MX, .TXT, .NS, .PTR]
    
    // 快捷输入按钮
    private let quickInputs = ["www.", ".com", ".cn", ".net"]
    // 默认快捷域名
    private let defaultDomains = ["www.qq.com", "www.baidu.com", "www.google.com", "github.com", "apple.com"]
    
    var body: some View {
        VStack(spacing: 16) {
            // 输入区域
            VStack(spacing: 12) {
                HStack {
                    ZStack(alignment: .trailing) {
                        TextField(l10n.enterDomain, text: $domainInput)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.asciiCapable)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .focused($isInputFocused)
                            .onSubmit {
                                startQuery()
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
                    
                    // 历史记录按钮
                    if !historyManager.dnsHistory.isEmpty {
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
                
                // 快捷输入按钮
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(quickInputs, id: \.self) { input in
                            Button {
                                insertQuickInput(input)
                            } label: {
                                Text(input)
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                    .foregroundColor(.cyan)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.cyan.opacity(0.1))
                                    .cornerRadius(6)
                            }
                        }
                    }
                }
                
                // 历史记录列表
                if showHistory && !historyManager.dnsHistory.isEmpty {
                    dnsHistoryListView
                }
                
                HStack {
                    // 记录类型选择
                    RecordTypePicker(
                        selectedRecordType: $selectedRecordType,
                        showMoreRecordTypes: $showMoreRecordTypes,
                        primaryRecordTypes: primaryRecordTypes,
                        moreRecordTypes: moreRecordTypes
                    )
                    
                    Button(action: {
                        isInputFocused = false
                        if dnsManager.isQuerying {
                            dnsManager.stopQuery()
                        } else {
                            startQuery()
                        }
                    }) {
                        Image(systemName: dnsManager.isQuerying ? "stop.fill" : "magnifyingglass")
                            .foregroundColor(.white)
                            .frame(width: 44, height: 32)
                            .background(dnsManager.isQuerying ? Color.red : Color.cyan)
                            .cornerRadius(8)
                    }
                }
            }
            .padding(.horizontal)
            
            // 结果列表
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("$ dig \(dnsManager.isQuerying || !dnsManager.results.isEmpty ? dnsManager.currentDomain : domainInput) \(selectedRecordType == .systemDefault ? "SYSTEM" : selectedRecordType.rawValue)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.green)
                    Spacer()
                    
                    if !dnsManager.results.isEmpty {
                        Button(action: {
                            dnsManager.clearHistory()
                        }) {
                            Text(l10n.clear)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.9))
                
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(dnsManager.results) { result in
                            DNSResultRow(result: result, onCopy: {
                                showCopyToastAnimation()
                            })
                        }
                        
                        if dnsManager.results.isEmpty {
                            Text(l10n.enterDomainToQuery)
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
            
            // 快捷域名
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // 历史记录（最多3条）
                    ForEach(historyManager.dnsHistory.prefix(3), id: \.self) { host in
                        HistoryHostChip(host: host, current: $domainInput, isHistory: true)
                    }
                    
                    // 分隔线
                    if !historyManager.dnsHistory.isEmpty {
                        Divider().frame(height: 20)
                    }
                    
                    // 默认域名
                    ForEach(defaultDomains, id: \.self) { domain in
                        if !historyManager.dnsHistory.prefix(3).contains(domain) {
                            QuickDomainChip(domain: domain, current: $domainInput)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .navigationTitle(l10n.dnsQuery)
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
            domainInput += input
        } else if input.hasSuffix(".") {
            if !domainInput.hasPrefix(input) {
                domainInput = input + domainInput
            }
        }
    }
    
    // DNS 历史记录列表视图
    private var dnsHistoryListView: some View {
        VStack(spacing: 0) {
            ForEach(historyManager.dnsHistory, id: \.self) { host in
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Text(host)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Spacer()
                    
                    Button {
                        historyManager.removeDNSHistory(host)
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
                
                if host != historyManager.dnsHistory.last {
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
    
    private func startQuery() {
        guard !domainInput.isEmpty else { return }
        historyManager.addDNSHistory(domainInput)
        dnsManager.query(domain: domainInput, recordType: selectedRecordType)
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

// MARK: - DNS 结果行
struct DNSResultRow: View {
    @EnvironmentObject var languageManager: LanguageManager
    let result: DNSResult
    var onCopy: (() -> Void)? = nil
    @State private var showDigOutput = false
    
    private var l10n: L10n { L10n.shared }
    
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()
    
    // 显示的服务器地址
    private var serverDisplay: String {
        return result.server ?? "unknown"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 头部
            HStack {
                Text(result.recordType.displayName)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.cyan)
                    .cornerRadius(4)
                
                Text(result.domain)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(Self.timeFormatter.string(from: result.timestamp))
                    .foregroundColor(.gray)
            }
            
            if showDigOutput {
                // dig 完整输出模式
                Text(digFullOutput())
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.green)
                    .textSelection(.enabled)
            } else {
                // 简洁模式：ANSWER SECTION
                if !result.records.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(";; ANSWER SECTION:")
                            .foregroundColor(.gray)
                            .font(.system(size: 10, design: .monospaced))
                        
                        ForEach(result.records) { record in
                            DNSRecordLineView(record: record)
                        }
                    }
                } else if let error = result.error {
                    Text(";; ERROR: \(error)")
                        .foregroundColor(.orange)
                }
                
                // 查询统计
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: ";; Query time: %.0f msec", result.latency * 1000))
                    Text(";; SERVER: \(serverDisplay)")
                }
                .foregroundColor(.gray)
                .font(.system(size: 10, design: .monospaced))
            }
            
            // 操作按钮
            HStack(spacing: 12) {
                Button(action: { showDigOutput.toggle() }) {
                    Text(showDigOutput ? l10n.simpleMode : l10n.digOutput)
                        .font(.system(size: 10))
                        .foregroundColor(.cyan)
                }
                
                Button(action: {
                    UIPasteboard.general.string = digFullOutput()
                    onCopy?()
                }) {
                    Text(l10n.copy)
                        .font(.system(size: 10))
                        .foregroundColor(.cyan)
                }
            }
        }
        .font(.system(size: 12, design: .monospaced))
        .padding(8)
        .background(Color.white.opacity(0.05))
        .cornerRadius(6)
        .id(result.id)
    }
    
    // 生成完整的 dig 风格输出
    private func digFullOutput() -> String {
        var lines: [String] = []
        
        // Header
        lines.append("; <<>> Pong DNS <<>> \(result.domain)")
        lines.append(";; Got answer:")
        
        let status = result.error == nil ? "NOERROR" : "ERROR"
        let answerCount = result.records.count
        lines.append(";; ->>HEADER<<- opcode: QUERY, status: \(status), id: \(result.id.hashValue & 0xFFFF)")
        lines.append(";; flags: qr rd ra; QUERY: 1, ANSWER: \(answerCount), AUTHORITY: 0, ADDITIONAL: 0")
        lines.append("")
        
        // Question Section
        lines.append(";; QUESTION SECTION:")
        lines.append(";\(result.domain).\t\t\tIN\t\(result.recordType.displayName)")
        lines.append("")
        
        // Answer Section
        if !result.records.isEmpty {
            lines.append(";; ANSWER SECTION:")
            for record in result.records {
                lines.append(record.digLine)
            }
            lines.append("")
        }
        
        // Footer
        lines.append(String(format: ";; Query time: %.0f msec", result.latency * 1000))
        lines.append(";; SERVER: \(serverDisplay)")
        
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE MMM dd HH:mm:ss zzz yyyy"
        lines.append(";; WHEN: \(formatter.string(from: result.timestamp))")
        
        return lines.joined(separator: "\n")
    }
}

// MARK: - DNS 记录行视图（带归属地和优先标记）
struct DNSRecordLineView: View {
    let record: DNSRecord
    
    /// 生成带归属地和优先标记的 dig 行
    private var digLineWithLocationAndPriority: String {
        let nameStr = (record.name ?? ".") + (record.name?.hasSuffix(".") == true ? "" : ".")
        let ttlStr = record.ttl.map { String($0) } ?? "0"
        
        // 值后面加优先标记和归属地
        // 注意：只有 A/AAAA 记录才显示"优先"标记，PTR/CNAME/NS/MX/TXT 等没有优先级概念
        var valueStr = record.value
        if record.isPrimary && (record.typeString == "A" || record.typeString == "AAAA") {
            valueStr += " \(L10n.shared.priorityMark)"
        }
        if let location = record.location, !location.isEmpty {
            valueStr += " (\(location))"
        }
        
        return "\(nameStr)\t\(ttlStr)\t\(record.rdclass)\t\(record.typeString)\t\(valueStr)"
    }
    
    var body: some View {
        Text(digLineWithLocationAndPriority)
            .foregroundColor(.green)
            .font(.system(size: 11, design: .monospaced))
            .textSelection(.enabled)
    }
}

// MARK: - 快捷域名标签
struct QuickDomainChip: View {
    let domain: String
    @Binding var current: String
    
    var body: some View {
        Button(action: {
            current = domain
        }) {
            Text(domain)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(current == domain ? Color.cyan : Color(.systemGray5))
                .foregroundColor(current == domain ? .white : .primary)
                .cornerRadius(16)
        }
    }
}

// MARK: - 记录类型选择器（带更多/返回选项）
struct RecordTypePicker: View {
    @Binding var selectedRecordType: DNSRecordType
    @Binding var showMoreRecordTypes: Bool
    let primaryRecordTypes: [DNSRecordType]
    let moreRecordTypes: [DNSRecordType]
    
    private var l10n: L10n { L10n.shared }
    
    // 用于内部选择的枚举，包含"更多"和"返回"选项
    private enum PickerOption: Hashable {
        case recordType(DNSRecordType)
        case more
        case back
        
        var displayName: String {
            switch self {
            case .recordType(let type):
                return type.displayName
            case .more:
                return L10n.shared.more
            case .back:
                return L10n.shared.back
            }
        }
    }
    
    // 当前显示的选项列表
    private var currentOptions: [PickerOption] {
        if showMoreRecordTypes {
            return moreRecordTypes.map { .recordType($0) } + [.back]
        } else {
            return primaryRecordTypes.map { .recordType($0) } + [.more]
        }
    }
    
    // 当前选中的选项
    private var selectedOption: PickerOption {
        .recordType(selectedRecordType)
    }
    
    var body: some View {
        Picker(l10n.recordType, selection: Binding(
            get: { selectedOption },
            set: { newValue in
                switch newValue {
                case .recordType(let type):
                    selectedRecordType = type
                case .more:
                    showMoreRecordTypes = true
                    selectedRecordType = moreRecordTypes.first ?? .MX
                case .back:
                    showMoreRecordTypes = false
                    selectedRecordType = primaryRecordTypes.first ?? .systemDefault
                }
            }
        )) {
            ForEach(currentOptions, id: \.self) { option in
                Text(option.displayName).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .id(showMoreRecordTypes) // 强制重建以避免选项错乱
        .animation(.easeInOut(duration: 0.2), value: showMoreRecordTypes)
    }
}

#Preview {
    NavigationStack {
        DNSView()
            .environmentObject(LanguageManager.shared)
    }
}
