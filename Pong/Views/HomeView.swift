//
//  HomeView.swift
//  Pong
//
//  Created by 张金琛 on 2025/12/12.
//

import SwiftUI
import SafariServices

// MARK: - URL Identifiable 扩展
extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

// MARK: - 工具类型
enum NetworkTool: CaseIterable, Identifiable {
    case ping
    case dns
    case tcp
    case udp
    case trace
    case httpGet
    case deviceInfo
    case speedTest
    case packetCapture
    
    var id: String { 
        switch self {
        case .speedTest: return "speedTest"
        case .ping: return "ping"
        case .trace: return "trace"
        case .tcp: return "tcp"
        case .udp: return "udp"
        case .dns: return "dns"
        case .httpGet: return "httpGet"
        case .packetCapture: return "packetCapture"
        case .deviceInfo: return "deviceInfo"
        }
    }
    
    func title(_ l10n: L10n) -> String {
        switch self {
        case .speedTest: return l10n.speedTest
        case .ping: return l10n.ping
        case .trace: return l10n.traceroute
        case .tcp: return l10n.tcp
        case .udp: return l10n.udp
        case .dns: return l10n.dns
        case .httpGet: return l10n.httpGet
        case .packetCapture: return l10n.packetCapture
        case .deviceInfo: return l10n.deviceInfo
        }
    }
    
    var icon: String {
        switch self {
        case .speedTest: return "speedometer"
        case .ping: return "network"
        case .trace: return "point.topleft.down.curvedto.point.bottomright.up"
        case .tcp: return "arrow.left.arrow.right"
        case .udp: return "paperplane"
        case .dns: return "server.rack"
        case .httpGet: return "globe"
        case .packetCapture: return "antenna.radiowaves.left.and.right"
        case .deviceInfo: return "iphone.gen3"
        }
    }
    
    var color: Color {
        switch self {
        case .speedTest: return .red
        case .ping: return .blue
        case .trace: return .purple
        case .tcp: return .orange
        case .udp: return .green
        case .dns: return .cyan
        case .httpGet: return .teal
        case .packetCapture: return .pink
        case .deviceInfo: return .indigo
        }
    }
    
    func description(_ l10n: L10n) -> String {
        switch self {
        case .speedTest: return l10n.speedTestDesc
        case .ping: return l10n.pingDesc
        case .trace: return l10n.tracerouteDesc
        case .tcp: return l10n.tcpDesc
        case .udp: return l10n.udpDesc
        case .dns: return l10n.dnsDesc
        case .httpGet: return l10n.httpGetDesc
        case .packetCapture: return l10n.packetCaptureDesc
        case .deviceInfo: return l10n.deviceInfoDesc
        }
    }
    
    var isEnabled: Bool {
        switch self {
        case .packetCapture: return false
        default: return true
        }
    }
}

// MARK: - 首页视图
struct HomeView: View {
    @EnvironmentObject var languageManager: LanguageManager
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var appSettings = AppSettings.shared
    @State private var selectedTool: NetworkTool?
    @State private var safariURL: URL?
    @State private var showQuickDiagnosis = false
    
    private var huatuoURL: URL {
        languageManager.currentLanguage == .chinese
            ? URL(string: "https://itango.tencent.com/app/data/huatuo")!
            : URL(string: "https://itango.tencent.com/app/data/huatuoen")!
    }
    
    private var l10n: L10n { L10n.shared }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 顶部标题栏
                    if appSettings.homeStyle == .modern {
                        // 新版样式：Logo + 语言切换
                        HStack {
                            Image(colorScheme == .dark ? "itango_night_logo" : "itango_logo")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 70)
                            Spacer()
                            
                            // 语言切换按钮
                            Button {
                                languageManager.toggleLanguage()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "globe")
                                        .font(.subheadline)
                                    Text(languageManager.currentLanguage.toggleButtonText)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(colorScheme == .dark ? .cyan : .blue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(colorScheme == .dark ? Color.cyan.opacity(0.15) : Color.blue.opacity(0.1))
                                .cornerRadius(16)
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.bottom, -20)
                    } else {
                        // 旧版样式：用户专区标题 + 语言切换
                        HStack {
                            Text(l10n.userZone)
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 4)
                            Spacer()
                            
                            // 语言切换按钮
                            Button {
                                languageManager.toggleLanguage()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "globe")
                                        .font(.subheadline)
                                    Text(languageManager.currentLanguage.toggleButtonText)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(colorScheme == .dark ? .cyan : .blue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(colorScheme == .dark ? Color.cyan.opacity(0.15) : Color.blue.opacity(0.1))
                                .cornerRadius(16)
                            }
                        }
                        .padding(.bottom, -16)
                    }
                    
                    // 一键诊断入口
                    quickDiagnosisEntry
                    
                    // 工具网格（旧版显示标题）
                    if appSettings.homeStyle == .classic {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(l10n.engineerZone)
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 4)
                            
                            toolsGridContent
                        }
                    } else {
                        toolsGrid
                    }
                    
                    // 快速操作
                    quickActions
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
            .navigationDestination(item: $selectedTool) { tool in
                destinationView(for: tool)
            }
            .navigationDestination(isPresented: $showQuickDiagnosis) {
                QuickDiagnosisView()
                    .onAppear {
                        // 确保每次进入时重置状态
                        QuickDiagnosisManager.shared.reset()
                    }
            }
            .sheet(item: $safariURL) { url in
                SafariView(url: url)
            }
        }
    }
    
    // MARK: - 一键诊断入口
    private var quickDiagnosisEntry: some View {
        Button {
            // 点击时先重置状态，确保进入干净的诊断页面
            QuickDiagnosisManager.shared.reset()
            showQuickDiagnosis = true
        } label: {
            VStack(spacing: 12) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
                
                Text(l10n.quickDiagnosis)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(l10n.quickDiagnosisDesc)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .background(
                Image("dig_bg")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            )
            .clipped()
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 工具网格
    private var toolsGrid: some View {
        toolsGridContent
    }
    
    private var toolsGridContent: some View {
        let columns = Array(repeating: GridItem(.flexible()), count: appSettings.toolsPerRow)
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(NetworkTool.allCases) { tool in
                ToolCard(tool: tool, l10n: l10n, columnsCount: appSettings.toolsPerRow) {
                    selectedTool = tool
                }
            }
        }
    }
    
    // MARK: - 快速操作
    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(l10n.quickActions)
                .font(appSettings.homeStyle == .classic ? .title2 : .headline)
                .fontWeight(appSettings.homeStyle == .classic ? .bold : .regular)
                .padding(.horizontal, 4)
            
            QuickActionButton(
                title: l10n.huatuoPlatform,
                subtitle: l10n.huatuoDesc,
                icon: "safari",
                color: .orange
            ) {
                safariURL = huatuoURL
            }
        }
    }
    
    // MARK: - 目标视图
    @ViewBuilder
    private func destinationView(for tool: NetworkTool) -> some View {
        switch tool {
        case .speedTest:
            SpeedTestView()
        case .ping:
            PingView()
        case .trace:
            TraceView()
        case .tcp:
            TCPView()
        case .udp:
            UDPView()
        case .dns:
            DNSView()
        case .httpGet:
            HTTPGetView()
        case .packetCapture:
            PacketCaptureView()
        case .deviceInfo:
            DeviceInfoView()
        }
    }
}

// MARK: - 工具卡片
struct ToolCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let tool: NetworkTool
    let l10n: L10n
    var columnsCount: Int = 2
    let action: () -> Void
    
    private var iconSize: CGFloat {
        switch columnsCount {
        case 4: return 40
        case 3: return 48
        default: return 56
        }
    }
    
    private var showDescription: Bool {
        columnsCount <= 2
    }
    
    // 深色模式下使用更亮的颜色
    private var iconBackgroundOpacity: Double {
        colorScheme == .dark ? 0.25 : 0.15
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color(.secondarySystemBackground) : Color(.systemBackground)
    }
    
    private var shadowOpacity: Double {
        colorScheme == .dark ? 0.3 : 0.05
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: columnsCount >= 4 ? 6 : (columnsCount == 3 ? 8 : 12)) {
                ZStack {
                    Circle()
                        .fill(tool.color.opacity(tool.isEnabled ? iconBackgroundOpacity : 0.08))
                        .frame(width: iconSize, height: iconSize)
                    
                    Image(systemName: tool.icon)
                        .font(columnsCount >= 4 ? .body : (columnsCount == 3 ? .title3 : .title2))
                        .foregroundColor(tool.isEnabled ? tool.color : .gray)
                }
                
                VStack(spacing: 4) {
                    Text(tool.title(l10n))
                        .font(columnsCount >= 4 ? .caption : (columnsCount == 3 ? .subheadline : .headline))
                        .fontWeight(columnsCount >= 3 ? .medium : .regular)
                        .foregroundColor(tool.isEnabled ? .primary : .secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    
                    if showDescription {
                        Text(tool.description(l10n))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, columnsCount >= 4 ? 12 : (columnsCount == 3 ? 16 : 20))
            .padding(.horizontal, columnsCount >= 4 ? 6 : (columnsCount == 3 ? 8 : 12))
            .background(cardBackground)
            .cornerRadius(columnsCount >= 4 ? 12 : 16)
            .shadow(color: .black.opacity(shadowOpacity), radius: columnsCount >= 4 ? 4 : 8, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: columnsCount >= 4 ? 12 : 16)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.1) : Color.clear, lineWidth: 1)
            )
            .opacity(tool.isEnabled ? 1.0 : 0.6)
        }
        .buttonStyle(.plain)
        .disabled(!tool.isEnabled)
    }
}

// MARK: - 快速操作按钮
struct QuickActionButton: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color(.secondarySystemBackground) : Color(.systemBackground)
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color.opacity(colorScheme == .dark ? 0.25 : 0.15))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(color)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.1) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HomeView()
        .environmentObject(LanguageManager.shared)
}

// MARK: - Safari 视图包装器
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
