//
//  LatencyTestView.swift
//  Pong
//
//  Created by 张金琛 on 2026/1/2.
//

import SwiftUI

// MARK: - 延迟测试视图
struct LatencyTestView: View {
    @EnvironmentObject var languageManager: LanguageManager
    @StateObject private var manager = LatencyTestManager.shared
    @State private var showAddSheet = false
    @State private var newURL = ""
    @State private var selectedResult: LatencyResult?
    
    private var l10n: L10n { L10n.shared }
    
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 用户自定义目标区域（未分类的）
                let uncategorizedCustomResults = manager.results.filter { $0.target.isCustom && $0.target.category == .custom }
                if !uncategorizedCustomResults.isEmpty {
                    CategorySection(
                        title: l10n.customTargets,
                        results: uncategorizedCustomResults,
                        columns: columns,
                        selectedResult: $selectedResult,
                        onDelete: { result in
                            manager.removeCustomTarget(result.target)
                        }
                    )
                }
                
                // 用户自定义分类
                ForEach(manager.customCategories, id: \.self) { categoryName in
                    let category = LatencyCategory.userDefined(categoryName)
                    let categoryResults = manager.results(for: category)
                    if !categoryResults.isEmpty {
                        CategorySection(
                            title: categoryName,
                            results: categoryResults,
                            columns: columns,
                            selectedResult: $selectedResult,
                            onDelete: { result in
                                manager.removeCustomTarget(result.target)
                            }
                        )
                    }
                }
                
                // 按分类展示默认目标（以及用户添加到预定义分类的目标）
                ForEach(manager.categories, id: \.rawValue) { category in
                    let categoryResults = manager.results(for: category)
                    if !categoryResults.isEmpty {
                        CategorySection(
                            title: category.displayName,
                            results: categoryResults,
                            columns: columns,
                            selectedResult: $selectedResult,
                            onDelete: categoryResults.contains(where: { $0.target.isCustom }) ? { result in
                                if result.target.isCustom {
                                    manager.removeCustomTarget(result.target)
                                }
                            } : nil
                        )
                    }
                }
                
                // 提示说明
                Text(l10n.totalTimeNote)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)
                    .padding(.top, 8)
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(l10n.latencyTest)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 12) {
                    // 添加按钮
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                    }
                    
                    // 开始测试按钮
                    Button {
                        if manager.isTesting {
                            manager.stopTest()
                        } else {
                            manager.startTest()
                        }
                    } label: {
                        if manager.isTesting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Image(systemName: "play.circle.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                    }
                    .disabled(manager.isTesting)
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddTargetSheet(
                newURL: $newURL,
                onSave: { category, name in
                    if !newURL.isEmpty && !name.isEmpty {
                        var urlToSave = newURL
                        if !urlToSave.hasPrefix("http://") && !urlToSave.hasPrefix("https://") {
                            urlToSave = "https://" + urlToSave
                        }
                        manager.addCustomTarget(label: name, url: urlToSave, category: category)
                        newURL = ""
                        showAddSheet = false
                        // 保存后自动测试
                        manager.startTest()
                    }
                },
                onCancel: {
                    newURL = ""
                    showAddSheet = false
                }
            )
        }
        .sheet(item: $selectedResult) { result in
            LatencyDetailView(result: result)
        }
        .onAppear {
            manager.startTest()
        }
    }
}

// MARK: - 分类区域
struct CategorySection: View {
    let title: String
    let results: [LatencyResult]
    let columns: [GridItem]
    @Binding var selectedResult: LatencyResult?
    let onDelete: ((LatencyResult) -> Void)?
    
    private var l10n: L10n { L10n.shared }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(results) { result in
                    LatencyResultCard(result: result) {
                        selectedResult = result
                    }
                    .contextMenu {
                        if let onDelete = onDelete {
                            Button(role: .destructive) {
                                onDelete(result)
                            } label: {
                                Label(l10n.delete, systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - 延迟结果卡片
struct LatencyResultCard: View {
    let result: LatencyResult
    let onTap: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    private var l10n: L10n { L10n.shared }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color(.secondarySystemBackground) : Color(.systemBackground)
    }
    
    // 截取域名，隐藏协议和www前缀，过长则省略
    private var displayURL: String {
        guard let url = URL(string: result.target.url),
              var host = url.host else {
            return result.target.url
        }
        // 移除 www. 前缀
        if host.hasPrefix("www.") {
            host = String(host.dropFirst(4))
        }
        // 过长则省略
        if host.count > 18 {
            let start = host.prefix(8)
            let end = host.suffix(6)
            return "\(start)...\(end)"
        }
        return host
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                // 左侧：标签和域名
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.target.label)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(displayURL)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer(minLength: 4)
                
                // 右侧：状态/延迟
                statusView
                    .frame(minWidth: 50, alignment: .trailing)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(cardBackground)
            .cornerRadius(12)
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.06), radius: 3, x: 0, y: 1)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.1) : Color.gray.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var statusView: some View {
        switch result.status {
        case .pending:
            Text(l10n.pending)
                .font(.caption)
                .foregroundColor(.secondary)
        case .testing:
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(0.7)
        case .success:
            if let latency = result.latency {
                Text(LanguageManager.formatLatency(latency))
                    .font(.system(.callout, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(latencyColor(latency))
            }
        case .failed:
            Button {
                LatencyTestManager.shared.retryTest(for: result)
            } label: {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .foregroundColor(.orange)
                    .font(.title3)
            }
        }
    }
    
    private func latencyColor(_ latency: Double) -> Color {
        if latency < 600 {
            return .green
        } else if latency < 1000 {
            return .orange
        } else {
            return .red
        }
    }
    
    private func timingStageColor(_ latency: Double) -> Color {
        if latency < 50 {
            return .green
        } else if latency < 150 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - 延迟详情视图
struct LatencyDetailView: View {
    let result: LatencyResult
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    private var l10n: L10n { L10n.shared }
    
    var body: some View {
        NavigationStack {
            List {
                // 基本信息
                Section {
                    LabeledContent(l10n.labelTitle, value: result.target.label)
                    LabeledContent("URL", value: result.target.url)
                    if let statusCode = result.statusCode {
                        LabeledContent(l10n.statusCode, value: "\(statusCode)")
                    }
                } header: {
                    Text(l10n.overview)
                }
                
                // Timing 信息
                Section {
                    if let timing = result.timing {
                        LabeledContent(l10n.totalTime) {
                            Text(LanguageManager.formatLatency(timing.totalTime))
                                .foregroundColor(latencyColor(timing.totalTime))
                        }
                        if let dns = timing.dnsLookup, dns > 0 {
                            LabeledContent(l10n.dnsLookupTime) {
                                Text(LanguageManager.formatLatency(dns))
                                    .foregroundColor(timingStageColor(dns))
                            }
                        }
                        if let tcp = timing.tcpConnection, tcp > 0 {
                            LabeledContent(l10n.tcpConnectionTime) {
                                Text(LanguageManager.formatLatency(tcp))
                                    .foregroundColor(timingStageColor(tcp))
                            }
                        }
                        if let tls = timing.tlsHandshake, tls > 0 {
                            LabeledContent(l10n.tlsHandshakeTime) {
                                Text(LanguageManager.formatLatency(tls))
                                    .foregroundColor(timingStageColor(tls))
                            }
                        }
                        if let req = timing.requestSent, req > 0 {
                            LabeledContent(l10n.requestSentTime) {
                                Text(LanguageManager.formatLatency(req))
                                    .foregroundColor(timingStageColor(req))
                            }
                        }
                        if let res = timing.responseReceived, res > 0 {
                            LabeledContent(l10n.responseReceivedTime) {
                                Text(LanguageManager.formatLatency(res))
                                    .foregroundColor(timingStageColor(res))
                            }
                        }
                        // 如果连接被复用，显示提示
                        if timing.dnsLookup == nil && timing.tcpConnection == nil {
                            Text(l10n.connectionReused)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else if let latency = result.latency {
                        LabeledContent(l10n.totalTime) {
                            Text(LanguageManager.formatLatency(latency))
                                .foregroundColor(latencyColor(latency))
                        }
                    } else {
                        Text(l10n.noData)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Timing")
                } footer: {
                    Text(l10n.totalTimeNote)
                }
                
                // Headers 信息
                if let headers = result.headers, !headers.isEmpty {
                    Section {
                        ForEach(headers.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(key)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(value)
                                    .font(.subheadline)
                                    .textSelection(.enabled)
                            }
                            .padding(.vertical, 2)
                        }
                    } header: {
                        Text("Headers")
                    }
                }
                
                // 错误信息
                if let error = result.errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    } header: {
                        Text(l10n.error)
                    }
                }
            }
            .navigationTitle(result.target.label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(l10n.done) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func latencyColor(_ latency: Double) -> Color {
        if latency < 600 {
            return .green
        } else if latency < 1000 {
            return .orange
        } else {
            return .red
        }
    }
    
    private func timingStageColor(_ latency: Double) -> Color {
        if latency < 50 {
            return .green
        } else if latency < 150 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - 添加目标 Sheet
struct AddTargetSheet: View {
    @Binding var newURL: String
    let onSave: (LatencyCategory, String) -> Void
    let onCancel: () -> Void
    
    @EnvironmentObject var languageManager: LanguageManager
    @StateObject private var manager = LatencyTestManager.shared
    @State private var newName = ""
    @State private var selectedCategory: LatencyCategory = .custom
    @State private var showNewCategorySheet = false
    @State private var newCategoryName = ""
    @FocusState private var isURLFieldFocused: Bool
    @FocusState private var isNameFieldFocused: Bool
    
    private var l10n: L10n { L10n.shared }
    
    // URL 快捷键
    private let urlShortcuts = ["https://", "http://", "www.", ".com", ".cn", ".net", ".org", ".io"]
    
    var body: some View {
        NavigationStack {
            Form {
                // 名称输入
                Section {
                    TextField(l10n.labelPlaceholder, text: $newName)
                        .focused($isNameFieldFocused)
                } header: {
                    Text(l10n.labelTitle)
                }
                
                Section {
                    TextField(l10n.urlPlaceholder, text: $newURL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .focused($isURLFieldFocused)
                    
                    // URL 快捷键
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(urlShortcuts, id: \.self) { shortcut in
                                Button {
                                    insertURLShortcut(shortcut)
                                } label: {
                                    Text(shortcut)
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color(.systemGray5))
                                        .foregroundColor(.primary)
                                        .cornerRadius(6)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("URL")
                } footer: {
                    Text(l10n.urlHint)
                }
                
                // 分类选择
                Section {
                    // 预定义分类
                    Picker(l10n.categoryTitle, selection: $selectedCategory) {
                        Text(l10n.noCategoryOption).tag(LatencyCategory.custom)
                        
                        ForEach(LatencyCategory.selectableCases, id: \.rawValue) { category in
                            Text(category.displayName).tag(category)
                        }
                        
                        // 用户自定义分类
                        if !manager.customCategories.isEmpty {
                            Section {
                                ForEach(manager.customCategories, id: \.self) { name in
                                    Text(name).tag(LatencyCategory.userDefined(name))
                                }
                            }
                        }
                    }
                    
                    // 创建新分类按钮
                    Button {
                        isURLFieldFocused = false
                        showNewCategorySheet = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text(l10n.createNewCategory)
                        }
                        .foregroundColor(.blue)
                    }
                } header: {
                    Text(l10n.categoryTitle)
                } footer: {
                    Text(l10n.categoryHint)
                }
            }
            .navigationTitle(l10n.addCustomTarget)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l10n.cancel) {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(l10n.confirm) {
                        onSave(selectedCategory, newName)
                    }
                    .disabled(newURL.isEmpty || newName.isEmpty)
                }
            }
            .sheet(isPresented: $showNewCategorySheet) {
                NewCategorySheet(
                    categoryName: $newCategoryName,
                    onSave: {
                        if !newCategoryName.isEmpty {
                            manager.addCustomCategory(newCategoryName)
                            selectedCategory = .userDefined(newCategoryName)
                            newCategoryName = ""
                        }
                        showNewCategorySheet = false
                    },
                    onCancel: {
                        newCategoryName = ""
                        showNewCategorySheet = false
                    }
                )
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    private func insertURLShortcut(_ shortcut: String) {
        // 智能插入逻辑
        if shortcut.hasPrefix("http") {
            // 协议前缀：如果已有协议则替换，否则插入到开头
            if newURL.hasPrefix("http://") || newURL.hasPrefix("https://") {
                if let range = newURL.range(of: "^https?://", options: .regularExpression) {
                    newURL.replaceSubrange(range, with: shortcut)
                }
            } else {
                newURL = shortcut + newURL
            }
        } else if shortcut == "www." {
            // www. 插入到协议后面或开头
            if let range = newURL.range(of: "^https?://", options: .regularExpression) {
                let afterProtocol = newURL.index(range.upperBound, offsetBy: 0)
                if !newURL[afterProtocol...].hasPrefix("www.") {
                    newURL.insert(contentsOf: shortcut, at: afterProtocol)
                }
            } else if !newURL.hasPrefix("www.") {
                newURL = shortcut + newURL
            }
        } else {
            // 域名后缀：追加到末尾
            newURL += shortcut
        }
    }
}

// MARK: - 新建分类 Sheet
struct NewCategorySheet: View {
    @Binding var categoryName: String
    let onSave: () -> Void
    let onCancel: () -> Void
    
    @FocusState private var isTextFieldFocused: Bool
    private var l10n: L10n { L10n.shared }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(l10n.categoryNamePlaceholder, text: $categoryName)
                        .focused($isTextFieldFocused)
                } footer: {
                    Text(l10n.createCategoryMessage)
                }
            }
            .navigationTitle(l10n.createNewCategory)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l10n.cancel) {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(l10n.confirm) {
                        onSave()
                    }
                    .disabled(categoryName.isEmpty)
                }
            }
            .onAppear {
                isTextFieldFocused = true
            }
        }
        .presentationDetents([.height(200)])
    }
}

// MARK: - LatencyResult Equatable for Sheet
// 已移动到 LatencyTestManager 中正确实现

#Preview {
    NavigationStack {
        LatencyTestView()
            .environmentObject(LanguageManager.shared)
    }
}
