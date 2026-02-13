const __lp_yt_ua = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36";

function __lp_yt_toString(v) {
  return v === undefined || v === null ? "" : String(v);
}

function __lp_yt_unescapeUnicode(text) {
  return __lp_yt_toString(text).replace(/\\u([0-9A-Fa-f]{4})/g, function (_, hex) {
    return String.fromCharCode(parseInt(hex, 16));
  });
}

function __lp_yt_decodeEscapedURL(url) {
  let out = __lp_yt_toString(url);
  for (let i = 0; i < 2; i += 1) {
    out = __lp_yt_unescapeUnicode(out);
  }
  out = out.replace(/\\\//g, "/");
  return out;
}

function __lp_yt_extractMeta(html, key) {
  const escaped = key.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const re = new RegExp(`<meta[^>]+(?:property|name)=["']${escaped}["'][^>]+content=["']([^"']+)["']`, "i");
  const m = __lp_yt_toString(html).match(re);
  return m && m[1] ? __lp_yt_toString(m[1]) : "";
}

function __lp_yt_extractTitle(html) {
  const ogTitle = __lp_yt_extractMeta(html, "og:title");
  if (ogTitle) return ogTitle;

  const titleM = __lp_yt_toString(html).match(/<title>(.*?)<\/title>/i);
  if (titleM && titleM[1]) {
    return __lp_yt_toString(titleM[1]).replace(/\s*-\s*YouTube\s*$/i, "");
  }
  return "";
}

function __lp_yt_extractThumb(html) {
  const ogImage = __lp_yt_extractMeta(html, "og:image");
  if (ogImage) return ogImage;
  const m = __lp_yt_toString(html).match(/"thumbnailUrl"\s*:\s*\[\s*"([^"]+)"/);
  return m && m[1] ? __lp_yt_decodeEscapedURL(m[1]) : "";
}

function __lp_yt_extractHlsManifestURL(html) {
  const candidates = [
    /"hlsManifestUrl"\s*:\s*"([^"]+)"/,
    /hlsManifestUrl\\"\s*:\s*\\"([^\\]+)\\"/
  ];

  const source = __lp_yt_toString(html);
  for (const re of candidates) {
    const m = source.match(re);
    if (m && m[1]) {
      const url = __lp_yt_decodeEscapedURL(m[1]);
      if (url.startsWith("http")) return url;
    }
  }

  return "";
}

function __lp_yt_extractVideoIdFromText(input) {
  const text = __lp_yt_toString(input).trim();
  if (!text) return "";

  if (/^[A-Za-z0-9_-]{11}$/.test(text)) {
    return text;
  }

  let m = text.match(/[?&]v=([A-Za-z0-9_-]{6,})/);
  if (m && m[1]) return __lp_yt_toString(m[1]);

  m = text.match(/\/live\/([A-Za-z0-9_-]{6,})/);
  if (m && m[1]) return __lp_yt_toString(m[1]);

  m = text.match(/youtu\.be\/([A-Za-z0-9_-]{6,})/);
  if (m && m[1]) return __lp_yt_toString(m[1]);

  return "";
}

async function __lp_yt_fetchWatchHTML(videoId) {
  const safeId = encodeURIComponent(__lp_yt_toString(videoId));
  const watchURL = `https://www.youtube.com/watch?v=${safeId}`;
  const resp = await Host.http.request({
    url: watchURL,
    method: "GET",
    headers: {
      "User-Agent": __lp_yt_ua,
      "Accept-Language": "en-US,en;q=0.9"
    },
    timeout: 20
  });

  const html = __lp_yt_toString(resp && resp.bodyText);
  if (!html) {
    throw new Error("empty youtube watch html");
  }

  return { html, finalURL: __lp_yt_toString(resp && resp.url) || watchURL };
}

async function __lp_yt_getLiveLatestInfo(videoId) {
  const { html } = await __lp_yt_fetchWatchHTML(videoId);
  const title = __lp_yt_extractTitle(html) || videoId;
  const thumbnail = __lp_yt_extractThumb(html);
  const hlsURL = __lp_yt_extractHlsManifestURL(html);

  return {
    userName: title,
    roomTitle: title,
    roomCover: thumbnail,
    userHeadImg: thumbnail,
    liveType: "7",
    liveState: hlsURL ? "1" : "0",
    userId: "",
    roomId: __lp_yt_toString(videoId),
    liveWatchedCount: "-"
  };
}

async function __lp_yt_getPlayArgs(videoId) {
  const { html } = await __lp_yt_fetchWatchHTML(videoId);
  const hlsURL = __lp_yt_extractHlsManifestURL(html);
  if (!hlsURL) {
    throw new Error(`youtube livestream hlsManifestUrl not found: ${videoId}`);
  }

  return [{
    cdn: "默认线路",
    qualitys: [{
      roomId: __lp_yt_toString(videoId),
      title: "地址1",
      qn: 0,
      url: hlsURL,
      liveCodeType: "m3u8",
      liveType: "7"
    }]
  }];
}

globalThis.LiveParsePlugin = {
  apiVersion: 1,

  async getCategoryList() {
    return [];
  },

  async getRoomList(payload) {
    return [];
  },

  async getPlayArgs(payload) {
    const roomId = __lp_yt_toString(payload && payload.roomId);
    if (!roomId) throw new Error("roomId is required");
    return await __lp_yt_getPlayArgs(roomId);
  },

  async searchRooms(payload) {
    return [];
  },

  async getLiveLastestInfo(payload) {
    const roomId = __lp_yt_toString(payload && payload.roomId);
    if (!roomId) throw new Error("roomId is required");
    return await __lp_yt_getLiveLatestInfo(roomId);
  },

  async getLiveState(payload) {
    const info = await this.getLiveLastestInfo(payload || {});
    return { liveState: __lp_yt_toString((info && info.liveState) || "0") };
  },

  async getRoomInfoFromShareCode(payload) {
    const shareCode = __lp_yt_toString(payload && payload.shareCode);
    if (!shareCode) throw new Error("shareCode is required");

    let roomId = __lp_yt_extractVideoIdFromText(shareCode);
    if (!roomId) {
      const firstURL = (__lp_yt_toString(shareCode).match(/https?:\/\/[^\s|]+/) || [""])[0];
      if (firstURL) {
        const resp = await Host.http.request({
          url: firstURL,
          method: "GET",
          headers: { "User-Agent": __lp_yt_ua },
          timeout: 20
        });
        const finalURL = __lp_yt_toString((resp && resp.url) || firstURL);
        roomId = __lp_yt_extractVideoIdFromText(finalURL);
      }
    }

    if (!roomId) {
      throw new Error(`invalid youtube share code: ${shareCode}`);
    }

    return await __lp_yt_getLiveLatestInfo(roomId);
  },

  async getDanmukuArgs(payload) {
    return {
      args: {},
      headers: null
    };
  }
};
