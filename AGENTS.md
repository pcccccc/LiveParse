# 仓库贡献指南（Repository Guidelines）

## 项目结构与模块划分
本仓库是 Swift Package：`LiveParse`。

- 核心源码：`Sources/LiveParse/`
- 插件运行时与管理：`Sources/LiveParse/Plugin/`
- 弹幕/WebSocket：`Sources/LiveParse/Danmu/`（Bilibili、Douyin、Douyu、Huya、CC、Soop）
- 内置 JS 插件资源：`Sources/LiveParse/Resources/`
- 测试：`Tests/LiveParseTests/`（自动化）、`Tests/DanmuTests/`（手动场景）
- 设计文档：`Docs/PluginSystem.md`、`Docs/CookieSessionMigrationPlan.md`
- SOOP 集成文档：`Sources/LiveParse/SOOP_INTEGRATION.md`

## 架构现状

**纯 JS 插件模式**（`enableJSPlugins = true`，`pluginFallbackToSwiftImplementation = false`）。

旧平台 Swift 解析文件（`Bilibili.swift`、`Douyin.swift`、`Douyu.swift`、`Huya.swift` 等）已全部删除。
Swift 侧仅保留宿主能力（`Host.http`、`Host.crypto`、`Host.storage`）与弹幕协议解析。

支持 8 个平台：bilibili、douyu、huya、douyin、ks、yy、cc、soop。

## 构建、测试与开发命令
- `swift build`：编译并检查集成是否通过。
- `swift test`：运行全部测试。
- `swift test --filter PluginSystemTests`：验证插件运行时/加载器。
- `swift test --filter BilibiliTests`：按平台定向回归。
- `swift test --filter DouyinTests`：抖音测试（需手动填 Cookie）。

说明：部分平台测试依赖真实上游接口，可能受网络与风控影响。

## 编码规范与命名
- Swift 使用 4 空格缩进，遵循 Swift 5.9 风格。
- 类型/协议/枚举用 `UpperCamelCase`，方法/变量用 `lowerCamelCase`。
- 平台入口方法与 `LiveParseJSPlatformManager` 8 大核心方法保持一致。
- 错误优先使用 `LiveParseError` 及增强错误类型。
- 插件文件命名：
  - `lp_plugin_<pluginId>_<version>_manifest.json`
  - `lp_plugin_<pluginId>_<version>_index.js`

## 插件开发规范

1. 全平台按 8 大方法维护 JS 插件实现（getCategories、getRooms、getPlayback、search、getRoomDetail、getLiveState、resolveShare、getDanmaku）。
2. 禁止新增"平台级 Swift fallback"逻辑。
3. 新增插件时必须提供 manifest.json，声明 pluginId、version、apiVersion、entry。
4. 如需预加载脚本（如签名库），在 manifest 的 `preloadScripts` 中声明。

## 测试与提交流程
- 测试框架：Swift Testing（`import Testing`、`@Test`）。
- 新增/修改插件时，至少覆盖 `PluginSystemTests` + 对应平台测试。
- 提交信息遵循历史约定：`feat:`、`fix:`、`refactor:`（可带 scope，如 `feat(douyin): ...`）。
- 当前仓库默认单人维护：直接 `commit + push` 到 `main`。

## 安全与配置提示
- 禁止提交 Cookie、Token、本地调试敏感数据。
- 分享码/链接输入必须校验与清洗。
- 更新插件 manifest 时，确保 `apiVersion` 与宿主兼容。
