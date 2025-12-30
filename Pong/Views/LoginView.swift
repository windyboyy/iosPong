//
//  LoginView.swift
//  Pong
//
//  Created by 张金琛 on 2025/12/16.
//

import SwiftUI

struct LoginView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var languageManager: LanguageManager
    @StateObject private var viewModel: LoginViewModel
    
    // 验证码输入框焦点
    @FocusState private var isVerificationCodeFocused: Bool
    
    private var l10n: L10n { L10n.shared }
    
    var onLoginSuccess: (() -> Void)?
    
    // 初始化方法
    init(selectedMethod: LoginMethod = .guest, hideGuestLogin: Bool = false, onLoginSuccess: (() -> Void)? = nil) {
        self._viewModel = StateObject(wrappedValue: LoginViewModel(
            selectedMethod: selectedMethod,
            hideGuestLogin: hideGuestLogin
        ))
        self.onLoginSuccess = onLoginSuccess
    }
    
    var body: some View {
        NavigationStack {
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(spacing: 24) {
                        // Logo 和标题
                        headerView
                        
                        // 登录方式选择
                        loginMethodPicker
                        
                        // 登录表单
                        loginFormView
                        
                        // 登录按钮
                        loginButton
                            .id("loginButton")
                        
                        // 协议说明
                        agreementText
                    }
                    .padding()
                }
                .onChange(of: isVerificationCodeFocused) { _, focused in
                    if focused {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation {
                                scrollProxy.scrollTo("loginButton", anchor: .top)
                            }
                        }
                    }
                }
            }
            .navigationTitle(l10n.login)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(l10n.cancel) {
                        dismiss()
                    }
                }
            }
            .alert(l10n.loginFailed, isPresented: $viewModel.showError) {
                Button(l10n.confirm, role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage)
            }
            .overlay {
                if viewModel.showCodeSentToast {
                    toastView(message: l10n.codeSent)
                }
            }
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 12) {
            Image("itango_single_logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: viewModel.selectedMethod == .guest ? 80 : 50, height: viewModel.selectedMethod == .guest ? 80 : 50)
                .cornerRadius(viewModel.selectedMethod == .guest ? 18 : 12)
            
            Text(l10n.iTangoNetworkProbe)
                .font(viewModel.selectedMethod == .guest ? .title2 : .headline)
                .fontWeight(.bold)
            
            if viewModel.selectedMethod == .guest {
                Text(l10n.globalNetworkPlatform)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.top, viewModel.selectedMethod == .guest ? 16 : 8)
        .padding(.bottom, viewModel.selectedMethod == .guest ? 8 : 4)
        .animation(.easeInOut(duration: 0.25), value: viewModel.selectedMethod)
    }
    
    // MARK: - Login Method Picker
    private var loginMethodPicker: some View {
        HStack(spacing: 0) {
            ForEach(viewModel.availableMethods, id: \.self) { method in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.selectedMethod = method
                    }
                } label: {
                    Text(method.title(l10n))
                        .font(.subheadline)
                        .fontWeight(viewModel.selectedMethod == method ? .semibold : .regular)
                        .foregroundColor(viewModel.selectedMethod == method ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            viewModel.selectedMethod == method ? Color.blue : Color.clear
                        )
                }
            }
        }
        .background(Color.gray.opacity(0.15))
        .cornerRadius(10)
    }
    
    // MARK: - Login Form View
    @ViewBuilder
    private var loginFormView: some View {
        switch viewModel.selectedMethod {
        case .phone:
            phoneLoginForm
        case .account:
            accountLoginForm
        case .guest:
            guestLoginInfo
        }
    }
    
    // MARK: - Phone Login Form
    private var phoneLoginForm: some View {
        VStack(spacing: 16) {
            // 用户类型选择
            VStack(alignment: .leading, spacing: 8) {
                Text(l10n.userType)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 0) {
                    ForEach(AccountUserType.allCases, id: \.self) { userType in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.phoneUserType = userType
                            }
                        } label: {
                            Text(userType.title(l10n))
                                .font(.subheadline)
                                .fontWeight(viewModel.phoneUserType == userType ? .semibold : .regular)
                                .foregroundColor(viewModel.phoneUserType == userType ? .white : .primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    viewModel.phoneUserType == userType ? Color.blue : Color.clear
                                )
                        }
                    }
                }
                .background(Color.gray.opacity(0.15))
                .cornerRadius(10)
            }
            
            // 手机号输入
            VStack(alignment: .leading, spacing: 8) {
                Text(l10n.phoneNumber)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                TextField(l10n.enterPhoneNumber, text: $viewModel.phoneNumber)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
            }
            
            // 验证码输入
            VStack(alignment: .leading, spacing: 8) {
                Text(l10n.verificationCode)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 12) {
                    TextField(l10n.enterVerificationCode, text: $viewModel.verificationCode)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .focused($isVerificationCodeFocused)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                    
                    Button {
                        Task {
                            await viewModel.sendCode()
                            if viewModel.showCodeSentToast {
                                isVerificationCodeFocused = true
                            }
                        }
                    } label: {
                        Text(viewModel.codeButtonText)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(viewModel.canSendCode ? .white : .gray)
                            .frame(width: 90)
                            .padding(.vertical, 14)
                            .background(viewModel.canSendCode ? Color.blue : Color.gray.opacity(0.3))
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    .disabled(!viewModel.canSendCode)
                }
            }
        }
    }
    
    // MARK: - Account Login Form
    private var accountLoginForm: some View {
        VStack(spacing: 16) {
            // 用户类型选择
            VStack(alignment: .leading, spacing: 8) {
                Text(l10n.userType)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 0) {
                    ForEach(AccountUserType.allCases, id: \.self) { userType in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.selectedUserType = userType
                            }
                        } label: {
                            Text(userType.title(l10n))
                                .font(.subheadline)
                                .fontWeight(viewModel.selectedUserType == userType ? .semibold : .regular)
                                .foregroundColor(viewModel.selectedUserType == userType ? .white : .primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    viewModel.selectedUserType == userType ? Color.blue : Color.clear
                                )
                        }
                    }
                }
                .background(Color.gray.opacity(0.15))
                .cornerRadius(10)
            }
            
            // 用户名输入
            VStack(alignment: .leading, spacing: 8) {
                Text(l10n.username)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                TextField(l10n.enterUsername, text: $viewModel.username)
                    .textContentType(.username)
                    .autocapitalization(.none)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
            }
            
            // 密码输入
            VStack(alignment: .leading, spacing: 8) {
                Text(l10n.password)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    if viewModel.showPassword {
                        TextField(l10n.enterPassword, text: $viewModel.password)
                            .textContentType(.password)
                            .autocapitalization(.none)
                    } else {
                        SecureField(l10n.enterPassword, text: $viewModel.password)
                            .textContentType(.password)
                    }
                    
                    Button {
                        viewModel.showPassword.toggle()
                    } label: {
                        Image(systemName: viewModel.showPassword ? "eye.slash.fill" : "eye.fill")
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
            }
            
            // 图形验证码
            VStack(alignment: .leading, spacing: 8) {
                Text(l10n.captcha)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 12) {
                    TextField(l10n.enterCaptcha, text: $viewModel.captchaValue)
                        .keyboardType(.asciiCapable)
                        .autocapitalization(.none)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                    
                    // 验证码图片
                    Button {
                        Task {
                            await viewModel.loadCaptcha()
                        }
                    } label: {
                        if viewModel.isLoadingCaptcha {
                            ProgressView()
                                .frame(width: 100, height: 44)
                        } else if let image = viewModel.captchaImage {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 100, height: 44)
                                .cornerRadius(8)
                        } else {
                            Text(l10n.loadCaptcha)
                                .font(.caption)
                                .foregroundColor(.blue)
                                .frame(width: 100, height: 44)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.loadCaptcha()
            }
        }
    }
    
    // MARK: - Guest Login Info
    private var guestLoginInfo: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text(l10n.oneClickLogin)
                    .font(.subheadline)
            }
            
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text(l10n.autoAssignID)
                    .font(.subheadline)
            }
            
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text(l10n.enjoyCloudProbe)
                    .font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.blue.opacity(0.08))
        .cornerRadius(12)
    }
    
    // MARK: - Login Button
    private var loginButton: some View {
        Button {
            Task {
                let success = await viewModel.performLogin()
                if success {
                    onLoginSuccess?()
                    dismiss()
                }
            }
        } label: {
            HStack {
                if viewModel.isLoggingIn {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
                Text(viewModel.isLoggingIn ? l10n.loggingIn : l10n.login)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(viewModel.canLogin ? Color.blue : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.canLogin || viewModel.isLoggingIn)
    }
    
    // MARK: - Agreement Text
    private var agreementText: some View {
        VStack(spacing: 8) {
            // 勾选框和同意文字
            HStack(alignment: .top, spacing: 8) {
                Button {
                    viewModel.hasAgreedToTerms.toggle()
                } label: {
                    Image(systemName: viewModel.hasAgreedToTerms ? "checkmark.square.fill" : "square")
                        .foregroundColor(viewModel.hasAgreedToTerms ? .blue : .gray)
                        .font(.system(size: 20))
                }
                .buttonStyle(.plain)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(l10n.agreeToTerms)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // 协议链接
                    FlowLayout(spacing: 4) {
                        agreementLink(.userService)
                        agreementLink(.privacySummary)
                        agreementLink(.privacyFull)
                        agreementLink(.thirdPartySDK)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(item: $viewModel.showingAgreement) { agreement in
            NavigationStack {
                ScrollView {
                    Text(agreement.content(for: languageManager.currentLanguage))
                        .padding()
                }
                .navigationTitle(agreement.title(l10n))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(l10n.confirm) {
                            viewModel.showingAgreement = nil
                        }
                    }
                }
            }
        }
    }
    
    // 协议链接按钮
    private func agreementLink(_ type: AgreementType) -> some View {
        Button {
            viewModel.showingAgreement = type
        } label: {
            Text("《\(type.title(l10n))》")
                .font(.caption)
                .foregroundColor(.blue)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Toast View
    private func toastView(message: String) -> some View {
        VStack {
            Spacer()
            Text(message)
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.75))
                .cornerRadius(8)
                .padding(.bottom, 100)
        }
        .transition(.opacity)
    }
}

#Preview {
    LoginView()
        .environmentObject(LanguageManager.shared)
}

// MARK: - FlowLayout
struct FlowLayout: Layout {
    var spacing: CGFloat = 4
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }
    
    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            
            positions.append(CGPoint(x: currentX, y: currentY))
            
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            totalWidth = max(totalWidth, currentX - spacing)
        }
        
        totalHeight = currentY + lineHeight
        
        return (CGSize(width: totalWidth, height: totalHeight), positions)
    }
}
