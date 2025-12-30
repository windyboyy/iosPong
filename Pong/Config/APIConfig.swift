//
//  APIConfig.swift
//  Pong
//
//  Created by 张金琛 on 2025/12/24.
//

import Foundation

/// API 配置
/// 集中管理 SystemId 和 SecretKey 等敏感配置
struct APIConfig {
    
    // MARK: - 默认配置
    
    /// 默认系统 ID
    static let systemId = "4"
    
    /// 默认系统 ID（整数类型）
    static let systemIdInt = 4
    
    /// 默认签名密钥（十六进制字符串）
    static let secretKey = "b5df1b887f2a16077f0083556fde647552cc8d0f777233681ddc69bcc534cd77"
    
    // MARK: - 认证配置
    
    /// 获取默认的 API 认证配置
    static var defaultAuth: AuthConfig {
        return AuthConfig(
            systemId: systemId,
            secretKey: secretKey,
            useHmacSha512: true
        )
    }
    
    // MARK: - API 端点
    
    /// iTango API 地址（需要签名认证）
    static let apiURL = "https://api.itango.tencent.com/api"
    
    /// iTango 基础地址（登录、验证码等）
    static let baseURL = "https://itango.tencent.com"
}
