const _bili_ua = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36";
const _bili_referer = "https://live.bilibili.com/";
const _bili_playbackUserAgent = "libmpv";
const _bili_playbackHeaders = {
  "User-Agent": _bili_playbackUserAgent
};

function _bili_throw(code, message, context) {
  if (globalThis.Host && typeof Host.raise === "function") {
    Host.raise(code, message, context || {});
  }
  if (globalThis.Host && typeof Host.makeError === "function") {
    throw Host.makeError(code || "UNKNOWN", message || "", context || {});
  }
  throw new Error(`LP_PLUGIN_ERROR:${JSON.stringify({ code: String(code || "UNKNOWN"), message: String(message || ""), context: context || {} })}`);
}

function _bili_md5(input) {
  return Host.crypto.md5(String(input || ""));
}

function _bili_getLiveStateString(liveState) {
  const value = _bili_toNumberOrDefault(liveState, -1);
  if (value === 0) return "0";
  if (value === 1) return "1";
  if (value === 2) return "0";
  return "3";
}

function _bili_toNumberOrDefault(value, defaultValue) {
  if (value === null || value === undefined || value === "") return defaultValue;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : defaultValue;
}

function _bili_stripHTML(text) {
  return String(text || "").replace(/<[^>]*>/g, "");
}

function _bili_parseQueryString(qs) {
  const out = {};
  if (!qs) return out;
  const parts = String(qs).split("&");
  for (const p of parts) {
    if (!p) continue;
    const idx = p.indexOf("=");
    const key = idx >= 0 ? p.slice(0, idx) : p;
    const val = idx >= 0 ? p.slice(idx + 1) : "";
    out[key] = val;
  }
  return out;
}

function _bili_cookieStoreFromPayload(payload) {
  return {
    cookie: String((payload && payload.cookie) || ""),
    uid: String((payload && payload.uid) || "0")
  };
}

async function _bili_getBuvid3And4() {
  const resp = await Host.http.request({
    url: "https://api.bilibili.com/x/frontend/finger/spi",
    method: "GET",
    timeout: 20
  });
  const obj = JSON.parse(resp.bodyText || "{}");
  const data = obj && obj.data ? obj.data : {};
  return {
    b3: String(data.b_3 || ""),
    b4: String(data.b_4 || "")
  };
}

async function _bili_getHeaders(payload) {
  const state = _bili_cookieStoreFromPayload(payload);
  let cookie = state.cookie;
  console.log(`[bilibili] getHeaders: payload.cookie长度=${String(state.cookie || "").length}, uid=${state.uid}, hasSESSDATA=${String(state.cookie || "").includes("SESSDATA")}`);

  if (!cookie) {
    const buvids = await _bili_getBuvid3And4();
    cookie = `buvid3=${buvids.b3}; buvid4=${buvids.b4};DedeUserID=${Math.floor(Math.random() * 100000)}`;
    console.log(`[bilibili] getHeaders: 无cookie, 生成匿名buvid`);
  } else if (!cookie.includes("buvid3")) {
    const buvids = await _bili_getBuvid3And4();
    const uid = state.uid || "0";
    cookie = `${cookie};buvid3=${buvids.b3}; buvid4=${buvids.b4};DedeUserID=${uid}`;
    console.log(`[bilibili] getHeaders: 有cookie但无buvid3, 追加buvid`);
  } else {
    console.log(`[bilibili] getHeaders: cookie完整, 直接使用`);
  }

  console.log(`[bilibili] getHeaders: 最终cookie长度=${cookie.length}`);
  return {
    cookie,
    "User-Agent": _bili_ua,
    Referer: _bili_referer
  };
}

async function _bili_getAccessId(headers) {
  const resp = await Host.http.request({
    url: "https://live.bilibili.com/lol",
    method: "GET",
    headers,
    timeout: 20
  });
  const html = String(resp.bodyText || "");
  const m = html.match(/"access_id":"(.*?)"/);
  return m && m[1] ? String(m[1]).replace(/\\/g, "") : "";
}

async function _bili_getWbiKeys() {
  const resp = await Host.http.request({
    url: "https://api.bilibili.com/x/web-interface/nav",
    method: "GET",
    headers: {
      "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1",
      Referer: "https://www.bilibili.com/"
    },
    timeout: 20
  });
  const obj = JSON.parse(resp.bodyText || "{}");
  console.log(`[bilibili] nav response code=${obj && obj.code}, isLogin=${obj && obj.data && obj.data.isLogin}`);
  const imgURL = (((obj || {}).data || {}).wbi_img || {}).img_url || "";
  const subURL = (((obj || {}).data || {}).wbi_img || {}).sub_url || "";

  const imgKey = String(imgURL).split("/").pop().split(".")[0] || "";
  const subKey = String(subURL).split("/").pop().split(".")[0] || "";
  return { imgKey, subKey };
}

function _bili_getMixinKey(orig) {
  const mixinKeyEncTab = [
    46, 47, 18, 2, 53, 8, 23, 32, 15, 50, 10, 31, 58, 3, 45, 35, 27, 43, 5, 49,
    33, 9, 42, 19, 29, 28, 14, 39, 12, 38, 41, 13, 37, 48, 7, 16, 24, 55, 40,
    61, 26, 17, 0, 1, 60, 51, 30, 4, 22, 25, 54, 21, 56, 59, 6, 63, 57, 62, 11,
    36, 20, 34, 44, 52
  ];

  return mixinKeyEncTab.map(function (idx) { return orig[idx] || ""; }).join("").slice(0, 32);
}

async function _bili_wbiSign(param) {
  const keys = await _bili_getWbiKeys();
  console.log(`[bilibili] wbiKeys: imgKey=${String(keys.imgKey || "").substring(0, 10)}..., subKey=${String(keys.subKey || "").substring(0, 10)}...`);
  const mixinKey = _bili_getMixinKey(String(keys.imgKey || "") + String(keys.subKey || ""));

  let params = _bili_parseQueryString(param);
  params.wts = Math.floor(Date.now() / 1000);
  console.log(`[bilibili] wbiSign wts=${params.wts}`);

  const sortedKeys = Object.keys(params).sort();
  const escaped = {};
  for (const key of sortedKeys) {
    escaped[key] = String(params[key]).split("").filter(function (char) {
      return "!'()*".indexOf(char) < 0;
    }).join("");
  }

  const query = Object.keys(escaped)
    .sort()
    .map(function (key) { return `${key}=${escaped[key]}`; })
    .join("&");

  const wRid = _bili_md5(query + mixinKey);
  escaped.w_rid = wRid;
  console.log(`[bilibili] wbiSign: w_rid=${wRid}, queryLen=${query.length}, mixinKeyLen=${mixinKey.length}`);

  return Object.keys(escaped)
    .map(function (key) { return `${key}=${escaped[key]}`; })
    .join("&");
}

async function _bili_getRoomDanmuDetail(roomId, headers) {
  const query = await _bili_wbiSign(`id=${roomId}&type=0&sort_type=&vajra_business_key=&web_location=444.43`);
  const resp = await Host.http.request({
    url: `https://api.live.bilibili.com/xlive/web-room/v1/index/getDanmuInfo?${query}`,
    method: "GET",
    headers,
    timeout: 20
  });
  const obj = JSON.parse(resp.bodyText || "{}");
  const data = obj && obj.data;
  if (!data) _bili_throw("INVALID_RESPONSE", "danmu detail is empty");
  return data;
}

async function _bili_getCategoryList() {
  const resp = await Host.http.request({
    url: "https://api.live.bilibili.com/room/v1/Area/getList",
    method: "GET",
    timeout: 20
  });
  const obj = JSON.parse(resp.bodyText || "{}");
  const data = obj && obj.data ? obj.data : [];

  const out = [];
  for (const item of data) {
    const sub = item && item.list ? item.list : [];
    const subList = sub.map(function (s) {
      return {
        id: String(s.id || ""),
        parentId: String(s.parent_id || ""),
        title: String(s.name || ""),
        icon: String(s.pic || ""),
        biz: ""
      };
    });

    out.push({
      id: String(item.id || ""),
      title: String(item.name || ""),
      icon: "",
      biz: "",
      subList
    });
  }
  return out;
}

async function _bili_getRoomList(id, parentId, page, headers) {
  const cookieLen = String(headers && headers.cookie || "").length;
  const hasSESSDATA = String(headers && headers.cookie || "").includes("SESSDATA");
  const hasBuvid3 = String(headers && headers.cookie || "").includes("buvid3");
  console.log(`[bilibili] getRoomList: id=${id}, page=${page}, cookieLen=${cookieLen}, hasSESSDATA=${hasSESSDATA}, hasBuvid3=${hasBuvid3}`);

  const accessId = await _bili_getAccessId(headers);
  console.log(`[bilibili] accessId=${accessId}`);

  const query = await _bili_wbiSign(`area_id=${id}&page=${page}&parent_area_id=${parentId || ""}&platform=web&sort_type=&vajra_business_key=&web_location=444.43&w_webid=${accessId}`);
  const url = `https://api.live.bilibili.com/xlive/web-interface/v1/second/getList?${query}`;
  console.log(`[bilibili] getRoomList URL: ${url.substring(0, 200)}`);

  const resp = await Host.http.request({
    url,
    method: "GET",
    headers,
    timeout: 20
  });
  const obj = JSON.parse(resp.bodyText || "{}");
  const code = obj && Object.prototype.hasOwnProperty.call(obj, "code")
    ? Number(obj.code)
    : -1;
  console.log(`[bilibili] getRoomList response code=${code}, msg=${(obj && (obj.message || obj.msg)) || ""}`);
  if (code !== 0) {
    _bili_throw("UPSTREAM", `apiError code=${obj && obj.code} msg=${(obj && (obj.message || obj.msg)) || ""}`, {
      code: String((obj && obj.code) || ""),
      message: String((obj && (obj.message || obj.msg)) || "")
    });
  }

  const listModelArray = (((obj || {}).data || {}).list) || [];
  return listModelArray.map(function (item) {
    return {
      userName: String(item.uname || ""),
      roomTitle: String(item.title || ""),
      roomCover: String(item.cover || ""),
      userHeadImg: String(item.face || ""),
      liveType: "0",
      liveState: "",
      userId: String(item.uid || "0"),
      roomId: String(item.roomid || "0"),
      liveWatchedCount: String((item.watched_show && item.watched_show.text_small) || "")
    };
  });
}

async function _bili_getPlayArgs(roomId, headers) {
  const qualityResp = await Host.http.request({
    url: `https://api.live.bilibili.com/room/v1/Room/playUrl?platform=web&cid=${encodeURIComponent(String(roomId))}&qn=`,
    method: "GET",
    headers,
    timeout: 20
  });

  const qualityObj = JSON.parse(qualityResp.bodyText || "{}");
  const qualityDescription = (((qualityObj || {}).data || {}).quality_description) || null;

  const liveQualitys = [];
  const hostArray = [];

  async function appendByQn(qn, title) {
    const params = [
      "platform=h5",
      `room_id=${encodeURIComponent(String(roomId))}`,
      `qn=${encodeURIComponent(String(qn))}`,
      "protocol=0,1",
      "format=0,1,2",
      "codec=0",
      "mask=0"
    ].join("&");

    const playInfoResp = await Host.http.request({
      url: `https://api.live.bilibili.com/xlive/web-room/v2/index/getRoomPlayInfo?${params}`,
      method: "GET",
      headers,
      timeout: 20
    });
    const playInfoObj = JSON.parse(playInfoResp.bodyText || "{}");
    const streams = (((playInfoObj || {}).data || {}).playurl_info || {}).playurl;
    const streamList = streams && streams.stream ? streams.stream : [];

    for (const streamInfo of streamList) {
      if (streamInfo.protocol_name !== "http_hls" && streamInfo.protocol_name !== "http_stream") continue;

      const formatList = streamInfo.format || [];
      const formatLast = formatList.length > 0 ? formatList[formatList.length - 1] : null;
      const codecList = formatLast && formatLast.codec ? formatLast.codec : [];
      const codecLast = codecList.length > 0 ? codecList[codecList.length - 1] : null;
      const urlInfoList = codecLast && codecLast.url_info ? codecLast.url_info : [];
      const urlInfoLast = urlInfoList.length > 0 ? urlInfoList[urlInfoList.length - 1] : null;

      const host = String((urlInfoLast && urlInfoLast.host) || "");
      const baseUrl = String((codecLast && codecLast.base_url) || "");
      const extra = String((urlInfoLast && urlInfoLast.extra) || "");
      if (!host) continue;

      if (!hostArray.includes(host)) hostArray.push(host);
      liveQualitys.push({
        roomId: String(roomId),
        title: String(title || "默认"),
        qn: Number(qn || 1500),
        url: `${host}${baseUrl}${extra}`,
        liveCodeType: streamInfo.protocol_name === "http_hls" ? "m3u8" : "flv",
        liveType: "0",
        userAgent: _bili_playbackUserAgent,
        headers: _bili_playbackHeaders
      });
    }
  }

  if (qualityDescription && qualityDescription.length > 0) {
    for (const item of qualityDescription) {
      await appendByQn(item.qn, item.desc);
    }
  } else {
    await appendByQn(1500, "默认");
  }

  const out = [];
  for (let i = 0; i < hostArray.length; i += 1) {
    const host = hostArray[i];
    const qualitys = liveQualitys.filter(function (item) { return String(item.url || "").includes(host); });
    out.push({
      cdn: `线路 ${i + 1}`,
      qualitys
    });
  }
  return out;
}

async function _bili_getLiveLatestInfo(roomId, headers) {
  const resp = await Host.http.request({
    url: `https://api.live.bilibili.com/xlive/web-room/v1/index/getH5InfoByRoom?room_id=${encodeURIComponent(String(roomId))}`,
    method: "GET",
    headers,
    timeout: 20
  });
  console.log(`[bilibili][raw][getH5InfoByRoom] roomId=${String(roomId)} body=${String(resp.bodyText || "")}`);
  const obj = JSON.parse(resp.bodyText || "{}");
  const data = obj && obj.data ? obj.data : null;
  if (!data) _bili_throw("INVALID_RESPONSE", "empty room info", { roomId: String(roomId || "") });

  let liveStatus = "3";
  const status = _bili_toNumberOrDefault(data.room_info && data.room_info.live_status, -1);
  if (status === 0) liveStatus = "0";
  else if (status === 1) liveStatus = "1";
  else if (status === 2) liveStatus = "0";
  else liveStatus = "3";
    console.log(`[bilibili][raw][getH5InfoByRoomlive_status] ${data.room_info.live_status}`);
    console.log(`[bilibili][raw][getH5InfoByRoomlive_status] ${status}`);
    console.log(`[bilibili][raw][getH5InfoByRoomlive_status] ${liveStatus}`);
    
  let realRoomId = String(roomId);
  const serverRoomId = data.room_info && data.room_info.room_id ? String(data.room_info.room_id) : realRoomId;
  if (serverRoomId !== String(roomId)) {
    realRoomId = serverRoomId;
  }

  const cover = data.room_info && data.room_info.cover ? String(data.room_info.cover) : "";
  const roomCover = cover || "https://s1.hdslb.com/bfs/static/blive/blfe-link-center/static/img/average-backimg.e65973e.png";

  return {
    userName: String((((data || {}).anchor_info || {}).base_info || {}).uname || ""),
    roomTitle: String((data.room_info && data.room_info.title) || ""),
    roomCover,
    userHeadImg: String((((data || {}).anchor_info || {}).base_info || {}).face || ""),
    liveType: "0",
    liveState: liveStatus,
    userId: String((data.room_info && data.room_info.uid) || 0),
    roomId: realRoomId,
    liveWatchedCount: String(((data || {}).watched_show || {}).text_small || "")
  };
}

async function _bili_search(keyword, page, headers) {
  const params = [
    "context=",
    "search_type=live",
    "cover_type=user_cover",
    "order=",
    `keyword=${encodeURIComponent(String(keyword))}`,
    "category_id=",
    "__refresh__=",
    "_extra=",
    "highlight=0",
    "single_column=0",
    `page=${encodeURIComponent(String(page))}`
  ].join("&");

  const resp = await Host.http.request({
    url: `https://api.bilibili.com/x/web-interface/search/type?${params}`,
    method: "GET",
    headers,
    timeout: 20
  });
  const obj = JSON.parse(resp.bodyText || "{}");

  const tempArray = [];
  const liveRooms = ((((obj || {}).data || {}).result || {}).live_room) || [];
  for (const item of liveRooms) {
    tempArray.push({
      userName: String(item.uname || ""),
      roomTitle: String(item.title || ""),
      roomCover: `https:${String(item.cover || "")}`,
      userHeadImg: `https:${String(item.uface || "")}`,
      liveType: "0",
      liveState: _bili_getLiveStateString(item.live_status),
      userId: String(item.uid || "0"),
      roomId: String(item.roomid || "0"),
      liveWatchedCount: String(((item || {}).watched_show || {}).text_small || "")
    });
  }

  const liveUsers = ((((obj || {}).data || {}).result || {}).live_user) || [];
  for (const item of liveUsers) {
    const flowCount = Number(item.attentions || 0);
    const flowFormatString = flowCount > 10000
      ? `${(flowCount / 10000.0).toFixed(2)} 万人关注直播间`
      : `${flowCount} 人关注直播间`;

    const userName = _bili_stripHTML(item.uname || "");
    tempArray.push({
      userName,
      roomTitle: String(item.title || `${String(item.cate_name || "无分区")} · ${flowFormatString}`),
      roomCover: `https:${String(item.uface || "")}`,
      userHeadImg: `https:${String(item.uface || "")}`,
      liveType: "0",
      liveState: _bili_getLiveStateString(item.live_status),
      userId: String(item.uid || "0"),
      roomId: String(item.roomid || "0"),
      liveWatchedCount: flowFormatString
    });
  }

  return tempArray;
}

async function _bili_getLiveState(roomId, headers) {
  const resp = await Host.http.request({
    url: `https://api.live.bilibili.com/room/v1/Room/get_info?room_id=${encodeURIComponent(String(roomId))}`,
    method: "GET",
    headers,
    timeout: 20
  });
  console.log(`[bilibili][raw][get_info] roomId=${String(roomId)} body=${String(resp.bodyText || "")}`);

  const obj = JSON.parse(resp.bodyText || "{}");
  const liveStatus = _bili_toNumberOrDefault((((obj || {}).data) || {}).live_status, -1);
  return {
    liveState: _bili_getLiveStateString(liveStatus)
  };
}

async function _bili_getRoomInfoFromShareCode(shareCode, headers) {
  const text = String(shareCode || "");
  let roomId = "";
  let realUrl = "";

  if (text.includes("b23.tv")) {
    const url = (text.match(/https?:\/\/[^\s|]+/) || ["", ""])[0] || "";
    const redirectResp = await Host.http.request({
      url,
      method: "GET",
      headers,
      timeout: 20
    });
    realUrl = String(redirectResp.url || url);
  } else if (text.includes("live.bilibili.com")) {
    realUrl = text;
  } else {
    roomId = text;
  }

  if (!roomId) {
    const m = String(realUrl).match(/https:\/\/live\.bilibili\.com\/(\d+)/);
    roomId = m && m[1] ? String(m[1]) : "";
  }

  if (!roomId || !(parseInt(roomId, 10) > 0)) {
    _bili_throw("NOT_FOUND", `invalid room id from share code: ${shareCode}`, { shareCode: String(shareCode || "") });
  }

  return await _bili_getLiveLatestInfo(roomId, headers);
}

async function _bili_getDanmukuArgs(roomId, headers) {
  let buvid = "";
  const cookie = String(headers.cookie || "");

  if (!cookie.includes("buvid3")) {
    const resp = await Host.http.request({
      url: "https://api.bilibili.com/x/frontend/finger/spi",
      method: "GET",
      timeout: 20
    });
    const obj = JSON.parse(resp.bodyText || "{}");
    buvid = String(((obj || {}).data || {}).b_3 || "");
  } else {
    const m = cookie.match(/buvid3=(.*?);/);
    buvid = m && m[1] ? String(m[1]) : "";
  }

  const roomInfo = await _bili_getLiveLatestInfo(roomId, headers);
  const danmuDetail = await _bili_getRoomDanmuDetail(roomInfo.roomId, headers);
  const hostList = danmuDetail && danmuDetail.host_list ? danmuDetail.host_list : [];
  const wsHost = hostList.length > 0 && hostList[0].host
    ? String(hostList[0].host)
    : "broadcastlv.chat.bilibili.com";

  return {
    args: {
      roomId: String(roomId),
      buvid: String(buvid || ""),
      token: String((danmuDetail && danmuDetail.token) || ""),
      ws_url: `wss://${wsHost}/sub`
    },
    headers: null
  };
}

globalThis.LiveParsePlugin = {
  apiVersion: 1,

  async getCategories(payload) {
    return await _bili_getCategoryList();
  },

  async getRooms(payload) {
    const id = String(payload && payload.id ? payload.id : "");
    const parentId = String(payload && payload.parentId ? payload.parentId : "");
    const page = payload && payload.page ? Number(payload.page) : 1;
    if (!id) _bili_throw("INVALID_ARGS", "id is required", { field: "id" });
    const headers = await _bili_getHeaders(payload || {});
    return await _bili_getRoomList(id, parentId, page, headers);
  },

  async getPlayback(payload) {
    const roomId = String(payload && payload.roomId ? payload.roomId : "");
    if (!roomId) _bili_throw("INVALID_ARGS", "roomId is required", { field: "roomId" });
    const headers = await _bili_getHeaders(payload || {});
    return await _bili_getPlayArgs(roomId, headers);
  },

  async getRoomDetail(payload) {
    const roomId = String(payload && payload.roomId ? payload.roomId : "");
    if (!roomId) _bili_throw("INVALID_ARGS", "roomId is required", { field: "roomId" });
    const headers = await _bili_getHeaders(payload || {});
    return await _bili_getLiveLatestInfo(roomId, headers);
  },

  async search(payload) {
    const keyword = String(payload && payload.keyword ? payload.keyword : "");
    const page = payload && payload.page ? Number(payload.page) : 1;
    if (!keyword) _bili_throw("INVALID_ARGS", "keyword is required", { field: "keyword" });
    const headers = await _bili_getHeaders(payload || {});
    return await _bili_search(keyword, page, headers);
  },

  async getLiveState(payload) {
    const roomId = String(payload && payload.roomId ? payload.roomId : "");
    if (!roomId) _bili_throw("INVALID_ARGS", "roomId is required", { field: "roomId" });
    const headers = await _bili_getHeaders(payload || {});
    return await _bili_getLiveState(roomId, headers);
  },

  async resolveShare(payload) {
    const shareCode = String(payload && payload.shareCode ? payload.shareCode : "");
    if (!shareCode) _bili_throw("INVALID_ARGS", "shareCode is required", { field: "shareCode" });
    const headers = await _bili_getHeaders(payload || {});
    return await _bili_getRoomInfoFromShareCode(shareCode, headers);
  },

  async getDanmaku(payload) {
    const roomId = String(payload && payload.roomId ? payload.roomId : "");
    if (!roomId) _bili_throw("INVALID_ARGS", "roomId is required", { field: "roomId" });
    const headers = await _bili_getHeaders(payload || {});
    return await _bili_getDanmukuArgs(roomId, headers);
  }
};
