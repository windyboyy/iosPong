//
//  LanguageManager.swift
//  Pong
//
//  Created by 张金琛 on 2025/12/15.
//

import SwiftUI
internal import Combine

// MARK: - 语言类型
enum AppLanguage: String, CaseIterable {
    case chinese = "zh"
    case english = "en"
    
    var displayName: String {
        switch self {
        case .chinese: return "中文"
        case .english: return "English"
        }
    }
    
    var shortName: String {
        switch self {
        case .chinese: return "中"
        case .english: return "EN"
        }
    }
    
    /// 切换按钮显示的文字（显示目标语言）
    var toggleButtonText: String {
        switch self {
        case .chinese: return "EN"  // 中文时显示 EN，表示点击切换到英文
        case .english: return "中"   // 英文时显示 中，表示点击切换到中文
        }
    }
}

// MARK: - 首页样式
enum HomeStyle: String, CaseIterable {
    case modern = "modern"
    case classic = "classic"
}

// MARK: - 应用设置管理器
class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
    private let toolsPerRowKey = "ToolsPerRow"
    private let homeStyleKey = "HomeStyle"
    
    @Published var toolsPerRow: Int {
        didSet {
            UserDefaults.standard.set(toolsPerRow, forKey: toolsPerRowKey)
        }
    }
    
    @Published var homeStyle: HomeStyle {
        didSet {
            UserDefaults.standard.set(homeStyle.rawValue, forKey: homeStyleKey)
        }
    }
    
    private init() {
        let saved = UserDefaults.standard.integer(forKey: toolsPerRowKey)
        toolsPerRow = saved >= 2 && saved <= 4 ? saved : 3
        
        if let savedStyle = UserDefaults.standard.string(forKey: homeStyleKey),
           let style = HomeStyle(rawValue: savedStyle) {
            homeStyle = style
        } else {
            homeStyle = .modern
        }
    }
}

// MARK: - 语言管理器
class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    
    private let languageKey = "AppLanguage"
    
    @Published var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: languageKey)
        }
    }
    
    var isChinese: Bool {
        currentLanguage == .chinese
    }
    
    private init() {
        if let savedLanguage = UserDefaults.standard.string(forKey: languageKey),
           let language = AppLanguage(rawValue: savedLanguage) {
            currentLanguage = language
        } else {
            // 默认根据系统语言设置
            let preferredLanguage = Locale.preferredLanguages.first ?? "en"
            currentLanguage = preferredLanguage.hasPrefix("zh") ? .chinese : .english
        }
    }
    
    func setLanguage(_ language: AppLanguage) {
        currentLanguage = language
        // 通知 SpeedTestManager 刷新应用列表
        Task { @MainActor in
            SpeedTestManager.shared.refreshAppListForLanguageChange()
        }
    }
    
    func toggleLanguage() {
        currentLanguage = currentLanguage == .chinese ? .english : .chinese
        // 通知 SpeedTestManager 刷新应用列表
        Task { @MainActor in
            SpeedTestManager.shared.refreshAppListForLanguageChange()
        }
    }
    
    // MARK: - 网络状态检查
    
    /// 检查当前是否有网络连接
    /// 注意：unknown 状态时允许尝试测试，因为网络监控可能还未完成初始化
    var isNetworkAvailable: Bool {
        let status = DeviceInfoManager.shared.networkStatus
        return status != .disconnected
    }
    
    /// 无网络连接的错误提示
    var noNetworkError: String {
        isChinese ? "无网络连接，请检查网络设置后重试" : "No network connection. Please check your network settings."
    }
    
    // MARK: - 延迟格式化
    
    /// 格式化延迟显示，超过1000ms显示为秒
    static func formatLatency(_ ms: Double) -> String {
        if ms >= 1000 {
            return String(format: "%.2fs", ms / 1000)
        } else {
            return String(format: "%.0fms", ms)
        }
    }
}

// MARK: - 本地化字符串
struct L10n {
    static var shared: L10n { L10n() }
    
    private var lang: AppLanguage {
        LanguageManager.shared.currentLanguage
    }
    
    // MARK: - Tab 栏
    var tabLocalProbe: String { lang == .chinese ? "本地测" : "Local" }
    var tabIPQuery: String { lang == .chinese ? "IP" : "IP" }
    var tabProfile: String { lang == .chinese ? "我的" : "Profile" }
    
    // MARK: - 首页
    var quickDiagnosis: String { lang == .chinese ? "一键诊断" : "Quick Diagnosis" }
    var quickDiagnosisDesc: String { lang == .chinese ? "输入诊断码，快速定位网络问题" : "Enter diagnosis code to locate network issues" }
    var quickActions: String { lang == .chinese ? "快速诊断" : "Quick Actions" }
    var huatuoPlatform: String { lang == .chinese ? "华佗诊断平台" : "Huatuo Platform" }
    var huatuoDesc: String { lang == .chinese ? "查看网络诊断数据" : "View network diagnosis data" }
    var cableStatus: String { lang == .chinese ? "海缆态势感知" : "Cable Status" }
    var cableDesc: String { lang == .chinese ? "全球海底光缆状态" : "Global submarine cable status" }
    
    // MARK: - 网络工具
    var speedTest: String { lang == .chinese ? "测速" : "Speed Test" }
    var speedTestDesc: String { lang == .chinese ? "测试网络上传下载速度" : "Test upload/download speed" }
    var ping: String { "Ping" }
    var pingDesc: String { lang == .chinese ? "测试网络延迟和连通性" : "Test latency and connectivity" }
    var traceroute: String { "Traceroute" }
    var tracerouteDesc: String { lang == .chinese ? "追踪数据包路由路径" : "Trace packet routing path" }
    var tcp: String { "TCP" }
    var tcpDesc: String { lang == .chinese ? "TCP 端口扫描与连接测试" : "TCP port scan and connection test" }
    var udp: String { "UDP" }
    var udpDesc: String { lang == .chinese ? "UDP 数据包发送测试" : "UDP packet sending test" }
    var dns: String { "DNS" }
    var dnsDesc: String { lang == .chinese ? "DNS 域名解析查询" : "DNS domain resolution query" }
    var packetCapture: String { lang == .chinese ? "抓包" : "Capture" }
    var packetCaptureDesc: String { lang == .chinese ? "功能正在开发中" : "Feature in development" }
    var httpGet: String { "HTTP" }
    var httpGetDesc: String { lang == .chinese ? "HTTP GET 请求测试" : "HTTP GET request test" }
    var statusCode: String { lang == .chinese ? "状态码" : "Status Code" }
    var responseTime: String { lang == .chinese ? "响应时间" : "Response Time" }
    var error: String { lang == .chinese ? "错误" : "Error" }
    var deviceInfo: String { lang == .chinese ? "本机信息" : "Device Info" }
    var deviceInfoDesc: String { lang == .chinese ? "查看设备与 IP 归属地" : "View device and IP location" }
    var connectionTest: String { lang == .chinese ? "连接测试" : "Connection" }
    var connectionTestDesc: String { lang == .chinese ? "测试 IPv4/IPv6 优先级" : "Test IPv4/IPv6 priority" }
    
    // MARK: - 通用
    var loading: String { lang == .chinese ? "加载中..." : "Loading..." }
    var retry: String { lang == .chinese ? "重试" : "Retry" }
    var noData: String { lang == .chinese ? "暂无数据" : "No data" }
    var invalidHostFormat: String { lang == .chinese ? "请输入有效的域名或 IP 地址" : "Please enter a valid domain or IP address" }
    var success: String { lang == .chinese ? "成功" : "Success" }
    var failure: String { lang == .chinese ? "失败" : "Failed" }
    var unknown: String { lang == .chinese ? "未知" : "Unknown" }
    var other: String { lang == .chinese ? "其他" : "Other" }
    var unknownISP: String { lang == .chinese ? "未知运营商" : "Unknown ISP" }
    var source: String { lang == .chinese ? "源:" : "Source:" }
    var destination: String { lang == .chinese ? "目的:" : "Dest:" }
    var average: String { lang == .chinese ? "平均" : "Avg" }
    var minimum: String { lang == .chinese ? "最小" : "Min" }
    var maximum: String { lang == .chinese ? "最大" : "Max" }
    var packetLoss: String { lang == .chinese ? "丢包" : "Loss" }
    var sourceIP: String { lang == .chinese ? "源IP:" : "Source IP:" }
    var queryTime: String { lang == .chinese ? "查询耗时" : "Query Time" }
    var resolveResult: String { lang == .chinese ? "解析结果" : "Resolution Result" }
    var clear: String { lang == .chinese ? "清空" : "Clear" }
    var records: String { lang == .chinese ? "条记录" : "records" }
    var recordType: String { lang == .chinese ? "记录类型" : "Record Type" }
    var port: String { lang == .chinese ? "端口" : "Port" }
    var country: String { lang == .chinese ? "国家" : "Country" }
    var province: String { lang == .chinese ? "省份" : "Province" }
    var city: String { lang == .chinese ? "城市" : "City" }
    var isp: String { lang == .chinese ? "运营商" : "ISP" }
    var all: String { lang == .chinese ? "全部" : "All" }
    
    // MARK: - 连接测试
    var startTest: String { lang == .chinese ? "开始测试" : "Start Test" }
    var testResults: String { lang == .chinese ? "测试结果" : "Test Results" }
    var enterDomainToTest: String { lang == .chinese ? "输入域名开始测试" : "Enter domain to start test" }
    var resolvingDNS: String { lang == .chinese ? "正在解析 DNS..." : "Resolving DNS..." }
    var testingIPv4: String { lang == .chinese ? "正在测试 IPv4 连接..." : "Testing IPv4 connection..." }
    var testingIPv6: String { lang == .chinese ? "正在测试 IPv6 连接..." : "Testing IPv6 connection..." }
    var testCompleted: String { lang == .chinese ? "测试完成" : "Test completed" }
    var useIPv4: String { lang == .chinese ? "使用 IPv4 访问" : "Using IPv4" }
    var useIPv6: String { lang == .chinese ? "使用 IPv6 访问" : "Using IPv6" }
    var conclusion: String { lang == .chinese ? "结论" : "Conclusion" }
    var resolution: String { lang == .chinese ? "解析" : "Resolution" }
    var noRecord: String { lang == .chinese ? "无记录" : "No record" }
    var connectionTimeout: String { lang == .chinese ? "连接超时" : "Connection timeout" }
    var connectionCancelled: String { lang == .chinese ? "连接已取消" : "Connection cancelled" }
    
    // MARK: - IP 查询
    var ipQuery: String { lang == .chinese ? "IP查询" : "IP Query" }
    var ipQueryInput: String { lang == .chinese ? "输入IP地址" : "Enter IP Address" }
    var ipQueryPlaceholder: String { lang == .chinese ? "请输入IP地址" : "Enter IP address" }
    var query: String { lang == .chinese ? "查询" : "Query" }
    var querying: String { lang == .chinese ? "查询中..." : "Querying..." }
    var queryResult: String { lang == .chinese ? "查询结果" : "Query Result" }
    var invalidIPFormat: String { lang == .chinese ? "请输入有效的IP地址" : "Please enter a valid IP address" }
    var queryFailed: String { lang == .chinese ? "查询失败，请稍后重试" : "Query failed, please try again" }
    
    // MARK: - 我的页面
    var profile: String { lang == .chinese ? "我的" : "Profile" }
    var helpCenter: String { lang == .chinese ? "帮助中心" : "Help Center" }
    var feedback: String { lang == .chinese ? "意见反馈" : "Feedback" }
    var settings: String { lang == .chinese ? "设置" : "Settings" }
    var cancel: String { lang == .chinese ? "取消" : "Cancel" }
    var confirm: String { lang == .chinese ? "确定" : "Confirm" }
    
    // MARK: - 设置页面
    var displaySettings: String { lang == .chinese ? "显示设置" : "Display Settings" }
    var toolsPerRow: String { lang == .chinese ? "每行工具数" : "Tools Per Row" }
    var privacyAndAgreement: String { lang == .chinese ? "隐私与协议" : "Privacy & Agreement" }
    var userServiceAgreement: String { lang == .chinese ? "用户服务协议" : "Terms of Service" }
    var privacyPolicySummary: String { lang == .chinese ? "隐私政策摘要" : "Privacy Policy Summary" }
    var privacyPolicyFull: String { lang == .chinese ? "隐私政策完整版" : "Full Privacy Policy" }
    var collectedInfoList: String { lang == .chinese ? "已收集个人信息清单" : "Collected Information List" }
    var thirdPartySDK: String { lang == .chinese ? "第三方SDK目录" : "Third-party SDK List" }
    var about: String { lang == .chinese ? "关于" : "About" }
    var version: String { lang == .chinese ? "版本" : "Version" }
    var languageLabel: String { lang == .chinese ? "语言" : "Language" }
    var languageSettings: String { lang == .chinese ? "语言设置" : "Language Settings" }
    var homeStyleSettings: String { lang == .chinese ? "首页样式" : "Home Style" }
    var homeStyleModern: String { lang == .chinese ? "新版" : "Modern" }
    var homeStyleClassic: String { lang == .chinese ? "旧版" : "Classic" }
    var userZone: String { lang == .chinese ? "用户专区" : "User Zone" }
    var engineerZone: String { lang == .chinese ? "工程师专区" : "Engineer Zone" }
    
    // MARK: - 一键诊断
    var enterTargetAddress: String { lang == .chinese ? "请输入目标地址" : "Enter target address" }
    var targetAddressPlaceholder: String { lang == .chinese ? "输入域名或 IP 地址" : "Enter domain or IP address" }
    var diagnosisAddressHint: String { lang == .chinese ? "支持域名或 IP 地址，如 baidu.com 或 8.8.8.8" : "Supports domain or IP address, e.g. baidu.com or 8.8.8.8" }
    var startDiagnosis: String { lang == .chinese ? "开始诊断" : "Start Diagnosis" }
    var executingDiagnosis: String { lang == .chinese ? "正在执行诊断..." : "Executing diagnosis..." }
    var task: String { lang == .chinese ? "任务" : "Task" }
    var diagnosisComplete: String { lang == .chinese ? "诊断完成" : "Diagnosis Complete" }
    var tasksSuccess: String { lang == .chinese ? "个任务成功" : "tasks succeeded" }
    var reDiagnose: String { lang == .chinese ? "重新诊断" : "Re-diagnose" }
    var diagnosisFailed: String { lang == .chinese ? "诊断失败" : "Diagnosis Failed" }
    var pending: String { lang == .chinese ? "等待中" : "Pending" }
    var running: String { lang == .chinese ? "执行中" : "Running" }
    
    // 诊断任务类型
    var diagnosisPingTest: String { lang == .chinese ? "Ping 测试" : "Ping Test" }
    var diagnosisTCPConnect: String { lang == .chinese ? "TCP 连接" : "TCP Connect" }
    var diagnosisUDPTest: String { lang == .chinese ? "UDP 测试" : "UDP Test" }
    var diagnosisDNSQuery: String { lang == .chinese ? "DNS 查询" : "DNS Query" }
    var diagnosisTraceroute: String { lang == .chinese ? "路由追踪" : "Traceroute" }
    var diagnosisCount: String { lang == .chinese ? "次数" : "Count" }
    var diagnosisSize: String { lang == .chinese ? "大小" : "Size" }
    
    // MARK: - Ping 页面
    var enterHostOrIP: String { lang == .chinese ? "输入主机名或 IP" : "Enter hostname or IP" }
    var packetSize: String { lang == .chinese ? "包大小:" : "Size:" }
    var interval: String { lang == .chinese ? "间隔:" : "Interval:" }
    var sent: String { lang == .chinese ? "发送" : "Sent" }
    var received: String { lang == .chinese ? "接收" : "Recv" }
    var lost: String { lang == .chinese ? "丢失" : "Lost" }
    var pingInfoTitle: String { lang == .chinese ? "Ping 说明" : "Ping Info" }
    var pingInfoMessage: String { lang == .chinese ? "单次 Ping 探测最多执行 200 次，达到上限后将自动停止。" : "A single Ping probe executes up to 200 times and will stop automatically when the limit is reached." }
    var gotIt: String { lang == .chinese ? "知道了" : "Got it" }
    
    // MARK: - DNS 页面
    var enterDomain: String { lang == .chinese ? "输入域名" : "Enter domain" }
    var dnsQuery: String { lang == .chinese ? "DNS 查询" : "DNS Query" }
    var localDNSServer: String { lang == .chinese ? "本机 DNS 服务器" : "Local DNS Server" }
    var cannotGetDNS: String { lang == .chinese ? "无法获取 DNS 配置" : "Cannot get DNS config" }
    var enterDomainToQuery: String { lang == .chinese ? "输入域名开始查询" : "Enter domain to start query" }
    var simpleMode: String { lang == .chinese ? "简洁模式" : "Simple Mode" }
    var digOutput: String { lang == .chinese ? "dig 输出" : "dig Output" }
    var hideRaw: String { lang == .chinese ? "隐藏 RAW" : "Hide RAW" }
    var showRaw: String { lang == .chinese ? "显示 RAW" : "Show RAW" }
    var copy: String { lang == .chinese ? "复制" : "Copy" }
    var more: String { lang == .chinese ? "更多" : "More" }
    var back: String { lang == .chinese ? "返回" : "Back" }
    
    // MARK: - 测速页面
    var networkSpeedTest: String { lang == .chinese ? "网速测试" : "Speed Test" }
    var latency: String { lang == .chinese ? "延迟" : "Latency" }
    var jitter: String { lang == .chinese ? "抖动" : "Jitter" }
    var download: String { lang == .chinese ? "下载" : "Download" }
    var upload: String { lang == .chinese ? "上传" : "Upload" }
    var stopTest: String { lang == .chinese ? "停止测试" : "Stop Test" }
    var startSpeedTest: String { lang == .chinese ? "开始测速" : "Start Test" }
    var testing: String { lang == .chinese ? "测速中..." : "Testing..." }
    var testingLatency: String { lang == .chinese ? "测试延迟中..." : "Testing Latency..." }
    var usingCloudflare: String { lang == .chinese ? "使用 Cloudflare 测速服务器" : "Using Cloudflare speed test server" }
    var appLatency: String { lang == .chinese ? "常用应用延迟" : "App Latency" }
    var testComplete: String { lang == .chinese ? "测试完成" : "Test Complete" }
    var cellularDataWarning: String { lang == .chinese ? "流量提醒" : "Data Usage Warning" }
    var cellularDataWarningMessage: String { lang == .chinese ? "您正在使用移动数据，测速将消耗较多流量。" : "You are using cellular data. Speed test will consume significant data." }
    var estimatedDataUsage: String { lang == .chinese ? "预估流量消耗" : "Estimated Data Usage" }
    var continueTest: String { lang == .chinese ? "继续测试" : "Continue" }
    var downloadData: String { lang == .chinese ? "下载" : "Download" }
    var uploadData: String { lang == .chinese ? "上传" : "Upload" }
    var totalData: String { lang == .chinese ? "总计" : "Total" }
    var dataUsageNote: String { lang == .chinese ? "实际流量取决于网速，速度越快消耗越多" : "Actual usage depends on speed, faster = more data" }
    var actualDataUsage: String { lang == .chinese ? "本次测速流量消耗" : "Data Used This Test" }
    var basedOnSpeed: String { lang == .chinese ? "基于测速结果估算" : "Estimated based on speed test results" }
    var speedLevel: String { lang == .chinese ? "网速等级" : "Speed Level" }
    var speedLevel4GNormal: String { lang == .chinese ? "4G普通网速" : "4G Normal" }
    var speedLevel4GGood: String { lang == .chinese ? "4G良好网速" : "4G Good" }
    var speedLevel5G: String { lang == .chinese ? "5G网速" : "5G Speed" }
    var speedLevelWiFi100M: String { lang == .chinese ? "WiFi百兆宽带" : "WiFi 100Mbps" }
    var speedLevelWiFi500M: String { lang == .chinese ? "WiFi 500M宽带" : "WiFi 500Mbps" }
    var speedLevelWiFiGigabit: String { lang == .chinese ? "WiFi千兆宽带" : "WiFi Gigabit" }
    var speedLevelExcellent: String { lang == .chinese ? "极速网络" : "Ultra Fast" }
    var speedLevelSlow: String { lang == .chinese ? "网络较慢" : "Slow Network" }
    
    // MARK: - 帮助中心
    var faq: String { lang == .chinese ? "常见问题" : "FAQ" }
    var howToUseDiagnosis: String { lang == .chinese ? "如何使用一键诊断？" : "How to use Quick Diagnosis?" }
    var localToolsDesc: String { lang == .chinese ? "本地测工具说明" : "Local Tools Description" }
    var contactUs: String { lang == .chinese ? "联系我们" : "Contact Us" }
    var techSupport: String { lang == .chinese ? "技术支持" : "Tech Support" }
    
    // MARK: - 意见反馈
    var feedbackContent: String { lang == .chinese ? "反馈内容" : "Feedback Content" }
    var contactInfo: String { lang == .chinese ? "联系方式（选填）" : "Contact (Optional)" }
    var emailOrPhone: String { lang == .chinese ? "邮箱或手机号" : "Email or Phone" }
    var submitFeedback: String { lang == .chinese ? "提交反馈" : "Submit Feedback" }
    var submitSuccess: String { lang == .chinese ? "提交成功" : "Submitted Successfully" }
    var submitFailed: String { lang == .chinese ? "提交失败，请稍后重试" : "Submit failed, please try again" }
    var thanksFeedback: String { lang == .chinese ? "感谢您的反馈，我们会认真处理！" : "Thanks for your feedback!" }
    
    // MARK: - 通用
    
    // MARK: - Ping 结果
    var pingResult: String { lang == .chinese ? "Ping 结果" : "Ping Result" }
    var successRate: String { lang == .chinese ? "成功率" : "Success Rate" }
    var avgLatency: String { lang == .chinese ? "平均延迟" : "Avg Latency" }
    var lossRate: String { lang == .chinese ? "丢包率" : "Loss Rate" }
    
    // MARK: - TCP 结果
    var tcpResult: String { lang == .chinese ? "TCP 结果" : "TCP Result" }
    var portStatus: String { lang == .chinese ? "端口状态" : "Port Status" }
    var open: String { lang == .chinese ? "开放" : "Open" }
    var closed: String { lang == .chinese ? "关闭" : "Closed" }
    var connectionTime: String { lang == .chinese ? "连接耗时" : "Connection Time" }
    
    // MARK: - DNS 结果
    var dnsResult: String { lang == .chinese ? "DNS 结果" : "DNS Result" }
    var moreRecords: String { lang == .chinese ? "还有" : "more" }
    var recordsText: String { lang == .chinese ? "条记录" : "records" }
    
    // MARK: - Traceroute 结果
    var tracerouteResult: String { lang == .chinese ? "Traceroute 结果" : "Traceroute Result" }
    var totalHops: String { lang == .chinese ? "共" : "Total" }
    var hops: String { lang == .chinese ? "跳" : "hops" }
    var reachedTarget: String { lang == .chinese ? "已到达目标" : "Target reached" }
    var notReachedTarget: String { lang == .chinese ? "未到达目标" : "Target not reached" }
    var probeComplete: String { lang == .chinese ? "探测完成" : "Probe complete" }
    var tracingRoute: String { lang == .chinese ? "正在追踪路由..." : "Tracing route..." }
    var fetchingLocation: String { lang == .chinese ? "正在获取归属地..." : "Fetching location..." }
    var traceComplete: String { lang == .chinese ? "追踪完成" : "Trace complete" }
    var delayHeader: String { lang == .chinese ? "延时" : "Delay" }
    var lossHeader: String { lang == .chinese ? "丢包" : "Loss" }
    var locationHeader: String { lang == .chinese ? "归属地" : "Location" }
    var probesPerHop: String { lang == .chinese ? "每跳发包数:" : "Probes per hop:" }
    var ipProtocol: String { lang == .chinese ? "IP 协议:" : "IP Protocol:" }
    var systemDefault: String { lang == .chinese ? "默认" : "SYS" }
    var targetIPLabel: String { lang == .chinese ? "目标 IP:" : "Target IP:" }
    
    // Traceroute 结果文本（上报用）
    var traceRouteToTarget: String { lang == .chinese ? "路由追踪目标:" : "Traceroute to" }
    var traceHop: String { lang == .chinese ? "跳数" : "Hop" }
    var traceIPAddress: String { lang == .chinese ? "IP 地址" : "IP Address" }
    var traceSent: String { lang == .chinese ? "发送" : "Sent" }
    var traceRecv: String { lang == .chinese ? "接收" : "Recv" }
    var traceLoss: String { lang == .chinese ? "丢包%" : "Loss%" }
    var traceAvg: String { lang == .chinese ? "平均延迟" : "Avg" }
    var traceLocation: String { lang == .chinese ? "归属地" : "Location" }
    var traceReachedTarget: String { lang == .chinese ? "状态: 已到达目标" : "Status: Reached target" }
    var traceNotReached: String { lang == .chinese ? "状态: 未到达目标" : "Status: Target not reached" }
    
    // MARK: - UDP 结果
    var udpResult: String { lang == .chinese ? "UDP 结果" : "UDP Result" }
    var sendStatus: String { lang == .chinese ? "发送状态" : "Send Status" }
    var receiveStatus: String { lang == .chinese ? "接收状态" : "Receive Status" }
    var sendFailed: String { lang == .chinese ? "发送失败" : "Send Failed" }
    var noResponse: String { lang == .chinese ? "无响应" : "No Response" }
    
    // MARK: - 设备信息页面
    var publicIPInfo: String { lang == .chinese ? "公网 IP 信息" : "Public IP Info" }
    var publicIP: String { lang == .chinese ? "公网 IP" : "Public IP" }
    var location: String { lang == .chinese ? "归属地" : "Location" }
    var carrier: String { lang == .chinese ? "运营商" : "Carrier" }
    var fetching: String { lang == .chinese ? "正在获取..." : "Fetching..." }
    var deviceInfoSection: String { lang == .chinese ? "设备信息" : "Device Info" }
    var deviceName: String { lang == .chinese ? "设备名称" : "Device Name" }
    var deviceModel: String { lang == .chinese ? "设备型号" : "Device Model" }
    var deviceIdentifier: String { lang == .chinese ? "设备标识" : "Device ID" }
    var systemInfo: String { lang == .chinese ? "系统信息" : "System Info" }
    var systemVersion: String { lang == .chinese ? "系统版本" : "System Version" }
    var networkInfo: String { lang == .chinese ? "网络信息" : "Network Info" }
    var networkStatus: String { lang == .chinese ? "网络状态" : "Network Status" }
    var localIP: String { lang == .chinese ? "本地 IP" : "Local IP" }
    var localIPv4: String { lang == .chinese ? "本地 IPv4" : "Local IPv4" }
    var localIPv6: String { lang == .chinese ? "本地 IPv6" : "Local IPv6" }
    var wifiName: String { lang == .chinese ? "WiFi 名称" : "WiFi Name" }
    var hardwareStatus: String { lang == .chinese ? "硬件状态" : "Hardware Status" }
    var battery: String { lang == .chinese ? "电池" : "Battery" }
    var storage: String { lang == .chinese ? "存储空间" : "Storage" }
    var memoryUsage: String { lang == .chinese ? "内存使用" : "Memory Usage" }
    var refreshed: String { lang == .chinese ? "已刷新" : "Refreshed" }
    var copyText: String { lang == .chinese ? "复制" : "Copy" }
    var notObtained: String { lang == .chinese ? "未获取" : "Not obtained" }
    var noIPv6: String { lang == .chinese ? "当前网络无 IPv6" : "No IPv6 on current network" }
    var noNetworkConnection: String { lang == .chinese ? "无网络连接，请检查网络设置后重试" : "No network connection, please check network settings" }
    var noLocalIPv6ForTrace: String { lang == .chinese ? "当前网络无 IPv6 地址，无法进行 IPv6 路由追踪" : "No IPv6 address on current network, cannot perform IPv6 traceroute" }
    var noLocalIPv6ForPing: String { lang == .chinese ? "当前网络无 IPv6 地址，无法进行 IPv6 Ping" : "No IPv6 address on current network, cannot perform IPv6 Ping" }
    var noLocalIPv6ForTCP: String { lang == .chinese ? "当前网络无 IPv6 地址，无法进行 IPv6 TCP 测试" : "No IPv6 address on current network, cannot perform IPv6 TCP test" }
    var noLocalIPv6ForUDP: String { lang == .chinese ? "当前网络无 IPv6 地址，无法进行 IPv6 UDP 测试" : "No IPv6 address on current network, cannot perform IPv6 UDP test" }
    var ipv6NetworkUnreachable: String { lang == .chinese ? "IPv6 网络不可达，请检查网络是否支持 IPv6" : "IPv6 network unreachable, please check if your network supports IPv6" }
    
    // MARK: - 网络状态
    var networkUnknown: String { lang == .chinese ? "未知" : "Unknown" }
    var networkDisconnected: String { lang == .chinese ? "无网络" : "Disconnected" }
    var networkWifi: String { "WiFi" }
    var networkCellular: String { lang == .chinese ? "蜂窝网络" : "Cellular" }
    var networkEthernet: String { lang == .chinese ? "有线网络" : "Ethernet" }
    var networkOther: String { lang == .chinese ? "其他" : "Other" }
    
    // MARK: - 历史任务
    var taskHistory: String { lang == .chinese ? "历史任务" : "Task History" }
    var noHistoryData: String { lang == .chinese ? "暂无历史记录" : "No history yet" }
    var historyRetentionHint: String { lang == .chinese ? "历史记录保留14天" : "History retained for 14 days" }
    var clearHistory: String { lang == .chinese ? "清空历史" : "Clear History" }
    var clearHistoryMessage: String { lang == .chinese ? "确定要清空所有历史记录吗？此操作不可恢复。" : "Are you sure you want to clear all history? This cannot be undone." }
    var delete: String { lang == .chinese ? "删除" : "Delete" }
    var today: String { lang == .chinese ? "今天" : "Today" }
    var yesterday: String { lang == .chinese ? "昨天" : "Yesterday" }
    var result: String { lang == .chinese ? "结果" : "Result" }
    var reachStatus: String { lang == .chinese ? "到达状态" : "Reach Status" }
    var dnsRecords: String { lang == .chinese ? "解析记录" : "DNS Records" }
    var downloadSpeed: String { lang == .chinese ? "下载速度" : "Download Speed" }
    var uploadSpeed: String { lang == .chinese ? "上传速度" : "Upload Speed" }
    
    // MARK: - 历史上传
    var uploadToServer: String { lang == .chinese ? "上传" : "Upload" }
    var uploadAll: String { lang == .chinese ? "全部上传" : "Upload All" }
    var uploading: String { lang == .chinese ? "上传中..." : "Uploading..." }
    var uploadSuccess: String { lang == .chinese ? "上传成功" : "Upload Success" }
    var uploadFailed: String { lang == .chinese ? "上传失败" : "Upload Failed" }
    var uploadAllConfirm: String { lang == .chinese ? "确认上传" : "Confirm Upload" }
    var uploadAllMessage: String { lang == .chinese ? "确定要上传所有历史记录吗？" : "Are you sure you want to upload all history records?" }
    var noRecordsToUpload: String { lang == .chinese ? "没有可上传的记录" : "No records to upload" }
    var swipeHint: String { lang == .chinese ? "左滑记录可上传或删除" : "Swipe left to upload or delete" }
    var guestCannotUpload: String { lang == .chinese ? "游客无法上传记录" : "Guest cannot upload records" }
    var rawRecords: String { lang == .chinese ? "原始记录" : "Raw Records" }
    var minLatency: String { lang == .chinese ? "最小延迟" : "Min Latency" }
    var maxLatency: String { lang == .chinese ? "最大延迟" : "Max Latency" }
    var stdDevLatency: String { lang == .chinese ? "标准差" : "Std Dev" }
    var resolvedIP: String { lang == .chinese ? "解析 IP" : "Resolved IP" }
    var ipVersionLabel: String { lang == .chinese ? "IP 版本" : "IP Version" }
    var timeout: String { lang == .chinese ? "超时" : "Timeout" }
    var dnsServer: String { lang == .chinese ? "DNS 服务器" : "DNS Server" }
    var resolveRecords: String { lang == .chinese ? "解析记录" : "Resolve Records" }
    var copySuccess: String { lang == .chinese ? "已复制到剪贴板" : "Copied to clipboard" }
    
    // MARK: - 终端提示文字
    var noTestRecords: String { lang == .chinese ? "暂无测试记录" : "No test records" }
    var pingHint: String { lang == .chinese ? "点击开始按钮进行 Ping 测试" : "Tap start button to run Ping test" }
    var traceHint: String { lang == .chinese ? "点击开始按钮追踪路由路径" : "Tap start button to trace route" }
    var tcpHint: String { lang == .chinese ? "点击测试按钮检测端口连通性" : "Tap test button to check port connectivity" }
    var udpHint: String { lang == .chinese ? "点击发送按钮进行 UDP 测试" : "Tap send button to run UDP test" }
    var httpHint: String { lang == .chinese ? "输入 URL 并点击发送开始请求" : "Enter URL and tap send to start request" }
    
    // MARK: - 关于页面
    var versionInfo: String { lang == .chinese ? "版本信息" : "Version Info" }
    var currentVersion: String { lang == .chinese ? "当前版本" : "Current Version" }
    var buildNumber: String { lang == .chinese ? "构建号" : "Build Number" }
    var checkUpdate: String { lang == .chinese ? "检查更新" : "Check for Updates" }
    var developerInfo: String { lang == .chinese ? "开发信息" : "Developer Info" }
    var developer: String { lang == .chinese ? "开发者" : "Developer" }
    var copyright: String { lang == .chinese ? "版权" : "Copyright" }
    var relatedLinks: String { lang == .chinese ? "相关链接" : "Related Links" }
    var officialWebsite: String { lang == .chinese ? "官方网站" : "Official Website" }
    
    // MARK: - 更新检查
    var newVersionAvailable: String { lang == .chinese ? "发现新版本" : "New Version Available" }
    var latestVersion: String { lang == .chinese ? "最新版本" : "Latest Version" }
    var updateNow: String { lang == .chinese ? "立即更新" : "Update Now" }
    var updateLater: String { lang == .chinese ? "稍后提醒" : "Later" }
    var ignoreThisVersion: String { lang == .chinese ? "忽略此版本" : "Ignore This Version" }
    var alreadyLatestVersion: String { lang == .chinese ? "当前已是最新版本" : "You're on the latest version" }
    var checkUpdateFailed: String { lang == .chinese ? "检查更新失败" : "Failed to check for updates" }
    
    // MARK: - TCP 页面
    var tcpTitle: String { lang == .chinese ? "TCP 连接测试" : "TCP Connection Test" }
    var hostOrIP: String { lang == .chinese ? "主机名或 IP" : "Hostname or IP" }
    var scanCommonPorts: String { lang == .chinese ? "扫描常用端口" : "Scan Common Ports" }
    var stop: String { lang == .chinese ? "停止" : "Stop" }
    var test: String { lang == .chinese ? "测试" : "Test" }
    
    // MARK: - UDP 页面
    var udpTitle: String { lang == .chinese ? "UDP 测试" : "UDP Test" }
    var send: String { lang == .chinese ? "发送" : "Send" }
    var udpNote: String { lang == .chinese ? "UDP 是无连接协议，发送成功不代表对方收到" : "UDP is connectionless, successful send doesn't guarantee delivery" }
    var sendLabel: String { lang == .chinese ? "发送" : "Send" }
    var responseLabel: String { lang == .chinese ? "响应" : "Response" }
    var latencyLabel: String { lang == .chinese ? "延迟:" : "Latency:" }
    var errorLabel: String { lang == .chinese ? "错误:" : "Error:" }
    
    // MARK: - HTTP GET 页面
    var httpTitle: String { "HTTP GET" }
    var enterURL: String { lang == .chinese ? "输入 URL" : "Enter URL" }
    var timeoutLabel: String { lang == .chinese ? "超时:" : "Timeout:" }
    var requesting: String { lang == .chinese ? "请求中" : "Requesting" }
    
    // MARK: - Traceroute 页面
    var enterHostOrIPPlaceholder: String { lang == .chinese ? "输入主机名或 IP" : "Enter hostname or IP" }
    
    // MARK: - 抓包页面
    var packetCaptureTitle: String { lang == .chinese ? "网络抓包" : "Packet Capture" }
    var captureStatus: String { lang == .chinese ? "抓包状态" : "Capture Status" }
    var configureAndStart: String { lang == .chinese ? "配置并开始抓包" : "Configure and Start" }
    var startCapture: String { lang == .chinese ? "开始抓包" : "Start Capture" }
    var connecting: String { lang == .chinese ? "连接中..." : "Connecting..." }
    var stopCapture: String { lang == .chinese ? "停止抓包" : "Stop Capture" }
    var disconnecting: String { lang == .chinese ? "断开中..." : "Disconnecting..." }
    var firstTimeSetup: String { lang == .chinese ? "首次使用需要配置 VPN，点击上方按钮开始" : "First time setup requires VPN configuration, tap button above to start" }
    var capturingTraffic: String { lang == .chinese ? "正在捕获网络流量，所有请求都会被记录" : "Capturing network traffic, all requests will be recorded" }
    var packets: String { lang == .chinese ? "数据包" : "Packets" }
    var totalTraffic: String { lang == .chinese ? "总流量" : "Total" }
    var outgoing: String { lang == .chinese ? "上行" : "Out" }
    var incoming: String { lang == .chinese ? "下行" : "In" }
    var searchPlaceholder: String { lang == .chinese ? "搜索 IP、URL 或关键词" : "Search IP, URL or keywords" }
    var waitingForRequests: String { lang == .chinese ? "等待网络请求..." : "Waiting for requests..." }
    var tapToStartCapture: String { lang == .chinese ? "点击开始抓包" : "Tap to start capture" }
    var configureCapture: String { lang == .chinese ? "配置抓包环境" : "Configure capture environment" }
    var openOtherApps: String { lang == .chinese ? "打开其他 App 或浏览网页，流量会自动记录" : "Open other apps or browse web, traffic will be recorded" }
    var tapButtonToStart: String { lang == .chinese ? "点击上方按钮开始捕获网络流量" : "Tap button above to start capturing traffic" }
    var firstTimeVPNSetup: String { lang == .chinese ? "首次使用需要配置本地 VPN\n类似 Stream 的抓包方式" : "First time requires local VPN setup\nSimilar to Stream's capture method" }
    var httpsCapture: String { lang == .chinese ? "HTTPS 抓包" : "HTTPS Capture" }
    var httpsCaptureDesc: String { lang == .chinese ? "要查看 HTTPS 加密内容，需要安装并信任 CA 证书。这是 Stream、Charles 等抓包工具的标准做法。" : "To view HTTPS encrypted content, you need to install and trust CA certificate. This is standard practice for tools like Stream, Charles." }
    var securityTip: String { lang == .chinese ? "安全提示" : "Security Tip" }
    var securityTipContent: String { lang == .chinese ? "• 证书仅用于本地抓包调试\n• 抓包完成后建议删除证书\n• 不要在生产环境使用" : "• Certificate is only for local debugging\n• Remove certificate after capture\n• Don't use in production" }
    var httpsCertificate: String { lang == .chinese ? "HTTPS 证书" : "HTTPS Certificate" }
    var done: String { lang == .chinese ? "完成" : "Done" }
    var overview: String { lang == .chinese ? "概览" : "Overview" }
    var packetDetail: String { lang == .chinese ? "数据包详情" : "Packet Detail" }
    var sourceAddress: String { lang == .chinese ? "源地址" : "Source" }
    var destAddress: String { lang == .chinese ? "目标地址" : "Destination" }
    var time: String { lang == .chinese ? "时间" : "Time" }
    var direction: String { lang == .chinese ? "方向" : "Direction" }
    var sendDirection: String { lang == .chinese ? "发送" : "Send" }
    var receiveDirection: String { lang == .chinese ? "接收" : "Receive" }
    var protocolLabel: String { lang == .chinese ? "协议" : "Protocol" }
    var size: String { lang == .chinese ? "大小" : "Size" }
    var httpMethod: String { lang == .chinese ? "HTTP 方法" : "HTTP Method" }
    var url: String { "URL" }
    var noHttpHeaders: String { lang == .chinese ? "无 HTTP Headers" : "No HTTP Headers" }
    var protocolFilter: String { lang == .chinese ? "协议过滤" : "Protocol Filter" }
    var filterTitle: String { lang == .chinese ? "过滤器" : "Filter" }
    var exportData: String { lang == .chinese ? "导出数据" : "Export Data" }
    var needNetworkExtension: String { lang == .chinese ? "需要配置 Network Extension" : "Network Extension Required" }
    var networkExtensionDesc: String { lang == .chinese ? "本地 VPN 抓包功能需要 Apple 的 Network Extension 权限。" : "Local VPN capture requires Apple's Network Extension permission." }
    var solution: String { lang == .chinese ? "解决方案" : "Solution" }
    var alternativeSolution: String { lang == .chinese ? "替代方案" : "Alternative" }
    var alternativeDesc: String { lang == .chinese ? "如果无法获得 Network Extension 权限，可以使用以下工具：" : "If you cannot get Network Extension permission, use these tools:" }
    var configGuide: String { lang == .chinese ? "配置指南" : "Setup Guide" }
    var close: String { lang == .chinese ? "关闭" : "Close" }
    var bytes: String { "bytes" }
    
    // MARK: - 历史任务
    var scanResult: String { lang == .chinese ? "扫描结果" : "Scan Result" }
    var portDetails: String { lang == .chinese ? "端口详情" : "Port Details" }
    var portPrefix: String { "Port" }
    
    // MARK: - DNS
    var priorityMark: String { lang == .chinese ? "*优先" : "*Primary" }
    
    // MARK: - 设置
    var build: String { "Build" }
    
    // MARK: - 通用错误
    var errorTitle: String { lang == .chinese ? "错误" : "Error" }
    var ok: String { lang == .chinese ? "确定" : "OK" }
    var unknownError: String { lang == .chinese ? "未知错误" : "Unknown Error" }
    
    // MARK: - 私有 IP
    var localNetwork: String { lang == .chinese ? "本地网络" : "Local Network" }
    var localRegion: String { lang == .chinese ? "本地" : "Local" }
    
    // MARK: - 抓包设置指南
    var setupGuideStep1Title: String { lang == .chinese ? "申请 Network Extension 权限" : "Apply for Network Extension Permission" }
    var setupGuideStep1Desc: String { lang == .chinese ? "访问 Apple Developer Portal，为你的 App ID 申请 Network Extension 权限。这需要向 Apple 说明用途。" : "Visit Apple Developer Portal to apply for Network Extension permission for your App ID. This requires explaining the use case to Apple." }
    var setupGuideStep2Title: String { lang == .chinese ? "创建 Network Extension Target" : "Create Network Extension Target" }
    var setupGuideStep2Desc: String { lang == .chinese ? "在 Xcode 中添加 Network Extension Target，选择 Packet Tunnel Provider 类型。" : "Add a Network Extension Target in Xcode, select Packet Tunnel Provider type." }
    var setupGuideStep3Title: String { lang == .chinese ? "配置 App Groups" : "Configure App Groups" }
    var setupGuideStep3Desc: String { lang == .chinese ? "主 App 和 Extension 需要共享 App Group 以进行数据通信。" : "The main App and Extension need to share an App Group for data communication." }
    var setupGuideStep4Title: String { lang == .chinese ? "配置 Entitlements" : "Configure Entitlements" }
    var setupGuideStep4Desc: String { lang == .chinese ? "添加 com.apple.developer.networking.networkextension 权限。" : "Add com.apple.developer.networking.networkextension entitlement." }
    var alternativeStream: String { lang == .chinese ? "App Store 免费抓包工具" : "Free packet capture tool on App Store" }
    var alternativeCharles: String { lang == .chinese ? "macOS 代理抓包工具" : "macOS proxy capture tool" }
    var alternativeProxyman: String { lang == .chinese ? "macOS 现代抓包工具" : "Modern macOS capture tool" }
}

// MARK: - View Extension for Language
extension View {
    func localized() -> some View {
        self.environmentObject(LanguageManager.shared)
    }
}
