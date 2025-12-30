//
//  IPQueryView.swift
//  Pong
//
//  Created by 张金琛 on 2025/12/24.
//

import SwiftUI

struct IPQueryView: View {
    @EnvironmentObject var languageManager: LanguageManager
    @State private var inputIP: String = ""
    @State private var isQuerying = false
    @State private var queryResult: BatchIPInfo?
    @State private var errorMessage: String?
    @State private var hasQueried = false
    @FocusState private var isInputFocused: Bool
    
    // 历史记录
    @State private var ipHistory: [String] = []
    @State private var showHistory = false
    
    // 复制提示
    @State private var showCopyToast = false
    
    private var l10n: L10n { L10n.shared }
    
    // 主题色
    private let accentColor = Color.blue
    private let cardBackground = Color(.systemBackground)
    private let pageBackground = Color(.systemGray6)
    
    // 历史记录存储 key
    private let ipHistoryKey = "IPQueryHistory"
    private let maxHistoryCount = 10
    
    // 是否有有效输入
    private var hasValidInput: Bool {
        !inputIP.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // IP 输入区域
                ipInputSection
                
                // 查询按钮
                queryButton
                
                // 查询结果
                if hasQueried {
                    resultSection
                }
                
                Spacer(minLength: 20)
            }
            .padding(.top, 16)
        }
        .background(pageBackground)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadHistory()
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
    
    // MARK: - IP 输入区域
    private var ipInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "network")
                    .foregroundColor(accentColor)
                Text(l10n.ipQueryInput)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "globe")
                        .foregroundColor(hasValidInput ? accentColor : .secondary)
                        .frame(width: 24)
                    TextField(l10n.ipQueryPlaceholder, text: $inputIP)
                        .font(.body)
                        .keyboardType(.numbersAndPunctuation)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($isInputFocused)
                    
                    if !ipHistory.isEmpty {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showHistory.toggle()
                            }
                        } label: {
                            Image(systemName: showHistory ? "chevron.up" : "clock.arrow.circlepath")
                                .foregroundColor(accentColor)
                                .font(.subheadline)
                        }
                    }
                    
                    if !inputIP.isEmpty {
                        Button {
                            inputIP = ""
                            queryResult = nil
                            errorMessage = nil
                            hasQueried = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(14)
                .background(Color(.systemBackground))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(hasValidInput ? accentColor : Color(.systemGray4), lineWidth: hasValidInput ? 1.5 : 0.5)
                )
                
                // 历史记录列表
                if showHistory && !ipHistory.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(ipHistory, id: \.self) { ip in
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                                Text(ip)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                Spacer()
                                
                                // 删除按钮
                                Button {
                                    removeFromHistory(ip)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                inputIP = ip
                                showHistory = false
                                // 自动开始查询
                                queryIP()
                            }
                            
                            if ip != ipHistory.last {
                                Divider()
                                    .padding(.leading, 40)
                            }
                        }
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.systemGray4), lineWidth: 0.5)
                    )
                }
            }
        }
        .padding()
        .background(cardBackground)
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    // MARK: - 查询按钮
    private var queryButton: some View {
        Button {
            queryIP()
        } label: {
            HStack(spacing: 8) {
                if isQuerying {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                } else {
                    Image(systemName: "magnifyingglass")
                }
                Text(isQuerying ? l10n.querying : l10n.query)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(hasValidInput && !isQuerying ? accentColor : Color(.systemGray4))
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .disabled(!hasValidInput || isQuerying)
        .padding(.horizontal)
    }
    
    // MARK: - 查询结果区域
    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.text")
                    .foregroundColor(accentColor)
                Text(l10n.queryResult)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                
                // 复制按钮
                if queryResult != nil {
                    Button {
                        if let result = queryResult {
                            copyAllResults(result)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.doc")
                            Text(l10n.copyText)
                        }
                        .font(.caption)
                        .foregroundColor(accentColor)
                    }
                }
            }
            
            if let result = queryResult {
                VStack(spacing: 0) {
                    resultRow(title: "IP", value: result.IP ?? "-")
                    Divider().padding(.leading, 16)
                    resultRow(title: l10n.country, value: localizedCountry(result.Country))
                    Divider().padding(.leading, 16)
                    resultRow(title: l10n.province, value: result.Province?.isEmpty == false ? result.Province! : "-")
                    Divider().padding(.leading, 16)
                    resultRow(title: l10n.city, value: result.City?.isEmpty == false ? result.City! : "-")
                    Divider().padding(.leading, 16)
                    resultRow(title: l10n.isp, value: localizedISP(result.FrontISP))
                    Divider().padding(.leading, 16)
                    resultRow(title: "AS", value: result.AsId != nil ? "AS\(result.AsId!)" : "-")
                    Divider().padding(.leading, 16)
                    resultRow(title: l10n.location, value: {
                        let loc = localizedFullLocation(result)
                        return loc.isEmpty ? "-" : loc
                    }())
                }
                .background(Color(.systemBackground))
                .cornerRadius(8)
            } else if let error = errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemBackground))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(cardBackground)
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    // MARK: - 结果行
    private func resultRow(title: String, value: String) -> some View {
        Button {
            UIPasteboard.general.string = value
            showCopyToastAnimation()
        } label: {
            HStack {
                Text(title)
                    .font(.body)
                    .foregroundColor(.secondary)
                Spacer()
                Text(value)
                    .font(.body)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 查询方法
    private func queryIP() {
        // 收起键盘
        isInputFocused = false
        
        let ip = inputIP.trimmingCharacters(in: .whitespaces)
        
        // 验证 IP 格式
        guard IPLocationService.shared.isValidIP(ip) else {
            errorMessage = l10n.invalidIPFormat
            queryResult = nil
            hasQueried = true
            return
        }
        
        // 保存到历史记录
        saveToHistory(ip)
        
        isQuerying = true
        errorMessage = nil
        queryResult = nil
        
        Task {
            let result = await IPLocationService.shared.fetchDetailedLocations(for: [ip])
            
            await MainActor.run {
                isQuerying = false
                hasQueried = true
                
                if let info = result[ip] {
                    queryResult = info
                } else {
                    errorMessage = l10n.queryFailed
                }
            }
        }
    }
    
    // MARK: - 历史记录管理
    private func loadHistory() {
        ipHistory = UserDefaults.standard.stringArray(forKey: ipHistoryKey) ?? []
    }
    
    private func saveToHistory(_ ip: String) {
        // 如果已存在，先移除
        ipHistory.removeAll { $0 == ip }
        // 插入到最前面
        ipHistory.insert(ip, at: 0)
        // 限制数量
        if ipHistory.count > maxHistoryCount {
            ipHistory = Array(ipHistory.prefix(maxHistoryCount))
        }
        // 保存
        UserDefaults.standard.set(ipHistory, forKey: ipHistoryKey)
    }
    
    private func removeFromHistory(_ ip: String) {
        ipHistory.removeAll { $0 == ip }
        UserDefaults.standard.set(ipHistory, forKey: ipHistoryKey)
        
        if ipHistory.isEmpty {
            showHistory = false
        }
    }
    
    // MARK: - 本地化辅助方法
    
    /// 获取本地化的国家名称
    private func localizedCountry(_ country: String?) -> String {
        guard let country = country, !country.isEmpty else { return "-" }
        
        // 英文环境下转换为英文
        if languageManager.currentLanguage == .english {
            return LocalizationMapping.toEnglishCountry(country)
        }
        return country
    }
    
    /// 获取本地化的运营商名称
    private func localizedISP(_ isp: String?) -> String {
        guard let isp = isp, !isp.isEmpty else { return "-" }
        
        // 英文环境下转换为英文
        if languageManager.currentLanguage == .english {
            return LocalizationMapping.toEnglishISP(isp)
        }
        return isp
    }
    
    /// 获取本地化的完整归属地描述（换行拼接）
    private func localizedFullLocation(_ result: BatchIPInfo) -> String {
        var parts: [String] = []
        
        if let country = result.Country, !country.isEmpty {
            if languageManager.currentLanguage == .english {
                parts.append(LocalizationMapping.toEnglishCountry(country))
            } else {
                parts.append(country)
            }
        }
        
        if let province = result.Province, !province.isEmpty {
            if languageManager.currentLanguage == .english {
                parts.append(province.toPinyin())
            } else {
                parts.append(province)
            }
        }
        
        // 城市与省份不同时才显示
        if let city = result.City, !city.isEmpty, city != result.Province {
            if languageManager.currentLanguage == .english {
                parts.append(city.toPinyin())
            } else {
                parts.append(city)
            }
        }
        
        if let isp = result.FrontISP, !isp.isEmpty {
            if languageManager.currentLanguage == .english {
                parts.append(LocalizationMapping.toEnglishISP(isp))
            } else {
                parts.append(isp)
            }
        }
        
        return parts.isEmpty ? "-" : parts.joined(separator: "\n")
    }
    
    // MARK: - 复制所有结果
    private func copyAllResults(_ result: BatchIPInfo) {
        var lines: [String] = []
        lines.append("IP: \(result.IP ?? "-")")
        lines.append("\(l10n.country): \(localizedCountry(result.Country))")
        lines.append("\(l10n.province): \(result.Province ?? "-")")
        lines.append("\(l10n.city): \(result.City ?? "-")")
        lines.append("\(l10n.isp): \(localizedISP(result.FrontISP))")
        lines.append("AS: \(result.AsId != nil ? "AS\(result.AsId!)" : "-")")
        lines.append("\(l10n.location): \(localizedFullLocation(result))")
        
        UIPasteboard.general.string = lines.joined(separator: "\n")
        showCopyToastAnimation()
    }
    
    // MARK: - 显示复制提示动画
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

#Preview {
    IPQueryView()
        .environmentObject(LanguageManager.shared)
}
