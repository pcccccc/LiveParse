/**
 * LiveParse Plugin — SOOP (formerly AfreecaTV)
 * =============================================
 * 韩国直播平台 SOOP（原 AfreecaTV）插件
 *
 * API 域名：
 *   分类/搜索: sch.sooplive.co.kr
 *   播放信息: live.sooplive.co.kr
 *   直播流:   livestream-manager.sooplive.co.kr
 *   主播信息: st.sooplive.co.kr
 *
 * 关键 Cookie: AbroadChk=OK（海外访问必需）
 */

// ============================================================
// 常量 & 工具
// ============================================================

const __soop_defaultHeaders = {
  "user-agent":
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36",
  "accept-language": "zh-CN,zh;q=0.9",
  accept: "application/json, text/javascript, */*; q=0.01",
};

const __soop_defaultCookie = "AbroadChk=OK";

// 运行时用户登录 Cookie（由 APP 侧通过 setCookie 注入，用于 19+ 房间）
var __soop_runtimeCookie = "";

const __soop_playerApiUrl =
  "https://live.sooplive.co.kr/afreeca/player_live_api.php";

const __soop_cdnMapping = {
  gs_cdn: "gs_cdn_pc_web",
  lg_cdn: "lg_cdn_pc_web",
};

const __soop_qualityPresets = [
  { name: "original", label: "1080p" },
  { name: "hd4k", label: "720p" },
  { name: "hd", label: "540p" },
  { name: "sd", label: "360p" },
];

function _soop_throw(code, message, context) {
  if (globalThis.Host && typeof Host.raise === "function") {
    Host.raise(code, message, context || {});
  }
  if (globalThis.Host && typeof Host.makeError === "function") {
    throw Host.makeError(
      code || "UNKNOWN",
      message || "",
      context || {}
    );
  }
  throw new Error(
    `LP_PLUGIN_ERROR:${JSON.stringify({
      code: String(code || "UNKNOWN"),
      message: String(message || ""),
      context: context || {},
    })}`
  );
}

function _soop_str(val) {
  if (val === null || val === undefined) return "";
  return String(val);
}

function _soop_firstURL(text) {
  var m = String(text || "").match(/https?:\/\/[^\s"'<>|]+/);
  return m ? m[0] : "";
}

function _soop_isValidBjId(val) {
  return /^[a-zA-Z0-9_]{2,20}$/.test(String(val || ""));
}

// ============================================================
// 内部 API 封装
// ============================================================

/**
 * 通用请求封装，自动附加 Cookie
 */
async function _soop_request(options) {
  var headers = Object.assign({}, __soop_defaultHeaders, options.headers || {});
  headers["cookie"] = __soop_runtimeCookie
    ? __soop_defaultCookie + "; " + __soop_runtimeCookie
    : __soop_defaultCookie;

  return await Host.http.request({
    url: options.url,
    method: options.method || "GET",
    headers: headers,
    body: options.body || null,
    timeout: options.timeout || 20,
  });
}

/**
 * 获取一级菜单列表
 */
async function _soop_fetchMenuList() {
  var resp = await _soop_request({
    url: "https://live.sooplive.co.kr/api/explore/get_menu_list.php",
  });

  var data = JSON.parse(resp.bodyText || "{}");
  if (!data.data || !data.data.list) {
    _soop_throw("INVALID_RESPONSE", "missing menu data", {});
  }

  return data.data.list;
}

/**
 * 获取分类列表（二级）
 */
async function _soop_fetchCategories() {
  var resp = await _soop_request({
    url: "https://sch.sooplive.co.kr/api.php?m=categoryList&szKeyword=&szOrder=view_cnt&nPageNo=1&nListCnt=900&nOffset=0&szPlatform=pc",
  });

  var data = JSON.parse(resp.bodyText || "{}");
  if (!data.data || !data.data.list) {
    _soop_throw("INVALID_RESPONSE", "missing category data", {});
  }

  return data.data.list;
}

/**
 * 获取分类下的房间列表（按 category_no）
 */
async function _soop_fetchRooms(categoryNo, page) {
  var resp = await _soop_request({
    url:
      "https://sch.sooplive.co.kr/api.php?m=categoryContentsList&szType=live&nPageNo=" +
      encodeURIComponent(String(page)) +
      "&nListCnt=60&szPlatform=pc&szCateNo=" +
      encodeURIComponent(String(categoryNo)) +
      "&szOrder=view_cnt&strmLangType=",
  });

  var data = JSON.parse(resp.bodyText || "{}");
  if (!data.data || !data.data.list) {
    _soop_throw("INVALID_RESPONSE", "missing room data", {
      categoryNo: String(categoryNo),
    });
  }

  return data.data.list;
}

/**
 * 获取 admin menu 下的房间列表（按 menuId）
 */
async function _soop_fetchMenuRooms(menuId, page) {
  var resp = await _soop_request({
    url:
      "https://live.sooplive.co.kr/api/explore/get_contents_list.php?szMenuId=" +
      encodeURIComponent(String(menuId)) +
      "&szType=live&nPageNo=" +
      encodeURIComponent(String(page)) +
      "&nListCnt=60&szPlatform=pc&szOrder=view_cnt_desc&szTerm=1week&strmLangType=",
  });

  var data = JSON.parse(resp.bodyText || "{}");
  if (!data.data || !data.data.list) {
    _soop_throw("INVALID_RESPONSE", "missing menu room data", {
      menuId: String(menuId),
    });
  }

  return data.data.list;
}

/**
 * 调用 player_live_api（获取频道信息 / AID）
 */
async function _soop_playerApi(bjId, broadNo, type, quality) {
  var bodyParts = [
    "bid=" + encodeURIComponent(String(bjId)),
    "bno=" + encodeURIComponent(String(broadNo || "")),
    "type=" + encodeURIComponent(String(type || "live")),
    "pwd=",
    "player_type=html5",
    "stream_type=common",
    "mode=landing",
    "from_api=0",
  ];
  if (quality) {
    bodyParts.push("quality=" + encodeURIComponent(String(quality)));
  }

  var resp = await _soop_request({
    url: __soop_playerApiUrl + "?bjid=" + encodeURIComponent(String(bjId)),
    method: "POST",
    headers: {
      "content-type": "application/x-www-form-urlencoded",
      origin: "https://play.sooplive.co.kr",
      referer: "https://play.sooplive.co.kr/" + encodeURIComponent(String(bjId)),
    },
    body: bodyParts.join("&"),
  });
  console.log(
    "[soop][raw][player_live_api] bjId=" +
      String(bjId) +
      " broadNo=" +
      String(broadNo || "") +
      " type=" +
      String(type || "live") +
      " quality=" +
      String(quality || "") +
      " body=" +
      String(resp.bodyText || "")
  );

  var result = JSON.parse(resp.bodyText || "{}");
  var channel = result && result.CHANNEL;
  if (!channel) {
    _soop_throw("INVALID_RESPONSE", "missing CHANNEL in player API response", {
      bjId: String(bjId),
    });
  }

  return channel;
}

/**
 * 获取频道信息（type=live）
 */
async function _soop_getChannelInfo(bjId, broadNo) {
  return await _soop_playerApi(bjId, broadNo, "live", null);
}

/**
 * 获取 AID（type=aid）
 */
async function _soop_getAid(bjId, broadNo, quality) {
  var channel = await _soop_playerApi(bjId, broadNo, "aid", quality);
  return _soop_str(channel.AID);
}

/**
 * 获取 HLS 播放地址（broad_stream_assign）
 */
async function _soop_getStreamUrl(rmd, cdn, broadNo, quality) {
  var returnType = __soop_cdnMapping[cdn] || cdn;
  var broadKey = broadNo + "-common-" + quality + "-hls";

  var resp = await _soop_request({
    url:
      rmd +
      "/broad_stream_assign.html?return_type=" +
      encodeURIComponent(String(returnType)) +
      "&broad_key=" +
      encodeURIComponent(String(broadKey)),
    headers: {
      origin: "https://play.sooplive.co.kr",
      referer: "https://play.sooplive.co.kr/",
    },
  });

  var data = JSON.parse(resp.bodyText || "{}");
  return _soop_str(data.view_url);
}

/**
 * 搜索直播
 */
async function _soop_search(keyword, page) {
  var resp = await _soop_request({
    url:
      "https://sch.sooplive.co.kr/api.php?m=liveSearch&szKeyword=" +
      encodeURIComponent(String(keyword)) +
      "&szType=live&nPageNo=" +
      encodeURIComponent(String(page)) +
      "&nListCnt=20&szPlatform=pc",
  });

  var data = JSON.parse(resp.bodyText || "{}");
  if (_soop_str(data.RESULT) !== "1") {
    _soop_throw("UPSTREAM", "SOOP search error", {
      keyword: String(keyword),
    });
  }

  return data.REAL_BROAD || [];
}

/**
 * 获取主播站点状态（用于 getLiveState / getRoomDetail 补充信息）
 */
async function _soop_getStationStatus(bjId) {
  var resp = await _soop_request({
    url:
      "https://st.sooplive.co.kr/api/get_station_status.php?szBjId=" +
      encodeURIComponent(String(bjId)),
  });
  console.log(
    "[soop][raw][station_status] bjId=" +
      String(bjId) +
      " body=" +
      String(resp.bodyText || "")
  );

  var data = JSON.parse(resp.bodyText || "{}");
  return data.DATA || data.data || null;
}

// ============================================================
// 数据转换
// ============================================================

function _soop_roomToModel(item) {
  return {
    userName: _soop_str(item.user_nick),
    roomTitle: _soop_str(item.broad_title),
    roomCover: _soop_str(item.thumbnail || item.broad_img || item.sn_url),
    userHeadImg: _soop_str(item.user_profile_img || ""),
    liveState: "1",
    userId: _soop_str(item.user_id),
    roomId: _soop_str(item.broad_no),
    liveWatchedCount: _soop_str(item.total_view_cnt || item.current_view_cnt || item.view_cnt || "0"),
  };
}

function _soop_searchToModel(item) {
  return {
    userName: _soop_str(item.user_nick || item.station_name),
    roomTitle: _soop_str(item.broad_title),
    roomCover: _soop_str(item.broad_img || item.sn_url),
    userHeadImg: _soop_str(item.logo || ""),
    liveState: "1",
    userId: _soop_str(item.user_id),
    roomId: _soop_str(item.broad_no),
    liveWatchedCount: _soop_str(item.total_view_cnt || item.current_view_cnt || "0"),
  };
}

// ============================================================
// 分享链接解析
// ============================================================

function _soop_parseShareCode(shareCode) {
  var trimmed = String(shareCode || "").trim();
  if (!trimmed) _soop_throw("INVALID_ARGS", "shareCode is empty", { field: "shareCode" });

  // URL 格式: https://play.sooplive.co.kr/{bjId}/{broadNo}
  //          https://play.afreecatv.com/{bjId}/{broadNo}
  //          https://bj.sooplive.co.kr/{bjId}
  var urlText = _soop_firstURL(trimmed);
  if (urlText) {
    // play.sooplive.co.kr/{bjId}/{broadNo}
    var playMatch = urlText.match(
      /play\.(sooplive\.co\.kr|afreecatv\.com)\/([a-zA-Z0-9_]+)/
    );
    if (playMatch && playMatch[2]) {
      return playMatch[2];
    }

    // bj.sooplive.co.kr/{bjId}
    var bjMatch = urlText.match(
      /bj\.(sooplive\.co\.kr|afreecatv\.com)\/([a-zA-Z0-9_]+)/
    );
    if (bjMatch && bjMatch[2]) {
      return bjMatch[2];
    }
  }

  // 纯 bjId
  if (_soop_isValidBjId(trimmed)) return trimmed;

  // 从文本中提取
  var tokens = trimmed.split(/[\s|]+/);
  for (var i = 0; i < tokens.length; i++) {
    if (_soop_isValidBjId(tokens[i])) return tokens[i];
  }

  _soop_throw("NOT_FOUND", "cannot resolve bjId from shareCode", {
    shareCode: String(shareCode || ""),
  });
}

// ============================================================
// 插件导出
// ============================================================

globalThis.LiveParsePlugin = {
  apiVersion: 1,

  /**
   * 获取分区列表
   * 1. 调用 get_menu_list 获取一级菜单
   * 2. type=category → "分类"，子项为 categoryList 原样平铺
   * 3. type=admin → 独立一级分类（如 Talk），子项 id 用 "menu_{menuId}"
   */
  async getCategories(payload) {
    var menuList = await _soop_fetchMenuList();
    var result = [];

    for (var m = 0; m < menuList.length; m++) {
      var menu = menuList[m];
      var menuType = _soop_str(menu.type);
      var menuName = _soop_str(menu.menu_name);
      var menuId = menu.menu_id;

      if (menuType === "category") {
        // "分类" 菜单：请求 categoryList，原样平铺为子分类
        var categoryList = await _soop_fetchCategories();
        var subList = [];

        for (var i = 0; i < categoryList.length; i++) {
          var item = categoryList[i];
          var viewCnt = Number(item.view_cnt) || 0;
          if (viewCnt <= 0) continue;

          subList.push({
            id: _soop_str(item.category_no),
            parentId: "category",
            title: _soop_str(item.category_name),
            icon: _soop_str(item.cate_img || ""),
          });
        }

        result.push({
          id: "category",
          title: menuName,
          icon: "",
          subList: subList,
        });
      } else if (menuType === "admin") {
        // admin 菜单（如 Talk）：独立一级分类，子项只有自身
        result.push({
          id: "menu_" + menuId,
          title: menuName,
          icon: "",
          subList: [
            {
              id: "menu_" + menuId,
              parentId: "menu_" + menuId,
              title: menuName,
              icon: "",
            },
          ],
        });
      }
    }

    return result;
  },

  /**
   * 获取房间列表
   * id 以 "menu_" 开头 → 走 get_contents_list（admin 菜单）
   * 否则 → 走 categoryContentsList（普通分类）
   */
  async getRooms(payload) {
    var id = _soop_str(payload && payload.id);
    var page = (payload && payload.page) ? Number(payload.page) : 1;
    if (!id) _soop_throw("INVALID_ARGS", "id is required", { field: "id" });

    var rawList;
    if (id.indexOf("menu_") === 0) {
      var menuId = id.substring(5);
      rawList = await _soop_fetchMenuRooms(menuId, page);
    } else {
      rawList = await _soop_fetchRooms(id, page);
    }

    var rooms = [];
    for (var i = 0; i < rawList.length; i++) {
      var item = rawList[i];
      if (Number(item.is_password) === 1) continue;
      rooms.push(_soop_roomToModel(item));
    }

    return rooms;
  },

  /**
   * 获取播放地址（三步流程）
   * 1. player_live_api type=live → 频道信息 (RMD, CDN, BNO, VIEWPRESET)
   * 2. player_live_api type=aid → AID token
   * 3. broad_stream_assign → view_url (m3u8)
   * 最终地址: view_url?aid=AID
   */
  async getPlayback(payload) {
    var roomId = _soop_str(payload && payload.roomId);
    var userId = _soop_str(payload && payload.userId);
    if (!roomId && !userId)
      _soop_throw("INVALID_ARGS", "roomId or userId is required", {
        field: "roomId",
      });

    // userId 在 SOOP 是 bjId (user_id), roomId 是 broad_no
    var bjId = userId || roomId;
    var broadNo = roomId;

    // Step 1: 获取频道信息
    var channel = await _soop_getChannelInfo(bjId, broadNo);
    if (Number(channel.RESULT) !== 1) {
      _soop_throw("NOT_FOUND", "channel not live or not found", {
        bjId: bjId,
        result: String(channel.RESULT),
      });
    }

    var rmd = _soop_str(channel.RMD);
    var cdn = _soop_str(channel.CDN);
    var bno = _soop_str(channel.BNO);
    var viewPreset = channel.VIEWPRESET || [];

    if (!rmd || !bno) {
      _soop_throw("NOT_FOUND", "missing RMD or BNO", { bjId: bjId });
    }

    // 获取可用清晰度
    var qualities = [];
    for (var i = 0; i < viewPreset.length; i++) {
      var preset = viewPreset[i];
      if (_soop_str(preset.name) === "auto") continue;
      qualities.push({
        name: _soop_str(preset.name),
        label: _soop_str(preset.label),
      });
    }

    if (qualities.length === 0) {
      qualities = __soop_qualityPresets.slice();
    }

    // Step 2 & 3: 为每个清晰度获取 AID 和播放地址
    var qualityDetails = [];
    for (var q = 0; q < qualities.length; q++) {
      var quality = qualities[q];
      try {
        var aid = await _soop_getAid(bjId, bno, quality.name);
        if (!aid) continue;

        var viewUrl = await _soop_getStreamUrl(rmd, cdn, bno, quality.name);
        if (!viewUrl) continue;

        var finalUrl = viewUrl + "?aid=" + encodeURIComponent(aid);

        qualityDetails.push({
          roomId: bno,
          title: quality.label,
          qn: q,
          url: finalUrl,
          liveCodeType: "m3u8",
          liveType: "8",
        });
      } catch (e) {
        // 某些清晰度可能不可用，跳过
        continue;
      }
    }

    if (qualityDetails.length === 0) {
      _soop_throw("NOT_FOUND", "no playback URL available", {
        bjId: bjId,
        broadNo: bno,
      });
    }

    return [
      {
        cdn: "SOOP CDN",
        qualitys: qualityDetails,
      },
    ];
  },

  /**
   * 搜索
   */
  async search(payload) {
    var keyword = _soop_str(payload && payload.keyword);
    var page = (payload && payload.page) ? Number(payload.page) : 1;
    if (!keyword)
      _soop_throw("INVALID_ARGS", "keyword is required", { field: "keyword" });

    var rawList = await _soop_search(keyword, page);

    var rooms = [];
    for (var i = 0; i < rawList.length; i++) {
      rooms.push(_soop_searchToModel(rawList[i]));
    }

    return rooms;
  },

  /**
   * 获取房间详情
   */
  async getRoomDetail(payload) {
    var roomId = _soop_str(payload && payload.roomId);
    var userId = _soop_str(payload && payload.userId);

    var bjId = userId || roomId;
    if (!bjId)
      _soop_throw("INVALID_ARGS", "roomId or userId is required", {
        field: "roomId",
      });

    // 先用收藏记录的 roomId 尝试获取当前频道
    try {
      var channel = await _soop_getChannelInfo(bjId, roomId);
      if (Number(channel.RESULT) === 1 && channel.BNO) {
        return {
          userName: _soop_str(channel.BJNICK),
          roomTitle: _soop_str(channel.TITLE),
          roomCover:
            "https://liveimg.sooplive.co.kr/m/" + _soop_str(channel.BNO),
          userHeadImg: "",
          liveState: "1",
          userId: _soop_str(channel.BJID),
          roomId: _soop_str(channel.BNO),
          liveWatchedCount: "0",
        };
      }
    } catch (e) {
      // ignore
    }

    // 再用空 broadNo 查询当前频道，兼容收藏中 roomId 过期（主播重新开播后 BNO 变化）
    try {
      var latestChannel = await _soop_getChannelInfo(bjId, "");
      if (Number(latestChannel.RESULT) === 1 && latestChannel.BNO) {
        return {
          userName: _soop_str(latestChannel.BJNICK),
          roomTitle: _soop_str(latestChannel.TITLE),
          roomCover:
            "https://liveimg.sooplive.co.kr/m/" + _soop_str(latestChannel.BNO),
          userHeadImg: "",
          liveState: "1",
          userId: _soop_str(latestChannel.BJID),
          roomId: _soop_str(latestChannel.BNO),
          liveWatchedCount: "0",
        };
      }
    } catch (e) {
      // ignore
    }

    // 从 station_status 获取基本信息
    var stationData = await _soop_getStationStatus(bjId);
    if (stationData) {
      return {
        userName: _soop_str(stationData.user_nick || stationData.station_name),
        roomTitle: _soop_str(
          stationData.station_title || stationData.station_name || ""
        ),
        roomCover: "",
        userHeadImg: "",
        // broad_start 可能是历史开播时间，不能作为在线状态判定依据
        liveState: "0",
        userId: _soop_str(stationData.user_id || bjId),
        roomId: _soop_str(stationData.station_no || bjId),
        liveWatchedCount: _soop_str(stationData.total_view_cnt || "0"),
      };
    }

    _soop_throw("NOT_FOUND", "SOOP room not found", { bjId: bjId });
  },

  /**
   * 查询直播状态
   */
  async getLiveState(payload) {
    var roomId = _soop_str(payload && payload.roomId);
    var userId = _soop_str(payload && payload.userId);

    var bjId = userId || roomId;
    if (!bjId)
      _soop_throw("INVALID_ARGS", "roomId or userId is required", {
        field: "roomId",
      });

    try {
      var channel = await _soop_getChannelInfo(bjId, "");
      if (Number(channel.RESULT) === 1 && channel.BNO) {
        return { liveState: "1" };
      }
    } catch (e) {
      // ignore
    }

    return { liveState: "0" };
  },

  /**
   * 解析分享链接/口令
   */
  async resolveShare(payload) {
    var shareCode = _soop_str(payload && payload.shareCode);
    if (!shareCode)
      _soop_throw("INVALID_ARGS", "shareCode is required", {
        field: "shareCode",
      });

    var bjId = _soop_parseShareCode(shareCode);
    return await this.getRoomDetail({ roomId: bjId, userId: bjId });
  },

  /**
   * 获取弹幕连接参数
   * WebSocket: wss://{CHDOMAIN}:{CHPT+1}/Websocket/{BJID}
   * SubProtocol: chat
   */
  async getDanmaku(payload) {
    var roomId = _soop_str(payload && payload.roomId);
    var userId = _soop_str(payload && payload.userId);

    var bjId = userId || roomId;
    if (!bjId)
      _soop_throw("INVALID_ARGS", "roomId or userId is required", {
        field: "roomId",
      });

    try {
      var channel = await _soop_getChannelInfo(bjId, roomId);
      if (Number(channel.RESULT) === 1) {
        var chDomain = _soop_str(channel.CHDOMAIN).toLowerCase();
        var chPort = String(Number(channel.CHPT || 0) + 1);
        var chatNo = _soop_str(channel.CHATNO);
        var ftk = _soop_str(channel.FTK);
        var broadNo = _soop_str(channel.BNO);
        var bjid = _soop_str(channel.BJID);

        return {
          args: {
            roomId: broadNo,
            chatDomain: chDomain,
            chatPort: chPort,
            chatNo: chatNo,
            ftk: ftk,
            bjId: bjid,
            ws_url:
              "wss://" + chDomain + ":" + chPort + "/Websocket/" + bjid,
          },
          headers: null,
        };
      }
    } catch (e) {
      // 未开播，弹幕不可用
    }

    return { args: {}, headers: null };
  },

  /**
   * 设置用户登录 Cookie（由 APP 侧调用，用于 19+ 房间访问）
   */
  async setCookie(payload) {
    var cookie = (payload && payload.cookie) || "";
    __soop_runtimeCookie = String(cookie).trim();
    return { ok: true, hasCookie: __soop_runtimeCookie.length > 0 };
  },

  /**
   * 清除用户登录 Cookie
   */
  async clearCookie() {
    __soop_runtimeCookie = "";
    return { ok: true, hasCookie: false };
  },
};
