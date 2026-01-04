//
//  NetworkService.swift
//  Pong
//
//  Created by 张金琛 on 2025/12/14.
//

import Foundation

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
