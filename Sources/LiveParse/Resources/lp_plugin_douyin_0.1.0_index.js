const _dy_ua = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36";
const _dy_runtime = {
  cookie: "",
  searchId: "",
  searchKeyword: ""
};

function _dy_throw(code, message, context) {
  if (globalThis.Host && typeof Host.raise === "function") {
    Host.raise(code, message, context || {});
  }
  if (globalThis.Host && typeof Host.makeError === "function") {
    throw Host.makeError(code || "UNKNOWN", message || "", context || {});
  }
  throw new Error(`LP_PLUGIN_ERROR:${JSON.stringify({ code: String(code || "UNKNOWN"), message: String(message || ""), context: context || {} })}`);
}

function _dy_tryDecodeURIComponent(text) {
  try {
    return decodeURIComponent(String(text || ""));
  } catch (e) {
    return String(text || "");
  }
}

function _dy_toString(v) {
  return v === undefined || v === null ? "" : String(v);
}

function _dy_normalizeCookie(cookie) {
  return _dy_toString(cookie).trim();
}

function _dy_setRuntimeCookie(cookie) {
  _dy_runtime.cookie = _dy_normalizeCookie(cookie);
}

function _dy_getRuntimeCookie(payload) {
  const payloadCookie = _dy_normalizeCookie(payload && payload.cookie);
  if (payloadCookie) {
    _dy_setRuntimeCookie(payloadCookie);
    return payloadCookie;
  }
  return _dy_runtime.cookie;
}

function _dy_withRuntimeCookie(payload) {
  const safePayload = payload && typeof payload === "object" ? Object.assign({}, payload) : {};
  const cookie = _dy_getRuntimeCookie(safePayload);
  if (cookie) safePayload.cookie = cookie;
  return safePayload;
}

function _dy_firstURL(text) {
  const m = String(text || "").match(/https?:\/\/[^\s|]+/);
  if (!m) return "";
  return String(m[0]).replace(/[),，。】]+$/g, "");
}

function _dy_firstMatch(text, re) {
  const m = String(text || "").match(re);
  return m && m[1] ? String(m[1]) : "";
}

function _dy_isNumericId(text) {
  const s = _dy_toString(text).trim();
  return /^\d+$/.test(s);
}

function _dy_firstArrayValue(v) {
  if (Array.isArray(v) && v.length > 0) {
    return _dy_toString(v[0]);
  }
  return "";
}

function _dy_extractFirstJSONObjectText(text) {
  const source = _dy_toString(text);
  let start = -1;
  let depth = 0;
  let inString = false;
  let escaped = false;

  for (let i = 0; i < source.length; i++) {
    const ch = source[i];

    if (start < 0) {
      if (ch === "{") {
        start = i;
        depth = 1;
      }
      continue;
    }

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
        return source.slice(start, i + 1);
      }
    }
  }

  return "";
}

function _dy_parseEscapedStateFromScript(html) {
  const marker = '\\"state\\":{';
  const markerPos = html.indexOf(marker);
  if (markerPos < 0) return null;

  const scriptStart = html.lastIndexOf("<script", markerPos);
  const scriptTagEnd = scriptStart >= 0 ? html.indexOf(">", scriptStart) : -1;
  const scriptEnd = html.indexOf("</script>", markerPos);

  let scriptText = "";
  if (scriptTagEnd >= 0 && scriptEnd > scriptTagEnd) {
    scriptText = html.slice(scriptTagEnd + 1, scriptEnd);
  } else {
    const start = Math.max(0, markerPos - 128);
    const end = Math.min(html.length, markerPos + 350000);
    scriptText = html.slice(start, end);
  }

  const normalized = _dy_toString(scriptText)
    .replace(/\\"/g, '"')
    .replace(/\\\\/g, "\\")
    .replace(/\\n/g, "");

  const jsonText = _dy_extractFirstJSONObjectText(normalized);
  if (!jsonText) return null;

  try {
    return JSON.parse(jsonText);
  } catch (e) {
    return null;
  }
}

function _dy_pickHeaders(cookie) {
  const out = {
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7; application/json",
    "Authority": "live.douyin.com",
    "Referer": "https://live.douyin.com",
    "User-Agent": _dy_ua
  };
  const normalizedCookie = _dy_normalizeCookie(cookie);
  if (normalizedCookie) out.Cookie = normalizedCookie;
  return out;
}

function _dy_requireCookie(payload, apiName) {
  const runtimePayload = _dy_withRuntimeCookie(payload || {});
  const cookie = _dy_normalizeCookie(runtimePayload.cookie);
  if (!cookie) {
    _dy_throw("AUTH_REQUIRED", `${apiName} requires cookie`, { api: String(apiName || "") });
  }
  runtimePayload.cookie = cookie;
  return runtimePayload;
}

function _dy_getCookieValue(cookie, name) {
  const source = _dy_toString(cookie);
  if (!source || !name) return "";
  const escapedName = String(name).replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const re = new RegExp(`(?:^|;\\s*)${escapedName}=([^;]*)`);
  const m = source.match(re);
  return m && m[1] ? _dy_toString(m[1]) : "";
}

function _dy_appendCookieKV(cookie, name, value) {
  const normalized = _dy_normalizeCookie(cookie);
  if (!name || !value) return normalized;
  if (_dy_getCookieValue(normalized, name)) return normalized;
  if (!normalized) return `${name}=${value}`;
  return `${normalized}${normalized.endsWith(";") ? "" : ";"} ${name}=${value}`;
}

function _dy_randomString(length, charset) {
  const chars = Array.from(_dy_toString(charset));
  if (chars.length === 0 || length <= 0) return "";
  let out = "";
  for (let i = 0; i < length; i++) {
    out += chars[Math.floor(Math.random() * chars.length)];
  }
  return out;
}

function _dy_generateMsToken() {
  const charset = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-";
  return _dy_randomString(184, charset);
}

function _dy_generateVerifyFp() {
  const now = Date.now().toString(36);
  const rand = _dy_randomString(36, "0123456789abcdefghijklmnopqrstuvwxyz");
  return `verify_${now}_${rand}`;
}

function _dy_objectKeys(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return "";
  try {
    return Object.keys(value).join("|");
  } catch (e) {
    return "";
  }
}

function _dy_firstNonEmptyString(values) {
  for (const value of values || []) {
    const text = _dy_toString(value);
    if (text) return text;
  }
  return "";
}

function _dy_firstNonEmptyObject(values) {
  for (const value of values || []) {
    if (value && typeof value === "object" && !Array.isArray(value)) {
      return value;
    }
  }
  return {};
}

function _dy_extractLiveModelsFromUserList(item) {
  const result = [];
  const userList = Array.isArray((item || {}).user_list) ? item.user_list : [];
  for (const userItem of userList) {
    const userInfo = (userItem && userItem.user_info) || {};
    const roomData = _dy_firstNonEmptyObject([
      userItem && userItem.room_data,
      userInfo && userInfo.room_data,
      userItem && userItem.live_info,
      userInfo && userInfo.live_info,
      userItem && userItem.webcast_info,
      userInfo && userInfo.webcast_info,
      userItem && userItem.room_info,
      userInfo && userInfo.room_info
    ]);
    const room = _dy_firstNonEmptyObject([
      roomData.room,
      roomData.data,
      roomData.room_data,
      roomData.live_info,
      roomData.webcast_info
    ]);
    const roomOwner = _dy_firstNonEmptyObject([roomData.owner, room.owner]);
    const avatar = userInfo.avatar_larger || userInfo.avatar_thumb || {};
    const cover = room.cover || roomData.cover || roomData.room_cover || {};
    const streamURL = room.stream_url || roomData.stream_url || {};
    const roomId = _dy_firstNonEmptyString([
      room.web_rid,
      room.room_id,
      room.id_str,
      room.id,
      room.room_id_str,
      roomData.web_rid,
      roomData.room_id,
      roomData.id_str,
      roomData.room_id_str,
      roomOwner.web_rid,
      userInfo.web_rid,
      userInfo.room_id,
      userInfo.room_id_str,
      userItem.room_id,
      userItem.room_id_str,
      userInfo.roomId
    ]);
    const userId = _dy_firstNonEmptyString([
      room.id_str,
      room.room_id_str,
      room.room_id,
      roomData.id_str,
      roomData.room_id_str,
      roomData.room_id,
      roomOwner.id_str,
      userInfo.uid,
      userInfo.user_id,
      roomId
    ]);
    if (!roomId) continue;
    const status = Number(room.status || roomData.status || roomData.live_status || userItem.live_status || 0);
    const hasStream = !!((((streamURL.live_core_sdk_data || {}).pull_data || {}).stream_data)
      || ((streamURL.hls_pull_url_map || {}).FULL_HD1)
      || ((streamURL.hls_pull_url_map || {}).HD1)
      || ((streamURL.hls_pull_url_map || {}).SD1));
    result.push({
      userName: _dy_toString(userInfo.nickname || roomOwner.nickname || ""),
      roomTitle: _dy_toString(room.title || roomData.title || roomData.room_title || userInfo.signature || ""),
      roomCover: _dy_firstArrayValue(cover.url_list),
      userHeadImg: _dy_firstArrayValue(avatar.url_list),
      liveType: "2",
      liveState: _dy_statusToLiveState(status, hasStream),
      userId,
      roomId,
      liveWatchedCount: _dy_toString(
        room.user_count_str ||
        (((room.room_view_stats || {}).display_short) || "") ||
        (((room.room_view_stats || {}).display_value) || "") ||
        roomData.user_count_str ||
        (((roomData.room_view_stats || {}).display_short) || "") ||
        roomData.online_total ||
        ""
      )
    });
  }
  return result;
}

function _dy_signDetail(queryString) {
  const query = _dy_toString(queryString);
  if (!query) _dy_throw("INVALID_ARGS", "queryString is empty", { field: "queryString" });
  if (typeof sign_datail !== "function") {
    _dy_throw("PARSE", "sign_datail is not available in douyin plugin");
  }
  return _dy_toString(sign_datail(query, _dy_ua));
}

const _dy_category_cache = {
  version: "",
  built: null,
  builtAt: 0
};

const _dy_category_source = {"version":"2025-01","description":"抖音直播分类数据（本地缓存）","categoryData":[{"partition":{"id_str":"101","type":4,"title":"聊天"},"sub_partition":[]},{"partition":{"id_str":"102","type":4,"title":"音乐"},"sub_partition":[]},{"partition":{"id_str":"103","type":4,"title":"游戏"},"sub_partition":[{"partition":{"id_str":"1","type":1,"title":"射击游戏"},"sub_partition":[{"partition":{"id_str":"1010032","type":1,"title":"和平精英"},"sub_partition":[]},{"partition":{"id_str":"1010037","type":1,"title":"穿越火线"},"sub_partition":[]},{"partition":{"id_str":"1011032","type":1,"title":"三角洲行动"},"sub_partition":[]},{"partition":{"id_str":"1010213","type":1,"title":"逆战手游"},"sub_partition":[]},{"partition":{"id_str":"1010017","type":1,"title":"无畏契约"},"sub_partition":[]},{"partition":{"id_str":"1010026","type":1,"title":"绝地求生"},"sub_partition":[]},{"partition":{"id_str":"1010003","type":1,"title":"CSGO"},"sub_partition":[]},{"partition":{"id_str":"1011309","type":1,"title":"无畏契约：源能行动"},"sub_partition":[]},{"partition":{"id_str":"1010015","type":1,"title":"穿越火线：枪战王者"},"sub_partition":[]},{"partition":{"id_str":"1011124","type":1,"title":"暗区突围：无限"},"sub_partition":[]},{"partition":{"id_str":"1010018","type":1,"title":"暗区突围"},"sub_partition":[]},{"partition":{"id_str":"1010002","type":1,"title":"Apex英雄"},"sub_partition":[]},{"partition":{"id_str":"1010339","type":1,"title":"守望先锋"},"sub_partition":[]},{"partition":{"id_str":"1010080","type":1,"title":"使命召唤手游"},"sub_partition":[]},{"partition":{"id_str":"1010132","type":1,"title":"逆战"},"sub_partition":[]},{"partition":{"id_str":"1010104","type":1,"title":"逃离塔科夫"},"sub_partition":[]},{"partition":{"id_str":"1010336","type":1,"title":"反恐精英OL"},"sub_partition":[]},{"partition":{"id_str":"1010214","type":1,"title":"萤火突击"},"sub_partition":[]},{"partition":{"id_str":"1010064","type":1,"title":"荒野行动"},"sub_partition":[]},{"partition":{"id_str":"1010329","type":1,"title":"使命召唤"},"sub_partition":[]},{"partition":{"id_str":"1010260","type":1,"title":"解限机"},"sub_partition":[]},{"partition":{"id_str":"1010593","type":1,"title":"The Finals"},"sub_partition":[]},{"partition":{"id_str":"1010409","type":1,"title":"生死狙击"},"sub_partition":[]},{"partition":{"id_str":"1010068","type":1,"title":"生死狙击2"},"sub_partition":[]},{"partition":{"id_str":"1010187","type":1,"title":"远光84"},"sub_partition":[]},{"partition":{"id_str":"1010367","type":1,"title":"战地1"},"sub_partition":[]},{"partition":{"id_str":"1010198","type":1,"title":"高能英雄"},"sub_partition":[]},{"partition":{"id_str":"1010168","type":1,"title":"卡拉彼丘"},"sub_partition":[]},{"partition":{"id_str":"1010402","type":1,"title":"彩虹六号：围攻"},"sub_partition":[]},{"partition":{"id_str":"1010383","type":1,"title":"堡垒之夜"},"sub_partition":[]},{"partition":{"id_str":"1010445","type":1,"title":"战术小队"},"sub_partition":[]},{"partition":{"id_str":"1010144","type":1,"title":"超凡先锋"},"sub_partition":[]}]},{"partition":{"id_str":"2","type":1,"title":"竞技游戏"},"sub_partition":[{"partition":{"id_str":"1010005","type":1,"title":"云顶之弈"},"sub_partition":[]},{"partition":{"id_str":"1010014","type":1,"title":"英雄联盟"},"sub_partition":[]},{"partition":{"id_str":"1010016","type":1,"title":"永劫无间"},"sub_partition":[]},{"partition":{"id_str":"1010041","type":1,"title":"第五人格"},"sub_partition":[]},{"partition":{"id_str":"1010055","type":1,"title":"金铲铲之战"},"sub_partition":[]},{"partition":{"id_str":"1010045","type":1,"title":"王者荣耀"},"sub_partition":[]},{"partition":{"id_str":"1010023","type":1,"title":"英雄联盟手游"},"sub_partition":[]},{"partition":{"id_str":"1010350","type":1,"title":"魔兽争霸3"},"sub_partition":[]},{"partition":{"id_str":"1010007","type":1,"title":"巅峰极速"},"sub_partition":[]},{"partition":{"id_str":"1010146","type":1,"title":"QQ飞车端游"},"sub_partition":[]},{"partition":{"id_str":"1010341","type":1,"title":"DOTA1"},"sub_partition":[]},{"partition":{"id_str":"1010278","type":1,"title":"永劫无间手游"},"sub_partition":[]},{"partition":{"id_str":"1010093","type":1,"title":"DOTA2"},"sub_partition":[]},{"partition":{"id_str":"1010340","type":1,"title":"坦克世界"},"sub_partition":[]},{"partition":{"id_str":"1010397","type":1,"title":"炉石传说"},"sub_partition":[]},{"partition":{"id_str":"1010102","type":1,"title":"红色警戒2"},"sub_partition":[]},{"partition":{"id_str":"1010033","type":1,"title":"QQ飞车手游"},"sub_partition":[]},{"partition":{"id_str":"1010131","type":1,"title":"跑跑卡丁车官方竞速版"},"sub_partition":[]},{"partition":{"id_str":"1010313","type":1,"title":"狼人杀"},"sub_partition":[]},{"partition":{"id_str":"1010170","type":1,"title":"战争雷霆"},"sub_partition":[]},{"partition":{"id_str":"1010292","type":1,"title":"决胜巅峰"},"sub_partition":[]},{"partition":{"id_str":"1010061","type":1,"title":"三国杀"},"sub_partition":[]},{"partition":{"id_str":"1010483","type":1,"title":"星际争霸"},"sub_partition":[]},{"partition":{"id_str":"1010331","type":1,"title":"跑跑卡丁车"},"sub_partition":[]},{"partition":{"id_str":"1010686","type":1,"title":"极品飞车：集结"},"sub_partition":[]},{"partition":{"id_str":"1010235","type":1,"title":"王者万象棋"},"sub_partition":[]},{"partition":{"id_str":"1010435","type":1,"title":"至暗时刻"},"sub_partition":[]},{"partition":{"id_str":"1010418","type":1,"title":"战舰世界"},"sub_partition":[]},{"partition":{"id_str":"1010430","type":1,"title":"恐惧饥荒"},"sub_partition":[]},{"partition":{"id_str":"1010429","type":1,"title":"极限竞速：地平线5"},"sub_partition":[]},{"partition":{"id_str":"1010509","type":1,"title":"星际争霸2"},"sub_partition":[]},{"partition":{"id_str":"1010524","type":1,"title":"王牌竞速"},"sub_partition":[]},{"partition":{"id_str":"1010180","type":1,"title":"全明星街球派对"},"sub_partition":[]},{"partition":{"id_str":"1010230","type":1,"title":"皇室战争"},"sub_partition":[]},{"partition":{"id_str":"1010057","type":1,"title":"决战！平安京"},"sub_partition":[]},{"partition":{"id_str":"1010030","type":1,"title":"实况足球"},"sub_partition":[]},{"partition":{"id_str":"1010327","type":1,"title":"猫和老鼠"},"sub_partition":[]},{"partition":{"id_str":"1010054","type":1,"title":"哈利波特：魔法觉醒"},"sub_partition":[]},{"partition":{"id_str":"1010058","type":1,"title":"逃跑吧！少年"},"sub_partition":[]},{"partition":{"id_str":"1010138","type":1,"title":"荒野乱斗"},"sub_partition":[]},{"partition":{"id_str":"1010395","type":1,"title":"坦克世界：闪电战"},"sub_partition":[]},{"partition":{"id_str":"1010353","type":1,"title":"极限竞速：地平线4"},"sub_partition":[]},{"partition":{"id_str":"1010107","type":1,"title":"最强NBA"},"sub_partition":[]},{"partition":{"id_str":"1010264","type":1,"title":"极品飞车"},"sub_partition":[]},{"partition":{"id_str":"1010381","type":1,"title":"曙光英雄"},"sub_partition":[]},{"partition":{"id_str":"1010510","type":1,"title":"红色警戒3"},"sub_partition":[]}]},{"partition":{"id_str":"3","type":1,"title":"单机游戏"},"sub_partition":[{"partition":{"id_str":"1010324","type":1,"title":"植物大战僵尸"},"sub_partition":[]},{"partition":{"id_str":"1010791","type":1,"title":"星露谷物语"},"sub_partition":[]},{"partition":{"id_str":"1011359","type":1,"title":"流放之路2"},"sub_partition":[]},{"partition":{"id_str":"1010358","type":1,"title":"黑神话：悟空"},"sub_partition":[]},{"partition":{"id_str":"1011048","type":1,"title":"俄罗斯钓鱼4"},"sub_partition":[]},{"partition":{"id_str":"1011393","type":1,"title":"Half Sword"},"sub_partition":[]},{"partition":{"id_str":"1010100","type":1,"title":"方舟"},"sub_partition":[]},{"partition":{"id_str":"1010250","type":1,"title":"星际战甲"},"sub_partition":[]},{"partition":{"id_str":"1010335","type":1,"title":"饥荒"},"sub_partition":[]},{"partition":{"id_str":"1010087","type":1,"title":"艾尔登法环"},"sub_partition":[]},{"partition":{"id_str":"1010038","type":1,"title":"猛兽派对"},"sub_partition":[]},{"partition":{"id_str":"1010593","type":1,"title":"The Finals"},"sub_partition":[]},{"partition":{"id_str":"1010149","type":1,"title":"只狼：影逝二度"},"sub_partition":[]},{"partition":{"id_str":"1010981","type":1,"title":"幻兽帕鲁"},"sub_partition":[]},{"partition":{"id_str":"1010783","type":1,"title":"森林之子"},"sub_partition":[]},{"partition":{"id_str":"1010363","type":1,"title":"荒野大镖客2"},"sub_partition":[]},{"partition":{"id_str":"1010326","type":1,"title":"人渣"},"sub_partition":[]},{"partition":{"id_str":"1010361","type":1,"title":"街头霸王6"},"sub_partition":[]},{"partition":{"id_str":"1010429","type":1,"title":"极限竞速：地平线5"},"sub_partition":[]},{"partition":{"id_str":"1010401","type":1,"title":"骑马与砍杀2：霸主"},"sub_partition":[]},{"partition":{"id_str":"1011136","type":1,"title":"掘地求升"},"sub_partition":[]},{"partition":{"id_str":"1011119","type":1,"title":"英雄无敌3"},"sub_partition":[]},{"partition":{"id_str":"1010396","type":1,"title":"泰拉瑞亚"},"sub_partition":[]},{"partition":{"id_str":"1010779","type":1,"title":"全面战争：三国"},"sub_partition":[]},{"partition":{"id_str":"1010171","type":1,"title":"女神异闻录5"},"sub_partition":[]},{"partition":{"id_str":"1010847","type":1,"title":"宝可梦朱紫"},"sub_partition":[]},{"partition":{"id_str":"1010334","type":1,"title":"拳皇97"},"sub_partition":[]},{"partition":{"id_str":"1010774","type":1,"title":"仁王"},"sub_partition":[]},{"partition":{"id_str":"1010030","type":1,"title":"实况足球"},"sub_partition":[]},{"partition":{"id_str":"1010081","type":1,"title":"塞尔达传说：旷野之息"},"sub_partition":[]},{"partition":{"id_str":"1010514","type":1,"title":"三国志14"},"sub_partition":[]},{"partition":{"id_str":"1010367","type":1,"title":"战地1"},"sub_partition":[]},{"partition":{"id_str":"1011000","type":1,"title":"绝地潜兵2"},"sub_partition":[]},{"partition":{"id_str":"1010436","type":1,"title":"双影奇境"},"sub_partition":[]},{"partition":{"id_str":"1010360","type":1,"title":"空洞骑士：丝之歌"},"sub_partition":[]},{"partition":{"id_str":"1011304","type":1,"title":"怪物猎人：荒野"},"sub_partition":[]},{"partition":{"id_str":"1010142","type":1,"title":"都市：天际线"},"sub_partition":[]},{"partition":{"id_str":"1011170","type":1,"title":"链在一起"},"sub_partition":[]},{"partition":{"id_str":"1010424","type":1,"title":"古墓丽影：暗影"},"sub_partition":[]},{"partition":{"id_str":"1010320","type":1,"title":"匹诺曹的谎言"},"sub_partition":[]},{"partition":{"id_str":"1010128","type":1,"title":"赛博朋克2077"},"sub_partition":[]},{"partition":{"id_str":"1011238","type":1,"title":"超级兔子人"},"sub_partition":[]},{"partition":{"id_str":"1010411","type":1,"title":"流放之路"},"sub_partition":[]},{"partition":{"id_str":"1011399","type":1,"title":"天国拯救2"},"sub_partition":[]},{"partition":{"id_str":"1010626","type":1,"title":"潜水员戴夫"},"sub_partition":[]},{"partition":{"id_str":"1010408","type":1,"title":"木筏求生"},"sub_partition":[]},{"partition":{"id_str":"1010130","type":1,"title":"人类：一败涂地"},"sub_partition":[]},{"partition":{"id_str":"1010485","type":1,"title":"刺客信条：奥德赛"},"sub_partition":[]},{"partition":{"id_str":"1010846","type":1,"title":"致命公司"},"sub_partition":[]},{"partition":{"id_str":"1010353","type":1,"title":"极限竞速：地平线4"},"sub_partition":[]},{"partition":{"id_str":"1010082","type":1,"title":"塞尔达传说：王国之泪"},"sub_partition":[]},{"partition":{"id_str":"1011366","type":1,"title":"去上班"},"sub_partition":[]},{"partition":{"id_str":"1010515","type":1,"title":"三国志11"},"sub_partition":[]}]},{"partition":{"id_str":"4","type":1,"title":"棋牌游戏"},"sub_partition":[{"partition":{"id_str":"1010040","type":1,"title":"指尖四川麻将"},"sub_partition":[]},{"partition":{"id_str":"1010004","type":1,"title":"JJ斗地主"},"sub_partition":[]},{"partition":{"id_str":"1010063","type":1,"title":"JJ象棋"},"sub_partition":[]},{"partition":{"id_str":"1010094","type":1,"title":"JJ麻将"},"sub_partition":[]},{"partition":{"id_str":"1010062","type":1,"title":"欢乐斗地主"},"sub_partition":[]},{"partition":{"id_str":"1010060","type":1,"title":"天天象棋"},"sub_partition":[]},{"partition":{"id_str":"1010012","type":1,"title":"途游斗地主"},"sub_partition":[]},{"partition":{"id_str":"1010714","type":1,"title":"微乐斗地主"},"sub_partition":[]},{"partition":{"id_str":"1010028","type":1,"title":"芒果斗地主"},"sub_partition":[]},{"partition":{"id_str":"1010711","type":1,"title":"开运麻将"},"sub_partition":[]},{"partition":{"id_str":"1010710","type":1,"title":"微乐四川麻将"},"sub_partition":[]},{"partition":{"id_str":"1010721","type":1,"title":"多乐升级"},"sub_partition":[]},{"partition":{"id_str":"1010059","type":1,"title":"腾讯欢乐麻将"},"sub_partition":[]},{"partition":{"id_str":"1010720","type":1,"title":"多乐够级"},"sub_partition":[]},{"partition":{"id_str":"1010098","type":1,"title":"禅游斗地主"},"sub_partition":[]}]},{"partition":{"id_str":"5","type":1,"title":"休闲益智"},"sub_partition":[{"partition":{"id_str":"1010022","type":1,"title":"我的世界"},"sub_partition":[]},{"partition":{"id_str":"1010011","type":1,"title":"蛋仔派对"},"sub_partition":[]},{"partition":{"id_str":"1011640","type":1,"title":"鹅鸭杀（手游）"},"sub_partition":[]},{"partition":{"id_str":"1010806","type":1,"title":"天天台球"},"sub_partition":[]},{"partition":{"id_str":"1010263","type":1,"title":"元梦之星"},"sub_partition":[]},{"partition":{"id_str":"1010010","type":1,"title":"球球大作战"},"sub_partition":[]},{"partition":{"id_str":"1010520","type":1,"title":"开心消消乐"},"sub_partition":[]},{"partition":{"id_str":"1010895","type":1,"title":"群雄逐鹿"},"sub_partition":[]},{"partition":{"id_str":"1010129","type":1,"title":"忍者必须死3"},"sub_partition":[]},{"partition":{"id_str":"1010046","type":1,"title":"迷你世界"},"sub_partition":[]},{"partition":{"id_str":"1010056","type":1,"title":"贪吃蛇大作战"},"sub_partition":[]},{"partition":{"id_str":"1010921","type":1,"title":"台球帝国"},"sub_partition":[]},{"partition":{"id_str":"1010099","type":1,"title":"地铁跑酷"},"sub_partition":[]},{"partition":{"id_str":"1010410","type":1,"title":"天天酷跑"},"sub_partition":[]}]},{"partition":{"id_str":"6","type":1,"title":"角色扮演"},"sub_partition":[{"partition":{"id_str":"1010053","type":1,"title":"梦幻西游"},"sub_partition":[]},{"partition":{"id_str":"1010051","type":1,"title":"梦幻西游手游"},"sub_partition":[]},{"partition":{"id_str":"1010039","type":1,"title":"原神"},"sub_partition":[]},{"partition":{"id_str":"1010150","type":1,"title":"魔兽世界"},"sub_partition":[]},{"partition":{"id_str":"1010190","type":1,"title":"明日方舟：终末地"},"sub_partition":[]},{"partition":{"id_str":"1010271","type":1,"title":"燕云十六声"},"sub_partition":[]},{"partition":{"id_str":"1010205","type":1,"title":"大话西游2"},"sub_partition":[]},{"partition":{"id_str":"1010092","type":1,"title":"地下城与勇士"},"sub_partition":[]},{"partition":{"id_str":"1010042","type":1,"title":"火影忍者手游"},"sub_partition":[]},{"partition":{"id_str":"1010241","type":1,"title":"火炬之光：无限"},"sub_partition":[]},{"partition":{"id_str":"1010159","type":1,"title":"鸣潮"},"sub_partition":[]},{"partition":{"id_str":"1010083","type":1,"title":"逆水寒手游"},"sub_partition":[]},{"partition":{"id_str":"1010234","type":1,"title":"地下城与勇士：起源"},"sub_partition":[]},{"partition":{"id_str":"1010035","type":1,"title":"光遇"},"sub_partition":[]},{"partition":{"id_str":"1010249","type":1,"title":"剑网3"},"sub_partition":[]},{"partition":{"id_str":"1010006","type":1,"title":"明日之后"},"sub_partition":[]},{"partition":{"id_str":"1010116","type":1,"title":"问道"},"sub_partition":[]},{"partition":{"id_str":"1010558","type":1,"title":"七日世界"},"sub_partition":[]},{"partition":{"id_str":"1010151","type":1,"title":"诛仙世界"},"sub_partition":[]},{"partition":{"id_str":"1010143","type":1,"title":"大话西游"},"sub_partition":[]},{"partition":{"id_str":"1010233","type":1,"title":"命运方舟"},"sub_partition":[]},{"partition":{"id_str":"1010155","type":1,"title":"绝区零"},"sub_partition":[]},{"partition":{"id_str":"1010364","type":1,"title":"逆水寒"},"sub_partition":[]},{"partition":{"id_str":"1010250","type":1,"title":"星际战甲"},"sub_partition":[]},{"partition":{"id_str":"1010203","type":1,"title":"洛克王国"},"sub_partition":[]},{"partition":{"id_str":"1010253","type":1,"title":"无限暖暖"},"sub_partition":[]},{"partition":{"id_str":"1010049","type":1,"title":"梦幻西游网页版"},"sub_partition":[]},{"partition":{"id_str":"1010149","type":1,"title":"只狼：影逝二度"},"sub_partition":[]},{"partition":{"id_str":"1010119","type":1,"title":"天涯明月刀"},"sub_partition":[]},{"partition":{"id_str":"1010568","type":1,"title":"新大话西游3"},"sub_partition":[]},{"partition":{"id_str":"1011139","type":1,"title":"航海王：壮志雄心"},"sub_partition":[]},{"partition":{"id_str":"1010533","type":1,"title":"妄想山海"},"sub_partition":[]},{"partition":{"id_str":"1010096","type":1,"title":"暗黑破坏神：不朽"},"sub_partition":[]},{"partition":{"id_str":"1010024","type":1,"title":"月圆之夜"},"sub_partition":[]},{"partition":{"id_str":"1010311","type":1,"title":"冒险岛：枫之传说"},"sub_partition":[]},{"partition":{"id_str":"1010256","type":1,"title":"诛仙2"},"sub_partition":[]},{"partition":{"id_str":"1010097","type":1,"title":"长安幻想"},"sub_partition":[]},{"partition":{"id_str":"1010231","type":1,"title":"航海王热血航线"},"sub_partition":[]},{"partition":{"id_str":"1010171","type":1,"title":"女神异闻录5"},"sub_partition":[]},{"partition":{"id_str":"1010631","type":1,"title":"境·界 刀鸣"},"sub_partition":[]},{"partition":{"id_str":"1010193","type":1,"title":"星球：重启"},"sub_partition":[]},{"partition":{"id_str":"1010044","type":1,"title":"晶核"},"sub_partition":[]},{"partition":{"id_str":"1010320","type":1,"title":"匹诺曹的谎言"},"sub_partition":[]},{"partition":{"id_str":"1010257","type":1,"title":"新完美世界"},"sub_partition":[]},{"partition":{"id_str":"1010411","type":1,"title":"流放之路"},"sub_partition":[]},{"partition":{"id_str":"1010405","type":1,"title":"激战2"},"sub_partition":[]},{"partition":{"id_str":"1010675","type":1,"title":"时空猎人3"},"sub_partition":[]}]},{"partition":{"id_str":"7","type":1,"title":"策略卡牌"},"sub_partition":[{"partition":{"id_str":"1010013","type":1,"title":"明日方舟"},"sub_partition":[]},{"partition":{"id_str":"1010324","type":1,"title":"植物大战僵尸"},"sub_partition":[]},{"partition":{"id_str":"1010043","type":1,"title":"崩坏：星穹铁道"},"sub_partition":[]},{"partition":{"id_str":"1010160","type":1,"title":"少女前线2：追放"},"sub_partition":[]},{"partition":{"id_str":"1010025","type":1,"title":"阴阳师"},"sub_partition":[]},{"partition":{"id_str":"1010009","type":1,"title":"三国志·战略版"},"sub_partition":[]},{"partition":{"id_str":"1010021","type":1,"title":"率土之滨"},"sub_partition":[]},{"partition":{"id_str":"1010067","type":1,"title":"植物大战僵尸2"},"sub_partition":[]},{"partition":{"id_str":"1010365","type":1,"title":"斗罗大陆：魂师对决"},"sub_partition":[]},{"partition":{"id_str":"1010084","type":1,"title":"恋与深空"},"sub_partition":[]},{"partition":{"id_str":"1010145","type":1,"title":"部落冲突"},"sub_partition":[]},{"partition":{"id_str":"1010105","type":1,"title":"万国觉醒"},"sub_partition":[]},{"partition":{"id_str":"1010419","type":1,"title":"奥奇传说"},"sub_partition":[]},{"partition":{"id_str":"1010287","type":1,"title":"大话西游：归来"},"sub_partition":[]},{"partition":{"id_str":"1010515","type":1,"title":"三国志11"},"sub_partition":[]},{"partition":{"id_str":"1010196","type":1,"title":"重返未来1999"},"sub_partition":[]}]}]},{"partition":{"id_str":"104","type":4,"title":"二次元"},"sub_partition":[]},{"partition":{"id_str":"105","type":4,"title":"舞蹈"},"sub_partition":[]},{"partition":{"id_str":"106","type":4,"title":"文化"},"sub_partition":[]},{"partition":{"id_str":"107","type":4,"title":"生活"},"sub_partition":[]},{"partition":{"id_str":"108","type":4,"title":"运动"},"sub_partition":[]}]};

function _dy_fallbackCategories() {
  return [
    {
      id: "101",
      title: "聊天",
      icon: "",
      biz: "",
      subList: [{ id: "101", parentId: "4", title: "聊天", icon: "", biz: "" }]
    },
    {
      id: "102",
      title: "音乐",
      icon: "",
      biz: "",
      subList: [{ id: "102", parentId: "4", title: "音乐", icon: "", biz: "" }]
    },
    {
      id: "103",
      title: "游戏",
      icon: "",
      biz: "",
      subList: [
        { id: "1010045", parentId: "1", title: "王者荣耀", icon: "", biz: "" },
        { id: "1010014", parentId: "1", title: "英雄联盟", icon: "", biz: "" },
        { id: "1010032", parentId: "1", title: "和平精英", icon: "", biz: "" }
      ]
    },
    {
      id: "104",
      title: "娱乐天地",
      icon: "",
      biz: "",
      subList: [{ id: "104", parentId: "4", title: "娱乐天地", icon: "", biz: "" }]
    }
  ];
}

function _dy_makeCategoryNode(partition, parentIdOverride) {
  const node = partition && typeof partition === "object" ? partition : {};
  const id = _dy_toString(node.id_str);
  if (!id) return null;
  const parentIdValue = parentIdOverride === undefined || parentIdOverride === null
    ? node.type
    : parentIdOverride;
  return {
    id,
    parentId: _dy_toString(parentIdValue),
    title: _dy_toString(node.title),
    icon: "",
    biz: ""
  };
}

function _dy_buildCategoriesFromSource(source) {
  const categoryData = Array.isArray((source || {}).categoryData) ? source.categoryData : [];
  const result = [];

  for (const item of categoryData) {
    const partition = (item && item.partition) || {};
    const mainId = _dy_toString(partition.id_str);
    const mainTitle = _dy_toString(partition.title);
    if (!mainId || !mainTitle) continue;

    const subPartition = Array.isArray(item && item.sub_partition) ? item.sub_partition : null;

    if (subPartition && subPartition.length === 0) {
      const node = _dy_makeCategoryNode(partition, partition.type);
      if (!node) continue;
      result.push({
        id: mainId,
        title: mainTitle,
        icon: "",
        biz: "",
        subList: [node]
      });
      continue;
    }

    if (!subPartition) {
      continue;
    }

    if (subPartition.length === 0) {
      const node = _dy_makeCategoryNode(partition, mainId);
      if (!node) continue;
      result.push({
        id: mainId,
        title: mainTitle,
        icon: "",
        biz: "",
        subList: [node]
      });
      continue;
    }

    const subList = [];

    for (const subItem of subPartition) {
      const subNodePartition = (subItem && subItem.partition) || {};
      const subNode = _dy_makeCategoryNode(subNodePartition, subNodePartition.type);
      if (!subNode) continue;

      const thirdPartition = Array.isArray(subItem && subItem.sub_partition) ? subItem.sub_partition : null;
      if (thirdPartition && thirdPartition.length > 0) {
        const thirdList = [];
        for (const thirdItem of thirdPartition) {
          const thirdNodePartition = (thirdItem && thirdItem.partition) || {};
          const thirdNode = _dy_makeCategoryNode(thirdNodePartition, thirdNodePartition.type);
          if (thirdNode) thirdList.push(thirdNode);
        }
        if (thirdList.length > 0) {
          result.push({
            id: _dy_toString(subNodePartition.id_str),
            title: _dy_toString(subNodePartition.title),
            icon: "",
            biz: "",
            subList: thirdList
          });
        }
      } else {
        subList.push(subNode);
      }
    }

    if (subList.length > 0) {
      result.push({
        id: mainId,
        title: mainTitle,
        icon: "",
        biz: "",
        subList
      });
    }
  }

  return result;
}

function _dy_defaultCategories() {
  const sourceVersion = _dy_toString((_dy_category_source || {}).version);
  if (_dy_category_cache.built && _dy_category_cache.version === sourceVersion) {
    return _dy_category_cache.built;
  }

  const built = _dy_buildCategoriesFromSource(_dy_category_source);
  const resolved = built.length > 0 ? built : _dy_fallbackCategories();
  _dy_category_cache.version = sourceVersion;
  _dy_category_cache.built = resolved;
  _dy_category_cache.builtAt = Date.now();
  return resolved;
}
function _dy_statusToLiveState(status, hasStream) {
  const s = Number(status || 0);
  if (s === 2) return hasStream ? "1" : "0";
  if (s === 4) return "0";
  return "3";
}

function _dy_buildLiveModel(roomData, explicitRoomId) {
  const room = (roomData && roomData.room) || {};
  const roomInfo = (roomData && roomData.roomInfo) || {};
  const owner = room.owner || {};
  const anchor = roomInfo.anchor || {};
  const streamUrl = room.stream_url || {};
  const hlsMap = streamUrl.hls_pull_url_map || {};
  const hasStream = !!(((streamUrl.live_core_sdk_data || {}).pull_data || {}).stream_data)
    || !!hlsMap.FULL_HD1 || !!hlsMap.HD1 || !!hlsMap.SD1 || !!hlsMap.SD2;

  const status = Number(room.status || 0);
  const activeOwner = status === 2 ? owner : anchor;
  const cover = room.cover || {};
  const avatar = activeOwner.avatar_thumb || {};
  const roomViewStats = room.room_view_stats || {};

  const userId = _dy_toString(room.id_str || activeOwner.id_str || "");
  const webRid = _dy_toString(activeOwner.web_rid || explicitRoomId || room.id_str || "");

  return {
    userName: _dy_toString(activeOwner.nickname || ""),
    roomTitle: _dy_toString(room.title || ""),
    roomCover: _dy_firstArrayValue(cover.url_list),
    userHeadImg: _dy_firstArrayValue(avatar.url_list),
    liveType: "2",
    liveState: _dy_statusToLiveState(status, hasStream),
    userId,
    roomId: webRid,
    liveWatchedCount: _dy_toString(room.user_count_str || roomViewStats.display_value || "")
  };
}

function _dy_extractPlayDetailsFromStreamData(roomId, streamDataText) {
  const details = [];
  if (!streamDataText) return details;

  let parsed;
  try {
    parsed = JSON.parse(String(streamDataText));
  } catch (e) {
    return details;
  }

  const data = (parsed && parsed.data) || {};
  const qualityMap = {
    origin: "原画",
    uhd: "蓝光",
    hd: "超清",
    sd: "高清",
    ld: "标清",
    md: "标清2",
    audio: "音频"
  };

  Object.keys(data).forEach(function (key) {
    const quality = data[key] || {};
    const main = quality.main || {};
    const title = qualityMap[key] || key;
    if (main.flv) {
      details.push({ roomId: _dy_toString(roomId), title: `${title}_FLV`, qn: 0, url: _dy_toString(main.flv), liveCodeType: "flv", liveType: "2" });
    }
    if (main.hls) {
      details.push({ roomId: _dy_toString(roomId), title: `${title}_HLS`, qn: 0, url: _dy_toString(main.hls), liveCodeType: "m3u8", liveType: "2" });
    }
  });

  return details;
}

function _dy_extractPlayArgs(roomData, roomId) {
  const room = (roomData && roomData.room) || {};
  const streamUrl = room.stream_url || {};
  const hlsMap = streamUrl.hls_pull_url_map || {};

  let qualitys = [];

  const streamData = (((streamUrl.live_core_sdk_data || {}).pull_data || {}).stream_data) || "";
  qualitys = qualitys.concat(_dy_extractPlayDetailsFromStreamData(roomId, streamData));

  if (qualitys.length === 0) {
    if (hlsMap.FULL_HD1) qualitys.push({ roomId: _dy_toString(roomId), title: "超清", qn: 0, url: _dy_toString(hlsMap.FULL_HD1), liveCodeType: "m3u8", liveType: "2" });
    if (hlsMap.HD1) qualitys.push({ roomId: _dy_toString(roomId), title: "高清", qn: 0, url: _dy_toString(hlsMap.HD1), liveCodeType: "m3u8", liveType: "2" });
    if (hlsMap.SD1) qualitys.push({ roomId: _dy_toString(roomId), title: "标清 1", qn: 0, url: _dy_toString(hlsMap.SD1), liveCodeType: "m3u8", liveType: "2" });
    if (hlsMap.SD2) qualitys.push({ roomId: _dy_toString(roomId), title: "标清 2", qn: 0, url: _dy_toString(hlsMap.SD2), liveCodeType: "m3u8", liveType: "2" });
  }

  if (qualitys.length === 0) {
    _dy_throw("INVALID_RESPONSE", `empty quality list for roomId=${roomId}`, { roomId: String(roomId || "") });
  }

  return [{ cdn: "线路 1", qualitys }];
}

function _dy_enrichCookie(cookie) {
  let enriched = _dy_normalizeCookie(cookie);
  if (!enriched) return enriched;
  if (!_dy_getCookieValue(enriched, "__ac_nonce")) {
    enriched = _dy_appendCookieKV(enriched, "__ac_nonce", _dy_randomString(21, "0123456789abcdef"));
  }
  if (!_dy_getCookieValue(enriched, "msToken")) {
    enriched = _dy_appendCookieKV(enriched, "msToken", _dy_generateMsToken());
  }
  return enriched;
}

// 获取新鲜匿名 cookie（ttwid + __ac_nonce + msToken）
// ttwid 通过 bytedance 注册接口获取，__ac_nonce 和 msToken 随机生成
// 注意：不使用用户的 auth cookie 调用 API，否则会触发 444 反爬
async function _dy_getCookie(roomId) {
  let ttwid = "";
  try {
    const resp = await Host.http.request({
      url: "https://ttwid.bytedance.com/ttwid/union/register/",
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        region: "cn",
        aid: 1768,
        needFid: false,
        service: "www.ixigua.com",
        migrate_info: { ticket: "", source: "node" },
        cbUrlProtocol: "https",
        union: true
      }),
      timeout: 10
    });
    const setCookie = _dy_toString(resp && resp.headers && resp.headers["Set-Cookie"]);
    console.log(`[douyin] _dy_getCookie: ttwid register status=${resp && resp.status}, Set-Cookie length=${setCookie.length}`);
    if (setCookie) {
      const parts = setCookie.split(";");
      for (const part of parts) {
        const kv = part.trim();
        if (kv.startsWith("ttwid=")) {
          ttwid = kv.split("=")[1];
          break;
        }
      }
    }
  } catch (e) {
    console.log(`[douyin] _dy_getCookie: ttwid register failed: ${_dy_toString(e && e.message)}`);
  }

  let dyCookie = "";
  if (ttwid) {
    dyCookie += "ttwid=" + ttwid + ";";
  }
  dyCookie += "__ac_nonce=" + _dy_randomString(21, "0123456789abcdef") + ";";
  dyCookie += "msToken=" + _dy_generateMsToken() + ";";
  console.log(`[douyin] _dy_getCookie: ttwid=${ttwid ? "yes" : "no"}, cookieLen=${dyCookie.length}`);
  return dyCookie;
}

async function _dy_getRoomDataByApi(roomId, userId, cookie) {
  const webRid = _dy_toString(roomId).trim();
  const roomIdStr = _dy_toString(userId || roomId).trim();
  if (!webRid) _dy_throw("INVALID_ARGS", "roomId is empty", { field: "roomId" });

  // 始终使用匿名 cookie（ttwid + __ac_nonce + msToken），不使用用户 auth cookie
  // 用户 auth cookie 会触发 444 反爬
  const finalCookie = await _dy_getCookie(webRid);

  // 和 Swift buildRequestUrl 完全一致：不 encode，直接拼接
  const params = `aid=6383&app_name=douyin_web&live_id=1&device_platform=web&language=zh-CN&enter_from=web_live&cookie_enabled=true&screen_width=1920&screen_height=1080&browser_language=zh-CN&browser_platform=MacIntel&browser_name=Chrome&browser_version=140.0.0.0&web_rid=${webRid}&room_id_str=${roomIdStr}&enter_source=&is_need_double_stream=false&insert_task_id=&live_reason=`;

  const aBogus = _dy_signDetail(params);
  // Swift: url + "?\(urlParams)&a_bogus=\(signature)" — 不 encodeURIComponent
  const requestURL = `https://live.douyin.com/webcast/room/web/enter/?${params}&a_bogus=${aBogus}`;

  // Swift: var requestHeaders = headers; requestHeaders.add(name: "cookie", value: cookie); requestHeaders.add(name: "accept", value: "application/json, text/plain, */*")
  const hdrs = _dy_pickHeaders(finalCookie);
  hdrs["Accept"] = "application/json, text/plain, */*";

  console.log(`[douyin] _dy_getRoomDataByApi: roomId=${webRid}, aBogusLen=${aBogus.length}, cookieLen=${finalCookie.length}`);
  console.log(`[douyin] cookie: ${finalCookie.substring(0, 80)}`);
  console.log(`[douyin] URL (first 250): ${requestURL.substring(0, 250)}`);
  console.log(`[douyin] headers: ${JSON.stringify(hdrs).substring(0, 300)}`);

  const resp = await Host.http.request({
    url: requestURL,
    method: "GET",
    headers: hdrs,
    timeout: 20
  });

  const httpStatus = resp && resp.status;
  const respUrl = _dy_toString(resp && resp.url);
  const bodyText = _dy_toString(resp && resp.bodyText);
  console.log(`[douyin] API response: httpStatus=${httpStatus}, bodyLen=${bodyText.length}, respUrl=${respUrl.substring(0, 200)}, first200=${bodyText.substring(0, 200)}`);
  let obj;
  try {
    obj = JSON.parse(bodyText || "{}");
  } catch (e) {
    _dy_throw("PARSE", "douyin API json parse failed", { roomId: String(roomId || ""), httpStatus: String(httpStatus || ""), bodyLen: String(bodyText.length), first200: bodyText.substring(0, 200) });
  }

  const statusCode = obj && obj.status_code;
  console.log(`[douyin] API response: status_code=${statusCode}, data_keys=${_dy_objectKeys(obj && obj.data)}`);

  const dataArr = (((obj || {}).data || {}).data) || [];
  const roomData = Array.isArray(dataArr) && dataArr.length > 0 ? dataArr[0] : null;
  const userData = ((obj || {}).data || {}).user || null;

  if (!roomData || !roomData.id_str) {
    _dy_throw("INVALID_RESPONSE", "douyin API returned empty room data", { roomId: String(roomId || ""), status_code: String(statusCode || "") });
  }

  // Build the same structure as _dy_getRoomDataByHtml returns
  const room = roomData;
  const owner = userData ? {
    nickname: _dy_toString(userData.nickname || ""),
    id_str: _dy_toString(userData.id_str || ""),
    web_rid: _dy_toString(userData.web_rid || webRid),
    avatar_thumb: userData.avatar_thumb || {}
  } : (room.owner || {});

  room.owner = owner;

  return { room, roomInfo: { room, anchor: owner }, roomStore: {}, streamStore: {}, state: {} };
}

async function _dy_getDouyinRoomDetail(roomId, userId, cookie, maxRetries) {
  const retries = maxRetries || 3;
  let lastError = null;

  for (let i = 0; i < retries; i++) {
    try {
      return await _dy_getRoomDataByApi(roomId, userId, cookie);
    } catch (e) {
      lastError = e;
      console.log(`[douyin] API attempt ${i + 1}/${retries} failed: ${_dy_toString(e && e.message)}`);
    }
  }

  try {
    return await _dy_getRoomDataByHtml(roomId, cookie);
  } catch (e) {
    throw lastError || e;
  }
}

async function _dy_getRoomDataByHtml(roomId, cookie) {
  const webRid = _dy_toString(roomId).trim();
  if (!webRid) _dy_throw("INVALID_ARGS", "roomId is empty", { field: "roomId" });

  const enrichedCookie = _dy_enrichCookie(cookie);

  const resp = await Host.http.request({
    url: `https://live.douyin.com/${encodeURIComponent(webRid)}`,
    method: "GET",
    headers: _dy_pickHeaders(enrichedCookie),
    timeout: 20
  });

  const statusCode = resp && resp.status;
  const html = _dy_toString(resp && resp.bodyText);
  console.log(`[douyin] getRoomDataByHtml: httpStatus=${statusCode}, htmlLen=${html.length}, hasState=${html.includes('\\"state\\"')}, hasRenderData=${html.includes('RENDER_DATA')}, first200=${html.substring(0, 200)}`);

  if (!html) {
    _dy_throw("INVALID_RESPONSE", "empty room html", { roomId: String(roomId || "") });
  }

  let payloadObj = null;

  const escapedMatch = html.match(/(\{\\"state\\":\{[\s\S]*?\]\\n)/);
  if (escapedMatch && escapedMatch[1]) {
    const normalized = String(escapedMatch[1])
      .replace(/\\"/g, '"')
      .replace(/\\\\/g, "\\")
      .replace(/\]\\n/g, "]");
    try {
      const jsonText = _dy_extractFirstJSONObjectText(normalized);
      payloadObj = jsonText ? JSON.parse(jsonText) : null;
    } catch (e) {
      payloadObj = null;
    }
  }

  if (!payloadObj) {
    const renderDataMatch = html.match(/<script[^>]*id="RENDER_DATA"[^>]*>([\s\S]*?)<\/script>/i);
    if (renderDataMatch && renderDataMatch[1]) {
      const renderText = _dy_tryDecodeURIComponent(String(renderDataMatch[1]));
      try {
        payloadObj = JSON.parse(renderText);
      } catch (e) {
        payloadObj = null;
      }
    }
  }

  if (!payloadObj) {
    const initStateMatch = html.match(/window\.__INITIAL_STATE__\s*=\s*(\{[\s\S]*?\})\s*;\s*<\/script>/i);
    if (initStateMatch && initStateMatch[1]) {
      try {
        payloadObj = JSON.parse(initStateMatch[1]);
      } catch (e) {
        payloadObj = null;
      }
    }
  }

  if (!payloadObj) {
    payloadObj = _dy_parseEscapedStateFromScript(html);
  }

  if (!payloadObj) {
    const hasEscapedState = html.includes('\\"state\\"');
    const hasRenderData = html.includes('id="RENDER_DATA"');
    const hasInitialState = html.includes('__INITIAL_STATE__');
    const titleMatch = html.match(/<title[^>]*>([\s\S]*?)<\/title>/i);
    const pageTitle = titleMatch ? titleMatch[1].substring(0, 100) : "no-title";
    _dy_throw("PARSE", "cannot parse douyin state payload from html", { roomId: String(roomId || "") });
  }

  const state = payloadObj.state || payloadObj;
  const roomStore = (state && state.roomStore) || {};
  const streamStore = (state && state.streamStore) || {};
  const roomInfo = (roomStore && roomStore.roomInfo) || {};
  let room = (roomInfo && roomInfo.room) || {};

  if ((!room || !room.id_str) && roomInfo) {
    const statusRaw = _dy_toString(roomInfo.status || roomStore.liveStatus || "").toLowerCase();
    let status = 0;
    if (statusRaw === "normal" || statusRaw === "2") status = 2;
    else if (statusRaw === "end" || statusRaw === "close" || statusRaw === "4") status = 4;

    room = {
      id_str: _dy_toString(roomInfo.roomId || roomInfo.web_rid || roomId),
      status,
      title: _dy_toString(roomInfo.title || ""),
      owner: roomInfo.anchor || {},
      cover: roomInfo.cover || {},
      room_view_stats: roomInfo.room_view_stats || {},
      stream_url: roomInfo.web_stream_url || {}
    };
  }

  if (!room || !room.id_str) {
    _dy_throw("INVALID_RESPONSE", "room info missing from html payload", { roomId: String(roomId || "") });
  }

  return { room, roomInfo, roomStore, streamStore, state };
}

async function _dy_getRoomList(id, parentId, page, cookie) {
  // 使用匿名 cookie 避免 444
  const freshCookie = await _dy_getCookie("");
  const params = [
    "aid=6383",
    "app_name=douyin_web",
    "live_id=1",
    "device_platform=web",
    "language=zh-CN",
    "enter_from=link_share",
    "cookie_enabled=true",
    "screen_width=1980",
    "screen_height=1080",
    "browser_language=zh-CN",
    "browser_platform=Win32",
    "browser_name=Edge",
    "browser_version=140.0.0.0",
    "browser_online=true",
    "count=15",
    `offset=${encodeURIComponent(String((Number(page || 1) - 1) * 15))}`,
    `partition=${encodeURIComponent(String(id || ""))}`,
    `partition_type=${encodeURIComponent(String(parentId || ""))}`,
    "req_from=2"
  ].join("&");

  const aBogus = _dy_signDetail(params);
  const requestURL = `https://live.douyin.com/webcast/web/partition/detail/room/v2/?${params}&a_bogus=${encodeURIComponent(aBogus)}`;

  const resp = await Host.http.request({
    url: requestURL,
    method: "GET",
    headers: _dy_pickHeaders(freshCookie),
    timeout: 20
  });

  const obj = JSON.parse(_dy_toString(resp && resp.bodyText) || "{}");
  const list = (((obj || {}).data || {}).data) || [];
  if (!Array.isArray(list) || list.length === 0) {
    _dy_throw("BLOCKED", "douyin room list empty or blocked", { id: String(id || ""), parentId: String(parentId || ""), page: Number(page || 1) });
  }

  return list.map(function (item) {
    const room = item.room || {};
    const owner = room.owner || item.owner || {};
    const avatar = owner.avatar_thumb || {};
    const cover = room.cover || {};
    const webRid = _dy_toString(owner.web_rid || room.id_str || owner.id_str || "");
    return {
      userName: _dy_toString(owner.nickname || ""),
      roomTitle: _dy_toString(room.title || ""),
      roomCover: _dy_firstArrayValue(cover.url_list),
      userHeadImg: _dy_firstArrayValue(avatar.url_list),
      liveType: "2",
      liveState: _dy_statusToLiveState(Number(room.status || 0), true),
      userId: _dy_toString(room.id_str || owner.id_str || ""),
      roomId: webRid,
      liveWatchedCount: _dy_toString(room.user_count_str || "")
    };
  });
}

async function _dy_searchRooms(keyword, page, cookie) {
  const normalizedCookie = _dy_normalizeCookie(cookie);
  let searchCookie = normalizedCookie;
  const msTokenFromCookie = _dy_getCookieValue(searchCookie, "msToken");
  const msToken = msTokenFromCookie || _dy_generateMsToken();
  const generatedMsToken = msTokenFromCookie ? 0 : 1;
  if (!msTokenFromCookie) {
    searchCookie = _dy_appendCookieKV(searchCookie, "msToken", msToken);
  }
  const verifyFpFromCookie =
    _dy_getCookieValue(searchCookie, "s_v_web_id") ||
    _dy_getCookieValue(searchCookie, "verifyFp");
  const verifyFp = verifyFpFromCookie || _dy_generateVerifyFp();
  const generatedVerifyFp = verifyFpFromCookie ? 0 : 1;
  if (!verifyFpFromCookie) {
    searchCookie = _dy_appendCookieKV(searchCookie, "s_v_web_id", verifyFp);
  }
  _dy_setRuntimeCookie(searchCookie);
  const keywordText = String(keyword || "").trim();
  const encodedKeyword = encodeURIComponent(keywordText);
  const pageNo = Number(page || 1);
  if (pageNo <= 1 || _dy_runtime.searchKeyword !== keywordText) {
    _dy_runtime.searchId = "";
    _dy_runtime.searchKeyword = keywordText;
  }
  const queryParts = [
    "device_platform=webapp",
    "aid=6383",
    "channel=channel_pc_web",
    "update_version_code=170400",
    "pc_client_type=1",
    "version_code=190600",
    "version_name=19.6.0",
    "cookie_enabled=true",
    "screen_width=1980",
    "screen_height=1080",
    "browser_language=zh-CN",
    "browser_platform=Win32",
    "browser_name=Edge",
    "browser_version=140.0.0.0",
    "browser_online=true",
    "engine_name=Blink",
    "engine_version=140.0.0.0",
    "os_name=Windows",
    "os_version=10",
    "cpu_core_num=12",
    "device_memory=8",
    "platform=PC",
    "downlink=4.7",
    "effective_type=4g",
    "round_trip_time=100",
    "webid=7247041636524377637",
    "search_channel=aweme_live",
    "enable_history=1",
    `keyword=${encodedKeyword}`,
    "search_source=tab_search",
    "query_correct_type=1",
    "is_filter_search=0",
    "from_group_id=",
    `offset=${encodeURIComponent(String((pageNo - 1) * 15))}`,
    "count=15",
    "need_filter_settings=1",
    "list_type=multi",
    `search_id=${encodeURIComponent(_dy_runtime.searchId || "")}`,
    `verifyFp=${encodeURIComponent(verifyFp)}`,
    `fp=${encodeURIComponent(verifyFp)}`,
    `msToken=${encodeURIComponent(msToken)}`
  ];

  const qs = queryParts.join("&");
  const requestURL = `https://www.douyin.com/aweme/v1/web/general/search/single/?${qs}`;
  const searchHeaders = Object.assign({}, _dy_pickHeaders(searchCookie), {
    "Accept": "application/json, text/plain, */*",
    "Authority": "www.douyin.com",
    "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
    "Referer": `https://www.douyin.com/search/${encodedKeyword}?type=general&source=tab_search`
  });

  const resp = await Host.http.request({
    url: requestURL,
    method: "GET",
    headers: searchHeaders,
    timeout: 20
  });

  const bodyText = _dy_toString(resp && resp.bodyText);

  let obj = {};
  try {
    obj = JSON.parse(bodyText || "{}");
  } catch (e) {
    _dy_throw("PARSE", "douyin search json parse failed", {
      http: _dy_toString(resp && resp.status),
      cookie_len: String(normalizedCookie.length),
      url: requestURL
    });
  }

  const list = (obj && obj.data) || [];
  const searchNilType = _dy_toString((((obj || {}).search_nil_info || {}).search_nil_type));
  const logId = _dy_toString((((obj || {}).extra || {}).logid));
  if (logId) {
    _dy_runtime.searchId = logId;
  }
  if (!Array.isArray(list)) {
    _dy_throw("INVALID_RESPONSE", "douyin search response invalid", {
      http: _dy_toString(resp && resp.status),
      status_code: _dy_toString(obj && obj.status_code),
      search_nil_type: searchNilType,
      logid: logId,
      cookie_len: String(normalizedCookie.length),
      generated_msToken: String(generatedMsToken),
      generated_verifyFp: String(generatedVerifyFp),
      url: requestURL
    });
  }

  const out = [];
  const seenRoomIds = new Set();
  let rawParsedCount = 0;
  let userListModelCount = 0;
  let userListUserCount = 0;
  let firstItemType = "";
  let firstItemKeys = "";
  let firstUserKeys = "";
  let firstUserInfoKeys = "";
  let firstRoomDataKeys = "";
  let firstUserRoomId = "";
  let firstUserInfoRoomId = "";
  let firstUserInfoRoomIdStr = "";
  let firstUserInfoUID = "";
  const pushModel = (model) => {
    const roomId = _dy_toString(model && model.roomId);
    if (!roomId || seenRoomIds.has(roomId)) return;
    seenRoomIds.add(roomId);
    out.push(model);
  };
  for (const item of list) {
    if (!firstItemType) {
      firstItemType = _dy_toString((item || {}).type);
      firstItemKeys = _dy_objectKeys(item);
    }
    const users = Array.isArray((item || {}).user_list) ? item.user_list : [];
    if (users.length > 0) {
      userListUserCount += users.length;
      if (!firstUserKeys) {
        const firstUser = users[0] || {};
        firstUserKeys = _dy_objectKeys(firstUser);
        firstUserInfoKeys = _dy_objectKeys(firstUser.user_info || {});
        firstUserRoomId = _dy_toString(firstUser.room_id);
        firstUserInfoRoomId = _dy_toString((firstUser.user_info || {}).room_id);
        firstUserInfoRoomIdStr = _dy_toString((firstUser.user_info || {}).room_id_str);
        firstUserInfoUID = _dy_toString((firstUser.user_info || {}).uid);
        firstRoomDataKeys = _dy_objectKeys(
          firstUser.room_data ||
          ((firstUser.user_info || {}).room_data) ||
          firstUser.live_info ||
          ((firstUser.user_info || {}).live_info) ||
          firstUser.webcast_info ||
          ((firstUser.user_info || {}).webcast_info) ||
          firstUser.room_info ||
          ((firstUser.user_info || {}).room_info) ||
          {}
        );
      }
    }
    const rawText = _dy_toString(
      (((item || {}).lives || {}).rawdata) ||
      (((item || {}).live || {}).rawdata) ||
      ((item || {}).rawdata) ||
      ""
    );
    if (rawText) {
      try {
        const raw = JSON.parse(rawText);
        const room = raw.room || {};
        const owner = raw.owner || room.owner || {};
        const cover = raw.cover || room.cover || {};
        const avatar = owner.avatar_thumb || {};
        const status = Number(raw.status || room.status || 0);
        const hasStream = !!((((raw.stream_url || room.stream_url || {}).live_core_sdk_data || {}).pull_data || {}).stream_data);
        pushModel({
          userName: _dy_toString(owner.nickname || ""),
          roomTitle: _dy_toString(raw.title || room.title || ""),
          roomCover: _dy_firstArrayValue(cover.url_list),
          userHeadImg: _dy_firstArrayValue(avatar.url_list),
          liveType: "2",
          liveState: _dy_statusToLiveState(status, hasStream),
          userId: _dy_toString(raw.id_str || room.id_str || owner.id_str || ""),
          roomId: _dy_toString(owner.web_rid || raw.web_rid || room.web_rid || room.id_str || ""),
          liveWatchedCount: _dy_toString(raw.user_count || raw.user_count_str || room.user_count_str || "")
        });
        rawParsedCount += 1;
      } catch (e) {
      }
    }

    const fallbackModels = _dy_extractLiveModelsFromUserList(item);
    for (const model of fallbackModels) {
      pushModel(model);
      userListModelCount += 1;
    }
  }

  if (out.length === 0) {
    _dy_throw("BLOCKED", "douyin search parse empty", {
      http: _dy_toString(resp && resp.status),
      status_code: _dy_toString(obj && obj.status_code),
      search_nil_type: searchNilType,
      logid: logId,
      cookie_len: String(normalizedCookie.length),
      has_msToken: msTokenFromCookie ? "1" : "0",
      has_verifyFp: verifyFpFromCookie ? "1" : "0",
      generated_msToken: String(generatedMsToken),
      generated_verifyFp: String(generatedVerifyFp),
      list_count: String(list.length),
      raw_parsed: String(rawParsedCount),
      user_list_users: String(userListUserCount),
      user_list_models: String(userListModelCount),
      first_item_type: firstItemType,
      first_item_keys: firstItemKeys,
      first_user_keys: firstUserKeys,
      first_user_info_keys: firstUserInfoKeys,
      first_user_room_id: firstUserRoomId,
      first_user_info_room_id: firstUserInfoRoomId,
      first_user_info_room_id_str: firstUserInfoRoomIdStr,
      first_user_info_uid: firstUserInfoUID,
      first_room_data_keys: firstRoomDataKeys,
      url: requestURL
    });
  }

  return out;
}

async function _dy_resolveRoomIdFromShareCode(shareCode, cookie) {
  const text = _dy_toString(shareCode).trim();
  if (!text) _dy_throw("INVALID_ARGS", "shareCode is empty", { field: "shareCode" });
  if (_dy_isNumericId(text)) return text;

  let roomId = _dy_firstMatch(text, /live\.douyin\.com\/(\d+)/);
  if (_dy_isNumericId(roomId)) return roomId;

  roomId = _dy_firstMatch(text, /douyin\/webcast\/reflow\/(\d+)/);
  if (_dy_isNumericId(roomId)) return roomId;

  const shortURL = _dy_firstURL(text) || (text.startsWith("http") ? text : "");
  if (shortURL) {
    const resp = await Host.http.request({
      url: shortURL,
      method: "GET",
      headers: _dy_pickHeaders(cookie),
      timeout: 20
    });

    const finalURL = _dy_toString((resp && resp.url) || shortURL);
    roomId = _dy_firstMatch(finalURL, /live\.douyin\.com\/(\d+)/);
    if (_dy_isNumericId(roomId)) return roomId;

    roomId = _dy_firstMatch(finalURL, /douyin\/webcast\/reflow\/(\d+)/);
    if (_dy_isNumericId(roomId)) return roomId;

    const html = _dy_toString(resp && resp.bodyText);
    roomId = _dy_firstMatch(html, /live\.douyin\.com\/(\d+)/);
    if (_dy_isNumericId(roomId)) return roomId;
  }

  _dy_throw("NOT_FOUND", `cannot resolve douyin roomId from shareCode: ${shareCode}`, { shareCode: String(shareCode || "") });
}

globalThis.LiveParsePlugin = {
  apiVersion: 1,

  async setCookie(payload) {
    const cookie = _dy_normalizeCookie(payload && payload.cookie);
    _dy_setRuntimeCookie(cookie);
    if (!cookie) {
      _dy_runtime.searchId = "";
      _dy_runtime.searchKeyword = "";
    }
    return { ok: true, hasCookie: cookie.length > 0 };
  },

  async clearCookie() {
    _dy_setRuntimeCookie("");
    _dy_runtime.searchId = "";
    _dy_runtime.searchKeyword = "";
    return { ok: true, hasCookie: false };
  },

  async getCategories() {
    return _dy_defaultCategories();
  },

  async getRooms(payload) {
    const runtimePayload = _dy_requireCookie(payload, "getRooms");
    const id = _dy_toString(runtimePayload.id);
    const parentId = _dy_toString(runtimePayload.parentId);
    const page = Number(runtimePayload.page || 1);
    if (!id) _dy_throw("INVALID_ARGS", "id is required", { field: "id" });
    return await _dy_getRoomList(id, parentId, page, runtimePayload.cookie);
  },

  async getPlayback(payload) {
    const runtimePayload = _dy_requireCookie(payload, "getPlayback");
    const roomId = _dy_toString(runtimePayload.roomId);
    const userId = _dy_toString(runtimePayload.userId);
    if (!roomId) _dy_throw("INVALID_ARGS", "roomId is required", { field: "roomId" });
    const data = await _dy_getDouyinRoomDetail(roomId, userId, runtimePayload.cookie, 3);
    return _dy_extractPlayArgs(data, roomId);
  },

  async search(payload) {
    const runtimePayload = _dy_requireCookie(payload, "search");
    const keyword = _dy_toString(runtimePayload.keyword);
    const page = Number(runtimePayload.page || 1);
    if (!keyword) _dy_throw("INVALID_ARGS", "keyword is required", { field: "keyword" });
    return await _dy_searchRooms(keyword, page, runtimePayload.cookie);
  },

  async getRoomDetail(payload) {
    const runtimePayload = _dy_requireCookie(payload, "getRoomDetail");
    const roomId = _dy_toString(runtimePayload.roomId);
    const userId = _dy_toString(runtimePayload.userId);
    if (!roomId) _dy_throw("INVALID_ARGS", "roomId is required", { field: "roomId" });
    const data = await _dy_getDouyinRoomDetail(roomId, userId, runtimePayload.cookie, 3);
    return _dy_buildLiveModel(data, roomId);
  },

  async getLiveState(payload) {
    const runtimePayload = _dy_requireCookie(payload, "getLiveState");
    const latest = await this.getRoomDetail(runtimePayload);
    return { liveState: _dy_toString((latest && latest.liveState) || "3") };
  },

  async resolveShare(payload) {
    const runtimePayload = _dy_requireCookie(payload, "resolveShare");
    const shareCode = _dy_toString(runtimePayload.shareCode);
    if (!shareCode) _dy_throw("INVALID_ARGS", "shareCode is required", { field: "shareCode" });
    const roomId = await _dy_resolveRoomIdFromShareCode(shareCode, runtimePayload.cookie);
    return await this.getRoomDetail({ roomId, userId: roomId, cookie: runtimePayload.cookie });
  },

  async getDanmaku(payload) {
    const runtimePayload = _dy_requireCookie(payload, "getDanmaku");
    const roomId = _dy_toString(runtimePayload.roomId);
    if (!roomId) _dy_throw("INVALID_ARGS", "roomId is required", { field: "roomId" });

    const live = await this.getRoomDetail(runtimePayload);
    const finalRoomId = _dy_toString((live && live.userId) || roomId);
    const cookie = _dy_toString(runtimePayload.cookie);

    // 生成 user_unique_id（随机 19 位数字，73xx-79xx 开头）
    const lo = 7300000000000000000;
    const hi = 7999999999999999999;
    const userUniqueId = String(Math.floor(Math.random() * (hi - lo + 1)) + lo);

    // 构建签名参数串（顺序与 Swift 侧一致）
    const sigParams = "live_id=1,aid=6383,version_code=180800,webcast_sdk_version=1.0.14-beta.0,"
      + "room_id=" + finalRoomId + ",sub_room_id=,sub_channel_id=,did_rule=3,"
      + "user_unique_id=" + userUniqueId + ",device_platform=web,device_type=,ac=,identity=audience";
    const xmsStub = Host.crypto.md5(sigParams);

    // 调用 webmssdk 的 get_sign 获取 X-Bogus 签名
    let signature = "";
    if (typeof get_sign === "function") {
      signature = _dy_toString(get_sign(xmsStub)) || "";
    }

    return {
      args: {
        room_id: finalRoomId,
        compress: "gzip",
        version_code: "180800",
        webcast_sdk_version: "1.0.14-beta.0",
        live_id: "1",
        did_rule: "3",
        user_unique_id: userUniqueId,
        identity: "audience",
        signature: signature,
        aid: "6383",
        device_platform: "web",
        browser_language: "zh-CN",
        browser_platform: "Win32",
        browser_name: "Mozilla",
        browser_version: _dy_ua
      },
      headers: cookie ? { cookie, "User-Agent": _dy_ua } : null
    };
  }
};


// ---- a_bogus implementation aligned with Swift ABogus (pageId=0, bigArray transform) ----
function rc4_encrypt(plaintext, key) {
    var s = [];
    for (var i = 0; i < 256; i++) {
        s[i] = i;
    }
    var j = 0;
    for (var i = 0; i < 256; i++) {
        j = (j + s[i] + key.charCodeAt(i % key.length)) % 256;
        var temp = s[i];
        s[i] = s[j];
        s[j] = temp;
    }

    var i = 0;
    var j = 0;
    var cipher = [];
    for (var k = 0; k < plaintext.length; k++) {
        i = (i + 1) % 256;
        j = (j + s[i]) % 256;
        var temp = s[i];
        s[i] = s[j];
        s[j] = temp;
        var t = (s[i] + s[j]) % 256;
        cipher.push(String.fromCharCode(s[t] ^ plaintext.charCodeAt(k)));
    }
    return cipher.join('');
}

// SM3 implementation (vendored from sm-crypto, MIT license)
const _dy_sm3_W = new Uint32Array(68);
const _dy_sm3_M = new Uint32Array(64);
const _dy_sm3_blockLen = 64;
const _dy_sm3_iPad = new Uint8Array(_dy_sm3_blockLen);
const _dy_sm3_oPad = new Uint8Array(_dy_sm3_blockLen);
for (let _lp_i = 0; _lp_i < _dy_sm3_blockLen; _lp_i++) {
    _dy_sm3_iPad[_lp_i] = 0x36;
    _dy_sm3_oPad[_lp_i] = 0x5C;
}

function _dy_sm3_rotl(x, n) {
    const s = n & 31;
    return (x << s) | (x >>> (32 - s));
}

function _dy_sm3_xor(x, y) {
    const result = [];
    for (let i = x.length - 1; i >= 0; i--) result[i] = (x[i] ^ y[i]) & 0xFF;
    return result;
}

function _dy_sm3_P0(X) { return (_dy_sm3_rotl(X, 9) ^ _dy_sm3_rotl(X, 17) ^ X); }
function _dy_sm3_P1(X) { return (_dy_sm3_rotl(X, 15) ^ _dy_sm3_rotl(X, 23) ^ X); }

function _dy_sm3_core(array) {
    let len = array.length * 8;
    let k = len % 512;
    k = k >= 448 ? 512 - (k % 448) - 1 : 448 - k - 1;
    const kArr = new Array((k - 7) / 8);
    const lenArr = new Array(8);
    for (let i = 0; i < kArr.length; i++) kArr[i] = 0;
    for (let i = 0; i < lenArr.length; i++) lenArr[i] = 0;
    len = len.toString(2);
    for (let i = 7; i >= 0; i--) {
        if (len.length > 8) {
            const start = len.length - 8;
            lenArr[i] = parseInt(len.substr(start), 2);
            len = len.substr(0, start);
        } else if (len.length > 0) {
            lenArr[i] = parseInt(len, 2);
            len = "";
        }
    }
    const m = new Uint8Array([...array, 0x80, ...kArr, ...lenArr]);
    const dataView = new DataView(m.buffer, 0);
    const n = m.length / 64;
    const V = new Uint32Array([0x7380166F, 0x4914B2B9, 0x172442D7, 0xDA8A0600, 0xA96F30BC, 0x163138AA, 0xE38DEE4D, 0xB0FB0E4E]);
    for (let i = 0; i < n; i++) {
        _dy_sm3_W.fill(0); _dy_sm3_M.fill(0);
        const start = 16 * i;
        for (let j = 0; j < 16; j++) _dy_sm3_W[j] = dataView.getUint32((start + j) * 4, false);
        for (let j = 16; j < 68; j++) _dy_sm3_W[j] = (_dy_sm3_P1((_dy_sm3_W[j - 16] ^ _dy_sm3_W[j - 9]) ^ _dy_sm3_rotl(_dy_sm3_W[j - 3], 15)) ^ _dy_sm3_rotl(_dy_sm3_W[j - 13], 7) ^ _dy_sm3_W[j - 6]);
        for (let j = 0; j < 64; j++) _dy_sm3_M[j] = _dy_sm3_W[j] ^ _dy_sm3_W[j + 4];
        const T1 = 0x79CC4519, T2 = 0x7A879D8A;
        let A = V[0], B = V[1], C = V[2], D = V[3], E = V[4], F = V[5], G = V[6], H = V[7];
        for (let j = 0; j < 64; j++) {
            const T = j <= 15 ? T1 : T2;
            const SS1 = _dy_sm3_rotl(_dy_sm3_rotl(A, 12) + E + _dy_sm3_rotl(T, j), 7);
            const SS2 = SS1 ^ _dy_sm3_rotl(A, 12);
            const TT1 = (j <= 15 ? ((A ^ B) ^ C) : (((A & B) | (A & C)) | (B & C))) + D + SS2 + _dy_sm3_M[j];
            const TT2 = (j <= 15 ? ((E ^ F) ^ G) : ((E & F) | ((~E) & G))) + H + SS1 + _dy_sm3_W[j];
            D = C; C = _dy_sm3_rotl(B, 9); B = A; A = TT1;
            H = G; G = _dy_sm3_rotl(F, 19); F = E; E = _dy_sm3_P0(TT2);
        }
        V[0] ^= A; V[1] ^= B; V[2] ^= C; V[3] ^= D; V[4] ^= E; V[5] ^= F; V[6] ^= G; V[7] ^= H;
    }
    const result = [];
    for (let i = 0; i < V.length; i++) {
        const word = V[i];
        result.push((word & 0xFF000000) >>> 24, (word & 0xFF0000) >>> 16, (word & 0xFF00) >>> 8, word & 0xFF);
    }
    return result;
}

function _dy_sm3_hmac(input, key) {
    if (key.length > _dy_sm3_blockLen) key = _dy_sm3_core(key);
    while (key.length < _dy_sm3_blockLen) key.push(0);
    return _dy_sm3_core([..._dy_sm3_xor(key, _dy_sm3_oPad), ..._dy_sm3_core([..._dy_sm3_xor(key, _dy_sm3_iPad), ...input])]);
}

function _dy_sm3_arrayToHex(arr) { return arr.map(function(item) { const h = item.toString(16); return h.length === 1 ? "0" + h : h; }).join(""); }
function _dy_sm3_hexToArray(hexStr) {
    const words = []; let text = _dy_toString(hexStr);
    if (text.length % 2 !== 0) text = "0" + text;
    for (let i = 0; i < text.length; i += 2) words.push(parseInt(text.substr(i, 2), 16));
    return words;
}
function _dy_sm3_utf8ToArray(str) {
    const arr = [];
    for (let i = 0; i < str.length; i++) {
        const point = str.codePointAt(i);
        if (point <= 0x007F) { arr.push(point); }
        else if (point <= 0x07FF) { arr.push(0xC0 | (point >>> 6)); arr.push(0x80 | (point & 0x3F)); }
        else if (point <= 0xD7FF || (point >= 0xE000 && point <= 0xFFFF)) { arr.push(0xE0 | (point >>> 12)); arr.push(0x80 | ((point >>> 6) & 0x3F)); arr.push(0x80 | (point & 0x3F)); }
        else if (point >= 0x010000 && point <= 0x10FFFF) { i += 1; arr.push(0xF0 | ((point >>> 18) & 0x1C)); arr.push(0x80 | ((point >>> 12) & 0x3F)); arr.push(0x80 | ((point >>> 6) & 0x3F)); arr.push(0x80 | (point & 0x3F)); }
        else { arr.push(point); }
    }
    return arr;
}

function sm3(input, options) {
    const normalizedInput = typeof input === "string" ? _dy_sm3_utf8ToArray(input) : Array.prototype.slice.call(input);
    if (options) {
        let key = options.key;
        if (!key) throw new Error("invalid key");
        key = typeof key === "string" ? _dy_sm3_hexToArray(key) : Array.prototype.slice.call(key);
        return _dy_sm3_arrayToHex(_dy_sm3_hmac(normalizedInput, key));
    }
    return _dy_sm3_arrayToHex(_dy_sm3_core(normalizedInput));
}

// ---- Swift-aligned ABogus (pageId=0, bigArray, Edge fingerprint) ----
const _ab_character = "Dkdpgh2ZmsQB80/MfvV36XI1R45-WUAlEixNLwoqYTOPuzKFjJnry79HbGcaStCe";
const _ab_character2 = "ckdp1h4ZKsUB80/Mfvw36XIgR25+WQAlEi7NLboqYTOPuzmFjJnryx9HVGDaStCe";
const _ab_salt = "cus";
const _ab_pageId = 0;
const _ab_aid = 6383;
const _ab_uaKey = [0x00, 0x01, 0x0E];
const _ab_options = [0, 1, 14];
const _ab_sortIndex = [18,20,52,26,30,34,58,38,40,53,42,21,27,54,55,31,35,57,39,41,43,22,28,32,60,36,23,29,33,37,44,45,59,46,47,48,49,50,24,25,65,66,70,71];
const _ab_sortIndex2 = [18,20,26,30,34,38,40,42,21,27,31,35,39,41,43,22,28,32,36,23,29,33,37,44,45,46,47,48,49,50,24,25,52,53,54,55,57,58,59,60,65,66,70,71];

function _ab_createBigArray() {
    return [121,243,55,234,103,36,47,228,30,231,106,6,115,95,78,101,250,207,198,50,139,227,220,105,97,143,34,28,194,215,18,100,159,160,43,8,169,217,180,120,247,45,90,11,27,197,46,3,84,72,5,68,62,56,221,75,144,79,73,161,178,81,64,187,134,117,186,118,16,241,130,71,89,147,122,129,65,40,88,150,110,219,199,255,181,254,48,4,195,248,208,32,116,167,69,201,17,124,125,104,96,83,80,127,236,108,154,126,204,15,20,135,112,158,13,1,188,164,210,237,222,98,212,77,253,42,170,202,26,22,29,182,251,10,173,152,58,138,54,141,185,33,157,31,252,132,233,235,102,196,191,223,240,148,39,123,92,82,128,109,57,24,38,113,209,245,2,119,153,229,189,214,230,174,232,63,52,205,86,140,66,175,111,171,246,133,238,193,99,60,74,91,225,51,76,37,145,211,166,151,213,206,0,200,244,176,218,44,184,172,49,216,93,168,53,21,183,41,67,85,224,155,226,242,87,177,146,70,190,12,162,19,137,114,25,165,163,192,23,59,9,94,179,107,35,7,142,131,239,203,149,136,61,249,14,156];
}

function _ab_sm3ToArray(input) {
    return _dy_sm3_hexToArray(sm3(input));
}

function _ab_paramsToArray(param, addSalt) {
    if (addSalt === undefined) addSalt = true;
    if (typeof param === "string" && addSalt) return _ab_sm3ToArray(param + _ab_salt);
    return _ab_sm3ToArray(param);
}

function _ab_base64Encode(inputString, selectedAlphabet) {
    const alphabet = selectedAlphabet === 1 ? _ab_character2 : _ab_character;
    const charValues = [];
    for (let i = 0; i < inputString.length; i++) charValues.push(inputString.charCodeAt(i) & 0xFF);
    let binaryString = charValues.map(function(v) { let s = v.toString(2); while (s.length < 8) s = "0" + s; return s; }).join("");
    const paddingLength = (6 - binaryString.length % 6) % 6;
    binaryString += "0".repeat(paddingLength);
    let result = "";
    for (let i = 0; i < binaryString.length; i += 6) result += alphabet[parseInt(binaryString.substring(i, i + 6), 2)];
    return result + "=".repeat(Math.floor(paddingLength / 2));
}

function _ab_transformBytes(bigArray, bytesList) {
    let resultValues = [];
    let indexB = bigArray[1];
    let initialValue = 0;
    let valueE = 0;
    for (let index = 0; index < bytesList.length; index++) {
        let sumInitial;
        if (index === 0) {
            initialValue = bigArray[indexB];
            sumInitial = indexB + initialValue;
            bigArray[1] = initialValue;
            bigArray[indexB] = indexB;
        } else {
            sumInitial = initialValue + valueE;
        }
        const charValue = bytesList[index] & 0xFF;
        sumInitial = ((sumInitial % bigArray.length) + bigArray.length) % bigArray.length;
        const valueF = bigArray[sumInitial];
        resultValues.push(charValue ^ valueF);
        valueE = bigArray[(index + 2) % bigArray.length];
        sumInitial = ((indexB + valueE) % bigArray.length + bigArray.length) % bigArray.length;
        initialValue = bigArray[sumInitial];
        bigArray[sumInitial] = bigArray[(index + 2) % bigArray.length];
        bigArray[(index + 2) % bigArray.length] = initialValue;
        indexB = sumInitial;
    }
    return resultValues;
}

function _ab_abogusEncode(randomValues, transformValues) {
    const alphabet = _ab_character;
    const charValues = randomValues.concat(transformValues);
    let abogus = [];
    for (let i = 0; i < charValues.length; i += 3) {
        let n;
        if (i + 2 < charValues.length) n = ((charValues[i] & 0xFF) << 16) | ((charValues[i+1] & 0xFF) << 8) | (charValues[i+2] & 0xFF);
        else if (i + 1 < charValues.length) n = ((charValues[i] & 0xFF) << 16) | ((charValues[i+1] & 0xFF) << 8);
        else n = (charValues[i] & 0xFF) << 16;
        const shifts = [18, 12, 6, 0], masks = [0xFC0000, 0x03F000, 0x0FC0, 0x3F];
        for (let j = 0; j < 4; j++) {
            if (shifts[j] === 6 && i + 1 >= charValues.length) break;
            if (shifts[j] === 0 && i + 2 >= charValues.length) break;
            abogus.push(alphabet[(n & masks[j]) >> shifts[j]]);
        }
    }
    return abogus.join("") + "=".repeat((4 - abogus.length % 4) % 4);
}

function _ab_generateRandomBytes() {
    let result = [];
    for (let i = 0; i < 3; i++) {
        const rd = Math.floor(Math.random() * 10000);
        result.push(((rd & 255) & 170) | 1);
        result.push(((rd & 255) & 85) | 2);
        result.push((((rd & 0xFFFFFFFF) >>> 8) & 170) | 5);
        result.push((((rd & 0xFFFFFFFF) >>> 8) & 85) | 40);
    }
    return result;
}

function _ab_generateEdgeFingerprint() {
    function r(min, max) { return Math.floor(Math.random() * (max - min + 1)) + min; }
    const iw = r(1024, 1920), ih = r(768, 1080);
    const ow = iw + r(24, 32), oh = ih + r(75, 90);
    const sy = [0, 30][Math.floor(Math.random() * 2)];
    const sw = r(1024, 1920), sh = r(768, 1080), aw = r(1280, 1920), ah = r(800, 1080);
    return iw+"|"+ih+"|"+ow+"|"+oh+"|0|"+sy+"|0|0|"+sw+"|"+sh+"|"+aw+"|"+ah+"|"+iw+"|"+ih+"|24|24|Win32";
}

function _ab_generateAbogus(params) {
    const userAgent = _dy_ua;
    const browserFp = _ab_generateEdgeFingerprint();
    const bigArray = _ab_createBigArray();

    let abDir = {};
    abDir[8] = 3;
    abDir[18] = 44;
    abDir[66] = 0; abDir[69] = 0; abDir[70] = 0; abDir[71] = 0;

    const startEncryption = Date.now();
    const array0 = _ab_paramsToArray(params, true);
    const array1 = _ab_sm3ToArray(array0);
    const bodyArray0 = _ab_paramsToArray("", true);
    const array2 = _ab_sm3ToArray(bodyArray0);
    const uaKeyStr = String.fromCharCode.apply(null, _ab_uaKey);
    const encryptedUA = rc4_encrypt(userAgent, uaKeyStr);
    const base64EncodedUA = _ab_base64Encode(encryptedUA, 1);
    const array3 = _dy_sm3_hexToArray(sm3(base64EncodedUA));
    const endEncryption = Date.now();

    abDir[20] = (startEncryption >> 24) & 255;
    abDir[21] = (startEncryption >> 16) & 255;
    abDir[22] = (startEncryption >> 8) & 255;
    abDir[23] = startEncryption & 255;
    abDir[24] = Math.floor(startEncryption / 256 / 256 / 256 / 256);
    abDir[25] = Math.floor(startEncryption / 256 / 256 / 256 / 256 / 256);
    abDir[26] = 0; abDir[27] = 0; abDir[28] = 0; abDir[29] = 0;
    abDir[30] = 0; abDir[31] = 1; abDir[32] = 0; abDir[33] = 0;
    abDir[34] = 0; abDir[35] = 0; abDir[36] = 0; abDir[37] = 14;
    abDir[38] = array1[21]; abDir[39] = array1[22];
    abDir[40] = array2[21]; abDir[41] = array2[22];
    abDir[42] = array3[23]; abDir[43] = array3[24];
    abDir[44] = (endEncryption >> 24) & 255;
    abDir[45] = (endEncryption >> 16) & 255;
    abDir[46] = (endEncryption >> 8) & 255;
    abDir[47] = endEncryption & 255;
    abDir[48] = 3;
    abDir[49] = Math.floor(endEncryption / 256 / 256 / 256 / 256);
    abDir[50] = Math.floor(endEncryption / 256 / 256 / 256 / 256 / 256);
    abDir[51] = 0; abDir[52] = 0; abDir[53] = 0; abDir[54] = 0; abDir[55] = 0;
    abDir[56] = 6383; abDir[57] = 6383 & 255; abDir[58] = (6383 >> 8) & 255; abDir[59] = 0; abDir[60] = 0;
    abDir[64] = browserFp.length;
    abDir[65] = browserFp.length;

    const fpBytes = [];
    for (let i = 0; i < browserFp.length; i++) fpBytes.push(browserFp.charCodeAt(i) & 0xFF);

    let abXor = (browserFp.length & 255) >> 8 & 255;
    for (let idx = 0; idx < _ab_sortIndex2.length - 1; idx++) {
        if (idx === 0) abXor = abDir[_ab_sortIndex2[idx]] || 0;
        abXor ^= (abDir[_ab_sortIndex2[idx + 1]] || 0);
    }

    const sortedValues = _ab_sortIndex.map(function(i) { return abDir[i] || 0; });
    const finalSortedValues = sortedValues.concat(fpBytes).concat([abXor]);
    const transformValues = _ab_transformBytes(bigArray, finalSortedValues);
    const randomValues = _ab_generateRandomBytes();
    return _ab_abogusEncode(randomValues, transformValues);
}

function sign_datail(params, userAgent) {
    return _ab_generateAbogus(params);
}

function sign_reply(params, userAgent) {
    return _ab_generateAbogus(params);
}
