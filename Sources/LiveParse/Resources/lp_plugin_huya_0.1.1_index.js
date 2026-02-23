function __lp_tryDecodePercent(s) {
  try {
    return decodeURIComponent(s);
  } catch (e) {
    return s;
  }
}

function __lp_huya_throw(code, message, context) {
  if (globalThis.Host && typeof Host.raise === "function") {
    Host.raise(code, message, context || {});
  }
  if (globalThis.Host && typeof Host.makeError === "function") {
    throw Host.makeError(code || "UNKNOWN", message || "", context || {});
  }
  throw new Error(`LP_PLUGIN_ERROR:${JSON.stringify({ code: String(code || "UNKNOWN"), message: String(message || ""), context: context || {} })}`);
}

function __lp_urlQueryAllowedEncode(s) {
  // 近似 iOS 的 urlQueryAllowed：尽量保留 + / =
  return encodeURIComponent(s)
    .replace(/%2B/gi, "+")
    .replace(/%2F/gi, "/")
    .replace(/%3D/gi, "=");
}

function __lp_parseQueryString(qs) {
  const out = {};
  if (!qs) return out;
  const parts = String(qs).split("&");
  for (const p of parts) {
    if (!p) continue;
    const idx = p.indexOf("=");
    const k = idx >= 0 ? p.slice(0, idx) : p;
    const v = idx >= 0 ? p.slice(idx + 1) : "";
    out[k] = __lp_tryDecodePercent(v);
  }
  return out;
}

const __lp_huya_wup_base64_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

function __lp_huya_bytesToBase64(bytes) {
  let out = "";
  let i = 0;
  while (i < bytes.length) {
    const b0 = bytes[i++] & 0xff;
    const hasB1 = i < bytes.length;
    const b1 = hasB1 ? (bytes[i++] & 0xff) : 0;
    const hasB2 = i < bytes.length;
    const b2 = hasB2 ? (bytes[i++] & 0xff) : 0;

    out += __lp_huya_wup_base64_chars[b0 >> 2];
    out += __lp_huya_wup_base64_chars[((b0 & 0x03) << 4) | (b1 >> 4)];
    out += hasB1 ? __lp_huya_wup_base64_chars[((b1 & 0x0f) << 2) | (b2 >> 6)] : "=";
    out += hasB2 ? __lp_huya_wup_base64_chars[b2 & 0x3f] : "=";
  }
  return out;
}

function __lp_huya_base64ToBytes(base64) {
  const text = String(base64 || "").replace(/[\r\n\s]/g, "");
  if (!text) return [];

  const map = {};
  for (let i = 0; i < __lp_huya_wup_base64_chars.length; i++) {
    map[__lp_huya_wup_base64_chars[i]] = i;
  }

  const out = [];
  let i = 0;
  while (i < text.length) {
    const c0 = text[i++];
    const c1 = text[i++];
    const c2 = text[i++];
    const c3 = text[i++];

    if (c0 === undefined || c1 === undefined) break;
    const e0 = map[c0];
    const e1 = map[c1];
    if (e0 === undefined || e1 === undefined) break;

    const e2 = c2 === "=" || c2 === undefined ? 0 : map[c2];
    const e3 = c3 === "=" || c3 === undefined ? 0 : map[c3];
    if ((c2 !== "=" && c2 !== undefined && e2 === undefined) || (c3 !== "=" && c3 !== undefined && e3 === undefined)) {
      break;
    }

    const b0 = (e0 << 2) | (e1 >> 4);
    out.push(b0 & 0xff);

    if (c2 !== "=" && c2 !== undefined) {
      const b1 = ((e1 & 0x0f) << 4) | (e2 >> 2);
      out.push(b1 & 0xff);
    }
    if (c3 !== "=" && c3 !== undefined) {
      const b2 = ((e2 & 0x03) << 6) | e3;
      out.push(b2 & 0xff);
    }
  }
  return out;
}

function __LP_HUYA_UserIdEx() {
  this.lUid = 0;
  this.sGuid = "";
  this.sToken = "";
  this.sHuYaUA = "";
  this.sCookie = "";
  this.iTokenType = 0;
  this.sDeviceInfo = "";
  this.sQIMEI = "";
}
__LP_HUYA_UserIdEx.prototype._clone = function () { return new __LP_HUYA_UserIdEx(); };
__LP_HUYA_UserIdEx.prototype._write = function (os, tag, value) { os.writeStruct(tag, value); };
__LP_HUYA_UserIdEx.prototype._read = function (is, tag, def) { return is.readStruct(tag, true, def); };
__LP_HUYA_UserIdEx.prototype.writeTo = function (os) {
  os.writeInt64(0, this.lUid);
  os.writeString(1, this.sGuid);
  os.writeString(2, this.sToken);
  os.writeString(3, this.sHuYaUA);
  os.writeString(4, this.sCookie);
  os.writeInt32(5, this.iTokenType);
  os.writeString(6, this.sDeviceInfo);
  os.writeString(7, this.sQIMEI);
};
__LP_HUYA_UserIdEx.prototype.readFrom = function (is) {
  this.lUid = is.readInt64(0, false, this.lUid);
  this.sGuid = is.readString(1, false, this.sGuid);
  this.sToken = is.readString(2, false, this.sToken);
  this.sHuYaUA = is.readString(3, false, this.sHuYaUA);
  this.sCookie = is.readString(4, false, this.sCookie);
  this.iTokenType = is.readInt32(5, false, this.iTokenType);
  this.sDeviceInfo = is.readString(6, false, this.sDeviceInfo);
  this.sQIMEI = is.readString(7, false, this.sQIMEI);
};

function __LP_HUYA_GetCdnTokenExReq() {
  this.sFlvUrl = "";
  this.sStreamName = "";
  this.iLoopTime = 0;
  this.tId = new __LP_HUYA_UserIdEx();
  this.iAppId = 66;
}
__LP_HUYA_GetCdnTokenExReq.prototype._clone = function () { return new __LP_HUYA_GetCdnTokenExReq(); };
__LP_HUYA_GetCdnTokenExReq.prototype._write = function (os, tag, value) { os.writeStruct(tag, value); };
__LP_HUYA_GetCdnTokenExReq.prototype._read = function (is, tag, def) { return is.readStruct(tag, true, def); };
__LP_HUYA_GetCdnTokenExReq.prototype.writeTo = function (os) {
  os.writeString(0, this.sFlvUrl);
  os.writeString(1, this.sStreamName);
  os.writeInt32(2, this.iLoopTime);
  os.writeStruct(3, this.tId);
  os.writeInt32(4, this.iAppId);
};
__LP_HUYA_GetCdnTokenExReq.prototype.readFrom = function (is) {
  this.sFlvUrl = is.readString(0, false, this.sFlvUrl);
  this.sStreamName = is.readString(1, false, this.sStreamName);
  this.iLoopTime = is.readInt32(2, false, this.iLoopTime);
  this.tId = is.readStruct(3, false, this.tId);
  this.iAppId = is.readInt32(4, false, this.iAppId);
};

function __LP_HUYA_GetCdnTokenExResp() {
  this.sFlvToken = "";
  this.iExpireTime = 0;
}
__LP_HUYA_GetCdnTokenExResp.prototype._clone = function () { return new __LP_HUYA_GetCdnTokenExResp(); };
__LP_HUYA_GetCdnTokenExResp.prototype._write = function (os, tag, value) { os.writeStruct(tag, value); };
__LP_HUYA_GetCdnTokenExResp.prototype._read = function (is, tag, def) { return is.readStruct(tag, true, def); };
__LP_HUYA_GetCdnTokenExResp.prototype.writeTo = function (os) {
  os.writeString(0, this.sFlvToken);
  os.writeInt32(1, this.iExpireTime);
};
__LP_HUYA_GetCdnTokenExResp.prototype.readFrom = function (is) {
  this.sFlvToken = is.readString(0, false, this.sFlvToken);
  this.iExpireTime = is.readInt32(1, false, this.iExpireTime);
};

const __lp_huya_tokenCache = {};

async function __lp_huya_getCdnTokenInfoEx(streamName) {
  const name = String(streamName || "");
  if (!name) return "";

  if ((typeof Taf === "undefined" || typeof HUYA === "undefined") &&
      globalThis.Host && Host.runtime && typeof Host.runtime.loadBuiltinScript === "function") {
    Host.runtime.loadBuiltinScript("huya.js");
  }
  if (typeof Taf === "undefined" || typeof HUYA === "undefined") {
    __lp_huya_throw("INVALID_RESPONSE", "huya.js runtime not available", { streamName: name });
  }

  const now = Date.now();
  const cached = __lp_huya_tokenCache[name];
  if (cached && cached.token && cached.expiresAt > now) {
    return cached.token;
  }

  const req = new __LP_HUYA_GetCdnTokenExReq();
  req.sFlvUrl = "";
  req.sStreamName = name;
  req.iLoopTime = 0;
  req.iAppId = 66;
  req.tId.lUid = 0;
  req.tId.sGuid = "";
  req.tId.sToken = "";
  req.tId.sHuYaUA = "pc_exe&7060000&official";
  req.tId.sCookie = "";
  req.tId.iTokenType = 0;
  req.tId.sDeviceInfo = "";
  req.tId.sQIMEI = "";

  const wup = new Taf.Wup();
  wup.setVersion(3);
  wup.setServant("liveui");
  wup.setFunc("getCdnTokenInfoEx");
  wup.setRequestId(0);
  wup.writeStruct("tReq", req);

  const encoded = wup.encode();
  const encodedBytes = Array.from(new Uint8Array(encoded.getBuffer()));
  const requestBodyBase64 = __lp_huya_bytesToBase64(encodedBytes);

  const response = await Host.http.request({
    url: "http://wup.huya.com",
    method: "POST",
    headers: {
      "Origin": "https://m.huya.com/",
      "Referer": "https://m.huya.com/",
      "User-Agent": "HYSDK(Windows, 30000002)_APP(pc_exe&7060000&official)_SDK(trans&2.32.3.5646)",
      "Content-Type": "application/x-wup"
    },
    bodyBase64: requestBodyBase64,
    timeout: 20
  });

  const responseBase64 = String((response && response.bodyBase64) || "");
  if (!responseBase64) {
    __lp_huya_throw("INVALID_RESPONSE", "empty wup response", { streamName: name });
  }

  const responseBytes = __lp_huya_base64ToBytes(responseBase64);
  if (responseBytes.length === 0) {
    __lp_huya_throw("INVALID_RESPONSE", "invalid wup response bytes", { streamName: name });
  }

  const respWup = new Taf.Wup();
  respWup.decode(new Uint8Array(responseBytes).buffer);
  const code = Number(respWup.readInt32("", 0));
  if (code !== 0) {
    __lp_huya_throw("UPSTREAM", `getCdnTokenInfoEx code=${code}`, { streamName: name, code: String(code) });
  }

  const rsp = respWup.readStruct("tRsp", new __LP_HUYA_GetCdnTokenExResp());
  const token = String((rsp && rsp.sFlvToken) || "");
  if (!token) {
    __lp_huya_throw("INVALID_RESPONSE", "empty sFlvToken", { streamName: name });
  }

  const expire = Number((rsp && rsp.iExpireTime) || 0);
  const safeTTL = expire > 0 ? Math.max(15, Math.min(60, expire - 5)) : 30;
  __lp_huya_tokenCache[name] = {
    token,
    expiresAt: now + safeTTL * 1000
  };
  return token;
}

async function __lp_huya_getCategorySubList(bussType) {
  const resp = await Host.http.request({
    url: `https://live.cdn.huya.com/liveconfig/game/bussLive?bussType=${encodeURIComponent(String(bussType))}`,
    method: "GET",
    timeout: 20
  });
  const obj = JSON.parse(resp.bodyText || "{}");
  const list = (obj && obj.data) || [];
  return list.map(function (item) {
    const gid = item.gid;
    return {
      id: String(gid),
      parentId: "",
      title: String(item.gameFullName || ""),
      icon: `https://huyaimg.msstatic.com/cdnimage/game/${gid}-MS.jpg`,
      biz: ""
    };
  });
}

async function __lp_huya_getRoomList(gameId, page) {
  const qs = [
    "m=LiveList",
    "do=getLiveListByPage",
    "tagAll=0",
    `gameId=${encodeURIComponent(String(gameId))}`,
    `page=${encodeURIComponent(String(page))}`
  ].join("&");
  const url = `https://www.huya.com/cache.php?${qs}`;
  const resp = await Host.http.request({ url, method: "GET", timeout: 20 });
  const obj = JSON.parse(resp.bodyText || "{}");
  const datas = (obj && obj.data && obj.data.datas) || [];
  return datas.map(function (item) {
    return {
      userName: String(item.nick || ""),
      roomTitle: String(item.introduction || ""),
      roomCover: String(item.screenshot || ""),
      userHeadImg: String(item.avatar180 || ""),
      liveType: "1",
      liveState: "",
      userId: String(item.uid || ""),
      roomId: String(item.profileRoom || ""),
      liveWatchedCount: String(item.totalCount || "")
    };
  });
}

async function __lp_huya_searchRooms(keyword, page) {
  const qs = [
    "m=Search",
    "do=getSearchContent",
    `q=${encodeURIComponent(String(keyword))}`,
    "uid=0",
    "v=4",
    "typ=-5",
    "livestate=0",
    "rows=20",
    `start=${encodeURIComponent(String((page - 1) * 20))}`
  ].join("&");
  const url = `https://search.cdn.huya.com/?${qs}`;
  const resp = await Host.http.request({ url, method: "GET", timeout: 20 });
  const obj = JSON.parse(resp.bodyText || "{}");
  const docs = (obj && obj.response && obj.response["3"] && obj.response["3"].docs) || [];
  return docs.map(function (item) {
    return {
      userName: String(item.game_nick || ""),
      roomTitle: String(item.game_introduction || ""),
      roomCover: String(item.game_screenshot || ""),
      userHeadImg: String(item.game_imgUrl || ""),
      liveType: "1",
      liveState: "1",
      userId: String(item.uid || ""),
      roomId: String(item.room_id || ""),
      liveWatchedCount: String(item.game_total_count || "")
    };
  });
}

function __lp_convertUnicodeEscapes(input) {
  return String(input).replace(/\\u([0-9A-Fa-f]{4})/g, function (_, hex) {
    return String.fromCharCode(parseInt(hex, 16));
  });
}

function __lp_removeIncludeFunctionValue(input) {
  // 保持 JSON 可解析：将 function(...) { ... } 替换为 ""。
  return String(input).replace(/function\s*\([^}]*\}/g, "\"\"");
}

function __lp_extractHNFGlobalInit(html) {
  const re = /window\.HNF_GLOBAL_INIT\s*=\s*(.*?)<\/script>/s;
  const m = String(html).match(re);
  if (!m) __lp_huya_throw("PARSE", "HNF_GLOBAL_INIT not found");

  let jsonString = m[1];
  jsonString = jsonString.replace(/\n/g, "").trim();
  jsonString = jsonString.replace(/;\s*$/, "");
  jsonString = __lp_removeIncludeFunctionValue(jsonString);
  jsonString = __lp_convertUnicodeEscapes(jsonString);
  return JSON.parse(jsonString);
}

function __lp_extractTopSid(html) {
  const m = String(html).match(/lChannelId\":(\d+)/);
  return m ? parseInt(m[1], 10) : 0;
}

function __lp_isValidRoomId(roomId) {
  const s = String(roomId || "").trim();
  if (!/^\d+$/.test(s)) return false;
  const n = parseInt(s, 10);
  return Number.isFinite(n) && n > 0;
}

function __lp_extractFirstURL(text) {
  const m = String(text || "").match(/https?:\/\/[^\s|]+/);
  if (!m) return "";
  return String(m[0]).replace(/[),，。】]+$/g, "");
}

function __lp_extractRoomIdFromText(text) {
  const s = String(text || "");
  let m = s.match(/(?:huya\.com\/)(\d+)/);
  if (m && m[1]) return m[1];
  m = s.match(/(?:m\.huya\.com\/)(\d+)/);
  if (m && m[1]) return m[1];
  return "";
}

function __lp_extractRoomIdFromHtml(html) {
  const s = String(html || "");
  let m = s.match(/lProfileRoom\":(\d+)/);
  if (m && m[1]) return m[1];
  m = s.match(/\"lProfileRoom\":(\d+)/);
  if (m && m[1]) return m[1];
  m = s.match(/\"lProfileRoom\":(\d+),/);
  if (m && m[1]) return m[1];
  return "";
}

async function __lp_huya_resolveRoomIdFromShareCode(shareCode) {
  const input = String(shareCode || "").trim();
  if (!input) __lp_huya_throw("INVALID_ARGS", "shareCode is empty", { field: "shareCode" });

  if (__lp_isValidRoomId(input)) return input;

  let roomId = __lp_extractRoomIdFromText(input);
  if (__lp_isValidRoomId(roomId)) return roomId;

  const ua = "Mozilla/5.0 (iPhone; CPU iPhone OS 13_2_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0.3 Mobile/15E148 Safari/604.1 Edg/91.0.4472.69";

  const guessedURL = (input.includes("huya.com") && input.indexOf("://") < 0)
    ? ("https://" + input.replace(/^\/\//, ""))
    : "";
  const url = __lp_extractFirstURL(input) || guessedURL;
  if (url) {
    roomId = __lp_extractRoomIdFromText(url);
    if (__lp_isValidRoomId(roomId)) return roomId;

    const resp = await Host.http.request({
      url,
      method: "GET",
      headers: { "user-agent": ua },
      timeout: 20
    });

    roomId = __lp_extractRoomIdFromText(resp.url || "");
    if (__lp_isValidRoomId(roomId)) return roomId;

    roomId = __lp_extractRoomIdFromHtml(resp.bodyText || "");
    if (__lp_isValidRoomId(roomId)) return roomId;
  }

  __lp_huya_throw("NOT_FOUND", "roomId not found", { shareCode: String(shareCode || "") });
}

function __lp_rotl64(t) {
  // Swift 实现：仅对低 32bit 做循环左移 8 位
  const low = (t >>> 0);
  const rotatedLow = (((low << 8) | (low >>> 24)) >>> 0);
  // 如果 t 超过 32bit，这里保持高位不变（一般 uid 不会超过 32bit）
  const high = Math.floor(t / 0x100000000) * 0x100000000;
  return high + rotatedLow;
}

function __lp_buildAntiCode(streamName, presenterUid, antiCode) {
  const params = __lp_parseQueryString(antiCode);
  if (!params.fm) return antiCode;

  const ctype = params.ctype || "huya_pc_exe";
  const platformId = parseInt(params.t || "0", 10) || 0;
  const isWap = platformId === 103;

  const calcStartTime = Date.now();
  const seqId = presenterUid + calcStartTime;
  const secretHash = Host.crypto.md5(`${seqId}|${ctype}|${platformId}`);

  const convertUid = __lp_rotl64(presenterUid);
  const calcUid = isWap ? presenterUid : convertUid;

  const fmDecoded = Host.crypto.base64Decode(__lp_tryDecodePercent(params.fm));
  const secretPrefix = String(fmDecoded).split("_")[0] || "";
  const wsTime = params.wsTime || "";
  const secretStr = `${secretPrefix}_${calcUid}_${streamName}_${secretHash}_${wsTime}`;
  const wsSecret = Host.crypto.md5(secretStr);

  const wsTimeInt = parseInt(wsTime, 16) || 0;
  const ct = Math.floor((wsTimeInt + Math.random()) * 1000);
  const uuid = Math.floor(((ct % 10000000000) + Math.random()) * 1000) % 0xFFFFFFFF;

  const fmEncoded = __lp_urlQueryAllowedEncode(params.fm);

  const res = [];
  res.push(`wsSecret=${wsSecret}`);
  res.push(`wsTime=${wsTime}`);
  res.push(`seqid=${seqId}`);
  res.push(`ctype=${ctype}`);
  res.push(`ver=1`);
  res.push(`fs=${params.fs || ""}`);
  res.push(`fm=${fmEncoded}`);
  res.push(`t=${platformId}`);

  if (isWap) {
    res.push(`uid=${presenterUid}`);
    res.push(`uuid=${uuid}`);
  } else {
    res.push(`u=${convertUid}`);
  }

  return res.join("&");
}

async function __lp_getPlayURL(stream, presenterUid, bitRate) {
  let antiCodeSource = "";
  try {
    antiCodeSource = await __lp_huya_getCdnTokenInfoEx(stream.sStreamName);
  } catch (_) {
    antiCodeSource = String(stream.sFlvAntiCode || "");
  }
  if (!antiCodeSource) {
    return "";
  }
  const antiCode = __lp_buildAntiCode(stream.sStreamName, presenterUid, antiCodeSource);
  let url = `${stream.sFlvUrl}/${stream.sStreamName}.flv?${antiCode}&codec=264`;
  if (bitRate > 0) {
    url += `&ratio=${bitRate}`;
  }
  return url;
}

async function __lp_getHlsPlayURL(stream, presenterUid, bitRate) {
  const base = String(stream.sHlsUrl || "");
  const streamName = String(stream.sStreamName || "");
  if (!base || !streamName) return "";

  const antiCodeSource = String(stream.sHlsAntiCode || stream.sFlvAntiCode || "");
  if (!antiCodeSource) return "";

  const antiCode = __lp_buildAntiCode(streamName, presenterUid, antiCodeSource);
  const suffix = String(stream.sHlsUrlSuffix || "m3u8");

  let url = `${base}/${streamName}.${suffix}?${antiCode}`;
  if (bitRate > 0) {
    url += `&ratio=${bitRate}`;
  }
  return url;
}

globalThis.LiveParsePlugin = {
  apiVersion: 1,
  async getRoomInfoFromShareCode(payload) {
    const shareCode = String(payload && payload.shareCode ? payload.shareCode : "");
    if (!shareCode) __lp_huya_throw("INVALID_ARGS", "shareCode is required", { field: "shareCode" });
    const roomId = await __lp_huya_resolveRoomIdFromShareCode(shareCode);
    return await this.getLiveLastestInfo({ roomId, userId: null });
  },
  async getCategoryList(payload) {
    const main = [
      { id: "1", title: "网游" },
      { id: "2", title: "单机" },
      { id: "8", title: "娱乐" },
      { id: "3", title: "手游" }
    ];
    const out = [];
    for (const item of main) {
      const subList = await __lp_huya_getCategorySubList(item.id);
      out.push({ id: item.id, title: item.title, icon: "", biz: "", subList });
    }
    return out;
  },

  async getRoomList(payload) {
    const id = String(payload && payload.id ? payload.id : "");
    const page = (payload && payload.page) ? Number(payload.page) : 1;
    if (!id) __lp_huya_throw("INVALID_ARGS", "id is required", { field: "id" });
    return await __lp_huya_getRoomList(id, page);
  },

  async searchRooms(payload) {
    const keyword = String(payload && payload.keyword ? payload.keyword : "");
    const page = (payload && payload.page) ? Number(payload.page) : 1;
    if (!keyword) __lp_huya_throw("INVALID_ARGS", "keyword is required", { field: "keyword" });
    return await __lp_huya_searchRooms(keyword, page);
  },

  async getLiveLastestInfo(payload) {
    const roomId = String(payload && payload.roomId ? payload.roomId : "");
    if (!roomId) __lp_huya_throw("INVALID_ARGS", "roomId is required", { field: "roomId" });

    const ua = "Mozilla/5.0 (iPhone; CPU iPhone OS 13_2_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0.3 Mobile/15E148 Safari/604.1 Edg/91.0.4472.69";
    const resp = await Host.http.request({
      url: `https://m.huya.com/${roomId}`,
      method: "GET",
      headers: { "user-agent": ua },
      timeout: 20
    });
    const html = resp.bodyText || "";
    const data = __lp_extractHNFGlobalInit(html);

    const roomInfo = data && data.roomInfo;
    const eLiveStatus = roomInfo ? roomInfo.eLiveStatus : 0;

    let liveState = "0";
    let liveInfo = roomInfo ? roomInfo.tRecentLive : null;

    if (eLiveStatus === 2) {
      liveState = "1";
      liveInfo = roomInfo.tLiveInfo;
    } else if (eLiveStatus === 3) {
      if (roomInfo && roomInfo.tReplayInfo) {
        liveState = "2";
        liveInfo = roomInfo.tReplayInfo;
      } else {
        liveState = "0";
        liveInfo = roomInfo ? roomInfo.tRecentLive : null;
      }
    } else {
      liveState = "0";
      liveInfo = roomInfo ? roomInfo.tRecentLive : null;
    }

    if (!liveInfo) {
      __lp_huya_throw("INVALID_RESPONSE", "missing liveInfo", { roomId: String(roomId || "") });
    }

    // liveInfo 结构与 Swift 侧 HuyaRoomTLiveInfo 对齐
    return {
      userName: String(liveInfo.sNick || ""),
      roomTitle: String(liveInfo.sIntroduction || ""),
      roomCover: String(liveInfo.sScreenshot || ""),
      userHeadImg: String(liveInfo.sAvatar180 || ""),
      liveType: "1",
      liveState,
      userId: String(liveInfo.lYyid || ""),
      roomId,
      liveWatchedCount: String(liveInfo.lTotalCount || "")
    };
  },

  async getLiveState(payload) {
    const roomId = String(payload && payload.roomId ? payload.roomId : "");
    if (!roomId) __lp_huya_throw("INVALID_ARGS", "roomId is required", { field: "roomId" });

    const info = await this.getLiveLastestInfo({
      roomId,
      userId: payload && payload.userId ? payload.userId : null
    });

    return {
      liveState: String(info && info.liveState ? info.liveState : "3")
    };
  },

  async getDanmukuArgs(payload) {
    const roomId = String(payload && payload.roomId ? payload.roomId : "");
    if (!roomId) __lp_huya_throw("INVALID_ARGS", "roomId is required", { field: "roomId" });

    const ua = "Mozilla/5.0 (iPhone; CPU iPhone OS 13_2_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0.3 Mobile/15E148 Safari/604.1 Edg/91.0.4472.69";
    const resp = await Host.http.request({
      url: `https://m.huya.com/${roomId}`,
      method: "GET",
      headers: { "user-agent": ua },
      timeout: 20
    });
    const html = resp.bodyText || "";

    const data = __lp_extractHNFGlobalInit(html);
    const liveInfo = data && data.roomInfo && data.roomInfo.tLiveInfo;
    const streamInfo = liveInfo && liveInfo.tLiveStreamInfo && liveInfo.tLiveStreamInfo.vStreamInfo;
    const firstStream = streamInfo && streamInfo.value ? streamInfo.value[0] : null;
    if (!liveInfo || !firstStream) {
      __lp_huya_throw("INVALID_RESPONSE", "missing stream info", { roomId: String(roomId || "") });
    }

    return {
      args: {
        lYyid: String(liveInfo.lYyid || ""),
        lChannelId: String(firstStream.lChannelId || ""),
        lSubChannelId: String(firstStream.lSubChannelId || "")
      },
      headers: null
    };
  },
  async getPlayArgs(payload) {
    const roomId = String(payload && payload.roomId ? payload.roomId : "");
    if (!roomId) __lp_huya_throw("INVALID_ARGS", "roomId is required", { field: "roomId" });

    const ua = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_3_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.3.1 Mobile/15E148 Safari/604.1";
    const resp = await Host.http.request({
      url: `https://m.huya.com/${roomId}`,
      method: "GET",
      headers: { "user-agent": ua },
      timeout: 20
    });
    const html = resp.bodyText || "";

    const data = __lp_extractHNFGlobalInit(html);
    const topSid = __lp_extractTopSid(html);
    const results = [];

    const streamInfo = data && data.roomInfo && data.roomInfo.tLiveInfo && data.roomInfo.tLiveInfo.tLiveStreamInfo;
    if (streamInfo && streamInfo.vStreamInfo && streamInfo.vBitRateInfo) {
      const streams = streamInfo.vStreamInfo.value || [];
      const bitRates = streamInfo.vBitRateInfo.value || [];

      for (const s of streams) {
        if (!s || !s.sFlvUrl) continue;
        const qualities = [];
        for (const br of bitRates) {
          if (!br || (br.sDisplayName || "").includes("HDR")) continue;
          const bitRate = br.iBitRate || 0;
          const title = br.sDisplayName || "";

          const flvURL = await __lp_getPlayURL(s, topSid, bitRate);
          if (flvURL) {
            qualities.push({
              roomId,
              title,
              qn: bitRate,
              url: flvURL,
              liveCodeType: "flv",
              liveType: "1"
            });
          }

          const hlsURL = await __lp_getHlsPlayURL(s, topSid, bitRate);
          if (hlsURL) {
            qualities.push({
              roomId,
              title: `${title}_HLS`,
              qn: bitRate,
              url: hlsURL,
              liveCodeType: "m3u8",
              liveType: "1"
            });
          }
        }
        if (qualities.length > 0) {
          results.push({ cdn: `线路 ${s.sCdnType}`, qualitys: qualities });
        }
      }

      if (results.length > 0) {
        return results;
      }
    }

    const replay = data && data.roomInfo && data.roomInfo.tReplayInfo && data.roomInfo.tReplayInfo.tReplayVideoInfo;
    if (replay && replay.sHlsUrl) {
      return [{
        cdn: "回放",
        qualitys: [{
          roomId,
          title: "回放",
          qn: replay.iVideoSyncTime || 0,
          url: replay.sHlsUrl,
          liveCodeType: "m3u8",
          liveType: "1"
        }]
      }];
    }

    __lp_huya_throw("INVALID_RESPONSE", "empty result", { roomId: String(roomId || "") });
  }
};
