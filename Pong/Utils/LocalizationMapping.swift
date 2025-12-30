//
//  LocalizationMapping.swift
//  Pong
//
//  Created by 张金琛 on 2025/12/24.
//

import Foundation

/// 本地化映射工具类
/// 用于将中文名称转换为英文
struct LocalizationMapping {
    
    // MARK: - ISP 运营商映射
    
    /// 中文运营商名称到英文的映射表
    static let ispMapping: [String: String] = [
        // ==================== 三大基础运营商 ====================
        "中国电信": "China Telecom",
        "电信": "China Telecom",
        "中国移动": "China Mobile",
        "移动": "China Mobile",
        "中国联通": "China Unicom",
        "联通": "China Unicom",
        
        // ==================== 其他基础运营商 ====================
        "中国广电": "China Broadcasting Network",
        "广电": "China Broadcasting Network",
        "中国铁通": "China Tietong",
        "铁通": "China Tietong",
        "中国网通": "China Netcom",
        "网通": "China Netcom",
        "中国吉通": "China Jitong",
        "吉通": "China Jitong",
        "中国卫通": "China Satcom",
        "卫通": "China Satcom",
        
        // ==================== 民营宽带运营商 ====================
        "长城宽带": "Great Wall Broadband",
        "鹏博士": "Dr. Peng",
        "方正宽带": "Founder Broadband",
        "华数": "Wasu",
        "华数宽带": "Wasu Broadband",
        "有线通": "Cable Network",
        "东方有线": "Oriental Cable",
        "歌华有线": "Gehua CATV",
        "歌华宽带": "Gehua Broadband",
        "天威视讯": "Topway",
        "天威宽带": "Topway Broadband",
        "珠江宽频": "Pearl River Broadband",
        "珠江宽带": "Pearl River Broadband",
        "中邦宽带": "Zhongbang Broadband",
        "视讯宽带": "Shixun Broadband",
        "东南宽带": "Southeast Broadband",
        "金桥网": "Jinqiao Network",
        "盈联宽带": "Yinglian Broadband",
        "华宇宽带": "Huayu Broadband",
        "有线宽带": "Cable Broadband",
        "广电宽带": "CATV Broadband",
        "世纪互联": "21Vianet",
        "蓝汛": "ChinaCache",
        "网银互联": "E-surfing",
        "艾普宽带": "Aipu Broadband",
        "e家宽": "E-Home Broadband",
        "宽带通": "Broadband Connect",
        "联通宽带": "China Unicom Broadband",
        "电信宽带": "China Telecom Broadband",
        "移动宽带": "China Mobile Broadband",
        "油田宽带": "Oilfield Broadband",
        "中信网络": "CITIC Network",
        
        // ==================== 云服务商 ====================
        "阿里云": "Alibaba Cloud",
        "腾讯云": "Tencent Cloud",
        "华为云": "Huawei Cloud",
        "百度云": "Baidu Cloud",
        "百度智能云": "Baidu AI Cloud",
        "京东云": "JD Cloud",
        "金山云": "Kingsoft Cloud",
        "UCloud": "UCloud",
        "青云": "QingCloud",
        "七牛云": "Qiniu Cloud",
        "又拍云": "Upyun",
        "天翼云": "CTYun",
        "移动云": "ECloud",
        "沃云": "WoCloud",
        "浪潮云": "Inspur Cloud",
        "紫光云": "Unis Cloud",
        "中国电子云": "CEC Cloud",
        "火山引擎": "Volcengine",
        "字节跳动": "ByteDance",
        
        // ==================== CDN服务商 ====================
        "网宿科技": "ChinaNetCenter",
        "帝联科技": "Dnion",
        "白山云": "Baishan Cloud",
        "蓝汛通信": "ChinaCache",
        "快网科技": "Fastweb",
        "同兴万点": "Tongxing",
        "高升科技": "Gaosheng",
        "云帆加速": "Yunfan",
        
        // ==================== 教育/科研网络 ====================
        "教育网": "CERNET",
        "中国教育网": "CERNET",
        "科技网": "CSTNET",
        "中科院": "CAS Network",
        "中国科技网": "CSTNET",
        
        // ==================== 数据中心/IDC ====================
        "万网": "HiChina",
        "新网": "Xinnet",
        "西部数码": "West.cn",
        "景安网络": "Jingan Network",
        "息壤": "Xirong",
        "美橙互联": "Cndns",
        "主机屋": "Zhujiwu",
        "恒创科技": "Hengchuang",
        
        // ==================== 国际运营商 ====================
        "AT&T": "AT&T",
        "Verizon": "Verizon",
        "T-Mobile": "T-Mobile",
        "Sprint": "Sprint",
        "Comcast": "Comcast",
        "NTT": "NTT",
        "KDDI": "KDDI",
        "SoftBank": "SoftBank",
        "SK电讯": "SK Telecom",
        "KT": "KT Corporation",
        "LG U+": "LG Uplus",
        "新加坡电信": "Singtel",
        "马来西亚电信": "TM",
        "台湾大哥大": "Taiwan Mobile",
        "中华电信": "Chunghwa Telecom",
        "远传电信": "Far EasTone",
        "香港电讯": "PCCW",
        "和记电讯": "Hutchison",
        "数码通": "SmarTone",
        "澳门电讯": "CTM",
        
        // ==================== 其他常见 ====================
        "局域网": "LAN",
        "内网": "Intranet",
        "本地网络": "Local Network",
        "未知": "Unknown",
    ]
    
    // MARK: - 国家/地区映射
    
    /// 中文国家/地区名称到英文的映射表
    static let countryMapping: [String: String] = [
        // 亚洲
        "中国": "China",
        "日本": "Japan",
        "韩国": "South Korea",
        "印度": "India",
        "新加坡": "Singapore",
        "马来西亚": "Malaysia",
        "泰国": "Thailand",
        "越南": "Vietnam",
        "印度尼西亚": "Indonesia",
        "菲律宾": "Philippines",
        "巴基斯坦": "Pakistan",
        "孟加拉国": "Bangladesh",
        "缅甸": "Myanmar",
        "柬埔寨": "Cambodia",
        "老挝": "Laos",
        "尼泊尔": "Nepal",
        "斯里兰卡": "Sri Lanka",
        "蒙古": "Mongolia",
        "朝鲜": "North Korea",
        "文莱": "Brunei",
        "东帝汶": "East Timor",
        "阿富汗": "Afghanistan",
        "伊朗": "Iran",
        "伊拉克": "Iraq",
        "沙特阿拉伯": "Saudi Arabia",
        "阿联酋": "UAE",
        "卡塔尔": "Qatar",
        "科威特": "Kuwait",
        "巴林": "Bahrain",
        "阿曼": "Oman",
        "也门": "Yemen",
        "约旦": "Jordan",
        "黎巴嫩": "Lebanon",
        "叙利亚": "Syria",
        "以色列": "Israel",
        "巴勒斯坦": "Palestine",
        "土耳其": "Turkey",
        "塞浦路斯": "Cyprus",
        "格鲁吉亚": "Georgia",
        "亚美尼亚": "Armenia",
        "阿塞拜疆": "Azerbaijan",
        "哈萨克斯坦": "Kazakhstan",
        "乌兹别克斯坦": "Uzbekistan",
        "土库曼斯坦": "Turkmenistan",
        "吉尔吉斯斯坦": "Kyrgyzstan",
        "塔吉克斯坦": "Tajikistan",
        // 欧洲
        "英国": "United Kingdom",
        "法国": "France",
        "德国": "Germany",
        "意大利": "Italy",
        "西班牙": "Spain",
        "葡萄牙": "Portugal",
        "荷兰": "Netherlands",
        "比利时": "Belgium",
        "瑞士": "Switzerland",
        "奥地利": "Austria",
        "瑞典": "Sweden",
        "挪威": "Norway",
        "丹麦": "Denmark",
        "芬兰": "Finland",
        "冰岛": "Iceland",
        "爱尔兰": "Ireland",
        "波兰": "Poland",
        "捷克": "Czech Republic",
        "斯洛伐克": "Slovakia",
        "匈牙利": "Hungary",
        "罗马尼亚": "Romania",
        "保加利亚": "Bulgaria",
        "希腊": "Greece",
        "乌克兰": "Ukraine",
        "白俄罗斯": "Belarus",
        "俄罗斯": "Russia",
        "爱沙尼亚": "Estonia",
        "拉脱维亚": "Latvia",
        "立陶宛": "Lithuania",
        "斯洛文尼亚": "Slovenia",
        "克罗地亚": "Croatia",
        "塞尔维亚": "Serbia",
        "波黑": "Bosnia and Herzegovina",
        "黑山": "Montenegro",
        "北马其顿": "North Macedonia",
        "阿尔巴尼亚": "Albania",
        "摩尔多瓦": "Moldova",
        "卢森堡": "Luxembourg",
        "摩纳哥": "Monaco",
        "列支敦士登": "Liechtenstein",
        "安道尔": "Andorra",
        "马耳他": "Malta",
        "圣马力诺": "San Marino",
        "梵蒂冈": "Vatican",
        // 北美洲
        "美国": "United States",
        "加拿大": "Canada",
        "墨西哥": "Mexico",
        "古巴": "Cuba",
        "牙买加": "Jamaica",
        "海地": "Haiti",
        "多米尼加": "Dominican Republic",
        "巴哈马": "Bahamas",
        "巴拿马": "Panama",
        "哥斯达黎加": "Costa Rica",
        "危地马拉": "Guatemala",
        "洪都拉斯": "Honduras",
        "萨尔瓦多": "El Salvador",
        "尼加拉瓜": "Nicaragua",
        "伯利兹": "Belize",
        // 南美洲
        "巴西": "Brazil",
        "阿根廷": "Argentina",
        "智利": "Chile",
        "秘鲁": "Peru",
        "哥伦比亚": "Colombia",
        "委内瑞拉": "Venezuela",
        "厄瓜多尔": "Ecuador",
        "玻利维亚": "Bolivia",
        "巴拉圭": "Paraguay",
        "乌拉圭": "Uruguay",
        "圭亚那": "Guyana",
        "苏里南": "Suriname",
        // 大洋洲
        "澳大利亚": "Australia",
        "新西兰": "New Zealand",
        "斐济": "Fiji",
        "巴布亚新几内亚": "Papua New Guinea",
        "新喀里多尼亚": "New Caledonia",
        "关岛": "Guam",
        // 非洲
        "埃及": "Egypt",
        "南非": "South Africa",
        "尼日利亚": "Nigeria",
        "肯尼亚": "Kenya",
        "埃塞俄比亚": "Ethiopia",
        "坦桑尼亚": "Tanzania",
        "摩洛哥": "Morocco",
        "阿尔及利亚": "Algeria",
        "突尼斯": "Tunisia",
        "利比亚": "Libya",
        "苏丹": "Sudan",
        "加纳": "Ghana",
        "科特迪瓦": "Ivory Coast",
        "喀麦隆": "Cameroon",
        "刚果": "Congo",
        "安哥拉": "Angola",
        "津巴布韦": "Zimbabwe",
        "赞比亚": "Zambia",
        "莫桑比克": "Mozambique",
        "马达加斯加": "Madagascar",
        "毛里求斯": "Mauritius",
        "塞内加尔": "Senegal",
        "乌干达": "Uganda",
        "卢旺达": "Rwanda",
        // 特别行政区
        "中国香港": "Hong Kong",
        "中国澳门": "Macau",
        "中国台湾": "Taiwan",
        "香港": "Hong Kong",
        "澳门": "Macau",
        "台湾": "Taiwan",
        "香港特别行政区": "Hong Kong",
        "澳门特别行政区": "Macau",
        "台湾省": "Taiwan",
    ]
    
    // MARK: - 转换方法
    
    /// 将中文运营商名称转换为英文
    /// - Parameter chinese: 中文运营商名称
    /// - Returns: 英文名称，如果无法翻译则返回原始值或拼音
    static func toEnglishISP(_ chinese: String) -> String {
        // 精确匹配
        if let english = ispMapping[chinese] {
            return english
        }
        
        // 部分匹配
        for (key, english) in ispMapping {
            if chinese.contains(key) {
                return english
            }
        }
        
        // 无法翻译时返回拼音
        return chinese.toPinyin()
    }
    
    /// 将中文国家/地区名称转换为英文
    /// - Parameter chinese: 中文国家/地区名称
    /// - Returns: 英文名称，如果无法翻译则返回原始值或拼音
    static func toEnglishCountry(_ chinese: String) -> String {
        // 精确匹配
        if let english = countryMapping[chinese] {
            return english
        }
        
        // 无法翻译时返回拼音
        return chinese.toPinyin()
    }
}
