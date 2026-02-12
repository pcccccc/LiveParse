function __lp_tryDecodePercent(s) {
  try {
    return decodeURIComponent(s);
  } catch (e) {
    return s;
  }
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

function __lp_isValidRoomId(roomId) {
  const s = String(roomId || "").trim();
  if (!/^\d+$/.test(s)) return false;
  const n = parseInt(s, 10);
  return Number.isFinite(n) && n > 0;
}

function __lp_firstMatch(text, re) {
  const m = String(text || "").match(re);
  if (!m || !m[1]) return "";
  return String(m[1]);
}

function __lp_extractFirstURL(text) {
  const m = String(text || "").match(/https?:\/\/[^\s|]+/);
  if (!m) return "";
  return String(m[0]).replace(/[),，。】]+$/g, "");
}

function __lp_generateRandomString(length) {
  const chars = "abcdefghijklmnopqrstuvwxyz0123456789";
  let out = "";
  for (let i = 0; i < length; i += 1) {
    out += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return out;
}

async function __lp_douyu_getCategoryList() {
  const resp = await Host.http.request({
    url: "https://m.douyu.com/api/cate/list",
    method: "GET",
    timeout: 20
  });
  const obj = JSON.parse(resp.bodyText || "{}");
  if ((obj && obj.code) !== 0) {
    throw new Error(`category code invalid: ${obj && obj.code}`);
  }

  const cate1Info = (obj && obj.data && obj.data.cate1Info) || [];
  const cate2Info = (obj && obj.data && obj.data.cate2Info) || [];

  return cate1Info.map(function (cate1) {
    const subList = cate2Info
      .filter(function (cate2) { return String(cate2.cate1Id || "") === String(cate1.cate1Id || ""); })
      .map(function (cate2) {
        return {
          id: String(cate2.cate2Id || ""),
          parentId: String(cate2.cate1Id || ""),
          title: String(cate2.cate2Name || ""),
          icon: String(cate2.icon || ""),
          biz: ""
        };
      });

    return {
      id: String(cate1.cate1Id || ""),
      title: String(cate1.cate1Name || ""),
      icon: "",
      biz: "",
      subList
    };
  });
}

async function __lp_douyu_getRoomList(id, page) {
  const url = `https://www.douyu.com/gapi/rkc/directory/mixList/2_${encodeURIComponent(String(id))}/${encodeURIComponent(String(page))}`;
  const resp = await Host.http.request({
    url,
    method: "GET",
    timeout: 20
  });
  const obj = JSON.parse(resp.bodyText || "{}");
  if ((obj && obj.code) !== 0) {
    throw new Error(`room list code invalid: ${obj && obj.code}`);
  }

  const list = (obj && obj.data && obj.data.rl) || [];
  return list
    .filter(function (item) { return Number(item.type || 0) === 1; })
    .map(function (item) {
      const av = String(item.av || "");
      const avMiddle = av ? `https://apic.douyucdn.cn/upload/${av}_middle.jpg` : "";
      return {
        userName: String(item.nn || ""),
        roomTitle: String(item.rn || ""),
        roomCover: String(item.rs16_avif || "") || avMiddle,
        userHeadImg: avMiddle,
        liveType: "3",
        liveState: "",
        userId: String(item.uid || "0"),
        roomId: String(item.rid || "0"),
        liveWatchedCount: String(item.ol || "0")
      };
    });
}

async function __lp_douyu_getLiveLatestInfo(roomId) {
  const url = `https://www.douyu.com/betard/${encodeURIComponent(String(roomId))}`;
  const resp = await Host.http.request({
    url,
    method: "GET",
    headers: {
      referer: `https://www.douyu.com/${String(roomId)}`,
      "user-agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36 Edg/114.0.1823.43"
    },
    timeout: 20
  });

  const obj = JSON.parse(resp.bodyText || "{}");
  const room = (obj && obj.room) || null;
  if (!room) throw new Error("missing room field");

  const showStatus = Number(room.show_status || -1);
  const videoLoop = Number(room.videoLoop || -1);

  let liveState = "0";
  if (showStatus === 1 && videoLoop === 0) {
    liveState = "1";
  } else if ((showStatus === 0 && videoLoop === 1) || (showStatus === 1 && videoLoop === 1)) {
    liveState = "2";
  } else {
    liveState = "0";
  }

  const roomBizAll = room.room_biz_all || {};
  return {
    userName: String(room.nickname || ""),
    roomTitle: String(room.room_name || ""),
    roomCover: String(room.room_pic || ""),
    userHeadImg: String(room.owner_avatar || ""),
    liveType: "3",
    liveState,
    userId: String(room.owner_id || "0"),
    roomId: String(roomId),
    liveWatchedCount: String(roomBizAll.hot || "")
  };
}

async function __lp_douyu_getSign(roomId) {
  const encResp = await Host.http.request({
    url: `https://www.douyu.com/swf_api/homeH5Enc?rids=${encodeURIComponent(String(roomId))}`,
    method: "GET",
    headers: {
      referer: `https://www.douyu.com/${String(roomId)}`,
      "user-agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36 Edg/114.0.1823.43"
    },
    timeout: 20
  });
  const encObj = JSON.parse(encResp.bodyText || "{}");
  const jsEnc = encObj && encObj.data && encObj.data[`room${String(roomId)}`];
  if (!jsEnc) throw new Error("missing js encryption code");

  let jsCode = String(jsEnc).replace(/return\s+eval/g, "return [strc, vdwdae325w_64we];");
  const m = jsCode.match(/(vdwdae325w_64we[\s\S]*function ub98484234[\s\S]*?)function/);
  if (!m || !m[1]) throw new Error("sign function not found");

  let encFunction = String(m[1]);
  encFunction = encFunction.replace(/eval.*?;\}/i, "strc;}");

  const jsRuntime = globalThis;
  let fnPair;
  try {
    fnPair = eval(`${encFunction};ub98484234();`);
  } catch (e) {
    throw new Error("execute encryption js failed");
  }

  if (!fnPair || !Array.isArray(fnPair) || fnPair.length < 2) {
    throw new Error("invalid encryption function result");
  }

  let signFun = String(fnPair[0] || "");
  const signV = String(fnPair[1] || "");
  if (!signFun || !signV) {
    throw new Error("sign function empty");
  }

  const tt = String(Math.floor(Date.now() / 1000));
  const did = Host.crypto.md5(tt);
  const rb = Host.crypto.md5(`${String(roomId)}${did}${tt}${signV}`);

  signFun = signFun.replace(/;+$/g, "").replace("CryptoJS.MD5(cb).toString()", `\"${rb}\"");
  signFun += `(\"${String(roomId)}\",\"${did}\",\"${tt}\");`;

  let paramsString = "";
  try {
    paramsString = String(eval(signFun) || "");
  } catch (e) {
    throw new Error("execute sign function failed");
  }

  const params = __lp_parseQueryString(paramsString);
  return params;
}

async function __lp_douyu_getRealPlayArgs(roomId, rate, cdn) {
  const params = await __lp_douyu_getSign(roomId);
  params.rate = String(rate || 0);
  if (cdn) params.cdn = String(cdn);

  const body = Object.keys(params)
    .map(function (k) { return `${encodeURIComponent(k)}=${encodeURIComponent(String(params[k] || ""))}`; })
    .join("&");

  const resp = await Host.http.request({
    url: `https://www.douyu.com/lapi/live/getH5Play/${encodeURIComponent(String(roomId))}`,
    method: "POST",
    headers: {
      referer: `https://www.douyu.com/${String(roomId)}`,
      "user-agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36 Edg/114.0.1823.43",
      "content-type": "application/x-www-form-urlencoded"
    },
    body,
    timeout: 20
  });

  const obj = JSON.parse(resp.bodyText || "{}");
  const data = obj && obj.data;
  if (!data) throw new Error("missing play data");

  const multirates = data.multirates || [];
  const cdns = data.cdnsWithName || [];
  const rtmpUrl = String(data.rtmp_url || "");
  const rtmpLive = String(data.rtmp_live || "");
  const playUrl = `${rtmpUrl}/${rtmpLive}`;

  const out = [];
  for (const cdnItem of cdns) {
    const serverCdn = String(cdnItem.cdn || "");
    if (cdn && serverCdn !== String(cdn)) continue;

    const qualitys = multirates.map(function (q) {
      return {
        roomId: String(roomId),
        title: String(q.name || ""),
        qn: Number(q.rate || 0),
        url: playUrl,
        liveCodeType: "flv",
        liveType: "3"
      };
    });

    out.push({
      cdn: String(cdnItem.name || ""),
      douyuCdnName: serverCdn,
      qualitys
    });
  }
  return out;
}

async function __lp_douyu_search(keyword, page) {
  const did = __lp_generateRandomString(32);
  const qs = [
    `kw=${encodeURIComponent(String(keyword))}`,
    `page=${encodeURIComponent(String(page))}`,
    "pageSize=20"
  ].join("&");

  const resp = await Host.http.request({
    url: `https://www.douyu.com/japi/search/api/searchShow?${qs}`,
    method: "GET",
    headers: {
      referer: "https://www.douyu.com/search/",
      "user-agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36 Edg/114.0.1823.43",
      Cookie: `dy_did=${did};acf_did=${did}`
    },
    timeout: 20
  });

  const obj = JSON.parse(resp.bodyText || "{}");
  const list = (obj && obj.data && obj.data.relateShow) || [];
  return list.map(function (item) {
    return {
      userName: String(item.nickName || ""),
      roomTitle: String(item.roomName || ""),
      roomCover: String(item.roomSrc || ""),
      userHeadImg: String(item.avatar || ""),
      liveType: "3",
      liveState: Number(item.roomType || 1) === 0 ? "1" : "0",
      userId: String(item.rid || ""),
      roomId: String(item.rid || ""),
      liveWatchedCount: String(item.hot || "")
    };
  });
}

async function __lp_douyu_resolveRoomIdFromShareCode(shareCode) {
  const input = String(shareCode || "").trim();
  if (!input) throw new Error("shareCode is empty");

  if (__lp_isValidRoomId(input)) return input;

  let roomId = "";
  if (input.includes("douyu.com")) {
    roomId = __lp_firstMatch(input, /douyu\.com\/(\d+)/);
    if (__lp_isValidRoomId(roomId)) return roomId;
    roomId = __lp_firstMatch(input, /rid=(\d+)/);
    if (__lp_isValidRoomId(roomId)) return roomId;
  }

  let candidateUrl = __lp_extractFirstURL(input);
  if (!candidateUrl) {
    if (input.startsWith("http")) {
      candidateUrl = input;
    } else if (input.includes("douyu")) {
      candidateUrl = `https://www.douyu.com/${input}`;
    }
  }

  if (candidateUrl) {
    const resp = await Host.http.request({
      url: candidateUrl,
      method: "GET",
      timeout: 20
    });

    roomId = __lp_firstMatch(resp.url || "", /(?:douyu\.com\/|rid=)(\d+)/);
    if (__lp_isValidRoomId(roomId)) return roomId;

    const html = String(resp.bodyText || "");
    const patterns = [
      /\"room_id\":\s*(\d+)/,
      /\"rid\":\s*\"?(\d+)/,
      /roomId\s*[:=]\s*\"?(\d+)/
    ];

    for (const p of patterns) {
      roomId = __lp_firstMatch(html, p);
      if (__lp_isValidRoomId(roomId)) return roomId;
    }
  }

  throw new Error("roomId not found");
}

globalThis.LiveParsePlugin = {
  apiVersion: 1,

  async getCategoryList() {
    return await __lp_douyu_getCategoryList();
  },

  async getRoomList(payload) {
    const id = String(payload && payload.id ? payload.id : "");
    const page = payload && payload.page ? Number(payload.page) : 1;
    if (!id) throw new Error("id is required");
    return await __lp_douyu_getRoomList(id, page);
  },

  async getPlayArgs(payload) {
    const roomId = String(payload && payload.roomId ? payload.roomId : "");
    if (!roomId) throw new Error("roomId is required");
    return await __lp_douyu_getRealPlayArgs(roomId, 0, null);
  },

  async getLiveLastestInfo(payload) {
    const roomId = String(payload && payload.roomId ? payload.roomId : "");
    if (!roomId) throw new Error("roomId is required");
    return await __lp_douyu_getLiveLatestInfo(roomId);
  },

  async getLiveState(payload) {
    const roomId = String(payload && payload.roomId ? payload.roomId : "");
    if (!roomId) throw new Error("roomId is required");
    const info = await __lp_douyu_getLiveLatestInfo(roomId);
    return {
      liveState: String(info && info.liveState ? info.liveState : "3")
    };
  },

  async searchRooms(payload) {
    const keyword = String(payload && payload.keyword ? payload.keyword : "");
    const page = payload && payload.page ? Number(payload.page) : 1;
    if (!keyword) throw new Error("keyword is required");
    return await __lp_douyu_search(keyword, page);
  },

  async getRoomInfoFromShareCode(payload) {
    const shareCode = String(payload && payload.shareCode ? payload.shareCode : "");
    if (!shareCode) throw new Error("shareCode is required");
    const roomId = await __lp_douyu_resolveRoomIdFromShareCode(shareCode);
    return await __lp_douyu_getLiveLatestInfo(roomId);
  },

  async getDanmukuArgs(payload) {
    const roomId = String(payload && payload.roomId ? payload.roomId : "");
    if (!roomId) throw new Error("roomId is required");
    return {
      args: {
        roomId: String(roomId)
      },
      headers: null
    };
  }
};
