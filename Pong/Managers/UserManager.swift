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

// MARK: - 游客登录响应模型
struct GuestLoginResponse: Codable {
    let status: Int?
    let msg: String?
    let data: GuestLoginData?
}

struct GuestLoginData: Codable {
    let Id: Int?
    let Username: String?
    let UserType: String?
    let Name: String?
    let PhoneNumber: String?
    let Company: String?
    let Duty: String?
}

// MARK: - 验证码发送请求模型
struct SendCodeRequest: Codable {
    let PhoneNumber: String
    let Scene: String
}

// MARK: - 验证码发送响应模型
struct SendCodeResponse: Codable {
    let status: Int?
    let msg: String?
    let data: String?
}

// MARK: - 登录类型
enum LoginType {
    case guest
    case phone(phoneNumber: String, code: String, userType: String)
    case password(username: String, password: String, captchaId: String, captchaValue: String, userType: String)
}

// MARK: - 图形验证码响应模型
struct CaptchaResponse: Codable {
    let status: Int?
    let msg: String?
    let data: CaptchaData?
}

struct CaptchaData: Codable {
    let captchaId: String?
    let code: Int?
    let data: String?  // base64 图片数据
    let msg: String?
}

// MARK: - 账号密码登录请求模型
struct AccountLoginRequest: Codable {
    let Verification: String
    let Username: String
    let Password: String
    let CaptchaValue: String
    let CaptchaId: String
    let UserType: String
    let PhoneNumber: String
    let Code: String
    let IsRemember: Bool
}

// MARK: - 手机号登录请求模型
struct PhoneLoginRequest: Codable {
    let Verification: String
    let Username: String
    let Password: String
    let CaptchaValue: String
    let CaptchaId: String
    let UserType: String
    let PhoneNumber: String
    let Code: String
    let IsRemember: Bool
}

// MARK: - 用户管理器
@MainActor
class UserManager: ObservableObject {
    static let shared = UserManager()
    
    @Published var currentUser: UserInfo?
    @Published var isLoggedIn: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let userDefaultsKey = "com.pong.currentUser"
    
    /// 获取当前用户ID，未登录返回 -1
    var currentUserId: Int {
        isLoggedIn ? (currentUser?.userId ?? -1) : -1
    }
    
    private init() {
        loadUserFromStorage()
    }
    
    // MARK: - 从本地存储加载用户
    private func loadUserFromStorage() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let user = try? JSONDecoder().decode(UserInfo.self, from: data) {
            self.currentUser = user
            self.isLoggedIn = true
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
    
    // MARK: - 游客登录
    func guestLogin() async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            let data = try await NetworkService.shared.post(
                url: "\(APIConfig.baseURL)/out/itango/player",
                body: nil
            )
            
            // 尝试解析响应
            let decoder = JSONDecoder()
            let response = try decoder.decode(GuestLoginResponse.self, from: data)
            
            if response.status == 0, let userData = response.data, let userId = userData.Id {
                let user = UserInfo(
                    userId: userId,
                    username: userData.Username,
                    userType: userData.UserType,
                    name: userData.Name,
                    phoneNumber: userData.PhoneNumber,
                    company: userData.Company,
                    duty: userData.Duty,
                    isGuest: userData.UserType == "player"
                )
                self.currentUser = user
                self.isLoggedIn = true
                saveUserToStorage(user)
                isLoading = false
                return true
            } else {
                errorMessage = response.msg?.isEmpty == false ? response.msg : "登录失败"
                isLoading = false
                return false
            }
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }
    
    // MARK: - 发送验证码
    func sendVerificationCode(phoneNumber: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            let request = SendCodeRequest(PhoneNumber: phoneNumber, Scene: "login")
            let data = try await NetworkService.shared.post(
                url: "\(APIConfig.baseURL)/out/sms/code",
                json: request
            )
            
            let decoder = JSONDecoder()
            let response = try decoder.decode(SendCodeResponse.self, from: data)
            
            isLoading = false
            if response.status == 0 {
                return true
            } else {
                errorMessage = response.msg ?? "发送验证码失败"
                return false
            }
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }
    
    // MARK: - 获取图形验证码
    func fetchCaptcha() async -> (captchaId: String, imageData: String)? {
        do {
            let data = try await NetworkService.shared.get(
                url: "\(APIConfig.baseURL)/out/captcha"
            )
            
            let decoder = JSONDecoder()
            let response = try decoder.decode(CaptchaResponse.self, from: data)
            
            if response.status == 0,
               let captchaData = response.data,
               let captchaId = captchaData.captchaId,
               let imageData = captchaData.data {
                return (captchaId, imageData)
            }
        } catch {
            print("获取验证码失败: \(error.localizedDescription)")
        }
        return nil
    }
    
    // MARK: - 统一登录接口（支持验证码登录和密码登录）
    func login(type: LoginType) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        switch type {
        case .guest:
            isLoading = false
            return await guestLogin()
            
        case .phone(let phoneNumber, let code, let userType):
            return await performPhoneLogin(phoneNumber: phoneNumber, code: code, userType: userType)
            
        case .password(let username, let password, let captchaId, let captchaValue, let userType):
            return await performAccountLogin(
                username: username,
                password: password,
                captchaId: captchaId,
                captchaValue: captchaValue,
                userType: userType
            )
        }
    }
    
    // MARK: - 手机号登录
    private func performPhoneLogin(phoneNumber: String, code: String, userType: String) async -> Bool {
        let loginURL = "\(APIConfig.baseURL)/out/itango/login"
        
        do {
            let request = PhoneLoginRequest(
                Verification: "Phone",
                Username: "",
                Password: "",
                CaptchaValue: "",
                CaptchaId: "",
                UserType: userType,
                PhoneNumber: phoneNumber,
                Code: code,
                IsRemember: false
            )
            
            let data = try await NetworkService.shared.post(
                url: loginURL,
                json: request
            )
            
            let decoder = JSONDecoder()
            let response = try decoder.decode(GuestLoginResponse.self, from: data)
            
            if response.status == 0, let userData = response.data, let userId = userData.Id {
                let user = UserInfo(
                    userId: userId,
                    username: userData.Username,
                    userType: userData.UserType,
                    name: userData.Name,
                    phoneNumber: userData.PhoneNumber ?? phoneNumber,
                    company: userData.Company,
                    duty: userData.Duty,
                    isGuest: false
                )
                self.currentUser = user
                self.isLoggedIn = true
                saveUserToStorage(user)
                isLoading = false
                return true
            } else {
                errorMessage = response.msg?.isEmpty == false ? response.msg : "登录失败"
                isLoading = false
                return false
            }
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }
    
    // MARK: - 账号密码登录
    private func performAccountLogin(
        username: String,
        password: String,
        captchaId: String,
        captchaValue: String,
        userType: String
    ) async -> Bool {
        let loginURL = "\(APIConfig.baseURL)/out/itango/login"
        
        do {
            let request = AccountLoginRequest(
                Verification: "Account",
                Username: username,
                Password: password,
                CaptchaValue: captchaValue,
                CaptchaId: captchaId,
                UserType: userType,
                PhoneNumber: "",
                Code: "",
                IsRemember: false
            )
            
            let data = try await NetworkService.shared.post(
                url: loginURL,
                json: request
            )
            
            let decoder = JSONDecoder()
            let response = try decoder.decode(GuestLoginResponse.self, from: data)
            
            if response.status == 0, let userData = response.data, let userId = userData.Id {
                let user = UserInfo(
                    userId: userId,
                    username: userData.Username,
                    userType: userData.UserType,
                    name: userData.Name,
                    phoneNumber: userData.PhoneNumber,
                    company: userData.Company,
                    duty: userData.Duty,
                    isGuest: false
                )
                self.currentUser = user
                self.isLoggedIn = true
                saveUserToStorage(user)
                isLoading = false
                return true
            } else {
                errorMessage = response.msg?.isEmpty == false ? response.msg : "登录失败"
                isLoading = false
                return false
            }
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }
    
    // MARK: - 登出
    func logout() {
        Task {
            // 调用服务端登出接口
            do {
                _ = try await NetworkService.shared.post(
                    url: "\(APIConfig.baseURL)/out/itango/logout",
                    json: EmptyRequest()
                )
            } catch {
                print("Logout request failed: \(error.localizedDescription)")
            }
        }
        
        // 无论服务端请求是否成功，都清除本地状态
        currentUser = nil
        isLoggedIn = false
        clearUserStorage()
    }
    
    // 空请求体
    private struct EmptyRequest: Codable {}
    
    // MARK: - 注销账号
    func deleteAccount() async -> Bool {
        // 注销账号逻辑（如果后端支持）
        // 目前只是本地清除
        logout()
        return true
    }
}
