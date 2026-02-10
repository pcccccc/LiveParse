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

function __lp_convertUnicodeEscapes(input) {
  return String(input).replace(/\\u([0-9A-Fa-f]{4})/g, function (_, hex) {
    return String.fromCharCode(parseInt(hex, 16));
  });
}

function __lp_removeIncludeFunctionValue(input) {
  return String(input).replace(/function\s*\([^}]*\}/g, );
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

