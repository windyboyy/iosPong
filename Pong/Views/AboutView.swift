//
//  AboutView.swift
//  Pong
//
//  Created by 张金琛 on 2025/12/23.
//

import SwiftUI

// Bundle 扩展：获取 App 图标
extension Bundle {
    var icon: UIImage? {
        if let icons = infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
           let lastIcon = iconFiles.last {
            return UIImage(named: lastIcon)
        }
        return nil
    }
}

struct AboutView: View {
    @EnvironmentObject var languageManager: LanguageManager
    @StateObject private var updateManager = AppUpdateManager.shared
    @State private var showUpdateResult = false
    @State private var updateResultMessage = ""
    @State private var isLatestVersion = false
    
    private var l10n: L10n { L10n.shared }
    
    var body: some View {
        List {
            // App 图标和名称
            Section {
                VStack(spacing: 12) {
                    // App 图标 - 使用 App 的 Logo
                    if let appIcon = UIImage(named: "AppIcon") ?? Bundle.main.icon {
                        Image(uiImage: appIcon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                            .cornerRadius(18)
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    } else {
                        Image(systemName: "app.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                            .foregroundColor(.blue)
                    }
                    
                    // App 名称
                    Text("iTango")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    // 版本信息
                    Text("\(l10n.version) \(updateManager.currentVersion) (\(updateManager.buildNumber))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 0)
                .padding(.bottom, 12)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            
            // 版本信息
            Section(l10n.versionInfo) {
                HStack {
                    Text(l10n.currentVersion)
                    Spacer()
                    Text(updateManager.currentVersion)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text(l10n.buildNumber)
                    Spacer()
                    Text(updateManager.buildNumber)
                        .foregroundColor(.secondary)
                }
                
                // 检查更新按钮
                Button {
                    checkForUpdate()
                } label: {
                    HStack {
                        Text(l10n.checkUpdate)
                        Spacer()
                        if updateManager.isChecking {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .disabled(updateManager.isChecking)
            }
            
            // 开发信息
            Section(l10n.developerInfo) {
                HStack {
                    Text(l10n.developer)
                    Spacer()
                    Text("iTango Team")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text(l10n.copyright)
                    Spacer()
                    Text("© 2025 ZJC")
                        .foregroundColor(.secondary)
                }
            }
            
            // 相关链接
            Section(l10n.relatedLinks) {
                Link(destination: URL(string: "https://itango.tencent.com")!) {
                    HStack {
                        Label(l10n.officialWebsite, systemImage: "globe")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(.secondary)
                    }
                }
                .foregroundColor(.primary)
            }
        }
        .navigationTitle(l10n.about)
        .navigationBarTitleDisplayMode(.inline)
        .alert(l10n.checkUpdate, isPresented: $showUpdateResult) {
            Button(l10n.confirm) { }
        } message: {
            Text(updateResultMessage)
        }
    }
    
    private func checkForUpdate() {
        Task {
            let result = await updateManager.checkUpdate(showAlertIfNoUpdate: true)
            
            switch result {
            case .noUpdate:
                updateResultMessage = l10n.alreadyLatestVersion
                showUpdateResult = true
            case .error(let message):
                updateResultMessage = "\(l10n.checkUpdateFailed): \(message)"
                showUpdateResult = true
            case .optionalUpdate, .forceUpdate:
                // 会自动显示更新弹窗
                break
            }
        }
    }
}

#Preview {
    NavigationStack {
        AboutView()
            .environmentObject(LanguageManager.shared)
    }
}
