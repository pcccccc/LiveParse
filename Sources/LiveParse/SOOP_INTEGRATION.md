# SOOP 平台集成文档

> SOOP（原 AfreecaTV）- 韩国直播平台
> 集成版本: v0.1.0 (PoC)
> 最后更新: 2026-02-24

---

## 一、功能完成度

| 功能 | 状态 | 说明 |
|------|------|------|
| 分类列表 | ✅ 完成 | 支持一级菜单（分类 + Talk）|
| 房间列表 | ✅ 完成 | 按分类/菜单分页加载 |
| 搜索 | ✅ 完成 | 关键词搜索主播 |
| 播放 | ✅ 完成 | HLS 流，支持多清晰度 |
| 直播状态 | ✅ 完成 | 在线/离线检测 |
| 分享码解析 | ✅ 完成 | 支持 sooplive/afreecatv URL |
| 弹幕 | ✅ 完成 | WebSocket 协议，文本帧 |
| 房间详情 | ✅ 完成 | 主播信息/观看人数 |
| **登录** | ❌ 待开发 | 下一阶段目标 |
| **图片资源** | ❌ 缺失 | 需要添加平台图标 |

---

## 二、文件清单

### LiveParse 包（`/Git_Mini/LiveParse/`）

| 文件 | 用途 |
|------|------|
| `Resources/lp_plugin_soop_0.1.0_manifest.json` | 插件清单 |
| `Resources/lp_plugin_soop_0.1.0_index.js` | JS 插件主实现（~712行）|
| `Danmu/Soop/SoopSocketDataParser.swift` | 弹幕 WebSocket 协议解析器 |
| `Danmu/WebSocketConnection.swift` | WebSocket 连接层（已添加 SOOP 支持）|
| `LiveModel.swift` | LiveType: `soop = "8"` |
| `LiveParse.swift` | 平台名称/描述映射 |
| `LiveParseJSPlatformManager.swift` | JS 插件调度入口 |

### AngelLive 主项目（`/Git/AngelLive/`）

| 文件 | 用途 |
|------|------|
| `Shared/AngelLiveCore/.../ApiManager.swift` | API 路由层，SOOP 转发到 JS 插件 |
| `iOS/.../RoomInfoViewModel.swift` | iOS 播放/弹幕对接 |
| `macOS/.../RoomInfoViewModel.swift` | macOS 播放/弹幕对接 |
| `TV/.../RoomInfoViewModel.swift` | tvOS 播放/弹幕对接 |
| `iOS/.../ContentView.swift` | 平台颜色 `#0078F0`、URL 模板 |
| `iOS/.../CategoryGridViewController.swift` | 引用 `live_card_soop` 图标 |
| `iOS/.../StreamerInfoSheet.swift` | 主播信息页平台标识 |
| `macOS/.../ContentView.swift` | 引用 `mini_live_card_soop` 图标 |
| `macOS/.../PlatformDetailView.swift` | 引用 `mini_live_card_soop` 图标 |
| `macOS/.../CategoryManagementView.swift` | 引用 `mini_live_card_soop` 图标 |

---

## 三、技术细节

### 3.1 API 域名

| 用途 | 域名 |
|------|------|
| 分类/搜索 | `sch.sooplive.co.kr` |
| 播放信息 | `live.sooplive.co.kr` |
| 直播流 | `livestream-manager.sooplive.co.kr` |
| 主播信息 | `st.sooplive.co.kr` |
| 一级菜单 | `live.sooplive.co.kr/api/explore/get_menu_list.php` |

### 3.2 关键请求头

```
Cookie: AbroadChk=OK（海外访问必需）
Accept-Language: zh-CN,zh;q=0.9（返回中文内容）
User-Agent: Chrome 145 macOS
```

### 3.3 分类结构

```
get_menu_list.php 返回两个一级菜单:
├── 分类 (type=category)
│   └── categoryList 接口的平铺分类列表（不做二次分组）
└── Talk (type=admin, menuId=316)
    └── get_contents_list.php?szMenuId=316 获取房间
```

- `getRooms` 通过 id 前缀 `menu_` 路由：有前缀走 `get_contents_list.php`，无前缀走 `categoryContentsList`

### 3.4 播放流程

```
1. player_live_api.php → 获取频道信息（CHANNEL, BJID, CDN 等）
2. getAid → 获取 AID token
3. livestream-manager.sooplive.co.kr → 拼接 m3u8 地址

支持清晰度: original(1080p), hd(720p), sd(540p), ld(360p)
```

### 3.5 弹幕 WebSocket 协议

```
连接地址: wss://chat.sooplive.co.kr:8001/Websocket（从 getDanmaku 返回动态地址）
帧类型: 文本帧（非二进制）

包格式:
  包头: ESC TAB (\x1b\t)
  字段分隔: Form Feed (\x0c)

握手流程:
  1. 发送 CONNECT 包 → \x1b\t000100000600\x0c\x0c\x0c16\x0c
  2. 等待 2 秒
  3. 发送 JOIN 包  → \x1b\t0002{size:06}00\x0c{chatNo}\x0c\x0c\x0c\x0c\x0c
  4. 每 60 秒发送 PING → \x1b\t000000000100\x0c

聊天消息:
  命令 ID: 0005
  fields[1] = 弹幕内容
  fields[2] = 用户 ID
  fields[6] = 用户昵称
```

### 3.6 分享链接格式

支持解析以下格式:
- `https://play.sooplive.co.kr/{bjId}/{broadNo}`
- `https://play.afreecatv.com/{bjId}/{broadNo}`
- `https://bj.sooplive.co.kr/{bjId}`
- 纯 `bjId` 字符串

---

## 四、已知问题 & 待办

### 缺失的图片资源

以下资源在代码中已引用但尚未添加到 Assets.xcassets:

- `live_card_soop` — iOS 平台卡片图标
- `pad_live_card_soop` — iPad 平台卡片图标
- `mini_live_card_soop` — macOS 平台小图标

需要在 `Shared/SharedAssets/Sources/SharedAssets/Resources/Assets.xcassets/` 中添加。

---

## 五、下一阶段：SOOP 登录功能

### 目标

实现 SOOP 平台账号登录，使用户可以：
- 使用 SOOP 账号登录
- 带 Cookie/Session 访问需要认证的 API
- 发送弹幕（当前仅接收）

### 需要调研的问题

1. **登录方式**: SOOP 网页端的登录流程（表单登录 / OAuth / 其他）
2. **Cookie 管理**: 登录后需要持久化哪些 Cookie（`PdboxTicket`、`PdboxSaveTicket` 等）
3. **Session 桥接**: 参考抖音的 Cookie 注入机制，将登录态注入到 JS 插件
4. **Token 刷新**: 登录态过期后的刷新策略
5. **UI 入口**: 在设置页 `PlatformAccountLoginView` 中添加 SOOP 登录入口

### 参考实现

- 抖音登录: `iOS/.../Views/Setting/PlatformAccountLoginView.swift`
- B站登录: `iOS/.../Views/Bilibili/BilibiliLoginViewModel.swift`
- Cookie 注入: LiveParse JS 插件的 `payload.cookie` 机制

### 预计涉及文件

```
新增:
  - iOS/.../Views/Soop/SoopLoginWebView.swift      (WebView 登录页)
  - iOS/.../Views/Soop/SoopLoginViewModel.swift     (登录状态管理)
  - Shared/.../Services/SoopCookieManager.swift     (Cookie 持久化)

修改:
  - iOS/.../Views/Setting/PlatformAccountLoginView.swift  (添加 SOOP 入口)
  - lp_plugin_soop_0.1.0_index.js                        (读取注入的 Cookie)
  - macOS/tvOS 对应的登录页面
```
