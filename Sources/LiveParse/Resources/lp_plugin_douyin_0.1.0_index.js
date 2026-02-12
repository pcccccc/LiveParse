const __lp_dy_ua = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36";

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

function __lp_dy_pickHeaders(payload) {
  const out = {
    "User-Agent": __lp_dy_ua,
    "Referer": "https://live.douyin.com/"
  };
  const cookie = payload && payload.cookie ? __lp_dy_toString(payload.cookie) : "";
  if (cookie) out.Cookie = cookie;
  return out;
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

  const escapedMatch = html.match(/(\{\\"state\\":\{\\"appStore[\s\S]*?\]\\n)/);
  if (escapedMatch && escapedMatch[1]) {
    const normalized = String(escapedMatch[1])
      .replace(/\\"/g, '"')
      .replace(/\\\\/g, "\\")
      .replace(/\]\\n/g, "]");
    try {
      payloadObj = JSON.parse(normalized);
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
    throw new Error("cannot parse douyin state payload from html");
  }

  const state = payloadObj.state || payloadObj;
  const roomStore = (state && state.roomStore) || {};
  const streamStore = (state && state.streamStore) || {};
  const roomInfo = (roomStore && roomStore.roomInfo) || {};
  const room = (roomInfo && roomInfo.room) || {};

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

  const resp = await Host.http.request({
    url: `https://live.douyin.com/webcast/web/partition/detail/room/v2/?${params}`,
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
    return {
      userName: __lp_dy_toString(owner.nickname || ""),
      roomTitle: __lp_dy_toString(room.title || ""),
      roomCover: __lp_dy_firstArrayValue(cover.url_list),
      userHeadImg: __lp_dy_firstArrayValue(avatar.url_list),
      liveType: "2",
      liveState: __lp_dy_statusToLiveState(Number(room.status || 0), true),
      userId: __lp_dy_toString(room.id_str || owner.id_str || ""),
      roomId: __lp_dy_toString(owner.web_rid || ""),
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

  const resp = await Host.http.request({
    url: `https://www.douyin.com/aweme/v1/web/live/search/?${qs}`,
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

  async getCategoryList() {
    return __lp_dy_defaultCategories();
  },

  async getRoomList(payload) {
    const id = __lp_dy_toString(payload && payload.id);
    const parentId = __lp_dy_toString(payload && payload.parentId);
    const page = Number((payload && payload.page) || 1);
    if (!id) throw new Error("id is required");
    return await __lp_dy_getRoomList(id, parentId, page, payload || {});
  },

  async getPlayArgs(payload) {
    const roomId = __lp_dy_toString(payload && payload.roomId);
    if (!roomId) throw new Error("roomId is required");
    const data = await __lp_dy_getRoomDataByHtml(roomId, payload || {});
    return __lp_dy_extractPlayArgs(data, roomId);
  },

  async searchRooms(payload) {
    const keyword = __lp_dy_toString(payload && payload.keyword);
    const page = Number((payload && payload.page) || 1);
    if (!keyword) throw new Error("keyword is required");
    return await __lp_dy_searchRooms(keyword, page, payload || {});
  },

  async getLiveLastestInfo(payload) {
    const roomId = __lp_dy_toString(payload && payload.roomId);
    if (!roomId) throw new Error("roomId is required");
    const data = await __lp_dy_getRoomDataByHtml(roomId, payload || {});
    return __lp_dy_buildLiveModel(data, roomId);
  },

  async getLiveState(payload) {
    const latest = await this.getLiveLastestInfo(payload || {});
    return { liveState: __lp_dy_toString((latest && latest.liveState) || "3") };
  },

  async getRoomInfoFromShareCode(payload) {
    const shareCode = __lp_dy_toString(payload && payload.shareCode);
    if (!shareCode) throw new Error("shareCode is required");
    const roomId = await __lp_dy_resolveRoomIdFromShareCode(shareCode, payload || {});
    return await this.getLiveLastestInfo({ roomId, userId: roomId, cookie: __lp_dy_toString(payload && payload.cookie) });
  },

  async getDanmukuArgs(payload) {
    const roomId = __lp_dy_toString(payload && payload.roomId);
    if (!roomId) throw new Error("roomId is required");

    const live = await this.getLiveLastestInfo(payload || {});
    const finalRoomId = __lp_dy_toString((live && live.userId) || roomId);
    const cookie = __lp_dy_toString(payload && payload.cookie);

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
