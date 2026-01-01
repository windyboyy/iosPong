//
//  HTTPManager.swift
//  Pong
//
//  Created by Claude on 2025/12/19.
//

import Foundation
internal import Combine

// MARK: - HTTP 请求各阶段耗时
struct HTTPTimingMetrics {
    var dnsLookup: TimeInterval = 0        // DNS 解析
    var tcpConnection: TimeInterval = 0    // TCP 连接
    var tlsHandshake: TimeInterval = 0     // TLS 握手
    var requestSent: TimeInterval = 0      // 请求发送
    var serverResponse: TimeInterval = 0   // 服务器响应 (TTFB)
    var contentDownload: TimeInterval = 0  // 内容下载
    var total: TimeInterval = 0            // 总耗时
    
    var hasData: Bool {
        total > 0
    }
}

// MARK: - HTTP 响应结果
struct HTTPResult: Identifiable {
    let id = UUID()
    let url: String
    let statusCode: Int?
    let statusMessage: String
    let headers: [String: String]
    let body: String
    let responseTime: TimeInterval
    let error: String?
    let timestamp: Date
    var timing: HTTPTimingMetrics
    
    var isSuccess: Bool {
        guard let code = statusCode else { return false }
        return code >= 200 && code < 300
    }
}

// MARK: - URLSession Delegate 用于获取 Metrics
private class HTTPSessionDelegate: NSObject, URLSessionTaskDelegate {
    var metricsHandler: ((URLSessionTaskMetrics) -> Void)?
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        metricsHandler?(metrics)
    }
}

@MainActor
class HTTPManager: ObservableObject {
    static let shared = HTTPManager()
    
    @Published var isLoading = false
    @Published var result: HTTPResult?
    @Published var currentURL = ""
    
    private var currentTask: URLSessionDataTask?
    private var sessionDelegate: HTTPSessionDelegate?
    private var currentSession: URLSession?
    
    private init() {}
    
    // MARK: - 网络状态检查
    
    /// 检查当前是否有网络连接
    /// 注意：如果状态是 unknown，我们假设网络可用（让实际的网络操作来判断）
    var isNetworkAvailable: Bool {
        let status = DeviceInfoManager.shared.networkStatus
        return status != .disconnected
    }
    
    func sendGetRequest(urlString: String, timeout: TimeInterval = 30) {
        // 停止之前的请求
        stop()
        
        // 自动补全 https://
        var finalURL = urlString
        if !finalURL.hasPrefix("http://") && !finalURL.hasPrefix("https://") {
            finalURL = "https://" + finalURL
        }
        
        currentURL = finalURL
        
        // 检查网络连接
        guard isNetworkAvailable else {
            let httpResult = HTTPResult(
                url: finalURL,
                statusCode: nil,
                statusMessage: "无网络连接",
                headers: [:],
                body: "",
                responseTime: 0,
                error: "无网络连接，请检查网络设置后重试",
                timestamp: Date(),
                timing: HTTPTimingMetrics()
            )
            result = httpResult
            saveToHistory(result: httpResult)
            return
        }
        
        guard let url = URL(string: finalURL) else {
            result = HTTPResult(
                url: finalURL,
                statusCode: nil,
                statusMessage: "无效的 URL",
                headers: [:],
                body: "",
                responseTime: 0,
                error: "URL 格式不正确",
                timestamp: Date(),
                timing: HTTPTimingMetrics()
            )
            return
        }
        
        isLoading = true
        result = nil
        
        let startTime = Date()
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout
        
        // 创建带 delegate 的 session 以获取 metrics
        let delegate = HTTPSessionDelegate()
        self.sessionDelegate = delegate
        
        var collectedMetrics: URLSessionTaskMetrics?
        delegate.metricsHandler = { metrics in
            collectedMetrics = metrics
        }
        
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        self.currentSession = session
        
        currentTask = session.dataTask(with: request) { [weak self] data, urlResponse, error in
            let responseTime = Date().timeIntervalSince(startTime)
            
            // 解析 timing metrics
            let timing = self?.parseMetrics(collectedMetrics) ?? HTTPTimingMetrics()
            // 优先使用 metrics 的精确时间，否则使用手动计算的时间
            let finalResponseTime = timing.total > 0 ? timing.total : responseTime
            
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoading = false
                self.currentTask = nil
                
                if let error = error {
                    let httpResult = HTTPResult(
                        url: finalURL,
                        statusCode: nil,
                        statusMessage: "请求失败",
                        headers: [:],
                        body: "",
                        responseTime: finalResponseTime,
                        error: error.localizedDescription,
                        timestamp: Date(),
                        timing: timing
                    )
                    self.result = httpResult
                    self.saveToHistory(result: httpResult)
                    return
                }
                
                guard let httpResponse = urlResponse as? HTTPURLResponse else {
                    let httpResult = HTTPResult(
                        url: finalURL,
                        statusCode: nil,
                        statusMessage: "无效响应",
                        headers: [:],
                        body: "",
                        responseTime: finalResponseTime,
                        error: "无法解析响应",
                        timestamp: Date(),
                        timing: timing
                    )
                    self.result = httpResult
                    self.saveToHistory(result: httpResult)
                    return
                }
                
                // 转换 headers
                var headers: [String: String] = [:]
                for (key, value) in httpResponse.allHeaderFields {
                    headers[String(describing: key)] = String(describing: value)
                }
                
                // 解析 body
                var bodyString = ""
                if let data = data {
                    bodyString = String(data: data, encoding: .utf8) ?? "无法解码响应体"
                    // 限制显示长度
                    if bodyString.count > 10000 {
                        bodyString = String(bodyString.prefix(10000)) + "\n... (内容过长，已截断)"
                    }
                }
                
                let httpResult = HTTPResult(
                    url: finalURL,
                    statusCode: httpResponse.statusCode,
                    statusMessage: HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode),
                    headers: headers,
                    body: bodyString,
                    responseTime: finalResponseTime,
                    error: nil,
                    timestamp: Date(),
                    timing: timing
                )
                self.result = httpResult
                self.saveToHistory(result: httpResult)
            }
        }
        
        currentTask?.resume()
    }
    
    // 解析 URLSessionTaskMetrics 获取各阶段耗时
    private nonisolated func parseMetrics(_ metrics: URLSessionTaskMetrics?) -> HTTPTimingMetrics {
        guard let metrics = metrics,
              let transaction = metrics.transactionMetrics.last else {
            return HTTPTimingMetrics()
        }
        
        var timing = HTTPTimingMetrics()
        
        // DNS 解析时间
        if let start = transaction.domainLookupStartDate,
           let end = transaction.domainLookupEndDate {
            timing.dnsLookup = end.timeIntervalSince(start)
        }
        
        // TCP 连接时间
        if let start = transaction.connectStartDate,
           let end = transaction.connectEndDate {
            timing.tcpConnection = end.timeIntervalSince(start)
            
            // TLS 握手时间（包含在连接时间内）
            if let secureStart = transaction.secureConnectionStartDate,
               let secureEnd = transaction.secureConnectionEndDate {
                timing.tlsHandshake = secureEnd.timeIntervalSince(secureStart)
                // TCP 连接时间需要减去 TLS 时间
                timing.tcpConnection = timing.tcpConnection - timing.tlsHandshake
            }
        }
        
        // 请求发送时间
        if let start = transaction.requestStartDate,
           let end = transaction.requestEndDate {
            timing.requestSent = end.timeIntervalSince(start)
        }
        
        // 服务器响应时间 (TTFB - Time To First Byte)
        if let requestEnd = transaction.requestEndDate,
           let responseStart = transaction.responseStartDate {
            timing.serverResponse = responseStart.timeIntervalSince(requestEnd)
        }
        
        // 内容下载时间
        if let start = transaction.responseStartDate,
           let end = transaction.responseEndDate {
            timing.contentDownload = end.timeIntervalSince(start)
        }
        
        // 总耗时
        if let start = transaction.fetchStartDate,
           let end = transaction.responseEndDate {
            timing.total = end.timeIntervalSince(start)
        }
        
        return timing
    }
    
    func stop() {
        currentTask?.cancel()
        currentTask = nil
        currentSession?.invalidateAndCancel()
        currentSession = nil
        sessionDelegate = nil
        isLoading = false
    }
    
    private func saveToHistory(result: HTTPResult) {
        let status: TaskStatus = result.isSuccess ? .success : .failure
        
        TaskHistoryManager.shared.addHTTPRecord(
            url: result.url,
            status: status,
            statusCode: result.statusCode,
            responseTime: result.responseTime * 1000,
            error: result.error
        )
    }
    
    // 常用 URL 列表
    static let commonURLs: [(String, String)] = [
        ("QQ", "https://www.qq.com"),
        ("Baidu", "https://www.baidu.com"),
        ("Google", "https://www.google.com"),
        ("GitHub", "https://api.github.com"),
        ("httpbin", "https://httpbin.org/get")
    ]
}
