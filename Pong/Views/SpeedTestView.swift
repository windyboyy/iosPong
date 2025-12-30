//
//  SpeedTestView.swift
//  Pong
//
//  Created by 张金琛 on 2025/12/13.
//

import SwiftUI

struct SpeedTestView: View {
    @EnvironmentObject var languageManager: LanguageManager
    @StateObject private var speedManager = SpeedTestManager.shared
    @State private var showCellularWarning = false
    
    private var l10n: L10n { L10n.shared }
    
    // 获取当前网络状态
    private var networkStatus: NetworkStatus {
        DeviceInfoManager.shared.networkStatus
    }
    
    // 预估流量消耗
    private var estimatedUsage: (download: Int, upload: Int, total: Int) {
        networkStatus.estimatedDataUsage
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 速度仪表盘（包含下载、上传、延迟、抖动）
                SpeedGaugeView(
                    downloadSpeed: speedManager.downloadSpeed,
                    uploadSpeed: speedManager.uploadSpeed,
                    latency: speedManager.latency,
                    jitter: speedManager.jitter,
                    isTesting: speedManager.isTesting,
                    phase: speedManager.currentPhase,
                    progress: speedManager.progress
                )
                
                // 预估流量消耗提示（仅移动网络且未测试时显示）
                if networkStatus.isCellular && !speedManager.isTesting && speedManager.currentPhase != .completed {
                    DataUsageEstimateView(
                        networkStatus: networkStatus,
                        estimatedUsage: estimatedUsage
                    )
                    .padding(.horizontal, 16)
                }
                
                // 测速结果（测速完成后显示）
                if speedManager.currentPhase == .completed && speedManager.downloadSpeed > 0 {
                    SpeedTestResultView(
                        downloadSpeed: speedManager.downloadSpeed,
                        uploadSpeed: speedManager.uploadSpeed,
                        latency: speedManager.latency,
                        isCellular: networkStatus.isCellular
                    )
                    .padding(.horizontal, 16)
                }
                
                // 进度条
                if speedManager.isTesting {
                    VStack(spacing: 8) {
                        ProgressView(value: speedManager.progress)
                            .tint(.blue)
                        Text(speedManager.currentPhase.localizedName(l10n))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 32)
                }
                
                // 错误信息
                if let error = speedManager.error {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
                
                // 测试按钮
                Button(action: {
                    if !speedManager.isTesting {
                        // 如果是移动网络，先显示流量提醒
                        if networkStatus.isCellular {
                            showCellularWarning = true
                        } else {
                            speedManager.startTest()
                        }
                    }
                }) {
                    HStack {
                        if speedManager.isTesting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "play.fill")
                        }
                        Text(speedManager.isTesting ? l10n.testing : l10n.startSpeedTest)
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(speedManager.isTesting ? Color.gray : Color.blue)
                    .cornerRadius(12)
                }
                .disabled(speedManager.isTesting)
                .padding(.horizontal, 32)
                
                // 常用应用延迟
                AppLatencyView()
                    .padding(.horizontal, 16)
                
                // 说明
                Text(l10n.usingCloudflare)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 20)
            }
            .padding(.vertical)
        }
        .navigationTitle(l10n.networkSpeedTest)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // 延迟 1 秒启动应用延迟测试，避免页面加载时卡顿
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                speedManager.startAppLatencyTest()
            }
        }
        .alert(l10n.cellularDataWarning, isPresented: $showCellularWarning) {
            Button(l10n.cancel, role: .cancel) { }
            Button(l10n.continueTest) {
                speedManager.startTest()
            }
        } message: {
            Text("\(l10n.cellularDataWarningMessage)\n\n\(l10n.estimatedDataUsage): ~\(estimatedUsage.total) MB")
        }
    }
}

// MARK: - 速度仪表盘
struct SpeedGaugeView: View {
    @EnvironmentObject var languageManager: LanguageManager
    let downloadSpeed: Double
    let uploadSpeed: Double
    let latency: Double
    let jitter: Double
    let isTesting: Bool
    let phase: SpeedTestManager.TestPhase
    let progress: Double
    
    @State private var rotationAngle: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    
    private var l10n: L10n { L10n.shared }
    
    // 根据阶段获取进度环的颜色
    private var progressGradient: LinearGradient {
        switch phase {
        case .latency:
            return LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
        case .download:
            return LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing)
        case .upload:
            return LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing)
        case .completed:
            return LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing)
        case .idle:
            return LinearGradient(colors: [.gray.opacity(0.3), .gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
        }
    }
    
    // 根据阶段获取显示的进度值（测试进度，非速度）
    private var displayProgress: Double {
        switch phase {
        case .idle:
            return 0
        case .latency, .download, .upload:
            return progress
        case .completed:
            return 1.0  // 测试完成，进度100%
        }
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // 主速度显示
            ZStack {
                // 背景圆环
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                    .frame(width: 200, height: 200)
                
                // 进度圆环
                Circle()
                    .trim(from: 0, to: displayProgress)
                    .stroke(
                        progressGradient,
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: displayProgress)
                
                // 中心速度数字
                VStack(spacing: 4) {
                    if phase == .download {
                        Text(formatSpeed(downloadSpeed))
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .scaleEffect(pulseScale)
                        Text("Mbps")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if phase == .upload {
                        Text(formatSpeed(uploadSpeed))
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .scaleEffect(pulseScale)
                        Text("Mbps")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if phase == .completed {
                        // 测试完成，显示完成图标
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 56))
                            .foregroundColor(.green)
                        Text(l10n.testComplete)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if phase == .latency {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 36))
                            .foregroundColor(.orange)
                            .scaleEffect(pulseScale)
                        Text(l10n.testingLatency)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if isTesting {
                        ProgressView()
                            .scaleEffect(1.5)
                    } else {
                        Text("--")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .onAppear {
                startAnimations()
            }
            .onChange(of: isTesting) { _, newValue in
                if newValue {
                    startAnimations()
                } else {
                    stopAnimations()
                }
            }
            
            // 下载和上传速度
            HStack(spacing: 0) {
                // 下载
                VStack(spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 12, weight: .bold))
                        Text(l10n.download)
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                    
                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text(formatSpeed(downloadSpeed))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                        Text("Mbps")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(formatSpeedMB(downloadSpeed))
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                
                // 分隔线
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 1, height: 50)
                
                // 上传
                VStack(spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 12, weight: .bold))
                        Text(l10n.upload)
                    }
                    .font(.caption)
                    .foregroundColor(.green)
                    
                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text(formatSpeed(uploadSpeed))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                        Text("Mbps")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(formatSpeedMB(uploadSpeed))
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 20)
            
            // 延迟和抖动
            HStack(spacing: 0) {
                // 延迟
                VStack(spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 12, weight: .medium))
                        Text(l10n.latency)
                    }
                    .font(.caption)
                    .foregroundColor(.orange)
                    
                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text(latency > 0 ? String(format: "%.1f", latency) : "--")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                        Text("ms")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                
                // 分隔线
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 1, height: 40)
                
                // 抖动
                VStack(spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "waveform.path")
                            .font(.system(size: 12, weight: .medium))
                        Text(l10n.jitter)
                    }
                    .font(.caption)
                    .foregroundColor(.purple)
                    
                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text(jitter > 0 ? String(format: "%.1f", jitter) : "--")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                        Text("ms")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 20)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    // 启动动画
    private func startAnimations() {
        // 旋转动画
        withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }
        // 脉冲动画
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
            pulseScale = 1.05
        }
    }
    
    // 停止动画
    private func stopAnimations() {
        withAnimation(.easeOut(duration: 0.3)) {
            rotationAngle = 0
            pulseScale = 1.0
        }
    }
    
    private func formatSpeed(_ speed: Double) -> String {
        // 始终保留一位小数，显得更真实
        return String(format: "%.1f", speed)
    }
    
    // Mbps 转换为 MB/s (1 Mbps = 0.125 MB/s)
    private func formatSpeedMB(_ speed: Double) -> String {
        let mbPerSec = speed / 8.0
        if mbPerSec < 1 {
            return String(format: "%.2f MB/s", mbPerSec)
        } else if mbPerSec < 10 {
            return String(format: "%.1f MB/s", mbPerSec)
        } else {
            return String(format: "%.0f MB/s", mbPerSec)
        }
    }
}

// MARK: - TestPhase 本地化扩展
extension SpeedTestManager.TestPhase {
    func localizedName(_ l10n: L10n) -> String {
        switch self {
        case .idle:
            return ""
        case .latency:
            return l10n.latency
        case .download:
            return l10n.download
        case .upload:
            return l10n.upload
        case .completed:
            return l10n.success
        }
    }
}

// MARK: - 网速等级枚举
enum SpeedLevel {
    case slow           // < 20 Mbps
    case level4GNormal  // 20-50 Mbps (4G 普通)
    case level4GGood    // 50-100 Mbps (4G 良好)
    case level5G        // 100-300 Mbps (5G)
    case wiFi100M       // 80-150 Mbps (WiFi 百兆)
    case wiFi500M       // 300-600 Mbps (WiFi 500M)
    case wiFiGigabit    // 600-1000 Mbps (WiFi 千兆)
    case excellent      // > 1000 Mbps (极速网络)
    
    /// 根据下载速度判断网速等级
    static func from(downloadSpeed: Double, isCellular: Bool) -> SpeedLevel {
        if downloadSpeed < 20 {
            return .slow
        } else if downloadSpeed < 50 {
            return isCellular ? .level4GNormal : .slow
        } else if downloadSpeed < 100 {
            return isCellular ? .level4GGood : .wiFi100M
        } else if downloadSpeed < 150 {
            return isCellular ? .level5G : .wiFi100M
        } else if downloadSpeed < 300 {
            return isCellular ? .level5G : .wiFi100M
        } else if downloadSpeed < 600 {
            return isCellular ? .level5G : .wiFi500M
        } else if downloadSpeed < 1000 {
            return .wiFiGigabit
        } else {
            return .excellent
        }
    }
    
    var localizedName: String {
        let l10n = L10n.shared
        switch self {
        case .slow: return l10n.speedLevelSlow
        case .level4GNormal: return l10n.speedLevel4GNormal
        case .level4GGood: return l10n.speedLevel4GGood
        case .level5G: return l10n.speedLevel5G
        case .wiFi100M: return l10n.speedLevelWiFi100M
        case .wiFi500M: return l10n.speedLevelWiFi500M
        case .wiFiGigabit: return l10n.speedLevelWiFiGigabit
        case .excellent: return l10n.speedLevelExcellent
        }
    }
    
    var icon: String {
        switch self {
        case .slow: return "tortoise.fill"
        case .level4GNormal: return "antenna.radiowaves.left.and.right"
        case .level4GGood: return "antenna.radiowaves.left.and.right"
        case .level5G: return "antenna.radiowaves.left.and.right.circle.fill"
        case .wiFi100M: return "wifi"
        case .wiFi500M: return "wifi"
        case .wiFiGigabit: return "wifi.circle.fill"
        case .excellent: return "bolt.horizontal.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .slow: return .red
        case .level4GNormal: return .orange
        case .level4GGood: return .yellow
        case .level5G: return .green
        case .wiFi100M: return .blue
        case .wiFi500M: return .cyan
        case .wiFiGigabit: return .purple
        case .excellent: return .pink
        }
    }
}

// MARK: - 测速结果视图（测速完成后显示）
struct SpeedTestResultView: View {
    let downloadSpeed: Double
    let uploadSpeed: Double
    let latency: Double
    let isCellular: Bool
    
    private var l10n: L10n { L10n.shared }
    
    private var speedLevel: SpeedLevel {
        SpeedLevel.from(downloadSpeed: downloadSpeed, isCellular: isCellular)
    }
    
    // 计算实际流量消耗（基于测速结果）
    private var actualDataUsage: (download: Int, upload: Int, total: Int) {
        // 下载：downloadSpeed (Mbps) × 10秒 ÷ 8 = MB
        let downloadMB = Int(downloadSpeed * 10 / 8)
        // 上传：uploadSpeed (Mbps) × 10秒 ÷ 8 = MB
        let uploadMB = Int(uploadSpeed * 10 / 8)
        return (downloadMB, uploadMB, downloadMB + uploadMB)
    }
    
    var body: some View {
        VStack(spacing: 10) {
            // 网速等级（单行布局）
            HStack {
                Image(systemName: speedLevel.icon)
                    .foregroundColor(speedLevel.color)
                    .font(.title3)
                Text(l10n.speedLevel)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                // 等级标签（显示完整名称）
                Text(speedLevel.localizedName)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(speedLevel.color)
                    .cornerRadius(16)
            }
            
            // 实际流量消耗（仅移动网络显示）
            if isCellular {
                Divider()
                
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                    Text(l10n.actualDataUsage)
                        .font(.caption)
                        .fontWeight(.medium)
                    Spacer()
                    Text("~\(actualDataUsage.total) MB")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(speedLevel.color.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(speedLevel.color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - 预估流量消耗视图
struct DataUsageEstimateView: View {
    let networkStatus: NetworkStatus
    let estimatedUsage: (download: Int, upload: Int, total: Int)
    
    private var l10n: L10n { L10n.shared }
    
    var body: some View {
        VStack(spacing: 12) {
            // 标题
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text(l10n.estimatedDataUsage)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                // 网络类型标签
                HStack(spacing: 4) {
                    Image(systemName: networkStatus.icon)
                        .font(.caption)
                    Text(networkStatus.localizedName(l10n))
                        .font(.caption)
                }
                .foregroundColor(.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.15))
                .cornerRadius(8)
            }
            
            // 流量详情
            HStack(spacing: 0) {
                // 下载
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.caption)
                        Text(l10n.downloadData)
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                    
                    Text("~\(estimatedUsage.download) MB")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                
                // 分隔线
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 1, height: 30)
                
                // 上传
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.caption)
                        Text(l10n.uploadData)
                            .font(.caption)
                    }
                    .foregroundColor(.green)
                    
                    Text("~\(estimatedUsage.upload) MB")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                
                // 分隔线
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 1, height: 30)
                
                // 总计
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "sum")
                            .font(.caption)
                        Text(l10n.totalData)
                            .font(.caption)
                    }
                    .foregroundColor(.orange)
                    
                    Text("~\(estimatedUsage.total) MB")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)
                }
                .frame(maxWidth: .infinity)
            }
            
            // 说明
            Text(l10n.dataUsageNote)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.orange.opacity(0.08))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - 常用应用延迟视图
struct AppLatencyView: View {
    @StateObject private var speedManager = SpeedTestManager.shared
    
    var body: some View {
        VStack(spacing: 16) {
            // 第一分类（腾讯系 / Tech Giants）
            AppLatencySectionView(
                title: speedManager.firstCategoryTitle,
                apps: speedManager.txAppLatencyResults,
                quality: speedManager.txAppLatencyQuality,
                isTesting: speedManager.isTestingAppLatency,
                onRefresh: { speedManager.startAppLatencyTest() }
            )
            
            // 第二分类（其他应用 / Social & Entertainment）
            AppLatencySectionView(
                title: speedManager.secondCategoryTitle,
                apps: speedManager.otherAppLatencyResults,
                quality: speedManager.otherAppLatencyQuality,
                isTesting: speedManager.isTestingAppLatency,
                onRefresh: nil
            )
            
            // 第三分类（Other - 仅英文模式）
            if speedManager.hasThirdCategory {
                AppLatencySectionView(
                    title: speedManager.thirdCategoryTitle,
                    apps: speedManager.thirdAppLatencyResults,
                    quality: speedManager.thirdAppLatencyQuality,
                    isTesting: speedManager.isTestingAppLatency,
                    onRefresh: nil
                )
            }
        }
    }
}

// MARK: - 应用延迟分组视图
struct AppLatencySectionView: View {
    let title: String
    let apps: [SpeedTestManager.AppLatencyInfo]
    let quality: SpeedTestManager.NetworkQuality
    let isTesting: Bool
    let onRefresh: (() -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题和整体质量
            HStack {
                Text(title)
                    .font(.headline)
                
                Spacer()
                
                if !isTesting && apps.contains(where: { $0.latency != nil }) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(quality.color)
                            .frame(width: 8, height: 8)
                        Text(quality.text)
                            .font(.caption)
                            .foregroundColor(quality.color)
                    }
                }
                
                // 刷新按钮（只在第一个分组显示）
                if let onRefresh = onRefresh {
                    Button(action: onRefresh) {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    .disabled(isTesting)
                }
            }
            
            // 应用列表 - 两列布局
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(apps) { app in
                    AppLatencyCard(app: app, isTesting: isTesting)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - 单个应用延迟卡片
struct AppLatencyCard: View {
    let app: SpeedTestManager.AppLatencyInfo
    let isTesting: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: app.icon)
                .font(.system(size: 16))
                .foregroundColor(app.quality.color)
                .frame(width: 24)
            
            Text(app.name)
                .font(.caption)
                .foregroundColor(.primary)
                .lineLimit(1)
            
            Spacer()
            
            if isTesting && app.latency == nil {
                ProgressView()
                    .scaleEffect(0.6)
            } else if let latency = app.latency {
                Text(LanguageManager.formatLatency(latency))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(app.quality.color)
            } else {
                Text("--")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

#Preview {
    NavigationStack {
        SpeedTestView()
            .environmentObject(LanguageManager.shared)
    }
}
