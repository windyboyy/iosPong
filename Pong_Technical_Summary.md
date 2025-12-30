# Pong (iTango 网络探测) - 技术概要

## 项目概述

| 项目 | 说明 |
|------|------|
| 项目名称 | Pong (iTango 网络探测) |
| 平台 | iOS (SwiftUI) |
| 架构 | MVVM + 单例管理器模式 |
| 语言支持 | 中文/英文双语 |
| 安装包大小 | ~1.8MB (App Store 下载大小) |
| 最低系统版本 | iOS 15.0 |

---

## 功能模块

### Tab 1 - 本地测 (Local)

| 功能 | 技术方案 | 说明 |
|------|----------|------|
| **Ping** | 原生 ICMP Socket | 支持 IPv4/IPv6，可配置包大小、间隔、次数 |
| **Traceroute** | ICMP + TTL 递增 | 支持 IPv4/IPv6，并发探测，批量 IP 归属地查询 |
| **DNS 查询** | Apple dnssd 框架 | 支持 A/AAAA/CNAME/MX/TXT/NS 记录类型 |
| **TCP 端口测试** | Network.framework | 单端口/批量扫描，3秒超时 |
| **UDP 测试** | Network.framework | 发送数据并尝试接收响应 |
| **HTTP GET** | URLSession | 返回状态码、响应头、响应体、响应时间 |
| **网速测试** | URLSession | 使用 Cloudflare 测速服务器，测试延迟/下载/上传 |
| **设备信息** | 系统 API | 公网 IP、设备信息、网络状态、硬件信息 |
| **一键诊断** | 综合调用 | 输入诊断码，批量执行任务并上报结果，支持 IPv4/IPv6 |

### Tab 2 - 云探测 (Cloud)

| 功能 | 说明 |
|------|------|
| 探针选择 | 按国家/运营商/AS号筛选公共探针 |
| 探测类型 | Ping / DNS / TCP / UDP |
| 任务执行 | 创建任务 → 轮询结果（最多5次，间隔3秒） |
| 鉴权方式 | HMAC-SHA-512 签名 |

### Tab 3 - IP查询 (IPQuery)

| 功能 | 说明 |
|------|------|
| IP 查询 | 支持 IPv4/IPv6 地址归属地查询 |
| 历史记录 | 最多保存 10 条，支持去重、删除、快速填充 |
| 存储方式 | UserDefaults |

### Tab 4 - 数据 (Data)

| 功能 | 说明 |
|------|------|
| 地图展示 | WKWebView + ECharts 5.4.3 |
| 地图数据 | 阿里云 DataV GeoJSON |
| 告警展示 | 飞线动画 + 涟漪效果 |
| 交互 | 省份点击筛选告警 |

### Tab 5 - 我的 (Profile)

| 功能 | 说明 |
|------|------|
| 用户系统 | 游客登录 / 手机号登录 / 账号密码登录 |
| 历史记录 | 支持查看、筛选、上传，14天自动过期 |
| 用户反馈 | 提交反馈内容和联系方式 |
| 设置 | 语言切换、关于、注销账号 |

---

## 公共服务

| 服务 | 说明 |
|------|------|
| 网络服务 | HTTP 请求封装、HMAC 签名鉴权 |
| IP 归属地 | 单个/批量 IP 查询，返回国家、省份、城市、运营商 |
| 多语言 | 中文/英文切换，UserDefaults 持久化 |
| APP 更新 | 启动时自动检查（1小时间隔），支持强制更新 |

---

## 项目结构

```
Pong/
├── PongApp.swift              # 应用入口
├── ContentView.swift          # 主视图（TabView）
├── Models/                    # 数据模型
├── Views/                     # 视图层
├── ViewModels/                # 视图模型
├── Managers/                  # 业务管理器（核心逻辑）
├── Services/                  # 网络服务
└── Assets.xcassets/           # 资源文件
```

---

## 技术亮点

1. **原生网络协议实现**：使用 Darwin BSD Socket API 实现真正的 ICMP Ping 和 Traceroute，无需第三方库
2. **IPv4/IPv6 双栈支持**：所有网络探测功能同时支持 IPv4 和 IPv6
3. **轻量级**：安装包仅 ~1.8MB，无重型依赖
4. **离线可用**：本地测功能无需网络即可使用（除 IP 归属地查询）
5. **WebView 混合开发**：地图模块使用 ECharts 实现复杂可视化效果
