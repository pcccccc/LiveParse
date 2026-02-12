const __lp_ks_categoryURL = "https://live.kuaishou.com/live_api/category/data";
const __lp_ks_gameListURL = "https://live.kuaishou.com/live_api/gameboard/list";
const __lp_ks_nonGameListURL = "https://live.kuaishou.com/live_api/non-gameboard/list";

function __lp_ks_firstMatch(text, re) {
  const m = String(text || "").match(re);
  if (!m || !m[1]) return "";
  return String(m[1]);
}

function __lp_ks_extractShortLink(text) {
  const m = String(text || "").match(/https:\/\/v\.kuaishou\.com\/[A-Za-z0-9]+/);
  return m ? String(m[0]) : "";
}

function __lp_ks_extractUserId(text) {
  return __lp_ks_firstMatch(text, /\/u\/([A-Za-z0-9_-]+)/);
}

function __lp_ks_extractLiveId(text) {
  return __lp_ks_firstMatch(text, /\/live\/([A-Za-z0-9_-]+)/);
}

function __lp_ks_isValidRoomId(roomId) {
  return /^[A-Za-z0-9_-]{3,}$/.test(String(roomId || ""));
}

function __lp_ks_roomListItemToLiveModel(item) {
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

function __lp_ks_makeQualityDetails(playUrl, roomId) {
  const adaptationSet = playUrl && playUrl.adaptationSet;
  const representation = adaptationSet && adaptationSet.representation;
  if (!Array.isArray(representation)) return [];

  return representation.map(function (rep) {
    return {
      roomId: String(roomId),
      title: String(rep && rep.name ? rep.name : ""),
      qn: Number(rep && rep.bitrate ? rep.bitrate : 0),
      url: String(rep && rep.url ? rep.url : ""),
      liveCodeType: "flv",
      liveType: "5"
    };
  }).filter(function (item) { return !!item.url; });
}

async function __lp_ks_getKSLiveRoom(roomId) {
  const url = `https://live.kuaishou.com/u/${encodeURIComponent(String(roomId))}`;
  const resp = await Host.http.request({
    url,
    method: "GET",
    headers: {
      "user-agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36"
    },
    timeout: 20
  });

  const html = String(resp.bodyText || "");
  const m = html.match(/<script>window\.__INITIAL_STATE__=\s*(.*?)\;/s);
  if (!m || !m[1]) {
    throw new Error("__INITIAL_STATE__ not found");
  }

  let jsonText = String(m[1]);
  jsonText = jsonText.replace(/:undefined/g, ':""');
  jsonText = jsonText.replace(/\\u([0-9A-Fa-f]{4})/g, function (_, hex) {
    return String.fromCharCode(parseInt(hex, 16));
  });

  return JSON.parse(jsonText);
}

async function __lp_ks_getCategorySubList(id) {
  let page = 1;
  let hasMore = true;
  const categoryList = [];

  while (hasMore) {
    const qs = [
      `type=${encodeURIComponent(String(id))}`,
      `page=${encodeURIComponent(String(page))}`,
      "pageSize=20"
    ].join("&");

    const resp = await Host.http.request({
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

async function __lp_ks_getRoomList(id, page) {
  const isNonGame = String(id || "").length >= 7;
  const url = isNonGame ? __lp_ks_nonGameListURL : __lp_ks_gameListURL;
  const qs = [
    "filterType=0",
    `page=${encodeURIComponent(String(page))}`,
    "pageSize=20",
    `gameId=${encodeURIComponent(String(id))}`
  ].join("&");

  const resp = await Host.http.request({
    url: `${url}?${qs}`,
    method: "GET",
    timeout: 20
  });
  const obj = JSON.parse(resp.bodyText || "{}");
  const list = obj && obj.data && obj.data.list ? obj.data.list : [];
  return list.map(__lp_ks_roomListItemToLiveModel);
}

async function __lp_ks_getLiveLatestInfo(roomId) {
  const liveData = await __lp_ks_getKSLiveRoom(roomId);
  const playList = liveData && liveData.liveroom && liveData.liveroom.playList;
  const current = Array.isArray(playList) && playList.length > 0 ? playList[0] : null;
  if (!current) {
    throw new Error(`room not found: ${roomId}`);
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

async function __lp_ks_getPlayArgs(roomId) {
  const liveData = await __lp_ks_getKSLiveRoom(roomId);
  const playList = liveData && liveData.liveroom && liveData.liveroom.playList;
  const current = Array.isArray(playList) && playList.length > 0 ? playList[0] : null;
  if (!current) {
    throw new Error("room not live or verification needed");
  }

  const playUrls = current.liveStream && current.liveStream.playUrls;
  if (!playUrls) {
    throw new Error("playUrls is empty");
  }

  let qualityDetails = [];
  if (playUrls.h264) {
    qualityDetails = qualityDetails.concat(__lp_ks_makeQualityDetails(playUrls.h264, roomId));
  }
  if (playUrls.hevc) {
    qualityDetails = qualityDetails.concat(__lp_ks_makeQualityDetails(playUrls.hevc, roomId));
  }

  if (qualityDetails.length === 0) {
    throw new Error("empty quality details");
  }
  return [{ cdn: "线路1", qualitys: qualityDetails }];
}

async function __lp_ks_resolveRoomInfoFromShareCode(shareCode) {
  const trimmed = String(shareCode || "").trim();
  if (!trimmed) throw new Error("shareCode is empty");

  const shortUrl = __lp_ks_extractShortLink(trimmed);
  if (shortUrl) {
    const resp = await Host.http.request({
      url: shortUrl,
      method: "GET",
      timeout: 20
    });
    const finalUrl = String(resp.url || shortUrl);

    const liveId = __lp_ks_extractLiveId(finalUrl);
    if (liveId) return await __lp_ks_getLiveLatestInfo(liveId);

    const userId = __lp_ks_extractUserId(finalUrl);
    if (userId) return await __lp_ks_getLiveLatestInfo(userId);

    throw new Error(`cannot resolve room id from short link: ${finalUrl}`);
  }

  if (trimmed.includes("live.kuaishou.com")) {
    const userId = __lp_ks_extractUserId(trimmed);
    if (userId) return await __lp_ks_getLiveLatestInfo(userId);

    const liveId = __lp_ks_extractLiveId(trimmed);
    if (liveId) return await __lp_ks_getLiveLatestInfo(liveId);
  }

  if (__lp_ks_isValidRoomId(trimmed)) {
    return await __lp_ks_getLiveLatestInfo(trimmed);
  }

  throw new Error("cannot resolve room id from shareCode");
}

globalThis.LiveParsePlugin = {
  apiVersion: 1,

  async getCategoryList() {
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
      const subList = await __lp_ks_getCategorySubList(id);
      result.push({ id, title, icon: "", biz: "", subList });
    }
    return result;
  },

  async getRoomList(payload) {
    const id = String(payload && payload.id ? payload.id : "");
    const page = payload && payload.page ? Number(payload.page) : 1;
    if (!id) throw new Error("id is required");
    return await __lp_ks_getRoomList(id, page);
  },

  async getPlayArgs(payload) {
    const roomId = String(payload && payload.roomId ? payload.roomId : "");
    if (!roomId) throw new Error("roomId is required");
    return await __lp_ks_getPlayArgs(roomId);
  },

  async searchRooms(payload) {
    const keyword = String(payload && payload.keyword ? payload.keyword : "");
    return [];
  },

  async getLiveLastestInfo(payload) {
    const roomId = String(payload && payload.roomId ? payload.roomId : "");
    if (!roomId) throw new Error("roomId is required");
    return await __lp_ks_getLiveLatestInfo(roomId);
  },

  async getLiveState(payload) {
    const roomId = String(payload && payload.roomId ? payload.roomId : "");
    const userId = String(payload && payload.userId ? payload.userId : "");
    if (!roomId) throw new Error("roomId is required");
    const info = await this.getLiveLastestInfo({ roomId, userId });
    return { liveState: String(info && info.liveState ? info.liveState : "3") };
  },

  async getRoomInfoFromShareCode(payload) {
    const shareCode = String(payload && payload.shareCode ? payload.shareCode : "");
    if (!shareCode) throw new Error("shareCode is required");
    return await __lp_ks_resolveRoomInfoFromShareCode(shareCode);
  },

  async getDanmukuArgs(payload) {
    const roomId = String(payload && payload.roomId ? payload.roomId : "");
    if (!roomId) throw new Error("roomId is required");
    return {
      args: {},
      headers: null
    };
  }
};
