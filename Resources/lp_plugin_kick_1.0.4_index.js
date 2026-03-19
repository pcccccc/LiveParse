const _kick_liveType = "10";
const _kick_platformId = "kick";
const _kick_userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36";
const _kick_playbackUserAgent = "libmpv";
const _kick_playbackHeaders = {
  "User-Agent": _kick_playbackUserAgent,
  Referer: "https://kick.com/",
  Origin: "https://kick.com"
};
const _kick_defaultPageSize = 20;
const _kick_categoryCacheKey = "kick_categories_v1";
const _kick_categoryCacheTtlMs = 24 * 60 * 60 * 1000;
const _kick_fallbackCategories = [
  { id: "just-chatting", title: "Just Chatting" },
  { id: "slots-casino", title: "Slots & Casino" },
  { id: "call-of-duty", title: "Call of Duty" },
  { id: "league-of-legends", title: "League of Legends" },
  { id: "valorant", title: "VALORANT" }
];

function _kick_throw(code, message, context) {
  if (globalThis.Host && typeof Host.raise === "function") {
    Host.raise(code, message, context || {});
  }
  if (globalThis.Host && typeof Host.makeError === "function") {
    throw Host.makeError(code || "UNKNOWN", message || "", context || {});
  }
  throw new Error(
    `LP_PLUGIN_ERROR:${JSON.stringify({
      code: String(code || "UNKNOWN"),
      message: String(message || ""),
      context: context || {}
    })}`
  );
}

function _kick_str(v) {
  return v === undefined || v === null ? "" : String(v);
}

function _kick_int(v, fallback) {
  const n = Number(v);
  return Number.isFinite(n) ? n : fallback;
}

function _kick_parseJSON(text, fallback) {
  try {
    return JSON.parse(_kick_str(text));
  } catch (_) {
    return fallback;
  }
}

function _kick_parseURLPathSlug(input) {
  const value = _kick_str(input).trim();
  if (!value) return "";

  const withoutAt = value.replace(/^@+/, "");
  if (/^[a-z0-9_\-]{2,60}$/i.test(withoutAt)) {
    return withoutAt.toLowerCase();
  }

  const m = value.match(/kick\.com\/([a-z0-9_\-]{2,60})/i);
  if (m && m[1]) return _kick_str(m[1]).toLowerCase();

  const m2 = value.match(/\/([a-z0-9_\-]{2,60})(?:\?|#|$)/i);
  if (m2 && m2[1]) return _kick_str(m2[1]).toLowerCase();

  return "";
}

function _kick_pickArray(obj, keys) {
  for (const key of keys) {
    const val = obj && obj[key];
    if (Array.isArray(val)) return val;
  }
  return [];
}

function _kick_pickLiveStream(channelObj) {
  if (!channelObj || typeof channelObj !== "object") return null;
  if (channelObj.livestream && typeof channelObj.livestream === "object") {
    return channelObj.livestream;
  }
  if (channelObj.live_stream && typeof channelObj.live_stream === "object") {
    return channelObj.live_stream;
  }
  if (channelObj.metadata || channelObj.playback_url || channelObj.thumbnail_url) {
    return {
      session_title: _kick_str(channelObj && channelObj.metadata && channelObj.metadata.title),
      title: _kick_str(channelObj && channelObj.metadata && channelObj.metadata.title),
      viewer_count: _kick_int(channelObj && channelObj.viewers_count, 0),
      thumbnail: _kick_str(channelObj && channelObj.thumbnail_url),
      playback_url: _kick_str(channelObj && channelObj.playback_url),
      category: (channelObj && channelObj.metadata && channelObj.metadata.category) || null,
      started_at: _kick_str(channelObj && channelObj.started_at)
    };
  }
  return null;
}

function _kick_pickCategoryFromChannel(channelObj, livestreamObj) {
  if (livestreamObj && livestreamObj.category && typeof livestreamObj.category === "object") {
    return livestreamObj.category;
  }

  const fromLive = _kick_pickArray(livestreamObj || {}, ["categories", "recent_categories"]);
  if (fromLive.length > 0) return fromLive[0];

  const fromChannel = _kick_pickArray(channelObj || {}, ["recent_categories", "categories"]);
  if (fromChannel.length > 0) return fromChannel[0];

  return null;
}

function _kick_categoryToModel(raw) {
  const id = _kick_str(raw && (raw.slug || raw.id || raw.category_id)).trim();
  const title = _kick_str(raw && (raw.name || raw.title || raw.display_name)).trim();
  if (!id || !title) return null;

  return {
    id: id,
    title: title,
    icon: _kick_str(raw && (raw.icon || (raw.banner && raw.banner.url) || raw.thumbnail || "")),
    biz: ""
  };
}

function _kick_toRoomModel(channelObj) {
  const channel = channelObj || {};
  const livestream = _kick_pickLiveStream(channel);
  const user = channel.user || (channel.streamer && channel.streamer.user) || {};

  const roomId = _kick_str(channel.slug || channel.name || channel.id);
  const category = _kick_pickCategoryFromChannel(channel, livestream);
  const categoryId = _kick_str(category && (category.slug || category.id || category.category_id));

  return {
    userName: _kick_str(user.username || roomId),
    roomTitle: _kick_str((livestream && (livestream.session_title || livestream.title)) || ""),
    roomCover: _kick_str((livestream && (livestream.thumbnail || livestream.preview_image)) || ""),
    userHeadImg: _kick_str(user.profilepic || user.profile_pic || ""),
    liveType: _kick_liveType,
    liveState: livestream ? "1" : "0",
    userId: _kick_str(channel.id || user.id || roomId),
    roomId: roomId,
    liveWatchedCount: _kick_str((livestream && (livestream.viewer_count || livestream.viewers || livestream.watch_count)) || 0),
    biz: categoryId
  };
}

function _kick_categoryMatch(channelObj, targetId) {
  const target = _kick_str(targetId).trim().toLowerCase();
  if (!target || target === "all" || target === "root") return true;

  const livestream = _kick_pickLiveStream(channelObj);
  const candidates = [];

  const pushCategory = function (cat) {
    if (!cat || typeof cat !== "object") return;
    candidates.push(_kick_str(cat.slug).toLowerCase());
    candidates.push(_kick_str(cat.name).toLowerCase());
    candidates.push(_kick_str(cat.id).toLowerCase());
    candidates.push(_kick_str(cat.category_id).toLowerCase());
  };

  if (livestream && livestream.category && typeof livestream.category === "object") {
    pushCategory(livestream.category);
  }

  _kick_pickArray(livestream || {}, ["categories", "recent_categories"]).forEach(pushCategory);
  _kick_pickArray(channelObj || {}, ["recent_categories", "categories"]).forEach(pushCategory);

  return candidates.some(function (x) {
    return x && x === target;
  });
}

async function _kick_storageGet(key) {
  try {
    if (globalThis.Host && Host.storage && typeof Host.storage.get === "function") {
      return await Host.storage.get(key);
    }
  } catch (_) {}
  return null;
}

async function _kick_storageSet(key, value) {
  try {
    if (globalThis.Host && Host.storage && typeof Host.storage.set === "function") {
      await Host.storage.set(key, value);
    }
  } catch (_) {}
}

function _kick_pickRuntimeCookie(payload) {
  const runtimeCookie = _kick_str(payload && payload.cookie);
  const runtimeHeaders =
    payload && payload.headers && typeof payload.headers === "object"
      ? payload.headers
      : null;

  if (!runtimeCookie && runtimeHeaders) {
    return _kick_str(runtimeHeaders.cookie || runtimeHeaders.Cookie);
  }

  return runtimeCookie;
}

async function _kick_request(options, authMode) {
  const merged = Object.assign({}, options || {});
  const headers = Object.assign(
    {
      "User-Agent": _kick_userAgent,
      Accept: "application/json, text/plain, */*",
      Referer: "https://kick.com/",
      Origin: "https://kick.com"
    },
    (options && options.headers) || {}
  );
  if (!merged.timeout) merged.timeout = 20;

  if (authMode) {
    return await Host.http.request({
      platformId: _kick_platformId,
      authMode: authMode,
      request: {
        url: merged.url,
        method: merged.method || "GET",
        headers: headers,
        body: merged.body || null,
        timeout: merged.timeout
      }
    });
  }

  merged.headers = headers;
  return await Host.http.request(merged);
}

async function _kick_fetchJSON(url) {
  const resp = await _kick_request({
    url: url,
    method: "GET"
  });

  const body = _kick_parseJSON(resp && resp.bodyText, null);
  if (body === null || body === undefined) {
    _kick_throw("INVALID_RESPONSE", "invalid kick response json", { url: url });
  }
  return body;
}

function _kick_normalizeCategoryList(rawList, limit) {
  const maxCount = Math.max(1, Math.min(500, _kick_int(limit, 200)));
  const list = Array.isArray(rawList) ? rawList : [];
  const result = [];
  const seen = new Set();

  for (const raw of list) {
    const item = _kick_categoryToModel(raw);
    if (!item) continue;
    const key = _kick_str(item.id).toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    result.push(item);
    if (result.length >= maxCount) break;
  }

  return result;
}

async function _kick_loadCategoryCache(limit) {
  const raw = await _kick_storageGet(_kick_categoryCacheKey);
  const payload = typeof raw === "string" ? _kick_parseJSON(raw, null) : raw;
  if (!payload || typeof payload !== "object") {
    return { fresh: false, categories: [] };
  }

  const updatedAt = _kick_int(payload.updatedAt, 0);
  const age = Date.now() - updatedAt;
  const categories = _kick_normalizeCategoryList(payload.categories, limit);

  return {
    fresh: updatedAt > 0 && age >= 0 && age <= _kick_categoryCacheTtlMs,
    categories: categories
  };
}

async function _kick_saveCategoryCache(categories) {
  const normalized = _kick_normalizeCategoryList(categories, 500);
  if (!normalized.length) return;

  await _kick_storageSet(
    _kick_categoryCacheKey,
    JSON.stringify({
      version: "1",
      updatedAt: Date.now(),
      categories: normalized
    })
  );
}

function _kick_extractCategoryArray(payload) {
  if (Array.isArray(payload)) return payload;
  if (!payload || typeof payload !== "object") return [];

  const direct = _kick_pickArray(payload, ["categories", "items", "result", "data"]);
  if (direct.length > 0) return direct;

  if (payload.data && typeof payload.data === "object") {
    return _kick_pickArray(payload.data, ["categories", "items", "result", "data"]);
  }

  return [];
}

async function _kick_fetchCategories(limit) {
  const maxCount = Math.max(20, Math.min(300, _kick_int(limit, 120)));
  const attempts = [
    "https://api.kick.com/private/v1/categories?limit=" + encodeURIComponent(String(maxCount)),
    "https://kick.com/api/v1/categories",
    "https://kick.com/api/v1/categories/top"
  ];

  for (const endpoint of attempts) {
    try {
      const obj = await _kick_fetchJSON(endpoint);
      const categories = _kick_normalizeCategoryList(_kick_extractCategoryArray(obj), maxCount);
      if (categories.length > 0) return categories;
    } catch (_) {
      continue;
    }
  }

  return [];
}

function _kick_extractChannelArray(payload) {
  if (Array.isArray(payload)) return payload;
  if (!payload || typeof payload !== "object") return [];

  for (const key of ["data", "livestreams", "channels", "result"]) {
    const candidate = payload[key];
    if (Array.isArray(candidate)) return candidate;
    if (candidate && typeof candidate === "object") {
      for (const nestedKey of ["data", "items", "livestreams", "channels"]) {
        if (Array.isArray(candidate[nestedKey])) return candidate[nestedKey];
      }
    }
  }

  return [];
}

function _kick_pickChannelFromItem(item) {
  if (!item || typeof item !== "object") return null;

  if (item.data && item.data.account && item.data.account.channel) {
    const ch = Object.assign({}, item.data.account.channel);
    ch.user = item.data.account.user || ch.user || {};
    return ch;
  }

  if (item.account && item.account.channel) {
    const ch = Object.assign({}, item.account.channel);
    ch.user = item.account.user || ch.user || {};
    return ch;
  }

  if (item.streamer && item.metadata) {
    const ch = Object.assign({}, (item.streamer && item.streamer.channel) || {});
    ch.user = (item.streamer && item.streamer.user) || {};
    ch.streamer = item.streamer;
    ch.livestream = {
      id: _kick_str(item.id),
      session_title: _kick_str(item.metadata && item.metadata.title),
      title: _kick_str(item.metadata && item.metadata.title),
      viewer_count: _kick_int(item.viewers_count, 0),
      thumbnail: _kick_str(item.thumbnail_url),
      playback_url: _kick_str(item.playback_url),
      category: (item.metadata && item.metadata.category) || null,
      categories: item.metadata && item.metadata.category ? [item.metadata.category] : [],
      started_at: _kick_str(item.started_at)
    };
    return ch;
  }

  if (item.channel && typeof item.channel === "object") {
    const merged = Object.assign({}, item.channel);
    if (item.livestream && !merged.livestream) {
      merged.livestream = item.livestream;
    }
    return merged;
  }

  if (item.slug || item.user || item.livestream || item.recent_categories) {
    return item;
  }

  return null;
}

async function _kick_fetchLiveChannels(page, pageSize) {
  const p = Math.max(1, _kick_int(page, 1));
  const size = Math.max(1, Math.min(100, _kick_int(pageSize, _kick_defaultPageSize)));
  const lang = "en";

  const attempts = [
    "https://api.kick.com/private/v1/livestreams?language=" + lang + "&page=" + encodeURIComponent(String(p)) + "&limit=" + encodeURIComponent(String(size)),
    "https://kick.com/stream/livestreams/" + lang + "?page=" + encodeURIComponent(String(p)) + "&limit=" + encodeURIComponent(String(size)),
    "https://kick.com/stream/livestreams/" + lang + "?page=" + encodeURIComponent(String(p))
  ];

  for (const endpoint of attempts) {
    try {
      const obj = await _kick_fetchJSON(endpoint);
      const channels = _kick_extractChannelArray(obj)
        .map(_kick_pickChannelFromItem)
        .filter(function (x) {
          return !!x;
        });
      if (channels.length > 0) return channels;
    } catch (_) {
      continue;
    }
  }

  return [];
}

async function _kick_findLiveBySlug(slug, maxPages) {
  const target = _kick_parseURLPathSlug(slug);
  if (!target) return null;

  const pages = Math.max(1, Math.min(8, _kick_int(maxPages, 4)));
  for (let page = 1; page <= pages; page += 1) {
    let channels = [];
    try {
      channels = await _kick_fetchLiveChannels(page, 50);
    } catch (_) {
      continue;
    }

    for (const channel of channels) {
      const id = _kick_parseURLPathSlug(channel && channel.slug);
      if (id && id === target) return channel;
    }
  }

  return null;
}

async function _kick_searchChannels(keyword) {
  const q = _kick_str(keyword).trim();
  if (!q) return [];

  const attempts = [
    "https://kick.com/api/search?searched_word=" + encodeURIComponent(q),
    "https://kick.com/api/search?query=" + encodeURIComponent(q)
  ];

  for (const endpoint of attempts) {
    try {
      const obj = await _kick_fetchJSON(endpoint);
      const channels = _kick_extractChannelArray(obj)
        .map(_kick_pickChannelFromItem)
        .filter(function (x) {
          return !!x;
        });
      if (channels.length > 0) return channels;
    } catch (_) {
      continue;
    }
  }

  // Fallback: filter active livestream list when search endpoint is blocked.
  const result = [];
  const seen = new Set();
  const qLower = q.toLowerCase();
  for (let page = 1; page <= 5; page += 1) {
    let channels = [];
    try {
      channels = await _kick_fetchLiveChannels(page, 50);
    } catch (_) {
      continue;
    }

    for (const channel of channels) {
      const room = _kick_toRoomModel(channel);
      const hitText = [
        _kick_str(room.userName),
        _kick_str(room.roomId),
        _kick_str(room.roomTitle)
      ].join(" ").toLowerCase();

      if (hitText.indexOf(qLower) < 0) continue;
      const key = _kick_str(room.roomId).toLowerCase();
      if (!key || seen.has(key)) continue;
      seen.add(key);
      result.push(channel);
    }

    if (result.length >= 100) break;
  }

  if (result.length > 0) return result;

  return [];
}

async function _kick_fetchChannelBySlug(slug) {
  const value = _kick_parseURLPathSlug(slug);
  if (!value) {
    _kick_throw("INVALID_ARGS", "roomId/userId is required", { slug: slug });
  }

  const attempts = [
    "https://api.kick.com/private/v1/channels/" + encodeURIComponent(value),
    "https://kick.com/api/v2/channels/" + encodeURIComponent(value)
  ];

  for (const endpoint of attempts) {
    try {
      const obj = await _kick_fetchJSON(endpoint);
      const channel = _kick_pickChannelFromItem(obj);
      if (channel && (_kick_str(channel.slug) || _kick_str(channel.id))) {
        return channel;
      }
    } catch (_) {
      continue;
    }
  }

  _kick_throw("NOT_FOUND", "channel not found", { slug: value });
}

async function _kick_fetchChannelLivestreamBySlug(slug) {
  const value = _kick_parseURLPathSlug(slug);
  if (!value) return null;

  const endpoint = "https://api.kick.com/private/v1/channels/" + encodeURIComponent(value) + "/livestream";
  try {
    const obj = await _kick_fetchJSON(endpoint);
    const raw = obj && obj.data ? obj.data : obj;
    if (raw && raw.livestream && typeof raw.livestream === "object") {
      return raw.livestream;
    }
  } catch (_) {}

  return null;
}

async function _kick_roomDetailFromPayload(payload) {
  const roomId = _kick_str(payload && payload.roomId);
  const userId = _kick_str(payload && payload.userId);
  const slug = _kick_parseURLPathSlug(roomId || userId);
  const channel = await _kick_fetchChannelBySlug(slug);

  if (!_kick_pickLiveStream(channel)) {
    const liveFromChannel = await _kick_fetchChannelLivestreamBySlug(slug);
    if (liveFromChannel && typeof liveFromChannel === "object") {
      channel.livestream = {
        id: _kick_str(liveFromChannel.id),
        session_title: _kick_str(liveFromChannel.metadata && liveFromChannel.metadata.title),
        title: _kick_str(liveFromChannel.metadata && liveFromChannel.metadata.title),
        viewer_count: _kick_int(liveFromChannel.viewers_count, 0),
        thumbnail: _kick_str(liveFromChannel.thumbnail_url),
        playback_url: _kick_str(liveFromChannel.playback_url),
        category: (liveFromChannel.metadata && liveFromChannel.metadata.category) || null,
        categories: liveFromChannel.metadata && liveFromChannel.metadata.category ? [liveFromChannel.metadata.category] : []
      };
    }
  }

  if ((!channel.livestream || !_kick_str(channel.livestream.playback_url)) && slug) {
    const liveFromList = await _kick_findLiveBySlug(slug, 6);
    if (liveFromList && _kick_pickLiveStream(liveFromList)) {
      channel.livestream = _kick_pickLiveStream(liveFromList);
      if (!channel.user || !_kick_str(channel.user.username)) {
        channel.user = liveFromList.user || channel.user || {};
      }
    }
  }

  return channel;
}

function _kick_extractPlaybackURL(payload) {
  if (!payload || typeof payload !== "object") return "";

  const directCandidates = [
    payload.playback_url,
    payload.playbackUrl,
    payload.url,
    payload.hls,
    payload.hls_url
  ];
  for (const val of directCandidates) {
    const text = _kick_str(val).trim();
    if (/^https?:\/\/.+\.m3u8/i.test(text)) return text;
  }

  const nested = payload.data && typeof payload.data === "object" ? payload.data : null;
  if (nested) {
    return _kick_extractPlaybackURL(nested);
  }

  return "";
}

async function _kick_tryFetchSignedPlaybackURL(slug, payload) {
  const value = _kick_parseURLPathSlug(slug);
  if (!value) return "";

  const runtimeCookie = _kick_pickRuntimeCookie(payload);
  const runtimeHeaders =
    payload && payload.headers && typeof payload.headers === "object"
      ? payload.headers
      : {};
  const headers = Object.assign({}, runtimeHeaders);
  if (runtimeCookie) {
    headers.cookie = runtimeCookie;
  }

  const attempts = [
    {
      url: "https://kick.com/api/v2/channels/" + encodeURIComponent(value) + "/playback-url",
      authMode: runtimeCookie ? "platform_cookie" : null
    },
    {
      url: "https://kick.com/api/v2/channels/" + encodeURIComponent(value) + "/livestream",
      authMode: runtimeCookie ? "platform_cookie" : null
    }
  ];

  for (const attempt of attempts) {
    try {
      const resp = await _kick_request(
        {
          url: attempt.url,
          method: "GET",
          headers: headers
        },
        attempt.authMode
      );
      const obj = _kick_parseJSON(resp && resp.bodyText, null);
      const url = _kick_extractPlaybackURL(obj);
      if (url) return url;
    } catch (_) {
      continue;
    }
  }

  return "";
}

async function _kick_preflightPlaybackURL(url) {
  const target = _kick_str(url).trim();
  if (!target) return { ok: false, statusCode: 0, bodyText: "" };

  try {
    const resp = await _kick_request({
      url: target,
      method: "GET",
      headers: _kick_playbackHeaders,
      timeout: 15
    });

    const statusCode = _kick_int(resp && (resp.statusCode || resp.status), 0);
    return {
      ok: statusCode >= 200 && statusCode < 300,
      statusCode: statusCode,
      bodyText: _kick_str(resp && resp.bodyText)
    };
  } catch (error) {
    const message = _kick_str(error && error.message);
    return {
      ok: false,
      statusCode: 0,
      bodyText: message
    };
  }
}

function _kick_dedupeRooms(rooms) {
  const seen = new Set();
  const result = [];

  for (const room of rooms) {
    const key = _kick_str(room && room.roomId).toLowerCase();
    if (!key || seen.has(key)) continue;
    seen.add(key);
    result.push(room);
  }

  return result;
}

async function _kick_extractQualities(masterUrl, defaultQualityObj) {
  const result = [];
  try {
    const resp = await _kick_request({
      url: masterUrl,
      method: "GET",
      headers: _kick_playbackHeaders,
      timeout: 10
    });
    const text = _kick_str(resp && resp.bodyText);
    if (!text || text.indexOf("#EXTM3U") < 0) {
      return [defaultQualityObj];
    }

    const lines = text.split(/\r?\n/);
    let currentRes = "";
    let currentBandwidth = 0;

    for (const line of lines) {
      const l = line.trim();
      if (!l) continue;
      
      if (l.startsWith("#EXT-X-STREAM-INF:")) {
        const resMatch = l.match(/RESOLUTION=\d+x(\d+)/i);
        if (resMatch && resMatch[1]) {
          currentRes = resMatch[1] + "p";
        }
        const bwMatch = l.match(/BANDWIDTH=(\d+)/i);
        if (bwMatch && bwMatch[1]) {
          currentBandwidth = parseInt(bwMatch[1], 10);
        }
      } else if (!l.startsWith("#")) {
        if (currentRes || currentBandwidth > 0) {
          let chunkUrl = l;
          if (!chunkUrl.startsWith("http://") && !chunkUrl.startsWith("https://")) {
            const urlParts = masterUrl.split("?");
            const basePath = urlParts[0].substring(0, urlParts[0].lastIndexOf("/") + 1);
            chunkUrl = basePath + chunkUrl;
            if (urlParts.length > 1 && chunkUrl.indexOf("?") < 0) {
              const sep = chunkUrl.indexOf("?") < 0 ? "?" : "&";
              chunkUrl += sep + urlParts[1];
            }
          }
          
          let title = currentRes || (Math.round(currentBandwidth / 1000) + "kbps");
          let qn = parseInt(currentRes.replace("p", ""), 10) || currentBandwidth;
          
          result.push(Object.assign({}, defaultQualityObj, {
            title: title,
            qn: qn,
            url: chunkUrl
          }));
          
          currentRes = "";
          currentBandwidth = 0;
        }
      }
    }
  } catch (_) {}

  if (result.length > 0) {
    result.sort(function(a, b) { return b.qn - a.qn; });
    const autoObj = Object.assign({}, defaultQualityObj, {
      title: "Auto",
      qn: 10000,
      url: masterUrl
    });
    result.unshift(autoObj);
    return result;
  }
  
  return [defaultQualityObj];
}

globalThis.LiveParsePlugin = {
  apiVersion: 1,

  async getCategories() {
    const maxCategories = 150;
    const cache = await _kick_loadCategoryCache(maxCategories);
    let categories = [];

    if (cache.fresh && cache.categories.length > 0) {
      categories = cache.categories;
    } else {
      try {
        categories = await _kick_fetchCategories(maxCategories);
      } catch (_) {
        categories = [];
      }

      categories = _kick_normalizeCategoryList(categories, maxCategories);
      if (categories.length > 0) {
        await _kick_saveCategoryCache(categories);
      } else if (cache.categories.length > 0) {
        categories = cache.categories;
      } else {
        categories = _kick_fallbackCategories.map(function (x) {
          return { id: x.id, title: x.title, icon: "", biz: "" };
        });
      }
    }

    return [
      {
        id: "root",
        title: "Kick",
        icon: "",
        biz: "",
        subList: categories.map(function (item) {
          return {
            id: _kick_str(item.id),
            parentId: "root",
            title: _kick_str(item.title),
            icon: _kick_str(item.icon),
            biz: _kick_str(item.biz)
          };
        })
      }
    ];
  },

  async getRooms(payload) {
    const categoryId = _kick_str(payload && payload.id) || "all";
    const page = Math.max(1, _kick_int(payload && payload.page, 1));
    const pageSize = Math.max(1, Math.min(50, _kick_int(payload && payload.pageSize, _kick_defaultPageSize)));

    const channels = await _kick_fetchLiveChannels(page, pageSize * 2);
    const rooms = channels
      .filter(function (ch) {
        return _kick_categoryMatch(ch, categoryId);
      })
      .map(_kick_toRoomModel)
      .filter(function (room) {
        return _kick_str(room.roomId) && _kick_str(room.liveState) === "1";
      });

    return _kick_dedupeRooms(rooms).slice(0, pageSize);
  },

  async getPlayback(payload) {
    const runtimePayload = payload || {};
    const channel = await _kick_roomDetailFromPayload(runtimePayload);
    const livestream = _kick_pickLiveStream(channel);

    if (!livestream) {
      _kick_throw("NOT_LIVE", "channel is offline", {
        roomId: _kick_str(channel && channel.slug)
      });
    }

    let m3u8 = _kick_str(
      (livestream && (livestream.playback_url || livestream.source)) ||
        channel.playback_url ||
        ""
    );

    if (!m3u8) {
      m3u8 = await _kick_tryFetchSignedPlaybackURL(_kick_str(channel && channel.slug), runtimePayload);
    }

    if (!m3u8) {
      _kick_throw("INVALID_RESPONSE", "missing playback url", {
        roomId: _kick_str(channel && channel.slug)
      });
    }

    const preflight = await _kick_preflightPlaybackURL(m3u8);
    if (!preflight.ok) {
      const body = _kick_str(preflight.bodyText).toLowerCase();
      const tokenRejected = body.indexOf("invalid_playback_auth_token") >= 0;
      if (tokenRejected) {
        const signed = await _kick_tryFetchSignedPlaybackURL(_kick_str(channel && channel.slug), runtimePayload);
        if (signed && signed !== m3u8) {
          m3u8 = signed;
        }
      }
    }

    const finalCheck = await _kick_preflightPlaybackURL(m3u8);
    if (!finalCheck.ok) {
      _kick_throw("REQUIRES_AUTH", "kick playback is access-controlled and returned 403", {
        roomId: _kick_str(channel && channel.slug),
        statusCode: _kick_int(finalCheck.statusCode, 0),
        detail: _kick_str(finalCheck.bodyText).slice(0, 240),
        tip: "Try passing Kick web cookie in getPlayback payload.cookie"
      });
    }

    const defaultItem = {
      roomId: _kick_str(channel && channel.slug),
      title: "Auto",
      qn: 0,
      url: m3u8,
      liveCodeType: "m3u8",
      liveType: _kick_liveType,
      userAgent: _kick_playbackUserAgent,
      headers: _kick_playbackHeaders
    };

    const finalQualitys = await _kick_extractQualities(m3u8, defaultItem);

    return [
      {
        cdn: "kick",
        qualitys: finalQualitys
      }
    ];
  },

  async search(payload) {
    const keyword = _kick_str(payload && payload.keyword).trim();
    if (!keyword) {
      _kick_throw("INVALID_ARGS", "keyword is required", { field: "keyword" });
    }

    const page = Math.max(1, _kick_int(payload && payload.page, 1));
    const pageSize = Math.max(1, Math.min(50, _kick_int(payload && payload.pageSize, _kick_defaultPageSize)));

    const channels = await _kick_searchChannels(keyword);
    const rooms = _kick_dedupeRooms(
      channels
        .map(_kick_toRoomModel)
        .filter(function (room) {
          return _kick_str(room.roomId).length > 0;
        })
    );

    const start = (page - 1) * pageSize;
    return rooms.slice(start, start + pageSize);
  },

  async getRoomDetail(payload) {
    const channel = await _kick_roomDetailFromPayload(payload || {});
    return _kick_toRoomModel(channel);
  },

  async getLiveState(payload) {
    const detail = await this.getRoomDetail(payload || {});
    return {
      liveState: _kick_str(detail && detail.liveState ? detail.liveState : "3")
    };
  },

  async resolveShare(payload) {
    const shareCode = _kick_str(payload && payload.shareCode).trim();
    if (!shareCode) {
      _kick_throw("INVALID_ARGS", "shareCode is required", { field: "shareCode" });
    }

    const slug = _kick_parseURLPathSlug(shareCode);
    if (!slug) {
      _kick_throw("PARSE", "cannot parse kick shareCode", { shareCode: shareCode });
    }

    return await this.getRoomDetail({ roomId: slug });
  },

  async getDanmaku(payload) {
    const roomId = _kick_str(payload && payload.roomId);
    if (!roomId) {
      _kick_throw("INVALID_ARGS", "roomId is required for danmaku", { field: "roomId" });
    }
    
    // We need the chatroom ID to subscribe to the Pusher channel
    const channel = await _kick_fetchChannelBySlug(roomId);
    let chatroomId = "";
    if (channel && channel.chatroom && channel.chatroom.id) {
      chatroomId = _kick_str(channel.chatroom.id);
    } else if (channel && channel.chatroom_id) {
      chatroomId = _kick_str(channel.chatroom_id);
    }
    
    if (!chatroomId) {
       _kick_throw("NOT_FOUND", "chatroom_id not found for channel", { roomId: roomId });
    }

    return {
      args: {
        roomId: roomId,
        chatroomId: chatroomId,
        ws_url: "wss://ws-us2.pusher.com/app/32cbd69e4b950bf97679?protocol=7&client=js&version=7.6.0&flash=false"
      },
      headers: null
    };
  }
};
