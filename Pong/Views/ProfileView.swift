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
    @State private var showLoginSheet = false
    @State private var showLogoutAlert = false
    @State private var showLoginSuccessToast = false
    
    private var l10n: L10n { L10n.shared }
    
    var body: some View {
        NavigationStack {
            List {
                // 用户信息区域
                Section {
                    if userManager.isLoggedIn, let user = userManager.currentUser {
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
                                
                                // 用户类型标签
                                userTypeLabel(for: user)
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    } else {
                        Button {
                            showLoginSheet = true
                        } label: {
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 60, height: 60)
                                    
                                    Image(systemName: "person.fill")
                                        .font(.title)
                                        .foregroundColor(.gray)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(l10n.clickToLogin)
                                        .font(.headline)
                                    
                                    Text(l10n.loginToUseCloud)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 8)
                        }
                        .foregroundColor(.primary)
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
                
                // 登出按钮
                if userManager.isLoggedIn {
                    Section {
                        Button(role: .destructive) {
                            showLogoutAlert = true
                        } label: {
                            HStack {
                                Spacer()
                                Text(l10n.logout)
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .sheet(isPresented: $showLoginSheet) {
                LoginView {
                    showLoginSuccessToast = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showLoginSuccessToast = false
                    }
                }
            }
            .overlay {
                if showLoginSuccessToast {
                    VStack {
                        Spacer()
                        Text(l10n.loginSuccess)
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.black.opacity(0.75))
                            .cornerRadius(8)
                            .padding(.bottom, 100)
                    }
                    .transition(.opacity)
                    .animation(.easeInOut, value: showLoginSuccessToast)
                }
            }
            .alert(l10n.confirmLogout, isPresented: $showLogoutAlert) {
                Button(l10n.cancel, role: .cancel) { }
                Button(l10n.exit, role: .destructive) {
                    userManager.logout()
                }
            } message: {
                Text(l10n.confirmLogoutMessage)
            }
        }
    }
    
    // MARK: - 用户类型标签
    @ViewBuilder
    private func userTypeLabel(for user: UserInfo) -> some View {
        if user.isGuest {
            // 游客 - 橙色
            Text(l10n.guestAccount)
                .font(.caption2)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.orange)
                .cornerRadius(4)
        } else if let accountType = AccountUserType.from(user.userType) {
            // 社区版/定制版
            Text(accountType.title(l10n))
                .font(.caption2)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(accountType.color)
                .cornerRadius(4)
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
                NavigationLink(l10n.whatIsCloudProbe) {
                    HelpDetailView(
                        title: l10n.whatIsCloudProbe,
                        content: cloudProbeHelpContent
                    )
                }
                
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
    
    private var cloudProbeHelpContent: String {
        if languageManager.currentLanguage == .chinese {
            return """
            云探测是一项网络质量监测服务，通过分布在全球各地的云主机节点，对目标地址进行网络探测。
            
            支持的探测类型：
            • Ping - 测试网络连通性和延迟
            • DNS - 查询域名解析结果
            • TCP - 测试TCP端口连通性
            • UDP - 测试UDP端口连通性
            
            使用云探测，您可以了解从不同地区、不同运营商访问您的服务的网络质量。
            """
        } else {
            return """
            Cloud Probe is a network quality monitoring service that performs network probing on target addresses through cloud host nodes distributed around the world.
            
            Supported probe types:
            • Ping - Test network connectivity and latency
            • DNS - Query domain resolution results
            • TCP - Test TCP port connectivity
            • UDP - Test UDP port connectivity
            
            With Cloud Probe, you can understand the network quality of accessing your services from different regions and ISPs.
            """
        }
    }
    
    private var diagnosisHelpContent: String {
        if languageManager.currentLanguage == .chinese {
            return """
            一键诊断功能可以帮助您快速诊断网络问题：
            
            1. 获取诊断码
               从技术支持人员处获取诊断码
            
            2. 输入诊断码
               在一键诊断页面输入诊断码
            
            3. 开始诊断
               点击开始按钮，系统会自动执行预设的诊断任务
            
            4. 查看结果
               诊断完成后可查看详细的诊断报告
            """
        } else {
            return """
            Quick Diagnosis helps you quickly diagnose network issues:
            
            1. Get diagnosis code
               Obtain the diagnosis code from technical support
            
            2. Enter diagnosis code
               Enter the diagnosis code on the Quick Diagnosis page
            
            3. Start diagnosis
               Click start button, the system will automatically execute preset diagnosis tasks
            
            4. View results
               View detailed diagnosis report after completion
            """
        }
    }
    
    private var localToolsHelpContent: String {
        if languageManager.currentLanguage == .chinese {
            return """
            本地测提供了多种网络诊断工具：
            
            • Ping - 测试目标主机的连通性和延迟
            • 路由追踪 - 显示数据包到达目标的路径
            • DNS查询 - 查询域名的DNS解析记录
            • TCP连接 - 测试TCP端口是否开放
            • UDP探测 - 测试UDP端口连通性
            • 测速 - 测试网络上下行速度
            • 抓包 - 捕获网络数据包进行分析
            """
        } else {
            return """
            Local Test provides various network diagnostic tools:
            
            • Ping - Test connectivity and latency to target host
            • Traceroute - Show the path packets take to reach target
            • DNS Query - Query DNS resolution records for domains
            • TCP Connection - Test if TCP ports are open
            • UDP Probe - Test UDP port connectivity
            • Speed Test - Test network upload/download speed
            • Packet Capture - Capture network packets for analysis
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
    @State private var feedbackText = ""
    @State private var contactInfo = ""
    @State private var isSubmitting = false
    @State private var showSuccessToast = false
    @State private var showErrorToast = false
    @State private var errorMessage = ""
    @Environment(\.dismiss) private var dismiss
    
    private var l10n: L10n { L10n.shared }
    private let apiURL = APIConfig.apiURL
    private let auth = APIConfig.defaultAuth
    
    var body: some View {
        Form {
            Section(l10n.feedbackContent) {
                TextEditor(text: $feedbackText)
                    .frame(minHeight: 150)
            }
            
            Section(l10n.contactInfo) {
                TextField(l10n.emailOrPhone, text: $contactInfo)
                    .keyboardType(.emailAddress)
            }
            
            Section {
                Button {
                    submitFeedback()
                } label: {
                    HStack {
                        Spacer()
                        if isSubmitting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text(l10n.submitFeedback)
                        }
                        Spacer()
                    }
                }
                .disabled(feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
            }
        }
        .navigationTitle(l10n.feedback)
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .top) {
            if showSuccessToast {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(l10n.submitSuccess)
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.75))
                .cornerRadius(8)
                .transition(.opacity)
                .animation(.easeInOut, value: showSuccessToast)
            }
            
            if showErrorToast {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.75))
                .cornerRadius(8)
                .transition(.opacity)
                .animation(.easeInOut, value: showErrorToast)
            }
        }
    }
    
    private func submitFeedback() {
        isSubmitting = true
        
        Task {
            do {
                let requestBody: [String: Any] = [
                    "Action": "App",
                    "Method": "Feedback",
                    "SystemId": APIConfig.systemId,
                    "AppendInfo": [
                        "UserId": UserManager.shared.currentUserId
                    ],
                    "Data": [
                        "Content": feedbackText,
                        "Contact": contactInfo,
                        "ContentType": "反馈"
                    ]
                ]
                
                let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
                
                let _ = try await NetworkService.shared.post(
                    url: apiURL,
                    body: jsonData,
                    headers: ["Content-Type": "application/json"],
                    auth: auth
                )
                
                await MainActor.run {
                    isSubmitting = false
                    showSuccessToast = true
                    
                    // 2秒后隐藏 toast 并返回
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showSuccessToast = false
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = l10n.submitFailed
                    showErrorToast = true
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showErrorToast = false
                    }
                }
            }
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(LanguageManager.shared)
}
