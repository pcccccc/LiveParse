# 仓库贡献指南（Repository Guidelines）

## 项目结构与模块划分
本仓库是 Swift Package：`LiveParse`。

- 核心源码：`Sources/LiveParse/`
- 平台解析（当前仍存在 Swift 实现）：`Bilibili.swift`、`Douyin.swift`、`Douyu.swift`、`Huya.swift`、`KuaiShou.swift`、`NeteaseCC.swift`、`YY.swift`、`YoutubeParse.swift`
- 插件运行时与管理：`Sources/LiveParse/Plugin/`
- 弹幕/WebSocket：`Sources/LiveParse/Danmu/`
- 内置 JS 插件资源：`Sources/LiveParse/Resources/`
- 测试：`Tests/LiveParseTests/`（自动化）、`Tests/DanmuTests/`（手动场景）
- 插件设计文档：`Docs/PluginSystem.md`

## 构建、测试与开发命令
- `swift build`：编译并检查集成是否通过。
- `swift test`：运行全部测试。
- `swift test --filter PluginSystemTests`：验证插件运行时/加载器。
- `swift test --filter HuyaTests`：按平台定向回归。

说明：部分平台测试依赖真实上游接口，可能受网络与风控影响。

## 编码规范与命名
- Swift 使用 4 空格缩进，遵循 Swift 5.9 风格。
- 类型/协议/枚举用 `UpperCamelCase`，方法/变量用 `lowerCamelCase`。
- 平台入口方法与 `LiveParse` 协议保持一致（8 大核心方法）。
- 错误优先使用 `LiveParseError` 及增强错误类型。
- 插件文件命名：
  - `lp_plugin_<pluginId>_<version>_manifest.json`
  - `lp_plugin_<pluginId>_<version>_index.js`

## 平台插件化迁移路径（必须遵守）
目标路径已确定：**所有平台解析完成后，移除 Swift 平台实现，统一使用 JS 插件**。

1. 每个平台先补齐 `LiveParse` 8 大方法的插件实现。
2. Swift 侧先保持“插件优先 + Swift fallback”。
3. 插件稳定后切到“仅插件”模式并完成回归。
4. 最后删除对应平台 Swift 解析文件，仅保留宿主能力（`Host.http`、`Host.crypto`、`Host.storage`）。

## 测试与提交流程
- 测试框架：Swift Testing（`import Testing`、`@Test`）。
- 新增/修改插件时，至少覆盖 `PluginSystemTests` + 对应平台测试。
- 提交信息遵循历史约定：`feat:`、`fix:`、`refactor:`（可带 scope，如 `feat(douyin): ...`）。
- PR 需写明：影响平台、影响方法、测试命令与结果、关键请求/响应变化。

## 安全与配置提示
- 禁止提交 Cookie、Token、本地调试敏感数据。
- 分享码/链接输入必须校验与清洗。
- 更新插件 manifest 时，确保 `apiVersion` 与宿主兼容。
