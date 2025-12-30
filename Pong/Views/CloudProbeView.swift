//
//  CloudProbeView.swift
//  Pong
//
//  Created by 张金琛 on 2025/12/14.
//

import SwiftUI
import Network

// MARK: - 云探测视图
struct CloudProbeView: View {
    @EnvironmentObject var languageManager: LanguageManager
    @State private var locations: [ProbeLocation] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isWaitingForPermission = false
    @State private var networkMonitor: NWPathMonitor?
    
    // 选择状态
    @State private var selectedCountry: String? = nil
    @State private var selectedISP: String? = nil
    @State private var selectedASId: Int? = nil
    
    // 探测类型
    @State private var probeType: CloudProbeType = .ping
    
    // 目标地址
    @State private var targetHost: String = ""
    @StateObject private var hostHistoryManager = HostHistoryManager.shared
    
    // TCP/UDP 端口
    @State private var targetPort: String = "443"
    
    // DNS 记录类型
    @State private var dnsRecordType: String = "A"
    private let dnsRecordTypes = ["A", "AAAA", "CNAME", "MX", "NS", "TXT", "SOA"]
    
    // 创建任务状态
    @State private var isCreatingTask = false
    @State private var showCreateResult = false
    @State private var createResultMessage: String = ""
    @State private var createResultSuccess = false
    
    // 查询结果状态
    @State private var isQueryingResult = false
    @State private var queryCount = 0
    @State private var pingResults: [CloudPingResult] = []
    @State private var dnsResults: [CloudDNSResult] = []
    @State private var showResults = false
    @State private var isFilterCollapsed = false
    
    // 登录相关状态
    @StateObject private var userManager = UserManager.shared
    @State private var showLoginSheet = false
    
    // Manager
    private let probeManager = CloudProbeManager.shared
    
    // 主题色
    private let accentColor = Color.blue
    private let cardBackground = Color(.systemBackground)
    private let pageBackground = Color(.systemGray6)
    
    private var l10n: L10n { L10n.shared }
    
    // 计算属性：所有国家列表
    private var allCountries: [String] {
        Array(Set(locations.map { $0.displayCountry })).sorted()
    }
    
    // 计算属性：根据选中国家筛选运营商
    private var filteredISPs: [String] {
        let filtered = selectedCountry == nil ? locations : locations.filter { $0.displayCountry == selectedCountry }
        return Array(Set(filtered.map { $0.displayISP })).sorted()
    }
    
    // 获取国家的本地化显示名称
    private func localizedCountryName(_ country: String) -> String {
        if LanguageManager.shared.currentLanguage == .english {
            return country.toEnglishCountry()
        }
        return country
    }
    
    // 获取运营商的本地化显示名称
    private func localizedISPName(_ isp: String) -> String {
        if LanguageManager.shared.currentLanguage == .english {
            return isp.toEnglishISP()
        }
        return isp
    }
    
    // 计算属性：根据选中国家和运营商筛选AS号
    private var filteredASIds: [Int] {
        var filtered = locations
        if let country = selectedCountry {
            filtered = filtered.filter { $0.displayCountry == country }
        }
        if let isp = selectedISP {
            filtered = filtered.filter { $0.displayISP == isp }
        }
        return Array(Set(filtered.map { $0.AsId })).sorted()
    }
    
    // 是否有有效选择
    private var hasValidSelection: Bool {
        (selectedCountry != nil || selectedISP != nil || selectedASId != nil) && !targetHost.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 内容区域
                Group {
                    if isLoading {
                        VStack(spacing: 16) {
                            ProgressView()
                                .tint(accentColor)
                            Text(l10n.loading)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let error = errorMessage {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.largeTitle)
                                .foregroundColor(.orange)
                            Text(error)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            Button(l10n.retry) {
                                Task { await fetchCloudProbe() }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(accentColor)
                        }
                        .padding(.horizontal, 32)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if !locations.isEmpty {
                        ScrollView {
                            VStack(spacing: 16) {
                                // 探测类型 Tab 栏
                                probeTypeSelector
                                
                                // 目标地址输入框
                                targetInputSection
                                
                                // 选择器区域
                                filterSection
                                
                                // 创建任务按钮
                                createTaskButton
                                
                                // 查询状态
                                if isQueryingResult {
                                    queryingStatusView
                                }
                                
                                // 结果表格
                                if showResults && (!pingResults.isEmpty || !dnsResults.isEmpty) {
                                    resultTableSection
                                        .padding(.horizontal)
                                }
                                
                                Spacer(minLength: 20)
                            }
                            .padding(.top, 12)
                        }
                    } else {
                        Text(l10n.noData)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .background(pageBackground)
            .navigationBarHidden(true)
            .task {
                await fetchCloudProbeWithPermissionMonitor()
            }
            .onDisappear {
                stopNetworkMonitor()
            }
            .alert(createResultSuccess ? l10n.success : l10n.failure, isPresented: $showCreateResult) {
                Button(l10n.confirm, role: .cancel) { }
            } message: {
                Text(createResultMessage)
            }
            .sheet(isPresented: $showLoginSheet) {
                LoginView {
                    Task { await createTask() }
                }
            }
        }
    }
    
    // MARK: - 探测类型选择器
    private var probeTypeSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "list.bullet")
                    .foregroundColor(accentColor)
                Text(l10n.probeType)
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
                if hasValidSelection {
                    Button(l10n.clear) {
                        selectedCountry = nil
                        selectedISP = nil
                        selectedASId = nil
                        targetHost = ""
                        targetPort = "443"
                    }
                    .font(.subheadline)
                    .foregroundColor(accentColor)
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(CloudProbeType.allCases, id: \.self) { type in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                probeType = type
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: type.icon)
                                    .font(.caption)
                                Text(type.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(probeType == type ? .semibold : .regular)
                            }
                            .foregroundColor(probeType == type ? .white : .secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(probeType == type ? accentColor : Color(.systemGray6))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding()
        .background(cardBackground)
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    // MARK: - 目标地址输入区
    private var targetInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "target")
                    .foregroundColor(accentColor)
                Text(l10n.targetAddress)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            // 使用公共的 HostInputField 组件
            HostInputField(
                text: $targetHost,
                placeholder: l10n.targetExample,
                history: hostHistoryManager.cloudProbeHistory,
                onHistorySelect: { _ in },
                onHistoryDelete: { host in
                    hostHistoryManager.removeCloudProbeHistory(host)
                }
            )
            
            // TCP/UDP 端口输入
            if probeType == .tcp || probeType == .udp {
                HStack {
                    Image(systemName: "number")
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    TextField(l10n.portDefault, text: $targetPort)
                        .keyboardType(.numberPad)
                }
                .padding(12)
                .background(Color(.systemBackground))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.systemGray4), lineWidth: 0.5)
                )
            }
            
            // DNS 记录类型选择
            if probeType == .dns {
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    Text(l10n.recordType)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Picker("", selection: $dnsRecordType) {
                        ForEach(dnsRecordTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(accentColor)
                }
                .padding(12)
                .background(Color(.systemBackground))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.systemGray4), lineWidth: 0.5)
                )
            }
        }
        .padding()
        .background(cardBackground)
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    // MARK: - 筛选条件区
    private var filterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题栏（可点击折叠）
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isFilterCollapsed.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(accentColor)
                    Text(l10n.filterCondition)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    Spacer()
                    if !isFilterCollapsed {
                        Text(l10n.selectAtLeastOne)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        // 折叠时显示已选条件摘要
                        if selectedCountry != nil || selectedISP != nil || selectedASId != nil {
                            Text(filterSummary)
                                .font(.caption2)
                                .foregroundColor(accentColor)
                                .lineLimit(1)
                        }
                    }
                    Image(systemName: isFilterCollapsed ? "chevron.down" : "chevron.up")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            // 筛选内容（可折叠）
            if !isFilterCollapsed {
                // 国家选择器
                filterRow(icon: "flag.fill", title: l10n.country, isSelected: selectedCountry != nil) {
                    Picker(l10n.country, selection: $selectedCountry) {
                        Text(l10n.all).tag(nil as String?)
                        ForEach(allCountries, id: \.self) { country in
                            Text(localizedCountryName(country)).tag(country as String?)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(accentColor)
                    .onChange(of: selectedCountry) { _, _ in
                        if let isp = selectedISP, !filteredISPs.contains(isp) {
                            selectedISP = nil
                        }
                        if let asId = selectedASId, !filteredASIds.contains(asId) {
                            selectedASId = nil
                        }
                    }
                }
                
                // 运营商选择器
                filterRow(icon: "building.2.fill", title: l10n.isp, isSelected: selectedISP != nil) {
                    Picker(l10n.isp, selection: $selectedISP) {
                        Text(l10n.all).tag(nil as String?)
                        ForEach(filteredISPs, id: \.self) { isp in
                            Text(localizedISPName(isp)).tag(isp as String?)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(accentColor)
                    .onChange(of: selectedISP) { _, _ in
                        if let asId = selectedASId, !filteredASIds.contains(asId) {
                            selectedASId = nil
                        }
                    }
                }
                
                // AS号选择器
                filterRow(icon: "number.circle.fill", title: l10n.asNumber, isSelected: selectedASId != nil) {
                    Picker(l10n.asNumber, selection: $selectedASId) {
                        Text(l10n.all).tag(nil as Int?)
                        ForEach(filteredASIds, id: \.self) { asId in
                            Text("AS\(asId)").tag(asId as Int?)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(accentColor)
                }
            }
        }
        .padding()
        .background(cardBackground)
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    // 筛选条件摘要
    private var filterSummary: String {
        var parts: [String] = []
        if let country = selectedCountry {
            parts.append(localizedCountryName(country))
        }
        if let isp = selectedISP {
            parts.append(localizedISPName(isp))
        }
        if let asId = selectedASId {
            parts.append("AS\(asId)")
        }
        return parts.joined(separator: " · ")
    }
    
    // 筛选行组件
    private func filterRow<Content: View>(icon: String, title: String, isSelected: Bool = false, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(isSelected ? accentColor : .secondary)
                .frame(width: 20)
            Text(title)
                .font(.subheadline)
                .foregroundColor(isSelected ? accentColor : .secondary)
            Spacer()
            content()
        }
        .padding(10)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
    }
    
    // MARK: - 创建任务按钮
    private var createTaskButton: some View {
        Button {
            if !userManager.isLoggedIn {
                showLoginSheet = true
            } else {
                Task { await createTask() }
            }
        } label: {
            HStack(spacing: 8) {
                if isCreatingTask || isQueryingResult {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                } else {
                    Image(systemName: "play.fill")
                }
                Text(isCreatingTask ? l10n.creating : (isQueryingResult ? l10n.probing : l10n.startProbe))
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(hasValidSelection && !isCreatingTask && !isQueryingResult ? accentColor : Color(.systemGray4))
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .disabled(!hasValidSelection || isCreatingTask || isQueryingResult)
        .padding(.horizontal)
    }
    
    // MARK: - 查询状态视图
    private var queryingStatusView: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(accentColor)
            Text(l10n.queryingResult)
                .foregroundColor(.primary)
            Text("(\(queryCount)/5)")
                .foregroundColor(accentColor)
                .font(.system(.body, design: .monospaced))
        }
        .padding()
        .background(cardBackground)
        .cornerRadius(10)
        .padding(.horizontal)
    }
    
    // MARK: - 结果表格
    @ViewBuilder
    private var resultTableSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.doc.horizontal")
                    .foregroundColor(accentColor)
                Text(l10n.probeResult)
                    .font(.headline)
                Spacer()
                Text("\(probeType == .dns ? dnsResults.count : pingResults.count) \(l10n.records)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray6))
                    .cornerRadius(4)
            }
            
            // Ping结果表格
            if probeType == .ping || probeType == .tcp || probeType == .udp {
                ForEach(pingResults) { result in
                    pingResultCard(result)
                }
            }
            
            // DNS结果表格
            if probeType == .dns {
                ForEach(dnsResults) { result in
                    dnsResultCard(result)
                }
            }
        }
        .padding()
        .background(cardBackground)
        .cornerRadius(12)
    }
    
    // MARK: - Ping结果卡片
    @ViewBuilder
    private func pingResultCard(_ result: CloudPingResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // 位置信息头部
            HStack {
                // 国家标签
                Text(localizedCountryName(result.AgentCountry ?? l10n.unknown))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                if let province = result.AgentProvince, !province.isEmpty {
                    Text("·")
                        .foregroundColor(.secondary)
                    Text(LanguageManager.shared.currentLanguage == .english ? province.toEnglishCountry() : province)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // AS号标签
                Text("AS\(String(format: "%d", result.AgentAsId))")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(accentColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(accentColor.opacity(0.1))
                    .cornerRadius(4)
            }
            
            // 运营商
            if let isp = result.AgentISP, !isp.isEmpty {
                Text(localizedISPName(isp))
                    .font(.caption)
                    .foregroundColor(accentColor)
            }
            
            // IP 信息
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Text(l10n.source)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                    Text(result.BuildinAgentRemoteIP ?? "-")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.primary)
                }
                HStack(spacing: 4) {
                    Text(l10n.destination)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                    Text(result.BuildinPeerIP ?? "-")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                }
            }
            
            Divider()
            
            // RTT和丢包率统计 - 一行显示
            HStack(spacing: 0) {
                // 平均延时
                VStack(spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(String(format: "%.1f", result.AvgRttMilli ?? 0))
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(.green)
                        Text("ms")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    Text(l10n.average)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                // 最小延时
                VStack(spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(String(format: "%.1f", result.MinRttMilli ?? 0))
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                        Text("ms")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    Text(l10n.minimum)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                // 最大延时
                VStack(spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(String(format: "%.1f", result.MaxRttMilli ?? 0))
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                        Text("ms")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    Text(l10n.maximum)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                // 丢包率
                VStack(spacing: 2) {
                    Text(String(format: "%.0f%%", (result.PacketLoss ?? 0) * 100))
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor((result.PacketLoss ?? 0) > 0 ? .red : .green)
                    Text(l10n.packetLoss)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            
            // 错误信息
            if let errMsg = result.BuildinErrMessage, !errMsg.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text(errMsg)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(6)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    // MARK: - DNS结果卡片
    @ViewBuilder
    private func dnsResultCard(_ result: CloudDNSResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // 位置信息头部
            HStack {
                Text(localizedCountryName(result.AgentCountry ?? l10n.unknown))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                if let province = result.AgentProvince, !province.isEmpty {
                    Text("·")
                        .foregroundColor(.secondary)
                    Text(LanguageManager.shared.currentLanguage == .english ? province.toEnglishCountry() : province)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("AS\(String(format: "%d", result.AgentAsId))")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(accentColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(accentColor.opacity(0.1))
                    .cornerRadius(4)
            }
            
            // 运营商
            if let isp = result.AgentISP, !isp.isEmpty {
                Text(localizedISPName(isp))
                    .font(.caption)
                    .foregroundColor(accentColor)
            }
            
            // Agent IP 和 DNS服务器
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(l10n.sourceIP)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                    Text(result.BuildinAgentRemoteIP ?? "-")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.primary)
                }
                
                HStack(spacing: 4) {
                    Text("DNS:")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                    Text(result.AtNameServer ?? "-")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }
            }
            
            Divider()
            
            // 查询耗时
            HStack {
                Text(l10n.queryTime)
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(String(format: "%.0f", result.RttMilli ?? 0))
                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                        .foregroundColor(.green)
                    Text("ms")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            
            // DNS解析结果
            if let answers = result.Answers, !answers.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(l10n.resolveResult)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ForEach(answers) { answer in
                        HStack(spacing: 8) {
                            // 记录类型标签
                            Text(answer.RRType ?? "-")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(recordTypeColor(answer.RRType))
                                .cornerRadius(4)
                            
                            // 解析结果
                            Text(answer.ParseIP ?? "-")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            
                            Spacer()
                        }
                    }
                }
            }
            
            // 错误信息
            if let errMsg = result.BuildinErrMessage, !errMsg.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text(errMsg)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(6)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    // DNS记录类型颜色
    private func recordTypeColor(_ type: String?) -> Color {
        switch type {
        case "A": return .blue
        case "AAAA": return .purple
        case "CNAME": return .orange
        case "MX": return .green
        case "NS": return .teal
        case "TXT": return .pink
        case "SOA": return .indigo
        default: return .gray
        }
    }

    // MARK: - 创建任务
    private func createTask() async {
        // 收起键盘
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
        let trimmedHost = targetHost.trimmingCharacters(in: .whitespaces)
        
        // 验证域名/IP 格式
        if !probeManager.isValidHostOrIP(trimmedHost) {
            createResultSuccess = false
            createResultMessage = l10n.invalidHostFormat
            showCreateResult = true
            return
        }
        
        // 保存目标地址到历史记录
        hostHistoryManager.addCloudProbeHistory(targetHost)
        
        // 折叠筛选条件区
        withAnimation(.easeInOut(duration: 0.2)) {
            isFilterCollapsed = true
        }
        
        isCreatingTask = true
        showResults = false
        pingResults = []
        dnsResults = []
        queryCount = 0
        
        let params = CreateTaskParams(
            probeType: probeType,
            targetHost: trimmedHost,
            targetPort: targetPort,
            dnsRecordType: dnsRecordType,
            selectedCountry: selectedCountry,
            selectedISP: selectedISP,
            selectedASId: selectedASId,
            userId: userManager.currentUser?.userId ?? 1
        )
        
        do {
            let mainTaskId = try await probeManager.createTask(params: params)
            isCreatingTask = false
            
            // 开始轮询查询结果
            await queryTaskResult(mainTaskId: mainTaskId)
        } catch {
            createResultSuccess = false
            createResultMessage = error.localizedDescription
            isCreatingTask = false
            showCreateResult = true
        }
    }
    
    // MARK: - 查询任务结果
    private func queryTaskResult(mainTaskId: Int) async {
        isQueryingResult = true
        queryCount = 0
        
        let userId = userManager.currentUser?.userId ?? 1
        
        do {
            let result = try await probeManager.pollTaskResult(
                mainTaskId: mainTaskId,
                userId: userId,
                probeType: probeType,
                maxRetries: 5
            ) { count, partialResult in
                queryCount = count
                if probeType == .dns {
                    dnsResults = partialResult.dnsResults
                } else {
                    pingResults = partialResult.pingResults
                }
                if !partialResult.pingResults.isEmpty || !partialResult.dnsResults.isEmpty {
                    showResults = true
                }
            }
            
            isQueryingResult = false
            
            if result.pingResults.isEmpty && result.dnsResults.isEmpty {
                createResultSuccess = false
                createResultMessage = l10n.noProbeResult
                showCreateResult = true
            }
        } catch {
            isQueryingResult = false
            createResultSuccess = false
            createResultMessage = error.localizedDescription
            showCreateResult = true
        }
    }
    
    // MARK: - 发起请求
    private func fetchCloudProbe() async {
        isLoading = true
        errorMessage = nil
        
        let userId = userManager.currentUser?.userId ?? 1
        
        do {
            locations = try await probeManager.fetchProbeLocations(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - 带权限监听的请求
    private func fetchCloudProbeWithPermissionMonitor() async {
        isLoading = true
        errorMessage = nil
        isWaitingForPermission = true
        
        let userId = userManager.currentUser?.userId ?? 1
        
        do {
            locations = try await probeManager.fetchProbeLocations(userId: userId)
            isWaitingForPermission = false
            stopNetworkMonitor()
        } catch {
            // 请求失败，可能是用户还没授权网络权限
            // 启动网络监听，等待用户授权后自动重试
            if isWaitingForPermission {
                startNetworkMonitor()
            }
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - 网络监听
    private func startNetworkMonitor() {
        stopNetworkMonitor()
        
        let monitor = NWPathMonitor()
        networkMonitor = monitor
        
        monitor.pathUpdateHandler = { [self] path in
            // 当网络状态变为可用时，自动重试
            if path.status == .satisfied && isWaitingForPermission {
                DispatchQueue.main.async {
                    isWaitingForPermission = false
                    stopNetworkMonitor()
                    Task {
                        await fetchCloudProbe()
                    }
                }
            }
        }
        
        let queue = DispatchQueue(label: "CloudProbeNetworkMonitor")
        monitor.start(queue: queue)
    }
    
    private func stopNetworkMonitor() {
        networkMonitor?.cancel()
        networkMonitor = nil
    }
}

#Preview {
    CloudProbeView()
        .environmentObject(LanguageManager.shared)
}
