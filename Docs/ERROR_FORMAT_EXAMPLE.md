# 插件错误格式示例

本文档定义 JS 插件标准错误输出样式，便于插件侧与宿主侧统一处理。

## 1) 标准错误载体

插件应通过以下方式抛错（推荐）：

```js
Host.raise("INVALID_ARGS", "roomId is required", { field: "roomId" });
```

底层等价格式：

```text
LP_PLUGIN_ERROR:{"code":"INVALID_ARGS","message":"roomId is required","context":{"field":"roomId"}}
```

宿主会解析为 `LiveParsePluginError.standardized`，最终展示：

```text
JS plugin error [INVALID_ARGS]: roomId is required, context=["field": "roomId"]
```

## 2) 标准错误码

`LiveParsePluginStandardErrorCode` 当前支持：

- `UNKNOWN`
- `INVALID_ARGS`
- `AUTH_REQUIRED`
- `NOT_FOUND`
- `BLOCKED`
- `RATE_LIMITED`
- `NETWORK`
- `TIMEOUT`
- `PARSE`
- `INVALID_RESPONSE`
- `UPSTREAM`

## 3) 实战示例（YY）

### 3.1 上游失败

```text
JS plugin error [UPSTREAM]: YY WebSocket failed: No play URL found, context=["roomId": "1351438696"]
```

### 3.2 运行时环境问题（已修复案例）

```text
JS plugin error [UPSTREAM]: YY WebSocket failed: Can't find variable: setTimeout, context=["payload": "[object Object]", "roomId": "1351438696"]
```

说明：JavaScriptCore 无浏览器 `setTimeout`，插件侧应改为 Promise/Host 异步调用，不应依赖定时器全局函数。

## 4) 插件实现建议

1. 参数校验失败统一抛 `INVALID_ARGS`，并在 `context` 带上缺失字段名。
2. 接口返回空数据抛 `NOT_FOUND` 或 `INVALID_RESPONSE`，避免仅返回空数组。
3. 上游接口报错统一映射 `UPSTREAM`，保留原始 `code/status` 到 `context`。
4. 严禁在 message 中塞超长原文；大对象放 `context` 并控制键值规模。

