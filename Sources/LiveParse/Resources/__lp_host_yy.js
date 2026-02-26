// YY Platform Host API Bootstrap
if (typeof Host === "undefined") {
  globalThis.Host = {};
}

if (typeof Host.yy === "undefined") {
  Host.yy = {};
}

// Host.yy.getStreamInfo(roomId) -> Promise<{stream_key, ver, url}>
Host.yy.getStreamInfo = function(roomId) {
  return new Promise(function(resolve, reject) {
    if (typeof __lp_yy_get_stream_info !== "function") {
      reject(new Error("YY Host API not available"));
      return;
    }

    __lp_yy_get_stream_info(String(roomId), function(jsonString) {
      try {
        const result = JSON.parse(jsonString);
        resolve(result);
      } catch (e) {
        reject(e);
      }
    }, function(error) {
      reject(new Error(String(error)));
    });
  });
};
