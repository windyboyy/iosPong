//
//  CloudProbeModels.swift
//  Pong
//
//  Created by 张金琛 on 2025/12/14.
//

import Foundation

// MARK: - 云探测请求模型
struct CloudProbeRequest: Encodable {
    let Action: String
    let AppendInfo: AppendInfo
    let Condition: Condition
    let Method: String
    let SystemId: String
    
    struct AppendInfo: Encodable {
        let UserId: Int
    }
    
    struct Condition: Encodable {
        let AddressFamily: Int
        let IsPublic: Int
    }
}

// MARK: - 云探测响应模型
struct CloudProbeResponse: Decodable {
    let Return: Int?
    let Details: String?
    let ReqId: String?
    let Data: [ProbeLocation]?
}

// MARK: - 创建任务请求模型
struct CreateTaskRequest: Encodable {
    let Action: String
    let AppendInfo: AppendInfo
    let Data: TaskData
    let Method: String
    let SystemId: String
    
    struct AppendInfo: Encodable {
        let UserId: Int
    }
    
    struct TaskData: Encodable {
        let MainTaskName: String
        let MsmSetting: MsmSetting
        let SubTaskList: [SubTask]
    }
    
    struct MsmSetting: Encodable {
        let Af: Int
        let MsmType: String
        let Options: MsmOptions
    }
    
    struct MsmOptions: Encodable {
        // Ping 选项
        let count: Int?
        let interval: Double?
        let size: Int?
        let timeout: Int?
        
        // DNS 选项
        let timeout_secs: Int?
        let rtype: String?
        let ns: String?
        
        init(count: Int, interval: Double, size: Int, timeout: Int) {
            self.count = count
            self.interval = interval
            self.size = size
            self.timeout = timeout
            self.timeout_secs = nil
            self.rtype = nil
            self.ns = nil
        }
        
        init(timeout_secs: Int, rtype: String, ns: String) {
            self.count = nil
            self.interval = nil
            self.size = nil
            self.timeout = nil
            self.timeout_secs = timeout_secs
            self.rtype = rtype
            self.ns = ns
        }
        
        enum CodingKeys: String, CodingKey {
            case count, interval, size, timeout
            case timeout_secs, rtype, ns
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(count, forKey: .count)
            try container.encodeIfPresent(interval, forKey: .interval)
            try container.encodeIfPresent(size, forKey: .size)
            try container.encodeIfPresent(timeout, forKey: .timeout)
            try container.encodeIfPresent(timeout_secs, forKey: .timeout_secs)
            try container.encodeIfPresent(rtype, forKey: .rtype)
            try container.encodeIfPresent(ns, forKey: .ns)
        }
    }
    
    struct SubTask: Encodable {
        let AgentScope: [AgentScope]
        let SubTaskName: String
        let TargetScope: [TargetScope]
    }
    
    struct AgentScope: Encodable {
        let GeoInfo: GeoInfo
        let type: String
        
        enum CodingKeys: String, CodingKey {
            case GeoInfo
            case type = "Type"
        }
    }
    
    struct GeoInfo: Encodable {
        let AsId: Int?
        let Country: String?
        let DataSource: String
        let ISP: String?
        
        enum CodingKeys: String, CodingKey {
            case AsId, Country, DataSource, ISP
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(AsId, forKey: .AsId)
            try container.encodeIfPresent(Country, forKey: .Country)
            try container.encode(DataSource, forKey: .DataSource)
            try container.encodeIfPresent(ISP, forKey: .ISP)
        }
    }
    
    struct TargetScope: Encodable {
        let ExplicitTargetHostList: [String]
        let type: String
        
        enum CodingKeys: String, CodingKey {
            case ExplicitTargetHostList
            case type = "Type"
        }
    }
}

// MARK: - 创建任务响应模型
struct CreateTaskResponse: Decodable {
    let Return: Int?
    let Details: String?
    let ReqId: String?
    let Data: CreateTaskData?
    
    struct CreateTaskData: Decodable {
        let MainTaskId: Int?
    }
}

// MARK: - 查询结果请求模型
struct QueryResultRequest: Encodable {
    let Action: String
    let AppendInfo: AppendInfo
    let Data: QueryData
    let Method: String
    let SystemId: Int
    
    struct AppendInfo: Encodable {
        let UserId: Int
    }
    
    struct QueryData: Encodable {
        let MainId: Int
    }
}

// MARK: - 查询结果响应模型
struct QueryResultResponse: Decodable {
    let Return: Int?
    let Details: String?
    let ReqId: String?
    let Data: QueryResultData?
    
    struct QueryResultData: Decodable {
        let Detail: [AnyCodable]?
        let Finished: Bool?
    }
}

// MARK: - AnyCodable for flexible decoding
struct AnyCodable: Decodable {
    let value: Any
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let dict = try? container.decode([String: AnyCodableValue].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = [String: Any]()
        }
    }
}

struct AnyCodableValue: Decodable {
    let value: Any
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let array = try? container.decode([AnyCodableValue].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodableValue].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }
}

// MARK: - Ping结果模型
struct CloudPingResult: Decodable, Identifiable {
    var id: String { "\(AgentAsId)-\(BuildinLocalTime ?? "")" }
    
    let AgentAsId: Int
    let AgentCountry: String?
    let AgentISP: String?
    let AgentProvince: String?
    let AvgRttMilli: Double?
    let BuildinAgentRemoteIP: String?
    let BuildinErrMessage: String?
    let BuildinLocalTime: String?
    let BuildinMainTaskSetId: Int?
    let BuildinPeerIP: String?
    let BuildinTargetHost: String?
    let BuildinUserId: Int?
    let MaxRttMilli: Double?
    let MinRttMilli: Double?
    let PacketLoss: Double?
}

// MARK: - DNS结果模型
struct CloudDNSResult: Decodable, Identifiable {
    var id: String { "\(AgentAsId)-\(BuildinMainTaskSetId ?? 0)" }
    
    let AgentAsId: Int
    let AgentCountry: String?
    let AgentISP: String?
    let AgentProvince: String?
    let Answers: [DNSAnswer]?
    let AtNameServer: String?
    let BuildinAgentRemoteIP: String?
    let BuildinErrMessage: String?
    let BuildinMainTaskSetId: Int?
    let BuildinPeerIP: String?
    let BuildinTargetHost: String?
    let RttMilli: Double?
    
    struct DNSAnswer: Decodable, Identifiable {
        var id: String { "\(Name ?? "")-\(ParseIP ?? "")-\(RRType ?? "")" }
        let Class: String?
        let Name: String?
        let ParseIP: String?
        let RRType: String?
    }
}

// MARK: - 探测位置模型
struct ProbeLocation: Decodable, Hashable {
    let Area: String?
    let AsId: Int
    let City: String?
    let Country: String?
    let ISP: String?
    let Province: String?
    
    // 用于显示的大洲名称（处理空值）
    var displayArea: String {
        if let area = Area, !area.isEmpty {
            return area
        }
        return L10n.shared.other
    }
    
    // 用于显示的运营商名称（原始值，用于筛选）
    var displayISP: String {
        if let isp = ISP, !isp.isEmpty {
            return isp
        }
        return L10n.shared.unknownISP
    }
    
    // 用于显示的国家名称（原始值，用于筛选）
    var displayCountry: String {
        Country ?? L10n.shared.unknown
    }
    
    // 本地化的运营商名称（用于UI显示）
    var localizedISP: String {
        let isp = displayISP
        if LanguageManager.shared.currentLanguage == .english {
            return isp.toEnglishISP()
        }
        return isp
    }
    
    // 本地化的国家名称（用于UI显示）
    var localizedCountry: String {
        let country = displayCountry
        if LanguageManager.shared.currentLanguage == .english {
            return country.toEnglishCountry()
        }
        return country
    }
    
    // 唯一标识
    var uniqueId: String {
        "\(displayCountry)-\(displayISP)-\(AsId)"
    }
}

// MARK: - 探测类型
enum CloudProbeType: String, CaseIterable {
    case ping = "Ping"
    case dns = "DNS"
    case tcp = "TCP"
    case udp = "UDP"
    
    var msmType: String {
        switch self {
        case .ping: return "ping"
        case .dns: return "dns"
        case .tcp: return "tcp_port"
        case .udp: return "udp_port"
        }
    }
    
    var icon: String {
        switch self {
        case .ping: return "network"
        case .dns: return "server.rack"
        case .tcp: return "arrow.left.arrow.right"
        case .udp: return "paperplane"
        }
    }
}

// MARK: - 创建任务参数
struct CreateTaskParams {
    let probeType: CloudProbeType
    let targetHost: String
    let targetPort: String
    let dnsRecordType: String
    let selectedCountry: String?
    let selectedISP: String?
    let selectedASId: Int?
    let userId: Int
}

// MARK: - 探测结果
struct CloudProbeResult {
    var pingResults: [CloudPingResult] = []
    var dnsResults: [CloudDNSResult] = []
    var isFinished: Bool = false
}
