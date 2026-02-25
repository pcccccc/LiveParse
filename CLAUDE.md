# CLAUDE.md

本文件为 Claude Code 在 LiveParse 仓库中工作时提供指导。

## 项目概述

LiveParse 是一个 Swift Package，负责解析 8 个直播平台的 API（哔哩哔哩、斗鱼、虎牙、抖音、快手、YY、网易CC、SOOP）。当前运行模式为**纯 JS 插件模式**，所有平台解析逻辑均由 JavaScript 插件实现。

## 构建与测试

```bash
swift build
swift test
```

抖音测试需要手动填入 Cookie：编辑 `Tests/LiveParseTests/DouyinTests.swift` 中的 `douyinTestCookie` 常量。

## 架构

### 运行模式

纯 JS 插件模式（`enableJSPlugins = true`，`pluginFallbackToSwiftImplementation = false`）。旧平台 Swift 解析文件（`Douyin.swift` 等）已全部删除。

### 目录结构

```
Sources/LiveParse/
├── Plugin/                              # 插件基础设施
│   ├── JSRuntime.swift                  # JavaScriptCore 运行时封装（DispatchQueue 隔离）
│   ├── LiveParsePluginManager.swift     # 插件加载、解析、调用管理
│   ├── LiveParseLoadedPlugin.swift      # 已加载插件实例（actor）
│   ├── LiveParsePluginManifest.swift    # manifest.json 模型
│   ├── LiveParsePlugins.swift           # 全局共享入口 LiveParsePlugins.shared
│   ├── LiveParsePluginError.swift       # 错误类型与标准错误码
│   ├── LiveParsePluginStorage.swift     # 插件持久化（沙盒目录管理）
│   ├── LiveParsePluginState.swift       # 插件状态模型
│   ├── LiveParsePluginInstaller.swift   # 插件安装
│   ├── LiveParsePluginUpdater.swift     # 插件更新
│   └── LiveParseRemotePluginIndex.swift # 远端索引
├── Danmu/                               # 弹幕 WebSocket 连接与协议解析
│   ├── WebSocketConnection.swift        # WebSocket 客户端（支持 6 个平台弹幕）
│   ├── Bilibili/                        # Protobuf 解析
│   ├── Douyin/                          # Protobuf 解析
│   ├── Douyu/                           # 自定义协议解析
│   ├── Huya/                            # Tars 协议解析
│   ├── CC/                              # 自定义协议解析
│   └── Soop/                            # 文本帧协议解析
├── Resources/                           # JS 插件资源
│   ├── lp_plugin_{平台}_{版本}_manifest.json
│   ├── lp_plugin_{平台}_{版本}_index.js
│   └── webmssdk.js                      # 抖音签名依赖（preloadScript）
├── LiveParse.swift                      # 公共 API 入口、平台名称映射
├── LiveModel.swift                      # 数据模型（LiveModel, LiveQualityModel, LiveState）
├── LiveParseJSPlatformManager.swift     # JS 平台调度层（v1→v2 方法名兼容）
├── LiveParseError+Enhanced.swift        # 增强错误报告
├── BiliBiliCookie.swift                 # Bilibili Cookie 管理
├── NetworkRequestHelper.swift           # HTTP 工具
└── String+Extension.swift               # 字符串扩展
```

### 插件 API（v2 方法名）

每个 JS 插件导出 `globalThis.LiveParsePlugin`，包含以下方法：

| v2 方法名 | v1 方法名（兼容） | 用途 |
|-----------|-------------------|------|
| `getCategories` | `getCategoryList` | 获取分类列表 |
| `getRooms` | `getRoomList` | 获取房间列表 |
| `getPlayback` | `getPlayArgs` | 获取播放地址 |
| `search` | `searchRooms` | 搜索房间 |
| `getRoomDetail` | `getLiveLastestInfo` | 获取房间详情 |
| `getLiveState` | `getLiveState` | 获取直播状态 |
| `resolveShare` | `getRoomInfoFromShareCode` | 解析分享码 |
| `getDanmaku` | `getDanmukuArgs` | 获取弹幕参数 |

### 关键机制

- **preloadScripts**：manifest 中声明预加载脚本，在入口脚本之前执行（如抖音的 `webmssdk.js`）
- **浏览器环境 shim**：JSRuntime 启动时注入 `window`/`document`/`navigator` 全局对象
- **Cookie 流**：
  - 抖音：通过 `setCookie`/`clearCookie` 管理 runtime cookie，API 调用使用匿名 ttwid cookie 避免 444
  - B站：通过 `payload.cookie` 传入（`injectCookieIfNeeded` 自动注入）
  - 其他平台：无需 Cookie
- **Host 桥接**：
  - `Host.http.request(options)` — 网络请求（Promise）
  - `Host.crypto.md5(input)` — MD5 计算
  - `Host.storage.get/set` — 键值存储
  - `Host.time.nowMillis()` — 时间戳
  - `Host.raise(code, msg, ctx)` / `Host.makeError(code, msg, ctx)` — 错误上报
- **签名机制**：抖音使用 ABogus 签名（SM3 + RC4 + bigArray transform），弹幕使用 webmssdk 的 X-Bogus 签名

## 平台要求

- Swift 6.2（swift-tools-version）
- macOS 13+ / iOS 16+ / tvOS 16+

## 依赖

- **Alamofire** — HTTP 网络
- **SwiftyJSON** — JSON 解析
- **Starscream** — WebSocket 客户端
- **SWCompression** — 压缩/解压
- **SwiftProtobuf** — Protobuf（B站/抖音弹幕）
- **GMObjC** — 加密工具
- **JavaScriptCore**（系统框架）— JS 运行时

## 支持的平台

| 平台 | 分类 | 房间 | 播放 | 搜索 | 详情 | 状态 | 分享码 | 弹幕 | 需要 Cookie |
|------|------|------|------|------|------|------|--------|------|-------------|
| 哔哩哔哩 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | 否（超清需要） |
| 斗鱼 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | 否 |
| 虎牙 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | 否 |
| 抖音 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | 是 |
| 快手 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | 否 |
| YY | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | 否 |
| 网易CC | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | 否 |
| SOOP | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | 否（登录待开发） |

## 测试

```bash
# 全量测试
swift test

# 按平台测试
swift test --filter BilibiliTests
swift test --filter DouyinTests     # 需要手动填 Cookie
swift test --filter HuyaTests
swift test --filter DouyuTests
swift test --filter KuaiShouTests
swift test --filter NeteaseCCTests
swift test --filter YYTests

# 插件系统测试
swift test --filter PluginSystemTests
```
