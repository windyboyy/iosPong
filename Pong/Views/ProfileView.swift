//
//  ProfileView.swift
//  Pong
//
//  Created by 张金琛 on 2025/12/15.
//

import SwiftUI

struct ProfileView: View {
    @StateObject private var userManager = UserManager.shared
    @EnvironmentObject var languageManager: LanguageManager
    
    private var l10n: L10n { L10n.shared }
    
    var body: some View {
        NavigationStack {
            List {
                // 用户信息区域
                Section {
                    if let user = userManager.currentUser {
                        HStack(spacing: 16) {
                            // 头像
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.2))
                                    .frame(width: 60, height: 60)
                                
                                Image(systemName: "person.fill")
                                    .font(.title)
                                    .foregroundColor(.blue)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.displayName)
                                    .font(.headline)
                                
                                Text("ID: \(String(user.userId))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                // 功能区域
                Section {
                    NavigationLink {
                        TaskHistoryView()
                    } label: {
                        Label(l10n.taskHistory, systemImage: "clock.arrow.circlepath")
                    }
                    
                    NavigationLink {
                        HelpView()
                    } label: {
                        Label(l10n.helpCenter, systemImage: "questionmark.circle")
                    }
                    
                    NavigationLink {
                        FeedbackView()
                    } label: {
                        Label(l10n.feedback, systemImage: "envelope")
                    }
                    
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label(l10n.settings, systemImage: "gearshape")
                    }
                    
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label(l10n.about, systemImage: "info.circle")
                    }
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
        }
    }
}

// MARK: - 帮助中心
struct HelpView: View {
    @EnvironmentObject var languageManager: LanguageManager
    private var l10n: L10n { L10n.shared }
    
    var body: some View {
        List {
            Section(l10n.faq) {
                NavigationLink(l10n.howToUseDiagnosis) {
                    HelpDetailView(
                        title: l10n.howToUseDiagnosis,
                        content: diagnosisHelpContent
                    )
                }
                
                NavigationLink(l10n.localToolsDesc) {
                    HelpDetailView(
                        title: l10n.localToolsDesc,
                        content: localToolsHelpContent
                    )
                }
            }
            
            Section(l10n.contactUs) {
                HStack {
                    Text(l10n.techSupport)
                    Spacer()
                    Text("zjccc5889@gmail.com")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle(l10n.helpCenter)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var diagnosisHelpContent: String {
        if languageManager.currentLanguage == .chinese {
            return """
            一键诊断是一个强大的网络问题排查工具，帮助您快速定位网络故障：
            
            【功能介绍】
            输入目标地址（域名或 IP），系统会自动执行一系列网络诊断任务，包括 Ping 测试、TCP 连接、DNS 查询和路由追踪等。
            
            【使用步骤】
            1. 输入目标地址
               在输入框中输入您要诊断的域名（如 baidu.com）或 IP 地址（如 8.8.8.8）
            
            2. 开始诊断
               点击"开始诊断"按钮，系统会自动执行多项网络测试
            
            3. 查看结果
               诊断完成后，您可以查看每项测试的详细结果，快速了解网络状况
            
            【适用场景】
            • 网页无法访问时，检查是 DNS 问题还是连接问题
            • 游戏或应用卡顿时，检查网络延迟和丢包情况
            • 排查特定服务器的连通性问题
            """
        } else {
            return """
            Quick Diagnosis is a powerful network troubleshooting tool that helps you quickly locate network issues:
            
            【Features】
            Enter a target address (domain or IP), and the system will automatically perform a series of network diagnostic tasks, including Ping test, TCP connection, DNS query, and traceroute.
            
            【How to Use】
            1. Enter target address
               Input the domain (e.g., google.com) or IP address (e.g., 8.8.8.8) you want to diagnose
            
            2. Start diagnosis
               Click "Start Diagnosis" button, the system will automatically run multiple network tests
            
            3. View results
               After completion, you can view detailed results of each test to quickly understand network status
            
            【Use Cases】
            • When a webpage is inaccessible, check if it's a DNS or connection issue
            • When games or apps are lagging, check network latency and packet loss
            • Troubleshoot connectivity issues to specific servers
            """
        }
    }
    
    private var localToolsHelpContent: String {
        if languageManager.currentLanguage == .chinese {
            return """
            本地测提供了专业的网络诊断工具集，帮助您全面了解网络状况：
            
            【Ping 测试】
            测试目标主机的连通性，获取往返延迟（RTT）、丢包率等关键指标。支持自定义包大小和发送间隔。
            
            【路由追踪 (Traceroute)】
            显示数据包从您的设备到目标服务器经过的所有路由节点，帮助定位网络瓶颈或故障点。
            
            【DNS 查询】
            查询域名的 DNS 解析记录，支持 A、AAAA、CNAME、MX、TXT 等多种记录类型，帮助排查域名解析问题。
            
            【TCP 连接测试】
            测试指定端口的 TCP 连接，检查服务是否可达。支持扫描常用端口，快速了解服务器开放情况。
            
            【UDP 测试】
            发送 UDP 数据包测试，适用于检测 UDP 服务（如 DNS、游戏服务器）的连通性。
            
            【网速测试】
            测试网络的上传和下载速度，以及网络延迟和抖动，全面评估网络质量。
            
            【HTTP 请求】
            发送 HTTP GET 请求，查看响应状态码、响应时间和响应内容，适合测试 Web 服务可用性。
            
            【设备信息】
            查看本机网络配置、公网 IP 归属地、设备信息等，快速了解当前网络环境。
            """
        } else {
            return """
            Local Test provides a professional network diagnostic toolkit to help you fully understand your network status:
            
            【Ping Test】
            Test connectivity to target host, get key metrics like round-trip time (RTT) and packet loss rate. Supports custom packet size and interval.
            
            【Traceroute】
            Shows all routing nodes that packets traverse from your device to the target server, helping locate network bottlenecks or failure points.
            
            【DNS Query】
            Query DNS resolution records for domains, supporting A, AAAA, CNAME, MX, TXT and other record types to troubleshoot DNS issues.
            
            【TCP Connection Test】
            Test TCP connections to specified ports, check if services are reachable. Supports scanning common ports to quickly understand server availability.
            
            【UDP Test】
            Send UDP packets for testing, suitable for checking connectivity of UDP services (like DNS, game servers).
            
            【Speed Test】
            Test network upload and download speeds, as well as latency and jitter, for comprehensive network quality assessment.
            
            【HTTP Request】
            Send HTTP GET requests, view response status code, response time and content, suitable for testing web service availability.
            
            【Device Info】
            View local network configuration, public IP location, device information, etc., to quickly understand your current network environment.
            """
        }
    }
}

struct HelpDetailView: View {
    let title: String
    let content: String
    
    var body: some View {
        ScrollView {
            Text(content)
                .padding()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 意见反馈
struct FeedbackView: View {
    @EnvironmentObject var languageManager: LanguageManager
    @State private var showMailError = false
    @State private var showCopySuccess = false
    @Environment(\.dismiss) private var dismiss
    
    private var l10n: L10n { L10n.shared }
    private let feedbackEmail = "zjccc5889@gmail.com"
    
    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                    
                    Text(l10n.feedbackEmailTitle)
                        .font(.headline)
                    
                    Text(l10n.feedbackEmailDesc)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Text(feedbackEmail)
                        .font(.body)
                        .foregroundColor(.blue)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
            
            Section {
                Button {
                    sendEmail()
                } label: {
                    HStack {
                        Spacer()
                        Label(l10n.sendEmail, systemImage: "paperplane.fill")
                        Spacer()
                    }
                }
                .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                
                Button {
                    UIPasteboard.general.string = feedbackEmail
                    withAnimation {
                        showCopySuccess = true
                    }
                    // 1.5秒后自动隐藏提示
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation {
                            showCopySuccess = false
                        }
                    }
                } label: {
                    HStack {
                        Spacer()
                        Label(l10n.copyEmail, systemImage: "doc.on.doc")
                        Spacer()
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(l10n.feedback)
        .navigationBarTitleDisplayMode(.inline)
        .alert(l10n.mailNotAvailable, isPresented: $showMailError) {
            Button(l10n.ok) { }
        } message: {
            Text(l10n.mailNotAvailableDesc)
        }
        .overlay(alignment: .top) {
            if showCopySuccess {
                CopySuccessToastView(message: l10n.copySuccess)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 60)
            }
        }
    }
    
    private func sendEmail() {
        let subject = l10n.feedbackEmailSubject
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        if let url = URL(string: "mailto:\(feedbackEmail)?subject=\(encodedSubject)") {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            } else {
                showMailError = true
            }
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(LanguageManager.shared)
}
