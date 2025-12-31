//
//  AgreementContent.swift
//  Pong
//
//  Created by 张金琛 on 2025/12/22.
//

import Foundation

// MARK: - 协议类型
enum AgreementType: Identifiable {
    case userService
    case privacySummary
    case privacyFull
    case thirdPartySDK
    
    var id: Int {
        switch self {
        case .userService: return 0
        case .privacySummary: return 1
        case .privacyFull: return 2
        case .thirdPartySDK: return 3
        }
    }
    
    func title(_ l10n: L10n) -> String {
        switch self {
        case .userService: return l10n.userServiceAgreement
        case .privacySummary: return l10n.privacyPolicySummary
        case .privacyFull: return l10n.privacyPolicyFull
        case .thirdPartySDK: return l10n.thirdPartySDK
        }
    }
    
    func content(for language: AppLanguage) -> String {
        switch self {
        case .userService:
            return language == .chinese ? AgreementContent.userServiceAgreement : AgreementContent.userServiceAgreementEN
        case .privacySummary:
            return language == .chinese ? AgreementContent.privacyPolicySummary : AgreementContent.privacyPolicySummaryEN
        case .privacyFull:
            return language == .chinese ? AgreementContent.privacyPolicyFull : AgreementContent.privacyPolicyFullEN
        case .thirdPartySDK:
            return language == .chinese ? AgreementContent.thirdPartySDKList : AgreementContent.thirdPartySDKListEN
        }
    }
}

// MARK: - 协议内容
struct AgreementContent {
    static let userServiceAgreement = """
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

    static let privacyPolicySummary = """
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

    static let privacyPolicyFull = """
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

    static let thirdPartySDKList = """
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

    // MARK: - English Versions
    
    static let userServiceAgreementEN = """
Terms of Service

Last Updated: December 15, 2025
Effective Date: December 15, 2025

Welcome to iTango Network Probe!

1. Service Description

iTango Network Probe (hereinafter referred to as "the Service") is a network quality monitoring tool provided by Tencent, including but not limited to:
• Local network diagnostic tools (Ping, Traceroute, DNS Query, etc.)
• One-click diagnosis service

2. User Registration and Account

1. You can use the Service through guest login, and the system will automatically assign you a unique user identifier.
2. You should keep your account information secure. The Service is not responsible for any losses caused by unauthorized use of your account.

3. User Conduct Guidelines

When using the Service, you should comply with the following guidelines:
1. Comply with applicable laws and regulations
2. Do not use the Service for any illegal activities
3. Do not maliciously probe or attack others' networks
4. Do not interfere with the normal operation of the Service

4. Service Changes and Termination

1. We reserve the right to change, suspend, or terminate part or all of the Service based on business needs.
2. If you violate this agreement, we have the right to terminate providing the Service to you.

5. Disclaimer

1. The network probe results provided by the Service are for reference only and do not constitute any form of guarantee.
2. We are not responsible for service interruptions caused by force majeure.

6. Miscellaneous

1. The interpretation, validity, and dispute resolution of this agreement shall be governed by the laws of the People's Republic of China.
2. Any disputes shall be resolved through friendly negotiation.

If you have any questions about this agreement, please contact: zjccc5889@gmail.com
"""

    static let privacyPolicySummaryEN = """
Privacy Policy Summary

Last Updated: December 15, 2025

This summary is intended to help you quickly understand how we collect and use your personal information.

Information We Collect:
• Device Information: Device model, operating system version, network status
• Network Information: IP address, network type, carrier information
• Usage Data: Feature usage records, probe task records

How We Use Information:
• Provide network probe services
• Improve service quality
• Ensure service security

Your Rights:
• Query and correct your personal information
• Delete your account and data
• Withdraw consent

For detailed information, please refer to the Full Privacy Policy.
"""

    static let privacyPolicyFullEN = """
Privacy Policy

Last Updated: December 15, 2025
Effective Date: December 15, 2025

Introduction

Tencent (hereinafter referred to as "we") understands the importance of personal information to you. We will protect your personal information security in accordance with laws and regulations.

1. Information We Collect

1. Device Information
   • Device model, operating system version
   • Device unique identifier
   • Screen resolution

2. Network Information
   • IP address
   • Network type (WiFi/Cellular)
   • Carrier information
   • Network status

3. Usage Data
   • Feature usage records
   • Probe task records
   • Probe result data

4. Account Information
   • User ID
   • Nickname (if any)

2. How We Use Information

1. Provide Services
   • Execute network probe tasks
   • Display probe results
   • Provide one-click diagnosis service

2. Improve Services
   • Analyze service usage
   • Optimize user experience
   • Fix issues and vulnerabilities

3. Security Protection
   • Identity verification
   • Prevent security risks
   • Prevent fraudulent behavior

3. Information Storage

1. Storage Location: Within the People's Republic of China
2. Storage Period: During the validity of the account and as required by law

4. Information Sharing

We will not share your personal information with third parties unless:
• We obtain your explicit consent
• Required by laws and regulations
• To protect our or the public's rights and interests

5. Your Rights

1. Right to Query: You can query your personal information
2. Right to Correct: You can correct inaccurate information
3. Right to Delete: You can cancel your account and delete data
4. Right to Withdraw Consent: You can withdraw consent for information collection

6. Protection of Minors

This Service is primarily intended for adults. If you are a minor, please use it under the guidance of a guardian.

7. Policy Updates

We may update this Privacy Policy, and the updated policy will be published on this page.

8. Contact Us

If you have any questions, please contact: zjccc5889@gmail.com
"""

    static let thirdPartySDKListEN = """
Third-Party SDK List

Last Updated: December 15, 2025

This application integrates the following third-party SDKs:

1. System SDKs

1. Foundation
   • Provider: Apple Inc.
   • Function: Basic framework support
   • Information Collected: None

2. SwiftUI
   • Provider: Apple Inc.
   • Function: User interface framework
   • Information Collected: None

3. Network
   • Provider: Apple Inc.
   • Function: Network communication support
   • Information Collected: Network status

4. CommonCrypto
   • Provider: Apple Inc.
   • Function: Encryption algorithm support
   • Information Collected: None

2. Third-Party SDKs

This application currently does not integrate any third-party commercial SDKs.

3. Notes

If new third-party SDKs are integrated in the future, we will update this list and notify you promptly.
"""
}
