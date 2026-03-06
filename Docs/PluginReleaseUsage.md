# LiveParse 动态插件发布与接入指南

本文是「可执行」的操作手册：
- 如何整理插件目录
- 如何打包 9 平台插件
- 如何部署 `plugins.json` 与 zip
- 三端（iOS/macOS/tvOS）如何消费图标字段

---

## 1. 仓库内插件目录（统一规范）

### 1.1 插件代码（内置 + 打包源）

放在：

- `Sources/LiveParse/Resources/lp_plugin_<pluginId>_<version>_manifest.json`
- `Sources/LiveParse/Resources/lp_plugin_<pluginId>_<version>_index.js`

示例：

- `lp_plugin_huya_1.0.0_manifest.json`
- `lp_plugin_huya_1.0.0_index.js`

### 1.2 插件图标（随 zip 发布，不依赖 App 资源）

放在：

- `Sources/LiveParse/Resources/plugin_assets/<pluginId>/`

每个平台固定 7 张图（必须）：

- `live_card_<pluginId>.png`
- `pad_live_card_<pluginId>.png`
- `mini_live_card_<pluginId>.png`
- `tv_<pluginId>_big.png`
- `tv_<pluginId>_small.png`
- `tv_<pluginId>_big_dark.png`
- `tv_<pluginId>_small_dark.png`

> `Scripts/build_plugin_release.py` 默认会强校验这 7 张图（官方 9 平台）。缺失会直接失败，避免线上出现“新增平台还要发 App 补图”的回退场景。

---

## 2. 一键打包

命令：

```bash
python3 Scripts/build_plugin_release.py \
  --url-prefix https://your-vercel-domain.vercel.app/plugins \
  --url-prefix https://github.com/your-org/liveparse-plugins/releases/download/latest
```

输出目录（默认）：

- `Dist/PluginRelease/zips/*.zip`
- `Dist/PluginRelease/plugins.json`
- `Dist/PluginRelease/checksums.txt`

说明：

- `zipURLs` 按顺序回退下载。
- `zipURL` 会自动写入最后一个地址，用于兼容旧客户端。
- `plugins.json` 中图标字段会写成 zip 内路径（`assets/...`）。

---

## 3. 部署建议（你当前方案）

你的目标方案：

- zip 文件：可放 GitHub Releases（或任意静态文件存储）
- 索引接口：放 Vercel（返回 `plugins.json`）

推荐做法：

1. 把 `Dist/PluginRelease/zips/*.zip` 上传到静态存储（可多源）。
2. 将 `Dist/PluginRelease/plugins.json` 作为 Vercel API 返回内容，或静态托管。
3. 在 `plugins.json` 中把 `zipURLs` 顺序设置为：
   - 国内优先源（如果有）
   - GitHub 备用源

---

## 4. 客户端字段使用约定（三端）

`plugins.json` 单个平台常用字段：

- `platform` / `platformName`
- `icon`
- `iosIcon`
- `macosIcon`
- `tvosIcon`
- `tvosBigIcon` / `tvosSmallIcon`
- `tvosBigIconDark` / `tvosSmallIconDark`
- `zipURLs` / `zipURL`
- `sha256`
- `changelog`（可选，字符串数组，用于“更新日志”展示）

三端建议映射：

- iOS 平台卡片：`iosIcon`
- macOS 平台卡片：`macosIcon`
- tvOS 列表卡片：`tvosIcon`（或 `icon`）
- tvOS 平台详情：
  - 浅色：`tvosBigIcon` + `tvosSmallIcon`
  - 深色：`tvosBigIconDark` + `tvosSmallIconDark`

如果字段为空：

- 优先回退到 `icon`
- 再回退到通用占位图（不要再回退到旧平台内置 assets）

---

## 5. 新增平台最小步骤

1. 新增插件代码：manifest + index.js。
2. 新增 `plugin_assets/<pluginId>/` 并放齐 7 张图。
3. 运行打包脚本生成 zip + `plugins.json`。
4. 部署 zip 与索引。
5. 客户端拉取索引后安装并展示。

到这一步为止，不需要发布 App 来补平台图标。

---

## 6. 线上更新流程（宿主侧）

LiveParse 已支持：

- `zipURLs` 多源下载回退
- sha256 校验
- `installAndActivate`（安装 + 冒烟 + `lastGoodVersion` 记录）
- 失败自动清理新版本

调用建议：

1. 拉取远端索引。
2. 对目标平台执行 `installAndActivate`。
3. 成功后切换运行版本；失败保持旧版本。
