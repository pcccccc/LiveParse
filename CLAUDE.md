# CLAUDE.md

本文件为 Claude Code 在 LiveParse 仓库中工作时提供指导。

## 项目概述

LiveParse 是一个直播平台 JS 插件仓库，提供 9 个直播平台（哔哩哔哩、斗鱼、虎牙、抖音、快手、YY、网易CC、SOOP、YouTube）的 API 解析插件。

插件运行时与管理器已迁移至主工程 [AngelLive](https://github.com/pcccccc/AngelLive)（`AngelLiveCore` 模块），本仓库仅维护 JS 插件源码、插件文档和发布产物。

## 目录结构

```
LiveParse/
├── Resources/                           # JS 插件源码
│   ├── lp_plugin_{平台}_{版本}_manifest.json
│   ├── lp_plugin_{平台}_{版本}_index.js
│   ├── plugin_assets/                   # 平台图标资源
│   ├── webmssdk.js                      # 抖音签名依赖（preloadScript）
│   ├── huya.js                          # 虎牙辅助脚本
│   ├── __lp_host_yy.js                  # YY Host 桥接脚本
│   └── douyin_categories.json           # 抖音分类数据
├── Docs/                                # 插件开发文档
│   ├── PluginAuthoringGuide.md          # 插件开发指南
│   ├── PluginAuthoringAIPrompt.md       # AI 插件开发提示词模板
│   ├── PluginSystem.md                  # 插件系统架构
│   ├── PluginReleaseUsage.md            # 发布与使用说明
│   └── CookieSessionMigrationPlan.md    # Cookie 会话迁移方案
├── Dist/PluginRelease/                  # 发布产物
│   ├── plugins.json                     # 插件索引
│   ├── checksums.txt                    # 校验和
│   └── zips/                            # 插件 ZIP 包
├── Scripts/                             # 构建脚本
│   └── build_plugin_release.py          # 插件打包脚本
├── README.md
└── LICENSE
```

## 插件 API（v2 方法名）

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

## 插件开发规范

1. 每个插件必须提供 `manifest.json`，声明 `pluginId`、`version`、`apiVersion`、`entry`。
2. 插件文件命名：`lp_plugin_<pluginId>_<version>_manifest.json` + `lp_plugin_<pluginId>_<version>_index.js`。
3. 如需预加载脚本（如签名库），在 manifest 的 `preloadScripts` 中声明。
4. 详细开发指南见 `Docs/PluginAuthoringGuide.md`。

## Host 桥接 API

宿主通过 JavaScriptCore 向插件暴露以下能力：

- `Host.http.request(options)` — 网络请求（Promise）
- `Host.crypto.md5(input)` — MD5 计算
- `Host.storage.get/set` — 键值存储
- `Host.time.nowMillis()` — 时间戳
- `Host.raise(code, msg, ctx)` / `Host.makeError(code, msg, ctx)` — 错误上报

## 发布流程

```bash
python3 Scripts/build_plugin_release.py
```

产物输出至 `Dist/PluginRelease/`。
