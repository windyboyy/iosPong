# iTango Pong - iOS 网络诊断工具 完整设计文档

## 一、项目概述

**项目名称**: Pong (iTango 网络探测)  
**平台**: iOS (SwiftUI)  
**架构**: MVVM + 单例管理器模式  
**语言支持**: 中文/英文双语

这是一个专业的网络诊断工具应用，提供本地网络测试、云端探测、一键诊断等功能，类似于网络工程师常用的诊断工具集合。

---

## 二、页面列表与导航结构

### 2.1 主导航 (TabBar - 4个Tab)

| Tab | 图标 | 中文名 | 英文名 | 对应页面 |
|-----|------|--------|--------|----------|
| 1 | `iphone.gen1` | 本地测 | Local | HomeView |
| 2 | `cloud` | 云探测 | Cloud | CloudProbeView |
| 3 | `apple.intelligence` | 数据 | Data | ChinaMapView |
| 4 | `person` | 我的 | Profile | ProfileView |

### 2.2 完整页面清单

| 页面 | 功能描述 | 入口 |
|------|----------|------|
| **HomeView** | 首页，展示工具入口网格和一键诊断入口 | Tab 1 |
| **CloudProbeView** | 云探测，从全球云节点发起探测 | Tab 2 |
| **ChinaMapView** | 中国地图告警可视化 (WebView) | Tab 3 |
| **ProfileView** | 个人中心，用户信息和功能入口 | Tab 4 |
| **PingView** | Ping 测试 | 首页工具卡片 |
| **DNSView** | DNS 查询 | 首页工具卡片 |
| **TCPView** | TCP 端口测试 | 首页工具卡片 |
| **UDPView** | UDP 测试 | 首页工具卡片 |
| **TraceView** | Traceroute 路由追踪 | 首页工具卡片 |
| **HTTPGetView** | HTTP GET 请求测试 | 首页工具卡片 |
| **SpeedTestView** | 网速测试 | 首页工具卡片 |
| **DeviceInfoView** | 设备信息展示 | 首页工具卡片 |
| **PacketCaptureView** | 抓包 (开发中) | 首页工具卡片 |
| **QuickDiagnosisView** | 一键诊断 | 首页顶部入口 |
| **TaskHistoryView** | 历史任务记录 | 我的页面 |
| **LoginView** | 登录页面 | 我的页面/云探测 |
| **SettingsView** | 设置页面 | 我的页面 |
| **HelpView** | 帮助中心 | 我的页面 |
| **FeedbackView** | 意见反馈 | 我的页面 |

---

## 三、功能列表

### 3.1 本地网络测试工具 (9个)

| 工具 | 图标 | 颜色 | 功能描述 | 状态 |
|------|------|------|----------|------|
| **测速** | `speedometer` | 红色 | 测试上传/下载速度、延迟、抖动 | ✅ |
| **Ping** | `network` | 蓝色 | 测试网络延迟和连通性 | ✅ |
| **Traceroute** | `point.topleft.down.curvedto.point.bottomright.up` | 紫色 | 追踪数据包路由路径 | ✅ |
| **TCP** | `arrow.left.arrow.right` | 橙色 | TCP 端口扫描与连接测试 | ✅ |
| **UDP** | `paperplane` | 绿色 | UDP 数据包发送测试 | ✅ |
| **DNS** | `server.rack` | 青色 | DNS 域名解析查询 | ✅ |
| **HTTP** | `globe` | 蓝绿色 | HTTP GET 请求测试 | ✅ |
| **本机信息** | `iphone.gen3` | 靛蓝色 | 查看设备与 IP 归属地 | ✅ |
| **抓包** | `antenna.radiowaves.left.and.right` | 粉色 | 网络数据包捕获 | 🚧 开发中 |

### 3.2 云探测功能

- **探测类型**: Ping / DNS / TCP / UDP
- **筛选条件**: 国家 / 运营商 / AS号
- **目标输入**: 支持域名和 IP (IPv4/IPv6)
- **结果展示**: 卡片式结果列表，显示延迟、丢包率、解析结果等

### 3.3 一键诊断功能

- 输入6位诊断码
- 自动获取诊断任务列表
- 批量执行诊断任务 (Ping/TCP/UDP/DNS/Traceroute)
- 结果关联到华佗平台 Report

### 3.4 用户系统

- **游客登录**: 一键登录，自动分配用户ID
- **手机号登录**: 验证码登录，支持社区版/定制版
- **账号密码登录**: 图形验证码，支持社区版/定制版

### 3.5 历史记录

- 保存所有本地测试任务记录
- 支持上传到服务器
- 14天自动过期清理
- 按任务类型筛选

---

## 四、UI 设计方案

### 4.1 设计风格

- **整体风格**: 现代简洁的 iOS 原生风格
- **配色方案**: 以蓝色为主色调，各工具有独立主题色
- **背景色**: 浅灰色分组背景 (`systemGroupedBackground`)
- **卡片背景**: 白色 (`systemBackground`)
- **圆角**: 卡片 12-16px，按钮 8-12px

### 4.2 首页布局

```
┌─────────────────────────────────────┐
│  [Logo]                    [EN/中]  │  顶部栏
├─────────────────────────────────────┤
│  ┌─────────────────────────────┐    │
│  │    ✨ 一键诊断              │    │  渐变卡片入口
│  │    输入诊断码，快速定位问题   │    │  (蓝紫渐变)
│  └─────────────────────────────┘    │
├─────────────────────────────────────┤
│  ┌─────┐ ┌─────┐ ┌─────┐          │
│  │测速 │ │Ping │ │Trace│          │  工具网格
│  └─────┘ └─────┘ └─────┘          │  (2-4列可配置)
│  ┌─────┐ ┌─────┐ ┌─────┐          │
│  │ TCP │ │ UDP │ │ DNS │          │
│  └─────┘ └─────┘ └─────┘          │
│  ┌─────┐ ┌─────┐ ┌─────┐          │
│  │HTTP │ │抓包 │ │本机 │          │
│  └─────┘ └─────┘ └─────┘          │
├─────────────────────────────────────┤
│  快速诊断                           │
│  ┌─────────────────────────────┐    │
│  │ 🌐 华佗诊断平台        >    │    │  快速操作入口
│  └─────────────────────────────┘    │
└─────────────────────────────────────┘
```

### 4.3 工具卡片设计

```
┌─────────────────┐
│      ⚪         │  圆形图标背景 (主题色 15% 透明度)
│      🔵         │  SF Symbol 图标
│                 │
│     Ping        │  工具名称 (粗体)
│  测试网络延迟    │  功能描述 (灰色小字)
└─────────────────┘
```

### 4.4 测试结果界面 (终端风格)

```
┌─────────────────────────────────────┐
│ $ ping www.qq.com          ⏳ [复制]│  命令行头部 (黑色背景)
├─────────────────────────────────────┤
│ [1] 14.18.175.154: 12.3 ms         │  结果列表
│ [2] 14.18.175.154: 11.8 ms         │  (等宽字体)
│ [3] 14.18.175.154: 13.1 ms         │
│ ...                                 │
├─────────────────────────────────────┤
│ --- www.qq.com ping statistics --- │  统计摘要
│ 10 packets, 10 received, 0% loss   │
│ min/avg/max = 11.2/12.5/14.1 ms    │
└─────────────────────────────────────┘
```

### 4.5 统计卡片设计

```
┌───────┬───────┬───────┬───────┐
│ 发送  │ 接收  │ 丢失  │ 平均  │
│  10   │  10   │  0%   │12.5ms │
│ 蓝色  │ 绿色  │ 灰色  │ 橙色  │
└───────┴───────┴───────┴───────┘
```

### 4.6 颜色定义

```kotlin
// 主题色
val Blue = Color(0xFF007AFF)
val GradientBlue = Color(0xFF3366E6)
val GradientPurple = Color(0xFF9933E6)

// 工具颜色
val SpeedTestRed = Color(0xFFFF3B30)
val PingBlue = Color(0xFF007AFF)
val TracePurple = Color(0xFFAF52DE)
val TCPOrange = Color(0xFFFF9500)
val UDPGreen = Color(0xFF34C759)
val DNSCyan = Color(0xFF32ADE6)
val HTTPTeal = Color(0xFF5AC8FA)
val CaptureRink = Color(0xFFFF2D55)
val DeviceIndigo = Color(0xFF5856D6)

// 状态颜色
val Success = Color(0xFF34C759)
val Warning = Color(0xFFFF9500)
val Error = Color(0xFFFF3B30)
```

---

## 4.7 各功能页面字体大小与颜色规范

### 4.7.1 Ping 页面 (PingView)

#### 页面布局

```
┌─────────────────────────────────────────┐
│  [输入框: 主机名/IP]  [历史] [▶️ 运行]   │  输入区域
├─────────────────────────────────────────┤
│  [www.] [.com] [.cn] [.net]             │  快捷输入按钮
├─────────────────────────────────────────┤
│  发包大小: [56▼]    间隔: [0.2s▼]       │  设置选项
├─────────────────────────────────────────┤
│  ┌─────┬─────┬─────┬─────┐              │
│  │ 发送 │ 接收 │ 丢失 │ 平均 │              │  统计卡片
│  │  10  │  10  │  0%  │12ms │              │
│  └─────┴─────┴─────┴─────┘              │
├─────────────────────────────────────────┤
│  $ ping www.qq.com              ⏳ [📋] │  终端头部
│  ┌─────────────────────────────────────┐│
│  │ [1] 14.18.175.154: 12.3 ms         ││  结果列表
│  │ [2] 14.18.175.154: 11.8 ms         ││  (黑色背景)
│  │ [3] 14.18.175.154: 13.1 ms         ││
│  │ ...                                 ││
│  │ --- ping statistics ---             ││  统计摘要
│  │ 10 packets, 10 received, 0% loss   ││
│  └─────────────────────────────────────┘│
├─────────────────────────────────────────┤
│ [🕐 qq.com] [🕐 baidu] | [8.8.8.8] ... │  快捷主机
└─────────────────────────────────────────┘
```

#### 样式规范

| 元素 | 字体大小 | 颜色 |
|------|----------|------|
| 快捷输入按钮 | 13pt (monospaced, medium) | `.blue` (`#007AFF`) |
| 快捷输入背景 | - | `.blue.opacity(0.1)` (`#007AFF` 10%) |
| 设置标签 (发包大小/间隔) | caption (~12pt) | `.secondary` (`#8E8E93`) |
| 终端命令行 | caption (~12pt, monospaced) | `.green` (`#34C759`) |
| 终端背景 | - | `.black.opacity(0.9)` (`#000000` 90%) |
| 结果行 | 12pt (monospaced) | 序号: `.gray` (`#8E8E93`), IP: `.cyan` (`#32ADE6`), 状态: `.green/.orange/.red` (`#34C759/#FF9500/#FF3B30`) |
| 统计数值 | headline (~17pt, monospaced, bold) | 发送: `.blue` (`#007AFF`), 接收: `.green` (`#34C759`), 丢失: `.red/.gray` (`#FF3B30/#8E8E93`), 平均: `.orange` (`#FF9500`) |
| 统计标签 | caption2 (~11pt) | `.secondary` (`#8E8E93`) |
| 统计卡片背景 | - | `Color(.systemGray6)` (`#F2F2F7`) |
| 快捷主机标签 | caption (~12pt) | 选中: `.white` (`#FFFFFF`), 未选中: `.primary` (`#000000`) |
| 快捷主机背景 | - | 选中: `.blue` (`#007AFF`), 未选中: `Color(.systemGray5)` (`#E5E5EA`) |
| 历史记录项 | subheadline (~15pt) | `.primary` (`#000000`) |
| 历史记录图标 | caption (~12pt) | `.secondary` (`#8E8E93`) |
| 操作按钮背景 | - | 运行中: `.red` (`#FF3B30`), 停止: `.blue` (`#007AFF`) |

### 4.7.2 DNS 页面 (DNSView)

#### 页面布局

```
┌─────────────────────────────────────────┐
│  [输入框: 域名]              [历史]      │  输入区域
├─────────────────────────────────────────┤
│  [www.] [.com] [.cn] [.net]             │  快捷输入按钮
├─────────────────────────────────────────┤
│  [ A ][ AAAA ][ CNAME ][ MX ][ TXT ][ NS ] [🔍]│  记录类型选择
├─────────────────────────────────────────┤
│  $ dig www.qq.com A            [清空]   │  终端头部
│  ┌─────────────────────────────────────┐│
│  │ ┌──────────────────────────────────┐││
│  │ │ [A] www.qq.com        14:32:05   │││  结果卡片
│  │ │ ;; ANSWER SECTION:               │││
│  │ │ www.qq.com. 300 IN A 14.18.175.154│││
│  │ │ ;; Query time: 23 msec           │││
│  │ │ ;; SERVER: 119.29.29.29          │││
│  │ │ [dig输出] [复制]                  │││
│  │ └──────────────────────────────────┘││
│  └─────────────────────────────────────┘│
├─────────────────────────────────────────┤
│ [🕐 qq.com] | [baidu.com] [google.com] │  快捷域名
└─────────────────────────────────────────┘
```

#### 样式规范

| 元素 | 字体大小 | 颜色 |
|------|----------|------|
| 快捷输入按钮 | 13pt (monospaced, medium) | `.cyan` (`#32ADE6`) |
| 快捷输入背景 | - | `.cyan.opacity(0.1)` (`#32ADE6` 10%) |
| 终端命令行 | caption (~12pt, monospaced) | `.green` (`#34C759`) |
| 清空按钮 | caption (~12pt) | `.red` (`#FF3B30`) |
| 记录类型标签 | caption (~12pt, bold) | `.black` (`#000000`) (背景 `.cyan` (`#32ADE6`)) |
| 域名显示 | 默认 | `.white` (`#FFFFFF`) |
| 时间戳 | 默认 | `.gray` (`#8E8E93`) |
| ANSWER SECTION 标题 | 10pt (monospaced) | `.gray` (`#8E8E93`) |
| DNS 记录行 | 11pt (monospaced) | `.green` (`#34C759`) |
| 查询统计 | 10pt (monospaced) | `.gray` (`#8E8E93`) |
| 错误信息 | 默认 | `.orange` (`#FF9500`) |
| 操作按钮 (dig输出/复制) | 10pt | `.cyan` (`#32ADE6`) |
| 结果卡片背景 | - | `.white.opacity(0.05)` (`#FFFFFF` 5%) |
| 空状态提示 | 12pt (monospaced) | `.gray` (`#8E8E93`) |
| 快捷域名标签 | caption (~12pt) | 选中: `.white` (`#FFFFFF`), 未选中: `.primary` (`#000000`) |
| 快捷域名背景 | - | 选中: `.cyan` (`#32ADE6`), 未选中: `Color(.systemGray5)` (`#E5E5EA`) |
| 操作按钮背景 | - | 运行中: `.red` (`#FF3B30`), 停止: `.cyan` (`#32ADE6`) |

### 4.7.3 TCP 页面 (TCPView)

#### 页面布局

```
┌─────────────────────────────────────────┐
│  [输入框: 主机名/IP]  [历史]  [端口: 443]│  输入区域
├─────────────────────────────────────────┤
│  [www.] [.com] [.cn] [.net]             │  快捷输入按钮
├─────────────────────────────────────────┤
│  [🔘 扫描常用端口]           [▶️ 测试]   │  扫描开关和按钮
├─────────────────────────────────────────┤
│  ████████████████░░░░  75%              │  进度条 (扫描模式)
├─────────────────────────────────────────┤
│  $ nc -zv www.qq.com     3/10 开放 [📋]│  终端头部
│  ┌─────────────────────────────────────┐│
│  │ ✅ 443  HTTPS   开放   23ms         ││  结果列表
│  │ ✅ 80   HTTP    开放   25ms         ││
│  │ ❌ 22   SSH     关闭                ││
│  │ ❌ 21   FTP     关闭                ││
│  └─────────────────────────────────────┘│
├─────────────────────────────────────────┤
│ [80/HTTP] [443/HTTPS] [22/SSH] [3306]..│  常用端口快捷按钮
└─────────────────────────────────────────┘
```

#### 样式规范

| 元素 | 字体大小 | 颜色 |
|------|----------|------|
| 快捷输入按钮 | 13pt (monospaced, medium) | `.orange` (`#FF9500`) |
| 快捷输入背景 | - | `.orange.opacity(0.1)` (`#FF9500` 10%) |
| 扫描开关标签 | subheadline (~15pt) | 默认 |
| 终端命令行 | caption (~12pt, monospaced) | `.green` (`#34C759`) |
| 统计文字 | caption (~12pt) | `.secondary` (`#8E8E93`) |
| 进度百分比 | caption (~12pt) | `.secondary` (`#8E8E93`) |
| 结果行 | 12pt (monospaced) | 端口: `.cyan` (`#32ADE6`), 服务名: `.gray` (`#8E8E93`), 开放: `.green` (`#34C759`), 关闭: `.red` (`#FF3B30`), 延迟: `.yellow` (`#FFCC00`) |
| 状态图标 | - | 开放: `.green` (`#34C759`), 关闭: `.red` (`#FF3B30`) |
| 端口按钮-端口号 | caption (~12pt, medium) | 选中: `.white` (`#FFFFFF`), 未选中: `.primary` (`#000000`) |
| 端口按钮-服务名 | caption2 (~11pt) | 同上 |
| 端口按钮背景 | - | 选中: `.orange` (`#FF9500`), 未选中: `Color(.systemGray5)` (`#E5E5EA`) |
| 操作按钮背景 | - | 运行中: `.red` (`#FF3B30`), 停止: `.orange` (`#FF9500`) |

### 4.7.4 UDP 页面 (UDPView)

#### 页面布局

```
┌─────────────────────────────────────────┐
│  [输入框: 主机名/IP]  [历史]  [端口: 53] │  输入区域
│                              [✈️ 发送]  │
├─────────────────────────────────────────┤
│  [www.] [.com] [.cn] [.net]             │  快捷输入按钮
├─────────────────────────────────────────┤
│  ℹ️ UDP 是无连接协议，发送成功不代表对方收到 │  说明提示
├─────────────────────────────────────────┤
│  $ nc -u 8.8.8.8 53                [📋]│  终端头部
│  ┌─────────────────────────────────────┐│
│  │ ↑发送 ✓  ↓响应 ✓        14:32:05   ││  结果行
│  │ 8.8.8.8:53                          ││
│  │ 延迟: 23.5ms                        ││
│  │ ─────────────────────────────────── ││
│  │ ↑发送 ✓  ↓响应 ✗        14:32:10   ││
│  │ 8.8.8.8:53                          ││
│  │ 无响应                              ││
│  └─────────────────────────────────────┘│
├─────────────────────────────────────────┤
│ [53/DNS] [123/NTP] [161/SNMP] [67/DHCP]│  常用端口快捷按钮
└─────────────────────────────────────────┘
```

#### 样式规范

| 元素 | 字体大小 | 颜色 |
|------|----------|------|
| 快捷输入按钮 | 13pt (monospaced, medium) | `.green` (`#34C759`) |
| 快捷输入背景 | - | `.green.opacity(0.1)` (`#34C759` 10%) |
| 说明文字 | caption (~12pt) | `.secondary` (`#8E8E93`) |
| 说明图标 | - | `.blue` (`#007AFF`) |
| 终端命令行 | caption (~12pt, monospaced) | `.green` (`#34C759`) |
| 结果行 | 12pt (monospaced) | 发送成功: `.green` (`#34C759`), 发送失败: `.red` (`#FF3B30`), 响应成功: `.green` (`#34C759`), 无响应: `.orange` (`#FF9500`), 目标: `.cyan` (`#32ADE6`), 延迟: `.yellow` (`#FFCC00`), 错误: `.orange` (`#FF9500`), 时间: `.gray` (`#8E8E93`) |
| 空状态提示 | 12pt (monospaced) | `.gray` (`#8E8E93`) |
| 端口按钮 | caption/caption2 | 选中: `.white` (`#FFFFFF`), 未选中: `.primary` (`#000000`) |
| 端口按钮背景 | - | 选中: `.green` (`#34C759`), 未选中: `Color(.systemGray5)` (`#E5E5EA`) |
| 操作按钮背景 | - | 运行中: `.red` (`#FF3B30`), 停止: `.green` (`#34C759`) |

### 4.7.5 Traceroute 页面 (TraceView)

#### 页面布局

```
┌─────────────────────────────────────────┐
│  [输入框: 主机名/IP]      [历史] [▶️]   │  输入区域
├─────────────────────────────────────────┤
│  [www.] [.com] [.cn] [.net]             │  快捷输入按钮
├─────────────────────────────────────────┤
│  每跳探测次数: [ 3 ][ 5 ][ 10 ][ 20 ]   │  探测次数选择
├─────────────────────────────────────────┤
│  目标 IP: 14.18.175.154                 │  状态信息
│  ⏳ 正在追踪路由...                      │
├─────────────────────────────────────────┤
│  $ traceroute www.qq.com           [📋]│  终端头部
│  ┌─────────────────────────────────────┐│
│  │  #   IP              延迟   丢包  归属地 ││  表头
│  │─────────────────────────────────────││
│  │  1  192.168.1.1     2.3ms   0%  局域网 ││  跳点列表
│  │  2  10.0.0.1        5.1ms   0%  广东电信││
│  │  3  *               *       100%  -    ││
│  │  4  14.18.175.154   12.5ms  0%  深圳  ││
│  └─────────────────────────────────────┘│
├─────────────────────────────────────────┤
│ [🕐 qq.com] | [baidu.com] [google.com] │  快捷主机
└─────────────────────────────────────────┘
```

#### 样式规范

| 元素 | 字体大小 | 颜色 |
|------|----------|------|
| 快捷输入按钮 | 13pt (monospaced, medium) | `.purple` (`#AF52DE`) |
| 快捷输入背景 | - | `.purple.opacity(0.1)` (`#AF52DE` 10%) |
| 探测次数标签 | caption (~12pt) | `.secondary` (`#8E8E93`) |
| 目标 IP 标签 | caption (~12pt) | `.secondary` (`#8E8E93`) |
| 目标 IP 值 | caption (~12pt, medium) | `.blue` (`#007AFF`) |
| 状态文字 | subheadline (~15pt) | `.secondary` (`#8E8E93`) |
| 完成图标 | - | `.green` (`#34C759`) |
| 错误信息 | caption (~12pt) | `.red` (`#FF3B30`) |
| 终端命令行 | caption (~12pt, monospaced) | `.green` (`#34C759`) |
| 表头 | 10pt (monospaced) | `.gray.opacity(0.7)` (`#8E8E93` 70%) |
| 表头背景 | - | `.black.opacity(0.8)` (`#000000` 80%) |
| 跳点行 | 11pt (monospaced) | 跳数: `.gray` (`#8E8E93`), IP: `.cyan` (`#32ADE6`) (超时: `.orange` (`#FF9500`)), 延迟: `.green/.orange/.red` (`#34C759/#FF9500/#FF3B30`), 丢包率: `.green/.yellow/.red` (`#34C759/#FFCC00/#FF3B30`), 归属地: `.white.opacity(0.8)` (`#FFFFFF` 80%) |
| 操作按钮背景 | - | 运行中: `.red` (`#FF3B30`), 停止: `.purple` (`#AF52DE`) |

### 4.7.6 HTTP GET 页面 (HTTPGetView)

#### 页面布局

```
┌─────────────────────────────────────────┐
│  [输入框: URL]                   [历史] │  输入区域
├─────────────────────────────────────────┤
│  [https://] [http://] [.com] [.cn]      │  快捷输入按钮
├─────────────────────────────────────────┤
│  超时: [ 10s ][ 30s ][ 60s ]   [✈️ 发送]│  超时设置和按钮
├─────────────────────────────────────────┤
│  $ curl -X GET https://www.qq... [📋]  │  终端头部
│  ┌─────────────────────────────────────┐│
│  │ ✅ HTTP 200 OK              156ms   ││  状态行
│  │                                      ││
│  │ ▶ Headers (12)                       ││  Headers 折叠
│  │   Content-Type: text/html            ││
│  │   Server: nginx                      ││
│  │                                      ││
│  │ ▼ Body (15.2 KB)                     ││  Body 折叠
│  │   <!DOCTYPE html>                    ││
│  │   <html>...                          ││
│  └─────────────────────────────────────┘│
├─────────────────────────────────────────┤
│ [QQ] [Baidu] [Google] [GitHub] [httpbin]│  常用 URL 快捷按钮
└─────────────────────────────────────────┘
```

#### 样式规范

| 元素 | 字体大小 | 颜色 |
|------|----------|------|
| 快捷输入按钮 | 13pt (monospaced, medium) | `.teal` (`#5AC8FA`) |
| 快捷输入背景 | - | `.teal.opacity(0.1)` (`#5AC8FA` 10%) |
| 超时标签 | subheadline (~15pt) | `.secondary` (`#8E8E93`) |
| 终端命令行 | caption (~12pt, monospaced) | `.green` (`#34C759`) |
| 状态码 | 14pt (monospaced, bold) | 成功: `.green` (`#34C759`), 失败: `.red` (`#FF3B30`) |
| 状态消息 | 14pt (monospaced) | `.gray` (`#8E8E93`) |
| 响应时间 | 14pt (monospaced) | `.yellow` (`#FFCC00`) |
| 错误信息 | 12pt (monospaced) | `.red` (`#FF3B30`) |
| Headers 标题 | 12pt (monospaced) | `.orange` (`#FF9500`) |
| Header Key | 11pt (monospaced) | `.cyan` (`#32ADE6`) |
| Header Value | 11pt (monospaced) | `.white` (`#FFFFFF`) |
| Body 标题 | 12pt (monospaced) | `.orange` (`#FF9500`) |
| Body 内容 | 11pt (monospaced) | `.white` (`#FFFFFF`) |
| 空状态提示 | 12pt (monospaced) | `.gray` (`#8E8E93`) |
| URL 按钮 | caption (~12pt, medium) | 选中: `.white` (`#FFFFFF`), 未选中: `.primary` (`#000000`) |
| URL 按钮背景 | - | 选中: `.teal` (`#5AC8FA`), 未选中: `Color(.systemGray5)` (`#E5E5EA`) |
| 操作按钮背景 | - | 运行中: `.red` (`#FF3B30`), 停止: `.teal` (`#5AC8FA`) |
| 历史记录项 | subheadline (~15pt) | `.primary` (`#000000`) |
| 历史记录图标 | caption (~12pt) | `.secondary` (`#8E8E93`) |

#### 4.7.6.1 常用 URL 列表

| 名称 | URL |
|------|-----|
| QQ | `https://www.qq.com` |
| Baidu | `https://www.baidu.com` |
| Google | `https://www.google.com` |
| GitHub | `https://api.github.com` |
| httpbin | `https://httpbin.org/get` |

#### 4.7.6.2 功能特性

- **自动补全协议**: 输入 URL 时如未指定协议，自动添加 `https://`
- **超时设置**: 支持 10s / 30s / 60s 三档超时选择
- **响应展示**:
  - 状态行：显示 HTTP 状态码、状态消息、响应时间
  - Headers 折叠区域：可展开查看所有响应头
  - Body 折叠区域：可展开查看响应体（超过 10KB 自动截断）
- **历史记录**: 保存最近 10 条请求 URL
- **一键复制**: 复制完整响应信息（状态、Headers、Body）

### 4.7.7 测速页面 (SpeedTestView)

#### 页面布局

```
┌─────────────────────────────────────────┐
│           ┌─────────────┐               │
│           │             │               │  速度仪表盘
│           │    56.8     │               │  (圆环进度)
│           │    Mbps     │               │
│           └─────────────┘               │
├─────────────────────────────────────────┤
│     ↓ 下载           ↑ 上传             │
│     56.8 Mbps        23.4 Mbps          │  下载/上传速度
│     7.1 MB/s         2.9 MB/s           │
├─────────────────────────────────────────┤
│  🕐 延迟: 23 ms      📊 抖动: 2.1 ms    │  延迟和抖动
├─────────────────────────────────────────┤
│  ████████████████░░░░  75%              │  进度条
│  测试下载...                             │  阶段文字
├─────────────────────────────────────────┤
│  ┌─────────────────────────────────────┐│
│  │      [▶️ 开始测速]                   ││  测试按钮
│  └─────────────────────────────────────┘│
├─────────────────────────────────────────┤
│  腾讯系                        🟢 极佳  │  应用延迟分组
│  ┌─────────┬─────────┐                  │
│  │📰 腾讯新闻│📺 腾讯视频│                  │  应用卡片网格
│  │   23ms   │   45ms   │                  │  (2列布局)
│  ├─────────┼─────────┤                  │
│  │💬 微信   │💳 微信支付│                  │
│  │   18ms   │   22ms   │                  │
│  └─────────┴─────────┘                  │
├─────────────────────────────────────────┤
│  其他应用                      🟢 极佳  │
│  ┌─────────┬─────────┐                  │
│  │🔍 百度   │🛒 阿里   │                  │
│  │   35ms   │   42ms   │                  │
│  └─────────┴─────────┘                  │
├─────────────────────────────────────────┤
│  使用 Cloudflare 测速服务               │  说明文字
└─────────────────────────────────────────┘
```

#### 样式规范

| 元素 | 字体大小 | 颜色 |
|------|----------|------|
| 速度数字 | 48pt (rounded, bold) | `.primary` (`#000000`) |
| 速度单位 (Mbps) | caption (~12pt) | `.secondary` (`#8E8E93`) |
| 下载/上传标签 | caption (~12pt) | `.secondary` (`#8E8E93`) |
| 下载/上传图标 | - | 下载: `.blue` (`#007AFF`), 上传: `.green` (`#34C759`) |
| 下载/上传速度 | title2 (~22pt, semibold) | `.primary` (`#000000`) |
| MB/s 换算 | caption2 (~11pt) | `.secondary.opacity(0.8)` (`#8E8E93` 80%) |
| 延迟标签 | 默认 | `.secondary` (`#8E8E93`) |
| 延迟图标 | - | `.orange` (`#FF9500`) |
| 抖动图标 | - | `.purple` (`#AF52DE`) |
| 延迟/抖动值 | 默认 (semibold) | `.primary` (`#000000`) |
| 进度条 | - | `.blue` (`#007AFF`) |
| 阶段文字 | caption (~12pt) | `.secondary` (`#8E8E93`) |
| 错误信息 | caption (~12pt) | `.red` (`#FF3B30`) |
| 测试按钮 | headline (~17pt) | `.white` (`#FFFFFF`) |
| 测试按钮背景 | - | 运行中: `.red` (`#FF3B30`), 停止: `.blue` (`#007AFF`) |
| 应用分组标题 | headline (~17pt) | `.primary` (`#000000`) |
| 网络质量指示 | caption (~12pt) | 根据质量: `.green/.yellow/.orange/.red` (`#34C759/#FFCC00/#FF9500/#FF3B30`) |
| 应用图标 | 16pt | 根据延迟质量着色 |
| 应用名称 | caption (~12pt) | `.primary` (`#000000`) |
| 应用延迟 | caption (~12pt, medium) | 根据质量着色 |
| 应用卡片背景 | - | `Color(.systemBackground)` (`#FFFFFF`) |
| 分组背景 | - | `Color(.systemGray6)` (`#F2F2F7`) |
| 说明文字 | caption2 (~11pt) | `.secondary` (`#8E8E93`) |

#### 4.7.7.1 测速服务器

| 服务器 | 下载测试 URL | 上传测试 URL | 延迟测试 URL |
|--------|-------------|-------------|-------------|
| 腾讯云 | `https://dldir1.qq.com/qqfile/qq/PCQQ9.7.17/QQ9.7.17.29225.exe` | - | `https://www.qq.com` |
| 阿里云 | `https://cdn.china-speed.org.cn/speedtest/100mb.bin` | - | `https://www.aliyun.com` |
| Cloudflare (备用) | `https://speed.cloudflare.com/__down?bytes=` | `https://speed.cloudflare.com/__up` | `https://speed.cloudflare.com/__down?bytes=0` |

#### 4.7.7.2 常用应用延迟测试列表

**腾讯系应用**

| 应用名称 | SF Symbol 图标 | 测试 URL |
|---------|---------------|---------|
| 腾讯新闻 | `newspaper.fill` | `https://www.qq.com` |
| 腾讯视频 | `tv.fill` | `https://v.qq.com` |
| 微信 | `message.fill` | `https://weixin.qq.com` |
| 微信支付 | `creditcard.fill` | `https://support.pay.weixin.qq.com` |
| 广告平台 | `megaphone.fill` | `https://e.qq.com` |
| 王者荣耀 | `gamecontroller.fill` | `https://pvp.qq.com` |
| 和平精英 | `scope` | `https://gp.qq.com` |
| 腾讯云 | `cloud.fill` | `https://cloud.tencent.com` |
| 腾讯官网 | `building.2.fill` | `https://www.tencent.com` |
| 元宝 | `sparkles` | `https://yuanbao.tencent.com` |

**其他应用**

| 应用名称 | SF Symbol 图标 | 测试 URL |
|---------|---------------|---------|
| 百度 | `magnifyingglass` | `https://www.baidu.com` |
| 阿里 | `cart.fill` | `https://www.aliyun.com` |
| 字节 | `play.circle.fill` | `https://www.bytedance.com` |
| 京东 | `bag.fill` | `https://www.jd.com` |
| 微博 | `bubble.left.fill` | `https://m.weibo.cn` |
| 美团 | `fork.knife` | `https://www.meituan.com` |
| 网易 | `envelope.fill` | `https://www.163.com` |
| Deepseek | `brain.head.profile` | `https://www.deepseek.com` |

#### 4.7.7.3 网络质量判定标准

| 质量等级 | 延迟范围 | 颜色 | 中文显示 | 英文显示 |
|---------|---------|------|---------|---------|
| 极佳 | < 50ms | `.green` (`#34C759`) | 极佳 | Excellent |
| 良好 | 50-100ms | `.blue` (`#007AFF`) | 良好 | Good |
| 一般 | 100-200ms | `.orange` (`#FF9500`) | 一般 | Fair |
| 较差 | > 200ms | `.red` (`#FF3B30`) | 较差 | Poor |

### 4.7.8 设备信息页面 (DeviceInfoView)

#### 页面布局

```
┌─────────────────────────────────────────┐
│  设备信息                          [🔄] │  导航栏 (带刷新按钮)
├─────────────────────────────────────────┤
│  公网 IP 信息                           │
│  ├─ 公网 IP      119.147.xxx.xxx        │
│  ├─ 归属地       广东省深圳市            │
│  └─ 运营商       中国电信                │
├─────────────────────────────────────────┤
│  设备信息                               │
│  ├─ 设备名称     iPhone 15 Pro          │
│  ├─ 设备型号     iPhone16,1             │
│  └─ 设备标识     A2848                  │
├─────────────────────────────────────────┤
│  系统信息                               │
│  └─ 系统版本     iOS 17.2               │
├─────────────────────────────────────────┤
│  网络信息                               │
│  ├─ 网络状态     🟢 WiFi                │
│  ├─ 本地 IP      192.168.1.100          │
│  ├─ WiFi 名称    MyWiFi                 │
│  └─ 运营商       中国移动                │
├─────────────────────────────────────────┤
│  硬件状态                               │
│  ├─ 电池         🔋 85% 充电中          │
│  ├─ 存储         128GB / 256GB          │
│  └─ 内存使用     2.1GB / 6GB            │
└─────────────────────────────────────────┘
```

#### 样式规范

| 元素 | 字体大小 | 颜色 |
|------|----------|------|
| 加载文字 | subheadline (~15pt) | `.secondary` (`#8E8E93`) |
| Section 标题 | 默认 | 默认 |
| 信息行标题 | 默认 | `.secondary` (`#8E8E93`) |
| 信息行值 | 默认 | `.primary` (`#000000`) |
| 网络状态图标 | - | 断开: `.red` (`#FF3B30`), 连接: `.green` (`#34C759`) |
| 错误图标 | - | `.orange` (`#FF9500`) |
| 错误文字 | 默认 | `.secondary` (`#8E8E93`) |
| 刷新提示 | subheadline (~15pt) | `.white` (`#FFFFFF`) |
| 刷新提示背景 | - | `.black.opacity(0.75)` (`#000000` 75%) |

### 4.7.9 首页 (HomeView)

| 元素 | 字体大小 | 颜色 |
|------|----------|------|
| Logo 高度 | 70pt | - |
| 语言切换按钮 | subheadline (~15pt, medium) | `.blue` (`#007AFF`) |
| 语言切换背景 | - | `.blue.opacity(0.1)` (`#007AFF` 10%) |
| 用户专区标题 | title2 (~22pt, bold) | `.primary` (`#000000`) |
| 一键诊断图标 | 32pt | `.white` (`#FFFFFF`) |
| 一键诊断标题 | title3 (~20pt, bold) | `.white` (`#FFFFFF`) |
| 一键诊断描述 | caption (~12pt) | `.white.opacity(0.8)` (`#FFFFFF` 80%) |
| 一键诊断背景渐变 | - | `Color(red: 0.2, green: 0.4, blue: 0.9)` (`#3366E6`) → `Color(red: 0.6, green: 0.3, blue: 0.9)` (`#9933E6`) |
| 工具卡片图标 (2列) | title2 (~22pt) | 各工具主题色 |
| 工具卡片图标 (3列) | title3 (~20pt) | 各工具主题色 |
| 工具卡片图标 (4列) | body (~17pt) | 各工具主题色 |
| 工具卡片标题 (2列) | headline (~17pt) | `.primary` (`#000000`) |
| 工具卡片标题 (3列) | subheadline (~15pt, medium) | `.primary` (`#000000`) |
| 工具卡片标题 (4列) | caption (~12pt) | `.primary` (`#000000`) |
| 工具卡片描述 | caption (~12pt) | `.secondary` (`#8E8E93`) |
| 工具卡片背景 | - | `Color(.systemBackground)` (`#FFFFFF`) |
| 快速操作标题 | headline/title2 | `.primary` (`#000000`) |
| 快速操作按钮标题 | subheadline (~15pt, medium) | `.primary` (`#000000`) |
| 快速操作按钮描述 | caption (~12pt) | `.secondary` (`#8E8E93`) |
| 快速操作图标 | title3 (~20pt) | `.orange` (`#FF9500`) |
| 快速操作背景 | - | `Color(.systemBackground)` (`#FFFFFF`) |

### 4.7.10 布局间距规范

| 位置 | 间距值 |
|------|--------|
| 首页主容器 VStack | 24pt |
| 首页外边距 | 16pt (默认 padding) |
| Logo 与一键诊断间距 | 4pt (24pt - 20pt 负边距) |
| 工具网格间距 | 12pt |
| 一键诊断内部 VStack | 12pt |
| 一键诊断垂直内边距 | 28pt |
| 工具卡片内部 VStack (2列) | 12pt |
| 工具卡片内部 VStack (3列) | 8pt |
| 工具卡片内部 VStack (4列) | 6pt |
| 工具卡片垂直内边距 (2列) | 20pt |
| 工具卡片垂直内边距 (3列) | 16pt |
| 工具卡片垂直内边距 (4列) | 12pt |
| 功能页面主 VStack | 16pt |
| 快捷输入按钮间距 | 6pt |
| 快捷主机/域名间距 | 8pt |

### 4.7.11 一键诊断页面 (QuickDiagnosisView)

一键诊断功能包含多个状态页面，根据诊断流程切换：

#### 4.7.11.1 输入诊断码页面 (idle/loading 状态)

```
┌─────────────────────────────────────────┐
│                                         │
│            ┌─────────────┐              │
│            │   ✨ 图标   │              │  渐变圆形背景 (80x80)
│            │  wand.and.  │              │  蓝紫渐变
│            │   stars     │              │
│            └─────────────┘              │
│                                         │
│             一键诊断                     │  标题 (title, bold)
│                                         │
│        输入诊断码，快速定位问题           │  副标题 (subheadline)
│                                         │
│     ┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌───┐│
│     │ 1 │ │ 2 │ │ 3 │ │ 4 │ │ 5 │ │ 6 ││  6位数字输入框
│     └───┘ └───┘ └───┘ └───┘ └───┘ └───┘│  (48x60 每格)
│                                         │
│          ⏳ 正在获取诊断任务...          │  加载状态 (loading时显示)
│                                         │
│        诊断码可从华佗平台获取            │  提示文字 (caption)
│                                         │
└─────────────────────────────────────────┘
```

#### 4.7.11.2 任务预览页面 (loaded 状态)

```
┌─────────────────────────────────────────┐
│  诊断任务名称                           │
│  诊断码: 123456          Report #12345  │  案例信息头部
│  ─────────────────────────────────────  │
│  📋 5 个探测任务                         │
├─────────────────────────────────────────┤
│  ┌─────────────────────────────────────┐│
│  │ 🔵 Ping 测试                         ││
│  │ www.qq.com (次数: 10, 大小: 56B)    ││  任务预览卡片
│  └─────────────────────────────────────┘│
│  ┌─────────────────────────────────────┐│
│  │ 🟠 TCP 连接                          ││
│  │ www.qq.com:443                       ││
│  └─────────────────────────────────────┘│
│  ┌─────────────────────────────────────┐│
│  │ 🟢 UDP 测试                          ││
│  │ 8.8.8.8:53                          ││
│  └─────────────────────────────────────┘│
│  ┌─────────────────────────────────────┐│
│  │ 🔷 DNS 查询                          ││
│  │ www.qq.com                          ││
│  └─────────────────────────────────────┘│
│  ┌─────────────────────────────────────┐│
│  │ 🟣 路由追踪                          ││
│  │ www.qq.com                          ││
│  └─────────────────────────────────────┘│
├─────────────────────────────────────────┤
│  ┌─────────────────────────────────────┐│
│  │      [▶️ 开始诊断]                   ││  渐变按钮
│  └─────────────────────────────────────┘│
└─────────────────────────────────────────┘
```

#### 4.7.11.3 执行中页面 (running 状态)

```
┌─────────────────────────────────────────┐
│                                         │
│            ┌─────────────┐              │
│            │    ╭───╮    │              │  圆环进度条 (80x80)
│            │   ╱     ╲   │              │  渐变色填充
│            │  │  45%  │  │              │
│            │   ╲     ╱   │              │
│            │    ╰───╯    │              │
│            └─────────────┘              │
│                                         │
│            正在执行诊断...               │  状态文字 (headline)
│            任务 2 / 5                    │  进度文字 (subheadline)
│                                         │
├─────────────────────────────────────────┤
│  ┌─────────────────────────────────────┐│
│  │ ✅ Ping 测试                         ││  已完成任务
│  │ www.qq.com                  成功     ││
│  └─────────────────────────────────────┘│
│  ┌─────────────────────────────────────┐│
│  │ ⏳ TCP 连接                          ││  执行中任务
│  │ www.qq.com:443              运行中   ││  (带 ProgressView)
│  └─────────────────────────────────────┘│
│  ┌─────────────────────────────────────┐│
│  │ 🕐 UDP 测试                          ││  待执行任务
│  │ 8.8.8.8:53                  等待中   ││
│  └─────────────────────────────────────┘│
│  ┌─────────────────────────────────────┐│
│  │ 🕐 DNS 查询                          ││
│  │ www.qq.com                  等待中   ││
│  └─────────────────────────────────────┘│
│  ┌─────────────────────────────────────┐│
│  │ 🕐 路由追踪                          ││
│  │ www.qq.com                  等待中   ││
│  └─────────────────────────────────────┘│
└─────────────────────────────────────────┘
```

#### 4.7.11.4 结果页面 (completed 状态)

```
┌─────────────────────────────────────────┐
│                                         │
│            ┌─────────────┐              │
│            │     ✅      │              │  完成图标 (64x64)
│            │  checkmark  │              │  绿色背景
│            │   .circle   │              │
│            └─────────────┘              │
│                                         │
│            诊断完成                      │  标题 (title3, bold)
│            4 / 5 任务成功                │  统计 (subheadline)
│       结果已关联到 Report #12345        │  关联信息 (caption, blue)
│                                         │
├─────────────────────────────────────────┤
│  ┌─────────────────────────────────────┐│
│  │ ✅ Ping 测试              12.5ms  ▼ ││  可展开结果卡片
│  │ www.qq.com                          ││
│  │ ─────────────────────────────────── ││
│  │ Ping 结果                           ││  展开后显示详情
│  │ 成功率: 10/10   平均延迟: 12.5ms    ││
│  │ 丢包率: 0%                          ││
│  └─────────────────────────────────────┘│
│  ┌─────────────────────────────────────┐│
│  │ ✅ TCP 连接               23.1ms  ▶ ││
│  │ www.qq.com:443                      ││
│  └─────────────────────────────────────┘│
│  ┌─────────────────────────────────────┐│
│  │ ✅ UDP 测试               15.2ms  ▶ ││
│  │ 8.8.8.8:53                          ││
│  └─────────────────────────────────────┘│
│  ┌─────────────────────────────────────┐│
│  │ ❌ DNS 查询                       ▶ ││  失败任务
│  │ www.qq.com                          ││
│  └─────────────────────────────────────┘│
│  ┌─────────────────────────────────────┐│
│  │ ✅ 路由追踪               856ms   ▶ ││
│  │ www.qq.com                          ││
│  └─────────────────────────────────────┘│
├─────────────────────────────────────────┤
│  ┌─────────────────────────────────────┐│
│  │    [🔄 重新诊断]                     ││  渐变按钮
│  └─────────────────────────────────────┘│
└─────────────────────────────────────────┘
```

#### 4.7.11.5 错误页面 (error 状态)

```
┌─────────────────────────────────────────┐
│                                         │
│                                         │
│            ┌─────────────┐              │
│            │     ⚠️      │              │  错误图标 (80x80)
│            │ exclamation │              │  红色背景
│            │  .triangle  │              │
│            └─────────────┘              │
│                                         │
│            获取失败                      │  标题 (title2, bold)
│                                         │
│        未找到诊断案例或网络错误          │  错误信息 (subheadline)
│                                         │
│         ┌─────────────────┐             │
│         │   [🔄 重试]     │             │  渐变按钮
│         └─────────────────┘             │
│                                         │
│                                         │
└─────────────────────────────────────────┘
```

#### 样式规范

| 元素 | 字体大小 | 颜色 |
|------|----------|------|
| **输入页面** | | |
| 图标圆形背景 | 80x80 | 渐变: `.gradientBlue` (`#3366E6`) → `.gradientPurple` (`#9933E6`) |
| 图标 | 36pt | `.white` (`#FFFFFF`) |
| 标题 | title (~28pt, bold) | `.primary` (`#000000`) |
| 副标题 | subheadline (~15pt) | `.secondary` (`#8E8E93`) |
| 数字输入框 | title (~28pt, semibold) | `.primary` (`#000000`) |
| 输入框边框 | - | 激活: `.gradientBlue` (`#3366E6`), 未激活: `systemGray4` |
| 加载文字 | 默认 | `.secondary` (`#8E8E93`) |
| 提示文字 | caption (~12pt) | `.secondary` (`#8E8E93`) |
| **任务预览页面** | | |
| 案例名称 | headline (~17pt) | `.primary` (`#000000`) |
| 诊断码 | caption (~12pt) | `.secondary` (`#8E8E93`) |
| Report ID | caption (~12pt) | `.secondary` (`#8E8E93`), 背景 `systemGray5` |
| 任务数量 | subheadline (~15pt) | `.secondary` (`#8E8E93`) |
| 任务卡片图标背景 | 44x44 | 各类型主题色 15% 透明度 |
| 任务类型名称 | headline (~17pt) | `.primary` (`#000000`) |
| 任务描述 | caption (~12pt) | `.secondary` (`#8E8E93`) |
| 开始按钮 | headline (~17pt) | `.white` (`#FFFFFF`), 渐变背景 |
| **执行中页面** | | |
| 进度环 | 80x80, 8pt 线宽 | 渐变填充, 背景 `systemGray4` |
| 进度百分比 | headline (~17pt, bold) | `.primary` (`#000000`) |
| 状态文字 | headline (~17pt) | `.primary` (`#000000`) |
| 任务进度 | subheadline (~15pt) | `.secondary` (`#8E8E93`) |
| 状态-等待 | caption (~12pt) | `.secondary` (`#8E8E93`), 图标 `.gray` |
| 状态-运行中 | caption (~12pt) | `.blue` (`#007AFF`), ProgressView |
| 状态-成功 | caption (~12pt) | `.green` (`#34C759`), 图标 checkmark |
| 状态-失败 | caption (~12pt) | `.red` (`#FF3B30`), 图标 xmark |
| **结果页面** | | |
| 完成图标背景 | 64x64 | `.green.opacity(0.15)` (`#34C759` 15%) |
| 完成图标 | 36pt | `.green` (`#34C759`) |
| 完成标题 | title3 (~20pt, bold) | `.primary` (`#000000`) |
| 成功统计 | subheadline (~15pt) | `.secondary` (`#8E8E93`) |
| Report 关联 | caption (~12pt) | `.blue` (`#007AFF`) |
| 结果卡片耗时 | caption (~12pt) | `.secondary` (`#8E8E93`) |
| 展开箭头 | caption (~12pt) | `.secondary` (`#8E8E93`) |
| 详情标签 | caption (~12pt, medium) | `.primary` (`#000000`) |
| 详情值标签 | caption2 (~11pt) | `.secondary` (`#8E8E93`) |
| 详情值 | caption (~12pt) | `.primary` (`#000000`) |
| 重新诊断按钮 | headline (~17pt) | `.white` (`#FFFFFF`), 渐变背景 |
| **错误页面** | | |
| 错误图标背景 | 80x80 | `.red.opacity(0.15)` (`#FF3B30` 15%) |
| 错误图标 | 40pt | `.red` (`#FF3B30`) |
| 错误标题 | title2 (~22pt, bold) | `.primary` (`#000000`) |
| 错误信息 | subheadline (~15pt) | `.secondary` (`#8E8E93`) |
| 重试按钮 | headline (~17pt) | `.white` (`#FFFFFF`), 渐变背景 |

#### 4.7.11.6 诊断任务类型

| 任务类型 | API 值 | 显示名称 | 图标 | 颜色 |
|---------|--------|---------|------|------|
| Ping | `ping` | Ping 测试 | `network` | `.blue` (`#007AFF`) |
| TCP | `tcp_port` | TCP 连接 | `arrow.left.arrow.right` | `.orange` (`#FF9500`) |
| UDP | `udp_port` | UDP 测试 | `paperplane` | `.green` (`#34C759`) |
| DNS | `dns` | DNS 查询 | `globe` | `.cyan` (`#32ADE6`) |
| Traceroute | `mtr` | 路由追踪 | `point.topleft.down.curvedto.point.bottomright.up` | `.purple` (`#AF52DE`) |

#### 4.7.11.7 诊断流程状态机

```
┌───────┐    输入6位码     ┌─────────┐    获取成功    ┌────────┐
│ idle  │ ───────────────▶ │ loading │ ─────────────▶ │ loaded │
└───────┘                  └─────────┘                └────────┘
    ▲                           │                         │
    │                           │ 获取失败                │ 点击开始
    │                           ▼                         ▼
    │                      ┌─────────┐               ┌─────────┐
    │                      │  error  │               │ running │
    │                      └─────────┘               └─────────┘
    │                           │                         │
    │         点击重试          │                         │ 全部完成
    └───────────────────────────┘                         ▼
    │                                               ┌───────────┐
    └─────────────────── 点击重新诊断 ◀────────────│ completed │
                                                    └───────────┘
```

---

## 五、数据模型

### 5.1 Ping 结果模型

```kotlin
data class PingResult(
    val id: String = UUID.randomUUID().toString(),
    val sequence: Int,
    val host: String,
    val ip: String,
    val latency: Double?,  // 秒
    val status: PingStatus,
    val timestamp: Date
)

enum class PingStatus {
    SUCCESS, TIMEOUT, ERROR
}

data class PingStatistics(
    var sent: Int = 0,
    var received: Int = 0,
    var lost: Int = 0,
    var minLatency: Double = Double.MAX_VALUE,
    var maxLatency: Double = 0.0,
    var totalLatency: Double = 0.0,
    var latencies: List<Double> = emptyList()
) {
    val lossRate: Double get() = if (sent > 0) lost.toDouble() / sent * 100 else 0.0
    val avgLatency: Double get() = if (received > 0) totalLatency / received else 0.0
    val stddevLatency: Double get() = // 计算标准差
}
```

### 5.2 DNS 结果模型

```kotlin
data class DNSResult(
    val id: String = UUID.randomUUID().toString(),
    val domain: String,
    val recordType: DNSRecordType,
    val records: List<DNSRecord>,
    val latency: Double,  // 秒
    val server: String?,
    val error: String?,
    val timestamp: Date
)

data class DNSRecord(
    val id: String = UUID.randomUUID().toString(),
    val name: String?,
    val type: Int,
    val typeString: String,
    val ttl: Long?,
    val rdclass: String = "IN",
    val value: String,
    val rawData: ByteArray
)

enum class DNSRecordType(val value: String) {
    A("A"), AAAA("AAAA"), CNAME("CNAME"), MX("MX"), TXT("TXT"), NS("NS")
}
```

### 5.3 Traceroute 跳点模型

```kotlin
data class TraceHop(
    val id: String = UUID.randomUUID().toString(),
    val hop: Int,
    val ip: String,
    val hostname: String?,
    val latencies: List<Double?>,  // 所有探测的延迟
    val status: HopStatus,
    var location: String? = null  // IP 归属地
) {
    val receivedCount: Int get() = latencies.filterNotNull().size
    val sentCount: Int get() = latencies.size
    val lossRate: Double get() = if (sentCount > 0) (sentCount - receivedCount).toDouble() / sentCount * 100 else 0.0
    val avgLatency: Double? get() = latencies.filterNotNull().takeIf { it.isNotEmpty() }?.average()
}

enum class HopStatus {
    SUCCESS, TIMEOUT, ERROR
}
```

### 5.4 TCP/UDP 结果模型

```kotlin
data class TCPResult(
    val id: String = UUID.randomUUID().toString(),
    val host: String,
    val port: Int,
    val isOpen: Boolean,
    val latency: Double?,
    val error: String?,
    val timestamp: Date
)

data class UDPResult(
    val id: String = UUID.randomUUID().toString(),
    val host: String,
    val port: Int,
    val sent: Boolean,
    val received: Boolean,
    val latency: Double?,
    val error: String?,
    val timestamp: Date
)
```

### 5.5 HTTP 结果模型

```kotlin
data class HTTPResult(
    val id: String = UUID.randomUUID().toString(),
    val url: String,
    val statusCode: Int?,
    val statusMessage: String,
    val headers: Map<String, String>,
    val body: String,
    val responseTime: Double,  // 秒
    val error: String?,
    val timestamp: Date
) {
    val isSuccess: Boolean get() = statusCode?.let { it in 200..299 } ?: false
}
```

### 5.6 历史任务记录模型

```kotlin
data class TaskHistoryRecord(
    val id: String = UUID.randomUUID().toString(),
    val type: TaskType,
    val target: String,
    val port: Int? = null,
    val status: TaskStatus,
    val resultSummary: String,
    val timestamp: Date,
    val details: TaskDetails? = null
)

enum class TaskType(val displayName: String, val iconName: String) {
    PING("Ping", "network"),
    TRACEROUTE("Traceroute", "route"),
    DNS("DNS", "dns"),
    TCP("TCP", "lan"),
    UDP("UDP", "upload"),
    SPEED_TEST("测速", "speed"),
    HTTP("HTTP", "http")
}

enum class TaskStatus {
    SUCCESS, FAILURE, PARTIAL
}

data class TaskDetails(
    // Ping
    var pingAvgLatency: Double? = null,
    var pingMinLatency: Double? = null,
    var pingMaxLatency: Double? = null,
    var pingStdDev: Double? = null,
    var pingLossRate: Double? = null,
    var pingSent: Int? = null,
    var pingReceived: Int? = null,
    // Traceroute
    var traceHops: Int? = null,
    var traceReachedTarget: Boolean? = null,
    // DNS
    var dnsRecords: List<String>? = null,
    var dnsQueryTime: Double? = null,
    var dnsServer: String? = null,
    // TCP
    var tcpIsOpen: Boolean? = null,
    var tcpLatency: Double? = null,
    // UDP
    var udpSent: Boolean? = null,
    var udpReceived: Boolean? = null,
    // 测速
    var downloadSpeed: Double? = null,
    var uploadSpeed: Double? = null,
    var latency: Double? = null,
    // HTTP
    var httpStatusCode: Int? = null,
    var httpResponseTime: Double? = null,
    var httpError: String? = null
)
```

---

## 六、计数/统计方案

### 6.1 Ping 统计

| 指标 | 计算方式 |
|------|----------|
| 发送数 | 每发送一个包 +1 |
| 接收数 | 每收到响应 +1 |
| 丢失数 | 发送数 - 接收数 |
| 丢包率 | (丢失数 / 发送数) × 100% |
| 最小延迟 | min(所有延迟) |
| 最大延迟 | max(所有延迟) |
| 平均延迟 | sum(延迟) / 接收数 |
| 标准差 | sqrt(sum((延迟-平均)²) / 接收数) |

### 6.2 Traceroute 统计

| 指标 | 计算方式 |
|------|----------|
| 总跳数 | 路由节点数量 |
| 每跳丢包率 | (发送数-接收数) / 发送数 × 100% |
| 每跳平均延迟 | sum(该跳延迟) / 接收数 |
| 是否到达目标 | 最后一跳 IP == 目标 IP |

### 6.3 测速统计

| 指标 | 单位 | 说明 |
|------|------|------|
| 下载速度 | Mbps | 下载测试文件的速率 |
| 上传速度 | Mbps | 上传测试数据的速率 |
| 延迟 | ms | 到测速服务器的 RTT |
| 抖动 | ms | 延迟的标准差 |

---

## 七、本地化字符串 (部分关键)

```kotlin
object L10n {
    // Tab 栏
    val tabLocalProbe = mapOf("zh" to "本地测", "en" to "Local")
    val tabCloudProbe = mapOf("zh" to "云探测", "en" to "Cloud")
    val tabData = mapOf("zh" to "数据", "en" to "Data")
    val tabProfile = mapOf("zh" to "我的", "en" to "Profile")
    
    // 网络工具
    val speedTest = mapOf("zh" to "测速", "en" to "Speed Test")
    val ping = "Ping"
    val traceroute = "Traceroute"
    val tcp = "TCP"
    val udp = "UDP"
    val dns = "DNS"
    val httpGet = "HTTP"
    val deviceInfo = mapOf("zh" to "本机信息", "en" to "Device Info")
    val packetCapture = mapOf("zh" to "抓包", "en" to "Capture")
    
    // 统计
    val sent = mapOf("zh" to "发送", "en" to "Sent")
    val received = mapOf("zh" to "接收", "en" to "Recv")
    val lost = mapOf("zh" to "丢失", "en" to "Lost")
    val average = mapOf("zh" to "平均", "en" to "Avg")
    val minimum = mapOf("zh" to "最小", "en" to "Min")
    val maximum = mapOf("zh" to "最大", "en" to "Max")
    val lossRate = mapOf("zh" to "丢包率", "en" to "Loss Rate")
    
    // 状态
    val success = mapOf("zh" to "成功", "en" to "Success")
    val failure = mapOf("zh" to "失败", "en" to "Failed")
    val timeout = mapOf("zh" to "超时", "en" to "Timeout")
    val open = mapOf("zh" to "开放", "en" to "Open")
    val closed = mapOf("zh" to "关闭", "en" to "Closed")
    
    // 操作
    val startProbe = mapOf("zh" to "开始探测", "en" to "Start Probe")
    val clear = mapOf("zh" to "清空", "en" to "Clear")
    val copy = mapOf("zh" to "复制", "en" to "Copy")
    val retry = mapOf("zh" to "重试", "en" to "Retry")
    val cancel = mapOf("zh" to "取消", "en" to "Cancel")
    val confirm = mapOf("zh" to "确定", "en" to "Confirm")
}
```

---

## 八、API 接口

### 8.0 API 鉴权机制

#### 8.0.1 鉴权配置

| 配置项 | 值 |
|--------|-----|
| SystemId | `"4"` |
| SecretKey | `"b5df1b887f2a16077f0083556fde647552cc8d0f777233681ddc69bcc534cd77"` |
| 签名算法 | HMAC-SHA-512 |

#### 8.0.2 签名生成流程

**步骤 1: 准备签名数据**

```
strToSign = timestamp + requestBody
```

- `timestamp`: 当前 Unix 时间戳（秒级）
- `requestBody`: 请求体 JSON 字符串

**步骤 2: 计算 HMAC 签名**

```swift
// 1. 将十六进制密钥转换为 Data
let keyData = Data(hexString: secretKey)

// 2. 计算 HMAC-SHA-512
let signature = HMAC_SHA512(key: keyData, data: strToSign)

// 3. 将签名转换为小写十六进制字符串
let signatureHex = signature.map { String(format: "%02x", $0) }.joined()
```

**步骤 3: 构造 Authorization 头**

```
Authorization: HMAC-SHA-512 Timestamp={timestamp},Signature={signatureHex},SystemId={systemId}
```

#### 8.0.3 完整签名示例

**请求体**:
```json
{"Action":"Query","Method":"GetAgentGeo","SystemId":"4","AppendInfo":{"UserId":1},"Condition":{"AddressFamily":4,"IsPublic":1}}
```

**签名过程**:
```
timestamp = 1703232000
strToSign = "1703232000{\"Action\":\"Query\",\"Method\":\"GetAgentGeo\",...}"
signature = HMAC_SHA512(keyData, strToSign) = "a1b2c3d4e5f6..."
```

**最终请求头**:
```
Authorization: HMAC-SHA-512 Timestamp=1703232000,Signature=a1b2c3d4e5f6...,SystemId=4
Content-Type: application/json
```

#### 8.0.4 Swift 实现代码

```swift
import CommonCrypto

struct AuthConfig {
    let systemId: String
    let secretKey: String  // 十六进制字符串
    let useHmacSha512: Bool
}

/// 生成签名头部
func makeAuthorization(
    systemId: String,
    secretKey: String,
    requestBodyData: String,
    isHmacSha512: Bool = true
) -> String {
    let timestamp = Int(Date().timeIntervalSince1970)
    
    // 拼装需要参与签名的数据
    let strToSign = "\(timestamp)\(requestBodyData)"
    
    // 将十六进制密钥转换为 Data
    let keyData = Data(hexString: secretKey) ?? Data()
    
    // 计算 HMAC 签名
    let signature: String
    let algoName: String
    
    if isHmacSha512 {
        algoName = "HMAC-SHA-512"
        signature = hmacSHA512(key: keyData, data: strToSign)
    } else {
        algoName = "HMAC-SHA-256"
        signature = hmacSHA256(key: keyData, data: strToSign)
    }
    
    return "\(algoName) Timestamp=\(timestamp),Signature=\(signature),SystemId=\(systemId)"
}

// HMAC-SHA-512 计算
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
    
    return digest.map { String(format: "%02x", $0) }.joined()
}

// HMAC-SHA-256 计算
private func hmacSHA256(key: Data, data: String) -> String {
    let dataBytes = data.data(using: .utf8)!
    var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
    
    key.withUnsafeBytes { keyPtr in
        dataBytes.withUnsafeBytes { dataPtr in
            CCHmac(
                CCHmacAlgorithm(kCCHmacAlgSHA256),
                keyPtr.baseAddress,
                key.count,
                dataPtr.baseAddress,
                dataBytes.count,
                &digest
            )
        }
    }
    
    return digest.map { String(format: "%02x", $0) }.joined()
}

// 十六进制字符串转 Data 扩展
extension Data {
    init?(hexString: String) {
        let len = hexString.count / 2
        var data = Data(capacity: len)
        var index = hexString.startIndex
        for _ in 0..<len {
            let nextIndex = hexString.index(index, offsetBy: 2)
            if let byte = UInt8(hexString[index..<nextIndex], radix: 16) {
                data.append(byte)
            } else {
                return nil
            }
            index = nextIndex
        }
        self = data
    }
}
```

#### 8.0.5 需要鉴权的 API 列表

| API | 是否需要鉴权 |
|-----|-------------|
| 云探测 - 获取探针列表 | ✅ 需要 |
| 云探测 - 创建探测任务 | ✅ 需要 |
| 云探测 - 查询任务结果 | ✅ 需要 |
| 一键诊断 - 获取诊断案例 | ✅ 需要 |
| 一键诊断 - 上报诊断结果 | ✅ 需要 |
| 批量获取 IP 归属地 | ✅ 需要 |
| 历史任务 - 上传记录 | ✅ 需要 |
| 用户登录 - 游客登录 | ❌ 不需要 |
| 用户登录 - 手机号登录 | ❌ 不需要 |
| 用户登录 - 账号密码登录 | ❌ 不需要 |
| 获取图形验证码 | ❌ 不需要 |
| 发送短信验证码 | ❌ 不需要 |

---

### 8.1 云探测 API

**基础 URL**: `https://api.itango.tencent.com/api`

**鉴权方式**: HMAC-SHA512 签名（参见 8.0 节）

#### 获取探针列表

```json
{
    "Action": "Query",
    "Method": "GetAgentGeo",
    "SystemId": "4",
    "AppendInfo": { "UserId": 123 },  // 当前用户 ID，未登录为 -1
    "Condition": { "AddressFamily": 4, "IsPublic": 1 }
}
```

#### 创建探测任务

```json
{
    "Action": "MsmCustomTask",
    "Method": "Create",
    "SystemId": "4",
    "AppendInfo": { "UserId": 123 },  // 当前用户 ID，未登录为 -1
    "Data": {
        "MainTaskName": "itango-app-ping-task",
        "MsmSetting": {
            "Af": 4,
            "MsmType": "ping",
            "Options": {
                "count": 4,
                "interval": 0.02,
                "size": 64,
                "timeout": 4
            }
        },
        "SubTaskList": [...]
    }
}
```

**MsmType 可选值**:
- `ping` - Ping 探测
- `dns` - DNS 查询
- `tcp_port` - TCP 端口测试
- `udp_port` - UDP 端口测试

#### 查询任务结果

```json
{
    "Action": "MsmTaskResult",
    "Method": "RealTimeTaskResult",
    "SystemId": 4,
    "AppendInfo": { "UserId": 123 },  // 当前用户 ID，未登录为 -1
    "Data": { "MainId": 12345 }
}
```

### 8.2 一键诊断 API

#### 获取诊断案例

```
POST https://api.itango.tencent.com/api
Content-Type: application/json
```

**请求体**:

```json
{
    "Action": "MsmExample",
    "Method": "GetMsmExample",
    "SystemId": "4",
    "Condition": {
        "UniqueKey": "123456"
    },
    "AppendInfo": {
        "UserId": 123  // 当前用户 ID，未登录为 -1
    }
}
```

**响应示例**:

```json
{
    "Return": 0,
    "Details": "",
    "ReqId": "xxx",
    "Data": {
        "Data": [
            {
                "Id": 1,
                "TaskName": "诊断任务",
                "UniqueKey": "123456",
                "UserId": "1",
                "CreateTime": "2025-01-01 00:00:00",
                "UpdateTime": "2025-01-01 00:00:00",
                "ExampleDetail": [
                    {
                        "Id": 1,
                        "ExampleId": "xxx",
                        "MsmType": "ping",
                        "Target": "www.qq.com",
                        "Port": null,
                        "Options": {
                            "count": 10,
                            "size": 56,
                            "timeout": 5
                        },
                        "UserId": null
                    },
                    {
                        "Id": 2,
                        "ExampleId": "xxx",
                        "MsmType": "tcp_port",
                        "Target": "www.qq.com",
                        "Port": "443",
                        "Options": null,
                        "UserId": null
                    }
                ]
            }
        ],
        "ReportId": 12345
    }
}
```

**MsmType 可选值**:
- `ping` - Ping 探测
- `tcp_port` - TCP 端口测试
- `udp_port` - UDP 端口测试
- `dns` - DNS 查询
- `mtr` - Traceroute 路由追踪

#### 上报诊断结果

```
POST https://api.itango.tencent.com/api
Content-Type: application/json
```

**请求体** (需要 HMAC-SHA512 签名):

```json
{
    "Action": "MsmReceive",
    "Method": "BatchRun",
    "SystemId": "4",
    "Data": [
        {
            "MsmType": "ping",
            "MsmDatas": {
                "ExampleUniqueKey": "123456",
                "ExampleReportId": 12345,
                "LocalDeviceType": "iOS",
                "LocalNetwork": "WiFi",
                "Addr": "www.qq.com",
                "BuildinAf": "4",
                "BuildinSource": "app",
                "BuildinUserId": 1,
                "AvgRttMicro": 12500,
                "MinRttMicro": 11200,
                "MaxRttMicro": 14100,
                "PacketsSent": 10,
                "PacketsRecv": 10,
                "PacketLoss": 0,
                "RttsMicro": [12300, 11800, 13100],
                "IPAddr": "14.18.175.154",
                "ResultToText": "PING www.qq.com..."
            }
        }
    ]
}
```

### 8.3 用户登录 API

#### 游客登录

```
POST https://itango.tencent.com/out/itango/player
Content-Type: application/json
```

**请求体**: 空或 `{}`

**响应**:

```json
{
    "status": 0,
    "msg": "",
    "data": {
        "Id": 12345,
        "Username": null,
        "UserType": "player",
        "Name": null,
        "PhoneNumber": null,
        "Company": null,
        "Duty": null
    }
}
```

#### 发送验证码

```
POST https://itango.tencent.com/out/sms/code
Content-Type: application/json

{
    "PhoneNumber": "13800138000",
    "Scene": "login"
}
```

**响应**:

```json
{
    "status": 0,
    "msg": "",
    "data": null
}
```

#### 手机号登录

```
POST https://itango.tencent.com/out/itango/login
Content-Type: application/json

{
    "Verification": "Phone",
    "Username": "",
    "Password": "",
    "CaptchaValue": "",
    "CaptchaId": "",
    "UserType": "community",
    "PhoneNumber": "13800138000",
    "Code": "123456",
    "IsRemember": false
}
```

**UserType 可选值**:
- `community` - 社区版
- `custom` - 定制版

**响应**:

```json
{
    "status": 0,
    "msg": "",
    "data": {
        "Id": 12345,
        "Username": "user@example.com",
        "UserType": "community",
        "Name": "用户名",
        "PhoneNumber": "13800138000",
        "Company": "公司名",
        "Duty": "职位"
    }
}
```

#### 账号密码登录

```
POST https://itango.tencent.com/out/itango/login
Content-Type: application/json

{
    "Verification": "Account",
    "Username": "user@example.com",
    "Password": "password123",
    "CaptchaValue": "abcd",
    "CaptchaId": "xxx",
    "UserType": "community",
    "PhoneNumber": "",
    "Code": "",
    "IsRemember": false
}
```

#### 获取图形验证码

```
GET https://itango.tencent.com/out/captcha
```

**响应**:

```json
{
    "status": 0,
    "msg": "",
    "data": {
        "captchaId": "xxx",
        "code": 0,
        "data": "base64...",
        "msg": ""
    }
}
```

#### 登出

```
POST https://itango.tencent.com/out/itango/logout
Content-Type: application/json

{}
```
```

---

## 九、本地存储

| Key | 类型 | 说明 |
|-----|------|------|
| `AppLanguage` | String | 当前语言 (zh/en) |
| `ToolsPerRow` | Int | 首页每行工具数 (2-4) |
| `HomeStyle` | String | 首页样式 (modern/classic) |
| `com.pong.taskHistory` | JSON | 历史任务记录 |
| `PingHistory` | [String] | Ping 目标历史 (最多10条) |
| `DNSHistory` | [String] | DNS 查询历史 (最多10条) |
| `TCPHistory` | [String] | TCP 目标历史 (最多10条) |
| `UDPHistory` | [String] | UDP 目标历史 (最多10条) |
| `TraceHistory` | [String] | Traceroute 历史 (最多10条) |
| `HTTPHistory` | [String] | HTTP GET URL 历史 (最多10条) |
| `CloudProbeHostHistory` | [String] | 云探测目标历史 (最多10条) |
| `CurrentUser` | JSON | 当前登录用户信息 |

---

## 十、关键交互细节

### 10.1 输入框设计

- 支持快捷输入按钮: `www.` `.com` `.cn` `.net`
- 历史记录下拉列表 (最多保存10条)
- 清除按钮 (输入框右侧 X 图标)
- 回车键直接开始测试

### 10.2 结果展示

- 实时滚动到最新结果
- 终端风格黑色背景
- 等宽字体显示 (Menlo / Courier)
- 一键复制完整结果

### 10.3 状态指示

- 测试中: 显示加载动画 (ProgressView)
- 成功: 绿色文字/图标
- 超时: 橙色文字
- 错误: 红色文字

### 10.4 Toast 提示

- 复制成功提示
- 登录成功提示
- 上传成功/失败提示
- 网络错误提示

### 10.5 下拉刷新

- 历史记录页面支持下拉刷新
- 云探测结果支持下拉刷新

### 10.6 网络连接检查

所有网络探测功能在执行前会检查设备的网络连接状态。如果设备没有网络连接，会立即显示错误提示，避免无意义的等待。

#### 实现方式

通过 `DeviceInfoManager.shared.networkStatus` 获取当前网络状态：

```swift
var isNetworkAvailable: Bool {
    let status = DeviceInfoManager.shared.networkStatus
    return status != .disconnected && status != .unknown
}
```

#### 网络状态枚举

| 状态 | 说明 | 是否可用 |
|------|------|---------|
| `.unknown` | 未知状态 | ❌ |
| `.disconnected` | 无网络连接 | ❌ |
| `.wifi` | WiFi 连接 | ✅ |
| `.cellular` | 蜂窝网络 | ✅ |
| `.cellular2G` | 2G 网络 | ✅ |
| `.cellular3G` | 3G 网络 | ✅ |
| `.cellular4G` | 4G 网络 | ✅ |
| `.cellular5G` | 5G 网络 | ✅ |
| `.ethernet` | 有线网络 | ✅ |
| `.other` | 其他网络 | ✅ |

#### 受影响的 Manager

以下 Manager 在执行网络操作前会进行网络检查：

| Manager | 检查方法 | 无网络时的错误提示 |
|---------|----------|-------------------|
| `PingManager` | `startPing()` | 显示错误状态的 PingResult |
| `DNSManager` | `query()`, `queryAll()` | 返回错误 DNSResult |
| `TraceManager` | `startTrace()` | 设置 `errorMessage` |
| `HTTPManager` | `sendGetRequest()` | 返回错误 HTTPResult |
| `TCPManager` | `scanPorts()`, `testConnection()` | 显示错误状态的 TCPResult |
| `UDPManager` | `testUDP()` | 显示错误状态的 UDPResult |
| `SpeedTestManager` | `startTest()`, `startAppLatencyTest()` | 设置 `error` 属性 |
| `QuickDiagnosisManager` | `startDiagnosis()` | 标记所有任务为失败 |

#### 错误提示文案

统一使用以下错误提示：

- **中文**: "无网络连接，请检查网络设置后重试"
- **英文**: "No network connection, please check network settings and try again"

#### 用户体验

1. 检测到无网络时，**立即**返回错误，不进行任何网络请求
2. 错误信息会显示在对应的结果区域，保持界面一致性
3. 用户可以在恢复网络后重新发起请求

---

## 十一、技术实现要点

### 11.1 Ping 实现

**iOS 实现方式**:
iOS 使用 `NWConnection` (TCP 连接方式) 模拟 Ping，因为 iOS 不允许普通应用直接发送 ICMP 包。

**Android 建议实现**:
```kotlin
// 方式1: 命令行方式 (推荐)
fun ping(host: String, count: Int = 4): List<PingResult> {
    val process = Runtime.getRuntime().exec("ping -c $count $host")
    // 解析输出...
}

// 方式2: Socket 连接方式
fun tcpPing(host: String, port: Int = 80): Long {
    val startTime = System.currentTimeMillis()
    Socket().use { socket ->
        socket.connect(InetSocketAddress(host, port), 5000)
    }
    return System.currentTimeMillis() - startTime
}
```

### 11.2 DNS 查询

**iOS 实现方式**:
使用 `dnssd` 框架进行 DNS 查询。

**Android 建议实现**:
```kotlin
// 方式1: 系统 API
fun dnsLookup(domain: String): List<String> {
    return InetAddress.getAllByName(domain).map { it.hostAddress }
}

// 方式2: 使用 dnsjava 库 (支持更多记录类型)
// implementation 'dnsjava:dnsjava:3.5.2'
```

### 11.3 Traceroute 实现

需要逐跳发送 TTL 递增的包，记录每跳响应。

**Android 建议实现**:
```kotlin
// 命令行方式
fun traceroute(host: String): List<TraceHop> {
    val process = Runtime.getRuntime().exec("traceroute -m 30 $host")
    // 解析输出...
}
```

### 11.4 测速实现

使用 Cloudflare 测速服务器:

```kotlin
// 下载测试
val downloadUrl = "https://speed.cloudflare.com/__down?bytes=10000000"

// 上传测试
val uploadUrl = "https://speed.cloudflare.com/__up"

// 计算速度
fun calculateSpeed(bytes: Long, timeMs: Long): Double {
    return (bytes * 8.0) / (timeMs / 1000.0) / 1_000_000  // Mbps
}
```

### 11.5 TCP 端口测试

```kotlin
fun tcpTest(host: String, port: Int, timeout: Int = 5000): TCPResult {
    return try {
        val startTime = System.currentTimeMillis()
        Socket().use { socket ->
            socket.connect(InetSocketAddress(host, port), timeout)
        }
        val latency = System.currentTimeMillis() - startTime
        TCPResult(host, port, true, latency, null)
    } catch (e: Exception) {
        TCPResult(host, port, false, null, e.message)
    }
}
```

### 11.6 UDP 测试

```kotlin
fun udpTest(host: String, port: Int, timeout: Int = 5000): UDPResult {
    return try {
        DatagramSocket().use { socket ->
            socket.soTimeout = timeout
            val data = "test".toByteArray()
            val packet = DatagramPacket(data, data.size, InetAddress.getByName(host), port)
            val startTime = System.currentTimeMillis()
            socket.send(packet)
            // UDP 是无连接的，发送成功即可
            UDPResult(host, port, true, false, System.currentTimeMillis() - startTime, null)
        }
    } catch (e: Exception) {
        UDPResult(host, port, false, false, null, e.message)
    }
}
```

---

## 十二、权限要求

### Android 权限

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
<uses-permission android:name="android.permission.READ_PHONE_STATE" />
```

---

## 十三、第三方依赖建议 (Android)

| 功能 | 推荐库 |
|------|--------|
| 网络请求 | OkHttp / Retrofit |
| JSON 解析 | Gson / Moshi |
| 异步处理 | Kotlin Coroutines |
| UI 框架 | Jetpack Compose |
| 本地存储 | DataStore / Room |
| DNS 查询 | dnsjava |
| 图表展示 | MPAndroidChart |
| WebView | Android WebView |

---

## 十四、项目结构建议 (Android)

```
app/
├── src/main/
│   ├── java/com/itango/pong/
│   │   ├── ui/
│   │   │   ├── home/
│   │   │   ├── cloud/
│   │   │   ├── data/
│   │   │   ├── profile/
│   │   │   ├── tools/
│   │   │   │   ├── ping/
│   │   │   │   ├── dns/
│   │   │   │   ├── tcp/
│   │   │   │   ├── udp/
│   │   │   │   ├── trace/
│   │   │   │   ├── http/
│   │   │   │   ├── speed/
│   │   │   │   └── device/
│   │   │   └── components/
│   │   ├── data/
│   │   │   ├── model/
│   │   │   ├── repository/
│   │   │   └── api/
│   │   ├── network/
│   │   │   ├── PingService.kt
│   │   │   ├── DNSService.kt
│   │   │   ├── TCPService.kt
│   │   │   ├── UDPService.kt
│   │   │   ├── TraceService.kt
│   │   │   └── SpeedTestService.kt
│   │   └── utils/
│   └── res/
│       ├── values/
│       │   ├── strings.xml
│       │   ├── strings-en.xml
│       │   └── colors.xml
│       └── drawable/
└── build.gradle
```

---

本文档涵盖了 iOS 版 Pong 应用的完整设计，可作为 Android 版本开发的参考。
