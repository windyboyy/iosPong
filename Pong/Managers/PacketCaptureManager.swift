//
//  PacketCaptureManager.swift
//  Pong
//
//  Created by 张金琛 on 2025/12/15.
//
//  基于 Network Extension API 的本地 VPN 抓包方案
//  类似 Stream App 的实现方式
//

import Foundation
import NetworkExtension
import Network
import Security
internal import Combine

// MARK: - 数据包模型
struct CapturedPacket: Identifiable {
    let id = UUID()
    let timestamp: Date
    let direction: PacketDirection
    let `protocol`: NetworkProtocol
    let sourceIP: String
    let sourcePort: UInt16
    let destinationIP: String
    let destinationPort: UInt16
    let size: Int
    let payload: Data
    let summary: String
    
    // HTTP 相关
    var httpMethod: String?
    var httpURL: String?
    var httpStatusCode: Int?
    var httpHeaders: [String: String]?
    var httpBody: Data?
    
    enum PacketDirection: String {
        case incoming = "入"
        case outgoing = "出"
        
        var icon: String {
            switch self {
            case .incoming: return "arrow.down.circle.fill"
            case .outgoing: return "arrow.up.circle.fill"
            }
        }
    }
    
    enum NetworkProtocol: String {
        case tcp = "TCP"
        case udp = "UDP"
        case icmp = "ICMP"
        case http = "HTTP"
        case https = "HTTPS"
        case dns = "DNS"
        case unknown = "未知"
        
        var color: String {
            switch self {
            case .tcp: return "orange"
            case .udp: return "green"
            case .icmp: return "purple"
            case .http: return "blue"
            case .https: return "cyan"
            case .dns: return "indigo"
            case .unknown: return "gray"
            }
        }
    }
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }
    
    var hexDump: String {
        return payload.hexDump()
    }
    
    var asciiDump: String {
        return payload.asciiDump()
    }
}

// MARK: - Data 扩展
extension Data {
    func hexDump() -> String {
        var result = ""
        let bytesPerLine = 16
        
        for offset in stride(from: 0, to: count, by: bytesPerLine) {
            result += String(format: "%08x  ", offset)
            
            var hexPart = ""
            var asciiPart = ""
            
            for i in 0..<bytesPerLine {
                if offset + i < count {
                    let byte = self[offset + i]
                    hexPart += String(format: "%02x ", byte)
                    asciiPart += (byte >= 32 && byte < 127) ? String(UnicodeScalar(byte)) : "."
                } else {
                    hexPart += "   "
                }
                
                if i == 7 {
                    hexPart += " "
                }
            }
            
            result += hexPart + " |" + asciiPart + "|\n"
        }
        
        return result
    }
    
    func asciiDump() -> String {
        return String(data: self, encoding: .utf8) ?? String(data: self, encoding: .ascii) ?? "<无法解析>"
    }
}

// MARK: - VPN 状态
enum VPNConnectionStatus: String {
    case disconnected = "未连接"
    case connecting = "连接中"
    case connected = "已连接"
    case disconnecting = "断开中"
    case invalid = "未配置"
    
    var color: String {
        switch self {
        case .connected: return "green"
        case .connecting, .disconnecting: return "orange"
        case .disconnected, .invalid: return "gray"
        }
    }
}

// MARK: - 证书状态
enum CertificateInstallStatus {
    case notInstalled
    case downloaded
    case installed
    case trusted
    
    var description: String {
        switch self {
        case .notInstalled: return "未安装"
        case .downloaded: return "已下载"
        case .installed: return "已安装"
        case .trusted: return "已信任"
        }
    }
    
    var step: Int {
        switch self {
        case .notInstalled: return 0
        case .downloaded: return 1
        case .installed: return 2
        case .trusted: return 3
        }
    }
}

// MARK: - 网络抓包管理器
@MainActor
class PacketCaptureManager: NSObject, ObservableObject {
    static let shared = PacketCaptureManager()
    
    // VPN 状态
    @Published var vpnStatus: VPNConnectionStatus = .invalid
    @Published var isVPNConfigured = false
    @Published var certificateStatus: CertificateInstallStatus = .notInstalled
    
    // 抓包相关
    @Published var isCapturing = false
    @Published var capturedPackets: [CapturedPacket] = []
    @Published var filterProtocol: CapturedPacket.NetworkProtocol?
    @Published var filterKeyword: String = ""
    
    // 统计信息
    @Published var totalPackets: Int = 0
    @Published var totalBytes: Int = 0
    @Published var incomingBytes: Int = 0
    @Published var outgoingBytes: Int = 0
    
    // VPN Manager
    private var vpnManager: NETunnelProviderManager?
    private var vpnStatusObserver: NSObjectProtocol?
    
    // App Group 标识符（用于与 Network Extension 通信）
    let appGroupIdentifier = "group.com.pong.packetcapture"
    
    // Bundle ID
    let tunnelBundleIdentifier = "com.pong.Pong.PacketTunnel"
    
    private override init() {
        super.init()
        Task {
            await loadVPNConfiguration()
        }
    }
    
    deinit {
        if let observer = vpnStatusObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - VPN 配置管理
    
    /// 加载现有 VPN 配置
    func loadVPNConfiguration() async {
        do {
            let managers = try await NETunnelProviderManager.loadAllFromPreferences()
            
            if let existingManager = managers.first(where: {
                ($0.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == tunnelBundleIdentifier
            }) {
                self.vpnManager = existingManager
                self.isVPNConfigured = true
                self.updateVPNStatus(existingManager.connection.status)
                self.observeVPNStatus()
            } else {
                self.isVPNConfigured = false
                self.vpnStatus = .invalid
            }
        } catch {
            print("加载 VPN 配置失败: \(error)")
            self.isVPNConfigured = false
            self.vpnStatus = .invalid
        }
    }
    
    /// 创建并保存 VPN 配置（类似 Stream 的方式）
    func setupVPN() async throws {
        let manager = NETunnelProviderManager()
        
        // 配置本地 VPN 协议
        let protocolConfig = NETunnelProviderProtocol()
        protocolConfig.providerBundleIdentifier = tunnelBundleIdentifier
        protocolConfig.serverAddress = "Pong Local Capture" // 本地抓包，不连接外部服务器
        protocolConfig.providerConfiguration = [
            "appGroup": appGroupIdentifier,
            "mode": "capture"
        ]
        
        // 不验证服务器证书（本地 VPN）
        protocolConfig.disconnectOnSleep = false
        
        manager.protocolConfiguration = protocolConfig
        manager.localizedDescription = "Pong 网络抓包"
        manager.isEnabled = true
        
        // 保存配置（会弹出系统授权对话框）
        try await manager.saveToPreferences()
        try await manager.loadFromPreferences()
        
        self.vpnManager = manager
        self.isVPNConfigured = true
        self.vpnStatus = .disconnected
        self.observeVPNStatus()
    }
    
    /// 删除 VPN 配置
    func removeVPN() async throws {
        guard let manager = vpnManager else { return }
        try await manager.removeFromPreferences()
        self.vpnManager = nil
        self.isVPNConfigured = false
        self.vpnStatus = .invalid
    }
    
    /// 监听 VPN 状态变化
    private func observeVPNStatus() {
        vpnStatusObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: vpnManager?.connection,
            queue: .main
        ) { [weak self] notification in
            guard let connection = notification.object as? NEVPNConnection else { return }
            Task { @MainActor in
                self?.updateVPNStatus(connection.status)
            }
        }
    }
    
    /// 更新 VPN 状态
    private func updateVPNStatus(_ status: NEVPNStatus) {
        switch status {
        case .invalid:
            vpnStatus = .invalid
            isCapturing = false
        case .disconnected:
            vpnStatus = .disconnected
            isCapturing = false
        case .connecting:
            vpnStatus = .connecting
        case .connected:
            vpnStatus = .connected
            isCapturing = true
            addSystemPacket(message: "VPN 已连接，开始抓包...")
        case .reasserting:
            vpnStatus = .connecting
        case .disconnecting:
            vpnStatus = .disconnecting
        @unknown default:
            vpnStatus = .disconnected
        }
    }
    
    // MARK: - VPN 连接控制
    
    /// 开始抓包（启动 VPN）
    func startCapture() async throws {
        // 如果未配置，先配置
        if !isVPNConfigured {
            try await setupVPN()
        }
        
        guard let manager = vpnManager else {
            throw NSError(domain: "PacketCapture", code: -1, userInfo: [NSLocalizedDescriptionKey: "VPN 配置不存在"])
        }
        
        // 确保 VPN 已启用
        if !manager.isEnabled {
            manager.isEnabled = true
            try await manager.saveToPreferences()
        }
        
        // 启动 VPN 隧道
        try manager.connection.startVPNTunnel(options: nil)
    }
    
    /// 停止抓包（断开 VPN）
    func stopCapture() {
        vpnManager?.connection.stopVPNTunnel()
        addSystemPacket(message: "已停止抓包")
    }
    
    // MARK: - CA 证书管理
    
    /// 生成并导出 CA 证书（用于 HTTPS 解密）
    func exportCACertificate() -> URL? {
        // 生成自签名 CA 证书
        guard let certData = generateCACertificate() else {
            return nil
        }
        
        // 保存到临时目录
        let tempDir = FileManager.default.temporaryDirectory
        let certURL = tempDir.appendingPathComponent("PongCA.crt")
        
        do {
            try certData.write(to: certURL)
            return certURL
        } catch {
            print("导出证书失败: \(error)")
            return nil
        }
    }
    
    /// 生成自签名 CA 证书
    private func generateCACertificate() -> Data? {
        // 创建密钥对
        let keyParams: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits as String: 2048
        ]
        
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(keyParams as CFDictionary, &error) else {
            print("生成密钥失败: \(error?.takeRetainedValue().localizedDescription ?? "")")
            return nil
        }
        
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            return nil
        }
        
        // 这里简化处理，实际需要使用 ASN.1 编码生成完整的 X.509 证书
        // 完整实现需要使用 OpenSSL 或第三方库
        
        // 返回一个示例证书数据（实际应用需要完整实现）
        let certPEM = """
        -----BEGIN CERTIFICATE-----
        MIIDXTCCAkWgAwIBAgIJAJC1HiIAZAiUMA0GCSqGSIb3Qw0BBQUAMEUxCzAJBgNV
        BAYTAkFVMRMwEQYDVQQIDApTb21lLVN0YXRlMSEwHwYDVQQKDBhJbnRlcm5ldCBX
        aWRnaXRzIFB0eSBMdGQwHhcNMjQwMTAxMDAwMDAwWhcNMjUwMTAxMDAwMDAwWjBF
        MQswCQYDVQQGEwJBVTETMBEGA1UECAwKU29tZS1TdGF0ZTEhMB8GA1UECgwYSW50
        ZXJuZXQgV2lkZ2l0cyBQdHkgTHRkMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIB
        CgKCAQEA0Z3VS5JJcds3xfn/ygWyF8PbnGy0AHJSEzKMJL5KPtpB8gP5r3kXwDJB
        PongCA Root Certificate
        -----END CERTIFICATE-----
        """
        
        return certPEM.data(using: .utf8)
    }
    
    /// 获取证书安装说明
    func getCertificateInstallInstructions() -> [(step: Int, title: String, description: String, action: String?)] {
        return [
            (1, "下载证书", "点击下方按钮下载 CA 证书到设备", "下载证书"),
            (2, "安装证书", "前往「设置」→「通用」→「VPN与设备管理」→「已下载的描述文件」，点击安装", "打开设置"),
            (3, "信任证书", "前往「设置」→「通用」→「关于本机」→「证书信任设置」，开启对 Pong CA 的完全信任", nil)
        ]
    }
    
    // MARK: - 数据包管理
    
    func clearPackets() {
        capturedPackets.removeAll()
        totalPackets = 0
        totalBytes = 0
        incomingBytes = 0
        outgoingBytes = 0
    }
    
    private func addSystemPacket(message: String) {
        let packet = CapturedPacket(
            timestamp: Date(),
            direction: .incoming,
            protocol: .unknown,
            sourceIP: "系统",
            sourcePort: 0,
            destinationIP: "",
            destinationPort: 0,
            size: 0,
            payload: message.data(using: .utf8) ?? Data(),
            summary: message
        )
        capturedPackets.insert(packet, at: 0)
    }
    
    func addPacket(_ packet: CapturedPacket) {
        capturedPackets.insert(packet, at: 0)
        totalPackets += 1
        totalBytes += packet.size
        
        switch packet.direction {
        case .incoming:
            incomingBytes += packet.size
        case .outgoing:
            outgoingBytes += packet.size
        }
        
        if capturedPackets.count > 1000 {
            capturedPackets.removeLast()
        }
    }
    
    var filteredPackets: [CapturedPacket] {
        var result = capturedPackets
        
        if let proto = filterProtocol {
            result = result.filter { $0.protocol == proto }
        }
        
        if !filterKeyword.isEmpty {
            result = result.filter {
                $0.summary.localizedCaseInsensitiveContains(filterKeyword) ||
                $0.sourceIP.contains(filterKeyword) ||
                $0.destinationIP.contains(filterKeyword) ||
                ($0.httpURL?.localizedCaseInsensitiveContains(filterKeyword) ?? false)
            }
        }
        
        return result
    }
    
    static func formatBytes(_ bytes: Int) -> String {
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024)
        } else {
            return String(format: "%.2f MB", Double(bytes) / 1024 / 1024)
        }
    }
    
    func exportPackets() -> String {
        var output = "# Pong 网络抓包记录\n"
        output += "# 导出时间: \(Date())\n"
        output += "# 总数据包: \(totalPackets)\n"
        output += "# 总流量: \(PacketCaptureManager.formatBytes(totalBytes))\n\n"
        
        for packet in capturedPackets.reversed() {
            output += "[\(packet.formattedTime)] "
            output += "[\(packet.protocol.rawValue)] "
            output += "\(packet.direction.rawValue) "
            output += "\(packet.sourceIP):\(packet.sourcePort) -> "
            output += "\(packet.destinationIP):\(packet.destinationPort) "
            output += "(\(packet.size) bytes)\n"
            
            if let url = packet.httpURL {
                output += "  URL: \(url)\n"
            }
            if let method = packet.httpMethod {
                output += "  Method: \(method)\n"
            }
            if let status = packet.httpStatusCode {
                output += "  Status: \(status)\n"
            }
            output += "\n"
        }
        
        return output
    }
    
    // MARK: - 从 Network Extension 读取数据
    
    /// 定时从 App Group 读取抓包数据
    func loadPacketsFromExtension() {
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            return
        }
        
        if let packetsData = sharedDefaults.data(forKey: "capturedPackets"),
           let packets = try? JSONDecoder().decode([SharedPacketData].self, from: packetsData) {
            
            for packetData in packets {
                let packet = CapturedPacket(
                    timestamp: packetData.timestamp,
                    direction: packetData.isOutgoing ? .outgoing : .incoming,
                    protocol: detectProtocol(port: packetData.destinationPort, data: packetData.payload),
                    sourceIP: packetData.sourceIP,
                    sourcePort: packetData.sourcePort,
                    destinationIP: packetData.destinationIP,
                    destinationPort: packetData.destinationPort,
                    size: packetData.payload.count,
                    payload: packetData.payload,
                    summary: buildSummary(packetData)
                )
                addPacket(packet)
            }
            
            // 清除已读取的数据
            sharedDefaults.removeObject(forKey: "capturedPackets")
        }
    }
    
    private func detectProtocol(port: UInt16, data: Data) -> CapturedPacket.NetworkProtocol {
        switch port {
        case 80: return .http
        case 443: return .https
        case 53: return .dns
        default: return .tcp
        }
    }
    
    private func buildSummary(_ packet: SharedPacketData) -> String {
        let proto = detectProtocol(port: packet.destinationPort, data: packet.payload)
        switch proto {
        case .http, .https:
            return "\(packet.destinationIP):\(packet.destinationPort)"
        case .dns:
            return "DNS \(packet.destinationIP)"
        default:
            return "\(packet.sourceIP) → \(packet.destinationIP)"
        }
    }
}

// MARK: - 用于与 Extension 共享的数据结构
struct SharedPacketData: Codable {
    let timestamp: Date
    let isOutgoing: Bool
    let sourceIP: String
    let sourcePort: UInt16
    let destinationIP: String
    let destinationPort: UInt16
    let payload: Data
}
