# LiveParse 插件系统（JavaScriptCore）设计草案

目标：将各平台解析逻辑以 JS 插件形式解耦，Swift 侧提供统一宿主能力（网络、存储、加密等），并支持热更新、版本锁定、回滚。

## 核心原则

- **稳定 Swift API**：对调用方尽量保持现有 `LiveParse` 对外接口不变。
- **插件只做“逻辑”**：插件负责参数计算、签名、拼装请求、解析响应；网络与存储由 Swift 宿主提供。
- **强版本治理**：插件按 `pluginId + version` 管理，可锁定、可回滚、可灰度。
- **安全默认**：仅通过 `Host` 白名单桥接能力；插件包校验（`sha256`）+（建议）签名校验。

## 目录与存储

### 内置插件（Bundle.module）

SwiftPM 的资源在部分构建场景下可能会被“扁平化”拷贝到 bundle 根目录（子目录结构不一定保留）。

因此内置插件支持两种布局：

**A. 目录布局（理想）**

```
Resources/Plugins/<pluginId>/manifest.json
Resources/Plugins/<pluginId>/<entry>
```

**B. 扁平布局（推荐使用唯一文件名）**

```
Resources/lp_plugin_<pluginId>_<version>_manifest.json
Resources/lp_plugin_<pluginId>_<version>_<entry>.js
```

运行时会优先尝试目录布局；若不存在 `Plugins/` 目录，则回退到扫描 `lp_plugin_*_manifest.json`。

### 热更新插件（沙盒）

建议目录（跨 iOS/macOS/tvOS 通用）：

```
Application Support/LiveParse/plugins/<pluginId>/<version>/*
Application Support/LiveParse/state.json
```

- 每个版本独立目录，便于回滚。
- `state.json` 记录 pinned、lastGood、禁用状态、灰度信息等。

## Manifest 规范（manifest.json）

示例：

```json
{
  "pluginId": "huya",
  "version": "2.3.1",
  "apiVersion": 1,
  "displayName": "Huya",
  "liveTypes": ["1"],
  "entry": "index.js",
  "minHostVersion": "1.0.0"
}
```

字段约定：

- `pluginId`：插件唯一 ID（字符串，建议与平台一致）。
- `version`：SemVer（`MAJOR.MINOR.PATCH`）。
- `apiVersion`：宿主与插件的桥接协议版本（整数）。不兼容直接拒绝加载。
- `displayName`：展示名（可选）。
- `liveTypes`：该插件负责的 `LiveType.rawValue` 列表。
- `entry`：入口 JS 文件名。
- `minHostVersion`：宿主最低版本（可选）。

## 版本选择策略

针对同一 `pluginId` 多版本并存的选择顺序（建议）：

1. 若 `state.json` 中对该 `pluginId` 配置了 `pinnedVersion`：只加载 pinned。
2. 否则优先加载“沙盒已安装且校验通过”的最高版本。
3. 若沙盒不可用或加载失败：回退到 `lastGoodVersion`。
4. 若仍失败：回退到内置（Bundle）版本（若存在）。

> 任何新版本安装后，必须通过“试加载/冒烟调用”（至少执行一次 `ping` 或最常用接口）后才写入 `lastGoodVersion`。

## 远端索引（plugins.json）

远端建议提供一个索引文件用于描述各插件可用版本与下载信息。

示例：

```json
{
  "apiVersion": 1,
  "generatedAt": "2026-02-10T00:00:00Z",
  "plugins": [
    {
      "pluginId": "huya",
      "version": "2.3.1",
      "zipURL": "https://example.com/liveparse/huya/2.3.1.zip",
      "sha256": "<hex>",
      "signature": "<base64>",
      "signingKeyId": "main"
    }
  ]
}
```

字段约定：

- `zipURL`：插件包下载地址（zip）。
- `sha256`：zip 内容的 sha256（hex）。
- `signature/signingKeyId`：可选的签名与 key 标识（强烈建议上线使用）。

## 插件包（zip）格式

zip 解压后应包含：

```
manifest.json
index.js
assets/...
```

安全要求：

- 必须防 Zip Slip：禁止 `..` 与绝对路径。
- 解压后的 `manifest.json` 中 `pluginId/version` 必须与期望一致。

## Swift ↔︎ JS 桥接（Host）

JS 插件入口必须定义：

```js
globalThis.LiveParsePlugin = {
  apiVersion: 1,
  // 示例：可选冒烟
  ping(payload) { return { ok: true }; },
  // 真实接口：getPlayArgs/getRoomList/... 逐步实现
};
```

宿主向 JS 注入：

- `console.log/error`：重定向到 Swift 日志。
- `Host`（白名单能力，逐步加）：
  - `Host.http.request(...) -> Promise`
  - `Host.crypto.*`
  - `Host.storage.get/set`
  - `Host.time.nowMillis()`

## 更新流程（推荐）

1. 下载 `plugins.json`。
2. 对比本地已安装版本与 pinned 状态，决定是否更新。
3. 下载 zip → 校验 sha256 →（可选）校验签名。
4. 解压到临时目录 → 读取 manifest 校验一致性。
5. 移动到 `plugins/<pluginId>/<version>/`。
6. 试加载并冒烟调用成功 → 写入 `lastGoodVersion`。
7. 若失败 → 删除新版本目录并回滚。

## 错误与可观测性

- JS 运行时错误：应携带 stack、行号、插件版本等信息。
- 插件加载事件：安装成功/失败、回滚原因、当前选中版本。

## 当前迁移进度（2026-02-12）

当前仓库已落地“内置插件 + 插件优先调用 + Swift fallback”模式。

### 已完成平台

- `huya`
- `douyu`
- `cc`（NeteaseCC）
- `yy`
- `ks`（KuaiShou）
- `bilibili`
- `douyin`

以上平台均已：
- 提供内置插件资源（`lp_plugin_<id>_<ver>_manifest.json/index.js`）
- 在 Swift 8 大核心方法中接入插件优先逻辑
- 通过 `LiveParseConfig.pluginFallbackToSwiftImplementation` 控制失败回退

### 待完成平台

- `youtube`

### 最终目标（项目既定方向）

1. 全平台完成 JS 插件化（8 大方法）。
2. 回归稳定后切换到“仅插件模式”（关闭 Swift fallback）。
3. 删除平台 Swift 解析实现，仅保留宿主能力：`Host.http`、`Host.crypto`、`Host.storage`（及必要扩展）。
