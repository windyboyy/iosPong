//
//  DeviceInfoView.swift
//  Pong
//
//  Created by 张金琛 on 2025/12/14.
//

import SwiftUI

struct DeviceInfoView: View {
    @EnvironmentObject var languageManager: LanguageManager
    @StateObject private var manager = DeviceInfoManager.shared
    @State private var showRefreshToast = false
    @State private var isInitialLoading = true
    
    private var l10n: L10n { L10n.shared }
    
    var body: some View {
        Group {
            if isInitialLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text(l10n.loading)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                contentList
            }
        }
        .navigationTitle(l10n.deviceInfo)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task {
                        await manager.fetchAllInfo()
                        showRefreshToast = true
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                        showRefreshToast = false
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(manager.isLoading || isInitialLoading)
            }
        }
        .task {
            // 短暂延迟让页面先渲染，避免卡顿感
            try? await Task.sleep(nanoseconds: 100_000_000)
            await manager.fetchIPInfoOnly()
            isInitialLoading = false
        }
    }
    
    private var contentList: some View {
        List {
            // IP 归属地信息
            if let ipInfo = manager.ipInfo {
                Section(l10n.publicIPInfo) {
                    InfoRow(title: l10n.publicIP, value: ipInfo.ip ?? l10n.unknown, l10n: l10n)
                    InfoRow(title: l10n.location, value: ipInfo.localizedLocation(l10n), l10n: l10n)
                    if let localizedISP = ipInfo.localizedISP(l10n) {
                        InfoRow(title: l10n.carrier, value: localizedISP, l10n: l10n)
                    }
                }
            } else if manager.isLoading {
                Section(l10n.publicIPInfo) {
                    HStack {
                        ProgressView()
                            .padding(.trailing, 8)
                        Text(l10n.fetching)
                            .foregroundColor(.secondary)
                    }
                }
            } else if manager.errorMessage != nil {
                Section(l10n.publicIPInfo) {
                    InfoRow(title: l10n.publicIP, value: l10n.fetchFailed, l10n: l10n)
                    InfoRow(title: l10n.location, value: l10n.fetchFailed, l10n: l10n)
                    InfoRow(title: l10n.carrier, value: l10n.fetchFailed, l10n: l10n)
                }
            }
            
            // 设备信息
            if let device = manager.deviceInfo {
                Section(l10n.deviceInfoSection) {
                    InfoRow(title: l10n.deviceName, value: device.deviceName, l10n: l10n)
                    InfoRow(title: l10n.deviceModel, value: device.deviceModel, l10n: l10n)
                    InfoRow(title: l10n.deviceIdentifier, value: device.deviceIdentifier, l10n: l10n)
                }
                
                Section(l10n.systemInfo) {
                    InfoRow(title: l10n.systemVersion, value: device.systemFullName, l10n: l10n)
                }
                
                Section(l10n.networkInfo) {
                    HStack {
                        Text(l10n.networkStatus)
                            .foregroundColor(.secondary)
                        Spacer()
                        Image(systemName: manager.networkStatus.icon)
                            .foregroundColor(manager.networkStatus == .disconnected ? .red : .green)
                        Text(manager.networkStatus.localizedName(l10n))
                            .foregroundColor(.primary)
                    }
                    InfoRow(title: l10n.localIPv4, value: device.localIPAddress ?? l10n.notObtained, l10n: l10n)
                    InfoRow(title: l10n.localIPv6, value: device.localIPv6Address ?? l10n.noIPv6, l10n: l10n)
                    if let ssid = device.wifiSSID {
                        InfoRow(title: l10n.wifiName, value: ssid, l10n: l10n)
                    }
                    if let carrier = device.carrierName {
                        InfoRow(title: l10n.carrier, value: carrier, l10n: l10n)
                    }
                }
                
                Section(l10n.hardwareStatus) {
                    InfoRow(title: l10n.battery, value: device.batteryDescription, l10n: l10n)
                    InfoRow(title: l10n.storage, value: device.diskSpaceDescription, l10n: l10n)
                    InfoRow(title: l10n.memoryUsage, value: device.memoryDescription, l10n: l10n)
                }
            }
        }
        .refreshable {
            await manager.fetchAllInfo()
        }
        .overlay(alignment: .top) {
            if showRefreshToast {
                Text(l10n.refreshed)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.75))
                    .cornerRadius(8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 8)
                    .animation(.easeInOut(duration: 0.3), value: showRefreshToast)
            }
        }
    }
}

// MARK: - 信息行组件
struct InfoRow: View {
    let title: String
    let value: String
    let l10n: L10n
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
                .layoutPriority(1)
            Spacer(minLength: 16)
            Text(value)
                .foregroundColor(.primary)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 200, alignment: .trailing)
                .lineLimit(2)
        }
        .contextMenu {
            Button {
                UIPasteboard.general.string = value
            } label: {
                Label(l10n.copyText, systemImage: "doc.on.doc")
            }
        }
    }
}

#Preview {
    NavigationStack {
        DeviceInfoView()
            .environmentObject(LanguageManager.shared)
    }
}
