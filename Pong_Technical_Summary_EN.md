# Pong (iTango Network Diagnostics) - Technical Overview

## Project Overview

| Item | Description |
|------|-------------|
| Project Name | Pong (iTango Network Diagnostics) |
| Platform | iOS (SwiftUI) |
| Architecture | MVVM + Singleton Manager Pattern |
| Language Support | Chinese / English |
| App Size | ~1.8MB (App Store download size) |
| Minimum iOS Version | iOS 15.0 |

---

## Feature Modules

### Tab 1 - Local Test

| Feature | Technology | Description |
|---------|------------|-------------|
| **Ping** | Native ICMP Socket | IPv4/IPv6 support, configurable packet size, interval, count |
| **Traceroute** | ICMP + TTL Increment | IPv4/IPv6 support, concurrent probing, batch IP geolocation |
| **DNS Query** | Apple dnssd Framework | Supports A/AAAA/CNAME/MX/TXT/NS record types |
| **TCP Port Test** | Network.framework | Single/batch port scan, 3s timeout |
| **UDP Test** | Network.framework | Send data and attempt to receive response |
| **HTTP GET** | URLSession | Returns status code, headers, body, response time |
| **Speed Test** | URLSession | Uses Cloudflare speed test server for latency/download/upload |
| **Device Info** | System APIs | Public IP, device info, network status, hardware info |
| **Quick Diagnosis** | Combined Calls | Enter diagnosis code, batch execute tasks and report results |

### Tab 2 - Cloud Probe

| Feature | Description |
|---------|-------------|
| Probe Selection | Filter public probes by country/ISP/AS number |
| Probe Types | Ping / DNS / TCP / UDP |
| Task Execution | Create task → Poll results (max 5 times, 3s interval) |
| Authentication | HMAC-SHA-512 signature |

### Tab 3 - IP Query

| Feature | Description |
|---------|-------------|
| IP Lookup | IPv4/IPv6 address geolocation query |
| History | Stores up to 10 records, supports deduplication, deletion, quick fill |
| Storage | UserDefaults |

### Tab 4 - Data

| Feature | Description |
|---------|-------------|
| Map Display | WKWebView + ECharts 5.4.3 |
| Map Data | Alibaba Cloud DataV GeoJSON |
| Alert Display | Flying line animation + ripple effect |
| Interaction | Province click to filter alerts |

### Tab 5 - Profile

| Feature | Description |
|---------|-------------|
| User System | Guest login / Phone login / Account login |
| History | View, filter, upload; 14-day auto-expiration |
| Feedback | Submit feedback content and contact info |
| Settings | Language switch, About, Delete account |

---

## Common Services

| Service | Description |
|---------|-------------|
| Network Service | HTTP request wrapper, HMAC signature authentication |
| IP Geolocation | Single/batch IP query, returns country, province, city, ISP |
| Localization | Chinese/English switch, UserDefaults persistence |
| App Update | Auto-check on launch (1-hour interval), supports force update |

---

## Project Structure

```
Pong/
├── PongApp.swift              # App entry point
├── ContentView.swift          # Main view (TabView)
├── Models/                    # Data models
├── Views/                     # View layer
├── ViewModels/                # View models
├── Managers/                  # Business managers (core logic)
├── Services/                  # Network services
└── Assets.xcassets/           # Asset files
```

---

## Technical Highlights

1. **Native Network Protocol Implementation**: Uses Darwin BSD Socket API for real ICMP Ping and Traceroute, no third-party libraries required
2. **IPv4/IPv6 Dual-Stack Support**: All network diagnostic features support both IPv4 and IPv6
3. **Lightweight**: App size only ~1.8MB, no heavy dependencies
4. **Offline Capable**: Local test features work without network (except IP geolocation)
5. **WebView Hybrid Development**: Map module uses ECharts for complex visualization effects
