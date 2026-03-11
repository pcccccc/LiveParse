# LiveParse

## 介绍

直播平台 JS 插件仓库，提供 Bilibili/Douyu/Huya/Douyin/KuaiShou/YY/NeteaseCC/YouTube/SOOP 的 API 解析插件。

插件运行在 JavaScriptCore 中，由宿主 App（[AngelLive](https://github.com/pcccccc/AngelLive)）加载和调用。

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
| YouTube | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| SOOP | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

## 插件架构

```
宿主 App (AngelLive)                    JS 插件 (JavaScriptCore)
┌─────────────────────┐             ┌─────────────────────────┐
│ LiveParsePlugins    │             │ globalThis.LiveParsePlugin │
│   .shared           │ ──调用──→  │   .getCategories()       │
│                     │             │   .getRooms()            │
│ Host.http.request() │ ←──桥接──  │   .getPlayback()         │
│ Host.crypto.md5()   │             │   .search()              │
│ Host.storage.*      │             │   .getRoomDetail()       │
└─────────────────────┘             └─────────────────────────┘
```

## 插件开发

- [插件开发指南](Docs/PluginAuthoringGuide.md)
- [AI 插件开发提示词](Docs/PluginAuthoringAIPrompt.md)
- [插件系统架构](Docs/PluginSystem.md)
- [发布与使用说明](Docs/PluginReleaseUsage.md)

## 参考及引用

[dart_simple_live](https://github.com/xiaoyaocz/dart_simple_live/)

[iceking2nd/real-url](https://github.com/iceking2nd/real-url) `虎牙解析参考`

[wbt5/real-url](https://github.com/wbt5/real-url)

[ihmily/DouyinLiveRecorder](https://github.com/ihmily/DouyinLiveRecorder)

## 声明

本项目的所有功能都是基于互联网上公开的资料开发，无任何破解、逆向工程等行为。

本项目仅用于学习交流编程技术，严禁将本项目用于商业目的。如有任何商业行为，均与本项目无关。

如果本项目存在侵犯您的合法权益的情况，请及时与开发者联系，开发者将会及时删除有关内容。
