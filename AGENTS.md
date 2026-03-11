# 仓库贡献指南

## 项目定位

本仓库是直播平台 JS 插件仓库，插件运行时已迁移至主工程 AngelLive。

## 目录结构

- JS 插件源码：`Resources/`
- 插件开发文档：`Docs/`
- 发布产物：`Dist/PluginRelease/`
- 构建脚本：`Scripts/`

## 插件开发规范

1. 全平台按 8 大方法维护 JS 插件（getCategories、getRooms、getPlayback、search、getRoomDetail、getLiveState、resolveShare、getDanmaku）。
2. 新增插件时必须提供 manifest.json，声明 pluginId、version、apiVersion、entry。
3. 如需预加载脚本（如签名库），在 manifest 的 `preloadScripts` 中声明。
4. 插件文件命名：`lp_plugin_<pluginId>_<version>_manifest.json` + `lp_plugin_<pluginId>_<version>_index.js`。

## 提交规范

- 提交信息：`feat:`、`fix:`、`refactor:`（可带 scope，如 `feat(douyin): ...`）。
- 禁止提交 Cookie、Token、本地调试敏感数据。

## 发布

```bash
python3 Scripts/build_plugin_release.py
```
