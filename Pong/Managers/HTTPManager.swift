//
//  HTTPManager.swift
//  Pong
//
//  Created by Claude on 2025/12/19.
//

import Foundation
internal import Combine

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
    
    var isSuccess: Bool {
        guard let code = statusCode else { return false }
        return code >= 200 && code < 300
    }
}

@MainActor
class HTTPManager: ObservableObject {
    static let shared = HTTPManager()
    
    @Published var isLoading = false
    @Published var result: HTTPResult?
    @Published var currentURL = ""
    
    private var currentTask: URLSessionDataTask?
    
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
                timestamp: Date()
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
                timestamp: Date()
            )
            return
        }
        
        isLoading = true
        result = nil
        
        let startTime = Date()
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout
        
        currentTask = URLSession.shared.dataTask(with: request) { [weak self] data, urlResponse, error in
            let responseTime = Date().timeIntervalSince(startTime)
            
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
                        responseTime: responseTime,
                        error: error.localizedDescription,
                        timestamp: Date()
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
                        responseTime: responseTime,
                        error: "无法解析响应",
                        timestamp: Date()
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
                    responseTime: responseTime,
                    error: nil,
                    timestamp: Date()
                )
                self.result = httpResult
                self.saveToHistory(result: httpResult)
            }
        }
        
        currentTask?.resume()
    }
    
    func stop() {
        currentTask?.cancel()
        currentTask = nil
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
