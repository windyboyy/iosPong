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
    
    private var l10n: L10n { L10n.shared }
    
    /// 获取当前版本号
    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    /// 获取 Build 号
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    var body: some View {
        List {
            // App 图标和名称
            Section {
                VStack(spacing: 8) {
                    // App Logo
                    AppLogoView(size: 80, showText: false)
                    
                    // App 名称
                    Text(l10n.appName)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    // 版本信息
                    Text("\(l10n.version) \(currentVersion) (\(buildNumber))")
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
                    Text(currentVersion)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text(l10n.buildNumber)
                    Spacer()
                    Text(buildNumber)
                        .foregroundColor(.secondary)
                }
            }
            
            // 开发信息
            Section(l10n.developerInfo) {
                HStack {
                    Text(l10n.developer)
                    Spacer()
                    Text("ZJC")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text(l10n.copyright)
                    Spacer()
                    Text("© 2025 ZJC")
                        .foregroundColor(.secondary)
                }
            }
            
        }
        .navigationTitle(l10n.about)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AboutView()
            .environmentObject(LanguageManager.shared)
    }
}
