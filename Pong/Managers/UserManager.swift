//
//  UserManager.swift
//  Pong
//
//  Created by 张金琛 on 2025/12/15.
//

import Foundation
internal import Combine

// MARK: - 用户信息模型
struct UserInfo: Codable {
    let userId: Int
    let username: String?
    let userType: String?
    let name: String?
    let phoneNumber: String?
    let company: String?
    let duty: String?
    let isGuest: Bool
    
    init(userId: Int, username: String? = nil, userType: String? = nil, name: String? = nil, phoneNumber: String? = nil, company: String? = nil, duty: String? = nil, isGuest: Bool = true) {
        self.userId = userId
        self.username = username
        self.userType = userType
        self.name = name
        self.phoneNumber = phoneNumber
        self.company = company
        self.duty = duty
        self.isGuest = isGuest
    }
    
    var displayName: String {
        // 优先使用 Name，其次使用 Username
        if let name = name, !name.isEmpty {
            return name
        }
        if let username = username, !username.isEmpty {
            return username
        }
        return "游客\(userId)"
    }
}

// MARK: - 用户管理器
@MainActor
class UserManager: ObservableObject {
    static let shared = UserManager()
    
    @Published var currentUser: UserInfo?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let userDefaultsKey = "com.pong.currentUser"
    
    /// 获取当前用户ID，未设置返回 -1
    var currentUserId: Int {
        currentUser?.userId ?? -1
    }
    
    private init() {
        loadUserFromStorage()
    }
    
    // MARK: - 从本地存储加载用户
    private func loadUserFromStorage() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let user = try? JSONDecoder().decode(UserInfo.self, from: data) {
            self.currentUser = user
        } else {
            // 如果没有存储的用户，创建一个默认用户
            let defaultUser = UserInfo(userId: Int.random(in: 100000...999999), isGuest: true)
            self.currentUser = defaultUser
            saveUserToStorage(defaultUser)
        }
    }
    
    // MARK: - 保存用户到本地存储
    private func saveUserToStorage(_ user: UserInfo) {
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
    
    // MARK: - 清除本地用户存储
    private func clearUserStorage() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
}
