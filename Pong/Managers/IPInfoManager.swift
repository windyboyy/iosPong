//
//  IPInfoManager.swift
//  Pong
//
//  Created by 张金琛 on 2025/12/27.
//

import Foundation

// MARK: - IP 信息管理器
class IPInfoManager {
    static let shared = IPInfoManager()
    
    private init() {}
    
    // MARK: - 获取当前设备 IP 归属地信息
    func fetchIPInfo() async throws -> IPInfoResponse {
        let url = URL(string: "https://mail.163.com/fgw/mailsrv-ipdetail/detail")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(NetEaseIPResponse.self, from: data)
        
        // 根据 code 判断接口是否调用成功
        guard apiResponse.code == 200, let result = apiResponse.result else {
            throw NetworkError.invalidResponse
        }
        
        return IPInfoResponse(
            ip: result.ip,
            country: result.country,
            province: result.province,
            city: result.city,
            region: nil,
            isp: result.isp,
            address: nil,
            latitude: Double(result.latitude ?? ""),
            longitude: Double(result.longitude ?? ""),
            asId: nil,
            backboneISP: nil,
            createTime: nil,
            id: nil
        )
    }
    
    // MARK: - 批量获取 IP 归属地信息（使用 Bilibili API 并发查询）
    func fetchBatchIPInfo(ipList: [String]) async throws -> [String: BatchIPInfo] {
        // 并发查询所有 IP
        return await withTaskGroup(of: (String, BatchIPInfo?).self) { group in
            for ip in ipList {
                group.addTask {
                    do {
                        let info = try await self.fetchSingleIPInfo(ip: ip)
                        return (ip, info)
                    } catch {
                        print("查询 IP \(ip) 失败: \(error)")
                        return (ip, nil)
                    }
                }
            }
            
            var result: [String: BatchIPInfo] = [:]
            for await (ip, info) in group {
                if let info = info {
                    result[ip] = info
                }
            }
            return result
        }
    }
    
    // MARK: - 查询单个 IP 归属地（使用 Bilibili API + ipinfo.io 获取 AS 号）
    private func fetchSingleIPInfo(ip: String) async throws -> BatchIPInfo {
        // 并发查询 Bilibili API 和 ipinfo.io
        async let bilibiliResult = fetchBilibiliIPInfo(ip: ip)
        async let asnResult = fetchASN(ip: ip)
        
        let (bilibiliInfo, asn) = await (bilibiliResult, asnResult)
        
        // 如果 Bilibili API 查询失败
        guard let info = bilibiliInfo else {
            return BatchIPInfo(
                Id: nil,
                IP: ip,
                Country: L10n.shared.fetchFailed,
                Province: nil,
                City: nil,
                Region: nil,
                Address: L10n.shared.fetchFailed,
                FrontISP: nil,
                BackboneISP: nil,
                AsId: nil,
                Latitude: nil,
                Longitude: nil,
                CreateTime: nil,
                isPrivate: false
            )
        }
        
        return BatchIPInfo(
            Id: nil,
            IP: info.addr,
            Country: info.country,
            Province: info.province,
            City: info.city,
            Region: nil,
            Address: nil,
            FrontISP: info.isp,
            BackboneISP: nil,
            AsId: asn,
            Latitude: Double(info.latitude ?? ""),
            Longitude: Double(info.longitude ?? ""),
            CreateTime: nil,
            isPrivate: false
        )
    }
    
    // MARK: - 查询 Bilibili IP 信息
    private func fetchBilibiliIPInfo(ip: String) async -> BilibiliIPData? {
        let urlString = "https://api.live.bilibili.com/client/v1/Ip/getInfoNew?ip=\(ip)"
        guard let url = URL(string: urlString) else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoder = JSONDecoder()
            let apiResponse = try decoder.decode(BilibiliIPResponse.self, from: data)
            
            guard apiResponse.code == 0 else { return nil }
            return apiResponse.data
        } catch {
            print("Bilibili IP 查询失败: \(error)")
            return nil
        }
    }
    
    // MARK: - 查询 AS 号（使用 ipinfo.io）
    private func fetchASN(ip: String) async -> Int? {
        let urlString = "https://api.ipinfo.io/lite/\(ip)?token=29b9fbba715064"
        guard let url = URL(string: urlString) else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoder = JSONDecoder()
            let apiResponse = try decoder.decode(IPInfoASNResponse.self, from: data)
            
            // 解析 ASN，格式为 "AS4134"
            if let asnString = apiResponse.asn, asnString.hasPrefix("AS") {
                let numberString = String(asnString.dropFirst(2))
                return Int(numberString)
            }
            return nil
        } catch {
            print("ASN 查询失败: \(error)")
            return nil
        }
    }
}

// MARK: - 163 邮箱 IP 查询 API 响应模型
private struct NetEaseIPResponse: Codable {
    let code: Int?
    let desc: String?
    let success: String?
    let result: NetEaseIPResult?
}

private struct NetEaseIPResult: Codable {
    let ip: String?
    let country: String?
    let province: String?
    let provinceEn: String?
    let city: String?
    let org: String?
    let isp: String?
    let latitude: String?
    let longitude: String?
    let timezone: String?
    let countryCode: String?
    let continentCode: String?
    let provinceCode: String?
    let continent: String?
    let county: String?
    let ispId: String?
    let zone: String?
}

// MARK: - Bilibili IP 查询 API 响应模型
private struct BilibiliIPResponse: Codable {
    let code: Int?
    let msg: String?
    let message: String?
    let data: BilibiliIPData?
}

private struct BilibiliIPData: Codable {
    let addr: String?
    let country: String?
    let province: String?
    let city: String?
    let isp: String?
    let latitude: String?
    let longitude: String?
}

// MARK: - ipinfo.io ASN 查询 API 响应模型
private struct IPInfoASNResponse: Codable {
    let ip: String?
    let asn: String?
    let as_name: String?
    let as_domain: String?
    let country_code: String?
    let country: String?
    let continent_code: String?
    let continent: String?
}

// MARK: - IP 信息响应模型（对外使用）
struct IPInfoResponse {
    let ip: String?
    let country: String?
    let province: String?
    let city: String?
    let region: String?
    let isp: String?
    let address: String?
    let latitude: Double?
    let longitude: Double?
    let asId: Int?
    let backboneISP: String?
    let createTime: String?
    let id: Int?
    
    // 获取完整的归属地描述
    var fullLocation: String {
        if let address = address, !address.isEmpty {
            return address
        }
        var parts: [String] = []
        if let country = country, !country.isEmpty { parts.append(country) }
        if let province = province, !province.isEmpty { parts.append(province) }
        if let city = city, !city.isEmpty { parts.append(city) }
        if let region = region, !region.isEmpty { parts.append(region) }
        return parts.isEmpty ? "未知" : parts.joined()
    }
    
    // 获取本地化的归属地描述（英文时转拼音）
    func localizedLocation(_ l10n: L10n) -> String {
        let isEnglish = LanguageManager.shared.currentLanguage == .english
        
        if isEnglish {
            var parts: [String] = []
            if let country = country, !country.isEmpty {
                parts.append(country.toPinyin())
            }
            if let province = province, !province.isEmpty {
                parts.append(province.toPinyin())
            }
            if let city = city, !city.isEmpty {
                parts.append(city.toPinyin())
            }
            if let region = region, !region.isEmpty {
                parts.append(region.toPinyin())
            }
            return parts.isEmpty ? l10n.unknown : parts.joined(separator: " ")
        } else {
            return fullLocation
        }
    }
    
    // 获取本地化的运营商名称（英文时翻译）
    func localizedISP(_ l10n: L10n) -> String? {
        guard let isp = isp, !isp.isEmpty else { return nil }
        
        let isEnglish = LanguageManager.shared.currentLanguage == .english
        if isEnglish {
            return isp.toEnglishISP()
        }
        return isp
    }
}

// MARK: - 单个 IP 详细信息
struct BatchIPInfo: Decodable {
    let Id: Int?
    let IP: String?
    let Country: String?
    let Province: String?
    let City: String?
    let Region: String?
    let Address: String?
    let FrontISP: String?
    let BackboneISP: String?
    let AsId: Int?
    let Latitude: Double?
    let Longitude: Double?
    let CreateTime: String?
    
    // 标记是否为私有 IP（不从 API 解码）
    var isPrivate: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case Id, IP, Country, Province, City, Region, Address, FrontISP, BackboneISP, AsId, Latitude, Longitude, CreateTime
    }
    
    /// 为私有 IP 创建本地化的 BatchIPInfo
    static func createPrivateIPInfo(ip: String) -> BatchIPInfo {
        let l10n = L10n.shared
        return BatchIPInfo(
            Id: nil,
            IP: ip,
            Country: l10n.localRegion,
            Province: nil,
            City: nil,
            Region: nil,
            Address: l10n.localNetwork,
            FrontISP: nil,
            BackboneISP: nil,
            AsId: nil,
            Latitude: nil,
            Longitude: nil,
            CreateTime: nil,
            isPrivate: true
        )
    }
    
    // 获取完整的归属地描述
    var fullLocation: String {
        // 私有 IP 直接返回本地化的地址
        if isPrivate {
            return Address ?? L10n.shared.localNetwork
        }
        
        if let address = Address, !address.isEmpty {
            return address
        }
        var parts: [String] = []
        if let country = Country, !country.isEmpty { parts.append(country) }
        if let province = Province, !province.isEmpty { parts.append(province) }
        if let city = City, !city.isEmpty { parts.append(city) }
        if let isp = FrontISP, !isp.isEmpty { parts.append(isp) }
        return parts.isEmpty ? "未知" : parts.joined(separator: " ")
    }
    
    // 获取简短的归属地描述
    // 中国：Province + FrontISP
    // 海外：Address + FrontISP
    var shortLocation: String {
        // 私有 IP 直接返回本地化的地址
        if isPrivate {
            return Address ?? L10n.shared.localNetwork
        }
        
        var parts: [String] = []
        
        // 判断是否为中国
        let isChina = Country == "中国" || Country == "China" || Country == "CN"
        
        if isChina {
            // 中国：显示省份
            if let province = Province, !province.isEmpty {
                parts.append(province)
            }
        } else {
            // 海外：显示 Address（通常是国家+地区）
            if let address = Address, !address.isEmpty {
                parts.append(address)
            } else if let country = Country, !country.isEmpty {
                parts.append(country)
            }
        }
        
        // 添加运营商
        if let isp = FrontISP, !isp.isEmpty {
            parts.append(isp)
        }
        
        return parts.isEmpty ? "未知" : parts.joined(separator: " ")
    }
}
