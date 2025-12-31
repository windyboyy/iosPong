//
//  SettingsView.swift
//  Pong
//
//  Created by 张金琛 on 2025/12/15.
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var appSettings = AppSettings.shared
    @EnvironmentObject var languageManager: LanguageManager
    @Environment(\.dismiss) private var dismiss
    
    private var l10n: L10n { L10n.shared }
    
    var body: some View {
        List {
            // 显示设置
            Section(l10n.displaySettings) {
                HStack {
                    Text(l10n.toolsPerRow)
                    Spacer()
                    Picker("", selection: $appSettings.toolsPerRow) {
                        Text("2").tag(2)
                        Text("3").tag(3)
                        Text("4").tag(4)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 120)
                }
                
                HStack {
                    Text(l10n.homeStyleSettings)
                    Spacer()
                    Picker("", selection: $appSettings.homeStyle) {
                        Text(l10n.homeStyleModern).tag(HomeStyle.modern)
                        Text(l10n.homeStyleClassic).tag(HomeStyle.classic)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 120)
                }
            }
            
            // 语言设置
            Section(l10n.languageSettings) {
                ForEach(AppLanguage.allCases, id: \.self) { language in
                    Button {
                        languageManager.setLanguage(language)
                    } label: {
                        HStack {
                            Text(language.displayName)
                                .foregroundColor(.primary)
                            Spacer()
                            if languageManager.currentLanguage == language {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            
            // 隐私与协议
            Section(l10n.privacyAndAgreement) {
                NavigationLink {
                    LegalDocumentView(
                        title: l10n.userServiceAgreement,
                        content: userServiceAgreement
                    )
                } label: {
                    Text(l10n.userServiceAgreement)
                }
                
                NavigationLink {
                    LegalDocumentView(
                        title: l10n.privacyPolicySummary,
                        content: privacyPolicySummary
                    )
                } label: {
                    Text(l10n.privacyPolicySummary)
                }
                
                NavigationLink {
                    LegalDocumentView(
                        title: l10n.privacyPolicyFull,
                        content: privacyPolicyFull
                    )
                } label: {
                    Text(l10n.privacyPolicyFull)
                }
                
                NavigationLink {
                    LegalDocumentView(
                        title: l10n.collectedInfoList,
                        content: collectedInfoList
                    )
                } label: {
                    Text(l10n.collectedInfoList)
                }
                
                NavigationLink {
                    LegalDocumentView(
                        title: l10n.thirdPartySDK,
                        content: thirdPartySDKList
                    )
                } label: {
                    Text(l10n.thirdPartySDK)
                }
            }
            
            // 关于
            Section(l10n.about) {
                HStack {
                    Text(l10n.version)
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text(l10n.build)
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle(l10n.settings)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 法律文档视图
struct LegalDocumentView: View {
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

// MARK: - 法律文档内容
private let userServiceAgreement = """
用户服务协议

更新日期：2025年12月15日
生效日期：2025年12月15日

欢迎使用 iTango 网络探测服务！

一、服务说明

iTango 网络探测（以下简称"本服务"）是由腾讯公司提供的网络质量监测工具，包括但不限于：
• 本地网络诊断工具（Ping、路由追踪、DNS查询等）
• 一键诊断服务

二、用户注册与账号

1. 您可以通过游客登录方式使用本服务，系统将自动为您分配唯一的用户标识。
2. 您应妥善保管您的账号信息，对于因您的账号被他人使用而造成的损失，本服务不承担责任。

三、用户行为规范

您在使用本服务时，应遵守以下规范：
1. 遵守中华人民共和国相关法律法规
2. 不得利用本服务进行任何违法活动
3. 不得对他人网络进行恶意探测或攻击
4. 不得干扰本服务的正常运行

四、服务变更与终止

1. 我们有权根据业务发展需要，变更、中断或终止部分或全部服务。
2. 如您违反本协议，我们有权终止向您提供服务。

五、免责声明

1. 本服务提供的网络探测结果仅供参考，不构成任何形式的保证。
2. 因不可抗力导致的服务中断，我们不承担责任。

六、其他

1. 本协议的解释、效力及争议解决均适用中华人民共和国法律。
2. 如有任何争议，双方应友好协商解决。

如您对本协议有任何疑问，请联系：zjccc5889@gmail.com
"""

private let privacyPolicySummary = """
隐私政策摘要

更新日期：2025年12月15日

本摘要旨在帮助您快速了解我们如何收集和使用您的个人信息。

我们收集的信息：
• 设备信息：设备型号、操作系统版本、网络状态
• 网络信息：IP地址、网络类型、运营商信息
• 使用数据：功能使用记录、探测任务记录

我们如何使用信息：
• 提供网络探测服务
• 改进服务质量
• 保障服务安全

您的权利：
• 查询、更正您的个人信息
• 删除您的账号和数据
• 撤回同意

如需了解详细信息，请查阅《隐私政策完整版》。
"""

private let privacyPolicyFull = """
隐私政策

更新日期：2025年12月15日
生效日期：2025年12月15日

引言

腾讯公司（以下简称"我们"）深知个人信息对您的重要性，我们将按照法律法规的规定，保护您的个人信息安全。

一、我们收集的信息

1. 设备信息
   • 设备型号、操作系统版本
   • 设备唯一标识符
   • 屏幕分辨率

2. 网络信息
   • IP地址
   • 网络类型（WiFi/蜂窝网络）
   • 运营商信息
   • 网络状态

3. 使用数据
   • 功能使用记录
   • 探测任务记录
   • 探测结果数据

4. 账号信息
   • 用户ID
   • 昵称（如有）

二、我们如何使用信息

1. 提供服务
   • 执行网络探测任务
   • 展示探测结果
   • 提供一键诊断服务

2. 改进服务
   • 分析服务使用情况
   • 优化用户体验
   • 修复问题和漏洞

3. 安全保障
   • 身份验证
   • 防范安全风险
   • 防止欺诈行为

三、信息存储

1. 存储地点：中华人民共和国境内
2. 存储期限：账号有效期内及法律规定的期限

四、信息共享

我们不会与第三方共享您的个人信息，除非：
• 获得您的明确同意
• 法律法规要求
• 保护我们或公众的权益

五、您的权利

1. 查询权：您可以查询您的个人信息
2. 更正权：您可以更正不准确的信息
3. 删除权：您可以注销账号并删除数据
4. 撤回同意：您可以撤回对信息收集的同意

六、未成年人保护

本服务主要面向成年人。如果您是未成年人，请在监护人指导下使用。

七、政策更新

我们可能会更新本隐私政策，更新后的政策将在本页面发布。

八、联系我们

如有任何问题，请联系：zjccc5889@gmail.com
"""

private let collectedInfoList = """
已收集个人信息清单

更新日期：2025年12月15日

根据相关法律法规要求，我们向您说明本应用收集的个人信息：

一、基础功能所需信息

1. 网络探测功能
   • 信息类型：IP地址、网络状态
   • 收集目的：执行网络探测任务
   • 收集方式：自动收集

2. 设备信息展示
   • 信息类型：设备型号、系统版本、网络类型
   • 收集目的：展示设备网络环境信息
   • 收集方式：自动收集

3. 用户账号
   • 信息类型：用户ID
   • 收集目的：识别用户身份，提供个性化服务
   • 收集方式：用户登录时自动生成

二、可选功能所需信息

1. 一键诊断功能
   • 信息类型：诊断码、诊断结果
   • 收集目的：执行诊断任务并上报结果
   • 收集方式：用户主动发起

三、信息使用说明

所有收集的信息仅用于提供服务和改进用户体验，不会用于其他目的。
"""

private let thirdPartySDKList = """
第三方SDK目录

更新日期：2025年12月15日

本应用集成了以下第三方SDK：

一、系统SDK

1. Foundation
   • 提供方：Apple Inc.
   • 功能：基础框架支持
   • 收集信息：无

2. SwiftUI
   • 提供方：Apple Inc.
   • 功能：用户界面框架
   • 收集信息：无

3. Network
   • 提供方：Apple Inc.
   • 功能：网络通信支持
   • 收集信息：网络状态

4. CommonCrypto
   • 提供方：Apple Inc.
   • 功能：加密算法支持
   • 收集信息：无

二、第三方SDK

本应用目前未集成第三方商业SDK。

三、说明

如后续集成新的第三方SDK，我们将及时更新本目录并通知您。
"""

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(LanguageManager.shared)
    }
}
