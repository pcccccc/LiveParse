function __lp_tryDecodePercent(s) {
  try {
    return decodeURIComponent(s);
  } catch (e) {
    return s;
  }
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
  if (!m) throw new Error("HNF_GLOBAL_INIT not found");

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
  if (!input) throw new Error("shareCode is empty");

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

  throw new Error("roomId not found");
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
  const token = await Host.huya.getCdnTokenInfoEx(stream.sStreamName);
  const antiCode = __lp_buildAntiCode(stream.sStreamName, presenterUid, token);
  let url = `${stream.sFlvUrl}/${stream.sStreamName}.flv?${antiCode}&codec=264`;
  if (bitRate > 0) {
    url += `&ratio=${bitRate}`;
  }
  return url;
}

globalThis.LiveParsePlugin = {
  apiVersion: 1,
  async getRoomInfoFromShareCode(payload) {
    const shareCode = String(payload && payload.shareCode ? payload.shareCode : "");
    if (!shareCode) throw new Error("shareCode is required");
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
    if (!id) throw new Error("id is required");
    return await __lp_huya_getRoomList(id, page);
  },

  async searchRooms(payload) {
    const keyword = String(payload && payload.keyword ? payload.keyword : "");
    const page = (payload && payload.page) ? Number(payload.page) : 1;
    if (!keyword) throw new Error("keyword is required");
    return await __lp_huya_searchRooms(keyword, page);
  },

  async getLiveLastestInfo(payload) {
    const roomId = String(payload && payload.roomId ? payload.roomId : "");
    if (!roomId) throw new Error("roomId is required");

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
      throw new Error("missing liveInfo");
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
  async getDanmukuArgs(payload) {
    const roomId = String(payload && payload.roomId ? payload.roomId : "");
    if (!roomId) throw new Error("roomId is required");

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
      throw new Error("missing stream info");
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
    if (!roomId) throw new Error("roomId is required");

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
          const playUrl = await __lp_getPlayURL(s, topSid, br.iBitRate || 0);
          qualities.push({
            roomId,
            title: br.sDisplayName || "",
            qn: br.iBitRate || 0,
            url: playUrl,
            liveCodeType: "flv",
            liveType: "1"
          });
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

    throw new Error("empty result");
  }
};
