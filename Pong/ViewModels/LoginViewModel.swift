//
//  LoginViewModel.swift
//  Pong
//
//  Created by 张金琛 on 2025/12/22.
//

import SwiftUI
internal import Combine

// MARK: - 登录方式
enum LoginMethod: CaseIterable {
    case guest
    case phone
    case account
    
    func title(_ l10n: L10n) -> String {
        switch self {
        case .guest: return l10n.guestLogin
        case .phone: return l10n.phoneLogin
        case .account: return l10n.accountLogin
        }
    }
}

// MARK: - 用户类型（账号密码登录）
enum AccountUserType: String, CaseIterable {
    case community = "community"
    case business = "business"
    
    func title(_ l10n: L10n) -> String {
        switch self {
        case .community: return l10n.communityVersion
        case .business: return l10n.customVersion
        }
    }
    
    var color: Color {
        switch self {
        case .community: return .green
        case .business: return .blue
        }
    }
    
    /// 从 userType 字符串创建
    static func from(_ userType: String?) -> AccountUserType? {
        guard let userType = userType else { return nil }
        return AccountUserType(rawValue: userType)
    }
}

// MARK: - 登录视图模型
@MainActor
class LoginViewModel: ObservableObject {
    // MARK: - 依赖
    private let userManager = UserManager.shared
    private var timerCancellable: AnyCancellable?
    
    // MARK: - 登录方式
    @Published var selectedMethod: LoginMethod
    
    // MARK: - 手机号登录
    @Published var phoneNumber = ""
    @Published var verificationCode = ""
    @Published var isSendingCode = false
    @Published var countdown = 0
    @Published var phoneUserType: AccountUserType = .community
    
    // MARK: - 账号密码登录
    @Published var username = ""
    @Published var password = ""
    @Published var showPassword = false
    @Published var selectedUserType: AccountUserType = .community
    @Published var captchaId = ""
    @Published var captchaValue = ""
    @Published var captchaImageData = ""
    @Published var isLoadingCaptcha = false
    
    // MARK: - 状态
    @Published var isLoggingIn = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var showCodeSentToast = false
    @Published var hasAgreedToTerms = false
    
    // MARK: - 协议弹窗
    @Published var showingAgreement: AgreementType? = nil
    
    // MARK: - 配置
    let hideGuestLogin: Bool
    
    // 上次登录信息存储 key
    private static let lastPhoneNumberKey = "com.pong.lastPhoneNumber"
    private static let lastUsernameKey = "com.pong.lastUsername"
    
    // MARK: - 计算属性
    var availableMethods: [LoginMethod] {
        hideGuestLogin ? [.phone, .account] : LoginMethod.allCases
    }
    
    var codeButtonText: String {
        let l10n = L10n.shared
        if isSendingCode {
            return l10n.sendingCode
        } else if countdown > 0 {
            return "\(countdown)s"
        } else {
            return l10n.getVerificationCode
        }
    }
    
    var canSendCode: Bool {
        !isSendingCode && countdown == 0 && isValidPhoneNumber
    }
    
    var isValidPhoneNumber: Bool {
        phoneNumber.count >= 11
    }
    
    var canLogin: Bool {
        guard hasAgreedToTerms else { return false }
        switch selectedMethod {
        case .phone:
            return isValidPhoneNumber && !verificationCode.isEmpty
        case .account:
            return !username.isEmpty && !password.isEmpty && !captchaValue.isEmpty && !captchaId.isEmpty
        case .guest:
            return true
        }
    }
    
    var captchaImage: UIImage? {
        guard !captchaImageData.isEmpty else { return nil }
        let base64String = captchaImageData.replacingOccurrences(of: "data:image/png;base64,", with: "")
        guard let data = Data(base64Encoded: base64String) else { return nil }
        return UIImage(data: data)
    }
    
    // MARK: - 初始化
    init(selectedMethod: LoginMethod = .guest, hideGuestLogin: Bool = false) {
        self.hideGuestLogin = hideGuestLogin
        // 如果隐藏游客登录且初始方式是游客，则默认选择手机登录
        let effectiveMethod = (hideGuestLogin && selectedMethod == .guest) ? .phone : selectedMethod
        self.selectedMethod = effectiveMethod
        
        setupTimer()
        loadLastLoginInfo()
    }
    
    deinit {
        timerCancellable?.cancel()
    }
    
    // MARK: - 私有方法
    private func setupTimer() {
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.countdown > 0 {
                    self.countdown -= 1
                }
            }
    }
    
    private func loadLastLoginInfo() {
        if let lastPhone = UserDefaults.standard.string(forKey: Self.lastPhoneNumberKey), !lastPhone.isEmpty {
            phoneNumber = lastPhone
        }
        if let lastUsername = UserDefaults.standard.string(forKey: Self.lastUsernameKey), !lastUsername.isEmpty {
            username = lastUsername
        }
    }
    
    private func saveLastLoginInfo() {
        switch selectedMethod {
        case .phone:
            UserDefaults.standard.set(phoneNumber, forKey: Self.lastPhoneNumberKey)
        case .account:
            UserDefaults.standard.set(username, forKey: Self.lastUsernameKey)
        case .guest:
            break
        }
    }
    
    // MARK: - 公开方法
    func loadCaptcha() async {
        isLoadingCaptcha = true
        if let result = await userManager.fetchCaptcha() {
            captchaId = result.captchaId
            captchaImageData = result.imageData
        }
        isLoadingCaptcha = false
    }
    
    func sendCode() async {
        let l10n = L10n.shared
        guard isValidPhoneNumber else {
            errorMessage = l10n.invalidPhoneNumber
            showError = true
            return
        }
        
        isSendingCode = true
        let success = await userManager.sendVerificationCode(phoneNumber: phoneNumber)
        isSendingCode = false
        
        if success {
            countdown = 60
            showCodeSentToast = true
            // 2秒后隐藏 toast
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                showCodeSentToast = false
            }
        } else {
            errorMessage = userManager.errorMessage ?? l10n.sendCodeFailed
            showError = true
        }
    }
    
    func performLogin() async -> Bool {
        let l10n = L10n.shared
        
        // 验证输入
        switch selectedMethod {
        case .phone:
            guard isValidPhoneNumber else {
                errorMessage = l10n.invalidPhoneNumber
                showError = true
                return false
            }
            guard !verificationCode.isEmpty else {
                errorMessage = l10n.invalidVerificationCode
                showError = true
                return false
            }
        case .account:
            guard !username.isEmpty else {
                errorMessage = l10n.invalidUsername
                showError = true
                return false
            }
            guard !password.isEmpty else {
                errorMessage = l10n.invalidPassword
                showError = true
                return false
            }
            guard !captchaValue.isEmpty else {
                errorMessage = l10n.invalidCaptcha
                showError = true
                return false
            }
        case .guest:
            break
        }
        
        isLoggingIn = true
        
        let success: Bool
        switch selectedMethod {
        case .phone:
            success = await userManager.login(type: .phone(
                phoneNumber: phoneNumber,
                code: verificationCode,
                userType: phoneUserType.rawValue
            ))
        case .account:
            success = await userManager.login(type: .password(
                username: username,
                password: password,
                captchaId: captchaId,
                captchaValue: captchaValue,
                userType: selectedUserType.rawValue
            ))
        case .guest:
            success = await userManager.guestLogin()
        }
        
        isLoggingIn = false
        
        if success {
            saveLastLoginInfo()
            return true
        } else {
            errorMessage = userManager.errorMessage ?? l10n.loginFailedRetry
            showError = true
            // 登录失败后刷新验证码
            if selectedMethod == .account {
                captchaValue = ""
                await loadCaptcha()
            }
            return false
        }
    }
}
