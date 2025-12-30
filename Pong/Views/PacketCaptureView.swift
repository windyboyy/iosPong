//
//  PacketCaptureView.swift
//  Pong
//
//  Created by 张金琛 on 2025/12/15.
//
//  类似 Stream App 的抓包界面
//

import SwiftUI

// MARK: - 网络抓包视图
struct PacketCaptureView: View {
    @StateObject private var captureManager = PacketCaptureManager.shared
    @State private var selectedPacket: CapturedPacket?
    @State private var showExportSheet = false
    @State private var showFilterSheet = false
    @State private var showCertificateSheet = false
    @State private var showSetupGuide = false
    @State private var searchText = ""
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var pollingTimer: Timer?
    
    private var l10n: L10n { L10n.shared }
    
    var body: some View {
        VStack(spacing: 0) {
            // VPN 状态和控制
            vpnControlSection
            
            // 统计信息栏
            if captureManager.isCapturing {
                statsBar
            }
            
            // 搜索栏
            if !captureManager.capturedPackets.isEmpty {
                searchBar
            }
            
            // 数据包列表
            packetList
        }
        .navigationTitle(l10n.packetCaptureTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    // HTTPS 证书
                    Button {
                        showCertificateSheet = true
                    } label: {
                        Image(systemName: "lock.shield")
                    }
                    
                    // 过滤
                    Button {
                        showFilterSheet = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundColor(captureManager.filterProtocol != nil ? .orange : .primary)
                    }
                    
                    // 导出
                    Button {
                        showExportSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(captureManager.capturedPackets.isEmpty)
                    
                    // 清除
                    Button {
                        captureManager.clearPackets()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .disabled(captureManager.capturedPackets.isEmpty)
                }
            }
        }
        .sheet(item: $selectedPacket) { packet in
            PacketDetailView(packet: packet)
        }
        .sheet(isPresented: $showFilterSheet) {
            FilterSheetView(captureManager: captureManager)
        }
        .sheet(isPresented: $showExportSheet) {
            ExportSheetView(content: captureManager.exportPackets())
        }
        .sheet(isPresented: $showCertificateSheet) {
            CertificateSetupView(captureManager: captureManager)
        }
        .sheet(isPresented: $showSetupGuide) {
            SetupGuideView()
        }
        .alert(l10n.errorTitle, isPresented: $showError) {
            Button(l10n.ok, role: .cancel) { }
        } message: {
            Text(errorMessage ?? l10n.unknownError)
        }
        .onChange(of: searchText) { _, newValue in
            captureManager.filterKeyword = newValue
        }
        .onAppear {
            startPolling()
        }
        .onDisappear {
            stopPolling()
        }
    }
    
    // MARK: - VPN 控制区域
    private var vpnControlSection: some View {
        VStack(spacing: 16) {
            // 状态卡片
            VStack(spacing: 16) {
                // 状态显示
                HStack {
                    // 状态指示灯
                    Circle()
                        .fill(vpnStatusColor)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(vpnStatusColor.opacity(0.3), lineWidth: 4)
                        )
                    
                    Text(l10n.captureStatus)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(captureManager.vpnStatus.rawValue)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(vpnStatusColor)
                }
                
                // 主控制按钮
                Button {
                    handleCaptureToggle()
                } label: {
                    HStack(spacing: 12) {
                        if captureManager.vpnStatus == .connecting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: captureManager.isCapturing ? "stop.fill" : "play.fill")
                        }
                        Text(buttonTitle)
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(buttonColor)
                    .cornerRadius(14)
                }
                .disabled(captureManager.vpnStatus == .connecting || captureManager.vpnStatus == .disconnecting)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
            .padding(.horizontal)
            
            // 提示信息
            if !captureManager.isVPNConfigured {
                tipCard(
                    icon: "info.circle.fill",
                    color: .blue,
                    text: l10n.firstTimeSetup
                )
            } else if captureManager.isCapturing {
                tipCard(
                    icon: "antenna.radiowaves.left.and.right",
                    color: .green,
                    text: l10n.capturingTraffic
                )
            }
        }
        .padding(.vertical, 12)
        .background(Color(.systemGroupedBackground))
    }
    
    private func tipCard(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal)
    }
    
    private var buttonTitle: String {
        switch captureManager.vpnStatus {
        case .invalid:
            return l10n.configureAndStart
        case .disconnected:
            return l10n.startCapture
        case .connecting:
            return l10n.connecting
        case .connected:
            return l10n.stopCapture
        case .disconnecting:
            return l10n.disconnecting
        }
    }
    
    private var buttonColor: Color {
        switch captureManager.vpnStatus {
        case .connected:
            return .red
        case .connecting, .disconnecting:
            return .gray
        default:
            return .green
        }
    }
    
    private var vpnStatusColor: Color {
        switch captureManager.vpnStatus {
        case .connected: return .green
        case .connecting, .disconnecting: return .orange
        case .disconnected: return .gray
        case .invalid: return .gray
        }
    }
    
    private func handleCaptureToggle() {
        if captureManager.isCapturing {
            captureManager.stopCapture()
        } else {
            Task {
                do {
                    try await captureManager.startCapture()
                } catch {
                    // 检查是否是权限问题
                    if error.localizedDescription.contains("permission") ||
                       error.localizedDescription.contains("entitlement") {
                        showSetupGuide = true
                    } else {
                        errorMessage = error.localizedDescription
                        showError = true
                    }
                }
            }
        }
    }
    
    // MARK: - 统计信息栏
    private var statsBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                CaptureStatItem(title: l10n.packets, value: "\(captureManager.totalPackets)", icon: "doc.text")
                Divider().frame(height: 40)
                CaptureStatItem(title: l10n.totalTraffic, value: PacketCaptureManager.formatBytes(captureManager.totalBytes), icon: "arrow.left.arrow.right")
                Divider().frame(height: 40)
                CaptureStatItem(title: l10n.outgoing, value: PacketCaptureManager.formatBytes(captureManager.outgoingBytes), icon: "arrow.up")
                Divider().frame(height: 40)
                CaptureStatItem(title: l10n.incoming, value: PacketCaptureManager.formatBytes(captureManager.incomingBytes), icon: "arrow.down")
            }
            .padding(.vertical, 10)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - 搜索栏
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField(l10n.searchPlaceholder, text: $searchText)
                .textFieldStyle(.plain)
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - 数据包列表
    private var packetList: some View {
        Group {
            if captureManager.filteredPackets.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(captureManager.filteredPackets) { packet in
                        PacketRowView(packet: packet)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedPacket = packet
                            }
                    }
                }
                .listStyle(.plain)
            }
        }
    }
    
    // MARK: - 空状态
    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 50))
                    .foregroundColor(.blue.opacity(0.6))
            }
            
            VStack(spacing: 8) {
                Text(emptyStateTitle)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(emptyStateSubtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
        }
    }
    
    private var emptyStateTitle: String {
        if captureManager.isCapturing {
            return l10n.waitingForRequests
        } else if captureManager.isVPNConfigured {
            return l10n.tapToStartCapture
        } else {
            return l10n.configureCapture
        }
    }
    
    private var emptyStateSubtitle: String {
        if captureManager.isCapturing {
            return l10n.openOtherApps
        } else if captureManager.isVPNConfigured {
            return l10n.tapButtonToStart
        } else {
            return l10n.firstTimeVPNSetup
        }
    }
    
    // MARK: - 轮询
    private func startPolling() {
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            Task { @MainActor in
                if captureManager.isCapturing {
                    captureManager.loadPacketsFromExtension()
                }
            }
        }
    }
    
    private func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }
}

// MARK: - 抓包统计项
struct CaptureStatItem: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 证书设置视图
struct CertificateSetupView: View {
    @ObservedObject var captureManager: PacketCaptureManager
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 0
    
    private var l10n: L10n { L10n.shared }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 说明
                    VStack(alignment: .leading, spacing: 8) {
                        Label(l10n.httpsCapture, systemImage: "lock.shield")
                            .font(.headline)
                        
                        Text(l10n.httpsCaptureDesc)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // 步骤
                    VStack(spacing: 16) {
                        ForEach(captureManager.getCertificateInstallInstructions(), id: \.step) { instruction in
                            CertificateStepView(
                                step: instruction.step,
                                title: instruction.title,
                                description: instruction.description,
                                actionTitle: instruction.action,
                                isCompleted: instruction.step <= captureManager.certificateStatus.step,
                                action: {
                                    handleStepAction(instruction.step)
                                }
                            )
                        }
                    }
                    
                    // 警告
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(l10n.securityTip)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(l10n.securityTipContent)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle(l10n.httpsCertificate)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(l10n.done) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func handleStepAction(_ step: Int) {
        switch step {
        case 1:
            // 下载证书
            if let certURL = captureManager.exportCACertificate() {
                // 使用 Safari 打开证书（触发安装）
                UIApplication.shared.open(certURL)
            }
        case 2:
            // 打开设置
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        default:
            break
        }
    }
}

// MARK: - 证书步骤视图
struct CertificateStepView: View {
    let step: Int
    let title: String
    let description: String
    let actionTitle: String?
    let isCompleted: Bool
    let action: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // 步骤编号
            ZStack {
                Circle()
                    .fill(isCompleted ? Color.green : Color.blue)
                    .frame(width: 32, height: 32)
                
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                } else {
                    Text("\(step)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let actionTitle = actionTitle, !isCompleted {
                    Button(action: action) {
                        Text(actionTitle)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - 设置指南视图（权限问题时显示）
struct SetupGuideView: View {
    @Environment(\.dismiss) private var dismiss
    
    private var l10n: L10n { L10n.shared }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 标题
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        
                        Text(l10n.needNetworkExtension)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(l10n.networkExtensionDesc)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    // 解决方案
                    VStack(alignment: .leading, spacing: 16) {
                        Text(l10n.solution)
                            .font(.headline)
                        
                        GuideStepView(
                            number: 1,
                            title: l10n.setupGuideStep1Title,
                            description: l10n.setupGuideStep1Desc
                        )
                        
                        GuideStepView(
                            number: 2,
                            title: l10n.setupGuideStep2Title,
                            description: l10n.setupGuideStep2Desc
                        )
                        
                        GuideStepView(
                            number: 3,
                            title: l10n.setupGuideStep3Title,
                            description: l10n.setupGuideStep3Desc
                        )
                        
                        GuideStepView(
                            number: 4,
                            title: l10n.setupGuideStep4Title,
                            description: l10n.setupGuideStep4Desc
                        )
                    }
                    
                    // 替代方案
                    VStack(alignment: .leading, spacing: 12) {
                        Text(l10n.alternativeSolution)
                            .font(.headline)
                        
                        Text(l10n.alternativeDesc)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            AlternativeToolView(name: "Stream", description: l10n.alternativeStream)
                            AlternativeToolView(name: "Charles Proxy", description: l10n.alternativeCharles)
                            AlternativeToolView(name: "Proxyman", description: l10n.alternativeProxyman)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle(l10n.configGuide)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(l10n.close) {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct GuideStepView: View {
    let number: Int
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color.blue)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct AlternativeToolView: View {
    let name: String
    let description: String
    
    var body: some View {
        HStack {
            Text("•")
                .foregroundColor(.blue)
            Text(name)
                .fontWeight(.medium)
            Text("- \(description)")
                .foregroundColor(.secondary)
        }
        .font(.caption)
    }
}

// MARK: - 数据包行视图
struct PacketRowView: View {
    let packet: CapturedPacket
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: packet.direction.icon)
                .foregroundColor(packet.direction == .outgoing ? .orange : .green)
                .font(.title3)
            
            Text(packet.protocol.rawValue)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(protocolColor)
                .cornerRadius(4)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(packet.summary)
                    .font(.subheadline)
                    .lineLimit(1)
                
                HStack {
                    Text(packet.formattedTime)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text("\(packet.size) \(L10n.shared.bytes)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if let statusCode = packet.httpStatusCode {
                Text("\(statusCode)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(statusCodeColor(statusCode))
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    private var protocolColor: Color {
        switch packet.protocol {
        case .tcp: return .orange
        case .udp: return .green
        case .icmp: return .purple
        case .http: return .blue
        case .https: return .cyan
        case .dns: return .indigo
        case .unknown: return .gray
        }
    }
    
    private func statusCodeColor(_ code: Int) -> Color {
        switch code {
        case 200..<300: return .green
        case 300..<400: return .orange
        case 400..<500: return .red
        case 500..<600: return .purple
        default: return .secondary
        }
    }
}

// MARK: - 数据包详情视图
struct PacketDetailView: View {
    let packet: CapturedPacket
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    
    private var l10n: L10n { L10n.shared }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                basicInfoSection
                
                Picker("", selection: $selectedTab) {
                    Text(l10n.overview).tag(0)
                    Text("Headers").tag(1)
                    Text("Hex").tag(2)
                    Text("Raw").tag(3)
                }
                .pickerStyle(.segmented)
                .padding()
                
                ScrollView {
                    switch selectedTab {
                    case 0: overviewTab
                    case 1: headersTab
                    case 2: hexTab
                    case 3: rawTab
                    default: EmptyView()
                    }
                }
            }
            .navigationTitle(l10n.packetDetail)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(l10n.done) { dismiss() }
                }
            }
        }
    }
    
    private var basicInfoSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: packet.direction.icon)
                    .foregroundColor(packet.direction == .outgoing ? .orange : .green)
                
                Text(packet.protocol.rawValue)
                    .font(.headline)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(6)
                
                Spacer()
                
                Text(packet.formattedTime)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                VStack(alignment: .leading) {
                    Text(l10n.sourceAddress).font(.caption).foregroundColor(.secondary)
                    Text("\(packet.sourceIP):\(packet.sourcePort)")
                        .font(.subheadline).fontWeight(.medium)
                }
                Spacer()
                Image(systemName: "arrow.right").foregroundColor(.secondary)
                Spacer()
                VStack(alignment: .trailing) {
                    Text(l10n.destAddress).font(.caption).foregroundColor(.secondary)
                    Text("\(packet.destinationIP):\(packet.destinationPort)")
                        .font(.subheadline).fontWeight(.medium)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    private var overviewTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            DetailRow(title: l10n.time, value: packet.formattedTime)
            DetailRow(title: l10n.direction, value: packet.direction == .outgoing ? l10n.sendDirection : l10n.receiveDirection)
            DetailRow(title: l10n.protocolLabel, value: packet.protocol.rawValue)
            DetailRow(title: l10n.size, value: "\(packet.size) \(l10n.bytes)")
            if let method = packet.httpMethod { DetailRow(title: l10n.httpMethod, value: method) }
            if let url = packet.httpURL { DetailRow(title: l10n.url, value: url) }
            if let statusCode = packet.httpStatusCode { DetailRow(title: l10n.statusCode, value: "\(statusCode)") }
            Spacer()
        }
        .padding()
    }
    
    private var headersTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let headers = packet.httpHeaders, !headers.isEmpty {
                ForEach(Array(headers.keys.sorted()), id: \.self) { key in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(key).font(.caption).fontWeight(.semibold).foregroundColor(.blue)
                        Text(headers[key] ?? "").font(.caption).foregroundColor(.primary)
                    }
                    .padding(.vertical, 4)
                    Divider()
                }
            } else {
                Text(l10n.noHttpHeaders).foregroundColor(.secondary).padding()
            }
            Spacer()
        }
        .padding()
    }
    
    private var hexTab: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            Text(packet.hexDump)
                .font(.system(.caption, design: .monospaced))
                .padding()
        }
    }
    
    private var rawTab: some View {
        ScrollView {
            Text(packet.asciiDump)
                .font(.system(.caption, design: .monospaced))
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - 详情行
struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundColor(.secondary)
            Text(value).font(.subheadline)
        }
    }
}

// MARK: - 过滤器 Sheet
struct FilterSheetView: View {
    @ObservedObject var captureManager: PacketCaptureManager
    @Environment(\.dismiss) private var dismiss
    
    private var l10n: L10n { L10n.shared }
    
    var body: some View {
        NavigationStack {
            List {
                Section(l10n.protocolFilter) {
                    Button {
                        captureManager.filterProtocol = nil
                    } label: {
                        HStack {
                            Text(l10n.all)
                            Spacer()
                            if captureManager.filterProtocol == nil {
                                Image(systemName: "checkmark").foregroundColor(.blue)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                    
                    ForEach([CapturedPacket.NetworkProtocol.http, .https, .tcp, .udp, .dns], id: \.rawValue) { proto in
                        Button {
                            captureManager.filterProtocol = proto
                        } label: {
                            HStack {
                                Text(proto.rawValue)
                                Spacer()
                                if captureManager.filterProtocol == proto {
                                    Image(systemName: "checkmark").foregroundColor(.blue)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
            }
            .navigationTitle(l10n.filterTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(l10n.done) { dismiss() }
                }
            }
        }
    }
}

// MARK: - 导出 Sheet
struct ExportSheetView: View {
    let content: String
    @Environment(\.dismiss) private var dismiss
    
    private var l10n: L10n { L10n.shared }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                Text(content)
                    .font(.system(.caption, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle(l10n.exportData)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(l10n.cancel) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        UIPasteboard.general.string = content
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                }
            }
        }
    }
}

// MARK: - Extensions
extension CapturedPacket: Equatable {
    static func == (lhs: CapturedPacket, rhs: CapturedPacket) -> Bool { lhs.id == rhs.id }
}

extension CapturedPacket: Hashable {
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

#Preview {
    NavigationStack {
        PacketCaptureView()
    }
}
