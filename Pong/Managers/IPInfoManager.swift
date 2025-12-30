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
        let data = try await NetworkService.shared.get(url: "\(APIConfig.baseURL)/out/itango/myip")
        
        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(MyIPAPIResponse.self, from: data)
        
        guard let asnInfo = apiResponse.data?.asnInfo else {
            throw NetworkError.invalidResponse
        }
        
        return IPInfoResponse(
            ip: asnInfo.ip,
            country: asnInfo.country,
            province: asnInfo.province,
            city: asnInfo.city,
            region: asnInfo.region,
            isp: asnInfo.frontISP,
            address: asnInfo.address,
            latitude: asnInfo.latitude,
            longitude: asnInfo.longitude,
            asId: asnInfo.asId,
            backboneISP: asnInfo.backboneISP,
            createTime: asnInfo.createTime,
            id: asnInfo.id
        )
    }
    
    // MARK: - 批量获取 IP 归属地信息
    func fetchBatchIPInfo(ipList: [String]) async throws -> [String: BatchIPInfo] {
        let userId = await MainActor.run { UserManager.shared.currentUserId }
        
        let request = BatchIPInfoRequest(
            Action: "HuaTuo",
            Method: "GetBatchIPInfo",
            SystemId: APIConfig.systemIdInt,
            AppendInfo: BatchIPInfoRequest.AppendInfo(UserId: userId),
            Data: BatchIPInfoRequest.RequestData(IpList: ipList)
        )
        
        let auth = APIConfig.defaultAuth
        
        let rawData = try await NetworkService.shared.post(
            url: APIConfig.apiURL,
            json: request,
            auth: auth
        )
        
        let decoder = JSONDecoder()
        let response = try decoder.decode(BatchIPInfoResponse.self, from: rawData)
        
        guard response.Return == 0, let data = response.Data else {
            throw NetworkError.invalidResponse
        }
        
        // 将数组转换为字典，以 IP 为 key，取 Info 字段
        var result: [String: BatchIPInfo] = [:]
        for item in data {
            if let ip = item.IP, item.Success == true, let info = item.Info {
                result[ip] = info
            }
        }
        return result
    }
}

// MARK: - MyIP API 原始响应模型
private struct MyIPAPIResponse: Codable {
    let data: MyIPData?
    let msg: String?
    let status: Int?
}

private struct MyIPData: Codable {
    let asnInfo: AsnInfo?
    let code: Int?
    let errMessage: String?
    let ip: String?
    
    enum CodingKeys: String, CodingKey {
        case asnInfo = "AsnInfo"
        case code = "Code"
        case errMessage = "ErrMessage"
        case ip = "IP"
    }
}

private struct AsnInfo: Codable {
    let address: String?
    let asId: Int?
    let backboneISP: String?
    let city: String?
    let country: String?
    let createTime: String?
    let frontISP: String?
    let ip: String?
    let id: Int?
    let latitude: Double?
    let longitude: Double?
    let province: String?
    let region: String?
    
    enum CodingKeys: String, CodingKey {
        case address = "Address"
        case asId = "AsId"
        case backboneISP = "BackboneISP"
        case city = "City"
        case country = "Country"
        case createTime = "CreateTime"
        case frontISP = "FrontISP"
        case ip = "IP"
        case id = "Id"
        case latitude = "Latitude"
        case longitude = "Longitude"
        case province = "Province"
        case region = "Region"
    }
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
        return parts.isEmpty ? "未知" : parts.joined(separator: " ")
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

// MARK: - 批量 IP 信息请求模型
struct BatchIPInfoRequest: Encodable {
    let Action: String
    let Method: String
    let SystemId: Int
    let AppendInfo: AppendInfo
    let Data: RequestData
    
    struct AppendInfo: Encodable {
        let UserId: Int
    }
    
    struct RequestData: Encodable {
        let IpList: [String]
    }
}

// MARK: - 批量 IP 信息响应模型
struct BatchIPInfoResponse: Decodable {
    let Return: Int?
    let Details: String?
    let ReqId: String?
    let Data: [BatchIPItem]?
}

// MARK: - 批量 IP 查询结果项
struct BatchIPItem: Decodable {
    let IP: String?
    let Info: BatchIPInfo?
    let Success: Bool?
    let ErrMsg: String?
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
