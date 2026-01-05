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

更新日期：2026年1月5日
生效日期：2026年1月5日

欢迎使用网络魔法箱服务！

一、服务说明

网络魔法箱（以下简称"本服务"）是一款网络质量监测工具，包括但不限于：
• 本地网络诊断工具（Ping、路由追踪、DNS查询、TCP/UDP端口检测等）
• HTTP请求测试
• 网络连通性测试
• 快速诊断服务
• 网速测试
• 延迟测试
• IP归属地查询
• 设备信息查看

二、用户注册与账号

1. 您可以通过游客登录方式使用本服务，系统将自动为您分配唯一的用户标识（存储于本地）。
2. 您应妥善保管您的设备，对于因您的设备被他人使用而造成的损失，本服务不承担责任。

三、用户行为规范

您在使用本服务时，应遵守以下规范：
1. 遵守中华人民共和国相关法律法规
2. 不得利用本服务进行任何违法活动
3. 不得对他人网络进行恶意探测或攻击
4. 不得干扰本服务的正常运行
5. 不得利用本服务进行网络扫描、端口扫描等可能侵犯他人权益的行为

四、服务变更与终止

1. 我们有权根据业务发展需要，变更、中断或终止部分或全部服务。
2. 如您违反本协议，我们有权终止向您提供服务。

五、免责声明

1. 本服务提供的网络探测结果仅供参考，不构成任何形式的保证。
2. 因不可抗力导致的服务中断，我们不承担责任。
3. 网速测试结果受多种因素影响，仅供参考。
4. IP归属地信息来自第三方服务，可能存在误差。

六、数据说明

1. 本应用的所有数据均存储在您的本地设备上。
2. 历史记录可在应用内清除。
3. 卸载应用将删除所有本地数据。

七、其他

1. 本协议的解释、效力及争议解决均适用中华人民共和国法律。
2. 如有任何争议，双方应友好协商解决。

如您对本协议有任何疑问，请联系：zjccc5889@gmail.com
"""

    static let privacyPolicySummary = """
隐私政策摘要

更新日期：2026年1月5日

本摘要旨在帮助您快速了解我们如何收集和使用您的个人信息。

【重要提示】本应用为纯本地应用，所有数据均存储在您的设备本地，不会主动上传至我们的服务器。

我们收集的信息（仅存储于本地）：
• 设备信息：设备型号、操作系统版本、设备标识符（用于本地展示）
• 网络信息：本地IP地址、网络类型（WiFi/蜂窝网络）
• 使用数据：探测目标历史记录、IP查询历史记录
• 用户标识：本地生成的游客ID

我们如何使用信息：
• 提供网络探测服务
• 展示设备网络环境信息
• 保存历史记录方便下次使用

网络请求说明：
• IP归属地查询功能会向第三方服务发送您的公网IP地址，用于获取IP地理位置信息
• 除此之外，我们不会向任何服务器发送您的个人信息

您的权利：
• 随时清除历史记录
• 卸载应用删除所有数据

如需了解详细信息，请查阅《隐私政策完整版》。
"""

    static let privacyPolicyFull = """
隐私政策

更新日期：2026年1月5日
生效日期：2026年1月5日

引言

我们深知个人信息对您的重要性，我们将按照法律法规的规定，保护您的个人信息安全。

【重要声明】本应用为纯本地应用，不会将您的任何数据上传至服务器。所有信息均存储在您的设备本地。

一、我们收集的信息

1. 设备信息（本地读取，用于展示）
   • 设备名称、设备型号
   • 操作系统版本
   • 设备标识符（机型标识，非IDFA/IDFV）
   • 电池电量、电池状态
   • 磁盘空间、内存使用情况

2. 网络信息（本地读取，用于网络诊断）
   • 本地IP地址（IPv4/IPv6）
   • 网络类型（WiFi/2G/3G/4G/5G）
   • 网络连接状态

3. 使用数据（本地存储）
   • Ping目标历史记录
   • DNS查询历史记录
   • TCP/UDP端口检测历史记录
   • 路由追踪历史记录
   • HTTP请求历史记录
   • 连接测试历史记录
   • 快速诊断历史记录
   • IP查询历史记录

4. 用户标识（本地生成）
   • 游客ID（随机生成，仅用于本地标识）

二、我们如何使用信息

1. 提供服务
   • 执行网络探测任务（Ping、DNS、TCP、UDP、Traceroute等）
   • 展示探测结果
   • 提供快速诊断服务
   • 进行网速测试和延迟测试

2. 提升体验
   • 保存历史记录，方便快速选择
   • 展示设备网络环境信息

三、信息存储

1. 存储位置：您的设备本地（UserDefaults）
2. 存储期限：直到您清除历史记录或卸载应用
3. 我们不会将任何数据上传至服务器

四、第三方服务

本应用使用以下第三方网络服务查询IP归属地信息：

1. 网易IP查询服务（mail.163.com）
   • 提供方：网易公司
   • 功能：获取当前设备的公网IP地址及归属地
   • 发送数据：网络请求（自动携带公网IP）
   • 返回数据：公网IP地址、国家、省份、城市、运营商

2. Bilibili IP查询服务（api.live.bilibili.com）
   • 提供方：哔哩哔哩
   • 功能：查询指定IP的地理位置信息
   • 发送数据：待查询的IP地址
   • 返回数据：国家、省份、城市、运营商、经纬度

3. ipinfo.io ASN查询服务（api.ipinfo.io）
   • 提供方：IPinfo Inc.（美国）
   • 功能：查询IP的AS号（自治系统号）
   • 发送数据：待查询的IP地址
   • 返回数据：AS号、AS名称、国家

五、信息共享

除IP归属地查询外，我们不会与任何第三方共享您的个人信息。

六、您的权利

1. 清除权：您可以在应用内清除所有历史记录
2. 删除权：卸载应用将删除所有本地数据
3. 知情权：您可以随时查看本隐私政策

七、未成年人保护

本服务主要面向成年人。如果您是未成年人，请在监护人指导下使用。

八、政策更新

我们可能会更新本隐私政策，更新后的政策将在应用内发布。

九、联系我们

如有任何问题，请联系：zjccc5889@gmail.com
"""

    static let thirdPartySDKList = """
第三方SDK目录

更新日期：2026年1月5日

本应用集成了以下SDK：

一、Apple系统SDK

1. Foundation
   • 提供方：Apple Inc.
   • 功能：基础框架支持，提供基本数据类型和集合
   • 收集信息：无

2. SwiftUI
   • 提供方：Apple Inc.
   • 功能：用户界面框架，构建应用界面
   • 收集信息：无

3. UIKit
   • 提供方：Apple Inc.
   • 功能：UI组件支持，获取设备信息
   • 收集信息：设备名称、系统版本、电池状态

4. Network
   • 提供方：Apple Inc.
   • 功能：网络通信支持，TCP/UDP连接、网络状态监控
   • 收集信息：网络连接状态

5. CoreTelephony
   • 提供方：Apple Inc.
   • 功能：获取蜂窝网络信息
   • 收集信息：蜂窝网络类型（2G/3G/4G/5G）

6. NetworkExtension
   • 提供方：Apple Inc.
   • 功能：网络扩展支持（抓包功能预留）
   • 收集信息：无

7. Security
   • 提供方：Apple Inc.
   • 功能：安全框架支持
   • 收集信息：无

8. Darwin
   • 提供方：Apple Inc.
   • 功能：底层系统调用，用于Ping、Traceroute等功能
   • 收集信息：无

9. dnssd
   • 提供方：Apple Inc.
   • 功能：DNS服务发现，用于DNS查询功能
   • 收集信息：无

二、第三方商业SDK

本应用目前未集成任何第三方商业SDK，包括但不限于：
• 无广告SDK
• 无统计分析SDK
• 无社交分享SDK
• 无推送SDK
• 无支付SDK

三、第三方网络服务

1. 网易IP查询服务
   • 服务地址：mail.163.com
   • 提供方：网易公司
   • 功能：获取当前设备的公网IP地址及归属地
   • 发送数据：网络请求（自动携带公网IP）
   • 返回数据：公网IP地址、国家、省份、城市、运营商

2. Bilibili IP查询服务
   • 服务地址：api.live.bilibili.com
   • 提供方：哔哩哔哩
   • 功能：查询指定IP的地理位置信息
   • 发送数据：待查询的IP地址
   • 返回数据：国家、省份、城市、运营商、经纬度

3. ipinfo.io ASN查询服务
   • 服务地址：api.ipinfo.io
   • 提供方：IPinfo Inc.（美国）
   • 功能：查询IP的AS号（自治系统号）
   • 发送数据：待查询的IP地址
   • 返回数据：AS号、AS名称、国家

四、说明

1. 本应用仅使用Apple官方系统SDK，确保安全可靠。
2. 如后续集成新的第三方SDK，我们将及时更新本目录并通知您。
3. 所有SDK的使用均遵循最小必要原则。
"""

    // MARK: - English Versions
    
    static let userServiceAgreementEN = """
Terms of Service

Last Updated: January 5, 2026
Effective Date: January 5, 2026

Welcome to NetMagic!

1. Service Description

NetMagic (hereinafter referred to as "the Service") is a network quality monitoring tool, including but not limited to:
• Local network diagnostic tools (Ping, Traceroute, DNS Query, TCP/UDP Port Detection, etc.)
• HTTP Request Testing
• Network Connectivity Testing
• Quick Diagnosis Service
• Speed Test
• Latency Test
• IP Geolocation Query
• Device Information View

2. User Registration and Account

1. You can use the Service through guest login, and the system will automatically assign you a unique user identifier (stored locally).
2. You should keep your device secure. The Service is not responsible for any losses caused by unauthorized use of your device.

3. User Conduct Guidelines

When using the Service, you should comply with the following guidelines:
1. Comply with applicable laws and regulations
2. Do not use the Service for any illegal activities
3. Do not maliciously probe or attack others' networks
4. Do not interfere with the normal operation of the Service
5. Do not use the Service for network scanning, port scanning, or other activities that may infringe on others' rights

4. Service Changes and Termination

1. We reserve the right to change, suspend, or terminate part or all of the Service based on business needs.
2. If you violate this agreement, we have the right to terminate providing the Service to you.

5. Disclaimer

1. The network probe results provided by the Service are for reference only and do not constitute any form of guarantee.
2. We are not responsible for service interruptions caused by force majeure.
3. Speed test results are affected by various factors and are for reference only.
4. IP geolocation information comes from third-party services and may contain errors.

6. Data Description

1. All data in this application is stored on your local device.
2. History records can be cleared within the app.
3. Uninstalling the app will delete all local data.

7. Miscellaneous

1. The interpretation, validity, and dispute resolution of this agreement shall be governed by the laws of the People's Republic of China.
2. Any disputes shall be resolved through friendly negotiation.

If you have any questions about this agreement, please contact: zjccc5889@gmail.com
"""

    static let privacyPolicySummaryEN = """
Privacy Policy Summary

Last Updated: January 5, 2026

This summary is intended to help you quickly understand how we collect and use your personal information.

[IMPORTANT] This is a purely local application. All data is stored on your device locally and will not be actively uploaded to our servers.

Information We Collect (stored locally only):
• Device Information: Device model, operating system version, device identifier (for local display)
• Network Information: Local IP address, network type (WiFi/Cellular)
• Usage Data: Probe target history, IP query history
• User Identifier: Locally generated guest ID

How We Use Information:
• Provide network probe services
• Display device network environment information
• Save history for convenient future use

Network Request Notice:
• The IP geolocation feature sends your public IP address to third-party services to obtain geographic location information
• Other than this, we do not send your personal information to any server

Your Rights:
• Clear history at any time
• Delete all data by uninstalling the app

For detailed information, please refer to the Full Privacy Policy.
"""

    static let privacyPolicyFullEN = """
Privacy Policy

Last Updated: January 5, 2026
Effective Date: January 5, 2026

Introduction

We understand the importance of personal information to you. We will protect your personal information security in accordance with laws and regulations.

[IMPORTANT STATEMENT] This is a purely local application and will not upload any of your data to servers. All information is stored locally on your device.

1. Information We Collect

1. Device Information (read locally for display)
   • Device name, device model
   • Operating system version
   • Device identifier (model identifier, not IDFA/IDFV)
   • Battery level, battery status
   • Disk space, memory usage

2. Network Information (read locally for network diagnosis)
   • Local IP address (IPv4/IPv6)
   • Network type (WiFi/2G/3G/4G/5G)
   • Network connection status

3. Usage Data (stored locally)
   • Ping target history
   • DNS query history
   • TCP/UDP port detection history
   • Traceroute history
   • HTTP request history
   • Connection test history
   • Quick diagnosis history
   • IP query history

4. User Identifier (generated locally)
   • Guest ID (randomly generated, used only for local identification)

2. How We Use Information

1. Provide Services
   • Execute network probe tasks (Ping, DNS, TCP, UDP, Traceroute, etc.)
   • Display probe results
   • Provide quick diagnosis service
   • Perform speed tests and latency tests

2. Improve Experience
   • Save history for quick selection
   • Display device network environment information

3. Information Storage

1. Storage Location: Your device locally (UserDefaults)
2. Storage Period: Until you clear history or uninstall the app
3. We will not upload any data to servers

4. Third-Party Services

This application uses the following third-party network services for IP geolocation:

1. NetEase IP Query Service (mail.163.com)
   • Provider: NetEase, Inc.
   • Function: Obtain current device's public IP address and geolocation
   • Data Sent: Network request (automatically carries public IP)
   • Data Returned: Public IP address, country, province, city, ISP

2. Bilibili IP Query Service (api.live.bilibili.com)
   • Provider: Bilibili Inc.
   • Function: Query geographic location of specified IP
   • Data Sent: IP address to query
   • Data Returned: Country, province, city, ISP, coordinates

3. ipinfo.io ASN Query Service (api.ipinfo.io)
   • Provider: IPinfo Inc. (USA)
   • Function: Query AS number (Autonomous System Number) of IP
   • Data Sent: IP address to query
   • Data Returned: AS number, AS name, country

5. Information Sharing

Except for IP geolocation queries, we will not share your personal information with any third party.

6. Your Rights

1. Right to Clear: You can clear all history within the app
2. Right to Delete: Uninstalling the app will delete all local data
3. Right to Know: You can view this privacy policy at any time

7. Protection of Minors

This Service is primarily intended for adults. If you are a minor, please use it under the guidance of a guardian.

8. Policy Updates

We may update this Privacy Policy, and the updated policy will be published within the app.

9. Contact Us

If you have any questions, please contact: zjccc5889@gmail.com
"""

    static let thirdPartySDKListEN = """
Third-Party SDK List

Last Updated: January 5, 2026

This application integrates the following SDKs:

1. Apple System SDKs

1. Foundation
   • Provider: Apple Inc.
   • Function: Basic framework support, provides basic data types and collections
   • Information Collected: None

2. SwiftUI
   • Provider: Apple Inc.
   • Function: User interface framework, builds app interface
   • Information Collected: None

3. UIKit
   • Provider: Apple Inc.
   • Function: UI component support, obtains device information
   • Information Collected: Device name, system version, battery status

4. Network
   • Provider: Apple Inc.
   • Function: Network communication support, TCP/UDP connections, network status monitoring
   • Information Collected: Network connection status

5. CoreTelephony
   • Provider: Apple Inc.
   • Function: Obtains cellular network information
   • Information Collected: Cellular network type (2G/3G/4G/5G)

6. NetworkExtension
   • Provider: Apple Inc.
   • Function: Network extension support (reserved for packet capture feature)
   • Information Collected: None

7. Security
   • Provider: Apple Inc.
   • Function: Security framework support
   • Information Collected: None

8. Darwin
   • Provider: Apple Inc.
   • Function: Low-level system calls, used for Ping, Traceroute, etc.
   • Information Collected: None

9. dnssd
   • Provider: Apple Inc.
   • Function: DNS service discovery, used for DNS query feature
   • Information Collected: None

2. Third-Party Commercial SDKs

This application currently does not integrate any third-party commercial SDKs, including but not limited to:
• No advertising SDKs
• No analytics SDKs
• No social sharing SDKs
• No push notification SDKs
• No payment SDKs

3. Third-Party Network Services

1. NetEase IP Query Service
   • Service URL: mail.163.com
   • Provider: NetEase, Inc.
   • Function: Obtain current device's public IP address and geolocation
   • Data Sent: Network request (automatically carries public IP)
   • Data Returned: Public IP address, country, province, city, ISP

2. Bilibili IP Query Service
   • Service URL: api.live.bilibili.com
   • Provider: Bilibili Inc.
   • Function: Query geographic location of specified IP
   • Data Sent: IP address to query
   • Data Returned: Country, province, city, ISP, coordinates

3. ipinfo.io ASN Query Service
   • Service URL: api.ipinfo.io
   • Provider: IPinfo Inc. (USA)
   • Function: Query AS number (Autonomous System Number) of IP
   • Data Sent: IP address to query
   • Data Returned: AS number, AS name, country

4. Notes

1. This application only uses Apple official system SDKs to ensure safety and reliability.
2. If new third-party SDKs are integrated in the future, we will update this list and notify you promptly.
3. All SDK usage follows the principle of minimum necessity.
"""
}
