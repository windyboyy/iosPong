//
//  IPLocationService.swift
//  Pong
//
//  Created by 张金琛 on 2025/12/23.
//

import Foundation

/// 全局 IP 归属地查询服务
/// 提供统一的 IP 归属地查询接口，支持单个和批量查询
class IPLocationService {
    static let shared = IPLocationService()
    
    // MARK: - 缓存
    
    /// IP 归属地缓存（简短描述）
    private var locationCache: [String: String] = [:]
    
    /// IP 详细信息缓存
    private var detailedCache: [String: BatchIPInfo] = [:]
    
    /// 缓存锁
    private let cacheLock = NSLock()
    
    private init() {}
    
    // MARK: - 私有/特殊 IP 识别
    
    /// 检查是否为私有或特殊 IP 地址
    /// - Parameter ip: IP 地址字符串
    /// - Returns: 是否为私有/特殊 IP
    func isPrivateIP(_ ip: String) -> Bool {
        // IPv6 本地地址
        let lowercaseIP = ip.lowercased()
        if lowercaseIP.hasPrefix("::1") ||           // IPv6 回环地址
           lowercaseIP.hasPrefix("fe80:") ||         // IPv6 链路本地地址
           lowercaseIP.hasPrefix("fc") ||            // IPv6 唯一本地地址 (ULA)
           lowercaseIP.hasPrefix("fd") {             // IPv6 唯一本地地址 (ULA)
            return true
        }
        
        // IPv4 私有地址
        if ip.hasPrefix("10.") ||                    // A 类私有地址
           ip.hasPrefix("192.168.") ||               // C 类私有地址
           ip.hasPrefix("127.") ||                   // 本地回环地址
           ip.hasPrefix("169.254.") ||               // 链路本地地址 (APIPA)
           ip == "0.0.0.0" ||                        // 无效地址
           ip == "255.255.255.255" {                 // 广播地址
            return true
        }
        
        // B 类私有地址 172.16.x.x - 172.31.x.x
        if ip.hasPrefix("172.") {
            let parts = ip.split(separator: ".")
            if parts.count >= 2, let second = Int(parts[1]) {
                if second >= 16 && second <= 31 {
                    return true
                }
            }
        }
        
        return false
    }
    
    /// 获取私有 IP 的本地化归属地描述
    /// - Parameter ip: IP 地址
    /// - Returns: 本地化的归属地描述，如果不是私有 IP 则返回 nil
    func getPrivateIPLocation(_ ip: String) -> String? {
        guard isPrivateIP(ip) else { return nil }
        return L10n.shared.localNetwork
    }
    
    /// 获取私有 IP 的本地化国家/地区描述
    /// - Parameter ip: IP 地址
    /// - Returns: 本地化的国家/地区描述，如果不是私有 IP 则返回 nil
    func getPrivateIPCountry(_ ip: String) -> String? {
        guard isPrivateIP(ip) else { return nil }
        return L10n.shared.localRegion
    }
    
    // MARK: - 缓存操作
    
    /// 从缓存获取归属地
    private func getCachedLocation(_ ip: String) -> String? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return locationCache[ip]
    }
    
    /// 缓存归属地
    private func cacheLocation(_ ip: String, location: String) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        locationCache[ip] = location
    }
    
    /// 从缓存获取详细信息
    private func getCachedDetailedInfo(_ ip: String) -> BatchIPInfo? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return detailedCache[ip]
    }
    
    /// 缓存详细信息
    private func cacheDetailedInfo(_ ip: String, info: BatchIPInfo) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        detailedCache[ip] = info
    }
    
    /// 清除所有缓存
    func clearCache() {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        locationCache.removeAll()
        detailedCache.removeAll()
    }
    
    // MARK: - 单个 IP 归属地查询
    
    /// 查询单个 IP 的归属地
    /// - Parameter ip: IP 地址
    /// - Returns: 归属地信息，查询失败返回 nil
    func fetchLocation(for ip: String) async -> String? {
        // 验证是否为有效 IP
        guard isValidIP(ip) else { return nil }
        
        // 检查是否为私有 IP（直接返回并缓存）
        if let privateLocation = getPrivateIPLocation(ip) {
            cacheLocation(ip, location: privateLocation)
            return privateLocation
        }
        
        // 检查缓存
        if let cached = getCachedLocation(ip) {
            return cached
        }
        
        do {
            let result = try await IPInfoManager.shared.fetchBatchIPInfo(ipList: [ip])
            if let location = result[ip]?.shortLocation {
                cacheLocation(ip, location: location)
                return location
            }
            return nil
        } catch {
            print("IP 归属地查询失败: \(error)")
            return nil
        }
    }
    
    // MARK: - 批量 IP 归属地查询
    
    /// 批量查询 IP 归属地
    /// - Parameter ips: IP 地址列表
    /// - Returns: IP 到归属地的映射字典
    func fetchLocations(for ips: [String]) async -> [String: String] {
        // 过滤有效 IP
        let validIPs = ips.filter { isValidIP($0) }
        guard !validIPs.isEmpty else { return [:] }
        
        // 去重
        let uniqueIPs = Array(Set(validIPs))
        
        // 分离私有 IP、已缓存 IP 和需要查询的公网 IP
        var locations: [String: String] = [:]
        var publicIPs: [String] = []
        
        for ip in uniqueIPs {
            if let privateLocation = getPrivateIPLocation(ip) {
                // 私有 IP：直接返回并缓存
                locations[ip] = privateLocation
                cacheLocation(ip, location: privateLocation)
            } else if let cached = getCachedLocation(ip) {
                // 已缓存：直接使用
                locations[ip] = cached
            } else {
                // 需要查询
                publicIPs.append(ip)
            }
        }
        
        // 查询公网 IP
        if !publicIPs.isEmpty {
            do {
                let result = try await IPInfoManager.shared.fetchBatchIPInfo(ipList: publicIPs)
                for (ip, info) in result {
                    let location = info.shortLocation
                    locations[ip] = location
                    cacheLocation(ip, location: location)
                }
            } catch {
                print("批量 IP 归属地查询失败: \(error)")
            }
        }
        
        return locations
    }
    
    /// 批量查询 IP 归属地（返回完整信息）
    /// - Parameter ips: IP 地址列表
    /// - Returns: IP 到详细信息的映射字典
    func fetchDetailedLocations(for ips: [String]) async -> [String: BatchIPInfo] {
        // 过滤有效 IP
        let validIPs = ips.filter { isValidIP($0) }
        guard !validIPs.isEmpty else { return [:] }
        
        // 去重
        let uniqueIPs = Array(Set(validIPs))
        
        // 分离私有 IP、已缓存 IP 和需要查询的公网 IP
        var result: [String: BatchIPInfo] = [:]
        var publicIPs: [String] = []
        
        for ip in uniqueIPs {
            if isPrivateIP(ip) {
                // 私有 IP：创建本地化的 BatchIPInfo 并缓存
                let info = BatchIPInfo.createPrivateIPInfo(ip: ip)
                result[ip] = info
                cacheDetailedInfo(ip, info: info)
            } else if let cached = getCachedDetailedInfo(ip) {
                // 已缓存：直接使用
                result[ip] = cached
            } else {
                // 需要查询
                publicIPs.append(ip)
            }
        }
        
        // 查询公网 IP
        if !publicIPs.isEmpty {
            do {
                let apiResult = try await IPInfoManager.shared.fetchBatchIPInfo(ipList: publicIPs)
                for (ip, info) in apiResult {
                    result[ip] = info
                    cacheDetailedInfo(ip, info: info)
                }
            } catch {
                print("批量 IP 归属地查询失败: \(error)")
            }
        }
        
        return result
    }
    
    // MARK: - IP 验证
    
    /// 验证是否为有效的 IPv4 或 IPv6 地址
    /// - Parameter ip: IP 地址字符串
    /// - Returns: 是否有效
    func isValidIP(_ ip: String) -> Bool {
        return isValidIPv4(ip) || isValidIPv6(ip)
    }
    
    /// 验证是否为有效的 IPv4 地址
    func isValidIPv4(_ ip: String) -> Bool {
        // 使用 split 时保留空字符串以检测连续的点（如 "1..2.3"）
        let parts = ip.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return false }
        
        for part in parts {
            let partStr = String(part)
            
            // 检查是否为空
            guard !partStr.isEmpty else { return false }
            
            // 检查是否只包含数字
            guard partStr.allSatisfy({ $0.isNumber }) else { return false }
            
            // 检查前导零（"0" 本身是允许的，但 "01"、"001" 等不允许）
            if partStr.count > 1 && partStr.hasPrefix("0") {
                return false
            }
            
            // 检查数值范围
            guard let num = Int(partStr), num >= 0, num <= 255 else {
                return false
            }
        }
        return true
    }
    
    /// 验证是否为有效的 IPv6 地址
    func isValidIPv6(_ ip: String) -> Bool {
        // 简单验证：包含冒号且不包含非法字符
        guard ip.contains(":") else { return false }
        
        let allowedChars = CharacterSet(charactersIn: "0123456789abcdefABCDEF:")
        return ip.unicodeScalars.allSatisfy { allowedChars.contains($0) }
    }
    
    /// 从字符串中提取 IP 地址
    /// - Parameter value: 可能包含 IP 的字符串
    /// - Returns: 提取到的 IP 地址，如果没有则返回 nil
    func extractIP(from value: String) -> String? {
        // 尝试直接验证
        if isValidIP(value) {
            return value
        }
        
        // IPv4 正则
        let ipv4Pattern = #"(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})"#
        if let range = value.range(of: ipv4Pattern, options: .regularExpression) {
            let ip = String(value[range])
            if isValidIPv4(ip) {
                return ip
            }
        }
        
        // IPv6 正则（简化版）
        let ipv6Pattern = #"([0-9a-fA-F:]+:[0-9a-fA-F:]+)"#
        if let range = value.range(of: ipv6Pattern, options: .regularExpression) {
            let ip = String(value[range])
            if isValidIPv6(ip) {
                return ip
            }
        }
        
        return nil
    }
}
