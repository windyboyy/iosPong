//
//  DeviceInfoManager.swift
//  Pong
//
//  Created by 张金琛 on 2025/12/14.
//

import Foundation
import UIKit
import Network
import CoreTelephony
internal import Combine

// MARK: - 设备信息管理器
@MainActor
class DeviceInfoManager: ObservableObject {
    static let shared = DeviceInfoManager()
    
    @Published var deviceInfo: DeviceInfo?
    @Published var ipInfo: IPInfoResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var networkStatus: NetworkStatus = .unknown
    
    private let networkMonitor = NetworkMonitor()
    
    private init() {
        networkMonitor.start { [weak self] status in
            Task { @MainActor in
                guard let self = self else { return }
                let oldStatus = self.networkStatus
                self.networkStatus = status
                
                // 网络状态变化时，刷新设备信息（包括 IP 地址）
                if oldStatus != status || self.deviceInfo == nil {
                    self.deviceInfo = self.getLocalDeviceInfo()
                }
            }
        }
    }
    
    deinit {
        networkMonitor.stop()
    }
    
    // MARK: - 获取所有信息
    func fetchAllInfo() async {
        isLoading = true
        errorMessage = nil
        
        // 刷新本地设备信息
        deviceInfo = getLocalDeviceInfo()
        
        // 异步获取 IP 归属地信息（不阻塞 UI）
        do {
            ipInfo = try await IPInfoManager.shared.fetchIPInfo()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - 仅获取 IP 信息（用于首次加载）
    func fetchIPInfoOnly() async {
        guard ipInfo == nil else { return }
        isLoading = true
        errorMessage = nil
        
        do {
            ipInfo = try await IPInfoManager.shared.fetchIPInfo()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - 获取本地设备信息
    private func getLocalDeviceInfo() -> DeviceInfo {
        let device = UIDevice.current
        let ipAddresses = getLocalIPAddresses()
        
        return DeviceInfo(
            deviceName: device.name,
            deviceModel: getDeviceModelName(),
            systemName: device.systemName,
            systemVersion: device.systemVersion,
            deviceIdentifier: getDeviceIdentifier(),
            localIPAddress: ipAddresses.ipv4,
            localIPv6Address: ipAddresses.ipv6,
            wifiSSID: getWiFiSSID(),
            carrierName: getCarrierName(),
            batteryLevel: getBatteryLevel(),
            batteryState: getBatteryState(),
            diskSpace: getDiskSpace(),
            memoryUsage: getMemoryUsage()
        )
    }
    
    // MARK: - 获取设备型号名称
    private func getDeviceModelName() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return mapToDeviceName(identifier: identifier)
    }
    
    private func mapToDeviceName(identifier: String) -> String {
        let deviceMap: [String: String] = [
            // iPhone
            "iPhone14,2": "iPhone 13 Pro",
            "iPhone14,3": "iPhone 13 Pro Max",
            "iPhone14,4": "iPhone 13 mini",
            "iPhone14,5": "iPhone 13",
            "iPhone14,6": "iPhone SE (3rd)",
            "iPhone14,7": "iPhone 14",
            "iPhone14,8": "iPhone 14 Plus",
            "iPhone15,2": "iPhone 14 Pro",
            "iPhone15,3": "iPhone 14 Pro Max",
            "iPhone15,4": "iPhone 15",
            "iPhone15,5": "iPhone 15 Plus",
            "iPhone16,1": "iPhone 15 Pro",
            "iPhone16,2": "iPhone 15 Pro Max",
            "iPhone17,1": "iPhone 16 Pro",
            "iPhone17,2": "iPhone 16 Pro Max",
            "iPhone17,3": "iPhone 16",
            "iPhone17,4": "iPhone 16 Plus",
            // iPad
            "iPad13,18": "iPad (10th)",
            "iPad13,19": "iPad (10th)",
            "iPad14,3": "iPad Pro 11-inch (4th)",
            "iPad14,4": "iPad Pro 11-inch (4th)",
            "iPad14,5": "iPad Pro 12.9-inch (6th)",
            "iPad14,6": "iPad Pro 12.9-inch (6th)",
            // Simulator
            "x86_64": "Simulator",
            "arm64": "Simulator"
        ]
        return deviceMap[identifier] ?? identifier
    }
    
    // MARK: - 获取设备标识符
    private func getDeviceIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        return machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
    }
    
    // MARK: - 获取本地 IP 地址（IPv4 和 IPv6）
    /// 严格只返回当前活跃网络接口的 IP 地址，不使用其他接口的地址作为备用
    private func getLocalIPAddresses() -> (ipv4: String?, ipv6: String?) {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return (nil, nil)
        }
        defer { freeifaddrs(ifaddr) }
        
        // 根据当前网络状态决定使用哪个接口
        // WiFi: en0, 蜂窝网络: pdp_ip0
        let activeInterface: String
        switch networkStatus {
        case .wifi:
            activeInterface = "en0"
        case .cellular, .cellular2G, .cellular3G, .cellular4G, .cellular5G:
            activeInterface = "pdp_ip0"
        default:
            // 未知或断开状态时，不返回任何地址
            return (nil, nil)
        }
        
        var ipv4Address: String?
        var ipv6Address: String?
        
        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ptr.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family
            let name = String(cString: interface.ifa_name)
            
            // 只获取活跃接口的地址
            guard name == activeInterface else { continue }
            
            if addrFamily == UInt8(AF_INET) {
                // IPv4
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                           &hostname, socklen_t(hostname.count),
                           nil, socklen_t(0), NI_NUMERICHOST)
                ipv4Address = String(cString: hostname)
            } else if addrFamily == UInt8(AF_INET6) {
                // IPv6
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                           &hostname, socklen_t(hostname.count),
                           nil, socklen_t(0), NI_NUMERICHOST)
                let addr = String(cString: hostname)
                // 过滤掉 link-local 地址 (fe80::)
                if !addr.lowercased().hasPrefix("fe80::") {
                    ipv6Address = addr
                }
            }
        }
        
        return (ipv4Address, ipv6Address)
    }
    
    // MARK: - 获取 WiFi SSID
    private func getWiFiSSID() -> String? {
        // iOS 14+ 需要位置权限才能获取 SSID
        // 这里返回 nil，实际使用需要申请权限
        return nil
    }
    
    // MARK: - 获取运营商名称
    private func getCarrierName() -> String? {
        // iOS 16+ CoreTelephony 已废弃，返回 nil
        return nil
    }
    
    // MARK: - 获取电池电量
    private func getBatteryLevel() -> Float {
        UIDevice.current.isBatteryMonitoringEnabled = true
        return UIDevice.current.batteryLevel
    }
    
    // MARK: - 获取电池状态
    private func getBatteryState() -> String {
        UIDevice.current.isBatteryMonitoringEnabled = true
        switch UIDevice.current.batteryState {
        case .unknown: return "未知"
        case .unplugged: return "未充电"
        case .charging: return "充电中"
        case .full: return "已充满"
        @unknown default: return "未知"
        }
    }
    
    // MARK: - 获取磁盘空间
    private func getDiskSpace() -> (total: Int64, free: Int64)? {
        do {
            let attrs = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
            if let total = attrs[.systemSize] as? Int64,
               let free = attrs[.systemFreeSize] as? Int64 {
                return (total, free)
            }
        } catch {
            print("获取磁盘空间失败: \(error)")
        }
        return nil
    }
    
    // MARK: - 获取内存使用情况
    private func getMemoryUsage() -> (used: UInt64, total: UInt64)? {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let total = ProcessInfo.processInfo.physicalMemory
            return (info.resident_size, total)
        }
        return nil
    }
}

// MARK: - 设备信息模型
struct DeviceInfo {
    let deviceName: String
    let deviceModel: String
    let systemName: String
    let systemVersion: String
    let deviceIdentifier: String
    let localIPAddress: String?
    let localIPv6Address: String?
    let wifiSSID: String?
    let carrierName: String?
    let batteryLevel: Float
    let batteryState: String
    let diskSpace: (total: Int64, free: Int64)?
    let memoryUsage: (used: UInt64, total: UInt64)?
    
    var systemFullName: String {
        "\(systemName) \(systemVersion)"
    }
    
    var diskSpaceDescription: String {
        guard let disk = diskSpace else { return "未知" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB]
        formatter.countStyle = .file
        let total = formatter.string(fromByteCount: disk.total)
        let free = formatter.string(fromByteCount: disk.free)
        return "\(free) / \(total) 可用"
    }
    
    var memoryDescription: String {
        guard let memory = memoryUsage else { return "未知" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .memory
        let used = formatter.string(fromByteCount: Int64(memory.used))
        let total = formatter.string(fromByteCount: Int64(memory.total))
        return "\(used) / \(total)"
    }
    
    var batteryDescription: String {
        if batteryLevel < 0 {
            return "未知"
        }
        return String(format: "%.0f%% (%@)", batteryLevel * 100, batteryState)
    }
}

// MARK: - 网络状态枚举
enum NetworkStatus: String {
    case unknown = "未知"
    case disconnected = "无网络"
    case wifi = "WiFi"
    case cellular = "蜂窝网络"
    case cellular2G = "2G"
    case cellular3G = "3G"
    case cellular4G = "4G"
    case cellular5G = "5G"
    case ethernet = "有线网络"
    case other = "其他"
    
    var displayName: String {
        return rawValue
    }
    
    func localizedName(_ l10n: L10n) -> String {
        switch self {
        case .unknown: return l10n.networkUnknown
        case .disconnected: return l10n.networkDisconnected
        case .wifi: return l10n.networkWifi
        case .cellular: return l10n.networkCellular
        case .cellular2G: return "2G"
        case .cellular3G: return "3G"
        case .cellular4G: return "4G"
        case .cellular5G: return "5G"
        case .ethernet: return l10n.networkEthernet
        case .other: return l10n.networkOther
        }
    }
    
    var icon: String {
        switch self {
        case .unknown: return "questionmark.circle"
        case .disconnected: return "wifi.slash"
        case .wifi: return "wifi"
        case .cellular, .cellular2G, .cellular3G, .cellular4G, .cellular5G: return "antenna.radiowaves.left.and.right"
        case .ethernet: return "cable.connector"
        case .other: return "network"
        }
    }
    
    /// 是否是蜂窝网络（移动数据）
    var isCellular: Bool {
        switch self {
        case .cellular, .cellular2G, .cellular3G, .cellular4G, .cellular5G:
            return true
        default:
            return false
        }
    }
    
    /// 预估测速流量消耗（MB）
    /// 基于网络类型估算：下载10秒 + 上传10秒
    var estimatedDataUsage: (download: Int, upload: Int, total: Int) {
        let downloadMbps: Int
        let uploadMbps: Int
        
        switch self {
        case .cellular2G:
            downloadMbps = 1
            uploadMbps = 1
        case .cellular3G:
            downloadMbps = 10
            uploadMbps = 5
        case .cellular4G, .cellular:
            downloadMbps = 100
            uploadMbps = 20
        case .cellular5G:
            downloadMbps = 300
            uploadMbps = 50
        case .wifi:
            downloadMbps = 100
            uploadMbps = 20
        case .ethernet:
            downloadMbps = 500
            uploadMbps = 100
        default:
            downloadMbps = 50
            uploadMbps = 10
        }
        
        // 流量 = 速度(Mbps) × 时间(秒) ÷ 8 = MB
        let downloadMB = downloadMbps * 10 / 8
        let uploadMB = uploadMbps * 10 / 8
        return (downloadMB, uploadMB, downloadMB + uploadMB)
    }
}

// MARK: - 网络监控器（非隔离）
final class NetworkMonitor: @unchecked Sendable {
    private var pathMonitor: NWPathMonitor?
    private let monitorQueue = DispatchQueue(label: "com.pong.networkmonitor")
    
    func start(onStatusChange: @escaping (NetworkStatus) -> Void) {
        pathMonitor = NWPathMonitor()
        pathMonitor?.pathUpdateHandler = { path in
            let status = self.determineNetworkStatus(path: path)
            onStatusChange(status)
        }
        pathMonitor?.start(queue: monitorQueue)
        
        // 立即获取当前网络状态，避免初始状态为 unknown
        if let currentPath = pathMonitor?.currentPath {
            let status = determineNetworkStatus(path: currentPath)
            onStatusChange(status)
        }
    }
    
    func stop() {
        pathMonitor?.cancel()
        pathMonitor = nil
    }
    
    private func determineNetworkStatus(path: NWPath) -> NetworkStatus {
        if path.status != .satisfied {
            return .disconnected
        }
        
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return getCellularNetworkType()
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .ethernet
        } else {
            return .other
        }
    }
    
    private func getCellularNetworkType() -> NetworkStatus {
        let networkInfo = CTTelephonyNetworkInfo()
        
        guard let radioAccessTechnology = networkInfo.serviceCurrentRadioAccessTechnology?.values.first else {
            return .cellular
        }
        
        switch radioAccessTechnology {
        case CTRadioAccessTechnologyNRNSA, CTRadioAccessTechnologyNR:
            return .cellular5G
        case CTRadioAccessTechnologyLTE:
            return .cellular4G
        case CTRadioAccessTechnologyWCDMA,
             CTRadioAccessTechnologyHSDPA,
             CTRadioAccessTechnologyHSUPA,
             CTRadioAccessTechnologyCDMA1x,
             CTRadioAccessTechnologyCDMAEVDORev0,
             CTRadioAccessTechnologyCDMAEVDORevA,
             CTRadioAccessTechnologyCDMAEVDORevB,
             CTRadioAccessTechnologyeHRPD:
            return .cellular3G
        case CTRadioAccessTechnologyEdge,
             CTRadioAccessTechnologyGPRS:
            return .cellular2G
        default:
            return .cellular
        }
    }
}
