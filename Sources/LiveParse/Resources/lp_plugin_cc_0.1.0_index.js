const _cc_ua = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36";

function _cc_throw(code, message, context) {
  if (globalThis.Host && typeof Host.raise === "function") {
    Host.raise(code, message, context || {});
  }
  if (globalThis.Host && typeof Host.makeError === "function") {
    throw Host.makeError(code || "UNKNOWN", message || "", context || {});
  }
  throw new Error(`LP_PLUGIN_ERROR:${JSON.stringify({ code: String(code || "UNKNOWN"), message: String(message || ""), context: context || {} })}`);
}

function _cc_firstMatch(text, re) {
  const m = String(text || "").match(re);
  if (!m || !m[1]) return "";
  return String(m[1]);
}

function _cc_formatId(input) {
  const m = String(input || "").match(/\d+/);
  return m ? String(m[0]) : String(input || "");
}

function _cc_sanitizeId(value) {
  const s = String(value || "");
  if (s.includes("Optional")) return _cc_formatId(s);
  return s;
}

function _cc_isLive(room) {
  return Number(room && room.cuteid ? room.cuteid : 0) > 0;
}

function _cc_toRoomModel(room, fallbackRoomId) {
  const resolvedRoomId = String((room && room.cuteid) || (room && room.roomid) || fallbackRoomId || 0);
  const resolvedUserId = String((room && room.channel_id) || 0);
  const isLive = _cc_isLive(room);

  return {
    userName: String((room && room.nickname) || ""),
    roomTitle: String((room && room.title) || ""),
    roomCover: String((room && room.poster) || (room && room.adv_img) || ""),
    userHeadImg: String((room && room.portraiturl) || (room && room.purl) || ""),
    liveType: "4",
    liveState: isLive ? "1" : "0",
    userId: resolvedUserId,
    roomId: resolvedRoomId,
    liveWatchedCount: String((room && room.visitor) || 0)
  };
}

async function _cc_getCategorySubList(id) {
  const resp = await Host.http.request({
    url: `https://api.cc.163.com/v1/wapcc/gamecategory?catetype=${encodeURIComponent(String(id))}`,
    method: "GET",
    headers: {
      "User-Agent": _cc_ua
    },
    timeout: 20
  });
  const obj = JSON.parse(resp.bodyText || "{}");
  const list = (((obj || {}).data || {}).category_info || {}).game_list || [];
  return list.map(function (item) {
    return {
      id: String(item.gametype || ""),
      parentId: "",
      title: String(item.name || ""),
      icon: String(item.cover || ""),
      biz: ""
    };
  });
}

async function _cc_fetchRoomDetail(roomId, userId) {
  const sanitized = _cc_sanitizeId(String(userId || roomId || ""));
  const resp = await Host.http.request({
    url: `https://cc.163.com/live/channel/?channelids=${encodeURIComponent(String(sanitized))}`,
    method: "GET",
    headers: {
      "User-Agent": _cc_ua
    },
    timeout: 20
  });
  const obj = JSON.parse(resp.bodyText || "{}");
  const list = (obj && obj.data) || [];
  const room = list && list.length > 0 ? list[0] : null;
  if (!room) _cc_throw("NOT_FOUND", "room not found", { roomId: String(roomId || ""), userId: String(userId || "") });

  const resolvedChannelId = String(room.channel_id || parseInt(String(sanitized), 10) || 0);
  const resolvedRoomId = String(room.cuteid || room.roomid || _cc_formatId(String(roomId || "")) || 0);

  return {
    room,
    channelId: resolvedChannelId,
    roomId: resolvedRoomId
  };
}

function _cc_buildQualityModel(label, resolution, roomId) {
  if (!resolution || !resolution.cdn) return null;

  const cdn = resolution.cdn;
  const candidates = [
    ["ali", cdn.ali],
    ["ks", cdn.ks],
    ["hs", cdn.hs],
    ["hs2", cdn.hs2],
    ["ws", cdn.ws],
    ["dn", cdn.dn],
    ["xy", cdn.xy]
  ];

  const details = [];
  for (const item of candidates) {
    const name = item[0];
    const url = item[1];
    if (!url) continue;
    details.push({
      roomId: String(roomId),
      title: `线路 ${name}`,
      qn: Number(resolution.vbr || 0),
      url: String(url),
      liveCodeType: "flv",
      liveType: "4"
    });
  }

  if (details.length === 0) return null;
  return {
    cdn: String(label),
    qualitys: details
  };
}

async function _cc_getPlayback(roomId, userId) {
  const detail = await _cc_fetchRoomDetail(roomId, userId);
  const room = detail.room;
  const resolution = room && room.quickplay && room.quickplay.resolution;
  if (!resolution) _cc_throw("INVALID_RESPONSE", "missing quickplay resolution", { roomId: String(roomId || "") });

  const mapping = [
    ["原画", resolution.original],
    ["蓝光", resolution.blueray],
    ["超清", resolution.ultra],
    ["高清", resolution.high],
    ["标准", resolution.standard],
    ["标清", resolution.medium]
  ];

  const out = [];
  for (const pair of mapping) {
    const model = _cc_buildQualityModel(pair[0], pair[1], detail.roomId);
    if (model) out.push(model);
  }
  return out;
}

async function _cc_search(keyword, page) {
  const qs = [
    `query=${encodeURIComponent(String(keyword))}`,
    `page=${encodeURIComponent(String(page))}`,
    "size=20"
  ].join("&");

  const resp = await Host.http.request({
    url: `https://cc.163.com/search/anchor?${qs}`,
    method: "GET",
    headers: {
      "User-Agent": _cc_ua
    },
    timeout: 20
  });
  const obj = JSON.parse(resp.bodyText || "{}");
  const list = (((obj || {}).webcc_anchor || {}).result) || [];
  return list.map(function (item) {
    return _cc_toRoomModel(item, 0);
  });
}

function _cc_extractShareIds(text) {
  const source = String(text || "");

  let m = source.match(/https:\/\/h5\.cc\.163\.com\/cc\/(\d+)\?rid=(\d+)&cid=(\d+)/);
  if (m && m[1] && m[3]) {
    return {
      roomId: String(m[1]),
      channelId: String(m[3])
    };
  }

  m = source.match(/https:\/\/cc\.163\.com\/(\d+)\/?/);
  if (m && m[1]) {
    return {
      roomId: String(m[1]),
      channelId: null
    };
  }

  return null;
}

async function _cc_getDanmaku(roomId) {
  const resp = await Host.http.request({
    url: `https://api.cc.163.com/v1/activitylives/anchor/lives?anchor_ccid=${encodeURIComponent(String(roomId))}`,
    method: "GET",
    headers: {
      "User-Agent": _cc_ua
    },
    timeout: 20
  });
  const obj = JSON.parse(resp.bodyText || "{}");
  const data = (obj && obj.data) || {};
  const channelData = data[String(roomId)] || Object.values(data)[0] || null;
  if (!channelData || !channelData.channel_id || !channelData.room_id) {
    return {
      args: {},
      headers: null
    };
  }

  return {
    args: {
      cid: String(channelData.channel_id || ""),
      gametype: String(channelData.gametype || 0),
      roomId: String(channelData.room_id || "")
    },
    headers: null
  };
}

globalThis.LiveParsePlugin = {
  apiVersion: 1,

  async getCategories() {
    const main = [
      { id: "1", title: "网游" },
      { id: "2", title: "单机" },
      { id: "4", title: "竞技" },
      { id: "5", title: "综艺" }
    ];

    const out = [];
    for (const item of main) {
      const subList = await _cc_getCategorySubList(item.id);
      out.push({
        id: item.id,
        title: item.title,
        icon: "",
        biz: "",
        subList
      });
    }
    return out;
  },

  async getRooms(payload) {
    const id = String(payload && payload.id ? payload.id : "");
    const page = payload && payload.page ? Number(payload.page) : 1;
    if (!id) _cc_throw("INVALID_ARGS", "id is required", { field: "id" });

    const qs = [
      "format=json",
      "tag_id=0",
      `start=${encodeURIComponent(String((page - 1) * 20))}`,
      "size=20"
    ].join("&");

    const resp = await Host.http.request({
      url: `https://cc.163.com/api/category/${encodeURIComponent(String(id))}?${qs}`,
      method: "GET",
      headers: {
        "User-Agent": _cc_ua
      },
      timeout: 20
    });

    const obj = JSON.parse(resp.bodyText || "{}");
    const lives = (obj && obj.lives) || [];
    return lives.map(function (item) {
      return _cc_toRoomModel(item, 0);
    });
  },

  async getRoomDetail(payload) {
    const roomId = String(payload && payload.roomId ? payload.roomId : "");
    const userId = payload && payload.userId ? String(payload.userId) : null;
    if (!roomId) _cc_throw("INVALID_ARGS", "roomId is required", { field: "roomId" });

    const detail = await _cc_fetchRoomDetail(roomId, userId);
    return _cc_toRoomModel(detail.room, detail.roomId);
  },

  async getPlayback(payload) {
    const roomId = String(payload && payload.roomId ? payload.roomId : "");
    const userId = payload && payload.userId ? String(payload.userId) : null;
    if (!roomId) _cc_throw("INVALID_ARGS", "roomId is required", { field: "roomId" });
    return await _cc_getPlayback(roomId, userId);
  },

  async search(payload) {
    const keyword = String(payload && payload.keyword ? payload.keyword : "");
    const page = payload && payload.page ? Number(payload.page) : 1;
    if (!keyword) _cc_throw("INVALID_ARGS", "keyword is required", { field: "keyword" });
    return await _cc_search(keyword, page);
  },

  async getLiveState(payload) {
    const roomId = String(payload && payload.roomId ? payload.roomId : "");
    const userId = payload && payload.userId ? String(payload.userId) : null;
    if (!roomId) _cc_throw("INVALID_ARGS", "roomId is required", { field: "roomId" });
    const info = await this.getRoomDetail({ roomId, userId });
    return {
      liveState: String(info && info.liveState ? info.liveState : "3")
    };
  },

  async resolveShare(payload) {
    const shareCode = String(payload && payload.shareCode ? payload.shareCode : "");
    if (!shareCode) _cc_throw("INVALID_ARGS", "shareCode is required", { field: "shareCode" });

    const ids = _cc_extractShareIds(shareCode);
    if (ids) {
      return await this.getRoomDetail({
        roomId: String(ids.roomId),
        userId: ids.channelId ? String(ids.channelId) : null
      });
    }

    const resolved = _cc_formatId(shareCode);
    if (!resolved || !/^\d+$/.test(resolved)) {
      _cc_throw("PARSE", `cannot parse shareCode: ${shareCode}`, { shareCode: String(shareCode || "") });
    }
    return await this.getRoomDetail({ roomId: resolved, userId: null });
  },

  async getDanmaku(payload) {
    const roomId = String(payload && payload.roomId ? payload.roomId : "");
    if (!roomId) _cc_throw("INVALID_ARGS", "roomId is required", { field: "roomId" });
    return await _cc_getDanmaku(roomId);
  }
};
