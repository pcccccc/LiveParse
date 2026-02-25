# LiveParse

## 介绍

解析 Bilibili/Douyu/Huya/Douyin/KuaiShou/YY/NeteaseCC/SOOP 直播相关内容的 Swift Package。

当前默认运行模式：**纯 JS 插件模式**（所有平台 API 解析均通过 JavaScriptCore 插件实现）。

## 功能

获取直播分类、对应分类主播列表、主播信息、直播源地址、模糊搜索、通过分享链接识别主播信息、弹幕连接。

## Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/pcccccc/LiveParse.git", .upToNextMajor(from: "1.2.7"))
]
```

## 使用示例

### 获取分类列表

```swift
import LiveParse

let categories = try await LiveParseJSPlatformManager.getCategoryList(platform: .bilibili)
```

### 获取房间列表

```swift
let rooms = try await LiveParseJSPlatformManager.getRoomList(
    platform: .bilibili,
    id: "2",          // 分类 ID
    parentId: "2",    // 父分类 ID
    page: 1
)
```

### 获取播放地址

```swift
let qualitys = try await LiveParseJSPlatformManager.getPlayArgs(
    platform: .douyu,
    roomId: "9999",
    userId: nil
)
```

### 搜索主播

```swift
let results = try await LiveParseJSPlatformManager.searchRooms(
    platform: .huya,
    keyword: "王者荣耀",
    page: 1
)
```

### 通过分享码获取主播信息

```swift
let liveInfo = try await LiveParseJSPlatformManager.getRoomInfoFromShareCode(
    platform: .douyin,
    shareCode: "https://v.douyin.com/i8rhQQ2t/"
)
```

### 获取弹幕连接参数

```swift
let (args, headers) = try await LiveParseJSPlatformManager.getDanmukuArgs(
    platform: .bilibili,
    roomId: "21452505",
    userId: nil
)
let connection = WebSocketConnection(
    parameters: args,
    headers: headers,
    liveType: .bilibili
)
connection.delegate = self
connection.connect()
```

### 抖音（需要 Cookie）

抖音平台需要先设置 Cookie：

```swift
// 设置 Cookie（通常由宿主 App 的登录流程提供）
_ = try await LiveParsePlugins.shared.call(
    pluginId: "douyin",
    function: "setCookie",
    payload: ["cookie": douyinCookie]
)

// 之后正常调用
let rooms = try await LiveParseJSPlatformManager.searchRooms(
    platform: .douyin,
    keyword: "游戏",
    page: 1
)
```

## 各平台功能概览

| 平台 | 分类列表 | 房间列表 | 播放地址 | 搜索 | 主播详情 | 直播状态 | 分享码解析 | 弹幕 |
| :---: | :------: | :------: | :------: | :--: | :------: | :------: | :--------: | :--: |
| B站直播 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 斗鱼 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 虎牙 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 抖音 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 快手 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| YY | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| 网易CC | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| SOOP | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

## 插件架构

每个平台的 API 解析通过独立的 JS 插件实现，运行在 JavaScriptCore 中：

```
Swift 宿主 (Host)                    JS 插件 (JavaScriptCore)
┌─────────────────────┐             ┌─────────────────────────┐
│ LiveParsePlugins    │             │ globalThis.LiveParsePlugin │
│   .shared           │ ──调用──→  │   .getCategories()       │
│                     │             │   .getRooms()            │
│ Host.http.request() │ ←──桥接──  │   .getPlayback()         │
│ Host.crypto.md5()   │             │   .search()              │
│ Host.storage.*      │             │   .getRoomDetail()       │
└─────────────────────┘             └─────────────────────────┘
```

插件文件位于 `Sources/LiveParse/Resources/`：
- `lp_plugin_{平台}_{版本}_manifest.json` — 插件清单
- `lp_plugin_{平台}_{版本}_index.js` — 插件入口脚本

## 参考及引用

[dart_simple_live](https://github.com/xiaoyaocz/dart_simple_live/)

[iceking2nd/real-url](https://github.com/iceking2nd/real-url) `虎牙解析参考`

[wbt5/real-url](https://github.com/wbt5/real-url)

[ihmily/DouyinLiveRecorder](https://github.com/ihmily/DouyinLiveRecorder)

## 声明

本项目的所有功能都是基于互联网上公开的资料开发，无任何破解、逆向工程等行为。

本项目仅用于学习交流编程技术，严禁将本项目用于商业目的。如有任何商业行为，均与本项目无关。

如果本项目存在侵犯您的合法权益的情况，请及时与开发者联系，开发者将会及时删除有关内容。
