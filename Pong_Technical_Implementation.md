# Pong (iTango 网络探测) - 技术实现文档

## 目录

- [一、项目概述](#一项目概述)
- [二、功能模块架构](#二功能模块架构)
  - [2.1 项目结构](#21-项目结构)
  - [2.2 动态 Tab 配置](#22-动态-tab-配置)
- [三、Tab 1 - 本地测 (Local)](#三tab-1---本地测-local)
  - [3.1 Ping 测试](#31-ping-测试)
  - [3.2 Traceroute 路由追踪](#32-traceroute-路由追踪)
  - [3.3 DNS 查询](#33-dns-查询)
  - [3.4 TCP 端口测试](#34-tcp-端口测试)
  - [3.5 UDP 测试](#35-udp-测试)
  - [3.6 HTTP GET 测试](#36-http-get-测试)
  - [3.7 网速测试](#37-网速测试)
  - [3.8 设备信息](#38-设备信息)
  - [3.9 一键诊断](#39-一键诊断)
- [四、Tab 2 - 云探测 (Cloud)](#四tab-2---云探测-cloud)
  - [4.1 API 概述](#41-api-概述)
  - [4.2 获取探针列表 API](#42-获取探针列表-api)
  - [4.3 创建探测任务 API](#43-创建探测任务-api)
  - [4.4 查询任务结果 API](#44-查询任务结果-api)
- [五、Tab 3 - IP查询 (IPQuery)](#五tab-3---ip查询-ipquery)
  - [5.1 功能概述](#51-功能概述)
  - [5.2 技术实现](#52-技术实现)
  - [5.3 历史记录管理](#53-历史记录管理)
- [六、Tab 4 - 数据 (Data)](#六tab-4---数据-data)
  - [6.1 技术方案](#61-技术方案)
  - [6.2 架构设计](#62-架构设计)
  - [6.3 告警数据 API](#63-告警数据-api)
  - [6.4 数据转换逻辑](#64-数据转换逻辑)
  - [6.5 WebView 通信机制](#65-webview-通信机制)
  - [6.6 外部资源依赖](#66-外部资源依赖)
  - [6.7 省份坐标映射](#67-省份坐标映射)
  - [6.8 ECharts 配置](#68-echarts-配置)
  - [6.9 错误处理](#69-错误处理)
  - [6.10 功能特性](#610-功能特性)
  - [6.11 告警时间格式化](#611-告警时间格式化)
- [七、Tab 5 - 我的 (Profile)](#七tab-5---我的-profile)
  - [7.1 用户系统](#71-用户系统)
  - [7.2 历史记录](#72-历史记录)
  - [7.3 用户反馈](#73-用户反馈)
- [七、APP 更新](#七app-更新)
  - [7.1 更新检查机制](#71-更新检查机制)
  - [7.2 检查版本更新 API](#72-检查版本更新-api)
  - [7.3 版本比较逻辑](#73-版本比较逻辑)
  - [7.4 更新判断流程](#74-更新判断流程)
  - [7.5 本地存储](#75-本地存储)
- [八、公共服务](#八公共服务)
  - [8.1 网络服务](#81-网络服务)
  - [8.2 IP 归属地服务](#82-ip-归属地服务)
  - [8.3 多语言支持](#83-多语言支持)
  - [8.4 主机历史记录管理](#84-主机历史记录管理)
- [九、数据模型](#九数据模型)
  - [9.1 Ping 结果模型](#91-ping-结果模型)
  - [9.2 DNS 结果模型](#92-dns-结果模型)
  - [9.3 Traceroute 跳点模型](#93-traceroute-跳点模型)
- [十、鉴权配置](#十鉴权配置)

---

## 一、项目概述

**项目名称**: Pong (iTango 网络探测)  
**平台**: iOS (SwiftUI)  
**架构**: MVVM + 单例管理器模式  
**语言支持**: 中文/英文双语  
**安装包大小**: ~1.8MB（App Store 下载大小）

---

## 二、功能模块架构

### 2.1 项目结构

```
Pong/
├── PongApp.swift              # 应用入口
├── ContentView.swift          # 主视图（TabView 容器）
├── Models/                    # 数据模型层
├── Views/                     # 视图层
├── ViewModels/                # 视图模型层
├── Managers/                  # 业务管理器层（核心逻辑）
├── Services/                  # 网络服务层
└── Assets.xcassets/           # 资源文件
```

### 2.2 动态 Tab 配置

**实现文件**: `Managers/TabConfigManager.swift`, `ContentView.swift`

#### 2.2.1 功能概述

底部 Tab 栏支持通过 API 接口动态配置，可以控制：
- 显示哪些 Tab
- Tab 的排列顺序
- 是否启用某个 Tab

#### 2.2.2 Tab 类型定义

```swift
enum AppTab: String, CaseIterable {
    case localProbe = "localProbe"   // 本地探测
    case cloudProbe = "cloudProbe"   // 云拨测
    case ipQuery = "ipQuery"         // IP 查询
    case data = "data"               // 数据
    case profile = "profile"         // 我的
}
```

#### 2.2.3 配置刷新策略

| 时机 | 行为 | 说明 |
|------|------|------|
| **App 冷启动** | ✅ 每次刷新 | 杀死 App 后重新打开 |
| **从后台回到前台** | ⏱️ 超过 5 分钟才刷新 | 避免频繁切换时重复请求 |
| **5 分钟内切回前台** | ❌ 不刷新 | 使用缓存，节省流量 |

**配置参数**:
```swift
// 从后台恢复刷新间隔 - 5 分钟
private let foregroundRefreshInterval: TimeInterval = 300
```

#### 2.2.4 缓存机制

**存储方式**: `UserDefaults`

**缓存 Key**:
| Key | 说明 |
|-----|------|
| `cachedTabConfig` | Tab 配置数据（JSON） |
| `tabConfigVersion` | 配置版本号 |
| `tabConfigLastFetchTime` | 上次获取配置的时间戳 |
| `tabConfigLastBackgroundTime` | 上次进入后台的时间戳 |

**缓存加载流程**:
```
App 启动
    ↓
同步加载本地缓存 (loadCachedConfig)
    ↓
├── 有缓存 → 使用缓存配置渲染 UI
└── 无缓存 → 使用默认配置 (AppTab.allCases)
    ↓
异步请求 API 刷新配置
    ↓
├── 成功 → 更新 UI + 保存缓存
└── 失败 → 保持当前配置不变
```

**无缓存时的默认配置**:
```swift
// 没有缓存时，显示所有 Tab（按枚举定义顺序）
enabledTabs = AppTab.allCases
// 即: [localProbe, cloudProbe, ipQuery, data, profile]
```

**缓存读写实现**:
```swift
/// 从缓存加载配置（同步方法，确保初始化时立即可用）
private func loadCachedConfig() {
    guard let data = userDefaults.data(forKey: cachedConfigKey),
          let config = try? JSONDecoder().decode(TabConfigData.self, from: data) else {
        // 没有缓存，使用默认配置
        enabledTabs = AppTab.allCases
        return
    }
    
    enabledTabs = parseConfig(config)
    configVersion = config.version
}

/// 缓存配置
private func cacheConfig(_ config: TabConfigData) {
    if let encoded = try? JSONEncoder().encode(config) {
        userDefaults.set(encoded, forKey: cachedConfigKey)
        userDefaults.set(config.version, forKey: configVersionKey)
        userDefaults.set(Date().timeIntervalSince1970, forKey: lastFetchTimeKey)
    }
}
```

**降级策略**:
| 场景 | 行为 |
|------|------|
| 首次安装，无缓存 | 显示所有 Tab，等待 API 返回 |
| 有缓存，API 成功 | 使用 API 配置，更新缓存 |
| 有缓存，API 失败 | 保持缓存配置不变 |
| 无缓存，API 失败 | 保持默认配置（所有 Tab） |

#### 2.2.5 获取 Tab 配置 API

**URL**: `POST https://api.itango.tencent.com/api`

**鉴权**: HMAC-SHA-512

**请求体**:
```json
{
    "Action": "App",
    "Method": "GetAppConfig",
    "SystemId": 4,
    "AppendInfo": {
        "UserId": 123  // 当前用户 ID，未登录为 -1
    },
    "Data": {
        "Platform": "iOS",
        "AppVersion": "1.0.0"
    }
}
```

**Platform 可选值**:

| 平台 | 说明 |
|------|------|
| `iOS` | iPhone |
| `iPadOS` | iPad |
| `macOS` | Mac 原生应用 |
| `macCatalyst` | iPad 应用在 Mac 上运行 |
| `watchOS` | Apple Watch |
| `tvOS` | Apple TV |
| `visionOS` | Apple Vision Pro |
| `Android` | Android 手机 |
| `AndroidTablet` | Android 平板 |

**响应体**:
```json
{
    "Return": 0,
    "Details": "",
    "ReqId": "centralservicedf7zxsixknix5b",
    "Data": {
        "tabs": [
            {
                "id": "localProbe",
                "enabled": true,
                "order": 0,
                "icon": null,
                "title": null
            },
            {
                "id": "cloudProbe",
                "enabled": true,
                "order": 1,
                "icon": null,
                "title": null
            },
            {
                "id": "ipQuery",
                "enabled": true,
                "order": 2,
                "icon": null,
                "title": null
            },
            {
                "id": "data",
                "enabled": true,
                "order": 3,
                "icon": null,
                "title": null
            },
            {
                "id": "profile",
                "enabled": true,
                "order": 4,
                "icon": null,
                "title": null
            }
        ],
        "updateTime": "2025-12-26 16:13:53",
        "version": "1.0.0"
    }
}
```

**Tab 配置字段说明**:

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | String | Tab 标识符，对应 `AppTab` 的 rawValue |
| `enabled` | Bool | 是否启用该 Tab |
| `order` | Int | 排序顺序，数字越小越靠前 |
| `icon` | String? | 自定义图标名称（可选，为空使用默认） |
| `title` | String? | 自定义标题（可选，为空使用默认） |

#### 2.2.6 配置解析逻辑

```swift
/// 解析配置，返回排序后的 Tab 数组
private func parseConfig(_ config: TabConfigData) -> [AppTab] {
    let sortedTabs = config.tabs
        .filter { $0.enabled }           // 1. 过滤启用的 Tab
        .sorted { $0.order < $1.order }  // 2. 按 order 排序
        .compactMap { tabConfig -> AppTab? in
            AppTab(rawValue: tabConfig.id)  // 3. 转换为 AppTab 枚举
        }
    
    // 如果配置为空，使用默认配置（显示所有 Tab）
    return sortedTabs.isEmpty ? AppTab.allCases : sortedTabs
}
```

#### 2.2.7 生命周期监听

```swift
// 监听 App 进入后台
NotificationCenter.default.addObserver(
    forName: UIApplication.didEnterBackgroundNotification,
    object: nil,
    queue: .main
) { _ in
    // 记录进入后台的时间
    self.userDefaults.set(Date().timeIntervalSince1970, forKey: lastBackgroundTimeKey)
}

// 监听 App 回到前台
NotificationCenter.default.addObserver(
    forName: UIApplication.willEnterForegroundNotification,
    object: nil,
    queue: .main
) { _ in
    // 检查是否需要刷新配置
    Task { await self.refreshOnForeground() }
}
```

---

## 三、Tab 1 - 本地测 (Local)

### 3.1 Ping 测试

**实现文件**: `Managers/PingManager.swift`

**技术方案**:
- **协议**: 原生 ICMP (IPv4) / ICMPv6 (IPv6)
- **框架**: Darwin BSD Socket API
- **Socket 类型**: `SOCK_DGRAM` + `IPPROTO_ICMP` / `IPPROTO_ICMPV6`
- **超时**: 2 秒

**工作原理**:
```swift
// IPv4 ICMP Socket（无需 root 权限）
let sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP)

// 设置接收超时
var tv = timeval(tv_sec: Int(timeout), tv_usec: 0)
setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

// 构建 ICMP Echo Request 包
// Type: 8 (Echo Request), Code: 0
packet[0] = 8  // Type
packet[1] = 0  // Code
// Identifier + Sequence + Checksum + Payload

// 发送并等待 ICMP Echo Reply (type 0)
sendto(sock, &icmpPacket, icmpPacket.count, 0, sockaddrPtr, ...)
recvfrom(sock, &recvBuffer, recvBuffer.count, 0, sockaddrPtr, ...)

// 验证响应的 identifier 和 sequence 是否匹配
if recvIdentifier == identifier && recvSequence == sequence {
    return (true, latency, nil)
}
```

**IPv6 支持**:
```swift
// IPv6 ICMPv6 Socket
let sock = socket(AF_INET6, SOCK_DGRAM, IPPROTO_ICMPV6)

// ICMPv6 Echo Request: Type 128
// ICMPv6 Echo Reply: Type 129
packet[0] = 128  // Type

// 内核自动计算 ICMPv6 校验和
```

**协议自动切换**:
```swift
private func resolveHost(_ host: String) -> (ip: String?, version: IPVersion) {
    // 1. 检查是否已经是 IPv6 地址
    if inet_pton(AF_INET6, host, &addr6) == 1 {
        return (host, .ipv6)  // 直接使用 IPv6
    }
    
    // 2. 检查是否已经是 IPv4 地址
    if inet_pton(AF_INET, host, &addr4) == 1 {
        return (host, .ipv4)  // 直接使用 IPv4
    }
    
    // 3. DNS 解析 - 优先 IPv4
    hints.ai_family = AF_INET
    if getaddrinfo(...) == 0 {
        return (ipv4Address, .ipv4)
    }
    
    // 4. IPv4 解析失败，尝试 IPv6
    hints.ai_family = AF_INET6
    if getaddrinfo(...) == 0 {
        return (ipv6Address, .ipv6)
    }
    
    return (nil, .ipv4)  // 解析失败
}
```

**ICMP 校验和计算**:
```swift
private func icmpChecksum(_ data: [UInt8]) -> UInt16 {
    var sum: UInt32 = 0
    var i = 0
    
    while i < data.count - 1 {
        sum += UInt32(data[i]) | (UInt32(data[i + 1]) << 8)
        i += 2
    }
    
    if i < data.count {
        sum += UInt32(data[i])
    }
    
    while sum >> 16 != 0 {
        sum = (sum & 0xFFFF) + (sum >> 16)
    }
    
    return ~UInt16(sum & 0xFFFF)
}
```

**可配置参数**:
- 发包大小: 56 \/ 128 \/ 512 \/ 1024 字节（实际 payload 大小）
- 发包间隔: 0.2s \/ 0.5s \/ 1s \/ 2s
- 最大次数: 200 次

**统计指标**:
- 发送数 \/ 接收数 \/ 丢失数
- 丢包率 (%)
- 最小/平均/最大延迟 (ms)
- 标准差 (ms)

**ICMP 响应类型处理**:
| ICMP Type | 名称 | 处理方式 |
|-----------|------|----------|
| 0 | Echo Reply | 成功，验证 identifier + sequence |
| 3 | Destination Unreachable | 失败，目标不可达 |
| 其他 | - | 继续等待 |

**ICMPv6 响应类型处理**:
| ICMPv6 Type | 名称 | 处理方式 |
|-------------|------|----------|
| 129 | Echo Reply | 成功，验证 identifier + sequence |
| 1 | Destination Unreachable | 失败，目标不可达 |
| 其他 | - | 继续等待 |

**优势**:
- 真正的 ICMP ping，延迟测量更准确
- 无需 root 权限（macOS/iOS 允许 `SOCK_DGRAM` + `IPPROTO_ICMP`）
- 同时支持 IPv4 和 IPv6
- 支持自定义包大小

---

### 3.2 Traceroute 路由追踪

**实现文件**: `Managers/TraceManager.swift`

**技术方案**:
- **协议**: 原生 ICMP (IPv4) / ICMPv6 (IPv6)
- **框架**: Darwin BSD Socket API
- **Socket 类型**: `SOCK_DGRAM` + `IPPROTO_ICMP` / `IPPROTO_ICMPV6`

**工作原理**:
```swift
// IPv4 ICMP Socket
let sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP)

// 设置 TTL (Time To Live)
var ttlValue = Int32(ttl)
setsockopt(sock, IPPROTO_IP, IP_TTL, &ttlValue, socklen_t(MemoryLayout<Int32>.size))

// 构建 ICMP Echo Request 包
// Type: 8 (Echo Request), Code: 0
packet[0] = 8  // Type
packet[1] = 0  // Code
// Identifier + Sequence + Checksum + Payload

// 发送并等待 ICMP Time Exceeded (type 11) 或 Echo Reply (type 0)
```

**IPv6 支持**:
```swift
// IPv6 ICMPv6 Socket
let sock = socket(AF_INET6, SOCK_DGRAM, IPPROTO_ICMPV6)

// 设置 Hop Limit (IPv6 的 TTL)
var hopLimit = Int32(ttl)
setsockopt(sock, IPPROTO_IPV6, IPV6_UNICAST_HOPS, &hopLimit, ...)

// ICMPv6 Echo Request: Type 128
// ICMPv6 Echo Reply: Type 129
// ICMPv6 Time Exceeded: Type 3
```

**IPv6 可用性检查**:

在执行 IPv6 traceroute 前，会先检查本机是否有 IPv6 地址。如果没有，会返回错误信息并保存失败记录。

```swift
// 如果是 IPv6 traceroute，检查本机是否有 IPv6 地址
if version == .ipv6 {
    if DeviceInfoManager.shared.deviceInfo?.localIPv6Address == nil {
        self.errorMessage = L10n.shared.noLocalIPv6ForTrace
        self.isTracing = false
        // 保存失败的历史记录
        self.saveToHistory()
        return
    }
}
```

**错误处理流程**:
1. 检测到目标是 IPv6 地址或用户选择了 IPv6 协议
2. 检查 `DeviceInfoManager.shared.deviceInfo?.localIPv6Address`
3. 如果为 `nil`，设置错误信息："当前网络无 IPv6 地址，无法进行 IPv6 路由追踪"
4. 保存失败记录到历史任务（状态为 `.failure`）
5. 一键诊断时，错误信息会上报到 `BuildinErrMessage` 字段

**可配置参数**:
- 每跳探测次数: 3 \/ 5 \/ 10 \/ 20
- IP 协议偏好: 系统默认 \/ IPv4 \/ IPv6
- 最大跳数: 30
- 单次超时: 300ms (IPv4) \/ 500ms (IPv6)

**特性**:
- 并发发送探测包（提高效率）
- 反向 DNS 解析（获取主机名）
- 批量 IP 归属地查询

**反向 DNS 解析 (PTR 记录)**:

Traceroute 会对每个跳点的 IP 地址进行反向 DNS 解析，获取其主机名（如路由器名称）。

**技术方案**:
- **框架**: Darwin BSD Socket API
- **API**: `getnameinfo()`
- **用途**: 将 IP 地址解析为主机名（PTR 记录查询）
- **执行方式**: 批量异步并发解析（探测完成后统一解析）

**执行流程**:
```
探测跳 1 → 探测跳 2 → ... → 探测跳 N → 探测完成
                                        ↓
                              批量并发解析所有 PTR (fetchHostnames)
                              ↓
                              获取 IP 归属地
                              ↓
                              保存历史记录
```

**为什么采用批量异步解析**:

| 方式 | 优点 | 缺点 |
|------|------|------|
| **串行解析（每跳解析）** | 实时显示主机名 | 每跳都要等 PTR 解析，总耗时 = 探测时间 + N × PTR 时间 |
| **批量异步解析（当前方案）** | 不阻塞探测，总耗时 = 探测时间 + max(PTR 时间) | 主机名稍后显示 |

**批量解析实现**:
```swift
// MARK: - 批量获取 PTR 主机名
private func fetchHostnames(version: IPVersion) async {
    // 收集所有有效的 IP 地址（排除 "*"）
    let validIPs = hops.enumerated().compactMap { (index, hop) -> (Int, String)? in
        hop.ip != "*" ? (index, hop.ip) : nil
    }
    
    // 并发解析所有 PTR
    await withTaskGroup(of: (Int, String?).self) { group in
        for (index, ip) in validIPs {
            group.addTask {
                let hostname = await self.resolveReverseAsync(ip, version: version)
                return (index, hostname)
            }
        }
        
        // 收集结果并更新 UI
        for await (index, hostname) in group {
            if let hostname = hostname {
                await MainActor.run {
                    self.hops[index].hostname = hostname
                }
            }
        }
    }
}
```

**工作原理**:
```swift
// IPv4 反向解析
var addr = sockaddr_in()
addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
addr.sin_family = sa_family_t(AF_INET)
inet_pton(AF_INET, ip, &addr.sin_addr)

var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))

let result = getnameinfo(
    sockaddrPtr,                              // 地址结构指针
    socklen_t(MemoryLayout<sockaddr_in>.size), // 地址长度
    &hostname,                                 // 主机名缓冲区
    socklen_t(hostname.count),                 // 缓冲区大小
    nil,                                       // 服务名（不需要）
    0,                                         // 服务名长度
    0                                          // flags
)

if result == 0 {
    let name = String(cString: hostname)
    // 如果解析结果与 IP 相同，说明没有 PTR 记录
    return name != ip ? name : nil
}

// IPv6 反向解析
var addr6 = sockaddr_in6()
addr6.sin6_len = UInt8(MemoryLayout<sockaddr_in6>.size)
addr6.sin6_family = sa_family_t(AF_INET6)
inet_pton(AF_INET6, ip, &addr6.sin6_addr)
// 同样使用 getnameinfo() 解析
```

**PTR 记录说明**:
| 场景 | 返回值示例 | 说明 |
|------|-----------|------|
| 路由器有 PTR | `xiaoqiang` | 小米路由器默认主机名 |
| 运营商设备 | `221.183.47.1.static.bjtelecom.net` | 北京电信骨干路由 |
| 无 PTR 记录 | `nil` | 返回空，显示原始 IP |

**常见主机名含义**:
| 主机名关键词 | 含义 |
|-------------|------|
| `xiaoqiang` | 小米路由器 |
| `router`, `gateway` | 网关设备 |
| `core`, `backbone` | 骨干网路由 |
| `bras`, `ppp` | 宽带接入设备 |
| `telecom`, `unicom`, `cmnet` | 运营商设备 |

**PTR 数据存储与上传**:

| 位置 | 是否包含 PTR | 说明 |
|------|-------------|------|
| 实时显示 | ✅ | `TraceHop.hostname` |
| 历史记录存储 | ✅ | `TraceHopDetail.hostname` |
| 历史任务详情显示 | ✅ | IP 下方灰色小字显示 |
| 上传数据 | ✅ | `Hops[].Hostname` 字段 |
| 结果文本 (ResultToText) | ✅ | 表格中 Hostname 列 |

**上传数据结构示例**:
```json
{
    "Hops": [
        {
            "Hop": 1,
            "IP": "192.168.1.1",
            "Hostname": "router.local",
            "AvgLatencyMicro": 1200,
            "LossRate": 0,
            "SentCount": 3,
            "ReceivedCount": 3,
            "Location": "局域网"
        }
    ]
}
```

---

### 3.3 DNS 查询

**实现文件**: `Managers/DNSManager.swift`

**技术方案**:
- **框架**: Apple `dnssd` 框架 (DNS Service Discovery)
- **API**: `DNSServiceQueryRecord()`

**支持的记录类型**:
| 类型 | 常量 | 说明 |
|------|------|------|
| A | `kDNSServiceType_A` | IPv4 地址 |
| AAAA | `kDNSServiceType_AAAA` | IPv6 地址 |
| CNAME | `kDNSServiceType_CNAME` | 别名记录 |
| MX | `kDNSServiceType_MX` | 邮件交换记录 |
| TXT | `kDNSServiceType_TXT` | 文本记录 |
| NS | `kDNSServiceType_NS` | 域名服务器记录 |
| PTR | `kDNSServiceType_PTR` | 反向 DNS 查询（IP → 主机名） |
| 系统默认 | `getaddrinfo()` | 系统 DNS 解析 |

**工作原理**:
```swift
// 使用 dnssd 框架查询
var sdRef: DNSServiceRef?
DNSServiceQueryRecord(
    &sdRef,
    0,                          // flags
    0,                          // interfaceIndex
    domain,                     // 域名
    rrType,                     // 记录类型
    UInt16(kDNSServiceClass_IN),// IN class
    callback,                   // 回调函数
    context
)

// 使用 poll 等待响应（3秒超时）
let fd = DNSServiceRefSockFD(sdRef)
var pollFd = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
poll(&pollFd, 1, 3000)
DNSServiceProcessResult(sdRef)
```

**系统默认解析**:
```swift
// 使用 getaddrinfo 获取系统 DNS 解析结果
var hints = addrinfo()
hints.ai_family = AF_UNSPEC  // IPv4 + IPv6
hints.ai_socktype = SOCK_STREAM
getaddrinfo(domain, nil, &hints, &result)
```

**指定 DNS 服务器查询**:

支持使用指定的 DNS 服务器（如 8.8.8.8、1.1.1.1）进行查询，通过 UDP 直接向 DNS 服务器发送查询包。

```swift
// 创建 UDP socket
let sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)

// 配置目标 DNS 服务器地址（端口 53）
var serverAddr = sockaddr_in()
serverAddr.sin_family = sa_family_t(AF_INET)
serverAddr.sin_port = UInt16(53).bigEndian
inet_pton(AF_INET, server, &serverAddr.sin_addr)

// 构建 DNS 查询包
let queryPacket = buildDNSQuery(domain: domain, recordType: recordType)

// 发送查询并接收响应
sendto(sock, queryPacket, queryPacket.count, 0, sockaddrPtr, ...)
let recvLen = recv(sock, &buffer, buffer.count, 0)

// 解析 DNS 响应
let records = parseDNSResponse(data: responseData, domain: domain, recordType: recordType)
```

**DNS 查询包格式**:
| 字段 | 大小 | 说明 |
|------|------|------|
| Transaction ID | 2 bytes | 随机生成 |
| Flags | 2 bytes | 0x0100 (标准查询，递归请求) |
| Questions | 2 bytes | 1 |
| Answer RRs | 2 bytes | 0 |
| Authority RRs | 2 bytes | 0 |
| Additional RRs | 2 bytes | 0 |
| Question | 变长 | 域名 + QTYPE + QCLASS |

**DNS 响应解析**:
- 支持压缩指针解析（域名压缩）
- 解析 A、AAAA、CNAME、MX、TXT、NS、PTR 等记录类型
- 返回 TTL、记录值等完整信息

**PTR 反向 DNS 查询**:

支持通过 IP 地址查询其对应的主机名（反向 DNS 解析）。

**IP 地址自动转换**:
- IPv4: `8.8.8.8` → `8.8.8.8.in-addr.arpa`
- IPv6: `2001:4860:4860::8888` → `8.8.8.8.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.6.8.4.0.6.8.4.1.0.0.2.ip6.arpa`

```swift
/// 将 IPv4 地址转换为反向 DNS 域名
static func ipToReverseDomain(_ ip: String) -> String? {
    let parts = ip.split(separator: ".")
    if parts.count == 4, parts.allSatisfy({ UInt8($0) != nil }) {
        // IPv4: 反转各段并添加 .in-addr.arpa 后缀
        return parts.reversed().joined(separator: ".") + ".in-addr.arpa"
    }
    
    // IPv6: 展开地址，逐字符反转，添加 .ip6.arpa 后缀
    // ...
}
```

**使用方式**:
1. 选择 PTR 记录类型
2. 输入 IP 地址（如 `8.8.8.8`）
3. 自动转换为反向域名并查询
4. 返回主机名（如 `dns.google`）

---

### 3.4 TCP 端口测试

**实现文件**: `Managers/TCPManager.swift`

**技术方案**:
- **框架**: Apple `Network.framework` (`NWConnection`)
- **协议**: TCP

**工作原理**:
```swift
let connection = NWConnection(to: endpoint, using: .tcp)

connection.stateUpdateHandler = { state in
    switch state {
    case .ready:
        // 端口开放，记录连接延迟
        let latency = Date().timeIntervalSince(startTime)
        isOpen = true
    case .failed:
        // 端口关闭或连接失败
        isOpen = false
    }
}
connection.start(queue: .global())
```

**常用端口列表**:
| 端口 | 服务 |
|------|------|
| 21 | FTP |
| 22 | SSH |
| 23 | Telnet |
| 25 | SMTP |
| 53 | DNS |
| 80 | HTTP |
| 443 | HTTPS |
| 3306 | MySQL |
| 3389 | RDP |
| 6379 | Redis |
| 8080 | HTTP-Alt |

**功能**:
- 单端口测试
- 批量端口扫描（带进度条）
- 连接超时: 3 秒

---

### 3.5 UDP 测试

**实现文件**: `Managers/UDPManager.swift`

**技术方案**:
- **框架**: Apple `Network.framework` (`NWConnection`)
- **协议**: UDP

**工作原理**:
```swift
let connection = NWConnection(to: endpoint, using: .udp)

connection.stateUpdateHandler = { state in
    switch state {
    case .ready:
        // 发送数据
        connection.send(content: data, completion: .contentProcessed { ... })
        
        // 尝试接收响应
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65535) { data, ... in
            // 有响应 = received: true
            // 无响应 = received: false（UDP 无连接，可能正常）
        }
    }
}
```

**常用 UDP 端口**:
| 端口 | 服务 |
|------|------|
| 53 | DNS |
| 67/68 | DHCP |
| 123 | NTP |
| 161 | SNMP |
| 514 | Syslog |
| 5353 | mDNS |

**超时时间**: 3 秒

---

### 3.6 HTTP GET 测试

**实现文件**: `Managers/HTTPManager.swift`

**技术方案**:
- **框架**: `URLSession`
- **协议**: HTTP/HTTPS

**工作原理**:
```swift
var request = URLRequest(url: url)
request.httpMethod = "GET"
request.timeoutInterval = timeout

let (data, response) = try await URLSession.shared.data(for: request)

// 返回：状态码、响应头、响应体、响应时间
```

**常用测试 URL**:
| 名称 | URL |
|------|-----|
| QQ | `https://www.qq.com` |
| Baidu | `https://www.baidu.com` |
| Google | `https://www.google.com` |
| GitHub | `https://api.github.com` |
| httpbin | `https://httpbin.org/get` |

---

### 3.7 网速测试

**实现文件**: `Managers/SpeedTestManager.swift`

**技术方案**:
- **框架**: `URLSession` + `URLSessionDataDelegate`
- **多线程并发**: 下载使用 6 个并发连接，上传使用 4 个并发连接
- **测试时长**: 严格控制为 10 秒（使用定时器任务）
- **多语言支持**: 中英文模式统一使用 Cloudflare 测速服务器

**测试流程**:
1. **延迟测试**: HTTP HEAD 请求（10次），计算平均延迟和抖动
2. **下载测试**: 多线程并发下载（6线程），严格运行 10 秒
3. **上传测试**: 多线程并发上传（4线程），严格运行 10 秒

**数值显示格式**:
- 所有数值统一保留一位小数，显得更真实
- 下载速度：`156.3 Mbps`
- 上传速度：`48.7 Mbps`
- 延迟：`27.5 ms`
- 抖动：`3.2 ms`

#### 3.7.1 延迟和抖动测试

**测试方法**: HTTP HEAD 请求

**测试逻辑**:
1. 向测试 URL 发送 10 次 HTTP HEAD 请求
2. 每次请求间隔 100ms
3. **延迟**：取 10 次测量的**平均值**
4. **抖动**：计算相邻延迟差值绝对值的平均值

```swift
// 延迟计算：平均值
let avgLatency = latencies.reduce(0, +) / Double(latencies.count)

// 抖动计算：相邻延迟差值的绝对值的平均值
var jitterSum: Double = 0
for i in 1..<latencies.count {
    jitterSum += abs(latencies[i] - latencies[i-1])
}
let avgJitter = jitterSum / Double(latencies.count - 1)
```

**实时显示**：测试过程中实时更新当前的平均延迟和抖动值。

#### 3.7.2 下载速度测试（Speedtest 风格）

**测试方法**: 多线程并发下载 + 定时器严格控制时间

**核心设计理念**:
- 参考 Speedtest/librespeed 的实现方式
- 使用**时间控制**而非**数据量控制**
- 多个并发流持续下载，直到定时器触发取消

**为什么使用多线程并发下载**:

| 问题 | 单线程下载的局限 | 多线程并发的优势 |
|------|------------------|------------------|
| **TCP 慢启动** | 每个 TCP 连接需要时间达到最大吞吐量 | 多个连接并行，更快达到带宽上限 |
| **单连接带宽限制** | 部分服务器/CDN 对单连接有速度限制 | 多连接绕过单连接限制 |
| **网络波动** | 单连接受网络波动影响大 | 多连接平滑波动，测量更稳定 |
| **高速网络** | 单连接可能无法跑满 500Mbps+ 带宽 | 6 个并发流可充分利用高速带宽 |
| **测量准确性** | 受单次请求延迟影响 | 持续下载，统计学上更准确 |

**TCP 慢启动 (Slow Start) 原理**:

TCP 连接建立后，不会立即以最大速度发送数据，而是从一个较小的**拥塞窗口 (cwnd)** 开始，每收到一个 ACK 确认就增加窗口大小，呈指数增长：

```
时间轴（每格 = 1 RTT）：
┌─────┬─────┬─────┬─────┬─────┬─────┬─────┐
│ RTT1│ RTT2│ RTT3│ RTT4│ RTT5│ RTT6│ ... │
├─────┼─────┼─────┼─────┼─────┼─────┼─────┤
│ 1段 │ 2段 │ 4段 │ 8段 │16段 │32段 │ ... │  ← 发送的数据段数
└─────┴─────┴─────┴─────┴─────┴─────┴─────┘
        拥塞窗口指数增长，直到达到阈值或丢包
```

| 为什么需要慢启动 | 说明 |
|------------------|------|
| **避免网络拥塞** | 如果所有连接一开始就全速发送，会瞬间压垮网络 |
| **探测可用带宽** | TCP 不知道网络能承受多少流量，需要逐步试探 |
| **公平性** | 确保新连接不会抢占已有连接的带宽 |

**达到最大吞吐量需要多久**（假设 RTT=30ms，初始 cwnd=10 MSS≈14KB）：

| RTT | 窗口大小 | 等效速度 |
|-----|----------|----------|
| 1 | 14KB | ~0.4 Mbps |
| 3 | 56KB | ~1.5 Mbps |
| 5 | 224KB | ~6 Mbps |
| 7 | 896KB | ~24 Mbps |
| 9 | 3.6MB | ~96 Mbps |

**结论**：单连接需要约 **9 个 RTT（270ms）** 才能接近 100Mbps。对于 500Mbps+ 带宽需要更长时间。

**多连接如何解决**：6 个连接同时慢启动，总吞吐量叠加，比单连接快 6 倍达到目标速度。

**专业测速工具的做法**:
- **Speedtest.net**: 使用 6-8 个并发连接
- **fast.com (Netflix)**: 使用多个并发流
- **librespeed**: 开源测速，默认 6 个并发连接

**测试参数**:
| 参数 | 值 | 说明 |
|------|-----|------|
| 并发线程数 | 6 | 参考 Speedtest |
| 每个请求大小 | 25MB | 适应高速网络（500Mbps+） |
| 测试时长 | 10秒 | 定时器严格控制 |
| Grace Time | 1.5秒 | 前 1.5 秒不计入最终速度 |
| 滑动窗口 | 2秒 | 用于实时速度计算 |
| EMA 平滑因子 | 0.3 | 速度显示平滑处理 |

**技术实现架构**:

```
┌─────────────────────────────────────────────────────────────┐
│                    withThrowingTaskGroup                     │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐       ┌─────────────┐    │
│  │ Timer Task  │  │ Stream #1   │  ...  │ Stream #6   │    │
│  │ (10秒定时器) │  │ (持续下载)   │       │ (持续下载)   │    │
│  └──────┬──────┘  └──────┬──────┘       └──────┬──────┘    │
│         │                │                     │            │
│         │ 10秒后抛出      │ 报告进度            │            │
│         │ CancellationError │                  │            │
│         ▼                ▼                     ▼            │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              DownloadCoordinator                     │   │
│  │  - 汇总所有流的下载字节数                              │   │
│  │  - 计算实时速度（滑动窗口 + EMA）                      │   │
│  │  - 采样用于最终速度计算                               │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

**定时器控制机制**:

```swift
// 定时器任务：严格控制测试时间
group.addTask {
    let startTime = Date()
    while Date().timeIntervalSince(startTime) < testDuration {
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        // 更新进度条
        let elapsed = Date().timeIntervalSince(testStartTime)
        let timeProgress = min(elapsed / testDuration, 1.0)
        await MainActor.run {
            self.progress = 0.2 + (0.8 * timeProgress)
        }
    }
    // 时间到了，取消所有其他任务
    throw CancellationError()
}
```

**下载流实现**:

```swift
// 每个下载流：持续下载直到被取消或协调器停止
private func downloadStream(...) async throws {
    while !Task.isCancelled && !coordinator.isStopped {
        do {
            try await downloadSingleChunk(size: chunkSize, coordinator: coordinator)
        } catch is CancellationError {
            break  // 定时器触发，正常退出
        } catch {
            // 忽略单个请求错误，继续下一个
            if Task.isCancelled || coordinator.isStopped { break }
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms 后重试
        }
    }
}
```

**为什么不用固定文件下载**:
- QQ 安装包约 200MB，500Mbps 网速下 3-4 秒就下载完成
- 进度条还没走完测试就结束了
- 使用 Cloudflare 可以无限请求任意大小的数据

#### 3.7.3 上传速度测试（Speedtest 风格）

**测试方法**: 多线程并发上传 + 定时器严格控制时间

**为什么使用多线程并发上传**:

| 问题 | 单线程上传的局限 | 多线程并发的优势 |
|------|------------------|------------------|
| **TCP 慢启动** | 上传方向同样受 TCP 慢启动影响 | 多连接更快达到上传带宽上限 |
| **ACK 等待** | 单连接需等待服务器 ACK 确认 | 多连接并行，减少等待时间 |
| **上传带宽利用** | 家庭宽带上传带宽通常较小，单连接易受限 | 4 个并发流可充分利用上传带宽 |
| **服务器处理** | 服务器单连接处理能力有限 | 分散到多连接，提高吞吐量 |

**为什么上传用 4 线程而下载用 6 线程**:
- 家庭/移动网络的上传带宽通常远小于下载带宽（如 100M 下载 / 20M 上传）
- 上传带宽较小时，过多并发反而增加开销
- 4 个并发流是上传测试的最佳平衡点

**测试参数**:
| 参数 | 值 | 说明 |
|------|-----|------|
| 并发线程数 | 4 | 上传带宽通常较小 |
| 每个请求大小 | 2MB | 平衡请求开销和测试效率 |
| 测试时长 | 10秒 | 定时器严格控制 |
| Grace Time | 3秒 | 前 3 秒不计入最终速度（上传需要更长预热） |
| 滑动窗口 | 2秒 | 用于实时速度计算 |
| EMA 平滑因子 | 0.3 | 速度显示平滑处理 |

**上传数据生成**:

```swift
// 预生成随机数据（避免每次都生成，影响性能）
var randomData = Data(count: chunkSize)
randomData.withUnsafeMutableBytes { buffer in
    _ = SecRandomCopyBytes(kSecRandomDefault, chunkSize, buffer.baseAddress!)
}
```

#### 3.7.4 速度计算机制（DownloadCoordinator / UploadCoordinator）

**多线程下载量汇总**:

所有并发下载流向同一个 `DownloadCoordinator` 报告进度，协调器内部累加所有流的字节数：

```
┌─────────────┐  ┌─────────────┐       ┌─────────────┐
│  Stream #1  │  │  Stream #2  │  ...  │  Stream #6  │
│  收到 5MB   │  │  收到 3MB   │       │  收到 4MB   │
└──────┬──────┘  └──────┬──────┘       └──────┬──────┘
       │                │                     │
       │ reportProgress │ reportProgress      │ reportProgress
       └────────────────┼─────────────────────┘
                        ▼
              DownloadCoordinator
              totalReceivedBytes += bytes  ← 累加所有流的字节数
                        │
                        ▼
              速度 = 总字节数 × 8 / 时间 / 1,000,000 (Mbps)
```

**速度计算公式**:

```
速度 (Mbps) = 字节数 × 8 ÷ 时间(秒) ÷ 1,000,000

举例：2 秒内 6 个线程总共下载了 125MB
速度 = 125,000,000 × 8 ÷ 2 ÷ 1,000,000 = 500 Mbps
```

**为什么乘以 8**：字节(Byte) → 比特(bit)，网速单位是 Mbps（兆比特每秒）

**多线程上传量汇总**:

上传测试与下载测试原理相同，4 个并发上传流向同一个 `UploadCoordinator` 报告进度：

```
┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│  Stream #1  │  │  Stream #2  │  │  Stream #3  │  │  Stream #4  │
│  发送 2MB   │  │  发送 1.5MB │  │  发送 2MB   │  │  发送 1.8MB │
└──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘
       │                │                │                │
       │ reportProgress │                │                │
       └────────────────┴────────────────┴────────────────┘
                                 │
                                 ▼
                       UploadCoordinator
                       totalSentBytes += bytes  ← 累加所有流的上传字节数
                                 │
                                 ▼
                       速度 = 总字节数 × 8 / 时间 / 1,000,000 (Mbps)
```

**下载与上传的区别**:

| 项目 | 下载 (DownloadCoordinator) | 上传 (UploadCoordinator) |
|------|---------------------------|-------------------------|
| 并发线程数 | 6 | 4 |
| 每个请求大小 | 25MB | 2MB |
| Grace Time | 1.5 秒 | 3 秒 |
| 数据来源 | 服务器返回的数据 | 本地生成的随机数据 |
| 进度回调 | `didReceive data` | `didSendBodyData` |

**Grace Time（预热期）**:
- 下载：前 1.5 秒
- 上传：前 3 秒
- 预热期内的数据**不计入最终速度**，但会显示实时速度

**实时速度计算（滑动窗口 + EMA）**:

```swift
// 1. 滑动窗口计算瞬时速度
let windowStart = now.addingTimeInterval(-windowDuration)  // 2秒窗口
let windowData = history.filter { $0.time >= windowStart }
let windowSpeed = (bytesDiff / timeDiff * 8) / 1_000_000  // Mbps

// 2. EMA 平滑处理
smoothedSpeed = 0.3 * windowSpeed + 0.7 * smoothedSpeed
```

**最终速度计算（采样 + 去极值）**:

```swift
func calculateFinalSpeed() -> Double {
    // 优先使用 grace time 后的采样数据
    if speedSamples.count >= 5 {
        var samples = speedSamples.sorted()
        let dropCount = max(1, samples.count / 5)  // 去掉 20%
        samples = Array(samples.dropFirst(dropCount).dropLast(dropCount))
        return samples.reduce(0, +) / Double(samples.count)
    }
    
    // 备用：使用 EMA 平滑速度
    if smoothedSpeed > 0 {
        return smoothedSpeed
    }
    
    // 最后备用：使用 grace time 后的总体计算
    // ...
}
```

**采样机制**:
- 每 0.5 秒采样一次速度
- 最多保留 30 个样本
- 最终计算时去掉最高和最低 20% 的样本

**速度变化曲线（正常现象）**:

测速过程中，显示的速度曲线可能呈现多种形态，这些都是正常现象。

##### 曲线形态 1：标准曲线（先增后减）

```
速度
 ↑
 │           ┌───────────┐
 │          /             \
 │         /               \
 │        /                 \
 │       /                   \
 │      /                     \
 │─────/                       \─────
 └────────────────────────────────────→ 时间
     0s    3s    5s    7s    10s
     
     慢启动   峰值稳定   测试结束
```

| 阶段 | 时间 | 原因 |
|------|------|------|
| **逐渐增加** | 0-3秒 | TCP 慢启动，6 个连接逐步达到峰值 |
| **峰值稳定** | 3-7秒 | 所有连接达到最大吞吐量，速度稳定 |
| **逐渐减小** | 7-10秒 | EMA 平滑效应 + 部分请求完成等待新请求 |

##### 曲线形态 2：先增后减再增（中间有波谷）

```
速度
 ↑
 │        ┌──┐      ┌───┐
 │       /    \    /     \
 │      /      \  /       \
 │     /        \/         \
 │    /                     \
 │───/                       \───
 └────────────────────────────────→ 时间
    0s   2s   4s   6s   8s  10s
    
    慢启动  chunk间隙  恢复  结束
```

| 阶段 | 时间 | 原因 |
|------|------|------|
| **初始增加** | 0-2秒 | 6 个并发连接同时建立，拥塞窗口指数增长 |
| **中间下降** | 3-5秒 | Chunk 请求间隙：某个 25MB chunk 下载完成，新请求还未开始返回数据 |
| **再次上升** | 5-7秒 | 新的 chunk 请求开始返回数据，多个连接重新达到稳定吞吐量 |
| **最终下降** | 8-10秒 | 测试即将结束，部分连接完成当前 chunk 等待新请求 |

**中间下降的具体原因**:
1. **Chunk 请求间隙**：某个 25MB 的 chunk 下载完成，新请求还未开始返回数据
2. **EMA 平滑延迟**：平滑因子 0.3 意味着历史速度权重 70%，瞬时下降会被放大
3. **滑动窗口效应**：2 秒窗口内数据量波动

##### 曲线形态 3：结束时突然升高

```
速度
 ↑
 │                          ┌─┐ ← 最后突然升高
 │           ┌──────────────┘ │
 │          /                  │
 │         /                   │
 │        /                    │
 │───────/                     │
 └─────────────────────────────┴──→ 时间
    0s    2s    4s    6s    8s  10s
                              ↑
                           测试结束
```

| 阶段 | 原因 |
|------|------|
| **结束时速度突增** | 多个 chunk 同时完成，瞬间收到大量数据 |

**结束时速度升高的原因**:
1. **多个 chunk 同时完成**：6 个并发连接各自下载 25MB 的 chunk，测试快结束时可能有多个 chunk 同时完成
2. **EMA 平滑的延迟效应**：累积的数据一次性反映到速度上
3. **滑动窗口的边界效应**：2 秒滑动窗口在测试末期可能包含多个 chunk 的完成数据

##### 为什么这些波动不影响最终结果？

| 机制 | 作用 |
|------|------|
| **Grace Time** | 前 1.5 秒（慢启动阶段）不计入最终速度 |
| **采样机制** | 每 0.5 秒采样一次，最多 30 个样本 |
| **去极值** | 最终计算时去掉最高/最低 20% 的样本 |
| **取中位数据** | 最终速度是稳定阶段的平均值 |

```swift
// SpeedTestManager.swift 中的最终速度计算
func calculateFinalSpeed() -> Double {
    var samples = speedSamples.sorted()
    let dropCount = max(1, samples.count / 5)  // 去掉 20%
    samples = Array(samples.dropFirst(dropCount).dropLast(dropCount))
    return samples.reduce(0, +) / Double(samples.count)
}
```

**结论**：
- 实时显示的曲线波动是**正常的用户体验设计**
- 最终报告的速度是**经过统计处理的准确值**
- 曲线波动不会影响最终测速结果的准确性

#### 3.7.5 预估流量消耗

**功能说明**：在移动网络下测速前，显示预估的流量消耗，帮助用户决定是否继续测试。

**实现位置**：`DeviceInfoManager.swift` - `NetworkStatus.estimatedDataUsage`

**预估算法**：
```swift
/// 预估测速流量消耗（MB）
/// 基于网络类型估算：下载10秒 + 上传10秒
var estimatedDataUsage: (download: Int, upload: Int, total: Int) {
    let downloadMbps: Int
    let uploadMbps: Int
    
    switch self {
    case .cellular2G:
        downloadMbps = 1; uploadMbps = 1
    case .cellular3G:
        downloadMbps = 10; uploadMbps = 5
    case .cellular4G, .cellular:
        downloadMbps = 100; uploadMbps = 20
    case .cellular5G:
        downloadMbps = 300; uploadMbps = 50
    case .wifi:
        downloadMbps = 100; uploadMbps = 20
    case .ethernet:
        downloadMbps = 500; uploadMbps = 100
    default:
        downloadMbps = 50; uploadMbps = 10
    }
    
    // 流量 = 速度(Mbps) × 时间(秒) ÷ 8 = MB
    let downloadMB = downloadMbps * 10 / 8
    let uploadMB = uploadMbps * 10 / 8
    return (downloadMB, uploadMB, downloadMB + uploadMB)
}
```

**各网络类型预估流量**：

| 网络类型 | 预估下载速度 | 预估上传速度 | 下载流量 | 上传流量 | 总计 |
|----------|-------------|-------------|---------|---------|------|
| 2G | 1 Mbps | 1 Mbps | ~1 MB | ~1 MB | ~2 MB |
| 3G | 10 Mbps | 5 Mbps | ~12 MB | ~6 MB | ~18 MB |
| 4G | 100 Mbps | 20 Mbps | ~125 MB | ~25 MB | ~150 MB |
| 5G | 300 Mbps | 50 Mbps | ~375 MB | ~62 MB | ~437 MB |
| WiFi | 100 Mbps | 20 Mbps | ~125 MB | ~25 MB | ~150 MB |
| 有线 | 500 Mbps | 100 Mbps | ~625 MB | ~125 MB | ~750 MB |

**计算公式**：
```
流量(MB) = 速度(Mbps) × 测试时间(10秒) ÷ 8
```

**显示时机**：
1. 移动网络下，测速前在界面显示预估流量卡片
2. 点击开始测速时，弹出流量提醒对话框
3. 测速完成后，显示实际消耗流量（基于测速结果计算）

**实际流量计算**（测速完成后）：
```swift
// SpeedTestResultView 中的实际流量计算
private var actualDataUsage: (download: Int, upload: Int, total: Int) {
    // 下载：downloadSpeed (Mbps) × 10秒 ÷ 8 = MB
    let downloadMB = Int(downloadSpeed * 10 / 8)
    // 上传：uploadSpeed (Mbps) × 10秒 ÷ 8 = MB
    let uploadMB = Int(uploadSpeed * 10 / 8)
    return (downloadMB, uploadMB, downloadMB + uploadMB)
}
```

#### 3.7.6 网速等级评估

**功能说明**：测速完成后，根据下载速度和网络类型评估网速等级，给用户直观的参考。

**实现位置**：`SpeedTestView.swift` - `SpeedLevel` 枚举

**等级定义**：

| 等级 | 枚举值 | 移动网络速度范围 | WiFi 速度范围 | 中文名称 | 英文名称 | 图标 | 颜色 |
|------|--------|-----------------|--------------|----------|----------|------|------|
| 慢速 | `.slow` | < 20 Mbps | < 50 Mbps | 网络较慢 | Slow Network | `tortoise.fill` | 红色 |
| 4G普通 | `.level4GNormal` | 20-50 Mbps | - | 4G普通网速 | 4G Normal | `antenna.radiowaves.left.and.right` | 橙色 |
| 4G良好 | `.level4GGood` | 50-100 Mbps | - | 4G良好网速 | 4G Good | `antenna.radiowaves.left.and.right` | 黄色 |
| 5G | `.level5G` | 100-600 Mbps | - | 5G网速 | 5G Speed | `antenna.radiowaves.left.and.right.circle.fill` | 绿色 |
| WiFi百兆 | `.wiFi100M` | - | 50-300 Mbps | WiFi百兆宽带 | WiFi 100Mbps | `wifi` | 蓝色 |
| WiFi 500M | `.wiFi500M` | - | 300-600 Mbps | WiFi 500M宽带 | WiFi 500Mbps | `wifi` | 青色 |
| WiFi千兆 | `.wiFiGigabit` | 600-1000 Mbps | 600-1000 Mbps | WiFi千兆宽带 | WiFi Gigabit | `wifi.circle.fill` | 紫色 |
| 极速 | `.excellent` | > 1000 Mbps | > 1000 Mbps | 极速网络 | Ultra Fast | `bolt.horizontal.circle.fill` | 粉色 |

**等级判断逻辑**：

```swift
static func from(downloadSpeed: Double, isCellular: Bool) -> SpeedLevel {
    if downloadSpeed < 20 {
        return .slow
    } else if downloadSpeed < 50 {
        return isCellular ? .level4GNormal : .slow  // WiFi 下 20-50 Mbps 也是慢速
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
```

**速度阈值与等级对照表**：

| 速度范围 | 移动网络等级 | WiFi 等级 |
|----------|-------------|-----------|
| < 20 Mbps | 网络较慢 | 网络较慢 |
| 20-50 Mbps | 4G普通网速 | **网络较慢** |
| 50-100 Mbps | 4G良好网速 | WiFi百兆宽带 |
| 100-300 Mbps | 5G网速 | WiFi百兆宽带 |
| 300-600 Mbps | 5G网速 | WiFi 500M宽带 |
| 600-1000 Mbps | WiFi千兆宽带 | WiFi千兆宽带 |
| > 1000 Mbps | 极速网络 | 极速网络 |

**判断特点**：
1. **区分网络类型**：同样的速度在移动网络和 WiFi 下显示不同等级
2. **WiFi 标准更严格**：WiFi 下 20-50 Mbps 被认为是"网络较慢"，因为 WiFi 通常应该更快
3. **移动网络优先显示 4G/5G 等级**：用户更关心是否达到运营商宣传的速度
4. **WiFi 优先显示宽带等级**：用户更关心是否达到购买的宽带套餐速度

**显示样式**：
- 等级标签以胶囊形状显示在卡片右侧
- 背景色与等级颜色对应
- 图标使用 SF Symbols 系统图标

#### 3.7.8 测试结束与取消机制

**设计目标**: 确保测试结束后不会有遗留的网络请求继续消耗流量。

**双重检查机制**:

每个下载/上传流的循环同时检查两个条件：
1. `Task.isCancelled` - Swift 并发的任务取消标志
2. `coordinator.isStopped` - 协调器的停止标志

```swift
// 双重检查确保及时退出
while !Task.isCancelled && !coordinator.isStopped {
    // 下载/上传逻辑
}
```

**测试结束流程**:

```
10秒定时器到达
       │
       ▼
coordinator.stop()
       │
       ├─► 设置 _isStopped = true
       │
       ├─► 遍历 activeSessions，调用 invalidateAndCancel()
       │   取消所有正在进行的网络请求
       │
       └─► 清空 activeSessions 数组
       │
       ▼
downloadTask.cancel()
       │
       └─► 取消整个 Task，触发 Task.isCancelled
       │
       ▼
下载流检测到 isStopped 或 isCancelled
       │
       └─► 退出 while 循环，不再发起新请求
```

**Session 注册/注销机制**:

```swift
// 注册 session（下载开始时）
func registerSession(_ session: URLSession) {
    lock.lock()
    if !_isStopped {
        activeSessions.append(session)
    } else {
        // 如果已经停止，立即取消这个 session
        session.invalidateAndCancel()
    }
    lock.unlock()
}

// 注销 session（下载完成时）
func unregisterSession(_ session: URLSession) {
    lock.lock()
    activeSessions.removeAll { $0 === session }
    lock.unlock()
}
```

**防止遗漏请求**:

| 场景 | 处理方式 |
|------|----------|
| 正在进行的请求 | `stop()` 调用 `invalidateAndCancel()` 取消 |
| 刚完成一个 chunk，准备开始新请求 | 循环检测 `isStopped`，不再发起新请求 |
| `stop()` 后才注册的 session | `registerSession()` 检测到 `isStopped`，立即取消 |
| 已完成的请求 | `unregisterSession()` 从列表移除，不受影响 |

**线程安全**:

- 使用 `NSLock` 保护共享状态（`_isStopped`、`activeSessions`）
- `isStopped` 属性通过加锁的 getter 暴露，确保读取时的线程安全

```swift
var isStopped: Bool {
    lock.lock()
    defer { lock.unlock() }
    return _isStopped
}
```

#### 3.7.9 进度条更新机制

**进度条基于时间而非数据量**:

| 阶段 | 进度范围 | 更新方式 |
|------|----------|----------|
| 延迟测试 | 0% ~ 20% | 每完成一次请求更新 |
| 下载测试 | 20% ~ 100% | 定时器每 100ms 更新 |
| 上传测试 | 0% ~ 100% | 定时器每 100ms 更新 |

**确保进度条完整**:
- 定时器任务负责更新进度
- 测试结束时强制设置 `progress = 1.0`
- 无论网速多快，进度条都会平滑走完

#### 3.7.10 测速服务器

**统一使用 Cloudflare**:

| 用途 | URL | 说明 |
|------|-----|------|
| 下载测试 | `https://speed.cloudflare.com/__down?bytes={size}&r={uuid}` | 支持任意大小 |
| 上传测试 | `https://speed.cloudflare.com/__up` | POST 二进制数据 |
| 延迟测试（中文） | `https://www.qq.com` | HEAD 请求 |
| 延迟测试（英文） | `https://www.google.com` | HEAD 请求 |

**URL 参数说明**:
- `bytes`: 请求的数据大小（字节）
- `r`: 随机 UUID，防止缓存

#### 3.7.11 中英文模式差异

| 测试项 | 中文模式 | 英文模式 |
|--------|----------|----------|
| **延迟测试** | `qq.com` | `google.com` |
| **下载测试** | Cloudflare（6线程） | Cloudflare（6线程） |
| **上传测试** | Cloudflare（4线程） | Cloudflare（4线程） |

**说明**: 
- 之前中文模式使用 QQ 服务器下载固定文件，但高速网络下文件很快下载完
- 现在统一使用 Cloudflare，确保测试时间严格为 10 秒

#### 3.7.12 应用延迟测试地址

##### 中文模式 - 腾讯系 (10个)

| 名称 | URL |
|------|-----|
| 腾讯新闻 | `https://www.qq.com` |
| 腾讯视频 | `https://v.qq.com` |
| 微信 | `https://weixin.qq.com` |
| 微信支付 | `https://support.pay.weixin.qq.com` |
| 广告平台 | `https://e.qq.com` |
| 王者荣耀 | `https://pvp.qq.com` |
| 和平精英 | `https://gp.qq.com` |
| 腾讯云 | `https://cloud.tencent.com` |
| 腾讯官网 | `https://www.tencent.com` |
| 元宝 | `https://yuanbao.tencent.com` |

##### 中文模式 - 其他应用 (8个)

| 名称 | URL |
|------|-----|
| 百度 | `https://www.baidu.com` |
| 阿里 | `https://www.aliyun.com` |
| 字节 | `https://www.bytedance.com` |
| 京东 | `https://www.jd.com` |
| 微博 | `https://m.weibo.cn` |
| 美团 | `https://www.meituan.com` |
| 网易 | `https://www.163.com` |
| Deepseek | `https://www.deepseek.com` |

##### 英文模式 - Tech Giants (8个)

| 名称 | URL |
|------|-----|
| Google | `https://www.google.com` |
| Microsoft | `https://www.microsoft.com` |
| Amazon | `https://www.amazon.com` |
| AWS | `https://aws.amazon.com` |
| Apple | `https://www.apple.com` |
| Meta | `https://www.meta.com` |
| OpenAI | `https://openai.com` |
| Cloudflare | `https://www.cloudflare.com` |

##### 英文模式 - Social & Entertainment (8个)

| 名称 | URL |
|------|-----|
| YouTube | `https://www.youtube.com` |
| TikTok | `https://www.tiktok.com` |
| X | `https://x.com` |
| WhatsApp | `https://www.whatsapp.com` |
| Steam | `https://store.steampowered.com` |
| Netflix | `https://www.netflix.com` |
| Spotify | `https://www.spotify.com` |
| Reddit | `https://www.reddit.com` |

##### 英文模式 - Other (8个)

| 名称 | URL |
|------|-----|
| PayPal | `https://www.paypal.com` |
| Epic Games | `https://www.epicgames.com` |
| eBay | `https://www.ebay.com` |
| Uber Eats | `https://www.ubereats.com` |
| Yahoo | `https://www.yahoo.com` |
| Deepseek | `https://www.deepseek.com` |
| GitHub | `https://github.com` |
| Discord | `https://discord.com` |

#### 3.7.13 分类显示

| 语言 | 分类数 | 分类标题 |
|------|--------|----------|
| 中文 | 2 | 腾讯系、其他应用 |
| 英文 | 3 | Tech Giants、Social & Entertainment、Other |

**分类属性**:
```swift
var firstCategoryTitle: String   // 中文: "腾讯系", 英文: "Tech Giants"
var secondCategoryTitle: String  // 中文: "其他应用", 英文: "Social & Entertainment"
var thirdCategoryTitle: String   // "Other" (仅英文)
var hasThirdCategory: Bool       // 是否显示第三分类
```

#### 3.7.14 超时时间配置

| 测试类型 | 超时时间 | 说明 |
|----------|----------|------|
| 网速延迟测试 | 5秒 | 测试 10 次，取平均值 |
| 下载测试 | 10秒 | 定时器严格控制 |
| 上传测试 | 10秒 | 定时器严格控制 |
| 单个请求超时 | 15秒（下载）/ 30秒（上传） | 网络请求超时 |
| 应用延迟测试 | 5秒 | 测试 3 次，取最小值 |

#### 3.7.15 应用延迟测试实现

**测试方法**: HTTP HEAD 请求

**测试逻辑**:
1. 对每个应用 URL 发送 HTTP HEAD 请求
2. 每个应用测试 3 次，取最小延迟值
3. 所有应用并行测试，提高效率
4. 超时时间 5 秒，超时返回 `nil`（显示为 `--`）

```swift
private static func measureAppLatency(url urlString: String) async -> Double? {
    guard let url = URL(string: urlString) else { return nil }
    
    var request = URLRequest(url: url)
    request.httpMethod = "HEAD"
    request.timeoutInterval = 5  // 超时时间：5秒
    
    // 测试3次取最小值
    var latencies: [Double] = []
    for _ in 0..<3 {
        do {
            let start = Date()
            let _ = try await URLSession.shared.data(for: request)
            let elapsed = Date().timeIntervalSince(start) * 1000
            latencies.append(elapsed)
        } catch {
            continue  // 超时或失败则跳过
        }
    }
    
    return latencies.min()  // 返回最小值，全部失败则返回 nil
}
```

**国内访问海外地址说明**:

在国内网络环境下，英文模式测试 Google、YouTube 等海外服务可能会：
- 完全超时（5秒后返回 `nil`，显示为 `--`）
- 延迟极高（可能显示几秒）
- 部分可达（如 Cloudflare、GitHub 在国内通常可访问）

#### 3.7.16 网络质量评级

| 延迟范围 | 评级 | 颜色 |
|----------|------|------|
| < 50ms | 极佳 (Excellent) | 绿色 |
| 50-100ms | 良好 (Good) | 蓝色 |
| 100-200ms | 一般 (Fair) | 橙色 |
| > 200ms | 较差 (Poor) | 红色 |

#### 3.7.17 测试参数汇总

**延迟测试参数**:

| 参数 | 值 | 说明 |
|------|-----|------|
| 测试次数 | 10 次 | HTTP HEAD 请求 |
| 请求间隔 | 100ms | 每次请求间隔 |
| 单次超时 | 5 秒 | 请求超时时间 |
| 延迟计算 | 平均值 | 10 次测量的平均值 |
| 抖动计算 | 相邻差值平均 | 相邻延迟差值绝对值的平均值 |

**下载/上传测试参数**:

| 参数 | 下载 | 上传 | 说明 |
|------|------|------|------|
| 并发线程数 | 6 | 4 | 上传带宽通常较小，无需太多并发 |
| 每个请求大小 | 25MB | 2MB | 下载需要大块数据测试高速网络 |
| 测试时长 | 10 秒 | 10 秒 | 定时器严格控制 |
| Grace Time | 1.5 秒 | 3 秒 | 上传需要更长预热时间 |
| 滑动窗口 | 2 秒 | 2 秒 | 用于实时速度计算 |
| EMA 平滑因子 | 0.3 | 0.3 | 速度显示平滑处理 |
| 单个请求超时 | 15 秒 | 30 秒 | 上传超时更长 |
| 采样间隔 | 0.5 秒 | 0.5 秒 | 速度采样间隔 |
| 最大采样数 | 30 | 30 | 最多保留的样本数 |
| 去极值比例 | 20% | 20% | 最终计算时去掉最高/最低 20% |

**应用延迟测试参数**:

| 参数 | 值 | 说明 |
|------|-----|------|
| 测试次数 | 3 次 | 每个应用测试 3 次 |
| 延迟计算 | 最小值 | 取 3 次中的最小值 |
| 单次超时 | 5 秒 | 请求超时时间 |
| 并发方式 | 全部并行 | 所有应用同时测试 |

**测速服务器**:

| 用途 | URL | 说明 |
|------|-----|------|
| 下载测试 | `https://speed.cloudflare.com/__down?bytes={size}` | 支持任意大小 |
| 上传测试 | `https://speed.cloudflare.com/__up` | POST 二进制数据 |
| 延迟测试（中文） | `https://www.qq.com` | HEAD 请求 |
| 延迟测试（英文） | `https://www.google.com` | HEAD 请求 |

---

### 3.8 设备信息

**实现文件**: `Managers/DeviceInfoManager.swift`

**获取信息**:
| 类别 | 信息 | 获取方式 |
|------|------|----------|
| 公网 IP | IP 地址、归属地、运营商 | API 查询 |
| 设备 | 名称、型号、标识 | `UIDevice` |
| 系统 | 版本 | `ProcessInfo` |
| 网络 | 状态、本地 IP、WiFi 名称 | `NWPathMonitor` |
| 硬件 | 电池、存储、内存 | 系统 API |

#### 3.8.1 本地 IP 地址获取

**技术方案**:
- **框架**: Darwin BSD Socket API (`getifaddrs`)
- **特性**: 严格按当前网络状态返回对应接口的 IP 地址

**网络接口映射**:
| 网络状态 | 接口名称 | 说明 |
|----------|----------|------|
| WiFi | `en0` | WiFi 网络接口 |
| 蜂窝网络 | `pdp_ip0` | 移动数据网络接口 |
| 未知/断开 | - | 不返回任何地址 |

**工作原理**:
```swift
private func getLocalIPAddresses() -> (ipv4: String?, ipv6: String?) {
    var ifaddr: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
        return (nil, nil)
    }
    defer { freeifaddrs(ifaddr) }
    
    // 根据当前网络状态决定使用哪个接口
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
        let name = String(cString: interface.ifa_name)
        
        // 只获取活跃接口的地址
        guard name == activeInterface else { continue }
        
        if interface.ifa_addr.pointee.sa_family == UInt8(AF_INET) {
            // IPv4 地址
            ipv4Address = parseAddress(interface.ifa_addr)
        } else if interface.ifa_addr.pointee.sa_family == UInt8(AF_INET6) {
            // IPv6 地址（过滤 link-local fe80::）
            let addr = parseAddress(interface.ifa_addr)
            if !addr.lowercased().hasPrefix("fe80::") {
                ipv6Address = addr
            }
        }
    }
    
    return (ipv4Address, ipv6Address)
}
```

**设计要点**:
1. **严格接口匹配**: 只返回当前活跃网络接口的 IP 地址，不使用其他接口作为备用
2. **网络状态联动**: 依赖 `NWPathMonitor` 监听网络状态变化，状态变化时自动刷新设备信息
3. **IPv6 过滤**: 过滤掉 link-local 地址（`fe80::` 开头），只返回全局可路由的 IPv6 地址
4. **初始化时机**: 在 `NetworkMonitor` 回调返回正确网络状态后才获取设备信息，避免首次加载时 IP 为空

**网络状态变化处理**:
```swift
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
```

---

### 3.9 一键诊断

**实现文件**: `Managers/QuickDiagnosisManager.swift`

**功能流程**:
1. 输入 6 位诊断码
2. 调用 API 获取诊断任务列表
3. 批量执行诊断任务（Ping/TCP/UDP/DNS/Traceroute）
4. 上报结果到华佗平台

**支持的任务类型**:
| 类型 | API 值 | 执行器 | IPv6 支持 |
|------|--------|--------|----------|
| Ping | `ping` | `PingManager` | ✅ 通过 `Af` 字段指定 |
| TCP | `tcp_port` | `TCPManager` | ✅ 通过 `Af` 字段指定 |
| UDP | `udp_port` | `UDPManager` | ✅ 通过 `Af` 字段指定 |
| DNS | `dns` | `DNSManager` | ✅ 自动根据记录类型 |
| Traceroute | `mtr` | `TraceManager` | ✅ 通过 `Af` 字段指定 |

#### 3.9.1 IPv6 支持

一键诊断支持通过 `Af` 字段指定使用 IPv4 或 IPv6 进行探测：

| Af 值 | 说明 |
|-------|------|
| `4` 或 `null` | 使用 IPv4（默认） |
| `6` | 使用 IPv6 |

**实现方式**：
- `DiagnosisTaskDetail` 模型包含 `af: Int?` 字段
- 提供 `useIPv6` 计算属性：当 `af == 6` 时返回 `true`
- 执行探测时，各 Manager 根据 `useIPv6` 设置 DNS 解析优先级：
  - `PingManager.preferIPv6`
  - `TCPManager.preferIPv6`
  - `UDPManager.preferIPv6`
  - `TraceManager.protocolPreference`（设为 `.ipv6Only` 或 `.ipv4Only`）

#### 3.9.2 获取诊断任务列表 API

**URL**: `POST https://api.itango.tencent.com/api`

**鉴权**: HMAC-SHA-512

**请求体**:
```json
{
    "Action": "MsmExample",
    "Method": "GetMsmExample",
    "SystemId": "4",
    "Condition": {
        "UniqueKey": "ABC123"  // 6位诊断码
    },
    "AppendInfo": {
        "UserId": 123  // 当前用户 ID，未登录为 -1
    }
}
```

**响应体**:
```json
{
    "Return": 0,
    "Details": "",
    "ReqId": "xxx",
    "Data": {
        "Data": [
            {
                "Id": 123,
                "TaskName": "诊断任务名称",
                "UniqueKey": "ABC123",
                "UserId": "user123",
                "CreateTime": "2025-12-23 10:00:00",
                "UpdateTime": "2025-12-23 10:00:00",
                "ExampleDetail": [
                    {
                        "Id": 1,
                        "ExampleId": "example_1",
                        "MsmType": "ping",  // ping / tcp_port / udp_port / dns / mtr
                        "Target": "www.qq.com",
                        "Port": "443",      // TCP/UDP 时有值
                        "Af": 4,            // 地址族: 4=IPv4, 6=IPv6，默认 IPv4
                        "Options": {
                            "count": 4,
                            "size": 64,
                            "timeout": 5,
                            "rtype": "A",   // DNS 记录类型
                            "ns": ""        // DNS 服务器
                        },
                        "UserId": "user123"
                    }
                ]
            }
        ],
        "ReportId": 12345  // 用于结果上报
    }
}
```

#### 3.9.3 上传诊断结果 API

**URL**: `POST https://api.itango.tencent.com/api`

**鉴权**: HMAC-SHA-512

**请求体**:
```json
{
    "Action": "MsmReceive",
    "Method": "BatchRun",
    "SystemId": "4",
    "Data": [
        {
            "MsmType": "ping",  // ping / tcp_port / udp_port / dns / mtr
            "MsmDatas": {
                // 通用字段
                "ExampleUniqueKey": "ABC123",
                "ExampleReportId": 12345,
                "LocalDeviceType": "iOS",
                "LocalDeviceName": "iPhone 15 Pro",
                "LocalDeviceModel": "iPhone16,1",
                "LocalDeviceIdentifier": "xxx",
                "LocalSystemVersion": "iOS 17.0",
                "LocalNetwork": "WiFi",
                "LocalRecordType": "",
                "LocalExecTime": "2025-12-23 10:00:00",
                "Addr": "www.qq.com",
                "BuildinAf": "4",
                "BuildinAgentId": "",
                "BuildinAgentVersion": "1.0.0",
                "BuildinDurationNano": 1000000000,
                "BuildinErrMessage": "",
                "BuildinExcMode": "once",
                "BuildinFinishTimestampMilli": 1703304000000,
                "BuildinId": -1,
                "BuildinIntervalDuration": "1s",
                "BuildinLocalTime": "2025-12-23 10:00:00",
                "BuildinMainTaskSetId": -1,
                "BuildinPeerIP": "1.2.3.4",
                "BuildinAgentPublicIP": "5.6.7.8",
                "BuildinSource": "app",
                "BuildinSubTaskSetId": -1,
                "BuildinTargetHost": "www.qq.com",
                "BuildinTaskKey": "",
                "BuildinTimestampMilli": 1703304000000,
                "BuildinUserId": 123,
                "BuildinUtcTime": "2025-12-23T02:00:00.000Z",
                "LocalIPAddress": "192.168.1.100",
                "MsmType": "ping",
                
                // Ping 特有字段
                "AvgRttMicro": 50000,
                "MaxRttMicro": 80000,
                "MinRttMicro": 30000,
                "StdDevRttMicro": 10000,
                "PacketsSent": 4,
                "PacketsRecv": 4,
                "PacketLoss": 0,
                "RttsMicro": [30000, 40000, 50000, 80000],
                "RttsMilli": [30, 40, 50, 80],
                "Cname": "",
                "IPAddr": "1.2.3.4",
                "Network": "ip",
                "ResultToText": "PING www.qq.com (1.2.3.4): 64 data bytes\n..."
            }
        },
        {
            "MsmType": "tcp_port",
            "MsmDatas": {
                // ... 通用字段 ...
                "AvgRttMicro": 50000,
                "AvgRttMilli": 50,
                "MaxRttMicro": 50000,
                "MaxRttMilli": 50,
                "MinRttMicro": 50000,
                "MinRttMilli": 50,
                "Network": "tcp4",
                "PacketLoss": 0,
                "PacketsRecv": 1,
                "PacketsSent": 1,
                "RemotePort": "443",
                "RttsMicro": [50000],
                "RttsMicroMilli": [50],
                "StdDevRttMicro": 0,
                "ResultToText": "端口 443 开放，延迟 50.000 ms"
            }
        },
        {
            "MsmType": "udp_port",
            "MsmDatas": {
                // ... 通用字段 ...
                "AvgRttMicro": 50000,
                "AvgRttMilli": 50,
                "MaxRttMicro": 50000,
                "MaxRttMilli": 50,
                "MinRttMicro": 50000,
                "MinRttMilli": 50,
                "Network": "udp4",
                "PacketLoss": 0,
                "PacketsRecv": 1,
                "PacketsSent": 1,
                "RecvDataLen": 1,
                "RemotePort": 53,
                "RttsMicro": [50000],
                "RttsMicroMilli": [50],
                "StdDevRttMicro": 0,
                "ResultToText": "UDP 端口 53 可达，延迟 50.000 ms"
            }
        },
        {
            "MsmType": "dns",
            "MsmDatas": {
                // ... 通用字段 ...
                "Domain": "www.qq.com",
                "RecordType": "A",
                "Records": ["1.2.3.4", "5.6.7.8"],
                "LatencyMicro": 50000,
                "Server": "8.8.8.8",
                "ResultToText": "; <<>> Pong DNS <<>> www.qq.com\n..."
            }
        },
        {
            "MsmType": "mtr",
            "MsmDatas": {
                // ... 通用字段 ...
                "Hops": [
                    {
                        "Hop": 1,
                        "IP": "192.168.1.1",
                        "AvgLatencyMicro": 5000,
                        "LossRate": 0,
                        "Location": "局域网"
                    },
                    {
                        "Hop": 2,
                        "IP": "10.0.0.1",
                        "AvgLatencyMicro": 10000,
                        "LossRate": 0,
                        "Location": "广东 电信"
                    }
                ],
                "HopCount": 10,
                "ReachedTarget": true,
                "ResultToText": "Traceroute to www.qq.com\n1. 192.168.1.1 5.000 ms\n..."
            }
        }
    ]
}
```

**响应体**:
```json
{
    "Return": 0,
    "Details": "",
    "ReqId": "xxx"
}
```

#### 3.9.4 上报数据统一构建器

**实现文件**: `Managers/ReportDataBuilder.swift`

上报数据通过 `ReportDataBuilder` 统一构建，支持一键诊断和历史记录两种上报来源。

**上报来源区分**:
```swift
enum ReportSource {
    case diagnosis(uniqueKey: String, reportId: Int)  // 一键诊断
    case history                                       // 历史记录
    
    var localRecordType: String {
        switch self {
        case .diagnosis: return "diagnosis"
        case .history: return "history"
        }
    }
}
```

**一键诊断与历史任务上报的区别**:

| 字段 | 一键诊断 | 历史任务 | 说明 |
|------|----------|----------|------|
| `ExampleUniqueKey` | 诊断码 (如 "ABC123") | 空字符串 `""` | 关联诊断案例 |
| `ExampleReportId` | 报告 ID (如 12345) | `0` | 关联报告 |
| `LocalRecordType` | `"diagnosis"` | `"history"` | 区分上报来源 |
| `BuildinAgentRemoteIP` | 包含此字段 | 不包含 | 仅诊断上报 |
| `BuildinAgentPublicIP` | 公网出口 IP | 公网出口 IP | 两者相同 |

**通用基础字段**:
```json
{
    "ExampleUniqueKey": "ABC123",        // 一键诊断: 诊断码, 历史: ""
    "ExampleReportId": 12345,            // 一键诊断: 报告ID, 历史: 0
    "LocalDeviceType": "iOS",
    "LocalDeviceName": "iPhone 15 Pro",
    "LocalDeviceModel": "iPhone16,1",
    "LocalDeviceIdentifier": "xxx",
    "LocalSystemVersion": "iOS 17.0",
    "LocalNetwork": "WiFi",
    "LocalRecordType": "diagnosis",      // "diagnosis" 或 "history"
    "LocalExecTime": "2025-12-23 10:00:00",
    "Addr": "www.qq.com",
    "BuildinAf": "4",
    "BuildinAgentId": "",
    "BuildinAgentVersion": "1.0.0",
    "BuildinDurationNano": 1000000000,   // 执行时长（纳秒）
    "BuildinErrMessage": "",             // 错误信息
    "BuildinExcMode": "once",
    "BuildinFinishTimestampMilli": 1703304000000,
    "BuildinId": -1,
    "BuildinIntervalDuration": "1s",
    "BuildinLocalTime": "2025-12-23 10:00:00",
    "BuildinMainTaskSetId": -1,
    "BuildinPeerIP": "1.2.3.4",          // 目标 IP
    "BuildinSource": "app",
    "BuildinSubTaskSetId": -1,
    "BuildinTargetHost": "www.qq.com",
    "BuildinTaskKey": "",
    "BuildinTimestampMilli": 1703304000000,
    "BuildinUserId": 123,
    "BuildinUtcTime": "2025-12-23T02:00:00.000Z",
    "LocalIPAddress": "192.168.1.100",   // 本地 IPv4
    "LocalIPv6Address": "fe80::1",       // 本地 IPv6
    "MsmType": "ping"
}
```

**Ping 特有字段**:
```json
{
    "AvgRttMicro": 50000,          // 平均延迟（微秒）
    "MaxRttMicro": 80000,          // 最大延迟（微秒）
    "MinRttMicro": 30000,          // 最小延迟（微秒）
    "StdDevRttMicro": 10000,       // 标准差（微秒）
    "PacketsSent": 4,              // 发送包数
    "PacketsRecv": 4,              // 接收包数
    "PacketLoss": 0,               // 丢包率 (%)
    "RttsMicro": [30000, 40000, 50000, 80000],  // 每次延迟（微秒）
    "RttsMilli": [30, 40, 50, 80],              // 每次延迟（毫秒）
    "Cname": "",
    "IPAddr": "1.2.3.4",           // 解析后的 IP
    "Network": "ip",
    "ResultToText": "PING www.qq.com (1.2.3.4): 64 data bytes\n..."
}
```

**TCP 特有字段**:
```json
{
    "AvgRttMicro": 50000,          // 平均延迟（微秒）
    "AvgRttMilli": 50,             // 平均延迟（毫秒）
    "MaxRttMicro": 50000,
    "MaxRttMilli": 50,
    "MinRttMicro": 50000,
    "MinRttMilli": 50,
    "Network": "tcp4",
    "PacketLoss": 0,               // 丢包率 (%)
    "PacketsRecv": 1,              // 成功次数
    "PacketsSent": 1,              // 测试次数
    "RemotePort": "443",           // 端口号
    "RttsMicro": [50000],
    "RttsMicroMilli": [50],
    "StdDevRttMicro": 0,
    "ResultToText": "端口 443 开放，延迟 50.000 ms"
}
```

**TCP 批量扫描特有字段**:
```json
{
    "ScanMode": "batch",           // 批量扫描模式
    "OpenCount": 5,                // 开放端口数
    "TotalCount": 10,              // 总扫描端口数
    "RemotePort": "21,22,80,443,8080",  // 扫描的端口列表
    "ResultToText": "TCP Port Scan: www.qq.com\n\nPort 80 (HTTP): 开放 - 50.0ms\n..."
}
```

**UDP 特有字段**:
```json
{
    "AvgRttMicro": 50000,
    "AvgRttMilli": 50,
    "MaxRttMicro": 50000,
    "MaxRttMilli": 50,
    "MinRttMicro": 50000,
    "MinRttMilli": 50,
    "Network": "udp4",
    "PacketLoss": 0,
    "PacketsRecv": 1,              // 收到响应次数
    "PacketsSent": 1,              // 发送次数
    "RecvDataLen": 1,              // 收到响应则为 1，否则为 0
    "RemotePort": 53,
    "RttsMicro": [50000],
    "RttsMicroMilli": [50],
    "StdDevRttMicro": 0,
    "ResultToText": "UDP 端口 53: 可达，延迟 50.000 ms"
}
```

**DNS 特有字段**:
```json
{
    "Domain": "www.qq.com",
    "RecordType": "A",             // 记录类型
    "Records": ["1.2.3.4", "5.6.7.8"],  // 解析结果
    "LatencyMicro": 50000,         // 查询耗时（微秒）
    "Server": "8.8.8.8",           // DNS 服务器
    "ResultToText": "; <<>> Pong DNS <<>> www.qq.com\n;; Got answer:\n..."
}
```

**Traceroute (MTR) 特有字段**:
```json
{
    "Hops": [
        {
            "Hop": 1,
            "IP": "192.168.1.1",
            "Hostname": "router.local",    // PTR 反向解析的主机名
            "AvgLatencyMicro": 5000,
            "LossRate": 0,
            "SentCount": 3,
            "ReceivedCount": 3,
            "Location": "局域网"
        }
    ],
    "HopCount": 10,
    "ReachedTarget": true,
    "ResultToText": "Traceroute to www.qq.com\n\nHop  IP Address       Hostname         Sent Recv  Loss%        Avg  Location\n..."
}
```

**ResultToText 格式说明**:

各任务类型的 `ResultToText` 字段采用终端风格的文本输出，便于人工阅读和调试：

| 任务类型 | 输出格式 |
|----------|----------|
| Ping | 标准 ping 输出格式，包含每次响应和统计摘要 |
| TCP | 端口状态和延迟信息 |
| UDP | 发送/接收状态和延迟信息 |
| DNS | dig 风格输出，包含 QUESTION、ANSWER SECTION |
| Traceroute | 表格格式，包含跳数、IP、延迟、丢包率、归属地 |

---

## 四、Tab 2 - 云探测 (Cloud)

**实现文件**: `Managers/CloudProbeManager.swift`

### 4.1 API 概述

**基础 URL**: `https://api.itango.tencent.com/api`

**鉴权方式**: HMAC-SHA-512 签名（详见 [第十章 鉴权配置](#十鉴权配置)）

### 4.2 获取探针列表 API

**URL**: `POST https://api.itango.tencent.com/api`

**鉴权**: 需要（详见 [10.3 签名生成流程](#103-签名生成流程)）

**请求体**:
```json
{
    "Action": "Query",
    "Method": "GetAgentGeo",
    "SystemId": "4",
    "AppendInfo": {
        "UserId": 123  // 当前用户 ID，未登录为 -1
    },
    "Condition": {
        "AddressFamily": 4,  // 4=IPv4, 6=IPv6
        "IsPublic": 1        // 1=公共探针
    }
}
```

**响应体**:
```json
{
    "Return": 0,
    "Details": "",
    "ReqId": "xxx",
    "Data": [
        {
            "Area": "亚洲",
            "AsId": 4134,
            "City": "广州",
            "Country": "中国",
            "ISP": "电信",
            "Province": "广东"
        },
        {
            "Area": "北美洲",
            "AsId": 15169,
            "City": "Mountain View",
            "Country": "美国",
            "ISP": "Google",
            "Province": "California"
        }
    ]
}
```

### 4.3 创建探测任务 API

**URL**: `POST https://api.itango.tencent.com/api`

**鉴权**: 需要（详见 [10.3 签名生成流程](#103-签名生成流程)）

**请求体**:
```json
{
    "Action": "MsmCustomTask",
    "Method": "Create",
    "SystemId": "4",
    "AppendInfo": {
        "UserId": 123  // 当前用户 ID，未登录为 -1
    },
    "Data": {
        "MainTaskName": "itango-ios-app-ping-task",
        "MsmSetting": {
            "Af": 4,  // 4=IPv4, 6=IPv6
            "MsmType": "ping",  // ping / dns / tcp_port / udp_port
            "Options": {
                // Ping/TCP/UDP 选项
                "count": 4,
                "interval": 0.02,
                "size": 64,
                "timeout": 4
                
                // DNS 选项（二选一）
                // "timeout_secs": 10,
                // "rtype": "A",  // A / AAAA / CNAME / MX / TXT / NS
                // "ns": ""       // 指定 DNS 服务器
            }
        },
        "SubTaskList": [
            {
                "SubTaskName": "sub1",
                "AgentScope": [
                    {
                        "Type": "public",
                        "GeoInfo": {
                            "DataSource": "public",
                            "Country": "中国",     // 可选，筛选国家
                            "ISP": "电信",         // 可选，筛选运营商
                            "AsId": 4134          // 可选，指定 AS 号
                        }
                    }
                ],
                "TargetScope": [
                    {
                        "Type": "public",
                        "ExplicitTargetHostList": [
                            "www.qq.com",           // Ping/DNS 目标
                            "www.qq.com:443",       // TCP/UDP 目标（带端口）
                            "[2001:db8::1]:443"     // IPv6 目标（带端口）
                        ]
                    }
                ]
            }
        ]
    }
}
```

**响应体**:
```json
{
    "Return": 0,
    "Details": "",
    "ReqId": "xxx",
    "Data": {
        "MainTaskId": 12345
    }
}
```

### 4.4 查询任务结果 API

**URL**: `POST https://api.itango.tencent.com/api`

**鉴权**: 需要（详见 [10.3 签名生成流程](#103-签名生成流程)）

**请求体**:
```json
{
    "Action": "MsmTaskResult",
    "Method": "RealTimeTaskResult",
    "SystemId": 4,
    "AppendInfo": {
        "UserId": 123  // 当前用户 ID，未登录为 -1
    },
    "Data": {
        "MainId": 12345
    }
}
```

**响应体（Ping/TCP/UDP）**:
```json
{
    "Return": 0,
    "Details": "",
    "ReqId": "xxx",
    "Data": {
        "Finished": true,
        "Detail": [
            {
                "AgentAsId": 4134,
                "AgentCountry": "中国",
                "AgentISP": "电信",
                "AgentProvince": "广东",
                "AvgRttMilli": 50.5,
                "MaxRttMilli": 80.2,
                "MinRttMilli": 30.1,
                "PacketLoss": 0,
                "BuildinAgentRemoteIP": "1.2.3.4",
                "BuildinPeerIP": "5.6.7.8",
                "BuildinTargetHost": "www.qq.com",
                "BuildinLocalTime": "2025-12-23 10:00:00",
                "BuildinErrMessage": "",
                "BuildinMainTaskSetId": 12345,
                "BuildinUserId": 1
            }
        ]
    }
}
```

**响应体（DNS）**:
```json
{
    "Return": 0,
    "Details": "",
    "ReqId": "xxx",
    "Data": {
        "Finished": true,
        "Detail": [
            {
                "AgentAsId": 4134,
                "AgentCountry": "中国",
                "AgentISP": "电信",
                "AgentProvince": "广东",
                "RttMilli": 50.5,
                "AtNameServer": "8.8.8.8",
                "Answers": [
                    {
                        "Class": "IN",
                        "Name": "www.qq.com",
                        "ParseIP": "1.2.3.4",
                        "RRType": "A"
                    }
                ],
                "BuildinAgentRemoteIP": "1.2.3.4",
                "BuildinPeerIP": "5.6.7.8",
                "BuildinTargetHost": "www.qq.com",
                "BuildinErrMessage": "",
                "BuildinMainTaskSetId": 12345
            }
        ]
    }
}
```

**轮询机制**: 最多 5 次，每次间隔 3 秒

---

## 五、Tab 3 - IP查询 (IPQuery)

**实现文件**: `Views/IPQueryView.swift`

### 5.1 功能概述

IP查询功能允许用户输入任意 IP 地址（IPv4 或 IPv6），查询其归属地信息，包括国家、省份、城市、运营商等。

**功能特性**:
- 支持 IPv4 和 IPv6 地址查询
- IP 格式验证
- 历史查询记录（最多 10 条）
- 查询结果支持长按复制

### 5.2 技术实现

**IP 归属地查询**:
- 使用 `IPLocationService.shared.fetchDetailedLocations` 方法
- 调用批量 IP 归属地查询 API

#### 5.2.1 IP 归属地查询 API

**URL**: `POST https://api.itango.tencent.com/api`

**鉴权**: HMAC-SHA-512

**请求体**:
```json
{
    "Action": "HuaTuo",
    "Method": "GetBatchIPInfo",
    "SystemId": 4,
    "AppendInfo": {
        "UserId": 123  // 当前用户 ID，未登录为 -1
    },
    "Data": {
        "IpList": ["1.2.3.4", "2001:db8::1"]
    }
}
```

**响应体**:
```json
{
    "Return": 0,
    "Details": "",
    "ReqId": "xxx",
    "Data": [
        {
            "IP": "1.2.3.4",
            "Success": true,
            "ErrMsg": "",
            "Info": {
                "Id": 12345,
                "IP": "1.2.3.4",
                "Country": "中国",
                "Province": "广东",
                "City": "深圳",
                "Region": "南山区",
                "Address": "中国 广东 深圳 南山区",
                "FrontISP": "电信",
                "BackboneISP": "电信",
                "AsId": 4134,
                "Latitude": 22.5431,
                "Longitude": 114.0579,
                "CreateTime": "2025-12-23 10:00:00"
            }
        }
    ]
}
```

**响应字段说明**:
| 字段 | 类型 | 说明 |
|------|------|------|
| `IP` | String | 查询的 IP 地址 |
| `Country` | String | 国家 |
| `Province` | String | 省份 |
| `City` | String | 城市 |
| `Region` | String | 区县 |
| `FrontISP` | String | 前端运营商 |
| `BackboneISP` | String | 骨干运营商 |
| `AsId` | Int | AS 号 |
| `Latitude` | Double | 纬度 |
| `Longitude` | Double | 经度 |

#### 5.2.2 IP 格式验证

```swift
// IPLocationService.swift
func isValidIP(_ ip: String) -> Bool {
    // IPv4 验证
    var addr4 = in_addr()
    if inet_pton(AF_INET, ip, &addr4) == 1 {
        return true
    }
    
    // IPv6 验证
    var addr6 = in6_addr()
    if inet_pton(AF_INET6, ip, &addr6) == 1 {
        return true
    }
    
    return false
}
```

#### 5.2.3 查询结果数据模型

```swift
struct BatchIPInfo: Codable {
    let IP: String?
    let Country: String?
    let Province: String?
    let City: String?
    let FrontISP: String?
    
    // 计算属性：完整归属地
    var fullLocation: String {
        [Country, Province, City, FrontISP]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
```

### 5.3 历史记录管理

**存储方式**: `UserDefaults`

**存储 Key**: `IPQueryHistory`

**最大记录数**: 10 条

**实现逻辑**:
```swift
// 加载历史记录
private func loadHistory() {
    ipHistory = UserDefaults.standard.stringArray(forKey: ipHistoryKey) ?? []
}

// 保存到历史记录
private func saveToHistory(_ ip: String) {
    // 如果已存在，先移除（实现去重和置顶）
    ipHistory.removeAll { $0 == ip }
    // 插入到最前面
    ipHistory.insert(ip, at: 0)
    // 限制数量
    if ipHistory.count > maxHistoryCount {
        ipHistory = Array(ipHistory.prefix(maxHistoryCount))
    }
    // 保存
    UserDefaults.standard.set(ipHistory, forKey: ipHistoryKey)
}

// 从历史记录删除
private func removeFromHistory(_ ip: String) {
    ipHistory.removeAll { $0 == ip }
    UserDefaults.standard.set(ipHistory, forKey: ipHistoryKey)
}
```

**历史记录功能**:
- 自动去重：相同 IP 查询时自动移到最前
- 单条删除：支持删除单条历史记录
- 快速填充：点击历史记录自动填充到输入框

---

## 六、Tab 4 - 数据 (Data)

**实现文件**: 
- `Views/ChinaMapView.swift` - 主视图
- `Views/ChinaMapWebView.swift` - WebView 封装
- `Managers/AlarmManager.swift` - 告警数据管理
- `Models/AlarmModels.swift` - 数据模型

### 6.1 技术方案

- **组件**: `WKWebView` + `UIViewRepresentable`
- **图表库**: ECharts 5.4.3
- **地图数据**: 阿里云 DataV GeoJSON
- **数据管理**: `AlarmManager` 单例 + `@Published` 响应式

#### 6.1.1 地图视觉分层架构

地图区域采用**双层叠加**架构，实现深色模式下的星空视觉效果：

```
┌─────────────────────────────────────────┐
│           ChinaMapView (ZStack)          │
├─────────────────────────────────────────┤
│  Layer 3: 加载状态 / 错误提示            │  ← 条件显示
├─────────────────────────────────────────┤
│  Layer 2: ChinaMapWebView (ECharts)     │  ← 动态涟漪 + 连线动画
│           - effectScatter 涟漪散点       │
│           - lines 流动连线               │
├─────────────────────────────────────────┤
│  Layer 1: StarryBackgroundView          │  ← 仅深色模式
│           - SwiftUI Canvas 静态星星      │
│           - 深色渐变背景                 │
└─────────────────────────────────────────┘
```

**分层说明**:

| 层级 | 组件 | 渲染技术 | 显示条件 | 效果 |
|------|------|----------|----------|------|
| Layer 1 | `StarryBackgroundView` | SwiftUI Canvas | 深色模式 | 80 颗静态星星 + 深蓝渐变背景 |
| Layer 2 | `ChinaMapWebView` | WKWebView + ECharts | 始终显示 | 地图 + 涟漪动画 + 连线动画 |
| Layer 3 | 加载/错误视图 | SwiftUI | 条件显示 | ProgressView / 错误提示 |

**为什么采用分层架构**:

1. **性能优化**: 静态星空用原生 Canvas 绘制，避免 WebView 额外渲染负担
2. **视觉分离**: 星空背景与地图动画独立，互不干扰
3. **条件渲染**: 浅色模式下不加载星空组件，节省资源
4. **维护性**: 两套视觉效果独立实现，便于单独调整

#### 6.1.2 StarryBackgroundView 实现

StarryBackgroundView 是专为深色模式设计的地图背景组件，仅在系统处于深色模式时显示，为地图提供沉浸式的星空视觉效果。

**实现文件**: `Views/ChinaMapView.swift`

```swift
struct StarryBackgroundView: View {
    // 静态数据，使用固定种子确保每次渲染一致
    private static let starData: [(xRatio: CGFloat, yRatio: CGFloat, size: CGFloat, opacity: Double)] = {
        var result: [(CGFloat, CGFloat, CGFloat, Double)] = []
        srand48(42)  // 固定种子
        for _ in 0..<80 {
            result.append((
                CGFloat(drand48()),           // x 位置比例 (0~1)
                CGFloat(drand48()),           // y 位置比例 (0~1)
                CGFloat(drand48() * 1.5 + 1), // 大小 (1~2.5pt)
                drand48() * 0.6 + 0.4         // 透明度 (0.4~1.0)
            ))
        }
        return result
    }()
    
    var body: some View {
        ZStack {
            // 深色渐变背景
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.05, blue: 0.12),
                    Color(red: 0.05, green: 0.08, blue: 0.18),
                    Color(red: 0.03, green: 0.06, blue: 0.14)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Canvas 绘制静态星星
            Canvas { context, size in
                for star in Self.starData {
                    let rect = CGRect(
                        x: star.xRatio * size.width - star.size / 2,
                        y: star.yRatio * size.height - star.size / 2,
                        width: star.size,
                        height: star.size
                    )
                    context.opacity = star.opacity
                    context.fill(Circle().path(in: rect), with: .color(.white))
                }
            }
        }
    }
}
```

**技术要点**:

| 特性 | 说明 |
|------|------|
| **渲染引擎** | SwiftUI `Canvas`（底层 Core Graphics） |
| **星星数量** | 80 颗 |
| **位置稳定性** | 使用固定种子 `srand48(42)`，每次渲染位置一致 |
| **性能优化** | `static let` 静态数据，只计算一次 |
| **显示条件** | 仅深色模式 (`colorScheme == .dark`) |

#### 6.1.3 ECharts 动态效果

WebView 中的 ECharts 负责渲染动态效果：

**涟漪散点 (`effectScatter`)** - 告警点闪烁效果:
```javascript
{
    type: 'effectScatter',
    coordinateSystem: 'geo',
    rippleEffect: {
        brushType: 'stroke',  // 涟漪描边
        scale: 4              // 扩散倍数
    },
    symbol: 'circle',
    symbolSize: function(val) {
        return 8 + (val[2] || 0) / 10;  // 根据告警数量调整大小
    }
}
```

**流动连线 (`lines`)** - 告警传播动画:
```javascript
{
    type: 'lines',
    effect: {
        show: true,
        period: 4,           // 动画周期 4 秒
        trailLength: 0.3,    // 拖尾长度
        symbol: 'arrow',     // 箭头符号
        symbolSize: 6
    },
    lineStyle: {
        curveness: 0.2       // 曲线弯曲度
    }
}
```

**视觉效果总结**:

| 效果 | 实现层 | 技术 | 动态/静态 |
|------|--------|------|-----------|
| 星空背景 | SwiftUI | Canvas 绑定 | 静态 |
| 深蓝渐变 | SwiftUI | LinearGradient | 静态 |
| 涟漪闪烁 | WebView | ECharts effectScatter | 动态 |
| 连线流动 | WebView | ECharts lines | 动态 |
| 地图底图 | WebView | ECharts geo | 静态 |

#### 6.1.4 深色模式实现

地图支持跟随系统自动切换深色/浅色模式，通过 SwiftUI 和 JavaScript 双向联动实现。

**模式检测与传递**：

```swift
// ChinaMapView.swift - 检测系统主题
@Environment(\.colorScheme) private var colorScheme

var body: some View {
    ZStack {
        // 深色模式下显示星空背景
        if colorScheme == .dark {
            StarryBackgroundView()
        }
        
        ChinaMapWebView(
            isDarkMode: colorScheme == .dark  // 传递给 WebView
        )
    }
}
```

**WebView 初始化**：在生成 HTML 时将深色模式状态注入 JavaScript：

```swift
// ChinaMapWebView.swift
private func generateHTML() -> String {
    let isDarkModeJS = isDarkMode ? "true" : "false"
    return """
    <script>
        var isDarkMode = \(isDarkModeJS);
    </script>
    """
}
```

**动态更新**：当系统主题变化时，通过 `evaluateJavaScript` 实时更新：

```swift
func updateUIView(_ webView: WKWebView, context: Context) {
    let script = "if(typeof updateDarkMode === 'function') updateDarkMode(\(isDarkMode));"
    webView.evaluateJavaScript(script, completionHandler: nil)
}
```

**ECharts 地图样式函数**：

```javascript
function getGeoStyle() {
    if (isDarkMode) {
        return {
            itemStyle: {
                areaColor: 'rgba(30, 50, 80, 0.3)',      // 深蓝半透明
                borderColor: 'rgba(100, 180, 255, 0.6)', // 亮蓝边框
                borderWidth: 1.5
            },
            emphasis: {
                label: { show: true, color: '#fff' },
                itemStyle: { areaColor: 'rgba(60, 100, 150, 0.5)' }
            }
        };
    } else {
        return {
            itemStyle: {
                areaColor: '#e6f7ff',     // 浅蓝色
                borderColor: '#1890ff',    // 蓝色边框
                borderWidth: 1
            },
            emphasis: {
                label: { show: true, color: '#333' },
                itemStyle: { areaColor: '#91d5ff' }
            }
        };
    }
}

// 深色模式更新函数
function updateDarkMode(dark) {
    isDarkMode = dark;
    if (chart) {
        chart.setOption(getOption());  // 重新应用完整配置
    }
}
```

**Tooltip 样式适配**：

```javascript
tooltip: {
    backgroundColor: isDarkMode ? 'rgba(30, 40, 60, 0.9)' : 'rgba(255, 255, 255, 0.9)',
    borderColor: isDarkMode ? 'rgba(100, 180, 255, 0.3)' : '#ccc',
    textStyle: { color: isDarkMode ? '#fff' : '#333' }
}
```

**样式对比**：

| 元素 | 浅色模式 | 深色模式 |
|------|----------|----------|
| 地图区域填充 | `#e6f7ff` (浅蓝) | `rgba(30, 50, 80, 0.3)` (深蓝半透明) |
| 地图边框 | `#1890ff` 1px | `rgba(100, 180, 255, 0.6)` 1.5px |
| 高亮区域 | `#91d5ff` | `rgba(60, 100, 150, 0.5)` |
| 省份标签 | `#333` (深灰) | `#fff` (白色) |
| Tooltip 背景 | `rgba(255,255,255,0.9)` | `rgba(30, 40, 60, 0.9)` |
| 星空背景 | 不显示 | 80 颗静态星星 + 深蓝渐变 |

### 6.2 架构设计

#### 6.2.1 数据模型

```swift
// 告警 API 响应模型
struct AlarmAPIResponse: Codable {
    let Return: Int
    let Details: String?
    let Data: AlarmData?
}

struct AlarmData: Codable {
    let List: [AlarmItem]?
    let TotalRows: Int?
}

// 告警项模型
struct AlarmItem: Codable, Identifiable {
    let AlarmTime: String?      // 告警时间
    let RecoverTime: String?    // 恢复时间
    let AlarmType: String?      // 告警类型
    let CIName: String?         // CI 名称
    let DataType: String?       // 数据类型
    let DstIsp: String?         // 目标运营商
    let DstStr: String?         // 目标省份（逗号分隔）
    let Level: String?          // 告警级别 (level1/level2/level3)
    let Network: String?        // 网络类型
    let SrcIsp: String?         // 源运营商
    let SrcStr: String?         // 源省份/城市
    let Title: String?          // 告警标题
    
    var id: String {
        "\(AlarmTime ?? "")-\(SrcStr ?? "")-\(DstStr ?? "")"
    }
}

// 告警级别枚举
enum AlertLevel: String, Codable {
    case normal = "normal"      // level3 - 轻微 - 浅红色 #ff9999
    case warning = "warning"    // level2 - 中等 - 黄色 #ffcc00
    case critical = "critical"  // level1 - 严重 - 红色 #ff4d4f
}

// 地图连线数据模型
struct AlertLine: Identifiable {
    let id: String
    let fromProvince: String      // 源省份
    let toProvince: String        // 目标省份
    let alertLevel: AlertLevel    // 告警级别
    let count: Int                // 告警数量
}
```

#### 6.2.2 省份映射工具

```swift
struct ProvinceMapper {
    /// 城市到省份的映射
    static let cityToProvinceMap: [String: String] = [
        "待定": "新疆",  // 特殊映射
        "杭州": "浙江", "成都": "四川", "北京": "北京", "上海": "上海",
        "广州": "广东", "深圳": "广东", "汕尾": "广东", "武汉": "湖北", "南京": "江苏",
        "西安": "陕西", "重庆": "重庆", "天津": "天津", "苏州": "江苏",
        "郑州": "河南", "长沙": "湖南", "沈阳": "辽宁", "青岛": "山东",
        "大连": "辽宁", "厦门": "福建", "宁波": "浙江", "福州": "福建",
        "济南": "山东", "哈尔滨": "黑龙江", "长春": "吉林", "昆明": "云南",
        "贵阳": "贵州", "南宁": "广西", "太原": "山西", "石家庄": "河北",
        "合肥": "安徽", "南昌": "江西", "海口": "海南", "兰州": "甘肃",
        "银川": "宁夏", "西宁": "青海", "乌鲁木齐": "新疆", "拉萨": "西藏",
        "呼和浩特": "内蒙古", "香港": "香港", "澳门": "澳门", "台北": "台湾"
    ]
    
    /// 省份名称标准化映射（去除"省"、"市"等后缀）
    static let provinceNormalizeMap: [String: String] = [
        "甘肃省": "甘肃", "湖北省": "湖北", "福建省": "福建", "江西省": "江西",
        "河北省": "河北", "山东省": "山东", "陕西省": "陕西", "黑龙江省": "黑龙江",
        "吉林省": "吉林", "重庆市": "重庆", "湖南省": "湖南", "贵州省": "贵州",
        "辽宁省": "辽宁", "广西壮族自治区": "广西", "上海市": "上海",
        "内蒙古自治区": "内蒙古", "安徽省": "安徽", "山西省": "山西",
        "云南省": "云南", "浙江省": "浙江", "天津市": "天津",
        "西藏自治区": "西藏", "新疆维吾尔自治区": "新疆", "四川省": "四川",
        "江苏省": "江苏", "宁夏回族自治区": "宁夏", "海南省": "海南",
        "北京市": "北京", "河南省": "河南", "广东省": "广东", "青海省": "青海",
        "香港特别行政区": "香港", "澳门特别行政区": "澳门", "台湾省": "台湾"
    ]
    
    static func cityToProvince(_ city: String) -> String
    static func normalizeProvince(_ province: String) -> String
}
```

**当前支持的告警源城市** (22个):

| 城市 | 省份 | 城市 | 省份 |
|------|------|------|------|
| 广州 | 广东 | 上海 | 上海 |
| 北京 | 北京 | 南京 | 江苏 |
| 天津 | 天津 | 成都 | 四川 |
| 重庆 | 重庆 | 济南 | 山东 |
| 沈阳 | 辽宁 | 石家庄 | 河北 |
| 武汉 | 湖北 | 长沙 | 湖南 |
| 合肥 | 安徽 | 郑州 | 河南 |
| 杭州 | 浙江 | 汕尾 | 广东 |
| 贵阳 | 贵州 | 南昌 | 江西 |
| 福州 | 福建 | 深圳 | 广东 |
| 西安 | 陕西 | 太原 | 山西 |

#### 6.2.3 告警管理器

```swift
@MainActor
class AlarmManager: ObservableObject {
    static let shared = AlarmManager()
    
    @Published var alarmItems: [AlarmItem] = []      // 原始告警数据
    @Published var alertLines: [AlertLine] = []      // 地图连线数据
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    /// 获取告警数据
    func fetchAlarmData() async
    
    /// 将告警数据转换为地图连线数据
    func convertToAlertLines(_ alarms: [AlarmItem]) -> [AlertLine]
    
    /// 根据省份筛选告警
    func filterAlarms(by province: String?) -> [AlarmItem]
}
```

### 6.3 告警数据 API

**URL**: `POST https://api.itango.tencent.com/api`

**鉴权**: HMAC-SHA-512

**请求体**:
```json
{
    "Action": "QueryData",
    "Method": "run",
    "SystemId": "4",
    "SchemaId": "netq_isp_alarm_info",
    "ReturnTotalRows": 0,
    "AppendInfo": {
        "UserId": 123  // 当前用户 ID，未登录为 -1
    },
    "Data": {
        "ResultColumns": {
            "AlarmTime": "",
            "RecoverTime": "",
            "AlarmType": "",
            "CIName": "",
            "DataType": "",
            "DstIsp": "",
            "DstStr": "",
            "Level": "",
            "Network": "",
            "SrcIsp": "",
            "SrcStr": "",
            "Title": ""
        },
        "SearchCondition": {
            "AlarmTime": {
                "gt": "2025-12-24 10:00:00",
                "lt": "2025-12-25 10:00:00"
            },
            "RecoverTime": {"eq": "<<empty>>"}
        },
        "Sorts": [
            {"Column": "AlarmTime", "SortType": "desc"}
        ],
        "Limit": {
            "Size": 500,
            "Start": 0
        }
    }
}
```

**响应体**:
```json
{
    "Return": 0,
    "Details": "",
    "Data": {
        "List": [
            {
                "AlarmTime": "2025-12-25 09:30:00",
                "RecoverTime": "",
                "AlarmType": "网络异常",
                "CIName": "ci_001",
                "DataType": "延迟",
                "DstIsp": "电信",
                "DstStr": "广东省,福建省,江西省",
                "Level": "level1",
                "Network": "骨干网",
                "SrcIsp": "电信",
                "SrcStr": "杭州",
                "Title": "杭州到广东等地区延迟异常告警"
            }
        ],
        "TotalRows": 15
    }
}
```

**查询条件说明**:
| 字段 | 说明 |
|------|------|
| `AlarmTime.gt/lt` | 告警时间范围（最近 24 小时） |
| `RecoverTime.eq: "<<empty>>"` | 只查询未恢复的告警 |
| `Limit.Size` | 最大返回 500 条 |

### 6.4 数据转换逻辑

**告警数据 → 地图连线**:
```swift
func convertToAlertLines(_ alarms: [AlarmItem]) -> [AlertLine] {
    var lineMap: [String: (level: AlertLevel, count: Int)] = [:]
    
    for alarm in alarms {
        let from = alarm.sourceProvince  // 城市转省份
        guard !from.isEmpty else { continue }
        
        for to in alarm.destinationProvinces {  // 解析目标省份列表
            let key = "\(from)-\(to)"
            if let existing = lineMap[key] {
                // 取更高级别的告警
                let newLevel = alarm.alertLevel.rawValue < existing.level.rawValue 
                    ? alarm.alertLevel : existing.level
                lineMap[key] = (newLevel, existing.count + 1)
            } else {
                lineMap[key] = (alarm.alertLevel, 1)
            }
        }
    }
    
    // 按告警级别排序（严重的在前）
    return lines.sorted { $0.alertLevel.rawValue < $1.alertLevel.rawValue }
}
```

**告警级别映射**:
| API Level | AlertLevel | 显示文本 | 颜色 |
|-----------|------------|----------|------|
| `level1` | `.critical` | L1 (严重) | 红色 `#ff4d4f` |
| `level2` | `.warning` | L2 (中等) | 黄色 `#ffcc00` |
| `level3` | `.normal` | L3 (轻微) | 浅红色 `#ff9999` |

### 6.5 WebView 通信机制

**Swift → JavaScript**:
```swift
// 更新告警数据
let linesJSON = generateLinesJSON()
let script = "if(typeof updateAlertLines === 'function') updateAlertLines(\(linesJSON));"
webView.evaluateJavaScript(script, completionHandler: nil)
```

**JavaScript → Swift** (通过 `WKScriptMessageHandler`):
```javascript
// 省份点击事件
window.webkit.messageHandlers.provinceSelected.postMessage(params.name);

// 地图加载完成
window.webkit.messageHandlers.mapLoaded.postMessage('loaded');

// 地图加载错误
window.webkit.messageHandlers.mapError.postMessage(errorMessage);
```

### 6.6 外部资源依赖

| 资源 | CDN 地址 | 备用 CDN |
|------|----------|----------|
| ECharts | `cdn.jsdelivr.net/npm/echarts@5.4.3/dist/echarts.min.js` | `cdn.bootcdn.net/ajax/libs/echarts/5.4.3/echarts.min.js` |
| 中国地图 GeoJSON | `geo.datav.aliyun.com/areas_v3/bound/100000_full.json` | - |

### 6.7 省份坐标映射

```javascript
var geoCoordMap = {
    '北京': [116.46, 39.92],
    '天津': [117.2, 39.13],
    '上海': [121.48, 31.22],
    '重庆': [106.54, 29.59],
    '河北': [114.48, 38.03],
    '山西': [112.53, 37.87],
    '辽宁': [123.38, 41.8],
    '吉林': [125.35, 43.88],
    '黑龙江': [126.63, 45.75],
    '江苏': [118.78, 32.04],
    '浙江': [120.19, 30.26],
    '安徽': [117.27, 31.86],
    '福建': [119.3, 26.08],
    '江西': [115.89, 28.68],
    '山东': [117.0, 36.65],
    '河南': [113.65, 34.76],
    '湖北': [114.31, 30.52],
    '湖南': [112.98, 28.19],
    '广东': [113.23, 23.16],
    '海南': [110.35, 20.02],
    '四川': [104.06, 30.67],
    '贵州': [106.71, 26.57],
    '云南': [102.73, 25.04],
    '陕西': [108.95, 34.27],
    '甘肃': [103.73, 36.03],
    '青海': [101.74, 36.56],
    '台湾': [121.5, 25.05],
    '内蒙古': [111.65, 40.82],
    '广西': [108.33, 22.84],
    '西藏': [91.11, 29.97],
    '宁夏': [106.27, 38.47],
    '新疆': [87.68, 43.77],
    '香港': [114.17, 22.28],
    '澳门': [113.54, 22.19]
};
```

### 6.8 ECharts 配置

**地图配置**:
```javascript
geo: {
    map: 'china',
    roam: false,           // 禁止缩放和平移
    zoom: calculateZoom(), // 根据屏幕宽度动态计算
    center: [104, 29],     // 中心点（纬度 29 让地图偏上显示）
    itemStyle: {
        areaColor: '#e6f7ff',    // 区域颜色
        borderColor: '#1890ff',   // 边框颜色
        borderWidth: 1
    },
    emphasis: {
        itemStyle: {
            areaColor: '#91d5ff'  // 高亮颜色
        }
    }
}
```

**Zoom 自适应算法**:

根据 WebView 容器宽度动态计算 zoom 值，适配不同屏幕尺寸的设备：

```javascript
function calculateZoom() {
    var width = window.innerWidth;
    
    if (width <= 320) {
        return 1.0;   // iPhone SE
    } else if (width <= 375) {
        return 1.1;   // iPhone 12 mini
    } else if (width <= 393) {
        return 1.15;  // iPhone 14/15 Pro
    } else if (width <= 430) {
        return 1.2;   // iPhone 15 Pro Max
    } else if (width <= 500) {
        return 1.3;   // 大屏手机
    } else {
        return 1.4;   // iPad
    }
}
```

| 设备 | 屏幕宽度 | Zoom |
|------|----------|------|
| iPhone SE | ≤320pt | 1.0 |
| iPhone 12 mini | ≤375pt | 1.1 |
| iPhone 14/15 Pro | ≤393pt | 1.15 |
| iPhone 15 Pro Max | ≤430pt | 1.2 |
| 大屏手机 | ≤500pt | 1.3 |
| iPad | >500pt | 1.4 |

**窗口 resize 时自动更新**:
```javascript
window.addEventListener('resize', function() {
    chart.resize();
    chart.setOption({
        geo: { zoom: calculateZoom() }
    });
});
```

**连线配置** (飞线效果):
```javascript
{
    type: 'lines',
    zlevel: 2,
    effect: {
        show: true,
        period: 4,              // 动画周期
        trailLength: 0.3,       // 拖尾长度
        symbol: 'arrow',        // 箭头符号
        symbolSize: 6
    },
    lineStyle: {
        width: 2,
        opacity: 0.8,
        curveness: 0.2          // 曲率
    }
}
```

**散点配置** (涟漪效果):
```javascript
{
    type: 'effectScatter',
    coordinateSystem: 'geo',
    zlevel: 3,
    rippleEffect: {
        brushType: 'stroke',
        scale: 4                // 涟漪缩放比例
    },
    symbolSize: function(val) {
        return 8 + (val[2] || 0) / 10;  // 根据告警数动态调整大小
    }
}
```

### 6.9 错误处理

| 错误类型 | 处理方式 |
|----------|----------|
| ECharts CDN 加载失败 | 自动切换备用 CDN，最多尝试 2 次 |
| 地图 GeoJSON 加载失败 | 显示错误信息，提供重试按钮 |
| WebView 加载失败 | 显示错误信息，提供重试按钮 |
| CDN 全部失败 | 显示 "ECharts 加载失败，所有 CDN 均无法访问" |
| API 请求失败 | 显示错误信息，支持手动刷新 |

### 6.10 功能特性

- **数据加载**: 页面进入时自动加载最近 24 小时未恢复的告警
- **手动刷新**: 导航栏刷新按钮，刷新成功显示 Toast 提示
- **省份点击**: 点击地图省份筛选相关告警
- **告警筛选**: 按选中省份筛选告警列表，显示筛选标签
- **告警展开**: 点击告警行展开显示详细标题信息
- **动态更新**: 支持实时更新告警数据和地图连线
- **飞线动画**: 告警连线带箭头飞行效果
- **涟漪效果**: 告警点带涟漪扩散动画
- **智能时间**: 告警时间智能显示（今天/昨天/日期）

### 6.11 告警时间格式化

```swift
var formattedTime: String {
    guard let time = AlarmTime else { return "" }
    
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    guard let alarmDate = dateFormatter.date(from: time) else { return time }
    
    let calendar = Calendar.current
    let timeFormatter = DateFormatter()
    timeFormatter.dateFormat = "HH:mm"
    let timeStr = timeFormatter.string(from: alarmDate)
    
    if calendar.isDateInToday(alarmDate) {
        return timeStr                    // 今天: "21:48"
    } else if calendar.isDateInYesterday(alarmDate) {
        return "昨天 \(timeStr)"          // 昨天: "昨天 21:48"
    } else {
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "MM-dd"
        return "\(dayFormatter.string(from: alarmDate)) \(timeStr)"  // 更早: "12-24 21:48"
    }
}
```

---

## 七、Tab 5 - 我的 (Profile)

### 7.1 用户系统

**实现文件**: `Managers/UserManager.swift`

**API 基础 URL**: `https://itango.tencent.com/out/itango/`

#### 6.1.1 游客登录

**URL**: `POST https://itango.tencent.com/out/itango/player`

**请求体**: 无（空 POST）

**响应体**:
```json
{
    "status": 0,
    "msg": "",
    "data": {
        "Id": 12345,
        "Username": "player_12345",
        "UserType": "player",
        "Name": "",
        "PhoneNumber": "",
        "Company": "",
        "Duty": ""
    }
}
```

#### 6.1.2 手机号登录

**URL**: `POST https://itango.tencent.com/out/itango/login`

**请求体**:
```json
{
    "Verification": "Phone",
    "Username": "",
    "Password": "",
    "CaptchaValue": "",
    "CaptchaId": "",
    "UserType": "normal",  // normal / admin
    "PhoneNumber": "13800138000",
    "Code": "123456",      // 短信验证码
    "IsRemember": false
}
```

**响应体**:
```json
{
    "status": 0,
    "msg": "",
    "data": {
        "Id": 12345,
        "Username": "user_12345",
        "UserType": "normal",
        "Name": "张三",
        "PhoneNumber": "13800138000",
        "Company": "腾讯",
        "Duty": "工程师"
    }
}
```

#### 6.1.3 账号密码登录

**URL**: `POST https://itango.tencent.com/out/itango/login`

**请求体**:
```json
{
    "Verification": "Account",
    "Username": "admin",
    "Password": "password123",
    "CaptchaValue": "abcd",     // 图形验证码输入值
    "CaptchaId": "captcha_xxx", // 图形验证码 ID
    "UserType": "normal",
    "PhoneNumber": "",
    "Code": "",
    "IsRemember": false
}
```

**响应体**: 同手机号登录

#### 6.1.4 发送短信验证码

**URL**: `POST https://itango.tencent.com/out/sms/code`

**请求体**:
```json
{
    "PhoneNumber": "13800138000",
    "Scene": "login"
}
```

**响应体**:
```json
{
    "status": 0,
    "msg": "",
    "data": ""
}
```

#### 6.1.5 获取图形验证码

**URL**: `GET https://itango.tencent.com/out/captcha`

**响应体**:
```json
{
    "status": 0,
    "msg": "",
    "data": {
        "captchaId": "captcha_xxx",
        "code": 0,
        "data": "data:image/png;base64,iVBORw0KGgo...",  // Base64 图片
        "msg": ""
    }
}
```

#### 6.1.6 登出

**URL**: `POST https://itango.tencent.com/out/itango/logout`

**请求体**: `{}`

**响应体**:
```json
{
    "status": 0,
    "msg": ""
}
```

#### 6.1.7 注销账号

**实现文件**: `Managers/UserManager.swift`

**功能说明**:
- 注销账号后，用户的账号数据将被清除
- 此操作不可恢复
- 目前实现为本地清除用户状态（调用 logout 方法）

**本地处理流程**:
1. 调用服务端登出接口
2. 清除本地 UserDefaults 中的用户数据
3. 重置 `currentUser` 和 `isLoggedIn` 状态

**注意**: 如后端支持账号注销 API，可扩展为调用服务端接口

### 7.2 历史记录

**实现文件**: `Managers/TaskHistoryManager.swift`

**存储方式**: `UserDefaults` (JSON 编码)

**支持的任务类型**:
- Ping \/ Traceroute \/ DNS \/ TCP \/ UDP \/ HTTP \/ Speed Test

**功能**:
- 14 天自动过期清理
- 支持上传到服务器
- 按任务类型筛选

#### 6.2.1 上传历史记录 API

**URL**: `POST https://api.itango.tencent.com/api`

**鉴权**: HMAC-SHA-512

**请求体**:
```json
{
    "Action": "MsmReceive",
    "Method": "BatchRun",
    "SystemId": "4",
    "Data": [
        {
            "MsmType": "ping",  // ping / tcp_port / udp_port / dns / mtr
            "MsmDatas": {
                // 通用字段
                "ExampleUniqueKey": "",
                "ExampleReportId": 0,
                "LocalDeviceType": "iOS",
                "LocalDeviceName": "iPhone 15 Pro",
                "LocalDeviceModel": "iPhone16,1",
                "LocalDeviceIdentifier": "xxx",
                "LocalSystemVersion": "iOS 17.0",
                "LocalNetwork": "WiFi",
                "LocalRecordType": "history",  // 历史记录标识
                "LocalExecTime": "2025-12-23 10:00:00",
                "Addr": "www.qq.com",
                "BuildinAf": "4",
                "BuildinAgentId": "",
                "BuildinAgentVersion": "1.0.0",
                "BuildinDurationNano": 1000000000,
                "BuildinErrMessage": "",
                "BuildinExcMode": "once",
                "BuildinFinishTimestampMilli": 1703304000000,
                "BuildinId": -1,
                "BuildinIntervalDuration": "1s",
                "BuildinLocalTime": "2025-12-23 10:00:00",
                "BuildinMainTaskSetId": -1,
                "BuildinPeerIP": "1.2.3.4",
                "BuildinSource": "app",
                "BuildinSubTaskSetId": -1,
                "BuildinTargetHost": "www.qq.com",
                "BuildinTaskKey": "",
                "BuildinTimestampMilli": 1703304000000,
                "BuildinUserId": 123,
                "BuildinUtcTime": "2025-12-23T02:00:00.000Z",
                "LocalIPAddress": "192.168.1.100",
                "MsmType": "ping",
                
                // Ping 特有字段
                "AvgRttMicro": 50000,
                "MaxRttMicro": 80000,
                "MinRttMicro": 30000,
                "StdDevRttMicro": 10000,
                "PacketsSent": 4,
                "PacketsRecv": 4,
                "PacketLoss": 0,
                "RttsMicro": [30000, 40000, 50000, 80000],
                "RttsMilli": [30, 40, 50, 80],
                "Cname": "",
                "IPAddr": "1.2.3.4",
                "Network": "ip",
                "ResultToText": "PING www.qq.com (1.2.3.4): 64 data bytes\n..."
            }
        }
    ]
}
```

**响应体**:
```json
{
    "Return": 0,
    "Details": "",
    "ReqId": "xxx"
}
```

**注意**: 上传历史记录需要用户已登录且非游客状态

### 7.3 用户反馈

**实现文件**: `Views/ProfileView.swift` (FeedbackView)

#### 6.3.1 提交用户反馈 API

**URL**: `POST https://api.itango.tencent.com/api`

**鉴权**: HMAC-SHA-512

**请求体**:
```json
{
    "Action": "App",
    "Method": "Feedback",
    "Data": {
        "Content": "这是用户反馈的内容...",
        "Contact": "user@example.com",  // 用户联系方式（邮箱或手机号）
        "ContentType": "反馈"
    }
}
```

**响应体**:
```json
{
    "Return": 0,
    "Details": "",
    "ReqId": "xxx"
}
```

**功能说明**:
- 用户可以提交意见反馈
- 支持填写联系方式（可选）
- 提交成功后显示成功提示并自动返回

---

## 七、APP 更新

**实现文件**: `Managers/AppUpdateManager.swift`

### 7.1 更新检查机制

**触发时机**:
1. **应用启动时自动检查**: 在 `ContentView` 的 `.task` 修饰符中调用 `checkUpdateOnLaunch()`
2. **用户手动检查**: 在"关于"页面点击检查更新

**启动时检查流程**:
```swift
// ContentView.swift
.task {
    // 启动时检查更新
    await updateManager.checkUpdateOnLaunch()
}
```

**频率控制**:
- 检查间隔: 24 小时（`checkInterval = 86400` 秒）
- 如果距离上次检查不足 24 小时，跳过检查
- 上次检查时间存储在 `UserDefaults`（Key: `LastUpdateCheckTime`）

**更新提示弹窗**:
- 使用 SwiftUI 原生 `.alert` 修饰符
- 绑定到 `updateManager.showUpdateAlert`
- 根据 `isForceUpdate` 显示不同按钮选项

**更新类型**:
| 类型 | 说明 | 用户操作 |
|------|------|----------|
| 无更新 | 当前版本 >= 最新版本 | 无提示 |
| 可选更新 | 有新版本，但不强制 | 可选择"稍后更新"、"忽略此版本"或"立即更新" |
| 强制更新 | 当前版本 < 最低支持版本，或 `forceUpdate=true` | 只能点击"立即更新"，无法关闭弹窗 |

**忽略版本机制**:
- 用户点击"忽略此版本"后，该版本号存储到 `UserDefaults`（Key: `IgnoredAppVersion`）
- 自动检查时，如果最新版本已被忽略，不再提示
- 手动检查时，忽略此设置，仍会提示更新

### 7.2 检查版本更新 API

**URL**: `POST https://api.itango.tencent.com/api`

**鉴权**: HMAC-SHA-512

**请求体**:
```json
{
    "Action": "App",
    "Method": "CheckVersion",
    "Data": {
        "Platform": "iOS",
        "CurrentVersion": "1.0.0",
        "DeviceModel": "iPhone16,1",
        "SystemVersion": "17.0"
    }
}
```

**响应体**:
```json
{
    "Return": 0,
    "Details": "",
    "ReqId": "xxx",
    "Data": {
        "LatestVersion": "1.2.0",      // 最新版本号
        "MinVersion": "1.0.0",          // 最低支持版本，低于此版本强制更新
        "UpdateTitle": "新版本更新",     // 更新标题
        "UpdateContent": "1. 修复已知问题\n2. 优化性能\n3. 新增功能",  // 更新内容
        "DownloadUrl": "https://apps.apple.com/app/id123456789",  // App Store 下载链接
        "ForceUpdate": false,           // 是否强制更新
        "PublishTime": "2025-12-23 10:00:00"  // 发布时间
    }
}
```

### 7.3 版本比较逻辑

```swift
// 比较版本号: 返回 -1 表示 v1 < v2, 0 表示相等, 1 表示 v1 > v2
func compareVersions(_ v1: String, _ v2: String) -> Int {
    let parts1 = v1.split(separator: ".").compactMap { Int($0) }
    let parts2 = v2.split(separator: ".").compactMap { Int($0) }
    
    let maxLength = max(parts1.count, parts2.count)
    
    for i in 0..<maxLength {
        let p1 = i < parts1.count ? parts1[i] : 0
        let p2 = i < parts2.count ? parts2[i] : 0
        
        if p1 < p2 { return -1 }
        if p1 > p2 { return 1 }
    }
    
    return 0
}
```

### 7.4 更新判断流程

1. 比较 `currentVersion` 与 `latestVersion`
   - 如果 `currentVersion >= latestVersion`：无需更新
2. 比较 `currentVersion` 与 `minVersion`
   - 如果 `currentVersion < minVersion` 或 `forceUpdate == true`：强制更新
3. 检查用户是否已忽略此版本
   - 如果已忽略：不提示更新
4. 否则：可选更新

### 7.5 本地存储

| Key | 说明 |
|-----|------|
| `LastUpdateCheckTime` | 上次检查更新时间 |
| `IgnoredAppVersion` | 用户忽略的版本号 |

---

## 八、公共服务

### 8.1 网络服务

**实现文件**: `Services/NetworkService.swift`

**功能**:
- HTTP GET/POST 请求封装
- HMAC-SHA-256/512 签名鉴权
- IP 归属地查询（单个/批量）
- 中文转拼音
- 运营商/国家名称翻译

### 8.2 IP 归属地服务

**实现文件**: `Services/IPLocationService.swift`, `Services/NetworkService.swift`

#### 8.2.1 查询当前公网出口 IP

**URL**: `GET https://itango.tencent.com/out/itango/myip`

**鉴权**: 无

**响应体**:
```json
{
    "status": 0,
    "msg": "",
    "data": {
        "IP": "1.2.3.4",
        "Code": 0,
        "ErrMessage": "",
        "AsnInfo": {
            "Id": 12345,
            "IP": "1.2.3.4",
            "Country": "中国",
            "Province": "广东",
            "City": "深圳",
            "Region": "南山区",
            "Address": "中国 广东 深圳 南山区",
            "FrontISP": "电信",
            "BackboneISP": "电信",
            "AsId": 4134,
            "Latitude": 22.5431,
            "Longitude": 114.0579,
            "CreateTime": "2025-12-23 10:00:00"
        }
    }
}
```

#### 8.2.2 批量查询 IP 归属地

**URL**: `POST https://api.itango.tencent.com/api`

**鉴权**: HMAC-SHA-512

**请求体**:
```json
{
    "Action": "HuaTuo",
    "Method": "GetBatchIPInfo",
    "SystemId": 4,
    "AppendInfo": {
        "UserId": 123  // 当前用户 ID，未登录为 -1
    },
    "Data": {
        "IpList": ["1.2.3.4", "5.6.7.8", "2001:db8::1"]
    }
}
```

**响应体**:
```json
{
    "Return": 0,
    "Details": "",
    "ReqId": "xxx",
    "Data": [
        {
            "IP": "1.2.3.4",
            "Success": true,
            "ErrMsg": "",
            "Info": {
                "Id": 12345,
                "IP": "1.2.3.4",
                "Country": "中国",
                "Province": "广东",
                "City": "深圳",
                "Region": "南山区",
                "Address": "中国 广东 深圳 南山区",
                "FrontISP": "电信",
                "BackboneISP": "电信",
                "AsId": 4134,
                "Latitude": 22.5431,
                "Longitude": 114.0579,
                "CreateTime": "2025-12-23 10:00:00"
            }
        },
        {
            "IP": "5.6.7.8",
            "Success": true,
            "ErrMsg": "",
            "Info": {
                "Id": 12346,
                "IP": "5.6.7.8",
                "Country": "美国",
                "Province": "California",
                "City": "Mountain View",
                "Region": "",
                "Address": "美国 California Mountain View",
                "FrontISP": "Google",
                "BackboneISP": "Google",
                "AsId": 15169,
                "Latitude": 37.4056,
                "Longitude": -122.0775,
                "CreateTime": "2025-12-23 10:00:00"
            }
        }
    ]
}
```

#### 8.2.3 私有 IP 识别

**实现文件**: `Services/IPLocationService.swift`

在查询 IP 归属地之前，系统会先识别私有/特殊 IP 地址，避免无效的 API 请求。

**识别的 IP 类型**:

| 地址范围 | 类型 | 说明 |
|---------|------|------|
| `10.x.x.x` | IPv4 | A 类私有地址 |
| `172.16-31.x.x` | IPv4 | B 类私有地址 |
| `192.168.x.x` | IPv4 | C 类私有地址 |
| `127.x.x.x` | IPv4 | 本地回环地址 |
| `169.254.x.x` | IPv4 | 链路本地地址 (APIPA) |
| `0.0.0.0` | IPv4 | 无效地址 |
| `255.255.255.255` | IPv4 | 广播地址 |
| `::1` | IPv6 | 回环地址 |
| `fe80:` 开头 | IPv6 | 链路本地地址 |
| `fc` / `fd` 开头 | IPv6 | 唯一本地地址 (ULA) |

**UI 显示效果**:
- 归属地显示为 "本地网络" (英文: "Local Network")
- 国家/地区显示为 "本地" (英文: "Local")
- 不会调用远程 API 查询（直接返回本地结果并缓存）

**核心实现**:

```swift
// IPLocationService.swift
func isPrivateIP(_ ip: String) -> Bool {
    // IPv6 本地地址
    let lowercaseIP = ip.lowercased()
    if lowercaseIP.hasPrefix("::1") ||           // IPv6 回环地址
       lowercaseIP.hasPrefix("fe80:") ||         // IPv6 链路本地地址
       lowercaseIP.hasPrefix("fc") ||            // IPv6 唯一本地地址 (ULA)
       lowercaseIP.hasPrefix("fd") {             // IPv6 唯一本地地址 (ULA)
        return true
    }
    
    // IPv4 私有地址
    if ip.hasPrefix("10.") ||                    // A 类私有地址
       ip.hasPrefix("192.168.") ||               // C 类私有地址
       ip.hasPrefix("127.") ||                   // 本地回环地址
       ip.hasPrefix("169.254.") ||               // 链路本地地址 (APIPA)
       ip == "0.0.0.0" ||                        // 无效地址
       ip == "255.255.255.255" {                 // 广播地址
        return true
    }
    
    // B 类私有地址 172.16.x.x - 172.31.x.x
    if ip.hasPrefix("172.") {
        let parts = ip.split(separator: ".")
        if parts.count >= 2, let second = Int(parts[1]) {
            if second >= 16 && second <= 31 {
                return true
            }
        }
    }
    
    return false
}
```

**查询流程优化**:

1. 批量查询时，先分离私有 IP、已缓存 IP 和需要查询的公网 IP
2. 私有 IP 直接返回本地化的归属地信息并缓存，不发起 API 请求
3. 已缓存的 IP 直接使用缓存结果
4. 仅对未缓存的公网 IP 发起批量查询 API
5. 查询结果写入缓存供后续使用

```swift
// IPLocationService.swift

// 缓存
private var locationCache: [String: String] = [:]
private var detailedCache: [String: BatchIPInfo] = [:]
private let cacheLock = NSLock()

func fetchLocations(for ips: [String]) async -> [String: String] {
    var locations: [String: String] = [:]
    var publicIPs: [String] = []
    
    for ip in uniqueIPs {
        if let privateLocation = getPrivateIPLocation(ip) {
            // 私有 IP：直接返回并缓存
            locations[ip] = privateLocation
            cacheLocation(ip, location: privateLocation)
        } else if let cached = getCachedLocation(ip) {
            // 已缓存：直接使用
            locations[ip] = cached
        } else {
            // 需要查询
            publicIPs.append(ip)
        }
    }
    
    // 仅查询未缓存的公网 IP
    if !publicIPs.isEmpty {
        let result = try await IPInfoManager.shared.fetchBatchIPInfo(ipList: publicIPs)
        for (ip, info) in result {
            locations[ip] = info.shortLocation
            cacheLocation(ip, location: info.shortLocation)  // 写入缓存
        }
    }
    
    return locations
}
```

### 8.3 多语言支持

**实现文件**: `Managers/LanguageManager.swift`

**支持语言**: 中文 / 英文

**切换方式**: 用户手动切换，保存到 `UserDefaults`

### 8.4 主机历史记录管理

**实现文件**: `Managers/HostHistoryManager.swift`

#### 8.4.1 功能概述

`HostHistoryManager` 是一个通用的主机/目标地址历史记录管理器，用于管理各探测工具输入框中的历史记录。采用单例模式，各探测页面共享同一个管理器实例。

**使用场景**:
- Ping 测试 - 主机地址历史
- DNS 查询 - 域名历史
- TCP 端口测试 - 主机地址历史
- UDP 测试 - 主机地址历史
- Traceroute - 主机地址历史
- HTTP GET - URL 历史
- 云探测 - 目标地址历史

#### 8.4.2 数据结构

```swift
class HostHistoryManager: ObservableObject {
    static let shared = HostHistoryManager()
    
    // 各探测类型的历史记录
    @Published var pingHistory: [String] = []
    @Published var dnsHistory: [String] = []
    @Published var tcpHistory: [String] = []
    @Published var udpHistory: [String] = []
    @Published var traceHistory: [String] = []
    @Published var httpHistory: [String] = []
    @Published var cloudProbeHistory: [String] = []
    
    // 最大历史记录数
    private let maxHistoryCount = 10
}
```

#### 8.4.3 存储 Key

| 探测类型 | UserDefaults Key |
|---------|-----------------|
| Ping | `PingHostHistory` |
| DNS | `DNSHostHistory` |
| TCP | `TCPHostHistory` |
| UDP | `UDPHostHistory` |
| Traceroute | `TraceHostHistory` |
| HTTP | `HTTPHostHistory` |
| 云探测 | `CloudProbeHostHistory` |

#### 8.4.4 核心方法

```swift
// 添加历史记录（自动去重、置顶、限制数量）
func addPingHistory(_ host: String)
func addDNSHistory(_ host: String)
func addTCPHistory(_ host: String)
func addUDPHistory(_ host: String)
func addTraceHistory(_ host: String)
func addHTTPHistory(_ url: String)
func addCloudProbeHistory(_ host: String)

// 删除单条历史记录
func removePingHistory(_ host: String)
func removeDNSHistory(_ host: String)
// ... 其他类型类似

// 清空历史记录
func clearPingHistory()
func clearDNSHistory()
// ... 其他类型类似
```

#### 8.4.5 公共 UI 组件

**1. HostInputField - 带历史记录的输入框**

```swift
struct HostInputField: View {
    @Binding var text: String
    let placeholder: String
    let history: [String]
    let onHistorySelect: (String) -> Void
    let onHistoryDelete: (String) -> Void
}
```

**功能特性**:
- 输入框 + 历史记录下拉按钮
- 快捷输入按钮（www., .com, .cn, .net, .org）
- 历史记录列表（点击选中、单条删除）
- 展开/收起动画

**使用示例**:
```swift
@StateObject private var historyManager = HostHistoryManager.shared

HostInputField(
    text: $hostInput,
    placeholder: "请输入主机地址",
    history: historyManager.pingHistory,
    onHistorySelect: { host in
        // 选中历史记录后的回调
    },
    onHistoryDelete: { host in
        historyManager.removePingHistory(host)
    }
)
```

**2. HostHistoryChips - 历史记录快捷选择器**

```swift
struct HostHistoryChips: View {
    let history: [String]
    @Binding var current: String
    let defaultHosts: [String]
}
```

**功能特性**:
- 横向滚动的历史记录芯片（最多显示 3 条）
- 默认主机快捷按钮
- 选中状态高亮

**使用示例**:
```swift
HostHistoryChips(
    history: historyManager.pingHistory,
    current: $hostInput,
    defaultHosts: ["baidu.com", "qq.com", "google.com"]
)
```

**3. HistoryHostChip - 单个历史记录芯片**

```swift
struct HistoryHostChip: View {
    let host: String
    @Binding var current: String
    let isHistory: Bool  // true 显示时钟图标
}
```

#### 8.4.6 历史记录 UI 样式

| 元素 | 样式 |
|------|------|
| 历史记录按钮 | `clock.arrow.circlepath` 图标 |
| 展开图标 | `chevron.up` |
| 删除按钮 | `xmark.circle.fill` 图标 |
| 时钟图标 | `clock` 图标（历史记录行前缀）|
| 列表背景 | `Color(.systemBackground)` |
| 边框 | `Color(.systemGray4)`, 0.5pt |
| 圆角 | 8pt |
| 动画 | `.easeInOut(duration: 0.2)` |

#### 8.4.7 与 IP 查询历史的区别

| 特性 | HostHistoryManager | IP 查询历史 |
|------|-------------------|------------|
| 实现位置 | 独立 Manager | IPQueryView 内部 |
| 存储 Key | 各类型独立 Key | `IPQueryHistory` |
| 共享方式 | 单例，多页面共享 | 仅 IPQueryView 使用 |
| UI 组件 | HostInputField 等 | 内联实现 |
| 快捷输入 | 支持（www., .com 等）| 不支持 |

> **注意**: IP 查询页面的历史记录目前是独立实现的，未复用 `HostHistoryManager`。两者功能相似，未来可考虑统一。

---

## 九、数据模型

**实现文件**: `Models/NetworkModels.swift`, `Models/CloudProbeModels.swift`

### 9.1 Ping 结果模型

```swift
struct PingResult: Identifiable {
    let id: String
    let sequence: Int
    let host: String
    let ip: String
    let latency: Double?  // 秒
    let status: PingStatus  // success / timeout / error
    let timestamp: Date
}

struct PingStatistics {
    var sent: Int
    var received: Int
    var lost: Int
    var minLatency: Double
    var maxLatency: Double
    var totalLatency: Double
    var latencies: [Double]
    
    var lossRate: Double { ... }
    var avgLatency: Double { ... }
    var stddevLatency: Double { ... }
}
```

### 9.2 DNS 结果模型

```swift
struct DNSResult: Identifiable {
    let id: String
    let domain: String
    let recordType: DNSRecordType
    let records: [DNSRecord]
    let latency: Double  // 秒
    let server: String?
    let error: String?
    let timestamp: Date
}

struct DNSRecord: Identifiable {
    let id: String
    let name: String?
    let type: UInt16
    let typeString: String
    let ttl: UInt32?
    let value: String
    let rawData: Data
    var location: String?  // IP 归属地
    var isPrimary: Bool    // 是否为优先记录
}
```

### 9.3 Traceroute 跳点模型

```swift
struct TraceHop: Identifiable {
    let id: String
    let hop: Int
    let ip: String
    let hostname: String?
    let latencies: [Double?]
    let status: HopStatus
    var location: String?
    
    var receivedCount: Int { ... }
    var sentCount: Int { ... }
    var lossRate: Double { ... }
    var avgLatency: Double? { ... }
}
```

### 9.4 TCP 连接结果模型

```swift
struct TCPResult: Identifiable {
    let id: String
    let host: String
    let port: UInt16
    let isOpen: Bool
    let latency: Double?  // 秒
    let error: String?
    let timestamp: Date
}
```

### 9.5 UDP 测试结果模型

```swift
struct UDPResult: Identifiable {
    let id: String
    let host: String
    let port: UInt16
    let sent: Bool
    let received: Bool
    let latency: Double?  // 秒
    let error: String?
    let timestamp: Date
}
```

### 9.6 DNS 记录类型枚举

```swift
enum DNSRecordType: String, CaseIterable {
    case systemDefault = "系统默认"  // 系统默认解析
    case A = "A"                     // IPv4 地址
    case AAAA = "AAAA"               // IPv6 地址
    case CNAME = "CNAME"             // 别名记录
    case MX = "MX"                   // 邮件交换记录
    case TXT = "TXT"                 // 文本记录
    case NS = "NS"                   // 域名服务器记录
}
```

### 9.7 云探测结果模型

```swift
// Ping 结果
struct CloudPingResult: Identifiable {
    let AgentAsId: Int
    let AgentCountry: String?
    let AgentISP: String?
    let AgentProvince: String?
    let AvgRttMilli: Double?
    let BuildinAgentRemoteIP: String?
    let BuildinErrMessage: String?
    let BuildinLocalTime: String?
    let BuildinPeerIP: String?
    let BuildinTargetHost: String?
    let MaxRttMilli: Double?
    let MinRttMilli: Double?
    let PacketLoss: Double?
}

// DNS 结果
struct CloudDNSResult: Identifiable {
    let AgentAsId: Int
    let AgentCountry: String?
    let AgentISP: String?
    let AgentProvince: String?
    let Answers: [DNSAnswer]?
    let AtNameServer: String?
    let BuildinAgentRemoteIP: String?
    let BuildinErrMessage: String?
    let BuildinPeerIP: String?
    let BuildinTargetHost: String?
    let RttMilli: Double?
    
    struct DNSAnswer {
        let Class: String?
        let Name: String?
        let ParseIP: String?
        let RRType: String?
    }
}

// 探针位置
struct ProbeLocation: Hashable {
    let Area: String?       // 大洲
    let AsId: Int           // AS 号
    let City: String?       // 城市
    let Country: String?    // 国家
    let ISP: String?        // 运营商
    let Province: String?   // 省份
}

// 探测类型
enum CloudProbeType: String, CaseIterable {
    case ping = "Ping"
    case dns = "DNS"
    case tcp = "TCP"
    case udp = "UDP"
    
    var msmType: String {
        switch self {
        case .ping: return "ping"
        case .dns: return "dns"
        case .tcp: return "tcp_port"
        case .udp: return "udp_port"
        }
    }
}
```

### 9.8 告警数据模型

```swift
struct AlarmItem: Identifiable {
    let AlarmTime: String?      // 告警时间
    let RecoverTime: String?    // 恢复时间
    let AlarmType: String?      // 告警类型
    let CIName: String?         // CI 名称
    let DataType: String?       // 数据类型
    let DstIsp: String?         // 目标运营商
    let DstStr: String?         // 目标省份（逗号分隔）
    let Level: String?          // 级别: level1/level2/level3
    let Network: String?        // 网络类型
    let SrcIsp: String?         // 源运营商
    let SrcStr: String?         // 源城市
    let Title: String?          // 告警标题
    
    var alertLevel: AlertLevel { ... }
    var isRecovered: Bool { ... }
    var sourceProvince: String { ... }
    var destinationProvinces: [String] { ... }
}

enum AlertLevel: String {
    case normal = "normal"      // level3 - 轻微
    case warning = "warning"    // level2 - 中等
    case critical = "critical"  // level1 - 严重
}

struct AlertLine: Identifiable {
    let id: String
    let fromProvince: String    // 源省份
    let toProvince: String      // 目标省份
    let alertLevel: AlertLevel  // 告警级别
    let count: Int              // 告警数量
}
```

---

## 十、鉴权配置

**实现文件**: `Services/NetworkService.swift`

### 10.1 鉴权配置结构

```swift
struct AuthConfig {
    let systemId: String      // 系统 ID
    let secretKey: String     // 签名密钥（十六进制字符串）
    let useHmacSha512: Bool   // true 使用 HMAC-SHA-512，false 使用 HMAC-SHA-256
}
```

### 10.2 签名算法

**支持的算法**:
| 算法 | 说明 | 摘要长度 |
|------|------|----------|
| HMAC-SHA-512 | 默认算法，安全性更高 | 64 字节 (128 位十六进制) |
| HMAC-SHA-256 | 备用算法 | 32 字节 (64 位十六进制) |

### 10.3 签名生成流程

```
┌─────────────────────────────────────────────────────────────┐
│                      签名生成流程                            │
├─────────────────────────────────────────────────────────────┤
│  1. 获取当前时间戳 (Unix 秒级)                               │
│     timestamp = Int(Date().timeIntervalSince1970)           │
│                                                             │
│  2. 拼接待签名字符串                                         │
│     strToSign = timestamp + requestBody                     │
│     例: "1703304000{\"Action\":\"Query\",...}"              │
│                                                             │
│  3. 将十六进制密钥转换为 Data                                │
│     keyData = Data(hexString: secretKey)                    │
│                                                             │
│  4. 计算 HMAC 签名                                          │
│     signature = HMAC-SHA-512(keyData, strToSign)            │
│     输出为小写十六进制字符串                                  │
│                                                             │
│  5. 组装 Authorization 头                                   │
│     "HMAC-SHA-512 Timestamp=xxx,Signature=xxx,SystemId=xxx" │
└─────────────────────────────────────────────────────────────┘
```

### 10.4 签名实现代码

```swift
private func makeAuthorization(
    systemId: String,
    secretKey: String,
    requestBodyData: String,
    isHmacSha512: Bool = true
) -> String {
    // 1. 获取当前时间戳
    let timestamp = Int(Date().timeIntervalSince1970)
    
    // 2. 拼接待签名字符串: 时间戳 + 请求体
    let strToSign = "\(timestamp)\(requestBodyData)"
    
    // 3. 将十六进制密钥转换为 Data
    let keyData = Data(hexString: secretKey) ?? Data()
    
    // 4. 计算 HMAC 签名
    let signature: String
    let algoName: String
    
    if isHmacSha512 {
        algoName = "HMAC-SHA-512"
        signature = hmacSHA512(key: keyData, data: strToSign)
    } else {
        algoName = "HMAC-SHA-256"
        signature = hmacSHA256(key: keyData, data: strToSign)
    }
    
    // 5. 组装 Authorization 头
    return "\(algoName) Timestamp=\(timestamp),Signature=\(signature),SystemId=\(systemId)"
}
```

### 10.5 HMAC 计算实现

```swift
// HMAC-SHA-512
private func hmacSHA512(key: Data, data: String) -> String {
    let dataBytes = data.data(using: .utf8)!
    var digest = [UInt8](repeating: 0, count: Int(CC_SHA512_DIGEST_LENGTH))
    
    key.withUnsafeBytes { keyPtr in
        dataBytes.withUnsafeBytes { dataPtr in
            CCHmac(
                CCHmacAlgorithm(kCCHmacAlgSHA512),
                keyPtr.baseAddress,
                key.count,
                dataPtr.baseAddress,
                dataBytes.count,
                &digest
            )
        }
    }
    
    // 转换为小写十六进制字符串
    return digest.map { String(format: "%02x", $0) }.joined()
}
```

### 10.6 十六进制密钥转换

```swift
extension Data {
    /// 从十六进制字符串初始化 Data
    init?(hexString: String) {
        let len = hexString.count / 2
        var data = Data(capacity: len)
        var index = hexString.startIndex
        
        for _ in 0..<len {
            let nextIndex = hexString.index(index, offsetBy: 2)
            guard let byte = UInt8(hexString[index..<nextIndex], radix: 16) else {
                return nil
            }
            data.append(byte)
            index = nextIndex
        }
        
        self = data
    }
}
```

### 10.7 Authorization 头格式

**格式**:
```
{算法名称} Timestamp={时间戳},Signature={签名},SystemId={系统ID}
```

**示例**:
```
HMAC-SHA-512 Timestamp=1703304000,Signature=a1b2c3d4e5f6...（128位十六进制）,SystemId=4
```

### 10.8 请求示例

```swift
// 发起带鉴权的请求
let response = try await NetworkService.shared.post(
    url: "https://api.itango.tencent.com/api",
    json: requestBody,
    auth: APIConfig.defaultAuth  // 传入鉴权配置
)
```

### 10.9 API 鉴权分类

**需要鉴权的 API**:
| API | 说明 |
|-----|------|
| 获取 Tab 配置 | `App.GetAppConfig` |
| 获取探针列表 | `Query.GetAgentGeo` |
| 创建探测任务 | `MsmCustomTask.Create` |
| 查询任务结果 | `MsmTaskResult.RealTimeTaskResult` |
| 获取诊断任务 | `MsmExample.GetMsmExample` |
| 上传诊断结果 | `MsmReceive.BatchRun` |
| 批量 IP 归属地查询 | `HuaTuo.GetBatchIPInfo` |
| 告警数据查询 | `QueryData.run` |
| 检查版本更新 | `App.GetLatestVersion` |

**不需要鉴权的 API**:
| API | 说明 |
|-----|------|
| 用户登录 | 登录相关接口 |
| 图形验证码 | 获取验证码图片 |
| 短信验证码 | 发送短信验证码 |
