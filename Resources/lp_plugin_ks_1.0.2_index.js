const __lp_ks_categoryURL = "https://live.kuaishou.com/live_api/category/data";
const __lp_ks_gameListURL = "https://live.kuaishou.com/live_api/gameboard/list";
const __lp_ks_nonGameListURL = "https://live.kuaishou.com/live_api/non-gameboard/list";
const __lp_ks_searchOverviewURL = "https://live.kuaishou.com/live_api/search/overview";
const __lp_ks_searchAuthorURL = "https://live.kuaishou.com/live_api/search/author";
const __lp_ks_searchLiveStreamURL = "https://live.kuaishou.com/live_api/search/liveStream";
const __lp_ks_ua = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36";
const __lp_ks_playbackUserAgent = "libmpv";
const __lp_ks_playbackHeaders = { "User-Agent": __lp_ks_playbackUserAgent };
const __lp_ks_platformId = "ks";

async function _ks_platformRequest(request, authMode) {
  return await Host.http.request({
    platformId: __lp_ks_platformId,
    authMode: authMode || "none",
    request: request || {}
  });
}
function _ks_throw(code, message, context) {
  if (globalThis.Host && typeof Host.raise === "function") {
    Host.raise(code, message, context || {});
  }
  if (globalThis.Host && typeof Host.makeError === "function") {
    throw Host.makeError(code || "UNKNOWN", message || "", context || {});
  }
  throw new Error(`LP_PLUGIN_ERROR:${JSON.stringify({ code: String(code || "UNKNOWN"), message: String(message || ""), context: context || {} })}`);
}

function _ks_firstMatch(text, re) {
  const m = String(text || "").match(re);
  if (!m || !m[1]) return "";
  return String(m[1]);
}

function _ks_extractInitialStateText(html) {
  const source = String(html || "");
  const markers = ["window.__INITIAL_STATE__=", "__INITIAL_STATE__="];

  for (const marker of markers) {
    const idx = source.indexOf(marker);
    if (idx === -1) continue;

    const jsonStart = idx + marker.length;
    let depth = 0;
    let inString = false;
    let escape = false;

    for (let i = jsonStart; i < source.length; i += 1) {
      const ch = source[i];
      if (escape) {
        escape = false;
        continue;
      }
      if (ch === "\\") {
        escape = true;
        continue;
      }
      if (ch === "\"") {
        inString = !inString;
        continue;
      }
      if (inString) continue;
      if (ch === "{") {
        depth += 1;
      } else if (ch === "}") {
        depth -= 1;
        if (depth === 0) {
          return source.substring(jsonStart, i + 1);
        }
      }
    }
  }

  return "";
}

function _ks_parseInitialState(html) {
  const raw = _ks_extractInitialStateText(html);
  if (!raw) return null;

  try {
    return JSON.parse(raw.replace(/:\s*undefined/g, ":null"));
  } catch (e) {
    return null;
  }
}

function _ks_extractLiveStreamIdFallback(html) {
  return _ks_firstMatch(String(html || ""), /"id"\s*:\s*"([A-Za-z0-9_-]+)".*?"type"\s*:\s*"live"/s);
}

function _ks_extractShortLink(text) {
  const m = String(text || "").match(/https:\/\/v\.kuaishou\.com\/[A-Za-z0-9]+/);
  return m ? String(m[0]) : "";
}

function _ks_extractUserId(text) {
  return _ks_firstMatch(text, /\/u\/([A-Za-z0-9_-]+)/);
}

function _ks_extractLiveId(text) {
  return _ks_firstMatch(text, /\/live\/([A-Za-z0-9_-]+)/);
}

function _ks_isValidRoomId(roomId) {
  return /^[A-Za-z0-9_-]{3,}$/.test(String(roomId || ""));
}

function _ks_toRoomModel(item) {
  const author = item && item.author ? item.author : {};
  const isLiving = !!(item && item.living);
  const id = String((author && author.id) || (item && item.id) || "");
  return {
    userName: String((author && author.name) || ""),
    roomTitle: String((item && item.caption) || `${String((author && author.name) || "")}的直播间`),
    roomCover: String((item && item.poster) || ""),
    userHeadImg: String((author && author.avatar) || ""),
    liveType: "5",
    liveState: isLiving ? "1" : "0",
    userId: id,
    roomId: id,
    liveWatchedCount: String((item && item.watchingCount) || "")
  };
}

function _ks_qualityLabel(rep) {
  const qualityType = String(rep && rep.qualityType ? rep.qualityType : "").toUpperCase();
  const map = {
    SUPER: "蓝光4M",
    HIGH: "超清",
    STANDARD: "高清",
    LOW: "流畅"
  };
  const named = String(rep && (rep.name || rep.shortName) ? (rep.name || rep.shortName) : "").trim();
  return named || map[qualityType] || "默认";
}

function _ks_qualityRank(rep) {
  const bitrate = Number(rep && rep.bitrate ? rep.bitrate : 0);
  if (bitrate > 0) return bitrate;

  const qualityType = String(rep && rep.qualityType ? rep.qualityType : "").toUpperCase();
  const rankMap = {
    SUPER: 4000,
    HIGH: 2000,
    STANDARD: 1000,
    LOW: 500
  };
  return Number(rankMap[qualityType] || 0);
}

function _ks_makeQualityDetails(playUrl, roomId, codecName) {
  const adaptationSet = playUrl && playUrl.adaptationSet;
  const representation = adaptationSet && adaptationSet.representation;
  if (!Array.isArray(representation)) return [];

  return representation.map(function (rep) {
    const codecLabel = String(codecName || "").trim().toUpperCase();
    const baseTitle = _ks_qualityLabel(rep);
    return {
      roomId: String(roomId),
      title: codecLabel ? `${baseTitle}_${codecLabel}` : baseTitle,
      qn: _ks_qualityRank(rep),
      url: String(rep && rep.url ? rep.url : ""),
      liveCodeType: "flv",
      liveType: "5",
      userAgent: __lp_ks_playbackUserAgent,
      headers: __lp_ks_playbackHeaders
    };
  }).filter(function (item) { return !!item.url; });
}

function _ks_sortQualityDetails(details) {
  return (details || []).sort(function (left, right) {
    const rankDelta = Number((right && right.qn) || 0) - Number((left && left.qn) || 0);
    if (rankDelta !== 0) return rankDelta;

    return String((left && left.title) || "").localeCompare(String((right && right.title) || ""));
  });
}

function _ks_pickCurrentPlayItem(liveData) {
  const playList = liveData && liveData.liveroom && liveData.liveroom.playList;
  return Array.isArray(playList) && playList.length > 0 ? playList[0] : null;
}

function _ks_searchToRoomModel(item) {
  const source = item && typeof item === "object" ? item : {};
  const author = source.author && typeof source.author === "object" ? source.author : {};
  const roomId = String(source.id || source.liveStreamId || source.roomId || "");
  const userId = String(author.id || source.userId || source.ownerId || roomId);
  const roomCover = String(source.poster || source.coverUrl || source.cover || "");
  const userHeadImg = String(author.avatar || author.headerUrl || source.userHeadImg || "");
  const roomTitle = String(source.caption || source.title || `${String(author.name || "")}的直播间`);
  const stateFromItem = source.isLiving !== undefined ? !!source.isLiving : (source.living !== undefined ? !!source.living : true);
  const liveState = stateFromItem ? "1" : "0";
  if (!roomId || !userId) return null;
  return {
    userName: String(author.name || source.userName || ""),
    roomTitle,
    roomCover,
    userHeadImg,
    liveType: "5",
    liveState,
    userId,
    roomId,
    liveWatchedCount: String(source.watchingCount || source.displayWatchingCount || "")
  };
}

function _ks_pickHeaders(referer) {
  const out = {
    "User-Agent": __lp_ks_ua,
    "Accept": "application/json, text/plain, */*",
    "Referer": String(referer || "https://live.kuaishou.com/")
  };
  return out;
}

function _ks_toQueryString(params) {
  const parts = [];
  const source = params && typeof params === "object" ? params : {};
  for (const key of Object.keys(source)) {
    const value = source[key];
    if (value === undefined || value === null) continue;
    parts.push(`${encodeURIComponent(String(key))}=${encodeURIComponent(String(value))}`);
  }
  return parts.join("&");
}

async function _ks_getSearchData(url, params, referer) {
  const qs = _ks_toQueryString(params);
  const reqURL = qs ? `${url}?${qs}` : url;
  const resp = await _ks_platformRequest({
    url: reqURL,
    method: "GET",
    headers: _ks_pickHeaders(referer),
    timeout: 20
  });
  const obj = JSON.parse(resp.bodyText || "{}");
  const data = obj && obj.data ? obj.data : {};
  const resultCode = Number(data && data.result !== undefined ? data.result : 0);
  if (resultCode !== 1) {
    _ks_throw("UPSTREAM", `kuaishou search api failed: result=${resultCode}`, { url: reqURL, result: String(resultCode) });
  }
  return data;
}

async function _ks_fetchLiveRoomHTML(roomId, authMode) {
  const url = `https://live.kuaishou.com/u/${encodeURIComponent(String(roomId))}`;
  const resp = await _ks_platformRequest({
    url,
    method: "GET",
    headers: {
      "user-agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36"
    },
    timeout: 20
  }, authMode);

  return String(resp.bodyText || "");
}

async function _ks_getLiveRoomBundle(roomId, authMode) {
  const html = await _ks_fetchLiveRoomHTML(roomId, authMode);
  const liveData = _ks_parseInitialState(html);
  if (!liveData) {
    _ks_throw("PARSE", "__INITIAL_STATE__ not found");
  }

  return { html, liveData };
}

async function _ks_getLiveRoom(roomId, authMode) {
  const bundle = await _ks_getLiveRoomBundle(roomId, authMode);
  return bundle.liveData;
}

async function _ks_getCategorySubList(id) {
  let page = 1;
  let hasMore = true;
  const categoryList = [];

  while (hasMore) {
    const qs = [
      `type=${encodeURIComponent(String(id))}`,
      `page=${encodeURIComponent(String(page))}`,
      "pageSize=20"
    ].join("&");

    const resp = await _ks_platformRequest({
      url: `${__lp_ks_categoryURL}?${qs}`,
      method: "GET",
      timeout: 20
    });
    const obj = JSON.parse(resp.bodyText || "{}");
    const data = obj && obj.data;
    if (!data) break;

    const list = data.list || [];
    for (const item of list) {
      categoryList.push({
        id: String(item.id || ""),
        parentId: "",
        title: String(item.name || ""),
        icon: String(item.poster || ""),
        biz: ""
      });
    }

    hasMore = !!data.hasMore;
    page += 1;
  }

  return categoryList;
}

async function _ks_getRooms(id, page) {
  const isNonGame = String(id || "").length >= 7;
  const url = isNonGame ? __lp_ks_nonGameListURL : __lp_ks_gameListURL;
  const qs = [
    "filterType=0",
    `page=${encodeURIComponent(String(page))}`,
    "pageSize=20",
    `gameId=${encodeURIComponent(String(id))}`
  ].join("&");

  const resp = await _ks_platformRequest({
    url: `${url}?${qs}`,
    method: "GET",
    timeout: 20
  });
  const obj = JSON.parse(resp.bodyText || "{}");
  const list = obj && obj.data && obj.data.list ? obj.data.list : [];
  return list.map(_ks_toRoomModel);
}

async function _ks_search(keyword, page) {
  const keywordText = String(keyword || "").trim();
  if (!keywordText) return [];
  const pageNo = Number(page) > 0 ? Number(page) : 1;
  const searchReferer = `https://live.kuaishou.com/search/${encodeURIComponent(keywordText)}`;

  // 先打 overview，让站点侧建立搜索会话。
  await _ks_getSearchData(
    __lp_ks_searchOverviewURL,
    { keyword: keywordText, ussid: "" },
    searchReferer
  );

  const authorData = await _ks_getSearchData(
    __lp_ks_searchAuthorURL,
    {
      key: keywordText,
      keyword: keywordText,
      page: pageNo,
      ussid: "",
      lssid: "",
      count: 15
    },
    searchReferer
  );

  const ussid = String(authorData.ussid || "");
  const liveData = await _ks_getSearchData(
    __lp_ks_searchLiveStreamURL,
    {
      keyword: keywordText,
      page: pageNo,
      ussid
    },
    searchReferer
  );

  const out = [];
  const seenRoomIds = new Set();
  const pushModel = (model) => {
    const roomId = String(model && model.roomId ? model.roomId : "");
    if (!roomId || seenRoomIds.has(roomId)) return;
    seenRoomIds.add(roomId);
    out.push(model);
  };

  const liveList = Array.isArray(liveData.list) ? liveData.list : [];
  for (const item of liveList) {
    const model = _ks_searchToRoomModel(item);
    if (model) pushModel(model);
  }

  return out;
}

async function _ks_getRoomDetail(roomId) {
  const liveData = await _ks_getLiveRoom(roomId);
  const current = _ks_pickCurrentPlayItem(liveData);
  if (!current) {
    _ks_throw("NOT_FOUND", `room not found: ${roomId}`, { roomId: String(roomId) });
  }

  const author = current.author || {};
  const playUrls = current.liveStream && current.liveStream.playUrls;
  const h264List = playUrls && playUrls.h264 && playUrls.h264.adaptationSet && playUrls.h264.adaptationSet.representation;
  const hevcList = playUrls && playUrls.hevc && playUrls.hevc.adaptationSet && playUrls.hevc.adaptationSet.representation;
  const hasH264 = Array.isArray(h264List) && h264List.length > 0;
  const hasHevc = Array.isArray(hevcList) && hevcList.length > 0;
  const hasStream = hasH264 || hasHevc;
  const liveState = ((current.isLiving === undefined ? hasStream : !!current.isLiving) ? "1" : "0");

  const roomTitle = String((author && author.description) || (current.gameInfo && current.gameInfo.name) || (author && author.name) || "");
  const resolvedId = String((author && author.id) || roomId);

  return {
    userName: String((author && author.name) || ""),
    roomTitle,
    roomCover: String((current.liveStream && current.liveStream.poster) || (author && author.avatar) || ""),
    userHeadImg: String((author && author.avatar) || ""),
    liveType: "5",
    liveState,
    userId: resolvedId,
    roomId: resolvedId,
    liveWatchedCount: String((current.gameInfo && current.gameInfo.watchingCount) || "")
  };
}

async function _ks_getPlayback(roomId) {
  const liveData = await _ks_getLiveRoom(roomId, "platform_cookie");
  const current = _ks_pickCurrentPlayItem(liveData);
  if (!current) {
    _ks_throw("BLOCKED", "room not live or verification needed", { roomId: String(roomId) });
  }

  const playUrls = current.liveStream && current.liveStream.playUrls;
  if (!playUrls) {
    _ks_throw("INVALID_RESPONSE", "playUrls is empty", { roomId: String(roomId) });
  }

  let qualityDetails = [];
  if (playUrls.h264) {
    qualityDetails = qualityDetails.concat(_ks_makeQualityDetails(playUrls.h264, roomId, "H264"));
  }
  if (playUrls.hevc) {
    qualityDetails = qualityDetails.concat(_ks_makeQualityDetails(playUrls.hevc, roomId, "HEVC"));
  }
  qualityDetails = _ks_sortQualityDetails(qualityDetails);

  if (qualityDetails.length === 0) {
    const hlsUrl = String(current.liveStream && current.liveStream.hlsPlayUrl ? current.liveStream.hlsPlayUrl : "");
    if (hlsUrl) {
      qualityDetails.push({
        roomId: String(roomId),
        title: "默认_HLS",
        qn: 0,
        url: hlsUrl,
        liveCodeType: "m3u8",
        liveType: "5",
        userAgent: __lp_ks_playbackUserAgent,
        headers: __lp_ks_playbackHeaders
      });
    }
  }

  if (qualityDetails.length === 0) {
    _ks_throw("INVALID_RESPONSE", "empty quality details", { roomId: String(roomId) });
  }
  return [{ cdn: "线路1", qualitys: qualityDetails }];
}

async function _ks_resolveShare(shareCode) {
  const trimmed = String(shareCode || "").trim();
  if (!trimmed) _ks_throw("INVALID_ARGS", "shareCode is empty", { field: "shareCode" });

  const shortUrl = _ks_extractShortLink(trimmed);
  if (shortUrl) {
    const resp = await _ks_platformRequest({
      url: shortUrl,
      method: "GET",
      timeout: 20
    });
    const finalUrl = String(resp.url || shortUrl);

    const liveId = _ks_extractLiveId(finalUrl);
    if (liveId) return await _ks_getRoomDetail(liveId);

    const userId = _ks_extractUserId(finalUrl);
    if (userId) return await _ks_getRoomDetail(userId);

    _ks_throw("NOT_FOUND", "cannot resolve room id from short link", { finalUrl: String(finalUrl) });
  }

  if (trimmed.includes("live.kuaishou.com")) {
    const userId = _ks_extractUserId(trimmed);
    if (userId) return await _ks_getRoomDetail(userId);

    const liveId = _ks_extractLiveId(trimmed);
    if (liveId) return await _ks_getRoomDetail(liveId);
  }

  if (_ks_isValidRoomId(trimmed)) {
    return await _ks_getRoomDetail(trimmed);
  }

  _ks_throw("NOT_FOUND", "cannot resolve room id from shareCode", { shareCode: String(shareCode || "") });
}

globalThis.LiveParsePlugin = {
  apiVersion: 1,

  async getCategories() {
    const categories = [
      ["1", "热门"],
      ["2", "网游"],
      ["3", "单机"],
      ["4", "手游"],
      ["5", "棋牌"],
      ["6", "娱乐"],
      ["7", "综合"],
      ["8", "文化"]
    ];

    const result = [];
    for (const item of categories) {
      const id = item[0];
      const title = item[1];
      const subList = await _ks_getCategorySubList(id);
      result.push({ id, title, icon: "", biz: "", subList });
    }
    return result;
  },

  async getRooms(payload) {
    const id = String(payload && payload.id ? payload.id : "");
    const page = payload && payload.page ? Number(payload.page) : 1;
    if (!id) _ks_throw("INVALID_ARGS", "id is required", { field: "id" });
    return await _ks_getRooms(id, page);
  },

  async getPlayback(payload) {
    const roomId = String(payload && payload.roomId ? payload.roomId : "");
    if (!roomId) _ks_throw("INVALID_ARGS", "roomId is required", { field: "roomId" });
    return await _ks_getPlayback(roomId);
  },

  async search(payload) {
    const keyword = String(payload && payload.keyword ? payload.keyword : "");
    const page = payload && payload.page ? Number(payload.page) : 1;
    return await _ks_search(keyword, page);
  },

  async getRoomDetail(payload) {
    const roomId = String(payload && payload.roomId ? payload.roomId : "");
    if (!roomId) _ks_throw("INVALID_ARGS", "roomId is required", { field: "roomId" });
    return await _ks_getRoomDetail(roomId);
  },

  async getLiveState(payload) {
    const roomId = String(payload && payload.roomId ? payload.roomId : "");
    const userId = String(payload && payload.userId ? payload.userId : "");
    if (!roomId) _ks_throw("INVALID_ARGS", "roomId is required", { field: "roomId" });
    const info = await this.getRoomDetail({ roomId, userId });
    return { liveState: String(info && info.liveState ? info.liveState : "3") };
  },

  async resolveShare(payload) {
    const shareCode = String(payload && payload.shareCode ? payload.shareCode : "");
    if (!shareCode) _ks_throw("INVALID_ARGS", "shareCode is required", { field: "shareCode" });
    return await _ks_resolveShare(shareCode);
  },

  async getDanmaku(payload) {
    const roomId = String(payload && payload.roomId ? payload.roomId : "");
    if (!roomId) _ks_throw("INVALID_ARGS", "roomId is required", { field: "roomId" });

    const roomBundle = await _ks_getLiveRoomBundle(roomId, "platform_cookie");
    const current = _ks_pickCurrentPlayItem(roomBundle.liveData);

    let liveStreamId = String(current && current.liveStream && current.liveStream.id ? current.liveStream.id : "");
    if (!liveStreamId) {
      liveStreamId = _ks_extractLiveStreamIdFallback(roomBundle.html);
    }

    if (!liveStreamId) {
      _ks_throw("NOT_FOUND", "liveStreamId not found", { roomId: String(roomId) });
    }

    return {
      args: {
        "_danmu_type": "http_polling",
        "_polling_url": "https://live.kuaishou.com/live_api/liveroom/recall",
        "_polling_method": "POST",
        "_polling_interval": "3000",
        "liveStreamId": liveStreamId,
        "feedTypeCursorMap": {
          "1": 0,
          "2": 0
        }
      },
      headers: {
        "Content-Type": "application/json",
        "Referer": "https://live.kuaishou.com/",
        "User-Agent": __lp_ks_ua
      }
    };
  }
};
