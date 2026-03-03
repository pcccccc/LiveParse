const __yt_ua = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36";
const __yt_webClientName = "WEB";
const __yt_webClientVersionFallback = "2.20250201.00.00";
const __yt_androidClientName = "ANDROID";
const __yt_androidClientVersion = "19.45.36";
const __yt_iosClientName = "IOS";
const __yt_iosClientVersion = "20.03.02";
const __yt_tvClientName = "TVHTML5_SIMPLY_EMBEDDED_PLAYER";
const __yt_tvClientVersion = "2.0";
const __yt_iosPlaybackUserAgent = "com.google.ios.youtube/20.03.02 (iPhone16,2; U; CPU iOS 17_7_2 like Mac OS X;)";
const __yt_androidPlaybackUserAgent = "com.google.android.youtube/19.45.36 (Linux; U; Android 11) gzip";
const __yt_playbackUserAgent = __yt_ua;
const __yt_playbackHeaders = {
  "user-agent": __yt_playbackUserAgent,
  referer: "https://www.youtube.com/",
  origin: "https://www.youtube.com"
};
const __yt_youtubeiFallbackApiKey = "AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8";
const __yt_liveType = "7";
const __yt_liveHomeURL = "https://www.youtube.com/live";
const __yt_defaultPageSize = 20;
let __yt_debugLogEnabled = false;

function _yt_throw(code, message, context) {
  if (globalThis.Host && typeof Host.raise === "function") {
    Host.raise(code, message, context || {});
  }
  if (globalThis.Host && typeof Host.makeError === "function") {
    throw Host.makeError(code || "UNKNOWN", message || "", context || {});
  }
  throw new Error(
    "LP_PLUGIN_ERROR:" + JSON.stringify({
      code: String(code || "UNKNOWN"),
      message: String(message || ""),
      context: context || {}
    })
  );
}

function _yt_str(value) {
  return value === undefined || value === null ? "" : String(value);
}

function _yt_log(message) {
  if (!__yt_debugLogEnabled) return;
  if (globalThis.console && typeof console.log === "function") {
    console.log(_yt_str(message));
  }
}

function _yt_decodeText(text) {
  return _yt_str(text)
    .replace(/\\u([0-9A-Fa-f]{4})/g, function (_, hex) {
      return String.fromCharCode(parseInt(hex, 16));
    })
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'");
}

function _yt_decodeEscapedURL(url) {
  var out = _yt_str(url);
  for (var i = 0; i < 2; i += 1) {
    out = out.replace(/\\u([0-9A-Fa-f]{4})/g, function (_, hex) {
      return String.fromCharCode(parseInt(hex, 16));
    });
  }
  return out.replace(/\\\//g, "/");
}

function _yt_toInt(value, fallback) {
  var parsed = parseInt(_yt_str(value), 10);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function _yt_firstURL(text) {
  var match = _yt_str(text).match(/https?:\/\/[^\s"'<>|]+/);
  return match ? match[0] : "";
}

function _yt_textFromRuns(obj) {
  if (!obj || typeof obj !== "object") return "";
  if (typeof obj.simpleText === "string") return _yt_decodeText(obj.simpleText);
  if (Array.isArray(obj.runs)) {
    return _yt_decodeText(
      obj.runs
        .map(function (item) {
          return _yt_str(item && item.text);
        })
        .join("")
    );
  }
  return "";
}

function _yt_pickThumbnail(thumbnailObj) {
  var thumbs = thumbnailObj && thumbnailObj.thumbnails;
  if (!Array.isArray(thumbs) || thumbs.length === 0) return "";
  var last = thumbs[thumbs.length - 1] || {};
  var first = thumbs[0] || {};
  return _yt_str(last.url || first.url);
}

function _yt_collectByKey(root, key) {
  var out = [];
  var stack = [root];

  while (stack.length > 0) {
    var cur = stack.pop();
    if (!cur || typeof cur !== "object") continue;

    if (Array.isArray(cur)) {
      for (var i = 0; i < cur.length; i += 1) {
        stack.push(cur[i]);
      }
      continue;
    }

    if (Object.prototype.hasOwnProperty.call(cur, key)) {
      out.push(cur[key]);
    }

    var values = Object.values(cur);
    for (var j = 0; j < values.length; j += 1) {
      stack.push(values[j]);
    }
  }

  return out;
}

function _yt_extractObjectAfterMarker(source, marker) {
  var input = _yt_str(source);
  var idx = input.indexOf(marker);
  if (idx < 0) return null;

  var start = input.indexOf("{", idx + marker.length);
  if (start < 0) return null;

  var depth = 0;
  var inString = false;
  var escaped = false;

  for (var i = start; i < input.length; i += 1) {
    var ch = input[i];

    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (ch === "\\") {
        escaped = true;
      } else if (ch === '"') {
        inString = false;
      }
      continue;
    }

    if (ch === '"') {
      inString = true;
      continue;
    }

    if (ch === "{") {
      depth += 1;
      continue;
    }

    if (ch === "}") {
      depth -= 1;
      if (depth === 0) {
        return input.slice(start, i + 1);
      }
    }
  }

  return null;
}

function _yt_extractJSONAfterMarker(source, marker) {
  var jsonText = _yt_extractObjectAfterMarker(source, marker);
  if (!jsonText) return null;
  try {
    return JSON.parse(jsonText);
  } catch (_) {
    return null;
  }
}

function _yt_extractInitialData(html) {
  var markers = [
    "var ytInitialData = ",
    "window[\"ytInitialData\"] = ",
    "ytInitialData = "
  ];

  for (var i = 0; i < markers.length; i += 1) {
    var jsonText = _yt_extractObjectAfterMarker(html, markers[i]);
    if (!jsonText) continue;

    try {
      return JSON.parse(jsonText);
    } catch (_) {
      continue;
    }
  }

  _yt_throw("PARSE", "failed to extract ytInitialData", {});
}

function _yt_liveStatusOfRenderer(videoRenderer) {
  var badges = Array.isArray(videoRenderer && videoRenderer.badges) ? videoRenderer.badges : [];
  for (var i = 0; i < badges.length; i += 1) {
    var style = _yt_str(
      badges[i] && badges[i].metadataBadgeRenderer && badges[i].metadataBadgeRenderer.style
    );
    if (style === "BADGE_STYLE_TYPE_LIVE_NOW") return "live";
  }

  var overlays = Array.isArray(videoRenderer && videoRenderer.thumbnailOverlays)
    ? videoRenderer.thumbnailOverlays
    : [];
  for (var j = 0; j < overlays.length; j += 1) {
    var overlayStyle = _yt_str(
      overlays[j] && overlays[j].thumbnailOverlayTimeStatusRenderer && overlays[j].thumbnailOverlayTimeStatusRenderer.style
    );
    if (overlayStyle === "LIVE") return "live";
    if (overlayStyle === "UPCOMING") return "upcoming";
  }

  if (videoRenderer && videoRenderer.upcomingEventData) return "upcoming";

  var viewCountText = _yt_textFromRuns(videoRenderer && videoRenderer.viewCountText).toLowerCase();
  if (viewCountText.indexOf("watching") >= 0 || viewCountText.indexOf("正在观看") >= 0) {
    return "live";
  }

  return "none";
}

function _yt_extractChannelInfoFromRenderer(videoRenderer) {
  var ownerText =
    (videoRenderer && videoRenderer.ownerText) ||
    (videoRenderer && videoRenderer.longBylineText) ||
    (videoRenderer && videoRenderer.shortBylineText) ||
    null;

  var channelName = _yt_textFromRuns(ownerText);
  var channelId = "";
  var runs = Array.isArray(ownerText && ownerText.runs) ? ownerText.runs : [];

  for (var i = 0; i < runs.length; i += 1) {
    var browseId = _yt_str(
      runs[i] &&
        runs[i].navigationEndpoint &&
        runs[i].navigationEndpoint.browseEndpoint &&
        runs[i].navigationEndpoint.browseEndpoint.browseId
    );
    if (browseId.indexOf("UC") === 0) {
      channelId = browseId;
      break;
    }
  }

  return {
    channelName: channelName,
    channelId: channelId
  };
}

function _yt_videoRendererToItem(videoRenderer) {
  var videoId = _yt_str(videoRenderer && videoRenderer.videoId);
  var channelInfo = _yt_extractChannelInfoFromRenderer(videoRenderer || {});
  var status = _yt_liveStatusOfRenderer(videoRenderer || {});

  return {
    videoId: videoId,
    title: _yt_textFromRuns(videoRenderer && videoRenderer.title),
    channelName: channelInfo.channelName,
    channelId: channelInfo.channelId,
    status: status,
    isLiveNow: status === "live",
    thumbnail: _yt_pickThumbnail(videoRenderer && videoRenderer.thumbnail),
    viewCountText: _yt_textFromRuns(videoRenderer && videoRenderer.viewCountText),
    watchURL: videoId ? "https://www.youtube.com/watch?v=" + videoId : "",
    categories: []
  };
}

function _yt_toRoomModel(item) {
  var cover = _yt_str(item && item.thumbnail);
  var roomId = _yt_str(item && item.videoId);
  var liveState = item && item.isLiveNow ? "1" : "0";

  return {
    userName: _yt_str((item && item.channelName) || "YouTube"),
    roomTitle: _yt_str((item && item.title) || roomId),
    roomCover: cover,
    userHeadImg: cover,
    liveState: liveState,
    userId: _yt_str(item && item.channelId),
    roomId: roomId,
    liveWatchedCount: _yt_str(item && item.viewCountText)
  };
}

function _yt_extractMeta(html, key) {
  var escaped = _yt_str(key).replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  var regex = new RegExp(
    "<meta[^>]+(?:property|name)=[\"']" + escaped + "[\"'][^>]+content=[\"']([^\"']+)[\"']",
    "i"
  );
  var match = _yt_str(html).match(regex);
  return match && match[1] ? _yt_decodeText(match[1]) : "";
}

function _yt_extractWatchTitle(html, fallbackTitle) {
  var ogTitle = _yt_extractMeta(html, "og:title");
  if (ogTitle) return ogTitle;

  var titleMatch = _yt_str(html).match(/<title>(.*?)<\/title>/i);
  if (titleMatch && titleMatch[1]) {
    return _yt_decodeText(titleMatch[1]).replace(/\s*-\s*YouTube\s*$/i, "");
  }

  return _yt_str(fallbackTitle);
}

function _yt_extractWatchChannelInfo(html) {
  var source = _yt_str(html);
  var channelIdMatch = source.match(/"channelId":"(UC[A-Za-z0-9_-]+)"/);
  var ownerNameMatch = source.match(/"ownerChannelName":"([^\"]+)"/);

  return {
    channelId: channelIdMatch ? channelIdMatch[1] : "",
    channelName: _yt_decodeText(ownerNameMatch ? ownerNameMatch[1] : "")
  };
}

function _yt_extractWatchViewCount(html) {
  var source = _yt_str(html);
  var match =
    source.match(/"originalViewCount":"(\d+)"/) ||
    source.match(/"viewCount":"(\d+)"/);
  if (match && match[1]) {
    return match[1];
  }
  return "";
}

function _yt_extractWatchPlayerResponse(html) {
  var markers = [
    "var ytInitialPlayerResponse = ",
    "window[\"ytInitialPlayerResponse\"] = ",
    "ytInitialPlayerResponse = "
  ];

  for (var i = 0; i < markers.length; i += 1) {
    var parsed = _yt_extractJSONAfterMarker(html, markers[i]);
    if (parsed && typeof parsed === "object") {
      return parsed;
    }
  }

  return null;
}

function _yt_extractInnertubeApiKey(html) {
  var source = _yt_str(html);
  var match =
    source.match(/"INNERTUBE_API_KEY"\s*:\s*"([^"]+)"/) ||
    source.match(/INNERTUBE_API_KEY["']\s*:\s*["']([^"']+)["']/);
  return _yt_str(match && match[1]);
}

function _yt_extractInnertubeClientVersion(html) {
  var source = _yt_str(html);
  var match =
    source.match(/"INNERTUBE_CLIENT_VERSION"\s*:\s*"([^"]+)"/) ||
    source.match(/INNERTUBE_CLIENT_VERSION["']\s*:\s*["']([^"']+)["']/);
  return _yt_str(match && match[1]);
}

function _yt_extractVisitorData(html) {
  var source = _yt_str(html);
  var match =
    source.match(/"VISITOR_DATA"\s*:\s*"([^"]+)"/) ||
    source.match(/VISITOR_DATA["']\s*:\s*["']([^"']+)["']/);
  return _yt_str(match && match[1]);
}

function _yt_extractContinuationFromContinuationEntry(entry) {
  if (!entry || typeof entry !== "object") return "";
  if (_yt_str(entry.continuation)) return _yt_str(entry.continuation);

  var keys = [
    "reloadContinuationData",
    "invalidationContinuationData",
    "timedContinuationData",
    "liveChatReplayContinuationData"
  ];
  for (var i = 0; i < keys.length; i += 1) {
    var block = entry[keys[i]];
    var token = _yt_str(block && block.continuation);
    if (token) return token;
  }

  return "";
}

function _yt_pushUnique(out, seen, value) {
  var text = _yt_str(value);
  if (!text || seen[text]) return;
  seen[text] = true;
  out.push(text);
}

function _yt_extractLiveChatContinuation(playerResponse, initialData, html) {
  var out = [];
  var seen = {};

  function collectFromRoot(root) {
    if (!root || typeof root !== "object") return;

    var liveChatRenderers = _yt_collectByKey(root, "liveChatRenderer");
    for (var i = 0; i < liveChatRenderers.length; i += 1) {
      var renderer = liveChatRenderers[i];
      if (!renderer || typeof renderer !== "object") continue;
      var continuations = Array.isArray(renderer.continuations) ? renderer.continuations : [];
      for (var j = 0; j < continuations.length; j += 1) {
        _yt_pushUnique(out, seen, _yt_extractContinuationFromContinuationEntry(continuations[j]));
      }
    }

    var continuationBlocks = [
      _yt_collectByKey(root, "reloadContinuationData"),
      _yt_collectByKey(root, "invalidationContinuationData"),
      _yt_collectByKey(root, "timedContinuationData"),
      _yt_collectByKey(root, "liveChatReplayContinuationData")
    ];
    for (var k = 0; k < continuationBlocks.length; k += 1) {
      var blockList = continuationBlocks[k];
      for (var m = 0; m < blockList.length; m += 1) {
        _yt_pushUnique(out, seen, _yt_str(blockList[m] && blockList[m].continuation));
      }
    }
  }

  collectFromRoot(playerResponse);
  collectFromRoot(initialData);

  var source = _yt_str(html);
  var regex = /"continuation":"([^"]{20,})"/g;
  var match;
  while ((match = regex.exec(source)) !== null) {
    var token = _yt_str(match[1]);
    if (
      token.indexOf("live_chat") >= 0 ||
      token.indexOf("op2w") >= 0 ||
      token.indexOf("Cg") === 0
    ) {
      _yt_pushUnique(out, seen, token);
    }
  }

  return out.length > 0 ? out[0] : "";
}

function _yt_decodeManifestURL(url) {
  var out = _yt_decodeEscapedURL(url);
  out = _yt_decodeText(out);
  return _yt_str(out);
}

function _yt_collectManifestCandidatesFromPlayerResponse(playerResponse, sourceTag, expectedVideoId) {
  if (!playerResponse || typeof playerResponse !== "object") return [];

  var prVideoId =
    _yt_str(playerResponse.videoId) ||
    _yt_str(playerResponse.videoDetails && playerResponse.videoDetails.videoId);
  if (expectedVideoId && prVideoId && prVideoId !== expectedVideoId) {
    return [];
  }

  var streamingData = playerResponse.streamingData;
  if (!streamingData || typeof streamingData !== "object") {
    return [];
  }

  var urls = [
    _yt_str(streamingData.hlsManifestUrl),
    _yt_str(streamingData.hlsvp)
  ];
  var out = [];

  for (var i = 0; i < urls.length; i += 1) {
    var decoded = _yt_decodeManifestURL(urls[i]);
    if (decoded.indexOf("http") !== 0) continue;
    out.push({
      url: decoded,
      source: _yt_str(sourceTag),
      videoId: _yt_str(prVideoId)
    });
  }

  return out;
}

function _yt_collectManifestCandidatesFromLegacyHTML(html, expectedVideoId) {
  var source = _yt_str(html);
  var patterns = [
    /"hlsManifestUrl"\s*:\s*"([^"]+)"/g,
    /hlsManifestUrl\\"\s*:\s*\\"([^\\]+)\\"/g,
    /"hlsvp"\s*:\s*"([^"]+)"/g
  ];
  var out = [];
  var seen = {};

  for (var i = 0; i < patterns.length; i += 1) {
    var regex = patterns[i];
    var match;
    while ((match = regex.exec(source)) !== null) {
      if (!match || !match[1]) continue;
      var decoded = _yt_decodeManifestURL(match[1]);
      if (decoded.indexOf("http") !== 0) continue;
      if (seen[decoded]) continue;
      seen[decoded] = true;
      out.push({
        url: decoded,
        source: "watch_html_regex",
        videoId: _yt_str(expectedVideoId)
      });
    }
  }

  return out;
}

function _yt_expandManifestCandidates(candidates) {
  if (!Array.isArray(candidates) || candidates.length === 0) return [];

  var out = [];
  for (var i = 0; i < candidates.length; i += 1) {
    var base = candidates[i] || {};
    var baseURL = _yt_str(base.url);
    if (!baseURL) continue;
    out.push(base);

    // n 挑战在部分环境会导致 manifest 无法播放；先增加一个“去 n 段”候选作兜底。
    if (baseURL.indexOf("/n/") >= 0) {
      var stripped = baseURL.replace(/\/n\/[^/]+/, "");
      if (stripped && stripped !== baseURL) {
        out.push({
          url: stripped,
          source: _yt_str(base.source) + "_strip_n",
          videoId: _yt_str(base.videoId)
        });
      }
    }
  }

  return out;
}

function _yt_manifestCandidateScore(candidate, expectedVideoId) {
  var source = _yt_str(candidate && candidate.source);
  var url = _yt_str(candidate && candidate.url);
  var score = 0;

  if (source.indexOf("_strip_n") >= 0) score += 30;
  if (source.indexOf("youtubei_ios") >= 0) score += 260;
  else if (source.indexOf("youtubei_android") >= 0) score += 220;
  else if (source.indexOf("youtubei_web") >= 0) score += 210;
  else if (source.indexOf("youtubei_tv") >= 0) score += 190;
  else if (source.indexOf("watch_player_response") >= 0) score += 120;
  else if (source.indexOf("watch_html_regex") >= 0) score += 110;

  if (expectedVideoId) {
    if (url.indexOf("/id/" + expectedVideoId + ".") >= 0) score += 180;
    else if (url.indexOf("id=" + expectedVideoId) >= 0) score += 90;
  }

  if (url.indexOf("/source/yt_live_broadcast/") >= 0) score += 50;
  if (url.indexOf("/playlist_type/DVR/") >= 0) score += 20;
  if (url.indexOf("/ip/0.0.0.0/") >= 0) score += 120;
  // demuxed 链路切换子清晰度时更容易出现无声，优先选非 demuxed manifest。
  if (url.indexOf("/demuxed/1/") >= 0) score -= 260;

  var ipMatch = url.match(/\/ip\/([^/]+)\//);
  if (ipMatch && ipMatch[1]) {
    var ipToken = _yt_str(ipMatch[1]).toLowerCase();
    if (ipToken.indexOf(":") >= 0 || ipToken.indexOf("%3a") >= 0) score -= 420;
    else score += 30;
  }

  if (url.indexOf("/n/") >= 0) score -= 320;
  if (url.indexOf("manifest.googlevideo.com/api/manifest") >= 0) score += 20;

  return score;
}

function _yt_isIPv6BoundManifestURL(url) {
  var value = _yt_str(url);
  var ipMatch = value.match(/\/ip\/([^/]+)\//);
  if (!ipMatch || !ipMatch[1]) return false;
  var token = _yt_str(ipMatch[1]).toLowerCase();
  return token.indexOf(":") >= 0 || token.indexOf("%3a") >= 0;
}

function _yt_pickBestManifestCandidate(candidates, expectedVideoId) {
  if (!Array.isArray(candidates) || candidates.length === 0) return null;

  var sorted = _yt_sortManifestCandidates(candidates, expectedVideoId);
  return sorted.length > 0 ? sorted[0] : null;
}

function _yt_sortManifestCandidates(candidates, expectedVideoId) {
  if (!Array.isArray(candidates) || candidates.length === 0) return [];

  var expanded = _yt_expandManifestCandidates(candidates);
  var dedup = [];
  var seen = {};
  for (var i = 0; i < expanded.length; i += 1) {
    var item = expanded[i] || {};
    var url = _yt_str(item.url);
    if (!url || seen[url]) continue;
    seen[url] = true;
    dedup.push(item);
  }

  if (dedup.length === 0) return [];

  dedup.sort(function (lhs, rhs) {
    return _yt_manifestCandidateScore(rhs, expectedVideoId) - _yt_manifestCandidateScore(lhs, expectedVideoId);
  });

  return dedup;
}

function _yt_extractManifestFromWatchHTML(html, expectedVideoId) {
  var playerResponse = _yt_extractWatchPlayerResponse(html);
  var playerCandidates = _yt_collectManifestCandidatesFromPlayerResponse(
    playerResponse,
    "watch_player_response",
    expectedVideoId
  );
  var regexCandidates = _yt_collectManifestCandidatesFromLegacyHTML(html, expectedVideoId);
  var merged = playerCandidates.concat(regexCandidates);
  return _yt_pickBestManifestCandidate(merged, expectedVideoId);
}

function _yt_extractVideoIdFromText(input) {
  var text = _yt_str(input).trim();
  if (!text) return "";

  if (/^[A-Za-z0-9_-]{11}$/.test(text)) return text;

  var match = text.match(/[?&]v=([A-Za-z0-9_-]{11})/);
  if (match && match[1]) return match[1];

  match = text.match(/\/live\/([A-Za-z0-9_-]{11})/);
  if (match && match[1]) return match[1];

  match = text.match(/youtu\.be\/([A-Za-z0-9_-]{11})/);
  if (match && match[1]) return match[1];

  return "";
}

function _yt_inputToLiveURL(input) {
  var raw = _yt_str(input).trim();
  if (!raw) return "";

  if (raw.indexOf("http://") === 0 || raw.indexOf("https://") === 0) {
    return raw;
  }

  if (raw.charAt(0) === "@") {
    return "https://www.youtube.com/" + raw + "/live";
  }

  if (/^UC[A-Za-z0-9_-]+$/.test(raw)) {
    return "https://www.youtube.com/channel/" + raw + "/live";
  }

  return "";
}

function _yt_extractLiveVideoIdFromChannelHTML(html) {
  var source = _yt_str(html);
  var patterns = [
    /"videoId":"([A-Za-z0-9_-]{11})".{0,220}"isLiveNow":true/gs,
    /"videoId":"([A-Za-z0-9_-]{11})".{0,220}"BADGE_STYLE_TYPE_LIVE_NOW"/gs,
    /"videoId":"([A-Za-z0-9_-]{11})".{0,220}"LIVE"/gs
  ];

  for (var i = 0; i < patterns.length; i += 1) {
    var match = patterns[i].exec(source);
    if (match && match[1]) {
      return match[1];
    }
  }

  return "";
}

function _yt_extractCanonicalVideoId(html) {
  var source = _yt_str(html);
  var match = source.match(/<link rel="canonical" href="([^"]+)"/i);
  if (!match || !match[1]) return "";
  return _yt_extractVideoIdFromText(match[1]);
}

function _yt_parseM3U8Attributes(line) {
  var attrs = {};
  var re = /([A-Z0-9-]+)=(\"[^\"]+\"|[^,]*)(?:,|$)/g;
  var match;

  while ((match = re.exec(_yt_str(line))) !== null) {
    var key = _yt_str(match[1]);
    var raw = _yt_str(match[2]);
    attrs[key] = raw.replace(/^\"|\"$/g, "");
  }

  return attrs;
}

function _yt_parseResolutionHeight(resolution) {
  var match = _yt_str(resolution).match(/^(\d+)x(\d+)$/);
  if (!match) return 0;
  return _yt_toInt(match[2], 0);
}

function _yt_isPlaybackCodecCompatible(codecs) {
  var value = _yt_str(codecs).toLowerCase();
  if (!value) return true;
  // 优先返回 H.264，避免部分设备在 AV1/VP9 上出现加载超时。
  if (value.indexOf("avc1") >= 0) return true;
  if (value.indexOf("h264") >= 0) return true;
  return false;
}

function _yt_paginate(list, page, pageSize) {
  var safePage = Math.max(1, _yt_toInt(page, 1));
  var size = Math.max(1, _yt_toInt(pageSize, __yt_defaultPageSize));
  var start = (safePage - 1) * size;
  return list.slice(start, start + size);
}

function _yt_normalizeBool(value) {
  if (typeof value === "boolean") return value;
  var text = _yt_str(value).trim().toLowerCase();
  return text === "1" || text === "true" || text === "yes";
}

async function _yt_httpRequest(options) {
  return await Host.http.request(options || {});
}

async function _yt_fetchText(url, headers, timeoutSeconds) {
  var response = await _yt_httpRequest({
    url: url,
    method: "GET",
    headers: Object.assign(
      {
        "User-Agent": __yt_ua,
        "Accept-Language": "en-US,en;q=0.9"
      },
      headers || {}
    ),
    timeout: timeoutSeconds || 20
  });

  return {
    ok: _yt_toInt(response && response.status, 0) >= 200 && _yt_toInt(response && response.status, 0) < 300,
    status: _yt_toInt(response && response.status, 0),
    url: _yt_str(response && response.url) || _yt_str(url),
    text: _yt_str(response && response.bodyText)
  };
}

async function _yt_fetchWatchByVideoId(videoId) {
  var safeVideoId = encodeURIComponent(_yt_str(videoId));
  var watchURL = "https://www.youtube.com/watch?v=" + safeVideoId;
  var watch = await _yt_fetchText(watchURL, {}, 20);

  if (!watch.text) {
    _yt_throw("INVALID_RESPONSE", "empty watch html", { videoId: _yt_str(videoId) });
  }

  return watch;
}

async function _yt_fetchYoutubeiPlayerResponse(videoId, watchHTML) {
  return await _yt_fetchYoutubeiPlayerResponseByProfile(videoId, watchHTML, {
    source: "youtubei_web",
    client: {
      clientName: __yt_webClientName,
      clientVersion: _yt_extractInnertubeClientVersion(watchHTML) || __yt_webClientVersionFallback,
      platform: "DESKTOP",
      clientScreen: "WATCH",
      clientFormFactor: "UNKNOWN_FORM_FACTOR",
      browserName: "Chrome",
      browserVersion: "145.0.0.0",
      osName: "Macintosh",
      osVersion: "10_15_7",
      hl: "en",
      gl: "US"
    }
  });
}

async function _yt_fetchYoutubeiPlayerResponseByProfile(videoId, watchHTML, profile) {
  var safeProfile = profile && typeof profile === "object" ? profile : {};
  var source = _yt_str(safeProfile.source || "youtubei_unknown");
  var client = safeProfile.client && typeof safeProfile.client === "object" ? safeProfile.client : {};
  var apiKey = _yt_extractInnertubeApiKey(watchHTML) || __yt_youtubeiFallbackApiKey;
  var endpoint = "https://www.youtube.com/youtubei/v1/player?prettyPrint=false&key=" + encodeURIComponent(apiKey);
  var payload = {
    videoId: _yt_str(videoId),
    contentCheckOk: true,
    racyCheckOk: true,
    context: {
      client: client,
      user: { lockedSafetyMode: "false" },
      request: { useSsl: "true" }
    }
  };

  var response;
  try {
    response = await _yt_httpRequest({
      url: endpoint,
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "User-Agent": __yt_ua,
        "Accept-Language": "en-US,en;q=0.9"
      },
      body: JSON.stringify(payload),
      timeout: 12
    });
  } catch (error) {
    _yt_log("[youtube] " + source + " request failed: " + _yt_str(error && error.message));
    return null;
  }

  var status = _yt_toInt(response && response.status, 0);
  if (status < 200 || status >= 300) {
    _yt_log("[youtube] " + source + " non-2xx status=" + _yt_str(status));
    return null;
  }

  var bodyText = _yt_str(response && response.bodyText);
  if (!bodyText) return null;

  try {
    var parsed = JSON.parse(bodyText);
    return parsed && typeof parsed === "object" ? parsed : null;
  } catch (_) {
    _yt_log("[youtube] " + source + " parse failed");
    return null;
  }
}

async function _yt_collectYoutubeiManifestCandidates(videoId, watchHTML) {
  var webClientVersion = _yt_extractInnertubeClientVersion(watchHTML) || __yt_webClientVersionFallback;
  var profiles = [
    {
      source: "youtubei_web",
      client: {
        clientName: __yt_webClientName,
        clientVersion: webClientVersion,
        platform: "DESKTOP",
        clientScreen: "WATCH",
        clientFormFactor: "UNKNOWN_FORM_FACTOR",
        browserName: "Chrome",
        browserVersion: "145.0.0.0",
        osName: "Macintosh",
        osVersion: "10_15_7",
        hl: "en",
        gl: "US"
      }
    },
    {
      source: "youtubei_android",
      client: {
        clientName: __yt_androidClientName,
        clientVersion: __yt_androidClientVersion,
        platform: "MOBILE",
        androidSdkVersion: 30,
        userAgent: "com.google.android.youtube/19.45.36 (Linux; U; Android 11) gzip",
        osName: "Android",
        osVersion: "11",
        hl: "en",
        gl: "US"
      }
    },
    {
      source: "youtubei_ios",
      client: {
        clientName: __yt_iosClientName,
        clientVersion: __yt_iosClientVersion,
        deviceMake: "Apple",
        deviceModel: "iPhone16,2",
        userAgent: "com.google.ios.youtube/20.03.02 (iPhone16,2; U; CPU iOS 17_7_2 like Mac OS X;)",
        osName: "iPhone",
        osVersion: "17.7.2",
        hl: "en",
        gl: "US"
      }
    },
    {
      source: "youtubei_tv",
      client: {
        clientName: __yt_tvClientName,
        clientVersion: __yt_tvClientVersion,
        clientScreen: "EMBED",
        hl: "en",
        gl: "US"
      }
    }
  ];

  var out = [];
  for (var i = 0; i < profiles.length; i += 1) {
    var profile = profiles[i] || {};
    var response = await _yt_fetchYoutubeiPlayerResponseByProfile(videoId, watchHTML, profile);
    var candidates = _yt_collectManifestCandidatesFromPlayerResponse(
      response,
      _yt_str(profile.source),
      videoId
    );
    for (var j = 0; j < candidates.length; j += 1) {
      out.push(candidates[j]);
    }
  }

  return out;
}

async function _yt_verifyManifestCandidate(candidate) {
  var url = _yt_str(candidate && candidate.url);
  if (!url) return false;

  var master;
  try {
    master = await _yt_fetchText(url, __yt_playbackHeaders, 4);
  } catch (error) {
    _yt_log("[youtube] manifest check error source=" + _yt_str(candidate && candidate.source) + ": " + _yt_str(error && error.message));
    return false;
  }

  if (!master.ok) {
    _yt_log("[youtube] manifest check failed source=" + _yt_str(candidate && candidate.source) + ", status=" + _yt_str(master.status));
    return false;
  }

  var text = _yt_str(master.text);
  if (text.indexOf("#EXTM3U") < 0) {
    _yt_log("[youtube] manifest check invalid m3u8 source=" + _yt_str(candidate && candidate.source));
    return false;
  }

  var mediaPlaylistURL = _yt_pickMediaPlaylistURL(text, url);
  if (!mediaPlaylistURL) {
    _yt_log("[youtube] manifest check ok source=" + _yt_str(candidate && candidate.source) + ", status=" + _yt_str(master.status) + ", deep=skip");
    return true;
  }

  var media;
  try {
    media = await _yt_fetchText(mediaPlaylistURL, __yt_playbackHeaders, 3);
  } catch (error2) {
    _yt_log("[youtube] media playlist check error source=" + _yt_str(candidate && candidate.source) + ": " + _yt_str(error2 && error2.message));
    return false;
  }
  if (!media.ok) {
    _yt_log("[youtube] media playlist check failed source=" + _yt_str(candidate && candidate.source) + ", status=" + _yt_str(media.status));
    return false;
  }
  if (_yt_str(media.text).indexOf("#EXTM3U") < 0) {
    _yt_log("[youtube] media playlist invalid m3u8 source=" + _yt_str(candidate && candidate.source));
    return false;
  }

  var segmentURL = _yt_pickFirstSegmentURL(media.text, mediaPlaylistURL);
  if (!segmentURL) {
    _yt_log("[youtube] manifest check ok source=" + _yt_str(candidate && candidate.source) + ", status=" + _yt_str(master.status) + ", deep=no-segment");
    return true;
  }

  var segmentResp;
  try {
    segmentResp = await _yt_httpRequest({
      url: segmentURL,
      method: "GET",
      headers: Object.assign({}, __yt_playbackHeaders, {
        Range: "bytes=0-1"
      }),
      timeout: 6
    });
  } catch (error3) {
    _yt_log("[youtube] segment check error source=" + _yt_str(candidate && candidate.source) + ": " + _yt_str(error3 && error3.message));
    return false;
  }

  var segmentStatus = _yt_toInt(segmentResp && segmentResp.status, 0);
  if (segmentStatus < 200 || segmentStatus >= 300) {
    _yt_log("[youtube] segment check failed source=" + _yt_str(candidate && candidate.source) + ", status=" + _yt_str(segmentStatus));
    return false;
  }

  _yt_log("[youtube] manifest check ok source=" + _yt_str(candidate && candidate.source) + ", status=" + _yt_str(master.status) + ", deep=segment-" + _yt_str(segmentStatus));
  return true;
}

function _yt_resolveRelativeURL(candidate, base) {
  var raw = _yt_str(candidate);
  if (!raw) return "";
  try {
    return new URL(raw, base).toString();
  } catch (_) {
    return raw;
  }
}

function _yt_pickMediaPlaylistURL(masterText, masterURL) {
  var lines = _yt_str(masterText).split(/\r?\n/);
  for (var i = 0; i < lines.length; i += 1) {
    var line = _yt_str(lines[i]).trim();
    if (line.indexOf("#EXT-X-STREAM-INF:") !== 0) continue;
    for (var j = i + 1; j < lines.length; j += 1) {
      var next = _yt_str(lines[j]).trim();
      if (!next || next.charAt(0) === "#") continue;
      return _yt_resolveRelativeURL(next, masterURL);
    }
  }

  for (var k = 0; k < lines.length; k += 1) {
    var mediaLine = _yt_str(lines[k]).trim();
    if (mediaLine.indexOf("#EXT-X-MEDIA:") !== 0) continue;
    var attrs = _yt_parseM3U8Attributes(mediaLine.slice("#EXT-X-MEDIA:".length));
    var uri = _yt_str(attrs.URI);
    if (uri) {
      return _yt_resolveRelativeURL(uri, masterURL);
    }
  }

  if (_yt_str(masterText).indexOf("#EXTINF:") >= 0) {
    return _yt_str(masterURL);
  }

  return "";
}

function _yt_pickFirstSegmentURL(mediaText, mediaURL) {
  var lines = _yt_str(mediaText).split(/\r?\n/);
  for (var i = 0; i < lines.length; i += 1) {
    var line = _yt_str(lines[i]).trim();
    if (!line || line.charAt(0) === "#") continue;
    return _yt_resolveRelativeURL(line, mediaURL);
  }
  return "";
}

function _yt_pickPlaybackFallbackCandidate(sorted) {
  if (!Array.isArray(sorted) || sorted.length === 0) return null;
  var preferredSources = [
    "youtubei_ios",
    "youtubei_android",
    "youtubei_web",
    "youtubei_tv",
    "watch_player_response_strip_n",
    "watch_player_response",
    "watch_html_regex"
  ];

  for (var i = 0; i < preferredSources.length; i += 1) {
    var source = preferredSources[i];
    for (var j = 0; j < sorted.length; j += 1) {
      var candidate = sorted[j] || {};
      if (_yt_str(candidate.source).indexOf(source) >= 0) {
        return candidate;
      }
    }
  }

  return sorted[0];
}

async function _yt_resolveBestManifestCandidate(videoId, watchHTML, options) {
  var opts = options && typeof options === "object" ? options : {};
  var verifyManifest = _yt_normalizeBool(opts.verifyManifest);
  var base = _yt_extractManifestFromWatchHTML(watchHTML, videoId);

  var youtubeiCandidates = await _yt_collectYoutubeiManifestCandidates(videoId, watchHTML);
  var merged = [];

  // youtubei 候选优先；只有在 youtubei 完全拿不到时才回退 watch 页面候选。
  if (youtubeiCandidates.length > 0) {
    for (var i = 0; i < youtubeiCandidates.length; i += 1) {
      merged.push(youtubeiCandidates[i]);
    }
  } else if (base && base.url) {
    merged.push(base);
  }

  // 优先用非 IPv6 绑定的 manifest，降低播放器网络栈与签名 IP 不一致导致的 403。
  var ipv4Preferred = merged.filter(function (item) {
    return !_yt_isIPv6BoundManifestURL(item && item.url);
  });
  var candidatePool = ipv4Preferred.length > 0 ? ipv4Preferred : merged;

  var sorted = _yt_sortManifestCandidates(candidatePool, videoId);
  if (sorted.length === 0) return null;
  _yt_log("[youtube] manifest candidate count=" + _yt_str(sorted.length) + ", sources=" + sorted.map(function (item) { return _yt_str(item && item.source); }).join(","));

  // 默认关闭深度预检，显著缩短从解析到播放的等待时间。
  if (!verifyManifest) {
    return sorted[0];
  }

  // 调试模式下才做可播性校验。
  var verifyCount = Math.min(sorted.length, 2);
  for (var j = 0; j < verifyCount; j += 1) {
    var ok = await _yt_verifyManifestCandidate(sorted[j]);
    if (ok) return sorted[j];
  }

  // 全部校验失败时优先回退 youtubei 系列，避免 watch 链路出现 403 分片。
  return _yt_pickPlaybackFallbackCandidate(sorted);
}

async function _yt_resolveVideoId(input) {
  var direct = _yt_extractVideoIdFromText(input);
  if (direct) {
    return {
      videoId: direct,
      source: "video_id_or_watch_url"
    };
  }

  var sourceURL = _yt_inputToLiveURL(input);
  if (!sourceURL) {
    _yt_throw("INVALID_ARGS", "unsupported youtube input", {
      input: _yt_str(input)
    });
  }

  var page = await _yt_fetchText(sourceURL, {}, 20);

  var fromFinalURL = _yt_extractVideoIdFromText(page.url);
  if (fromFinalURL) {
    return {
      videoId: fromFinalURL,
      source: "redirect"
    };
  }

  var fromHTML = _yt_extractLiveVideoIdFromChannelHTML(page.text);
  if (fromHTML) {
    return {
      videoId: fromHTML,
      source: "channel_html"
    };
  }

  var fromCanonical = _yt_extractCanonicalVideoId(page.text);
  if (fromCanonical) {
    return {
      videoId: fromCanonical,
      source: "canonical"
    };
  }

  _yt_throw("NOT_FOUND", "no live video found for channel", {
    input: _yt_str(input),
    finalURL: _yt_str(page.url)
  });
}

function _yt_parseM3U8VariantsFromText(manifestText, manifestURL) {
  var lines = _yt_str(manifestText).split(/\r?\n/);
  var variants = [];

  for (var i = 0; i < lines.length; i += 1) {
    var line = _yt_str(lines[i]).trim();
    if (line.indexOf("#EXT-X-STREAM-INF:") !== 0) continue;

    var attrs = _yt_parseM3U8Attributes(line.slice("#EXT-X-STREAM-INF:".length));
    var nextURL = "";

    for (var j = i + 1; j < lines.length; j += 1) {
      var candidate = _yt_str(lines[j]).trim();
      if (!candidate || candidate.charAt(0) === "#") continue;
      nextURL = candidate;
      break;
    }

    var finalURL = "";
    if (nextURL) {
      try {
        finalURL = new URL(nextURL, manifestURL).toString();
      } catch (_) {
        finalURL = nextURL;
      }
    }

    var resolution = _yt_str(attrs.RESOLUTION);
    var bandwidth = _yt_toInt(attrs.BANDWIDTH, 0);
    var height = _yt_parseResolutionHeight(resolution);
    var codecs = _yt_str(attrs.CODECS);

    variants.push({
      resolution: resolution,
      bandwidth: bandwidth,
      codecs: codecs,
      qn: height,
      title: height > 0 ? height + "p" : "auto",
      url: finalURL
    });
  }

  variants.sort(function (a, b) {
    return b.bandwidth - a.bandwidth;
  });

  return variants;
}

async function _yt_parseM3U8Variants(manifestURL) {
  if (!manifestURL) return [];
  var manifest;
  try {
    manifest = await _yt_fetchText(manifestURL, __yt_playbackHeaders, 5);
  } catch (error) {
    _yt_log("[youtube] skip variant probing due to network error: " + _yt_str(error && error.message));
    return [];
  }

  if (!manifest.ok) {
    _yt_log("[youtube] skip variant probing, status=" + _yt_str(manifest.status));
    return [];
  }

  return _yt_parseM3U8VariantsFromText(manifest.text, manifestURL);
}

function _yt_buildPlayback(videoId, manifestURL, variants, options) {
  if (!manifestURL) {
    _yt_throw("NOT_FOUND", "youtube hls manifest not found", {
      videoId: _yt_str(videoId)
    });
  }

  var opts = options && typeof options === "object" ? options : {};
  var preferQn = Math.max(0, _yt_toInt(opts.preferQn, 0));
  var playbackProfile = _yt_pickPlaybackProfile(opts.sourceTag);
  _yt_log("[youtube] playback profile source=" + _yt_str(opts.sourceTag) + ", ua=" + _yt_str(playbackProfile.userAgent));
  var autoEntry = {
    roomId: _yt_str(videoId),
    title: "auto",
    qn: 0,
    url: _yt_str(manifestURL),
    liveCodeType: "m3u8",
    liveType: __yt_liveType,
    userAgent: playbackProfile.userAgent,
    headers: playbackProfile.headers
  };
  var qualitys = [];

  if (Array.isArray(variants) && variants.length > 0) {
    var filteredVariants = variants.filter(function (item) {
      return _yt_isPlaybackCodecCompatible(item && item.codecs);
    });
    var playableVariants = filteredVariants.length > 0 ? filteredVariants : variants;

    for (var i = 0; i < playableVariants.length; i += 1) {
      var item = playableVariants[i] || {};
      if (!_yt_str(item.url)) continue;
      qualitys.push({
        roomId: _yt_str(videoId),
        title: _yt_str(item.title) || "auto",
        qn: _yt_toInt(item.qn, 0),
        url: _yt_str(item.url),
        liveCodeType: "m3u8",
        liveType: __yt_liveType,
        userAgent: playbackProfile.userAgent,
        headers: playbackProfile.headers
      });
    }
  }

  // 先对具体清晰度去重，再把 auto 放到最后，便于手动切清晰度。
  var dedupVariants = [];
  var seen = {};
  for (var j = 0; j < qualitys.length; j += 1) {
    var key = _yt_str(qualitys[j] && qualitys[j].url);
    if (!key || seen[key]) continue;
    seen[key] = true;
    dedupVariants.push(qualitys[j]);
  }

  if (preferQn > 0 && dedupVariants.length > 1) {
    var bestIndex = -1;
    var bestDistance = Number.MAX_SAFE_INTEGER;
    for (var k = 0; k < dedupVariants.length; k += 1) {
      var qn = _yt_toInt(dedupVariants[k] && dedupVariants[k].qn, 0);
      if (qn <= 0) continue;
      var distance = Math.abs(qn - preferQn);
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = k;
      }
    }

    if (bestIndex > 0) {
      var picked = dedupVariants.splice(bestIndex, 1)[0];
      dedupVariants.unshift(picked);
      _yt_log("[youtube] preferQn=" + _yt_str(preferQn) + ", pickedQn=" + _yt_str(picked && picked.qn));
    }
  }

  var ordered = [];
  for (var m = 0; m < dedupVariants.length; m += 1) {
    ordered.push(dedupVariants[m]);
  }
  ordered.push(autoEntry);

  return [
    {
      cdn: "youtube_hls",
      qualitys: ordered
    }
  ];
}

function _yt_pickPlaybackProfile(sourceTag) {
  var source = _yt_str(sourceTag);
  var ua = __yt_playbackUserAgent;
  if (source.indexOf("youtubei_ios") >= 0) {
    ua = __yt_iosPlaybackUserAgent;
  } else if (source.indexOf("youtubei_android") >= 0) {
    ua = __yt_androidPlaybackUserAgent;
  }

  return {
    userAgent: ua,
    headers: {
      "user-agent": ua,
      referer: "https://www.youtube.com/",
      origin: "https://www.youtube.com"
    }
  };
}

async function _yt_probeLiveInfo(input) {
  var resolved = await _yt_resolveVideoId(input);
  var watch = await _yt_fetchWatchByVideoId(resolved.videoId);

  var title = _yt_extractWatchTitle(watch.text, resolved.videoId);
  var channel = _yt_extractWatchChannelInfo(watch.text);
  var cover = _yt_extractMeta(watch.text, "og:image");
  var manifestCandidate = _yt_extractManifestFromWatchHTML(watch.text, resolved.videoId);
  var hlsManifestUrl = _yt_str(manifestCandidate && manifestCandidate.url);

  return {
    input: _yt_str(input),
    resolvedSource: _yt_str(resolved.source),
    videoId: _yt_str(resolved.videoId),
    watchURL: _yt_str(watch.url),
    title: _yt_str(title),
    channelId: _yt_str(channel.channelId),
    channelName: _yt_str(channel.channelName),
    cover: _yt_str(cover),
    viewCountText: _yt_extractWatchViewCount(watch.text),
    liveState: hlsManifestUrl ? "1" : "0",
    hlsManifestUrl: _yt_str(hlsManifestUrl),
    hlsManifestSource: _yt_str(manifestCandidate && manifestCandidate.source)
  };
}

function _yt_probeToRoomModel(probe) {
  return {
    userName: _yt_str(probe.channelName || "YouTube"),
    roomTitle: _yt_str(probe.title || probe.videoId),
    roomCover: _yt_str(probe.cover || ""),
    userHeadImg: _yt_str(probe.cover || ""),
    liveState: _yt_str(probe.liveState || "0"),
    userId: _yt_str(probe.channelId || ""),
    roomId: _yt_str(probe.videoId || ""),
    liveWatchedCount: _yt_str(probe.viewCountText || "")
  };
}

function _yt_filterRoomsByRequest(rooms, categoryId, includeAll) {
  var out = Array.isArray(rooms) ? rooms.slice() : [];
  var selectedCategory = _yt_str(categoryId || "all");

  if (selectedCategory !== "all") {
    out = out.filter(function (item) {
      var categories = Array.isArray(item && item.categories) ? item.categories : [];
      return categories.indexOf(selectedCategory) >= 0;
    });
  }

  if (!includeAll) {
    out = out.filter(function (item) {
      return !!(item && item.isLiveNow);
    });
  }

  return out;
}

function _yt_extractHomeShelfRequests(initialData) {
  var sections = _yt_collectByKey(initialData, "richSectionRenderer");
  var out = [];
  var seen = {};

  for (var i = 0; i < sections.length; i += 1) {
    var section = sections[i];
    if (!section || typeof section !== "object") continue;

    var content = section.content;
    if (!content || typeof content !== "object") continue;

    var shelf = content.richShelfRenderer;
    if (!shelf || typeof shelf !== "object") continue;

    var category = _yt_textFromRuns(shelf.title).trim() || "Uncategorized";
    var endpoint = shelf.endpoint;
    var browse = endpoint && endpoint.browseEndpoint;
    var browseId = _yt_str(browse && browse.browseId);
    var params = _yt_str(browse && browse.params);
    if (!browseId || !params) continue;

    var key = category + "|" + browseId + "|" + params;
    if (seen[key]) continue;
    seen[key] = true;

    out.push({
      category: category,
      browseId: browseId,
      params: params,
      clickTrackingParams: _yt_str(endpoint && endpoint.clickTrackingParams)
    });
  }

  return out;
}

function _yt_extractBrowseVideoRenderers(response) {
  var out = [];
  var seen = {};

  function pushRenderer(renderer) {
    if (!renderer || typeof renderer !== "object") return;
    var roomId = _yt_str(renderer.videoId);
    if (!roomId || seen[roomId]) return;
    seen[roomId] = true;
    out.push(renderer);
  }

  function walkContinuationItems(items) {
    var continuationItems = Array.isArray(items) ? items : [];
    for (var i = 0; i < continuationItems.length; i += 1) {
      var item = continuationItems[i] || {};
      var rich = item.richItemRenderer;
      var inner = rich && rich.content;
      pushRenderer(inner && inner.videoRenderer);
      pushRenderer(item.videoRenderer);
    }
  }

  var grids = _yt_collectByKey(response, "richGridRenderer");
  for (var g = 0; g < grids.length; g += 1) {
    walkContinuationItems(grids[g] && grids[g].contents);
  }

  var appendActions = _yt_collectByKey(response, "appendContinuationItemsAction");
  for (var a = 0; a < appendActions.length; a += 1) {
    walkContinuationItems(appendActions[a] && appendActions[a].continuationItems);
  }

  var reloadActions = _yt_collectByKey(response, "reloadContinuationItemsCommand");
  for (var r = 0; r < reloadActions.length; r += 1) {
    walkContinuationItems(reloadActions[r] && reloadActions[r].continuationItems);
  }

  return out;
}

function _yt_extractBrowseContinuationState(response) {
  var continuationItems = _yt_collectByKey(response, "continuationItemRenderer");
  for (var i = 0; i < continuationItems.length; i += 1) {
    var renderer = continuationItems[i] || {};
    var endpoint = renderer.continuationEndpoint || {};
    var continuationCommand = endpoint.continuationCommand || {};
    var token = _yt_str(continuationCommand.token);
    if (!token) continue;

    return {
      token: token,
      clickTrackingParams: _yt_str(endpoint.clickTrackingParams || renderer.trackingParams)
    };
  }

  return {
    token: "",
    clickTrackingParams: ""
  };
}

async function _yt_fetchBrowsePage(apiKey, requestPayload, visitorData, refererURL) {
  var endpoint =
    "https://www.youtube.com/youtubei/v1/browse?prettyPrint=false&key=" +
    encodeURIComponent(_yt_str(apiKey));
  var headers = {
    "Content-Type": "application/json",
    "User-Agent": __yt_ua,
    Origin: "https://www.youtube.com",
    Referer: _yt_str(refererURL || __yt_liveHomeURL)
  };
  if (visitorData) {
    headers["X-Goog-Visitor-Id"] = _yt_str(visitorData);
  }

  var response;
  try {
    response = await _yt_httpRequest({
      url: endpoint,
      method: "POST",
      headers: headers,
      body: JSON.stringify(requestPayload || {}),
      timeout: 15
    });
  } catch (error) {
    _yt_log("[youtube] browse request failed: " + _yt_str(error && error.message));
    return null;
  }

  var status = _yt_toInt(response && response.status, 0);
  if (status < 200 || status >= 300) {
    _yt_log("[youtube] browse request non-2xx status=" + _yt_str(status));
    return null;
  }

  var bodyText = _yt_str(response && response.bodyText);
  if (!bodyText) return null;

  try {
    var parsed = JSON.parse(bodyText);
    return parsed && typeof parsed === "object" ? parsed : null;
  } catch (_) {
    _yt_log("[youtube] browse response parse failed");
    return null;
  }
}

function _yt_iterSectionVideos(initialData) {
  var sections = _yt_collectByKey(initialData, "richSectionRenderer");
  var out = [];

  for (var i = 0; i < sections.length; i += 1) {
    var section = sections[i];
    if (!section || typeof section !== "object") continue;

    var content = section.content;
    if (!content || typeof content !== "object") continue;

    var shelf = content.richShelfRenderer;
    if (!shelf || typeof shelf !== "object") continue;

    var category = _yt_textFromRuns(shelf.title).trim() || "Uncategorized";
    var contents = Array.isArray(shelf.contents) ? shelf.contents : [];

    for (var j = 0; j < contents.length; j += 1) {
      var richItem = contents[j] && contents[j].richItemRenderer;
      var inner = richItem && richItem.content;
      var renderer = inner && inner.videoRenderer;
      if (renderer && typeof renderer === "object") {
        out.push({
          category: category,
          renderer: renderer
        });
      }
    }
  }

  return out;
}

function _yt_parseHomeLiveItems(initialData, extraSectionVideos) {
  var sectionVideos = _yt_iterSectionVideos(initialData);
  if (Array.isArray(extraSectionVideos) && extraSectionVideos.length > 0) {
    sectionVideos = sectionVideos.concat(extraSectionVideos);
  }

  if (sectionVideos.length === 0) {
    var fallbackRenderers = _yt_collectByKey(initialData, "videoRenderer");
    var fallbackSeen = {};
    var fallbackRooms = [];

    for (var i = 0; i < fallbackRenderers.length; i += 1) {
      var item = _yt_videoRendererToItem(fallbackRenderers[i]);
      if (!item.videoId || fallbackSeen[item.videoId]) continue;
      fallbackSeen[item.videoId] = true;
      item.categories = ["live"];
      fallbackRooms.push(item);
    }

    return {
      rooms: fallbackRooms,
      categoryStats: [
        {
          name: "live",
          roomCount: fallbackRooms.length,
          liveRoomCount: fallbackRooms.filter(function (x) {
            return !!x.isLiveNow;
          }).length
        }
      ],
      categoryNames: ["live"]
    };
  }

  var byRoom = {};
  var categoryAll = {};
  var categoryLive = {};

  for (var j = 0; j < sectionVideos.length; j += 1) {
    var current = sectionVideos[j] || {};
    var category = _yt_str(current.category);
    var renderer = current.renderer || {};
    var roomId = _yt_str(renderer.videoId);
    if (!roomId) continue;

    if (!categoryAll[category]) categoryAll[category] = {};
    categoryAll[category][roomId] = true;

    var isLiveNow = _yt_liveStatusOfRenderer(renderer) === "live";
    if (!categoryLive[category]) categoryLive[category] = {};
    if (isLiveNow) categoryLive[category][roomId] = true;

    var item = byRoom[roomId];
    var candidate = _yt_videoRendererToItem(renderer);
    if (!item) {
      item = candidate;
      item.categories = [];
      byRoom[roomId] = item;
    } else {
      if (!item.title && candidate.title) item.title = candidate.title;
      if (!item.channelName && candidate.channelName) item.channelName = candidate.channelName;
      if (!item.channelId && candidate.channelId) item.channelId = candidate.channelId;
      if (!item.thumbnail && candidate.thumbnail) item.thumbnail = candidate.thumbnail;
      if (!item.viewCountText && candidate.viewCountText) item.viewCountText = candidate.viewCountText;

      var statusRank = {
        none: 0,
        upcoming: 1,
        live: 2
      };
      var currentStatus = _yt_str(item.status || "none");
      var candidateStatus = _yt_str(candidate.status || "none");
      if (_yt_toInt(statusRank[candidateStatus], 0) > _yt_toInt(statusRank[currentStatus], 0)) {
        item.status = candidateStatus;
        item.isLiveNow = candidateStatus === "live";
      }
    }

    if (item.categories.indexOf(category) < 0) {
      item.categories.push(category);
    }
  }

  var rooms = Object.values(byRoom).sort(function (a, b) {
    if (!!a.isLiveNow !== !!b.isLiveNow) {
      return a.isLiveNow ? -1 : 1;
    }
    return _yt_str(a.videoId).localeCompare(_yt_str(b.videoId));
  });

  var categoryNames = Object.keys(categoryAll).sort(function (a, b) {
    return a.localeCompare(b);
  });

  var categoryStats = categoryNames.map(function (name) {
    return {
      name: name,
      roomCount: Object.keys(categoryAll[name] || {}).length,
      liveRoomCount: Object.keys(categoryLive[name] || {}).length
    };
  });

  return {
    rooms: rooms,
    categoryStats: categoryStats,
    categoryNames: categoryNames
  };
}

async function _yt_fetchHomeLiveParsed(options) {
  var opts = options && typeof options === "object" ? options : {};
  var categoryId = _yt_str(opts.categoryId || "all");
  var includeAll = _yt_normalizeBool(opts.includeAll);
  var targetCount = Math.max(0, _yt_toInt(opts.targetCount, 0));

  var page = await _yt_fetchText(__yt_liveHomeURL, {
    "Accept-Language": "zh-CN,zh;q=0.9,en-US;q=0.8"
  }, 20);

  if (!page.ok) {
    _yt_throw("UPSTREAM", "failed to fetch youtube live home", {
      status: _yt_str(page.status),
      url: _yt_str(__yt_liveHomeURL)
    });
  }

  var initialData = _yt_extractInitialData(page.text);
  var extraSectionVideos = [];
  var parsed = _yt_parseHomeLiveItems(initialData, extraSectionVideos);

  var maybeFetchMore = targetCount > 0;
  if (maybeFetchMore) {
    var currentRooms = _yt_filterRoomsByRequest(parsed.rooms, categoryId, includeAll);
    if (currentRooms.length < targetCount) {
      var apiKey = _yt_extractInnertubeApiKey(page.text) || __yt_youtubeiFallbackApiKey;
      var clientVersion = _yt_extractInnertubeClientVersion(page.text) || __yt_webClientVersionFallback;
      var visitorData = _yt_extractVisitorData(page.text);
      var requestContext = {
        client: {
          clientName: __yt_webClientName,
          clientVersion: clientVersion,
          hl: "en",
          gl: "US"
        }
      };

      var shelfRequests = _yt_extractHomeShelfRequests(initialData);
      if (categoryId !== "all") {
        shelfRequests = shelfRequests.filter(function (item) {
          return _yt_str(item && item.category) === categoryId;
        });
      }

      var shouldStop = false;
      var maxContinuationPages = 8;

      for (var i = 0; i < shelfRequests.length && !shouldStop; i += 1) {
        var shelf = shelfRequests[i] || {};
        var browseId = _yt_str(shelf.browseId);
        var params = _yt_str(shelf.params);
        if (!browseId || !params) continue;

        var browseResponse = await _yt_fetchBrowsePage(
          apiKey,
          {
            context: requestContext,
            browseId: browseId,
            params: params
          },
          visitorData,
          page.url
        );
        if (!browseResponse) continue;

        var firstPageRenderers = _yt_extractBrowseVideoRenderers(browseResponse);
        for (var r = 0; r < firstPageRenderers.length; r += 1) {
          extraSectionVideos.push({
            category: _yt_str(shelf.category),
            renderer: firstPageRenderers[r]
          });
        }

        parsed = _yt_parseHomeLiveItems(initialData, extraSectionVideos);
        currentRooms = _yt_filterRoomsByRequest(parsed.rooms, categoryId, includeAll);
        if (currentRooms.length >= targetCount) {
          shouldStop = true;
          break;
        }

        var continuationState = _yt_extractBrowseContinuationState(browseResponse);
        var continuationToken = _yt_str(continuationState.token);
        var clickTrackingParams = _yt_str(
          continuationState.clickTrackingParams || shelf.clickTrackingParams
        );

        for (var pageIndex = 0; continuationToken && pageIndex < maxContinuationPages; pageIndex += 1) {
          var continuationPayload = {
            context: requestContext,
            continuation: continuationToken
          };
          if (clickTrackingParams || visitorData) {
            continuationPayload.clickTracking = {};
            if (clickTrackingParams) {
              continuationPayload.clickTracking.clickTrackingParams = clickTrackingParams;
            }
            if (visitorData) {
              continuationPayload.clickTracking.visitorData = visitorData;
            }
          }

          var continuationResponse = await _yt_fetchBrowsePage(
            apiKey,
            continuationPayload,
            visitorData,
            page.url
          );
          if (!continuationResponse) break;

          var continuationRenderers = _yt_extractBrowseVideoRenderers(continuationResponse);
          for (var x = 0; x < continuationRenderers.length; x += 1) {
            extraSectionVideos.push({
              category: _yt_str(shelf.category),
              renderer: continuationRenderers[x]
            });
          }

          parsed = _yt_parseHomeLiveItems(initialData, extraSectionVideos);
          currentRooms = _yt_filterRoomsByRequest(parsed.rooms, categoryId, includeAll);
          if (currentRooms.length >= targetCount) {
            shouldStop = true;
            break;
          }

          continuationState = _yt_extractBrowseContinuationState(continuationResponse);
          continuationToken = _yt_str(continuationState.token);
          if (_yt_str(continuationState.clickTrackingParams)) {
            clickTrackingParams = _yt_str(continuationState.clickTrackingParams);
          }
        }
      }
    }
  }

  return {
    finalURL: page.url,
    parsed: parsed
  };
}

async function _yt_searchLive(keyword) {
  var searchURL =
    "https://www.youtube.com/results?search_query=" + encodeURIComponent(_yt_str(keyword));
  var resp = await _yt_fetchText(searchURL, {}, 20);

  if (!resp.ok) {
    _yt_throw("UPSTREAM", "failed to fetch youtube search", {
      status: _yt_str(resp.status),
      keyword: _yt_str(keyword)
    });
  }

  var initialData = _yt_extractInitialData(resp.text);
  var renderers = _yt_collectByKey(initialData, "videoRenderer");
  var seen = {};
  var items = [];

  for (var i = 0; i < renderers.length; i += 1) {
    var item = _yt_videoRendererToItem(renderers[i]);
    if (!item.videoId || seen[item.videoId]) continue;
    seen[item.videoId] = true;
    items.push(item);
  }

  return items;
}

globalThis.LiveParsePlugin = {
  apiVersion: 1,

  async getCategories(payload) {
    var data = await _yt_fetchHomeLiveParsed();
    var stats = Array.isArray(data.parsed.categoryStats) ? data.parsed.categoryStats : [];

    var subList = [
      {
        id: "all",
        parentId: "youtube_live",
        title: "All Live",
        icon: ""
      }
    ];

    for (var i = 0; i < stats.length; i += 1) {
      var stat = stats[i] || {};
      if (_yt_toInt(stat.liveRoomCount, 0) <= 0) continue;

      subList.push({
        id: _yt_str(stat.name),
        parentId: "youtube_live",
        title: _yt_str(stat.name),
        icon: ""
      });
    }

    return [
      {
        id: "youtube_live",
        title: "YouTube Live",
        icon: "",
        subList: subList
      }
    ];
  },

  async getRooms(payload) {
    var categoryId = _yt_str(payload && payload.id) || "all";
    var page = _yt_toInt(payload && payload.page, 1);
    var includeAll = _yt_normalizeBool(payload && payload.includeAll);
    var pageSize = _yt_toInt(payload && payload.pageSize, __yt_defaultPageSize);
    var targetCount = Math.max(1, page) * Math.max(1, pageSize);

    var data = await _yt_fetchHomeLiveParsed({
      categoryId: categoryId,
      includeAll: includeAll,
      targetCount: targetCount
    });
    var rooms = Array.isArray(data.parsed.rooms) ? data.parsed.rooms : [];
    rooms = _yt_filterRoomsByRequest(rooms, categoryId, includeAll);

    var paged = _yt_paginate(rooms, page, pageSize);
    return paged.map(_yt_toRoomModel);
  },

  async getPlayback(payload) {
    var debugLog = _yt_normalizeBool(payload && payload.debug);
    if (!debugLog && payload && Object.prototype.hasOwnProperty.call(payload, "logDebug")) {
      debugLog = _yt_normalizeBool(payload && payload.logDebug);
    }
    var previousDebugLog = __yt_debugLogEnabled;
    __yt_debugLogEnabled = debugLog;
    try {
      var rawRoomId = _yt_str(payload && payload.roomId);
      if (!rawRoomId) {
        _yt_throw("INVALID_ARGS", "roomId is required", { field: "roomId" });
      }

      var resolved = await _yt_resolveVideoId(rawRoomId);
      var watch = await _yt_fetchWatchByVideoId(resolved.videoId);
      var verifyManifest = _yt_normalizeBool(payload && payload.verifyManifest);
      var qnInput = payload && payload.qn;
      if (qnInput === undefined || qnInput === null) qnInput = payload && payload.rate;
      if (qnInput === undefined || qnInput === null) qnInput = payload && payload.gear;
      var preferQn = Math.max(0, _yt_toInt(qnInput, 0));
      var manifestCandidate = await _yt_resolveBestManifestCandidate(resolved.videoId, watch.text, {
        verifyManifest: verifyManifest
      });
      var hlsManifestUrl = _yt_str(manifestCandidate && manifestCandidate.url);
      if (hlsManifestUrl) {
        var hasNChallenge = hlsManifestUrl.indexOf("/n/") >= 0;
        var ipv6Bound = /\/ip\/[^/]*:/.test(hlsManifestUrl);
        _yt_log(
          "[youtube] playback manifest source=" +
            _yt_str(manifestCandidate && manifestCandidate.source) +
            ", videoId=" +
            _yt_str(resolved.videoId) +
            ", hasN=" +
            _yt_str(hasNChallenge) +
            ", ipv6=" +
            _yt_str(ipv6Bound)
        );
      }
      // 默认开启清晰度解析，提供可切换画质；可通过 payload.probeVariants=false 关闭。
      var probeVariants = payload && Object.prototype.hasOwnProperty.call(payload, "probeVariants")
        ? _yt_normalizeBool(payload && payload.probeVariants)
        : true;
      var variants = probeVariants ? await _yt_parseM3U8Variants(hlsManifestUrl) : [];
      var isDemuxedManifest = hlsManifestUrl.indexOf("/demuxed/1/") >= 0;
      if (isDemuxedManifest && variants.length > 0) {
        // demuxed master 里的子播放列表常为纯视频，直接切子流可能导致无声。
        // 这里保留 master 播放以保证音频稳定。
        _yt_log("[youtube] demuxed manifest detected, disable direct variant URLs to keep audio");
        variants = [];
      }
      _yt_log("[youtube] playback variants=" + _yt_str(variants.length) + ", probeVariants=" + _yt_str(probeVariants) + ", preferQn=" + _yt_str(preferQn));

      return _yt_buildPlayback(resolved.videoId, hlsManifestUrl, variants, {
        preferQn: preferQn,
        sourceTag: _yt_str(manifestCandidate && manifestCandidate.source)
      });
    } finally {
      __yt_debugLogEnabled = previousDebugLog;
    }
  },

  async search(payload) {
    var keyword = _yt_str(payload && payload.keyword).trim();
    var page = _yt_toInt(payload && payload.page, 1);
    var includeAll = _yt_normalizeBool(payload && payload.includeAll);

    if (!keyword) {
      _yt_throw("INVALID_ARGS", "keyword is required", { field: "keyword" });
    }

    var items = await _yt_searchLive(keyword);
    if (!includeAll) {
      items = items.filter(function (item) {
        return _yt_str(item && item.status) === "live";
      });
    }

    var paged = _yt_paginate(items, page, __yt_defaultPageSize);
    return paged.map(_yt_toRoomModel);
  },

  async getRoomDetail(payload) {
    var rawRoomId = _yt_str(payload && payload.roomId);
    if (!rawRoomId) {
      _yt_throw("INVALID_ARGS", "roomId is required", { field: "roomId" });
    }

    var probe = await _yt_probeLiveInfo(rawRoomId);
    return _yt_probeToRoomModel(probe);
  },

  async getLiveState(payload) {
    var info = await this.getRoomDetail(payload || {});
    return {
      liveState: _yt_str((info && info.liveState) || "0")
    };
  },

  async resolveShare(payload) {
    var shareCode = _yt_str(payload && payload.shareCode);
    if (!shareCode) {
      _yt_throw("INVALID_ARGS", "shareCode is required", { field: "shareCode" });
    }

    var firstURL = _yt_firstURL(shareCode);
    var input = firstURL || shareCode;
    var probe = await _yt_probeLiveInfo(input);
    return _yt_probeToRoomModel(probe);
  },

  async getDanmaku(payload) {
    var roomId = _yt_str(payload && payload.roomId);
    if (!roomId) {
      _yt_throw("INVALID_ARGS", "roomId is required", { field: "roomId" });
    }

    var resolved = await _yt_resolveVideoId(roomId);
    var watch = await _yt_fetchWatchByVideoId(resolved.videoId);
    var playerResponse = _yt_extractWatchPlayerResponse(watch.text);
    var initialData = null;
    try {
      initialData = _yt_extractInitialData(watch.text);
    } catch (_) {
      initialData = null;
    }

    var continuation = _yt_extractLiveChatContinuation(playerResponse, initialData, watch.text);
    if (!continuation) {
      _yt_throw("NOT_FOUND", "youtube live chat continuation not found", {
        roomId: _yt_str(roomId),
        videoId: _yt_str(resolved.videoId)
      });
    }

    var apiKey = _yt_extractInnertubeApiKey(watch.text) || __yt_youtubeiFallbackApiKey;
    var clientVersion = _yt_extractInnertubeClientVersion(watch.text) || __yt_webClientVersionFallback;

    return {
      args: {
        _danmu_type: "http_polling",
        _polling_url: "https://www.youtube.com/youtubei/v1/live_chat/get_live_chat",
        _polling_method: "POST",
        _polling_interval: "2500",
        continuation: _yt_str(continuation),
        apiKey: _yt_str(apiKey),
        clientName: __yt_webClientName,
        clientVersion: _yt_str(clientVersion),
        hl: "en",
        gl: "US",
        videoId: _yt_str(resolved.videoId)
      },
      headers: {
        "Content-Type": "application/json",
        Origin: "https://www.youtube.com",
        Referer: "https://www.youtube.com/watch?v=" + encodeURIComponent(_yt_str(resolved.videoId)),
        "User-Agent": __yt_ua
      }
    };
  }
};
