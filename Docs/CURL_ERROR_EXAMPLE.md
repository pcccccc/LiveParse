# CURL 错误复现示例

本文档用于说明 LiveParse 在网络错误时输出的 `curl` 复现命令格式，方便定位线上问题。

## 1) 典型错误日志片段

当请求失败时，`LiveParseError+Enhanced` 会在错误详情中拼接如下区块：

```text
==================== 请求详情 ====================
CURL 命令（可直接复制使用）:
curl -X GET \
  -H 'User-Agent: Mozilla/5.0 ...' \
  -H 'Cookie: [已隐藏]' \
  'https://api.live.bilibili.com/xlive/web-room/v2/index/getRoomPlayInfo?room_id=123456'
==================================================
```

说明：
- `Cookie`、`Authorization` 等敏感头会自动脱敏为 `[已隐藏]`。
- 请求体会通过 `-d '...'` 输出（如 POST）。
- URL 已包含 query 参数，可直接复制执行。

## 2) YY 播放复现示例

YY 播放链路要求使用特定 UA/Headers，可按以下方式验证：

```bash
curl -L 'https://tx-flv-web.yy.com/live/xxx.flv?...' \
  -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36' \
  -H 'Referer: https://www.yy.com/' \
  -H 'Origin: https://www.yy.com'
```

若服务器返回 403/鉴权失败，先确认：
- URL 是否过期（`t=`、`secret=`、`rts_tk=`）。
- UA/Referer/Origin 是否完整透传。
- 是否使用了插件返回的播放参数（而不是客户端硬编码旧值）。

## 3) 推荐排障流程

1. 从错误详情提取 `curl`，在终端直接执行。
2. 若 `curl` 成功而 App 失败，优先检查播放器请求头注入逻辑。
3. 若 `curl` 也失败，优先判断链接过期、Cookie 失效、平台风控或区域限制。
4. 附上完整 `curl`（可保留脱敏头）与 HTTP 状态码，便于快速复现。

