/**
 * LiveParse Plugin Template
 * =========================
 * 使用此模板创建新的直播平台插件。
 *
 * 导出方法命名规范：
 *   getCategories  - 获取分区列表
 *   getRooms       - 获取房间列表
 *   getPlayback    - 获取播放地址
 *   search         - 关键词搜索
 *   getRoomDetail  - 获取房间完整信息
 *   getLiveState   - 查询直播状态
 *   resolveShare   - 解析分享链接/口令
 *   getDanmaku     - 获取弹幕连接参数
 *
 * 私有方法命名规范：
 *   _平台_动词名词    例: _bili_wbiSign, _dy_signDetail
 *
 * 宿主能力 (Host API)：
 *   Host.http.request(options)         - HTTP 请求 (返回 Promise)
 *   Host.crypto.md5(input)             - MD5 哈希
 *   Host.crypto.base64Decode(input)    - Base64 解码（含 URL decode）
 *   Host.raise(code, message, context) - 抛出标准化错误
 *   Host.makeError(code, message, ctx) - 创建标准化错误对象
 *
 * 标准错误码：
 *   INVALID_ARGS / AUTH_REQUIRED / NOT_FOUND / BLOCKED
 *   RATE_LIMITED / NETWORK / TIMEOUT / PARSE
 *   INVALID_RESPONSE / UPSTREAM / UNKNOWN
 */

// ============================================================
// 常用工具函数（按需保留，每个插件自包含，不依赖公共库）
// ============================================================

/** 安全解析 query string → 对象 */
function _tpl_parseQuery(qs) {
  var obj = {};
  if (!qs) return obj;
  String(qs).replace(/^\?/, "").split("&").forEach(function (pair) {
    var idx = pair.indexOf("=");
    if (idx < 0) return;
    var key = decodeURIComponent(pair.slice(0, idx));
    var val = decodeURIComponent(pair.slice(idx + 1));
    obj[key] = val;
  });
  return obj;
}

/** 正则取第一个捕获组 */
function _tpl_firstMatch(str, regex) {
  var m = String(str || "").match(regex);
  return m ? m[1] || "" : "";
}

/** 提取文本中第一个 URL */
function _tpl_firstURL(text) {
  var m = String(text || "").match(/https?:\/\/[^\s"'<>]+/);
  return m ? m[0] : "";
}

/** 校验纯数字 ID */
function _tpl_isNumericId(str) {
  return /^\d+$/.test(String(str || ""));
}

/** 安全 decodeURIComponent */
function _tpl_decodePercent(str) {
  try { return decodeURIComponent(String(str || "")); } catch (e) { return String(str || ""); }
}

/** 对象转 query string */
function _tpl_toQueryString(params) {
  return Object.keys(params || {}).map(function (k) {
    return encodeURIComponent(k) + "=" + encodeURIComponent(String(params[k] ?? ""));
  }).join("&");
}

/** 安全转字符串 */
function _tpl_str(val) {
  if (val === null || val === undefined) return "";
  return String(val);
}

/** 随机字符串 */
function _tpl_randomString(len, charset) {
  charset = charset || "abcdefghijklmnopqrstuvwxyz0123456789";
  var result = "";
  for (var i = 0; i < len; i++) {
    result += charset.charAt(Math.floor(Math.random() * charset.length));
  }
  return result;
}

// ============================================================
// 插件导出
// ============================================================

globalThis.LiveParsePlugin = {
  apiVersion: 1,

  /**
   * 获取分区列表
   * @param {Object} payload - {}
   * @returns {Array<{id: string, name: string, icon?: string, list?: Array}>}
   */
  async getCategories(payload) {
    // TODO: 实现分区列表获取
    Host.raise("UNKNOWN", "getCategories not implemented");
  },

  /**
   * 获取房间列表
   * @param {Object} payload - {id: string, parentId?: string, page: number}
   * @returns {Array<{userName, roomTitle, roomCover, userHeadImg, liveState, userId, roomId, liveWatchedCount?}>}
   */
  async getRooms(payload) {
    // TODO: 实现房间列表获取
    Host.raise("UNKNOWN", "getRooms not implemented");
  },

  /**
   * 获取播放地址
   * @param {Object} payload - {roomId: string, userId?: string}
   * @returns {Array<{cdn: string, qualitys: Array<{roomId, title, qn, url, liveCodeType, liveType, userAgent?: string, headers?: Object}>}>}
   */
  async getPlayback(payload) {
    // TODO: 实现播放地址获取
    Host.raise("UNKNOWN", "getPlayback not implemented");
  },

  /**
   * 关键词搜索
   * @param {Object} payload - {keyword: string, page: number}
   * @returns {Array<{userName, roomTitle, roomCover, userHeadImg, liveState, userId, roomId}>}
   */
  async search(payload) {
    // TODO: 实现搜索
    Host.raise("UNKNOWN", "search not implemented");
  },

  /**
   * 获取房间完整信息
   * @param {Object} payload - {roomId: string, userId?: string}
   * @returns {{userName, roomTitle, roomCover, userHeadImg, liveState, userId, roomId}}
   */
  async getRoomDetail(payload) {
    // TODO: 实现房间详情获取
    Host.raise("UNKNOWN", "getRoomDetail not implemented");
  },

  /**
   * 查询直播状态
   * @param {Object} payload - {roomId: string, userId?: string}
   * @returns {{liveState: "1"|"0"|"2"}} 或 {isLive: boolean}
   */
  async getLiveState(payload) {
    // TODO: 实现直播状态查询
    Host.raise("UNKNOWN", "getLiveState not implemented");
  },

  /**
   * 解析分享链接/口令
   * @param {Object} payload - {shareCode: string}
   * @returns {{userName, roomTitle, roomCover, userHeadImg, liveState, userId, roomId}}
   */
  async resolveShare(payload) {
    // TODO: 实现分享链接解析
    Host.raise("UNKNOWN", "resolveShare not implemented");
  },

  /**
   * 获取弹幕连接参数
   * @param {Object} payload - {roomId: string, userId?: string}
   * @returns {{args: {key: value, ...}, headers?: {key: value, ...}}} 或 null
   */
  async getDanmaku(payload) {
    // 不支持弹幕的平台返回空 args
    return { args: {}, headers: null };
  },
};
