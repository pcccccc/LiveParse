# CLAUDE.md

本文件为 Claude Code 在 LiveParse 仓库中工作时提供指导。

## 项目概述

LiveParse 是一个 Swift Package，负责解析 7 个国内直播平台的 API（哔哩哔哩、斗鱼、虎牙、抖音、快手、YY、网易CC）。当前运行模式为**纯 JS 插件模式**。

## 构建与测试

```bash
swift build
swift test
```

抖音测试需要手动填入 Cookie：编辑 `Tests/LiveParseTests/DouyinTests.swift` 中的 `douyinTestCookie` 常量。

## 架构

### 运行模式

纯 JS 插件模式（`enableJSPlugins = true`，`pluginFallbackToSwiftImplementation = false`）。各平台的 Swift 文件（如 `Douyin.swift`）为旧原生实现，将逐步删除。

### 目录结构

```
Sources/LiveParse/
├── Plugin/                          # 插件基础设施
│   ├── JSRuntime.swift              # JavaScriptCore 运行时封装
│   ├── LiveParsePluginManager.swift # 插件加载、解析、调用管理
│   ├── LiveParseLoadedPlugin.swift  # 已加载插件实例（actor）
│   ├── LiveParsePluginManifest.swift# manifest.json 模型
│   ├── LiveParsePlugins.swift       # 全局共享入口 LiveParsePlugins.shared
│   └── ...
├── Resources/                       # JS 插件资源
│   ├── lp_plugin_{平台}_{版本}_manifest.json
│   ├── lp_plugin_{平台}_{版本}_index.js
│   └── webmssdk.js                  # 抖音签名依赖
├── {Platform}.swift                 # 各平台 Swift 原生实现（旧，待删除）
├── LiveParseJSPlatformManager.swift # v1→v2 方法名兼容层
└── LiveModel.swift                  # 公共数据模型
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
- **Cookie 流**：JS 插件通过 `payload.cookie` 或 `_dy_runtime.cookie` 获取；抖音插件中 `_dy_requireCookie()` 强制校验
- **Host 桥接**：JS 通过 `Host.http.request()` 发网络请求，`Host.crypto.md5()` 计算 MD5

## 平台要求

- Swift 6.2（swift-tools-version）
- macOS 13+ / iOS 16+ / tvOS 16+

## 支持的平台

| 平台 | 分类 | 房间 | 播放 | 搜索 | 分享码 | 弹幕 | 需要 Cookie |
|------|------|------|------|------|--------|------|-------------|
| 哔哩哔哩 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | 否 |
| 斗鱼 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | 否 |
| 虎牙 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | 否 |
| 抖音 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | 是 |
| 快手 | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | 否 |
| YY | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | 否 |
| 网易CC | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | 否 |
