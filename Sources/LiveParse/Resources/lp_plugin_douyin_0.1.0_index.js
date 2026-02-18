const __lp_dy_ua = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36";
const __lp_dy_runtime = {
  cookie: ""
};

function __lp_dy_tryDecodeURIComponent(text) {
  try {
    return decodeURIComponent(String(text || ""));
  } catch (e) {
    return String(text || "");
  }
}

function __lp_dy_toString(v) {
  return v === undefined || v === null ? "" : String(v);
}

function __lp_dy_normalizeCookie(cookie) {
  return __lp_dy_toString(cookie).trim();
}

function __lp_dy_setRuntimeCookie(cookie) {
  __lp_dy_runtime.cookie = __lp_dy_normalizeCookie(cookie);
}

function __lp_dy_getRuntimeCookie(payload) {
  const payloadCookie = __lp_dy_normalizeCookie(payload && payload.cookie);
  if (payloadCookie) {
    __lp_dy_setRuntimeCookie(payloadCookie);
    return payloadCookie;
  }
  return __lp_dy_runtime.cookie;
}

function __lp_dy_withRuntimeCookie(payload) {
  const safePayload = payload && typeof payload === "object" ? Object.assign({}, payload) : {};
  const cookie = __lp_dy_getRuntimeCookie(safePayload);
  if (cookie) safePayload.cookie = cookie;
  return safePayload;
}

function __lp_dy_firstURL(text) {
  const m = String(text || "").match(/https?:\/\/[^\s|]+/);
  if (!m) return "";
  return String(m[0]).replace(/[),，。】]+$/g, "");
}

function __lp_dy_firstMatch(text, re) {
  const m = String(text || "").match(re);
  return m && m[1] ? String(m[1]) : "";
}

function __lp_dy_isNumericId(text) {
  const s = __lp_dy_toString(text).trim();
  return /^\d+$/.test(s);
}

function __lp_dy_firstArrayValue(v) {
  if (Array.isArray(v) && v.length > 0) {
    return __lp_dy_toString(v[0]);
  }
  return "";
}

function __lp_dy_extractFirstJSONObjectText(text) {
  const source = __lp_dy_toString(text);
  let start = -1;
  let depth = 0;
  let inString = false;
  let escaped = false;

  for (let i = 0; i < source.length; i++) {
    const ch = source[i];

    if (start < 0) {
      if (ch === "{") {
        start = i;
        depth = 1;
      }
      continue;
    }

    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (ch === "\\") {
        escaped = true;
      } else if (ch === '"') {
        inString = false;
      }
      continue;
    }

    if (ch === '"') {
      inString = true;
      continue;
    }
    if (ch === "{") {
      depth += 1;
      continue;
    }
    if (ch === "}") {
      depth -= 1;
      if (depth === 0) {
        return source.slice(start, i + 1);
      }
    }
  }

  return "";
}

function __lp_dy_parseEscapedStateFromScript(html) {
  const marker = '\\"state\\":{';
  const markerPos = html.indexOf(marker);
  if (markerPos < 0) return null;

  const scriptStart = html.lastIndexOf("<script", markerPos);
  const scriptTagEnd = scriptStart >= 0 ? html.indexOf(">", scriptStart) : -1;
  const scriptEnd = html.indexOf("</script>", markerPos);

  let scriptText = "";
  if (scriptTagEnd >= 0 && scriptEnd > scriptTagEnd) {
    scriptText = html.slice(scriptTagEnd + 1, scriptEnd);
  } else {
    const start = Math.max(0, markerPos - 128);
    const end = Math.min(html.length, markerPos + 350000);
    scriptText = html.slice(start, end);
  }

  const normalized = __lp_dy_toString(scriptText)
    .replace(/\\"/g, '"')
    .replace(/\\\\/g, "\\")
    .replace(/\\n/g, "");

  const jsonText = __lp_dy_extractFirstJSONObjectText(normalized);
  if (!jsonText) return null;

  try {
    return JSON.parse(jsonText);
  } catch (e) {
    return null;
  }
}

function __lp_dy_pickHeaders(payload) {
  const payloadWithCookie = __lp_dy_withRuntimeCookie(payload || {});
  const out = {
    "User-Agent": __lp_dy_ua,
    "Referer": "https://live.douyin.com/"
  };
  const cookie = payloadWithCookie.cookie ? __lp_dy_toString(payloadWithCookie.cookie) : "";
  if (cookie) out.Cookie = cookie;
  return out;
}

function __lp_dy_signDetail(queryString) {
  const query = __lp_dy_toString(queryString);
  if (!query) throw new Error("queryString is empty");
  if (typeof sign_datail !== "function") {
    throw new Error("sign_datail is not available in douyin plugin");
  }
  return __lp_dy_toString(sign_datail(query, __lp_dy_ua));
}

function __lp_dy_defaultCategories() {
  return [
    {
      id: "101",
      title: "聊天",
      icon: "",
      biz: "",
      subList: [{ id: "101", parentId: "4", title: "聊天", icon: "", biz: "" }]
    },
    {
      id: "102",
      title: "音乐",
      icon: "",
      biz: "",
      subList: [{ id: "102", parentId: "4", title: "音乐", icon: "", biz: "" }]
    },
    {
      id: "103",
      title: "游戏",
      icon: "",
      biz: "",
      subList: [
        { id: "1010045", parentId: "1", title: "王者荣耀", icon: "", biz: "" },
        { id: "1010014", parentId: "1", title: "英雄联盟", icon: "", biz: "" },
        { id: "1010032", parentId: "1", title: "和平精英", icon: "", biz: "" }
      ]
    },
    {
      id: "104",
      title: "娱乐天地",
      icon: "",
      biz: "",
      subList: [{ id: "104", parentId: "4", title: "娱乐天地", icon: "", biz: "" }]
    }
  ];
}

function __lp_dy_statusToLiveState(status, hasStream) {
  const s = Number(status || 0);
  if (s === 2) return hasStream ? "1" : "0";
  if (s === 4) return "0";
  return "3";
}

function __lp_dy_buildLiveModel(roomData, explicitRoomId) {
  const room = (roomData && roomData.room) || {};
  const roomInfo = (roomData && roomData.roomInfo) || {};
  const owner = room.owner || {};
  const anchor = roomInfo.anchor || {};
  const streamUrl = room.stream_url || {};
  const hlsMap = streamUrl.hls_pull_url_map || {};
  const hasStream = !!(((streamUrl.live_core_sdk_data || {}).pull_data || {}).stream_data)
    || !!hlsMap.FULL_HD1 || !!hlsMap.HD1 || !!hlsMap.SD1 || !!hlsMap.SD2;

  const status = Number(room.status || 0);
  const activeOwner = status === 2 ? owner : anchor;
  const cover = room.cover || {};
  const avatar = activeOwner.avatar_thumb || {};
  const roomViewStats = room.room_view_stats || {};

  const userId = __lp_dy_toString(room.id_str || activeOwner.id_str || "");
  const webRid = __lp_dy_toString(activeOwner.web_rid || explicitRoomId || room.id_str || "");

  return {
    userName: __lp_dy_toString(activeOwner.nickname || ""),
    roomTitle: __lp_dy_toString(room.title || ""),
    roomCover: __lp_dy_firstArrayValue(cover.url_list),
    userHeadImg: __lp_dy_firstArrayValue(avatar.url_list),
    liveType: "2",
    liveState: __lp_dy_statusToLiveState(status, hasStream),
    userId,
    roomId: webRid,
    liveWatchedCount: __lp_dy_toString(room.user_count_str || roomViewStats.display_value || "")
  };
}

function __lp_dy_extractPlayDetailsFromStreamData(roomId, streamDataText) {
  const details = [];
  if (!streamDataText) return details;

  let parsed;
  try {
    parsed = JSON.parse(String(streamDataText));
  } catch (e) {
    return details;
  }

  const data = (parsed && parsed.data) || {};
  const qualityMap = {
    origin: "原画",
    uhd: "蓝光",
    hd: "超清",
    sd: "高清",
    ld: "标清",
    md: "标清2",
    audio: "音频"
  };

  Object.keys(data).forEach(function (key) {
    const quality = data[key] || {};
    const main = quality.main || {};
    const title = qualityMap[key] || key;
    if (main.flv) {
      details.push({ roomId: __lp_dy_toString(roomId), title: `${title}_FLV`, qn: 0, url: __lp_dy_toString(main.flv), liveCodeType: "flv", liveType: "2" });
    }
    if (main.hls) {
      details.push({ roomId: __lp_dy_toString(roomId), title: `${title}_HLS`, qn: 0, url: __lp_dy_toString(main.hls), liveCodeType: "m3u8", liveType: "2" });
    }
  });

  return details;
}

function __lp_dy_extractPlayArgs(roomData, roomId) {
  const room = (roomData && roomData.room) || {};
  const streamUrl = room.stream_url || {};
  const hlsMap = streamUrl.hls_pull_url_map || {};

  let qualitys = [];

  const streamData = (((streamUrl.live_core_sdk_data || {}).pull_data || {}).stream_data) || "";
  qualitys = qualitys.concat(__lp_dy_extractPlayDetailsFromStreamData(roomId, streamData));

  if (qualitys.length === 0) {
    if (hlsMap.FULL_HD1) qualitys.push({ roomId: __lp_dy_toString(roomId), title: "超清", qn: 0, url: __lp_dy_toString(hlsMap.FULL_HD1), liveCodeType: "m3u8", liveType: "2" });
    if (hlsMap.HD1) qualitys.push({ roomId: __lp_dy_toString(roomId), title: "高清", qn: 0, url: __lp_dy_toString(hlsMap.HD1), liveCodeType: "m3u8", liveType: "2" });
    if (hlsMap.SD1) qualitys.push({ roomId: __lp_dy_toString(roomId), title: "标清 1", qn: 0, url: __lp_dy_toString(hlsMap.SD1), liveCodeType: "m3u8", liveType: "2" });
    if (hlsMap.SD2) qualitys.push({ roomId: __lp_dy_toString(roomId), title: "标清 2", qn: 0, url: __lp_dy_toString(hlsMap.SD2), liveCodeType: "m3u8", liveType: "2" });
  }

  if (qualitys.length === 0) {
    throw new Error(`empty quality list for roomId=${roomId}`);
  }

  return [{ cdn: "线路 1", qualitys }];
}

async function __lp_dy_getRoomDataByHtml(roomId, payload) {
  const webRid = __lp_dy_toString(roomId).trim();
  if (!webRid) throw new Error("roomId is empty");

  const resp = await Host.http.request({
    url: `https://live.douyin.com/${encodeURIComponent(webRid)}`,
    method: "GET",
    headers: __lp_dy_pickHeaders(payload || {}),
    timeout: 20
  });

  const html = __lp_dy_toString(resp && resp.bodyText);
  if (!html) {
    throw new Error("empty room html");
  }

  let payloadObj = null;

  const escapedMatch = html.match(/(\{\\"state\\":\{[\s\S]*?\]\\n)/);
  if (escapedMatch && escapedMatch[1]) {
    const normalized = String(escapedMatch[1])
      .replace(/\\"/g, '"')
      .replace(/\\\\/g, "\\")
      .replace(/\]\\n/g, "]");
    try {
      const jsonText = __lp_dy_extractFirstJSONObjectText(normalized);
      payloadObj = jsonText ? JSON.parse(jsonText) : null;
    } catch (e) {
      payloadObj = null;
    }
  }

  if (!payloadObj) {
    const renderDataMatch = html.match(/<script[^>]*id="RENDER_DATA"[^>]*>([\s\S]*?)<\/script>/i);
    if (renderDataMatch && renderDataMatch[1]) {
      const renderText = __lp_dy_tryDecodeURIComponent(String(renderDataMatch[1]));
      try {
        payloadObj = JSON.parse(renderText);
      } catch (e) {
        payloadObj = null;
      }
    }
  }

  if (!payloadObj) {
    const initStateMatch = html.match(/window\.__INITIAL_STATE__\s*=\s*(\{[\s\S]*?\})\s*;\s*<\/script>/i);
    if (initStateMatch && initStateMatch[1]) {
      try {
        payloadObj = JSON.parse(initStateMatch[1]);
      } catch (e) {
        payloadObj = null;
      }
    }
  }

  if (!payloadObj) {
    payloadObj = __lp_dy_parseEscapedStateFromScript(html);
  }

  if (!payloadObj) {
    throw new Error("cannot parse douyin state payload from html");
  }

  const state = payloadObj.state || payloadObj;
  const roomStore = (state && state.roomStore) || {};
  const streamStore = (state && state.streamStore) || {};
  const roomInfo = (roomStore && roomStore.roomInfo) || {};
  let room = (roomInfo && roomInfo.room) || {};

  if ((!room || !room.id_str) && roomInfo) {
    const statusRaw = __lp_dy_toString(roomInfo.status || roomStore.liveStatus || "").toLowerCase();
    let status = 0;
    if (statusRaw === "normal" || statusRaw === "2") status = 2;
    else if (statusRaw === "end" || statusRaw === "close" || statusRaw === "4") status = 4;

    room = {
      id_str: __lp_dy_toString(roomInfo.roomId || roomInfo.web_rid || roomId),
      status,
      title: __lp_dy_toString(roomInfo.title || ""),
      owner: roomInfo.anchor || {},
      cover: roomInfo.cover || {},
      room_view_stats: roomInfo.room_view_stats || {},
      stream_url: roomInfo.web_stream_url || {}
    };
  }

  if (!room || !room.id_str) {
    throw new Error("room info missing from html payload");
  }

  return { room, roomInfo, roomStore, streamStore, state };
}

async function __lp_dy_getRoomList(id, parentId, page, payload) {
  const params = [
    "aid=6383",
    "app_name=douyin_web",
    "live_id=1",
    "device_platform=web",
    "language=zh-CN",
    "enter_from=link_share",
    "cookie_enabled=true",
    "screen_width=1980",
    "screen_height=1080",
    "browser_language=zh-CN",
    "browser_platform=Win32",
    "browser_name=Edge",
    "browser_version=141.0.0.0",
    "browser_online=true",
    "count=15",
    `offset=${encodeURIComponent(String((Number(page || 1) - 1) * 15))}`,
    `partition=${encodeURIComponent(String(id || ""))}`,
    `partition_type=${encodeURIComponent(String(parentId || ""))}`,
    "req_from=2"
  ].join("&");

  const aBogus = __lp_dy_signDetail(params);
  const requestURL = `https://live.douyin.com/webcast/web/partition/detail/room/v2/?${params}&a_bogus=${encodeURIComponent(aBogus)}`;

  const resp = await Host.http.request({
    url: requestURL,
    method: "GET",
    headers: __lp_dy_pickHeaders(payload || {}),
    timeout: 20
  });

  const obj = JSON.parse(__lp_dy_toString(resp && resp.bodyText) || "{}");
  const list = (((obj || {}).data || {}).data) || [];
  if (!Array.isArray(list) || list.length === 0) {
    throw new Error("douyin room list empty or blocked");
  }

  return list.map(function (item) {
    const room = item.room || {};
    const owner = room.owner || item.owner || {};
    const avatar = owner.avatar_thumb || {};
    const cover = room.cover || {};
    const webRid = __lp_dy_toString(owner.web_rid || room.id_str || owner.id_str || "");
    return {
      userName: __lp_dy_toString(owner.nickname || ""),
      roomTitle: __lp_dy_toString(room.title || ""),
      roomCover: __lp_dy_firstArrayValue(cover.url_list),
      userHeadImg: __lp_dy_firstArrayValue(avatar.url_list),
      liveType: "2",
      liveState: __lp_dy_statusToLiveState(Number(room.status || 0), true),
      userId: __lp_dy_toString(room.id_str || owner.id_str || ""),
      roomId: webRid,
      liveWatchedCount: __lp_dy_toString(room.user_count_str || "")
    };
  });
}

async function __lp_dy_searchRooms(keyword, page, payload) {
  const qs = [
    "device_platform=webapp",
    "aid=6383",
    "channel=channel_pc_web",
    "search_channel=aweme_live",
    `keyword=${encodeURIComponent(String(keyword || ""))}`,
    "search_source=switch_tab",
    "query_correct_type=1",
    "is_filter_search=0",
    "from_group_id=",
    `offset=${encodeURIComponent(String((Number(page || 1) - 1) * 10))}`,
    "count=10"
  ].join("&");

  const aBogus = __lp_dy_signDetail(qs);
  const requestURL = `https://www.douyin.com/aweme/v1/web/live/search/?${qs}&a_bogus=${encodeURIComponent(aBogus)}`;

  const resp = await Host.http.request({
    url: requestURL,
    method: "GET",
    headers: __lp_dy_pickHeaders(payload || {}),
    timeout: 20
  });

  const obj = JSON.parse(__lp_dy_toString(resp && resp.bodyText) || "{}");
  const list = (obj && obj.data) || [];
  if (!Array.isArray(list)) {
    throw new Error("douyin search response invalid");
  }

  const out = [];
  for (const item of list) {
    const rawText = __lp_dy_toString((((item || {}).lives || {}).rawdata) || "");
    if (!rawText) continue;
    try {
      const raw = JSON.parse(rawText);
      const owner = raw.owner || {};
      out.push({
        userName: __lp_dy_toString(owner.nickname || ""),
        roomTitle: __lp_dy_toString(raw.title || ""),
        roomCover: __lp_dy_firstArrayValue(((raw.cover || {}).url_list)),
        userHeadImg: __lp_dy_firstArrayValue(((owner.avatar_thumb || {}).url_list)),
        liveType: "2",
        liveState: "",
        userId: __lp_dy_toString(raw.id_str || ""),
        roomId: __lp_dy_toString(owner.web_rid || ""),
        liveWatchedCount: __lp_dy_toString(raw.user_count || "")
      });
    } catch (e) {
    }
  }

  if (out.length === 0) {
    throw new Error("douyin search empty or blocked");
  }

  return out;
}

async function __lp_dy_resolveRoomIdFromShareCode(shareCode, payload) {
  const text = __lp_dy_toString(shareCode).trim();
  if (!text) throw new Error("shareCode is empty");
  if (__lp_dy_isNumericId(text)) return text;

  let roomId = __lp_dy_firstMatch(text, /live\.douyin\.com\/(\d+)/);
  if (__lp_dy_isNumericId(roomId)) return roomId;

  roomId = __lp_dy_firstMatch(text, /douyin\/webcast\/reflow\/(\d+)/);
  if (__lp_dy_isNumericId(roomId)) return roomId;

  const shortURL = __lp_dy_firstURL(text) || (text.startsWith("http") ? text : "");
  if (shortURL) {
    const resp = await Host.http.request({
      url: shortURL,
      method: "GET",
      headers: __lp_dy_pickHeaders(payload || {}),
      timeout: 20
    });

    const finalURL = __lp_dy_toString((resp && resp.url) || shortURL);
    roomId = __lp_dy_firstMatch(finalURL, /live\.douyin\.com\/(\d+)/);
    if (__lp_dy_isNumericId(roomId)) return roomId;

    roomId = __lp_dy_firstMatch(finalURL, /douyin\/webcast\/reflow\/(\d+)/);
    if (__lp_dy_isNumericId(roomId)) return roomId;

    const html = __lp_dy_toString(resp && resp.bodyText);
    roomId = __lp_dy_firstMatch(html, /live\.douyin\.com\/(\d+)/);
    if (__lp_dy_isNumericId(roomId)) return roomId;
  }

  throw new Error(`cannot resolve douyin roomId from shareCode: ${shareCode}`);
}

globalThis.LiveParsePlugin = {
  apiVersion: 1,

  async setCookie(payload) {
    const cookie = __lp_dy_normalizeCookie(payload && payload.cookie);
    __lp_dy_setRuntimeCookie(cookie);
    return { ok: true, hasCookie: cookie.length > 0 };
  },

  async clearCookie() {
    __lp_dy_setRuntimeCookie("");
    return { ok: true, hasCookie: false };
  },

  async getCategoryList() {
    return __lp_dy_defaultCategories();
  },

  async getRoomList(payload) {
    const runtimePayload = __lp_dy_withRuntimeCookie(payload || {});
    const id = __lp_dy_toString(runtimePayload.id);
    const parentId = __lp_dy_toString(runtimePayload.parentId);
    const page = Number(runtimePayload.page || 1);
    if (!id) throw new Error("id is required");
    return await __lp_dy_getRoomList(id, parentId, page, runtimePayload);
  },

  async getPlayArgs(payload) {
    const runtimePayload = __lp_dy_withRuntimeCookie(payload || {});
    const roomId = __lp_dy_toString(runtimePayload.roomId);
    if (!roomId) throw new Error("roomId is required");
    const data = await __lp_dy_getRoomDataByHtml(roomId, runtimePayload);
    return __lp_dy_extractPlayArgs(data, roomId);
  },

  async searchRooms(payload) {
    const runtimePayload = __lp_dy_withRuntimeCookie(payload || {});
    const keyword = __lp_dy_toString(runtimePayload.keyword);
    const page = Number(runtimePayload.page || 1);
    if (!keyword) throw new Error("keyword is required");
    return await __lp_dy_searchRooms(keyword, page, runtimePayload);
  },

  async getLiveLastestInfo(payload) {
    const runtimePayload = __lp_dy_withRuntimeCookie(payload || {});
    const roomId = __lp_dy_toString(runtimePayload.roomId);
    if (!roomId) throw new Error("roomId is required");
    const data = await __lp_dy_getRoomDataByHtml(roomId, runtimePayload);
    return __lp_dy_buildLiveModel(data, roomId);
  },

  async getLiveState(payload) {
    const latest = await this.getLiveLastestInfo(payload || {});
    return { liveState: __lp_dy_toString((latest && latest.liveState) || "3") };
  },

  async getRoomInfoFromShareCode(payload) {
    const runtimePayload = __lp_dy_withRuntimeCookie(payload || {});
    const shareCode = __lp_dy_toString(runtimePayload.shareCode);
    if (!shareCode) throw new Error("shareCode is required");
    const roomId = await __lp_dy_resolveRoomIdFromShareCode(shareCode, runtimePayload);
    return await this.getLiveLastestInfo({ roomId, userId: roomId, cookie: runtimePayload.cookie });
  },

  async getDanmukuArgs(payload) {
    const runtimePayload = __lp_dy_withRuntimeCookie(payload || {});
    const roomId = __lp_dy_toString(runtimePayload.roomId);
    if (!roomId) throw new Error("roomId is required");

    const live = await this.getLiveLastestInfo(runtimePayload);
    const finalRoomId = __lp_dy_toString((live && live.userId) || roomId);
    const cookie = __lp_dy_toString(runtimePayload.cookie);

    return {
      args: {
        room_id: finalRoomId,
        aid: "6383",
        live_id: "1",
        did_rule: "3",
        identity: "audience",
        device_platform: "web"
      },
      headers: cookie ? { cookie, "User-Agent": __lp_dy_ua } : null
    };
  }
};


// ---- a_bogus pure JS implementation (from public reference) ----
// All the content in this article is only for learning and communication use, not for any other purpose, strictly prohibited for commercial use and illegal use, otherwise all the consequences are irrelevant to the author!
function rc4_encrypt(plaintext, key) {
    var s = [];
    for (var i = 0; i < 256; i++) {
        s[i] = i;
    }
    var j = 0;
    for (var i = 0; i < 256; i++) {
        j = (j + s[i] + key.charCodeAt(i % key.length)) % 256;
        var temp = s[i];
        s[i] = s[j];
        s[j] = temp;
    }

    var i = 0;
    var j = 0;
    var cipher = [];
    for (var k = 0; k < plaintext.length; k++) {
        i = (i + 1) % 256;
        j = (j + s[i]) % 256;
        var temp = s[i];
        s[i] = s[j];
        s[j] = temp;
        var t = (s[i] + s[j]) % 256;
        cipher.push(String.fromCharCode(s[t] ^ plaintext.charCodeAt(k)));
    }
    return cipher.join('');
}

function le(e, r) {
    return (e << (r %= 32) | e >>> 32 - r) >>> 0
}

function de(e) {
    return 0 <= e && e < 16 ? 2043430169 : 16 <= e && e < 64 ? 2055708042 : void console['error']("invalid j for constant Tj")
}

function pe(e, r, t, n) {
    return 0 <= e && e < 16 ? (r ^ t ^ n) >>> 0 : 16 <= e && e < 64 ? (r & t | r & n | t & n) >>> 0 : (console['error']('invalid j for bool function FF'),
        0)
}

function he(e, r, t, n) {
    return 0 <= e && e < 16 ? (r ^ t ^ n) >>> 0 : 16 <= e && e < 64 ? (r & t | ~r & n) >>> 0 : (console['error']('invalid j for bool function GG'),
        0)
}

function reset() {
    this.reg[0] = 1937774191,
        this.reg[1] = 1226093241,
        this.reg[2] = 388252375,
        this.reg[3] = 3666478592,
        this.reg[4] = 2842636476,
        this.reg[5] = 372324522,
        this.reg[6] = 3817729613,
        this.reg[7] = 2969243214,
        this["chunk"] = [],
        this["size"] = 0
}

function write(e) {
    var a = "string" == typeof e ? function (e) {
        n = encodeURIComponent(e)['replace'](/%([0-9A-F]{2})/g, (function (e, r) {
                return String['fromCharCode']("0x" + r)
            }
        ))
            , a = new Array(n['length']);
        return Array['prototype']['forEach']['call'](n, (function (e, r) {
                a[r] = e.charCodeAt(0)
            }
        )),
            a
    }(e) : e;
    this.size += a.length;
    var f = 64 - this['chunk']['length'];
    if (a['length'] < f)
        this['chunk'] = this['chunk'].concat(a);
    else
        for (this['chunk'] = this['chunk'].concat(a.slice(0, f)); this['chunk'].length >= 64;)
            this['_compress'](this['chunk']),
                f < a['length'] ? this['chunk'] = a['slice'](f, Math['min'](f + 64, a['length'])) : this['chunk'] = [],
                f += 64
}

function sum(e, t) {
    e && (this['reset'](),
        this['write'](e)),
        this['_fill']();
    for (var f = 0; f < this.chunk['length']; f += 64)
        this._compress(this['chunk']['slice'](f, f + 64));
    var i = null;
    if (t == 'hex') {
        i = "";
        for (f = 0; f < 8; f++)
            i += se(this['reg'][f]['toString'](16), 8, "0")
    } else
        for (i = new Array(32),
                 f = 0; f < 8; f++) {
            var c = this.reg[f];
            i[4 * f + 3] = (255 & c) >>> 0,
                c >>>= 8,
                i[4 * f + 2] = (255 & c) >>> 0,
                c >>>= 8,
                i[4 * f + 1] = (255 & c) >>> 0,
                c >>>= 8,
                i[4 * f] = (255 & c) >>> 0
        }
    return this['reset'](),
        i
}

function _compress(t) {
    if (t < 64)
        console.error("compress error: not enough data");
    else {
        for (var f = function (e) {
            for (var r = new Array(132), t = 0; t < 16; t++)
                r[t] = e[4 * t] << 24,
                    r[t] |= e[4 * t + 1] << 16,
                    r[t] |= e[4 * t + 2] << 8,
                    r[t] |= e[4 * t + 3],
                    r[t] >>>= 0;
            for (var n = 16; n < 68; n++) {
                var a = r[n - 16] ^ r[n - 9] ^ le(r[n - 3], 15);
                a = a ^ le(a, 15) ^ le(a, 23),
                    r[n] = (a ^ le(r[n - 13], 7) ^ r[n - 6]) >>> 0
            }
            for (n = 0; n < 64; n++)
                r[n + 68] = (r[n] ^ r[n + 4]) >>> 0;
            return r
        }(t), i = this['reg'].slice(0), c = 0; c < 64; c++) {
            var o = le(i[0], 12) + i[4] + le(de(c), c)
                , s = ((o = le(o = (4294967295 & o) >>> 0, 7)) ^ le(i[0], 12)) >>> 0
                , u = pe(c, i[0], i[1], i[2]);
            u = (4294967295 & (u = u + i[3] + s + f[c + 68])) >>> 0;
            var b = he(c, i[4], i[5], i[6]);
            b = (4294967295 & (b = b + i[7] + o + f[c])) >>> 0,
                i[3] = i[2],
                i[2] = le(i[1], 9),
                i[1] = i[0],
                i[0] = u,
                i[7] = i[6],
                i[6] = le(i[5], 19),
                i[5] = i[4],
                i[4] = (b ^ le(b, 9) ^ le(b, 17)) >>> 0
        }
        for (var l = 0; l < 8; l++)
            this['reg'][l] = (this['reg'][l] ^ i[l]) >>> 0
    }
}

function _fill() {
    var a = 8 * this['size']
        , f = this['chunk']['push'](128) % 64;
    for (64 - f < 8 && (f -= 64); f < 56; f++)
        this.chunk['push'](0);
    for (var i = 0; i < 4; i++) {
        var c = Math['floor'](a / 4294967296);
        this['chunk'].push(c >>> 8 * (3 - i) & 255)
    }
    for (i = 0; i < 4; i++)
        this['chunk']['push'](a >>> 8 * (3 - i) & 255)

}

function SM3() {
    this.reg = [];
    this.chunk = [];
    this.size = 0;
    this.reset()
}
SM3.prototype.reset = reset;
SM3.prototype.write = write;
SM3.prototype.sum = sum;
SM3.prototype._compress = _compress;
SM3.prototype._fill = _fill;

function result_encrypt(long_str, num = null) {
    let s_obj = {
        "s0": "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=",
        "s1": "Dkdpgh4ZKsQB80/Mfvw36XI1R25+WUAlEi7NLboqYTOPuzmFjJnryx9HVGcaStCe=",
        "s2": "Dkdpgh4ZKsQB80/Mfvw36XI1R25-WUAlEi7NLboqYTOPuzmFjJnryx9HVGcaStCe=",
        "s3": "ckdp1h4ZKsUB80/Mfvw36XIgR25+WQAlEi7NLboqYTOPuzmFjJnryx9HVGDaStCe",
        "s4": "Dkdpgh2ZmsQB80/MfvV36XI1R45-WUAlEixNLwoqYTOPuzKFjJnry79HbGcaStCe"
    }
    let constant = {
        "0": 16515072,
        "1": 258048,
        "2": 4032,
        "str": s_obj[num],
    }

    let result = "";
    let lound = 0;
    let long_int = get_long_int(lound, long_str);
    for (let i = 0; i < long_str.length / 3 * 4; i++) {
        if (Math.floor(i / 4) !== lound) {
            lound += 1;
            long_int = get_long_int(lound, long_str);
        }
        let key = i % 4;
        switch (key) {
            case 0:
                temp_int = (long_int & constant["0"]) >> 18;
                result += constant["str"].charAt(temp_int);
                break;
            case 1:
                temp_int = (long_int & constant["1"]) >> 12;
                result += constant["str"].charAt(temp_int);
                break;
            case 2:
                temp_int = (long_int & constant["2"]) >> 6;
                result += constant["str"].charAt(temp_int);
                break;
            case 3:
                temp_int = long_int & 63;
                result += constant["str"].charAt(temp_int);
                break;
            default:
                break;
        }
    }
    return result;
}

function get_long_int(round, long_str) {
    round = round * 3;
    return (long_str.charCodeAt(round) << 16) | (long_str.charCodeAt(round + 1) << 8) | (long_str.charCodeAt(round + 2));
}

function gener_random(random, option) {
    return [
        (random & 255 & 170) | option[0] & 85, // 163
        (random & 255 & 85) | option[0] & 170, //87
        (random >> 8 & 255 & 170) | option[1] & 85, //37
        (random >> 8 & 255 & 85) | option[1] & 170, //41
    ]
}

//////////////////////////////////////////////
function generate_rc4_bb_str(url_search_params, user_agent, window_env_str, suffix = "cus", Arguments = [0, 1, 14]) {
    let sm3 = new SM3()
    let start_time = Date.now()
    /**
     * 进行3次加密处理
     * 1: url_search_params两次sm3之的结果
     * 2: 对后缀两次sm3之的结果
     * 3: 对ua处理之后的结果
     */
        // url_search_params两次sm3之的结果
    let url_search_params_list = sm3.sum(sm3.sum(url_search_params + suffix))
    // 对后缀两次sm3之的结果
    let cus = sm3.sum(sm3.sum(suffix))
    // 对ua处理之后的结果
    let ua = sm3.sum(result_encrypt(rc4_encrypt(user_agent, String.fromCharCode.apply(null, [0.00390625, 1, Arguments[2]])), "s3"))
    //
    let end_time = Date.now()
    // b
    let b = {
        8: 3, // 固定
        10: end_time, //3次加密结束时间
        15: {
            "aid": 6383,
            "pageId": 6241,
            "boe": false,
            "ddrt": 7,
            "paths": {
                "include": [
                    {},
                    {},
                    {},
                    {},
                    {},
                    {},
                    {}
                ],
                "exclude": []
            },
            "track": {
                "mode": 0,
                "delay": 300,
                "paths": []
            },
            "dump": true,
            "rpU": ""
        },
        16: start_time, //3次加密开始时间
        18: 44, //固定
        19: [1, 0, 1, 5],
    }

    //3次加密开始时间
    b[20] = (b[16] >> 24) & 255
    b[21] = (b[16] >> 16) & 255
    b[22] = (b[16] >> 8) & 255
    b[23] = b[16] & 255
    b[24] = (b[16] / 256 / 256 / 256 / 256) >> 0
    b[25] = (b[16] / 256 / 256 / 256 / 256 / 256) >> 0

    // 参数Arguments [0, 1, 14, ...]
    // let Arguments = [0, 1, 14]
    b[26] = (Arguments[0] >> 24) & 255
    b[27] = (Arguments[0] >> 16) & 255
    b[28] = (Arguments[0] >> 8) & 255
    b[29] = Arguments[0] & 255

    b[30] = (Arguments[1] / 256) & 255
    b[31] = (Arguments[1] % 256) & 255
    b[32] = (Arguments[1] >> 24) & 255
    b[33] = (Arguments[1] >> 16) & 255

    b[34] = (Arguments[2] >> 24) & 255
    b[35] = (Arguments[2] >> 16) & 255
    b[36] = (Arguments[2] >> 8) & 255
    b[37] = Arguments[2] & 255

    // (url_search_params + "cus") 两次sm3之的结果
    /**let url_search_params_list = [
     91, 186,  35,  86, 143, 253,   6,  76,
     34,  21, 167, 148,   7,  42, 192, 219,
     188,  20, 182,  85, 213,  74, 213, 147,
     37, 155,  93, 139,  85, 118, 228, 213
     ]*/
    b[38] = url_search_params_list[21]
    b[39] = url_search_params_list[22]

    // ("cus") 对后缀两次sm3之的结果
    /**
     * let cus = [
     136, 101, 114, 147,  58,  77, 207, 201,
     215, 162, 154,  93, 248,  13, 142, 160,
     105,  73, 215, 241,  83,  58,  51,  43,
     255,  38, 168, 141, 216, 194,  35, 236
     ]*/
    b[40] = cus[21]
    b[41] = cus[22]

    // 对ua处理之后的结果
    /**
     * let ua = [
     129, 190,  70, 186,  86, 196, 199,  53,
     99,  38,  29, 209, 243,  17, 157,  69,
     147, 104,  53,  23, 114, 126,  66, 228,
     135,  30, 168, 185, 109, 156, 251,  88
     ]*/
    b[42] = ua[23]
    b[43] = ua[24]

    //3次加密结束时间
    b[44] = (b[10] >> 24) & 255
    b[45] = (b[10] >> 16) & 255
    b[46] = (b[10] >> 8) & 255
    b[47] = b[10] & 255
    b[48] = b[8]
    b[49] = (b[10] / 256 / 256 / 256 / 256) >> 0
    b[50] = (b[10] / 256 / 256 / 256 / 256 / 256) >> 0


    // object配置项
    b[51] = b[15]['pageId']
    b[52] = (b[15]['pageId'] >> 24) & 255
    b[53] = (b[15]['pageId'] >> 16) & 255
    b[54] = (b[15]['pageId'] >> 8) & 255
    b[55] = b[15]['pageId'] & 255

    b[56] = b[15]['aid']
    b[57] = b[15]['aid'] & 255
    b[58] = (b[15]['aid'] >> 8) & 255
    b[59] = (b[15]['aid'] >> 16) & 255
    b[60] = (b[15]['aid'] >> 24) & 255

    // 中间进行了环境检测
    // 代码索引:  2496 索引值:  17 （索引64关键条件）
    // '1536|747|1536|834|0|30|0|0|1536|834|1536|864|1525|747|24|24|Win32'.charCodeAt()得到65位数组
    /**
     * let window_env_list = [49, 53, 51, 54, 124, 55, 52, 55, 124, 49, 53, 51, 54, 124, 56, 51, 52, 124, 48, 124, 51,
     * 48, 124, 48, 124, 48, 124, 49, 53, 51, 54, 124, 56, 51, 52, 124, 49, 53, 51, 54, 124, 56,
     * 54, 52, 124, 49, 53, 50, 53, 124, 55, 52, 55, 124, 50, 52, 124, 50, 52, 124, 87, 105, 110,
     * 51, 50]
     */
    let window_env_list = [];
    for (let index = 0; index < window_env_str.length; index++) {
        window_env_list.push(window_env_str.charCodeAt(index))
    }
    b[64] = window_env_list.length
    b[65] = b[64] & 255
    b[66] = (b[64] >> 8) & 255

    b[69] = [].length
    b[70] = b[69] & 255
    b[71] = (b[69] >> 8) & 255

    b[72] = b[18] ^ b[20] ^ b[26] ^ b[30] ^ b[38] ^ b[40] ^ b[42] ^ b[21] ^ b[27] ^ b[31] ^ b[35] ^ b[39] ^ b[41] ^ b[43] ^ b[22] ^
        b[28] ^ b[32] ^ b[36] ^ b[23] ^ b[29] ^ b[33] ^ b[37] ^ b[44] ^ b[45] ^ b[46] ^ b[47] ^ b[48] ^ b[49] ^ b[50] ^ b[24] ^
        b[25] ^ b[52] ^ b[53] ^ b[54] ^ b[55] ^ b[57] ^ b[58] ^ b[59] ^ b[60] ^ b[65] ^ b[66] ^ b[70] ^ b[71]
    let bb = [
        b[18], b[20], b[52], b[26], b[30], b[34], b[58], b[38], b[40], b[53], b[42], b[21], b[27], b[54], b[55], b[31],
        b[35], b[57], b[39], b[41], b[43], b[22], b[28], b[32], b[60], b[36], b[23], b[29], b[33], b[37], b[44], b[45],
        b[59], b[46], b[47], b[48], b[49], b[50], b[24], b[25], b[65], b[66], b[70], b[71]
    ]
    bb = bb.concat(window_env_list).concat(b[72])
    return rc4_encrypt(String.fromCharCode.apply(null, bb), String.fromCharCode.apply(null, [121]));
}

function generate_random_str() {
    let random_str_list = []
    random_str_list = random_str_list.concat(gener_random(Math.random() * 10000, [3, 45]))
    random_str_list = random_str_list.concat(gener_random(Math.random() * 10000, [1, 0]))
    random_str_list = random_str_list.concat(gener_random(Math.random() * 10000, [1, 5]))
    return String.fromCharCode.apply(null, random_str_list)
}

function sign(url_search_params, user_agent, arguments) {
    /**
     * url_search_params："device_platform=webapp&aid=6383&channel=channel_pc_web&update_version_code=170400&pc_client_type=1&version_code=170400&version_name=17.4.0&cookie_enabled=true&screen_width=1536&screen_height=864&browser_language=zh-CN&browser_platform=Win32&browser_name=Chrome&browser_version=123.0.0.0&browser_online=true&engine_name=Blink&engine_version=123.0.0.0&os_name=Windows&os_version=10&cpu_core_num=16&device_memory=8&platform=PC&downlink=10&effective_type=4g&round_trip_time=50&webid=7362810250930783783&msToken=VkDUvz1y24CppXSl80iFPr6ez-3FiizcwD7fI1OqBt6IICq9RWG7nCvxKb8IVi55mFd-wnqoNkXGnxHrikQb4PuKob5Q-YhDp5Um215JzlBszkUyiEvR"
     * user_agent："Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36"
     */
    let result_str = generate_random_str() + generate_rc4_bb_str(
        url_search_params,
        user_agent,
        "1536|747|1536|834|0|30|0|0|1536|834|1536|864|1525|747|24|24|Win32",
        "cus",
        arguments
    );
    return result_encrypt(result_str, "s4") + "=";
}

function sign_datail(params, userAgent) {
    return sign(params, userAgent, [0, 1, 14])
}

function sign_reply(params, userAgent) {
    return sign(params, userAgent, [0, 1, 8])
}
