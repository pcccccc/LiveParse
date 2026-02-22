const __lp_yy_defaultHeaders = {
  "user-agent": " Platform/iOS17.5.1 APP/yymip8.40.0 Model/iPhone Browerser:Default Scale/3.00 YY(ClientVersion:8.40.0 ClientEdition:yymip) HostName/yy HostVersion/8.40.0 HostId/1 UnionVersion/2.690.0 Build1492 HostExtendInfo/b576b278cba95c5100f84a69b26dc36bf44f080608b937825dcd64ee5911351f74dbda4ac85cfb011f32eb00b7c16ecc6bad4eaa3cd9f69c923177e74f6212682492886a946abdcf921a84c93ff329d4fd9e2bc67f5fe727d9a7b10ee65fbbbf",
  "accept-language": "zh-Hans-CN;q=1",
  "accept-encoding": "gzip, deflate, br, zstd",
  "content-type": "application/json; charset=utf-8",
  Accept: "application/json"
};

const __lp_yy_playHeaders = {
  "content-type": "text/plain;charset=UTF-8",
  referer: "https://www.yy.com"
};

const __lp_yy_sidQueryKeys = ["sid", "ssid", "roomId"];

function __lp_yy_throw(code, message, context) {
  if (globalThis.Host && typeof Host.raise === "function") {
    Host.raise(code, message, context || {});
  }
  if (globalThis.Host && typeof Host.makeError === "function") {
    throw Host.makeError(code || "UNKNOWN", message || "", context || {});
  }
  throw new Error(`LP_PLUGIN_ERROR:${JSON.stringify({ code: String(code || "UNKNOWN"), message: String(message || ""), context: context || {} })}`);
}

function __lp_yy_parseCode(value, fallback) {
  const raw = String(value === undefined || value === null ? "" : value).trim();
  if (!raw) return fallback;
  const parsed = parseInt(raw, 10);
  return Number.isNaN(parsed) ? fallback : parsed;
}

function __lp_yy_isValidRoomId(value) {
  return /^\d{3,}$/.test(String(value || ""));
}

function __lp_yy_firstURL(text) {
  const m = String(text || "").match(/https?:\/\/[^\s|]+/);
  return m ? String(m[0]) : "";
}

function __lp_yy_buildRoomListURL(id, parentId) {
  if (String(id) === "index") {
    return `https://yyapp-idx.yy.com/mobyy/nav/${encodeURIComponent(String(id))}/${encodeURIComponent(String(parentId || ""))}`;
  }
  return `https://rubiks-idx.yy.com/nav/${encodeURIComponent(String(id))}/${encodeURIComponent(String(parentId || ""))}`;
}

function __lp_yy_parseLineInfos(avpInfo) {
  const streamLineList = avpInfo && avpInfo.stream_line_list;
  if (!streamLineList || typeof streamLineList !== "object") return [];

  const result = [];
  const existed = new Set();
  for (const key of Object.keys(streamLineList)) {
    const lineDict = streamLineList[key];
    const lineInfos = lineDict && lineDict.line_infos;
    if (!Array.isArray(lineInfos)) continue;

    for (const info of lineInfos) {
      const name = String((info && info.line_print_name) || "");
      if (!name || existed.has(name)) continue;
      existed.add(name);
      result.push({
        name,
        lineSeq: String((info && info.line_seq) || -1)
      });
    }
  }
  return result;
}

function __lp_yy_extractPlayURL(avpInfo) {
  const lineAddr = avpInfo && avpInfo.stream_line_addr;
  if (!lineAddr || typeof lineAddr !== "object") return "";

  for (const key of Object.keys(lineAddr)) {
    const streamInfo = lineAddr[key];
    const cdnInfo = streamInfo && streamInfo.cdn_info;
    const url = cdnInfo && cdnInfo.url;
    if (url) return String(url);
  }
  return "";
}

function __lp_yy_parseQualityDetails(jsonObject, defaultURL, roomId) {
  const channelInfo = jsonObject && jsonObject.channel_stream_info;
  const streams = channelInfo && channelInfo.streams;
  if (!Array.isArray(streams)) {
    __lp_yy_throw("INVALID_RESPONSE", "missing channel_stream_info.streams", { roomId: String(roomId || "") });
  }

  const details = [];
  const existed = new Set();
  for (const stream of streams) {
    const jsonString = stream && stream.json;
    if (!jsonString) continue;

    let decoded = null;
    try {
      decoded = JSON.parse(String(jsonString));
    } catch (e) {
      continue;
    }

    const gearInfo = decoded && decoded.gear_info;
    if (!gearInfo) continue;

    const rate = Number(gearInfo.gear || 0);
    const title = String(gearInfo.name || "默认");
    const dedupeKey = `${title}_${rate}`;
    if (existed.has(dedupeKey)) continue;
    existed.add(dedupeKey);

    details.push({
      roomId: String(roomId),
      title,
      qn: rate,
      url: String(defaultURL),
      liveCodeType: "flv",
      liveType: "6"
    });
  }

  if (details.length === 0) {
    __lp_yy_throw("INVALID_RESPONSE", "missing gear_info", { roomId: String(roomId || "") });
  }
  return details;
}

async function __lp_yy_getRealPlayArgs(roomId, lineSeq, gear) {
  const millis13 = Date.now();
  const millis10 = Math.floor(Date.now() / 1000);

  const params = {
    head: {
      seq: millis13,
      appidstr: "0",
      bidstr: "121",
      cidstr: String(roomId),
      sidstr: String(roomId),
      uid64: 0,
      client_type: 108,
      client_ver: "5.18.2",
      stream_sys_ver: 1,
      app: "yylive_web",
      playersdk_ver: "5.18.2",
      thundersdk_ver: "0",
      streamsdk_ver: "5.18.2"
    },
    client_attribute: {
      client: "web",
      model: "web1",
      cpu: "",
      graphics_card: "",
      os: "chrome",
      osversion: "125.0.0.0",
      vsdk_version: "",
      app_identify: "",
      app_version: "",
      business: "",
      width: "1920",
      height: "1080",
      scale: "",
      client_type: 8,
      h265: 0
    },
    avp_parameter: {
      version: 1,
      client_type: 8,
      service_type: 0,
      imsi: 0,
      send_time: millis10,
      line_seq: lineSeq,
      gear,
      ssl: 1,
      stream_format: 0
    }
  };

  const url = `https://stream-manager.yy.com/v3/channel/streams?uid=0&cid=${encodeURIComponent(String(roomId))}&sid=${encodeURIComponent(String(roomId))}&appid=0&sequence=${encodeURIComponent(String(millis13))}&encode=json`;
  const resp = await Host.http.request({
    url,
    method: "POST",
    headers: __lp_yy_playHeaders,
    body: JSON.stringify(params),
    timeout: 20
  });

  const obj = JSON.parse(resp.bodyText || "{}");
  const avpInfo = obj && obj.avp_info_res;
  if (!avpInfo) __lp_yy_throw("INVALID_RESPONSE", "missing avp_info_res", { roomId: String(roomId || "") });

  const lineInfos = __lp_yy_parseLineInfos(avpInfo);
  const playURL = __lp_yy_extractPlayURL(avpInfo);
  if (!playURL) __lp_yy_throw("NOT_FOUND", "missing play url", { roomId: String(roomId || "") });

  const qualityDetails = __lp_yy_parseQualityDetails(obj, playURL, roomId);

  return lineInfos.map(function (line) {
    return {
      cdn: String(line.name || ""),
      yyLineSeq: String(line.lineSeq || "-1"),
      qualitys: qualityDetails
    };
  });
}

function __lp_yy_roomDataToLiveModel(item) {
  const sid = String(item && item.sid ? item.sid : "");
  const uid = item && item.uid ? String(item.uid) : sid;
  return {
    userName: String((item && item.name) || ""),
    roomTitle: String((item && item.desc) || ""),
    roomCover: String((item && item.img) || ""),
    userHeadImg: String((item && item.avatar) || ""),
    liveType: "6",
    liveState: "1",
    userId: uid,
    roomId: sid,
    liveWatchedCount: String((item && item.users) || 0)
  };
}

function __lp_yy_searchDocToLiveModel(doc) {
  const roomId = String((doc && doc.sid) || "");
  return {
    userName: String((doc && (doc.name || doc.stageName)) || ""),
    roomTitle: String((doc && (doc.stageName || doc.name)) || ""),
    roomCover: String((doc && doc.headurl) || ""),
    userHeadImg: String((doc && doc.headurl) || ""),
    liveType: "6",
    liveState: String((doc && doc.liveOn) || "3"),
    userId: String((doc && doc.uid) || roomId),
    roomId,
    liveWatchedCount: "0"
  };
}

function __lp_yy_resolveRoomIdFromShareCode(shareCode) {
  const trimmed = String(shareCode || "").trim();
  if (!trimmed) __lp_yy_throw("INVALID_ARGS", "shareCode is empty", { field: "shareCode" });

  const urlText = __lp_yy_firstURL(trimmed);
  if (urlText) {
    try {
      const u = new URL(urlText);
      for (const key of __lp_yy_sidQueryKeys) {
        const value = u.searchParams.get(key);
        if (value && __lp_yy_isValidRoomId(value)) {
          return value;
        }
      }

      const pathIds = String(u.pathname || "")
        .split("/")
        .filter(function (token) { return __lp_yy_isValidRoomId(token); });
      if (pathIds.length > 0) {
        return pathIds[pathIds.length - 1];
      }
    } catch (e) {
    }
  }

  const tokens = trimmed.split(/[\s|]+/);
  for (const token of tokens) {
    if (__lp_yy_isValidRoomId(token)) return token;
  }

  if (__lp_yy_isValidRoomId(trimmed)) return trimmed;

  __lp_yy_throw("NOT_FOUND", "cannot resolve roomId from shareCode", { shareCode: String(shareCode || "") });
}

globalThis.LiveParsePlugin = {
  apiVersion: 1,

  async getCategoryList() {
    const resp = await Host.http.request({
      url: "https://rubiks-idx.yy.com/navs",
      method: "GET",
      headers: __lp_yy_defaultHeaders,
      timeout: 20
    });

    const response = JSON.parse(resp.bodyText || "{}");
    if (__lp_yy_parseCode(response.code, -1) !== 0) {
      __lp_yy_throw("UPSTREAM", `YY category error: ${response.code} - ${response.message || ""}`, {
        code: String(response.code || ""),
        message: String(response.message || "")
      });
    }

    const lists = response.data || [];
    const result = [];

    for (const item of lists) {
      if (String(item.name || "") === "附近") continue;

      const subList = [];
      const navs = item.navs || [];
      for (const nav of navs) {
        subList.push({
          id: String(nav.id || ""),
          parentId: String(item.id || ""),
          title: String(nav.name || ""),
          icon: "",
          biz: String(nav.biz || "")
        });
      }

      if (subList.length === 0) {
        subList.push({
          id: "0",
          parentId: String(item.id || ""),
          title: String(item.name || ""),
          icon: "",
          biz: "idx"
        });
      }

      result.push({
        id: String(item.id || ""),
        title: String(item.name || ""),
        icon: String(item.pic || ""),
        biz: String(item.biz || ""),
        subList
      });
    }

    return result;
  },

  async getRoomList(payload) {
    const id = String(payload && payload.id ? payload.id : "");
    const parentId = String(payload && payload.parentId ? payload.parentId : "");
    if (!id) __lp_yy_throw("INVALID_ARGS", "id is required", { field: "id" });

    const url = __lp_yy_buildRoomListURL(id, parentId);
    const resp = await Host.http.request({
      url,
      method: "GET",
      headers: __lp_yy_defaultHeaders,
      timeout: 20
    });

    const response = JSON.parse(resp.bodyText || "{}");
    if (response.code !== undefined && __lp_yy_parseCode(response.code, -1) !== 0) {
      __lp_yy_throw("UPSTREAM", `YY room list error: ${response.code} - ${response.message || ""}`, {
        code: String(response.code || ""),
        message: String(response.message || "")
      });
    }

    const sections = response.data || [];
    const rooms = [];
    for (const section of sections) {
      const items = section.data || [];
      for (const item of items) {
        const sid = item && item.sid;
        if (!sid) continue;

        const name = String((item && item.name) || "");
        if (name.includes("预告") || name.includes("活动")) continue;
        rooms.push(__lp_yy_roomDataToLiveModel(item));
      }
    }
    return rooms;
  },

  async getPlayArgs(payload) {
    const roomId = String(payload && payload.roomId ? payload.roomId : "");
    if (!roomId) __lp_yy_throw("INVALID_ARGS", "roomId is required", { field: "roomId" });
    return await __lp_yy_getRealPlayArgs(roomId, -1, 4);
  },

  async getLiveLastestInfo(payload) {
    const roomId = String(payload && payload.roomId ? payload.roomId : "");
    if (!roomId) __lp_yy_throw("INVALID_ARGS", "roomId is required", { field: "roomId" });

    const url = `https://www.yy.com/api/liveInfoDetail/${encodeURIComponent(String(roomId))}/${encodeURIComponent(String(roomId))}/0`;
    const resp = await Host.http.request({
      url,
      method: "GET",
      timeout: 20
    });

    const response = JSON.parse(resp.bodyText || "{}");
    if (__lp_yy_parseCode(response.resultCode, -1) !== 0 || !response.data) {
      __lp_yy_throw("NOT_FOUND", `YY room detail not found: ${roomId}`, { roomId: String(roomId || "") });
    }

    const info = response.data;
    return {
      userName: String(info.name || ""),
      roomTitle: String(info.desc || ""),
      roomCover: String(info.thumb2 || info.gameThumb || ""),
      userHeadImg: String(info.avatar || ""),
      liveType: "6",
      liveState: "1",
      userId: String(info.uid || "0"),
      roomId: String(info.sid || roomId),
      liveWatchedCount: String(info.users || 0)
    };
  },

  async getLiveState(payload) {
    const roomId = String(payload && payload.roomId ? payload.roomId : "");
    if (!roomId) __lp_yy_throw("INVALID_ARGS", "roomId is required", { field: "roomId" });
    const latest = await this.getLiveLastestInfo(payload || {});
    return {
      liveState: String((latest && latest.liveState) || "3")
    };
  },

  async searchRooms(payload) {
    const keyword = String(payload && payload.keyword ? payload.keyword : "");
    const page = payload && payload.page ? Number(payload.page) : 1;
    if (!keyword) __lp_yy_throw("INVALID_ARGS", "keyword is required", { field: "keyword" });

    const qs = [
      `q=${encodeURIComponent(String(keyword))}`,
      "t=1",
      `n=${encodeURIComponent(String(page))}`
    ].join("&");

    const resp = await Host.http.request({
      url: `https://www.yy.com/apiSearch/doSearch.json?${qs}`,
      method: "GET",
      timeout: 20
    });

    const response = JSON.parse(resp.bodyText || "{}");
    if (!response.success) {
      __lp_yy_throw("UPSTREAM", `YY search error: ${response.message || ""}`, { message: String(response.message || "") });
    }

    const docs = (((response || {}).data || {}).searchResult || {}).response;
    const roomDocs = docs && docs["1"] && docs["1"].docs ? docs["1"].docs : [];
    return roomDocs
      .filter(function (doc) { return !!(doc && doc.sid); })
      .map(function (doc) { return __lp_yy_searchDocToLiveModel(doc); });
  },

  async getRoomInfoFromShareCode(payload) {
    const shareCode = String(payload && payload.shareCode ? payload.shareCode : "");
    if (!shareCode) __lp_yy_throw("INVALID_ARGS", "shareCode is required", { field: "shareCode" });
    const roomId = __lp_yy_resolveRoomIdFromShareCode(shareCode);
    return await this.getLiveLastestInfo({ roomId, userId: null });
  },

  async getDanmukuArgs(payload) {
    const roomId = String(payload && payload.roomId ? payload.roomId : "");
    if (!roomId) __lp_yy_throw("INVALID_ARGS", "roomId is required", { field: "roomId" });
    return {
      args: {},
      headers: null
    };
  }
};
