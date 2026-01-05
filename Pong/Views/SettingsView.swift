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

private let privacyPolicySummary = """
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

private let privacyPolicyFull = """
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

private let collectedInfoList = """
已收集个人信息清单

更新日期：2026年1月5日

根据相关法律法规要求，我们向您说明本应用收集的个人信息：

【重要说明】以下所有信息均仅存储于您的设备本地，不会上传至任何服务器。

一、设备信息（本地读取展示）

1. 基础设备信息
   • 信息类型：设备名称、设备型号、系统版本
   • 收集目的：在"设备信息"页面展示
   • 收集方式：通过系统API读取
   • 使用的API：UIDevice.current

2. 设备标识符
   • 信息类型：机型标识符（如iPhone17,1）
   • 收集目的：识别设备型号用于展示
   • 收集方式：通过utsname系统调用
   • 说明：非广告标识符(IDFA)，非设备唯一标识符(IDFV)

3. 设备状态信息
   • 信息类型：电池电量、电池状态、磁盘空间、内存使用
   • 收集目的：在"设备信息"页面展示
   • 收集方式：通过系统API读取

二、网络信息（本地读取用于诊断）

1. IP地址
   • 信息类型：本地IPv4地址、本地IPv6地址
   • 收集目的：网络诊断、设备信息展示
   • 收集方式：通过getifaddrs系统调用

2. 网络状态
   • 信息类型：网络类型（WiFi/蜂窝网络/无网络）
   • 收集目的：判断网络环境、网络诊断
   • 收集方式：通过NWPathMonitor监听

3. 蜂窝网络类型
   • 信息类型：2G/3G/4G/5G
   • 收集目的：展示详细网络类型
   • 收集方式：通过CoreTelephony框架

三、历史记录（本地存储）

1. 探测目标历史
   • 信息类型：Ping/DNS/TCP/UDP/Trace/HTTP目标地址
   • 收集目的：方便用户快速选择常用目标
   • 存储方式：UserDefaults本地存储
   • 存储数量：每类最多10条

2. IP查询历史
   • 信息类型：查询过的IP地址
   • 收集目的：方便用户查看历史查询
   • 存储方式：UserDefaults本地存储

3. 连接测试/快速诊断历史
   • 信息类型：测试目标地址
   • 收集目的：方便用户重复测试
   • 存储方式：UserDefaults本地存储

四、用户标识（本地生成）

1. 游客ID
   • 信息类型：随机生成的字符串
   • 收集目的：本地用户标识
   • 存储方式：UserDefaults本地存储
   • 说明：完全随机生成，不关联任何个人身份信息

五、网络请求（功能必需）

1. 网易IP查询服务
   • 服务地址：mail.163.com
   • 提供方：网易公司
   • 发送信息：网络请求（自动携带公网IP）
   • 接收信息：公网IP地址、国家、省份、城市、运营商
   • 目的：获取当前设备的公网IP及归属地信息

2. Bilibili IP查询服务
   • 服务地址：api.live.bilibili.com
   • 提供方：哔哩哔哩
   • 发送信息：待查询的IP地址
   • 接收信息：国家、省份、城市、运营商、经纬度
   • 目的：查询指定IP的地理位置信息

3. ipinfo.io ASN查询服务
   • 服务地址：api.ipinfo.io
   • 提供方：IPinfo Inc.（美国）
   • 发送信息：待查询的IP地址
   • 接收信息：AS号、AS名称、国家
   • 目的：查询IP的自治系统号（AS号）

六、信息清除方式

• 历史记录：可在各功能页面手动清除
• 所有数据：卸载应用即可删除全部本地数据
"""

private let thirdPartySDKList = """
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

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(LanguageManager.shared)
    }
}
