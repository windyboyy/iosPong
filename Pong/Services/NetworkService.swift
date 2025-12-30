//
//  NetworkService.swift
//  Pong
//
//  Created by 张金琛 on 2025/12/14.
//

import Foundation
import CommonCrypto

// MARK: - HTTP 请求方法
enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
}

// MARK: - 鉴权配置
struct AuthConfig {
    let systemId: String
    let secretKey: String  // 十六进制字符串
    let useHmacSha512: Bool
    
    init(systemId: String, secretKey: String, useHmacSha512: Bool = true) {
        self.systemId = systemId
        self.secretKey = secretKey
        self.useHmacSha512 = useHmacSha512
    }
}

// MARK: - 网络服务层
class NetworkService {
    static let shared = NetworkService()
    
    private let session: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - 通用 GET 请求
    /// - Parameters:
    ///   - url: 请求 URL
    ///   - headers: 额外的请求头
    ///   - auth: 鉴权配置（可选）
    /// - Returns: 响应数据
    func get(
        url: String,
        headers: [String: String]? = nil,
        auth: AuthConfig? = nil
    ) async throws -> Data {
        return try await request(
            url: url,
            method: .GET,
            body: nil,
            headers: headers,
            auth: auth
        )
    }
    
    /// 通用 GET 请求（泛型版本，自动解码）
    func get<T: Decodable>(
        url: String,
        headers: [String: String]? = nil,
        auth: AuthConfig? = nil,
        decoder: JSONDecoder = JSONDecoder()
    ) async throws -> T {
        let data = try await get(url: url, headers: headers, auth: auth)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingError(error)
        }
    }
    
    // MARK: - 通用 POST 请求
    /// - Parameters:
    ///   - url: 请求 URL
    ///   - body: 请求体数据
    ///   - headers: 额外的请求头
    ///   - auth: 鉴权配置（可选）
    /// - Returns: 响应数据
    func post(
        url: String,
        body: Data?,
        headers: [String: String]? = nil,
        auth: AuthConfig? = nil
    ) async throws -> Data {
        return try await request(
            url: url,
            method: .POST,
            body: body,
            headers: headers,
            auth: auth
        )
    }
    
    /// 通用 POST 请求（JSON 编码版本）
    func post<T: Encodable>(
        url: String,
        json: T,
        headers: [String: String]? = nil,
        auth: AuthConfig? = nil,
        encoder: JSONEncoder = JSONEncoder()
    ) async throws -> Data {
        let body = try encoder.encode(json)
        var allHeaders = headers ?? [:]
        allHeaders["Content-Type"] = "application/json"
        return try await post(url: url, body: body, headers: allHeaders, auth: auth)
    }
    
    /// 通用 POST 请求（泛型版本，自动编解码）
    func post<T: Encodable, R: Decodable>(
        url: String,
        json: T,
        headers: [String: String]? = nil,
        auth: AuthConfig? = nil,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) async throws -> R {
        let data = try await post(url: url, json: json, headers: headers, auth: auth, encoder: encoder)
        do {
            return try decoder.decode(R.self, from: data)
        } catch {
            throw NetworkError.decodingError(error)
        }
    }
    
    // MARK: - 底层请求方法
    private func request(
        url: String,
        method: HTTPMethod,
        body: Data?,
        headers: [String: String]?,
        auth: AuthConfig?
    ) async throws -> Data {
        guard let requestURL = URL(string: url) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: requestURL)
        request.httpMethod = method.rawValue
        request.httpBody = body
        
        // 添加自定义请求头
        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // 添加鉴权头
        if let auth = auth {
            let bodyString = body.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            let authHeader = makeAuthorization(
                systemId: auth.systemId,
                secretKey: auth.secretKey,
                requestBodyData: bodyString,
                isHmacSha512: auth.useHmacSha512
            )
            request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw NetworkError.httpError(httpResponse.statusCode)
            }
            
            return data
        } catch let error as NetworkError {
            throw error
        } catch {
            throw NetworkError.networkError(error)
        }
    }
    
    // MARK: - 生成鉴权头
    /// 生成签名头部，支持 HMAC-SHA-256 / HMAC-SHA-512 两种签名算法
    /// - Parameters:
    ///   - systemId: 系统 ID
    ///   - secretKey: 签名密钥（十六进制字符串）
    ///   - requestBodyData: 请求体数据
    ///   - isHmacSha512: true 使用 HMAC-SHA-512，false 使用 HMAC-SHA-256
    /// - Returns: Authorization 头的值
    private func makeAuthorization(
        systemId: String,
        secretKey: String,
        requestBodyData: String,
        isHmacSha512: Bool = true
    ) -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        
        // 拼装需要参与签名的数据
        let strToSign = "\(timestamp)\(requestBodyData)"
        
        // 将十六进制密钥转换为 Data
        let keyData = Data(hexString: secretKey) ?? Data()
        
        // 计算 HMAC 签名
        let signature: String
        let algoName: String
        
        if isHmacSha512 {
            algoName = "HMAC-SHA-512"
            signature = hmacSHA512(key: keyData, data: strToSign)
        } else {
            algoName = "HMAC-SHA-256"
            signature = hmacSHA256(key: keyData, data: strToSign)
        }
        
        return "\(algoName) Timestamp=\(timestamp),Signature=\(signature),SystemId=\(systemId)"
    }
    
    // MARK: - HMAC-SHA-512
    private func hmacSHA512(key: Data, data: String) -> String {
        let dataBytes = data.data(using: .utf8)!
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA512_DIGEST_LENGTH))
        
        key.withUnsafeBytes { keyPtr in
            dataBytes.withUnsafeBytes { dataPtr in
                CCHmac(
                    CCHmacAlgorithm(kCCHmacAlgSHA512),
                    keyPtr.baseAddress,
                    key.count,
                    dataPtr.baseAddress,
                    dataBytes.count,
                    &digest
                )
            }
        }
        
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - HMAC-SHA-256
    private func hmacSHA256(key: Data, data: String) -> String {
        let dataBytes = data.data(using: .utf8)!
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        
        key.withUnsafeBytes { keyPtr in
            dataBytes.withUnsafeBytes { dataPtr in
                CCHmac(
                    CCHmacAlgorithm(kCCHmacAlgSHA256),
                    keyPtr.baseAddress,
                    key.count,
                    dataPtr.baseAddress,
                    dataBytes.count,
                    &digest
                )
            }
        }
        
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Data 十六进制扩展
extension Data {
    init?(hexString: String) {
        let len = hexString.count / 2
        var data = Data(capacity: len)
        var index = hexString.startIndex
        
        for _ in 0..<len {
            let nextIndex = hexString.index(index, offsetBy: 2)
            guard let byte = UInt8(hexString[index..<nextIndex], radix: 16) else {
                return nil
            }
            data.append(byte)
            index = nextIndex
        }
        
        self = data
    }
    
    var hexString: String {
        return map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - 网络错误
enum NetworkError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingError(Error)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的 URL"
        case .invalidResponse:
            return "无效的响应"
        case .httpError(let code):
            return "HTTP 错误: \(code)"
        case .decodingError(let error):
            return "解析错误: \(error.localizedDescription)"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        }
    }
}

// MARK: - 中文转拼音扩展
extension String {
    /// 将中文转换为拼音（首字母大写）
    func toPinyin() -> String {
        let mutableString = NSMutableString(string: self)
        CFStringTransform(mutableString, nil, kCFStringTransformToLatin, false)
        CFStringTransform(mutableString, nil, kCFStringTransformStripDiacritics, false)
        
        // 首字母大写处理
        let words = (mutableString as String).components(separatedBy: " ")
        let capitalizedWords = words.map { $0.capitalized }
        return capitalizedWords.joined(separator: " ")
    }
    
    /// 将中文运营商名称转换为英文
    func toEnglishISP() -> String {
        return LocalizationMapping.toEnglishISP(self)
    }
    
    /// 将中文国家名称转换为英文
    func toEnglishCountry() -> String {
        return LocalizationMapping.toEnglishCountry(self)
    }
}
