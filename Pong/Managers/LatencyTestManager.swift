//
//  LatencyTestManager.swift
//  Pong
//
//  Created by 张金琛 on 2026/1/2.
//

import Foundation
internal import Combine

// MARK: - 测试目标分类
enum LatencyCategory: RawRepresentable, Codable, Hashable {
    case custom
    case search
    case social
    case video
    case gaming
    case shopping
    case cloud
    case ai
    case news
    case userDefined(String)  // 用户自定义分类
    
    // 预定义的分类列表（不含 userDefined）
    static var allCases: [LatencyCategory] {
        [.custom, .search, .social, .video, .gaming, .shopping, .cloud, .ai, .news]
    }
    
    // 用于选择器显示的分类（不含 custom）
    static var selectableCases: [LatencyCategory] {
        [.ai, .social, .video, .gaming, .shopping, .cloud, .news, .search]
    }
    
    var rawValue: String {
        switch self {
        case .custom: return "custom"
        case .search: return "search"
        case .social: return "social"
        case .video: return "video"
        case .gaming: return "gaming"
        case .shopping: return "shopping"
        case .cloud: return "cloud"
        case .ai: return "ai"
        case .news: return "news"
        case .userDefined(let name): return "userDefined:\(name)"
        }
    }
    
    init?(rawValue: String) {
        switch rawValue {
        case "custom": self = .custom
        case "search": self = .search
        case "social": self = .social
        case "video": self = .video
        case "gaming": self = .gaming
        case "shopping": self = .shopping
        case "cloud": self = .cloud
        case "ai": self = .ai
        case "news": self = .news
        default:
            if rawValue.hasPrefix("userDefined:") {
                let name = String(rawValue.dropFirst("userDefined:".count))
                self = .userDefined(name)
            } else {
                return nil
            }
        }
    }
    
    var chineseName: String {
        switch self {
        case .custom: return "自定义"
        case .search: return "搜索引擎"
        case .social: return "社交媒体"
        case .video: return "视频平台"
        case .gaming: return "游戏平台"
        case .shopping: return "购物电商"
        case .cloud: return "云服务"
        case .ai: return "AI 服务"
        case .news: return "新闻资讯"
        case .userDefined(let name): return name
        }
    }
    
    var englishName: String {
        switch self {
        case .custom: return "Custom"
        case .search: return "Search"
        case .social: return "Social"
        case .video: return "Video"
        case .gaming: return "Gaming"
        case .shopping: return "Shopping"
        case .cloud: return "Cloud"
        case .ai: return "AI"
        case .news: return "News"
        case .userDefined(let name): return name
        }
    }
    
    var displayName: String {
        LanguageManager.shared.currentLanguage == .chinese ? chineseName : englishName
    }
    
    var isUserDefined: Bool {
        if case .userDefined = self {
            return true
        }
        return false
    }
}

// MARK: - 测试目标模型
struct LatencyTarget: Identifiable, Codable, Equatable {
    let id: UUID
    var label: String
    var url: String
    var isCustom: Bool
    var category: LatencyCategory
    
    init(id: UUID = UUID(), label: String, url: String, isCustom: Bool = false, category: LatencyCategory = .custom) {
        self.id = id
        self.label = label
        self.url = url
        self.isCustom = isCustom
        self.category = category
    }
}

// MARK: - 测试结果模型
struct LatencyResult: Identifiable, Equatable {
    let id: UUID
    let target: LatencyTarget
    var latency: Double?  // 毫秒
    var status: LatencyStatus
    var errorMessage: String?
    var timing: LatencyTiming?
    var headers: [String: String]?
    var statusCode: Int?
    
    enum LatencyStatus: Equatable {
        case pending
        case testing
        case success
        case failed
    }

    static func == (lhs: LatencyResult, rhs: LatencyResult) -> Bool {
        lhs.id == rhs.id &&
        lhs.latency == rhs.latency &&
        lhs.status == rhs.status &&
        lhs.errorMessage == rhs.errorMessage &&
        lhs.statusCode == rhs.statusCode
    }
}

// MARK: - 详细时间信息
struct LatencyTiming: Equatable {
    var dnsLookup: Double?      // DNS 查询时间
    var tcpConnection: Double?  // TCP 连接时间
    var tlsHandshake: Double?   // TLS 握手时间
    var requestSent: Double?    // 请求发送时间
    var responseReceived: Double? // 响应接收时间
    var totalTime: Double       // 总时间
}

// MARK: - 延迟测试管理器
@MainActor
class LatencyTestManager: ObservableObject {
    static let shared = LatencyTestManager()
    
    private let customTargetsKey = "CustomLatencyTargets"
    private let customCategoriesKey = "CustomLatencyCategories"
    
    // 中文环境默认测试目标
    private let chineseDefaultTargets: [LatencyTarget] = [
        // 搜索引擎
        LatencyTarget(label: "百度", url: "https://www.baidu.com", category: .search),
        LatencyTarget(label: "搜狗", url: "https://www.sogou.com", category: .search),
        LatencyTarget(label: "必应中国", url: "https://cn.bing.com", category: .search),
        // 社交媒体
        LatencyTarget(label: "微信", url: "https://weixin.qq.com", category: .social),
        LatencyTarget(label: "微博", url: "https://www.weibo.com", category: .social),
        LatencyTarget(label: "知乎", url: "https://www.zhihu.com", category: .social),
        LatencyTarget(label: "小红书", url: "https://www.xiaohongshu.com", category: .social),
        LatencyTarget(label: "抖音", url: "https://www.douyin.com", category: .social),
        // 视频平台
        LatencyTarget(label: "哔哩哔哩", url: "https://www.bilibili.com", category: .video),
        LatencyTarget(label: "优酷", url: "https://www.youku.com", category: .video),
        LatencyTarget(label: "爱奇艺", url: "https://www.iqiyi.com", category: .video),
        LatencyTarget(label: "腾讯视频", url: "https://v.qq.com", category: .video),
        LatencyTarget(label: "芒果TV", url: "https://www.mgtv.com", category: .video),
        // 游戏平台
        LatencyTarget(label: "网易游戏", url: "https://game.163.com", category: .gaming),
        LatencyTarget(label: "腾讯游戏", url: "https://game.qq.com", category: .gaming),
        LatencyTarget(label: "米哈游", url: "https://www.mihoyo.com", category: .gaming),
        LatencyTarget(label: "TapTap", url: "https://www.taptap.cn", category: .gaming),
        // 购物电商
        LatencyTarget(label: "淘宝", url: "https://www.taobao.com", category: .shopping),
        LatencyTarget(label: "京东", url: "https://www.jd.com", category: .shopping),
        LatencyTarget(label: "拼多多", url: "https://www.pinduoduo.com", category: .shopping),
        LatencyTarget(label: "天猫", url: "https://www.tmall.com", category: .shopping),
        // 云服务
        LatencyTarget(label: "阿里云", url: "https://www.aliyun.com", category: .cloud),
        LatencyTarget(label: "腾讯云", url: "https://cloud.tencent.com", category: .cloud),
        LatencyTarget(label: "华为云", url: "https://www.huaweicloud.com", category: .cloud),
        // AI 服务
        LatencyTarget(label: "元宝", url: "https://yuanbao.tencent.com", category: .ai),
        LatencyTarget(label: "通义千问", url: "https://tongyi.aliyun.com", category: .ai),
        LatencyTarget(label: "文心一言", url: "https://yiyan.baidu.com", category: .ai),
        LatencyTarget(label: "Kimi", url: "https://kimi.moonshot.cn", category: .ai),
        LatencyTarget(label: "豆包", url: "https://www.doubao.com", category: .ai),
        LatencyTarget(label: "智谱清言", url: "https://chatglm.cn", category: .ai),
        // 新闻资讯
        LatencyTarget(label: "今日头条", url: "https://www.toutiao.com", category: .news),
        LatencyTarget(label: "网易新闻", url: "https://news.163.com", category: .news),
        LatencyTarget(label: "腾讯新闻", url: "https://news.qq.com", category: .news),
    ]
    
    // 英文环境默认测试目标
    private let englishDefaultTargets: [LatencyTarget] = [
        // 搜索引擎
        LatencyTarget(label: "Google", url: "https://www.google.com", category: .search),
        LatencyTarget(label: "Bing", url: "https://www.bing.com", category: .search),
        LatencyTarget(label: "DuckDuckGo", url: "https://duckduckgo.com", category: .search),
        // 社交媒体
        LatencyTarget(label: "Facebook", url: "https://www.facebook.com", category: .social),
        LatencyTarget(label: "Twitter/X", url: "https://www.x.com", category: .social),
        LatencyTarget(label: "Instagram", url: "https://www.instagram.com", category: .social),
        LatencyTarget(label: "LinkedIn", url: "https://www.linkedin.com", category: .social),
        LatencyTarget(label: "Reddit", url: "https://www.reddit.com", category: .social),
        // 视频平台
        LatencyTarget(label: "YouTube", url: "https://www.youtube.com", category: .video),
        LatencyTarget(label: "Netflix", url: "https://www.netflix.com", category: .video),
        LatencyTarget(label: "Twitch", url: "https://www.twitch.tv", category: .video),
        LatencyTarget(label: "Disney+", url: "https://www.disneyplus.com", category: .video),
        LatencyTarget(label: "Spotify", url: "https://www.spotify.com", category: .video),
        // 游戏平台
        LatencyTarget(label: "Steam", url: "https://store.steampowered.com", category: .gaming),
        LatencyTarget(label: "Epic Games", url: "https://www.epicgames.com", category: .gaming),
        LatencyTarget(label: "PlayStation", url: "https://www.playstation.com", category: .gaming),
        LatencyTarget(label: "Xbox", url: "https://www.xbox.com", category: .gaming),
        LatencyTarget(label: "Riot Games", url: "https://www.riotgames.com", category: .gaming),
        // 购物电商
        LatencyTarget(label: "Amazon", url: "https://www.amazon.com", category: .shopping),
        LatencyTarget(label: "eBay", url: "https://www.ebay.com", category: .shopping),
        LatencyTarget(label: "Walmart", url: "https://www.walmart.com", category: .shopping),
        LatencyTarget(label: "Target", url: "https://www.target.com", category: .shopping),
        // 云服务
        LatencyTarget(label: "AWS", url: "https://aws.amazon.com", category: .cloud),
        LatencyTarget(label: "Azure", url: "https://azure.microsoft.com", category: .cloud),
        LatencyTarget(label: "Google Cloud", url: "https://cloud.google.com", category: .cloud),
        LatencyTarget(label: "Cloudflare", url: "https://www.cloudflare.com", category: .cloud),
        LatencyTarget(label: "GitHub", url: "https://github.com", category: .cloud),
        // AI 服务
        LatencyTarget(label: "ChatGPT", url: "https://chat.openai.com", category: .ai),
        LatencyTarget(label: "Claude", url: "https://claude.ai", category: .ai),
        LatencyTarget(label: "Gemini", url: "https://gemini.google.com", category: .ai),
        LatencyTarget(label: "Perplexity", url: "https://www.perplexity.ai", category: .ai),
        LatencyTarget(label: "Midjourney", url: "https://www.midjourney.com", category: .ai),
        LatencyTarget(label: "Hugging Face", url: "https://huggingface.co", category: .ai),
        // 新闻资讯
        LatencyTarget(label: "CNN", url: "https://www.cnn.com", category: .news),
        LatencyTarget(label: "BBC", url: "https://www.bbc.com", category: .news),
        LatencyTarget(label: "NYTimes", url: "https://www.nytimes.com", category: .news),
    ]
    
    // 根据当前语言返回默认目标
    var defaultTargets: [LatencyTarget] {
        LanguageManager.shared.currentLanguage == .chinese ? chineseDefaultTargets : englishDefaultTargets
    }
    
    // 获取所有非自定义的分类（按顺序）
    var categories: [LatencyCategory] {
        [.ai, .social, .video, .gaming, .shopping, .cloud, .news, .search]
    }
    
    // 按分类获取结果
    func results(for category: LatencyCategory) -> [LatencyResult] {
        results.filter { $0.target.category == category }
    }
    
    @Published var customTargets: [LatencyTarget] = []
    @Published var customCategories: [String] = []  // 用户自定义分类名称列表
    @Published var results: [LatencyResult] = []
    @Published var isTesting: Bool = false
    
    private var testTasks: [UUID: Task<Void, Never>] = [:]
    
    private init() {
        loadCustomTargets()
        loadCustomCategories()
    }
    
    // MARK: - 持久化
    
    func loadCustomTargets() {
        if let data = UserDefaults.standard.data(forKey: customTargetsKey),
           let targets = try? JSONDecoder().decode([LatencyTarget].self, from: data) {
            customTargets = targets
        }
    }
    
    func saveCustomTargets() {
        if let data = try? JSONEncoder().encode(customTargets) {
            UserDefaults.standard.set(data, forKey: customTargetsKey)
        }
    }
    
    func loadCustomCategories() {
        if let categories = UserDefaults.standard.stringArray(forKey: customCategoriesKey) {
            customCategories = categories
        }
    }
    
    func saveCustomCategories() {
        UserDefaults.standard.set(customCategories, forKey: customCategoriesKey)
    }
    
    func addCustomCategory(_ name: String) {
        guard !name.isEmpty, !customCategories.contains(name) else { return }
        customCategories.append(name)
        saveCustomCategories()
    }
    
    func removeCustomCategory(_ name: String) {
        customCategories.removeAll { $0 == name }
        saveCustomCategories()
    }
    
    func addCustomTarget(label: String, url: String, category: LatencyCategory = .custom) {
        let target = LatencyTarget(label: label, url: url, isCustom: true, category: category)
        customTargets.append(target)
        saveCustomTargets()
    }
    
    func removeCustomTarget(_ target: LatencyTarget) {
        customTargets.removeAll { $0.id == target.id }
        saveCustomTargets()
        
        // 同步更新结果数组，移除对应项
        if let index = results.firstIndex(where: { $0.target.id == target.id }) {
            results.remove(at: index)
        }
    }
    
    // MARK: - 重试
    
    func retryTest(for result: LatencyResult) {
        guard let index = results.firstIndex(where: { $0.id == result.id }) else { return }
        
        let target = result.target
        testTasks[target.id]?.cancel()
        
        let task = Task { [weak self] in
            guard let self = self else { return }
            await self.testSingleTarget(target: target, index: index)
        }
        testTasks[target.id] = task
    }
    
    // MARK: - 测试
    
    func startTest() {
        guard !isTesting else { return }
        stopTest()
        
        isTesting = true
        
        // 合并所有目标
        let allTargets = customTargets + defaultTargets
        
        // 初始化结果（全部显示为 pending）
        results = allTargets.map { target in
            LatencyResult(id: target.id, target: target, latency: nil, status: .pending, timing: nil, headers: nil, statusCode: nil)
        }
        
        // 为每个目标启动独立的测试任务
        for (index, target) in allTargets.enumerated() {
            let task = Task { [weak self] in
                guard let self = self else { return }
                await self.testSingleTarget(target: target, index: index)
            }
            testTasks[target.id] = task
        }
        
        // 启动监控任务，检测全部完成
        Task { [weak self] in
            while let self = self {
                try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
                
                await MainActor.run {
                    guard self.isTesting else { return }
                    let allDone = self.results.allSatisfy { $0.status == .success || $0.status == .failed }
                    if allDone {
                        self.isTesting = false
                        self.testTasks.removeAll()
                        self.sortResults()
                    }
                }
                
                // 如果不再测试（已完成或被停止），退出循环
                let isStillTesting = await MainActor.run { self.isTesting }
                if !isStillTesting { break }
            }
        }
    }
    
    /// 测试单个目标并直接更新 results
    private func testSingleTarget(target: LatencyTarget, index: Int) async {
        // 标记为测试中
        updateResult(at: index) { $0.status = .testing }
        
        guard let url = URL(string: target.url) else {
            updateResult(at: index) {
                $0.status = .failed
                $0.errorMessage = "Invalid URL"
            }
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5
        
        // 执行请求
        let result = await performSingleRequest(request: request, target: target)
        
        // 更新结果 (自动回到主线程，因为 testSingleTarget 是 @MainActor)
        updateResult(at: index) {
            $0.latency = result.latency
            $0.status = result.status
            $0.statusCode = result.statusCode
            $0.timing = result.timing
            $0.headers = result.headers
            $0.errorMessage = result.errorMessage
        }
    }
    
    /// 安全更新结果并触发 UI 刷新 (必须在主线程调用)
    private func updateResult(at index: Int, update: (inout LatencyResult) -> Void) {
        guard index < results.count else { return }
        var newResults = results
        update(&newResults[index])
        results = newResults // 重新赋值触发 @Published
    }
    
    /// 执行单个请求，返回结果 (nonisolated 避免阻塞主线程)
    nonisolated private func performSingleRequest(request: URLRequest, target: LatencyTarget) async -> LatencyResult {
        await withCheckedContinuation { continuation in
            let delegate = MetricsDelegate()
            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = 5
            config.timeoutIntervalForResource = 5
            let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
            
            let task = session.dataTask(with: request) { _, response, error in
                defer { session.invalidateAndCancel() }
                
                if let error = error {
                    continuation.resume(returning: LatencyResult(
                        id: target.id,
                        target: target,
                        latency: nil,
                        status: .failed,
                        errorMessage: error.localizedDescription,
                        timing: nil,
                        headers: nil,
                        statusCode: nil
                    ))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    continuation.resume(returning: LatencyResult(
                        id: target.id,
                        target: target,
                        latency: nil,
                        status: .failed,
                        errorMessage: "Invalid Response",
                        timing: nil,
                        headers: nil,
                        statusCode: nil
                    ))
                    return
                }
                
                // 提取 headers
                var headers: [String: String] = [:]
                for (key, value) in httpResponse.allHeaderFields {
                    headers[String(describing: key)] = String(describing: value)
                }
                
                // 从 metrics 中提取 timing 信息
                var timing: LatencyTiming?
                if let metrics = delegate.metrics,
                   let tm = metrics.transactionMetrics.last {
                    
                    var dnsLookup: Double?
                    var tcpConnection: Double?
                    var tlsHandshake: Double?
                    var requestSent: Double?
                    var responseReceived: Double?
                    
                    if let start = tm.domainLookupStartDate, let end = tm.domainLookupEndDate {
                        dnsLookup = end.timeIntervalSince(start) * 1000
                    }
                    
                    if let start = tm.connectStartDate, let end = tm.connectEndDate {
                        var tcp = end.timeIntervalSince(start) * 1000
                        if let secureStart = tm.secureConnectionStartDate, let secureEnd = tm.secureConnectionEndDate {
                            tlsHandshake = secureEnd.timeIntervalSince(secureStart) * 1000
                            tcp -= tlsHandshake ?? 0
                        }
                        tcpConnection = tcp
                    }
                    
                    if let start = tm.requestStartDate, let end = tm.requestEndDate {
                        requestSent = end.timeIntervalSince(start) * 1000
                    }
                    
                    if let start = tm.responseStartDate, let end = tm.responseEndDate {
                        responseReceived = end.timeIntervalSince(start) * 1000
                    }
                    
                    var totalTime: Double = 0
                    if let start = tm.fetchStartDate, let end = tm.responseEndDate {
                        totalTime = end.timeIntervalSince(start) * 1000
                    }
                    
                    timing = LatencyTiming(
                        dnsLookup: dnsLookup,
                        tcpConnection: tcpConnection,
                        tlsHandshake: tlsHandshake,
                        requestSent: requestSent,
                        responseReceived: responseReceived,
                        totalTime: totalTime
                    )
                }
                
                let latency = timing?.totalTime ?? 0
                let status: LatencyResult.LatencyStatus = (200...399).contains(httpResponse.statusCode) ? .success : .failed
                let errorMsg: String? = status == .failed ? "HTTP \(httpResponse.statusCode)" : nil
                
                continuation.resume(returning: LatencyResult(
                    id: target.id,
                    target: target,
                    latency: latency,
                    status: status,
                    errorMessage: errorMsg,
                    timing: timing,
                    headers: headers,
                    statusCode: httpResponse.statusCode
                ))
            }
            task.resume()
        }
    }
    
    private func sortResults() {
        // 分离自定义和默认目标
        let customResults = results.filter { $0.target.isCustom }
        var defaultResults = results.filter { !$0.target.isCustom }
        
        // 默认目标按延迟排序
        defaultResults.sort { r1, r2 in
            switch (r1.latency, r2.latency) {
            case (let l1?, let l2?):
                return l1 < l2
            case (nil, _):
                return false
            case (_, nil):
                return true
            }
        }
        
        results = customResults + defaultResults
    }
    
    func stopTest() {
        for (_, task) in testTasks {
            task.cancel()
        }
        testTasks.removeAll()
        isTesting = false
        
        // 将所有还在 pending 或 testing 状态的结果标记为失败
        var newResults = results
        for index in newResults.indices {
            if newResults[index].status == .pending || newResults[index].status == .testing {
                newResults[index].status = .failed
                newResults[index].errorMessage = "Cancelled"
            }
        }
        results = newResults
    }
}

// MARK: - Metrics Delegate
private class MetricsDelegate: NSObject, URLSessionTaskDelegate {
    var metrics: URLSessionTaskMetrics?
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        self.metrics = metrics
    }
}
