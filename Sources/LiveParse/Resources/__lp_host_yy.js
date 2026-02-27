// YY Platform Host API Bootstrap
if (typeof Host === "undefined") {
  globalThis.Host = {};
}

if (typeof Host.yy === "undefined") {
  Host.yy = {};
}

// Host.yy.getStreamInfo(roomId, options?) -> Promise<{stream_key, ver, url, line_seq?, gear?}>
Host.yy.getStreamInfo = function(roomId, options) {
  return new Promise(function(resolve, reject) {
    const hasLegacyAPI = typeof __lp_yy_get_stream_info === "function";
    const hasExtendedAPI = typeof __lp_yy_get_stream_info_ex === "function";
    if (!hasLegacyAPI && !hasExtendedAPI) {
      reject(new Error("YY Host API not available"));
      return;
    }

    const onResolve = function(rawResult) {
      try {
        let result = rawResult;
        if (typeof rawResult === "string") {
          result = JSON.parse(rawResult || "{}");
        } else if (!rawResult || typeof rawResult !== "object") {
          result = {};
        }
        resolve(result);
      } catch (e) {
        reject(e);
      }
    };

    const onReject = function(error) {
      reject(new Error(String(error)));
    };

    const safeOptions = options && typeof options === "object" ? options : {};
    if (hasExtendedAPI) {
      __lp_yy_get_stream_info_ex(String(roomId), safeOptions, onResolve, onReject);
    } else {
      __lp_yy_get_stream_info(String(roomId), onResolve, onReject);
    }
  });
};
