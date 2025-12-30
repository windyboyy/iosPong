//
//  SpeedTestManager.swift
//  Pong
//
//  Created by 张金琛 on 2025/12/13.
//

import Foundation
import Network
import SwiftUI
internal import Combine

@MainActor
class SpeedTestManager: ObservableObject {
    static let shared = SpeedTestManager()
    
    @Published var isTesting = false
    @Published var currentPhase: TestPhase = .idle
    @Published var downloadSpeed: Double = 0  // Mbps
    @Published var uploadSpeed: Double = 0    // Mbps
    @Published var latency: Double = 0        // ms
    @Published var jitter: Double = 0         // ms (延迟抖动)
    @Published var progress: Double = 0       // 0-1
    @Published var error: String?
    
    // 常用应用延迟测试
    @Published var appLatencyResults: [AppLatencyInfo] = []
    @Published var isTestingAppLatency = false
    
    enum TestPhase: String {
        case idle = "准备就绪"
        case latency = "测试延迟..."
        case download = "测试下载..."
        case upload = "测试上传..."
        case completed = "测试完成"
    }
    
    // MARK: - 常用应用延迟
    struct AppLatencyInfo: Identifiable {
        let id = UUID()
        let name: String
        let icon: String
        let url: String
        var latency: Double? = nil
        
        var quality: NetworkQuality {
            guard let latency = latency else { return .unknown }
            if latency < 50 { return .excellent }
            if latency < 100 { return .good }
            if latency < 200 { return .fair }
            return .poor
        }
    }
    
    enum NetworkQuality {
        case excellent, good, fair, poor, unknown
        
        var color: Color {
            switch self {
            case .excellent: return .green
            case .good: return .blue
            case .fair: return .orange
            case .poor: return .red
            case .unknown: return .gray
            }
        }
        
        var text: String {
            let lang = LanguageManager.shared.currentLanguage
            switch self {
            case .excellent: return lang == .chinese ? "极佳" : "Excellent"
            case .good: return lang == .chinese ? "良好" : "Good"
            case .fair: return lang == .chinese ? "一般" : "Fair"
            case .poor: return lang == .chinese ? "较差" : "Poor"
            case .unknown: return "--"
            }
        }
    }
    
    // MARK: - 中文应用列表
    
    // 腾讯系应用列表 (中文)
    private let txAppsCN: [AppLatencyInfo] = [
        AppLatencyInfo(name: "腾讯新闻", icon: "newspaper.fill", url: "https://www.qq.com"),
        AppLatencyInfo(name: "腾讯视频", icon: "tv.fill", url: "https://v.qq.com"),
        AppLatencyInfo(name: "微信", icon: "message.fill", url: "https://weixin.qq.com"),
        AppLatencyInfo(name: "微信支付", icon: "creditcard.fill", url: "https://support.pay.weixin.qq.com"),
        AppLatencyInfo(name: "广告平台", icon: "megaphone.fill", url: "https://e.qq.com"),
        AppLatencyInfo(name: "王者荣耀", icon: "gamecontroller.fill", url: "https://pvp.qq.com"),
        AppLatencyInfo(name: "和平精英", icon: "scope", url: "https://gp.qq.com"),
        AppLatencyInfo(name: "腾讯云", icon: "cloud.fill", url: "https://cloud.tencent.com"),
        AppLatencyInfo(name: "腾讯官网", icon: "building.2.fill", url: "https://www.tencent.com"),
        AppLatencyInfo(name: "元宝", icon: "sparkles", url: "https://yuanbao.tencent.com"),
    ]
    
    // 其他应用列表 (中文)
    private let otherAppsCN: [AppLatencyInfo] = [
        AppLatencyInfo(name: "百度", icon: "magnifyingglass", url: "https://www.baidu.com"),
        AppLatencyInfo(name: "阿里", icon: "cart.fill", url: "https://www.aliyun.com"),
        AppLatencyInfo(name: "字节", icon: "play.circle.fill", url: "https://www.bytedance.com"),
        AppLatencyInfo(name: "京东", icon: "bag.fill", url: "https://www.jd.com"),
        AppLatencyInfo(name: "微博", icon: "bubble.left.fill", url: "https://m.weibo.cn"),
        AppLatencyInfo(name: "美团", icon: "fork.knife", url: "https://www.meituan.com"),
        AppLatencyInfo(name: "网易", icon: "envelope.fill", url: "https://www.163.com"),
        AppLatencyInfo(name: "Deepseek", icon: "brain.head.profile", url: "https://www.deepseek.com"),
    ]
    
    // MARK: - 英文应用列表
    
    // Tech Giants (科技巨头)
    private let techGiantsEN: [AppLatencyInfo] = [
        AppLatencyInfo(name: "Google", icon: "magnifyingglass", url: "https://www.google.com"),
        AppLatencyInfo(name: "Microsoft", icon: "building.2.fill", url: "https://www.microsoft.com"),
        AppLatencyInfo(name: "Amazon", icon: "cart.fill", url: "https://www.amazon.com"),
        AppLatencyInfo(name: "AWS", icon: "cloud.fill", url: "https://aws.amazon.com"),
        AppLatencyInfo(name: "Apple", icon: "apple.logo", url: "https://www.apple.com"),
        AppLatencyInfo(name: "Meta", icon: "person.2.fill", url: "https://www.meta.com"),
        AppLatencyInfo(name: "OpenAI", icon: "sparkles", url: "https://openai.com"),
        AppLatencyInfo(name: "Cloudflare", icon: "shield.fill", url: "https://www.cloudflare.com"),
    ]
    
    // Social & Entertainment (社交娱乐)
    private let socialEntertainmentEN: [AppLatencyInfo] = [
        AppLatencyInfo(name: "YouTube", icon: "tv.fill", url: "https://www.youtube.com"),
        AppLatencyInfo(name: "TikTok", icon: "play.circle.fill", url: "https://www.tiktok.com"),
        AppLatencyInfo(name: "X", icon: "bubble.left.fill", url: "https://x.com"),
        AppLatencyInfo(name: "WhatsApp", icon: "message.fill", url: "https://www.whatsapp.com"),
        AppLatencyInfo(name: "Steam", icon: "gamecontroller.fill", url: "https://store.steampowered.com"),
        AppLatencyInfo(name: "Netflix", icon: "film.fill", url: "https://www.netflix.com"),
        AppLatencyInfo(name: "Spotify", icon: "music.note", url: "https://www.spotify.com"),
        AppLatencyInfo(name: "Reddit", icon: "text.bubble.fill", url: "https://www.reddit.com"),
    ]
    
    // Other (其他)
    private let otherEN: [AppLatencyInfo] = [
        AppLatencyInfo(name: "PayPal", icon: "creditcard.fill", url: "https://www.paypal.com"),
        AppLatencyInfo(name: "Epic Games", icon: "scope", url: "https://www.epicgames.com"),
        AppLatencyInfo(name: "eBay", icon: "bag.fill", url: "https://www.ebay.com"),
        AppLatencyInfo(name: "Uber Eats", icon: "fork.knife", url: "https://www.ubereats.com"),
        AppLatencyInfo(name: "Yahoo", icon: "envelope.fill", url: "https://www.yahoo.com"),
        AppLatencyInfo(name: "Deepseek", icon: "brain.head.profile", url: "https://www.deepseek.com"),
        AppLatencyInfo(name: "GitHub", icon: "chevron.left.forwardslash.chevron.right", url: "https://github.com"),
        AppLatencyInfo(name: "Discord", icon: "headphones", url: "https://discord.com"),
    ]
    
    // MARK: - 根据语言获取应用列表
    
    private var isChinese: Bool {
        LanguageManager.shared.currentLanguage == .chinese
    }
    
    private var txApps: [AppLatencyInfo] {
        isChinese ? txAppsCN : techGiantsEN
    }
    
    private var otherApps: [AppLatencyInfo] {
        isChinese ? otherAppsCN : socialEntertainmentEN
    }
    
    // 英文第三分类
    private var thirdApps: [AppLatencyInfo] {
        isChinese ? [] : otherEN
    }
    
    // 分类标题
    var firstCategoryTitle: String {
        isChinese ? "腾讯系" : "Tech Giants"
    }
    
    var secondCategoryTitle: String {
        isChinese ? "其他应用" : "Social & Entertainment"
    }
    
    var thirdCategoryTitle: String {
        "Other"
    }
    
    // 是否显示第三分类
    var hasThirdCategory: Bool {
        !isChinese
    }
    
    // 合并的应用列表
    private var defaultApps: [AppLatencyInfo] {
        txApps + otherApps + thirdApps
    }
    
    // MARK: - 测速服务器配置
    
    // 延迟测试 URL（使用 HEAD 请求，响应体大小无影响）
    private var latencyTestURL: String {
        isChinese ? "https://www.qq.com" : "https://www.google.com"
    }
    
    private var testTask: Task<Void, Never>?
    private var appLatencyTask: Task<Void, Never>?
    
    private init() {
        // 初始化应用延迟列表
        appLatencyResults = defaultApps
    }
    
    // MARK: - 网络状态检查
    
    /// 检查当前是否有网络连接（使用 LanguageManager 统一管理）
    var isNetworkAvailable: Bool {
        LanguageManager.shared.isNetworkAvailable
    }
    
    func startTest() {
        stopTest()
        
        // 检查网络连接
        guard isNetworkAvailable else {
            error = LanguageManager.shared.noNetworkError
            currentPhase = .completed
            return
        }
        
        isTesting = true
        currentPhase = .idle
        downloadSpeed = 0
        uploadSpeed = 0
        latency = 0
        jitter = 0
        progress = 0
        error = nil
        
        testTask = Task {
            do {
                // 1. 测试延迟和抖动（占进度 0 ~ 0.2）
                currentPhase = .latency
                progress = 0
                let (measuredLatency, measuredJitter) = try await measureLatencyAndJitter()
                latency = measuredLatency
                jitter = measuredJitter
                
                // 2. 测试下载速度（占进度 0.2 ~ 1.0）
                currentPhase = .download
                // 延迟测试完成后 progress 已经是 0.2，下载继续到 1.0
                downloadSpeed = try await measureDownloadSpeed()
                
                // 3. 测试上传速度（进度重置，从 0 ~ 1）
                currentPhase = .upload
                progress = 0  // 上传开始，进度重置为 0
                uploadSpeed = try await measureUploadSpeed()
                
                progress = 1.0
                currentPhase = .completed
                // 保存历史记录
                saveToHistory(success: true)
            } catch {
                if !Task.isCancelled {
                    self.error = error.localizedDescription
                    saveToHistory(success: false)
                }
            }
            
            isTesting = false
        }
    }
    
    private func saveToHistory(success: Bool) {
        let status: TaskStatus = success ? .success : .failure
        TaskHistoryManager.shared.addSpeedTestRecord(
            status: status,
            downloadSpeed: downloadSpeed > 0 ? downloadSpeed : nil,
            uploadSpeed: uploadSpeed > 0 ? uploadSpeed : nil,
            latency: latency > 0 ? latency : nil
        )
    }
    
    func stopTest() {
        testTask?.cancel()
        testTask = nil
        isTesting = false
        currentPhase = .idle
    }
    
    // MARK: - 延迟和抖动测试
    // 抖动(Jitter)计算：相邻延迟测量值差值的绝对值的平均值
    private func measureLatencyAndJitter() async throws -> (latency: Double, jitter: Double) {
        guard let url = URL(string: latencyTestURL) else {
            return (0, 0)
        }
        
        var latencies: [Double] = []
        let testCount = 10  // 测试10次以获得更准确的抖动值
        
        for i in 0..<testCount {
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"
            request.timeoutInterval = 5
            
            do {
                let start = Date()
                let _ = try await URLSession.shared.data(for: request)
                let elapsed = Date().timeIntervalSince(start) * 1000
                latencies.append(elapsed)
                
                // 实时显示当前平均延迟
                let avgLatency = latencies.reduce(0, +) / Double(latencies.count)
                self.latency = avgLatency
                
                // 实时计算并显示抖动值（使用当前所有数据计算）
                if latencies.count >= 2 {
                    var jitterSum: Double = 0
                    for j in 1..<latencies.count {
                        jitterSum += abs(latencies[j] - latencies[j-1])
                    }
                    self.jitter = jitterSum / Double(latencies.count - 1)
                }
                
                // 更新进度：延迟阶段占 0 ~ 0.2
                self.progress = 0.2 * Double(i + 1) / Double(testCount)
            } catch {
                continue
            }
            
            // 短暂间隔
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        
        guard latencies.count >= 2 else {
            return (latencies.first ?? 0, 0)
        }
        
        // 最终结果：取平均延迟
        let avgLatency = latencies.reduce(0, +) / Double(latencies.count)
        
        // 计算最终抖动：相邻延迟差值的绝对值的平均值
        var jitterSum: Double = 0
        for i in 1..<latencies.count {
            jitterSum += abs(latencies[i] - latencies[i-1])
        }
        let avgJitter = jitterSum / Double(latencies.count - 1)
        
        return (avgLatency, avgJitter)
    }
    
    // MARK: - 下载速度测试（多线程并发，模拟专业测速）
    private func measureDownloadSpeed() async throws -> Double {
        if isChinese {
            // 中文模式：使用 QQ 下载服务器（单线程，下载固定文件）
            return try await measureDownloadSpeedWithQQ()
        } else {
            // 英文模式：使用 Cloudflare 多线程下载
            return try await measureDownloadSpeedWithCloudflare()
        }
    }
    
    /// 中文模式：使用 Cloudflare 多线程下载测速（与英文模式相同，确保测试时间固定）
    private func measureDownloadSpeedWithQQ() async throws -> Double {
        // 中文模式也使用 Cloudflare，确保测试时间严格为 10 秒
        let concurrentStreams = 6
        let chunkSize = 25_000_000  // 每个请求 25MB
        let testDuration: TimeInterval = 10.0
        
        let coordinator = DownloadCoordinator(testDuration: testDuration)
        let testStartTime = Date()
        
        coordinator.onProgress = { [weak self] totalReceived, speed in
            Task { @MainActor in
                guard let self = self else { return }
                self.downloadSpeed = speed
            }
        }
        
        // 使用单独的 Task 来控制超时，确保严格 10 秒结束
        let downloadTask = Task {
            try await withThrowingTaskGroup(of: Void.self) { group in
                // 启动多个并发下载流
                for streamIndex in 0..<concurrentStreams {
                    group.addTask {
                        try await self.downloadStreamCN(
                            streamIndex: streamIndex,
                            chunkSize: chunkSize,
                            coordinator: coordinator
                        )
                    }
                }
                
                // 等待所有任务（实际上会被外部取消）
                for try await _ in group { }
            }
        }
        
        // 定时器：严格控制测试时间
        let startTime = Date()
        while Date().timeIntervalSince(startTime) < testDuration {
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            let elapsed = Date().timeIntervalSince(testStartTime)
            let timeProgress = min(elapsed / testDuration, 1.0)
            self.progress = 0.2 + (0.8 * timeProgress)
        }
        
        // 停止协调器，不再更新 UI
        coordinator.stop()
        
        // 时间到，取消下载任务
        downloadTask.cancel()
        
        // 确保进度条到达终点
        self.progress = 1.0
        
        // 计算最终速度
        let finalSpeed = coordinator.calculateFinalSpeed()
        self.downloadSpeed = finalSpeed
        return finalSpeed
    }
    
    /// 中文模式下载流：交替使用腾讯和 Cloudflare CDN
    private func downloadStreamCN(streamIndex: Int, chunkSize: Int, coordinator: DownloadCoordinator) async throws {
        // 使用 Cloudflare（国内访问也很快）
        while !Task.isCancelled && !coordinator.isStopped {
            do {
                try await downloadSingleChunk(size: chunkSize, coordinator: coordinator)
            } catch is CancellationError {
                break
            } catch {
                if Task.isCancelled || coordinator.isStopped { break }
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
        }
    }
    
    /// 英文模式：使用 Cloudflare 多线程下载测速（Speedtest 风格：持续下载）
    private func measureDownloadSpeedWithCloudflare() async throws -> Double {
        let concurrentStreams = 6  // 6 个并发流（参考 Speedtest）
        let chunkSize = 25_000_000  // 每个请求 25MB（增大以适应高速网络）
        let testDuration: TimeInterval = 10.0  // 测试 10 秒
        
        let coordinator = DownloadCoordinator(testDuration: testDuration)
        let testStartTime = Date()
        
        coordinator.onProgress = { [weak self] totalReceived, speed in
            Task { @MainActor in
                guard let self = self else { return }
                self.downloadSpeed = speed
            }
        }
        
        // 使用单独的 Task 来控制超时，确保严格 10 秒结束
        let downloadTask = Task {
            try await withThrowingTaskGroup(of: Void.self) { group in
                // 启动多个并发下载流
                for streamIndex in 0..<concurrentStreams {
                    group.addTask {
                        try await self.downloadStream(
                            streamIndex: streamIndex,
                            chunkSize: chunkSize,
                            testDuration: testDuration,
                            coordinator: coordinator
                        )
                    }
                }
                
                // 等待所有任务（实际上会被外部取消）
                for try await _ in group { }
            }
        }
        
        // 定时器：严格控制测试时间
        let startTime = Date()
        while Date().timeIntervalSince(startTime) < testDuration {
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            let elapsed = Date().timeIntervalSince(testStartTime)
            let timeProgress = min(elapsed / testDuration, 1.0)
            self.progress = 0.2 + (0.8 * timeProgress)
        }
        
        // 停止协调器，不再更新 UI
        coordinator.stop()
        
        // 时间到，取消下载任务
        downloadTask.cancel()
        
        // 确保进度条到达终点
        self.progress = 1.0
        
        // 计算最终速度
        let finalSpeed = coordinator.calculateFinalSpeed()
        self.downloadSpeed = finalSpeed
        return finalSpeed
    }
    
    /// 单个下载流：持续下载直到被取消（Speedtest 风格）
    private func downloadStream(streamIndex: Int, chunkSize: Int, testDuration: TimeInterval, coordinator: DownloadCoordinator) async throws {
        // 持续下载直到被取消
        while !Task.isCancelled && !coordinator.isStopped {
            do {
                try await downloadSingleChunk(size: chunkSize, coordinator: coordinator)
            } catch is CancellationError {
                // 任务被取消，正常退出
                break
            } catch {
                // 忽略单个请求的错误，继续下一个
                if Task.isCancelled || coordinator.isStopped { break }
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms 后重试
            }
        }
    }
    
    /// 下载单个数据块并报告进度
    private func downloadSingleChunk(size: Int, coordinator: DownloadCoordinator) async throws {
        guard let url = URL(string: "https://speed.cloudflare.com/__down?bytes=\(size)&r=\(UUID().uuidString)") else {
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 15  // 减少超时时间
        
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let delegate = ChunkDownloadDelegate()
                delegate.onProgress = { receivedBytes in
                    coordinator.reportProgress(bytes: receivedBytes)
                }
                
                let config = URLSessionConfiguration.default
                config.httpMaximumConnectionsPerHost = 10
                let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
                
                // 注册 session 以便停止时取消
                coordinator.registerSession(session)
                
                delegate.onComplete = { [weak session] result in
                    // 完成后注销 session
                    if let session = session {
                        coordinator.unregisterSession(session)
                    }
                    switch result {
                    case .success:
                        continuation.resume()
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
                
                let task = session.dataTask(with: request)
                delegate.session = session
                delegate.task = task
                task.resume()
            }
        } onCancel: {
            // 任务取消时不做额外处理，coordinator.stop() 会处理
        }
    }
    
    // MARK: - 上传速度测试（Speedtest 风格：持续小块上传）
    private func measureUploadSpeed() async throws -> Double {
        let testDuration: TimeInterval = 10.0  // 测试 10 秒
        let chunkSize = 2_000_000  // 每个请求 2MB（增大以适应高速网络）
        let concurrentStreams = 4  // 4 个并发流
        
        let coordinator = UploadCoordinator(testDuration: testDuration)
        let testStartTime = Date()
        
        coordinator.onProgress = { [weak self] totalSent, speed in
            Task { @MainActor in
                guard let self = self else { return }
                self.uploadSpeed = speed
            }
        }
        
        // 使用单独的 Task 来控制超时，确保严格 10 秒结束
        let uploadTask = Task {
            try await withThrowingTaskGroup(of: Void.self) { group in
                // 启动多个并发上传流
                for streamIndex in 0..<concurrentStreams {
                    group.addTask {
                        try await self.uploadStream(
                            streamIndex: streamIndex,
                            chunkSize: chunkSize,
                            testDuration: testDuration,
                            coordinator: coordinator
                        )
                    }
                }
                
                // 等待所有任务（实际上会被外部取消）
                for try await _ in group { }
            }
        }
        
        // 定时器：严格控制测试时间
        let startTime = Date()
        while Date().timeIntervalSince(startTime) < testDuration {
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            let elapsed = Date().timeIntervalSince(testStartTime)
            let timeProgress = min(elapsed / testDuration, 1.0)
            self.progress = timeProgress
        }
        
        // 时间到，取消上传任务
        // 停止协调器，不再更新 UI
        coordinator.stop()
        
        // 时间到，取消上传任务
        uploadTask.cancel()
        
        // 确保进度到 100%
        self.progress = 1.0
        
        // 计算最终速度
        let finalSpeed = coordinator.calculateFinalSpeed()
        self.uploadSpeed = finalSpeed
        return finalSpeed
    }
    
    /// 单个上传流：持续发送小块数据直到被取消
    private func uploadStream(streamIndex: Int, chunkSize: Int, testDuration: TimeInterval, coordinator: UploadCoordinator) async throws {
        guard let url = URL(string: "https://speed.cloudflare.com/__up") else {
            return
        }
        
        // 预生成随机数据（避免每次都生成）
        var randomData = Data(count: chunkSize)
        randomData.withUnsafeMutableBytes { buffer in
            _ = SecRandomCopyBytes(kSecRandomDefault, chunkSize, buffer.baseAddress!)
        }
        
        // 持续上传直到被取消
        while !Task.isCancelled && !coordinator.isStopped {
            do {
                let _ = try await uploadSingleChunk(url: url, data: randomData, coordinator: coordinator)
            } catch is CancellationError {
                // 任务被取消，正常退出
                break
            } catch {
                // 忽略单个请求的错误，继续下一个
                if Task.isCancelled || coordinator.isStopped { break }
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms 后重试
            }
        }
    }
    
    /// 上传单个数据块并报告进度
    private func uploadSingleChunk(url: URL, data: Data, coordinator: UploadCoordinator) async throws -> Int {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        
        // 使用 URLSession 的 upload 方法
        let config = URLSessionConfiguration.default
        config.httpMaximumConnectionsPerHost = 10
        
        return try await withCheckedThrowingContinuation { continuation in
            let delegate = StreamUploadDelegate()
            delegate.onProgress = { bytesSent in
                coordinator.reportProgress(bytes: Int(bytesSent))
            }
            
            let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
            
            // 注册 session 以便停止时取消
            coordinator.registerSession(session)
            
            delegate.onComplete = { [weak session] result in
                // 完成后注销 session
                if let session = session {
                    coordinator.unregisterSession(session)
                }
                switch result {
                case .success(let totalBytes):
                    continuation.resume(returning: totalBytes)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            
            let task = session.uploadTask(with: request, from: data)
            delegate.session = session
            task.resume()
        }
    }
    
    // MARK: - 常用应用延迟测试
    func startAppLatencyTest() {
        guard !isTestingAppLatency else { return }
        
        // 检查网络连接
        guard isNetworkAvailable else {
            error = LanguageManager.shared.noNetworkError
            return
        }
        
        isTestingAppLatency = true
        
        // 重置所有延迟 - 使用当前语言的应用列表
        appLatencyResults = defaultApps
        
        appLatencyTask = Task {
            // 获取所有 URL
            let apps = defaultApps
            let urls = apps.map { $0.url }
            
            // 并行测试所有应用
            await withTaskGroup(of: (Int, Double?).self) { group in
                for (index, url) in urls.enumerated() {
                    group.addTask {
                        let latency = await Self.measureAppLatency(url: url)
                        return (index, latency)
                    }
                }
                
                for await (index, latency) in group {
                    if index < appLatencyResults.count {
                        appLatencyResults[index].latency = latency
                    }
                }
            }
            
            isTestingAppLatency = false
        }
    }
    
    func stopAppLatencyTest() {
        appLatencyTask?.cancel()
        appLatencyTask = nil
        isTestingAppLatency = false
    }
    
    private static func measureAppLatency(url urlString: String) async -> Double? {
        guard let url = URL(string: urlString) else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5
        
        // 测试3次取最小值
        var latencies: [Double] = []
        for _ in 0..<3 {
            do {
                let start = Date()
                let _ = try await URLSession.shared.data(for: request)
                let elapsed = Date().timeIntervalSince(start) * 1000
                latencies.append(elapsed)
            } catch {
                continue
            }
        }
        
        return latencies.min()
    }
    
    // 计算整体网络质量
    var overallAppLatencyQuality: NetworkQuality {
        let validLatencies = appLatencyResults.compactMap { $0.latency }
        guard !validLatencies.isEmpty else { return .unknown }
        let avgLatency = validLatencies.reduce(0, +) / Double(validLatencies.count)
        if avgLatency < 50 { return .excellent }
        if avgLatency < 100 { return .good }
        if avgLatency < 200 { return .fair }
        return .poor
    }
    
    // 腾讯系/主流应用数量
    var txAppsCount: Int { txApps.count }
    
    // 第二分类应用数量
    var otherAppsCount: Int { otherApps.count }
    
    // 腾讯系/主流应用延迟结果
    var txAppLatencyResults: [AppLatencyInfo] {
        Array(appLatencyResults.prefix(txAppsCount))
    }
    
    // 其他应用延迟结果
    var otherAppLatencyResults: [AppLatencyInfo] {
        Array(appLatencyResults.dropFirst(txAppsCount).prefix(otherAppsCount))
    }
    
    // 第三分类延迟结果（仅英文）
    var thirdAppLatencyResults: [AppLatencyInfo] {
        Array(appLatencyResults.dropFirst(txAppsCount + otherAppsCount))
    }
    
    // 腾讯系/主流应用网络质量
    var txAppLatencyQuality: NetworkQuality {
        let validLatencies = txAppLatencyResults.compactMap { $0.latency }
        guard !validLatencies.isEmpty else { return .unknown }
        let avgLatency = validLatencies.reduce(0, +) / Double(validLatencies.count)
        if avgLatency < 50 { return .excellent }
        if avgLatency < 100 { return .good }
        if avgLatency < 200 { return .fair }
        return .poor
    }
    
    // 其他应用网络质量
    var otherAppLatencyQuality: NetworkQuality {
        let validLatencies = otherAppLatencyResults.compactMap { $0.latency }
        guard !validLatencies.isEmpty else { return .unknown }
        let avgLatency = validLatencies.reduce(0, +) / Double(validLatencies.count)
        if avgLatency < 50 { return .excellent }
        if avgLatency < 100 { return .good }
        if avgLatency < 200 { return .fair }
        return .poor
    }
    
    // 第三分类网络质量
    var thirdAppLatencyQuality: NetworkQuality {
        let validLatencies = thirdAppLatencyResults.compactMap { $0.latency }
        guard !validLatencies.isEmpty else { return .unknown }
        let avgLatency = validLatencies.reduce(0, +) / Double(validLatencies.count)
        if avgLatency < 50 { return .excellent }
        if avgLatency < 100 { return .good }
        if avgLatency < 200 { return .fair }
        return .poor
    }
    
    // MARK: - 语言切换时刷新应用列表
    func refreshAppListForLanguageChange() {
        if !isTestingAppLatency {
            appLatencyResults = defaultApps
        }
    }
}

// MARK: - 单个下载任务代理（高效处理大数据块）
class ChunkDownloadDelegate: NSObject, URLSessionDataDelegate {
    var session: URLSession?
    var task: URLSessionDataTask?  // 保存 task 引用以便取消
    var onProgress: ((Int) -> Void)?
    var onComplete: ((Result<Void, Error>) -> Void)?
    private var hasCompleted = false
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        // 直接报告收到的数据量，不做任何处理
        onProgress?(data.count)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard !hasCompleted else { return }
        hasCompleted = true
        
        defer {
            self.session?.invalidateAndCancel()
        }
        
        if let error = error {
            onComplete?(.failure(error))
        } else {
            onComplete?(.success(()))
        }
    }
    
    /// 取消当前任务
    func cancel() {
        guard !hasCompleted else { return }
        hasCompleted = true
        task?.cancel()
        session?.invalidateAndCancel()
        onComplete?(.failure(CancellationError()))
    }
}

// MARK: - 下载协调器（Speedtest 风格：基于时间的测试）
class DownloadCoordinator {
    let startTime: Date = Date()
    let testDuration: TimeInterval
    private var totalReceivedBytes: Int = 0
    private var lastUpdateTime: Date = Date()
    private let lock = NSLock()
    
    // 停止标志：测试结束后不再更新 UI（公开只读）
    private var _isStopped: Bool = false
    var isStopped: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isStopped
    }
    
    // 保存所有活跃的 session，以便停止时取消
    private var activeSessions: [URLSession] = []
    
    // Grace Time 配置 - 前 1.5 秒不计入速度计算（参考 Speedtest）
    private let graceTime: TimeInterval = 1.5
    private var graceTimeEnded: Bool = false
    private var bytesAtGraceEnd: Int = 0
    private var timeAtGraceEnd: Date?
    
    // 速度计算
    private var speedHistory: [(time: Date, bytes: Int)] = []
    private let windowDuration: TimeInterval = 2.0
    private let smoothingFactor: Double = 0.3
    private var smoothedSpeed: Double = 0
    
    // 采样用于最终计算
    private var speedSamples: [Double] = []
    private let sampleInterval: TimeInterval = 0.5
    private var lastSampleTime: Date?
    private var bytesAtLastSample: Int = 0
    
    var onProgress: ((Int, Double) -> Void)?
    
    init(testDuration: TimeInterval) {
        self.testDuration = testDuration
    }
    
    /// 停止协调器，不再触发 UI 更新，并取消所有网络请求
    func stop() {
        lock.lock()
        _isStopped = true
        let sessions = activeSessions
        activeSessions.removeAll()
        lock.unlock()
        
        // 取消所有活跃的网络请求
        for session in sessions {
            session.invalidateAndCancel()
        }
    }
    
    /// 注册一个活跃的 session
    func registerSession(_ session: URLSession) {
        lock.lock()
        if !_isStopped {
            activeSessions.append(session)
        } else {
            // 如果已经停止，立即取消这个 session
            session.invalidateAndCancel()
        }
        lock.unlock()
    }
    
    /// 移除一个已完成的 session
    func unregisterSession(_ session: URLSession) {
        lock.lock()
        activeSessions.removeAll { $0 === session }
        lock.unlock()
    }
    
    func reportProgress(bytes: Int) {
        lock.lock()
        if _isStopped {
            lock.unlock()
            return
        }
        totalReceivedBytes += bytes
        let currentReceived = totalReceivedBytes
        lock.unlock()
        
        let now = Date()
        let elapsed = now.timeIntervalSince(startTime)
        
        // 记录数据点
        lock.lock()
        speedHistory.append((time: now, bytes: currentReceived))
        speedHistory = speedHistory.filter { now.timeIntervalSince($0.time) <= windowDuration + 1 }
        lock.unlock()
        
        // 检查 grace time 是否结束
        if !graceTimeEnded && elapsed >= graceTime {
            graceTimeEnded = true
            timeAtGraceEnd = now
            bytesAtGraceEnd = currentReceived
            lastSampleTime = now
            bytesAtLastSample = currentReceived
        }
        
        // Grace time 结束后进行采样
        if graceTimeEnded, let lastSample = lastSampleTime {
            let timeSinceLastSample = now.timeIntervalSince(lastSample)
            if timeSinceLastSample >= sampleInterval {
                let sampleBytes = currentReceived - bytesAtLastSample
                let sampleSpeed = (Double(sampleBytes) / timeSinceLastSample * 8) / 1_000_000
                if sampleSpeed > 0 && sampleSpeed < 2000 {
                    lock.lock()
                    speedSamples.append(sampleSpeed)
                    if speedSamples.count > 30 {
                        speedSamples.removeFirst()
                    }
                    lock.unlock()
                }
                lastSampleTime = now
                bytesAtLastSample = currentReceived
            }
        }
        
        let timeSinceLastUpdate = now.timeIntervalSince(lastUpdateTime)
        
        // 每 150ms 更新一次 UI
        if timeSinceLastUpdate >= 0.15 {
            var displaySpeed: Double = 0
            
            if elapsed > 0.3 {
                // 使用滑动窗口计算速度
                let windowSpeed = calculateWindowSpeed(at: now)
                
                if windowSpeed > 0 && windowSpeed < 2000 {
                    if smoothedSpeed == 0 {
                        smoothedSpeed = windowSpeed
                    } else {
                        smoothedSpeed = smoothingFactor * windowSpeed + (1 - smoothingFactor) * smoothedSpeed
                    }
                    displaySpeed = smoothedSpeed
                }
            }
            
            onProgress?(currentReceived, displaySpeed)
            lastUpdateTime = now
        }
    }
    
    private func calculateWindowSpeed(at now: Date) -> Double {
        lock.lock()
        let history = speedHistory
        lock.unlock()
        
        let windowStart = now.addingTimeInterval(-windowDuration)
        let windowData = history.filter { $0.time >= windowStart }
        
        guard windowData.count >= 2 else {
            // 数据不足，使用总体计算
            let elapsed = now.timeIntervalSince(startTime)
            if elapsed > 0.3 && totalReceivedBytes > 0 {
                return (Double(totalReceivedBytes) / elapsed * 8) / 1_000_000
            }
            return 0
        }
        
        let earliest = windowData.first!
        let latest = windowData.last!
        
        let timeDiff = latest.time.timeIntervalSince(earliest.time)
        let bytesDiff = latest.bytes - earliest.bytes
        
        if timeDiff > 0.1 && bytesDiff > 0 {
            return (Double(bytesDiff) / timeDiff * 8) / 1_000_000
        }
        return 0
    }
    
    func calculateFinalSpeed() -> Double {
        // 优先使用 grace time 后的采样数据
        if speedSamples.count >= 5 {
            var samples = speedSamples.sorted()
            let dropCount = max(1, samples.count / 5)
            samples = Array(samples.dropFirst(dropCount).dropLast(dropCount))
            if !samples.isEmpty {
                return samples.reduce(0, +) / Double(samples.count)
            }
        } else if speedSamples.count >= 3 {
            var samples = speedSamples.sorted()
            samples.removeFirst()
            samples.removeLast()
            return samples.reduce(0, +) / Double(samples.count)
        } else if !speedSamples.isEmpty {
            return speedSamples.reduce(0, +) / Double(speedSamples.count)
        }
        
        // 备用：使用平滑速度
        if smoothedSpeed > 0 {
            return smoothedSpeed
        }
        
        // 最后备用：使用 grace time 后的总体计算
        if let graceEnd = timeAtGraceEnd {
            let stableElapsed = Date().timeIntervalSince(graceEnd)
            let stableBytes = totalReceivedBytes - bytesAtGraceEnd
            if stableElapsed > 0.1 && stableBytes > 100_000 {
                return (Double(stableBytes) / stableElapsed * 8) / 1_000_000
            }
        }
        
        return 0
    }
}

// MARK: - 上传协调器（Speedtest 风格：基于时间的测试）
class UploadCoordinator {
    let startTime: Date = Date()
    let testDuration: TimeInterval
    private var totalSentBytes: Int = 0
    private var lastUpdateTime: Date = Date()
    private let lock = NSLock()
    
    // 停止标志：测试结束后不再更新 UI（公开只读）
    private var _isStopped: Bool = false
    var isStopped: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isStopped
    }
    
    // 保存所有活跃的 session，以便停止时取消
    private var activeSessions: [URLSession] = []
    
    // 缓冲期配置 - 前 3 秒为 grace time（参考 Speedtest）
    private let graceTime: TimeInterval = 3.0
    private var graceTimeEnded: Bool = false
    private var bytesAtGraceEnd: Int = 0
    private var timeAtGraceEnd: Date?
    
    // 速度计算
    private var speedHistory: [(time: Date, bytes: Int)] = []
    private let windowDuration: TimeInterval = 2.0
    private let smoothingFactor: Double = 0.3
    private var smoothedSpeed: Double = 0
    
    // 采样用于最终计算
    private var speedSamples: [Double] = []
    private let sampleInterval: TimeInterval = 0.5
    private var lastSampleTime: Date?
    private var bytesAtLastSample: Int = 0
    
    var onProgress: ((Int, Double) -> Void)?
    
    init(testDuration: TimeInterval) {
        self.testDuration = testDuration
    }
    
    /// 停止协调器，不再触发 UI 更新，并取消所有网络请求
    func stop() {
        lock.lock()
        _isStopped = true
        let sessions = activeSessions
        activeSessions.removeAll()
        lock.unlock()
        
        // 取消所有活跃的网络请求
        for session in sessions {
            session.invalidateAndCancel()
        }
    }
    
    /// 注册一个活跃的 session
    func registerSession(_ session: URLSession) {
        lock.lock()
        if !_isStopped {
            activeSessions.append(session)
        } else {
            // 如果已经停止，立即取消这个 session
            session.invalidateAndCancel()
        }
        lock.unlock()
    }
    
    /// 移除一个已完成的 session
    func unregisterSession(_ session: URLSession) {
        lock.lock()
        activeSessions.removeAll { $0 === session }
        lock.unlock()
    }
    
    func reportProgress(bytes: Int) {
        lock.lock()
        if _isStopped {
            lock.unlock()
            return
        }
        totalSentBytes += bytes
        let currentSent = totalSentBytes
        lock.unlock()
        
        let now = Date()
        let elapsed = now.timeIntervalSince(startTime)
        
        // 记录数据点
        lock.lock()
        speedHistory.append((time: now, bytes: currentSent))
        speedHistory = speedHistory.filter { now.timeIntervalSince($0.time) <= windowDuration + 1 }
        lock.unlock()
        
        // 检查 grace time 是否结束
        if !graceTimeEnded && elapsed >= graceTime {
            graceTimeEnded = true
            timeAtGraceEnd = now
            bytesAtGraceEnd = currentSent
            lastSampleTime = now
            bytesAtLastSample = currentSent
        }
        
        // Grace time 结束后进行采样
        if graceTimeEnded, let lastSample = lastSampleTime {
            let timeSinceLastSample = now.timeIntervalSince(lastSample)
            if timeSinceLastSample >= sampleInterval {
                let sampleBytes = currentSent - bytesAtLastSample
                let sampleSpeed = (Double(sampleBytes) / timeSinceLastSample * 8) / 1_000_000
                if sampleSpeed > 0 && sampleSpeed < 1000 {
                    lock.lock()
                    speedSamples.append(sampleSpeed)
                    if speedSamples.count > 30 {
                        speedSamples.removeFirst()
                    }
                    lock.unlock()
                }
                lastSampleTime = now
                bytesAtLastSample = currentSent
            }
        }
        
        let timeSinceLastUpdate = now.timeIntervalSince(lastUpdateTime)
        
        // 每 200ms 更新一次 UI
        if timeSinceLastUpdate >= 0.2 {
            var displaySpeed: Double = 0
            
            if elapsed > 0.5 {
                // 使用滑动窗口计算速度
                let windowSpeed = calculateWindowSpeed(at: now)
                
                if windowSpeed > 0 && windowSpeed < 1000 {
                    if smoothedSpeed == 0 {
                        smoothedSpeed = windowSpeed
                    } else {
                        smoothedSpeed = smoothingFactor * windowSpeed + (1 - smoothingFactor) * smoothedSpeed
                    }
                    displaySpeed = smoothedSpeed
                }
            }
            
            onProgress?(currentSent, displaySpeed)
            lastUpdateTime = now
        }
    }
    
    private func calculateWindowSpeed(at now: Date) -> Double {
        lock.lock()
        let history = speedHistory
        lock.unlock()
        
        let windowStart = now.addingTimeInterval(-windowDuration)
        let windowData = history.filter { $0.time >= windowStart }
        
        guard windowData.count >= 2 else {
            // 数据不足，使用总体计算
            let elapsed = now.timeIntervalSince(startTime)
            if elapsed > 0.3 && totalSentBytes > 0 {
                return (Double(totalSentBytes) / elapsed * 8) / 1_000_000
            }
            return 0
        }
        
        let earliest = windowData.first!
        let latest = windowData.last!
        
        let timeDiff = latest.time.timeIntervalSince(earliest.time)
        let bytesDiff = latest.bytes - earliest.bytes
        
        if timeDiff > 0.1 && bytesDiff > 0 {
            return (Double(bytesDiff) / timeDiff * 8) / 1_000_000
        }
        return 0
    }
    
    func calculateFinalSpeed() -> Double {
        // 优先使用 grace time 后的采样数据
        if speedSamples.count >= 5 {
            var samples = speedSamples.sorted()
            let dropCount = max(1, samples.count / 5)
            samples = Array(samples.dropFirst(dropCount).dropLast(dropCount))
            if !samples.isEmpty {
                return samples.reduce(0, +) / Double(samples.count)
            }
        } else if speedSamples.count >= 3 {
            var samples = speedSamples.sorted()
            samples.removeFirst()
            samples.removeLast()
            return samples.reduce(0, +) / Double(samples.count)
        } else if !speedSamples.isEmpty {
            return speedSamples.reduce(0, +) / Double(speedSamples.count)
        }
        
        // 备用：使用平滑速度
        if smoothedSpeed > 0 {
            return smoothedSpeed
        }
        
        // 最后备用：使用 grace time 后的总体计算
        if let graceEnd = timeAtGraceEnd {
            let stableElapsed = Date().timeIntervalSince(graceEnd)
            let stableBytes = totalSentBytes - bytesAtGraceEnd
            if stableElapsed > 0.1 && stableBytes > 100_000 {
                return (Double(stableBytes) / stableElapsed * 8) / 1_000_000
            }
        }
        
        return 0
    }
}

// MARK: - 流式上传代理（单个请求）
class StreamUploadDelegate: NSObject, URLSessionTaskDelegate, URLSessionDataDelegate {
    var session: URLSession?
    var lastReportedBytes: Int64 = 0
    var onProgress: ((Int64) -> Void)?
    var onComplete: ((Result<Int, Error>) -> Void)?
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        let delta = totalBytesSent - lastReportedBytes
        if delta > 0 {
            onProgress?(delta)
            lastReportedBytes = totalBytesSent
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        defer {
            self.session?.invalidateAndCancel()
        }
        
        if let error = error {
            onComplete?(.failure(error))
            return
        }
        
        onComplete?(.success(Int(lastReportedBytes)))
    }
}
