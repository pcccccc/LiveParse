# Cookie/Session 改造方向与阶段任务拆解（面向 AngelLive + LiveParse）

更新时间：2026-02-18

## 背景

当前能力以 Bilibili 为主，Cookie 获取、保存、同步、校验已可用，但链路分散在多个组件。  
后续目标是支持“登录后导入平台关注列表”，并逐步扩展到多平台。

## 当前进度同步（2026-02-18）

- 抖音插件已新增 cookie 入口：`setCookie` / `clearCookie`，插件内维护 runtime cookie。
- 抖音插件调用路径已去除 `Douyin.swift` 对 `payload.cookie = ensureCookie(...)` 的注入依赖。
- 现阶段链路改为：宿主会话层写入后调用插件入口同步 cookie，插件侧独立消费该 cookie 发起请求。
- 已完成 iOS 真机构建链路验证（`generic/platform=iOS` + `CODE_SIGNING_ALLOWED=NO`，构建成功）。
- 后续要求：其余涉及登录态的插件也统一采用该方式进行 cookie 交互。

## 核心结论

不建议把“Cookie 获取链路”放在插件内（插件不负责登录抓取）。  
建议采用：

- 宿主管理会话（登录、存储、同步、续期、失效）
- 插件负责业务解析（关注列表分页、字段映射、反爬参数）
- Host.http 基于 `sessionScope` 自动注入鉴权信息

## 目标与非目标

### 目标

- 支持 Bilibili 登录会话稳定接入并导入关注列表。
- 定义可扩展的会话抽象，便于后续接入 Douyin/Douyu/Huya 等。
- 明确安全边界：敏感凭据不在插件层扩散。

### 非目标（本轮）

- 不在本轮实现所有平台登录 UI。
- 不在本轮改造所有历史 API 调用。
- 不在本轮做大规模 UI 重构。

## 目标架构

- `PlatformSessionManager`（宿主，建议 `actor`）
  - 统一管理 `platformId -> session`
  - 负责会话状态：匿名/已登录/过期/失效
- `SessionStore`
  - Keychain：`SESSDATA`、csrf、refreshToken 等敏感字段
  - UserDefaults：低敏缓存（uid、lastSync、source、expireAt）
- `Host.http.request(...)`
  - 新增 `sessionScope`、`authRequired`
  - 自动注入 Cookie/Header
  - 接收 `Set-Cookie` 并回写 SessionStore
- 插件
  - 不负责会话生成/存储
  - 仅通过宿主注入的 cookie（或后续 `sessionScope`）请求业务接口

## 里程碑与阶段任务

## M0 基线盘点（0.5 天）

### 任务

- 梳理现有 Bilibili 会话链路（登录、同步、读取、校验）。
- 盘点所有直接读取 `SimpleLive.Setting.BilibiliCookie` 的调用点。
- 标记“必须登录”的业务接口（尤其关注列表相关）。

### 交付物

- 调用点清单（文件+函数）
- 风险清单（并发写入、过期判断、重复存储）

### 验收标准

- 能明确回答“当前 Cookie 从哪来、谁写入、谁消费、谁同步”。

## M1 会话基础层（1~2 天）

### 任务

- 新建 `PlatformSessionManager` 与 `SessionStore` 抽象。
- 提供统一接口：
  - `getSession(platformId:)`
  - `updateSession(platformId:, data:)`
  - `clearSession(platformId:)`
  - `validateSession(platformId:)`
- 接入 Keychain 存储敏感字段，UserDefaults 仅留低敏元数据。

### 交付物

- 新增会话核心模块代码（含单测）
- Bilibili 会话模型定义（字段规范）

### 验收标准

- 上层不再直接散落读写 Cookie 字符串。
- 会话读写路径唯一且可追踪。

## M2 Bilibili 接入改造（1~2 天）

### 任务

- `BilibiliCookieManager`、`BilibiliCookieSyncService`、登录 ViewModel 改为调用 `PlatformSessionManager`。
- 保持原有 iCloud/Bonjour 同步能力，但底层改为读写统一 Session。
- 清理重复写入逻辑（避免多处 `UserDefaults.standard.set(cookie)`）。

### 交付物

- Bilibili 端到端链路改造 PR
- 兼容迁移逻辑（旧 key -> 新 SessionStore）

### 验收标准

- Bilibili 登录、退出、同步流程行为不变。
- 业务调用不再依赖手工拼 Cookie 字符串。

## M3 Host.http 鉴权注入（1~2 天）

### 当前状态

- 进行中（抖音一期已先落地插件入口注入）

### 任务

- 为宿主请求层增加：
  - `sessionScope: String?`
  - `authRequired: Bool`
- 自动注入会话头（Cookie/UA/Referer/CSRF）。
- 响应中处理 `Set-Cookie` 并回写会话。
- 规范错误码：`authRequired`、`sessionExpired`、`riskControlBlocked`。

### 交付物

- Host.http 新接口与适配代码
- 请求链路单测（注入/回写/失效）
- 抖音插件 `setCookie/clearCookie` 与 runtime cookie 能力（已落地）
- 其余平台插件（至少 `bilibili`、`ks`）同模式改造方案与落地清单

### 验收标准

- 插件侧不再需要 `payload.cookie`/`payload.uid`。
- 鉴权失败可被上层统一识别并引导登录。
- 所有涉及登录态 cookie 的插件都具备统一 cookie 交互入口（`setCookie` / `clearCookie`）。

## M4 Bilibili 关注列表导入（1~1.5 天）

### 任务

- 插件新增 `getFollowingList`（支持分页/游标）。
- 宿主新增“导入关注列表”服务：
  - 拉取 -> 去重 -> 映射到 App 内数据模型 -> 持久化
- 增加导入状态（进行中/成功/部分失败/失败原因）。

### 交付物

- Bilibili 关注导入能力（含 UI 触发入口可选）
- 导入结果日志与失败重试策略

### 验收标准

- 登录后可稳定导入关注列表。
- 同一账号重复导入不会产生重复数据。

## M5 多平台模板化（持续迭代）

### 任务

- 定义平台接入模板：
  - `PlatformSessionProvider`（登录态定义、校验规则）
  - `FollowingImporter`（关注列表 API + 映射）
- 优先级建议：Douyu -> Huya -> Douyin（按登录复杂度与收益排序）。

### 交付物

- 新平台接入模板文档
- 至少 1 个非 Bilibili 平台样例接入

### 验收标准

- 新平台新增时无需复制一套 `*CookieManager/*SyncService`。

## 风险与对策

- 风险：平台风控导致 Cookie 短时失效  
  - 对策：分级错误 + 自动降级 + 引导重新登录
- 风险：同步来源冲突（本地/iCloud/局域网）  
  - 对策：时间戳与来源优先级规则（本地登录 > 手动 > iCloud > 局域网）
- 风险：旧数据迁移不完整  
  - 对策：首次启动迁移 + 回滚开关 + 迁移日志

## 建议任务分配（单人维护可按角色思维执行）

- 会话基础层（M1/M3）：核心架构与网络层
- Bilibili 业务链路（M2/M4）：登录、同步、导入
- 测试与验证：关键路径自动化 + 手动回归
- 文档维护：每个里程碑更新设计与验收记录

## 每阶段测试清单（最小）

- 登录成功后会话持久化正确（重启后可用）
- 退出登录后会话彻底清理
- iCloud/局域网同步后会话可用
- `authRequired` 能触发统一登录引导
- 关注列表导入分页完整、去重正确

## 建议执行顺序

1. M0 基线盘点  
2. M1 会话基础层  
3. M2 Bilibili 改造  
4. M3 Host.http 注入  
5. M4 关注导入  
6. M5 多平台扩展
