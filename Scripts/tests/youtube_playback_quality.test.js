#!/usr/bin/env node

const test = require("node:test");
const assert = require("node:assert/strict");

const {
  _yt_parseM3U8VariantsFromText,
  _yt_compareVariantForPreferQn,
  _yt_compareManifestProbeResult,
  _yt_manifestCandidateScore,
  _yt_buildPlayback,
} = require("../../Resources/lp_plugin_youtube_1.0.5_index.js");

test("YouTube plugin parses 1080p60 labels and sorts qualities from highest to lowest", () => {
  const manifest = `#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=2800000,RESOLUTION=1280x720,FRAME-RATE=30.000,CODECS="mp4a.40.2,avc1.4d401f"
720p.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=5100000,RESOLUTION=1920x1080,FRAME-RATE=60.000,CODECS="mp4a.40.2,avc1.640028"
1080p60.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=4200000,RESOLUTION=1920x1080,FRAME-RATE=30.000,CODECS="mp4a.40.2,avc1.640028"
1080p.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=1900000,RESOLUTION=854x480,FRAME-RATE=30.000,CODECS="mp4a.40.2,avc1.4d401f"
https://cdn.example.com/live/itag/94/480p.m3u8
`;

  const variants = _yt_parseM3U8VariantsFromText(
    manifest,
    "https://example.com/master/index.m3u8"
  );

  assert.deepEqual(
    variants.map(function (item) {
      return item.title;
    }),
    ["1080p60", "1080p", "720p", "480p"]
  );
  assert.equal(variants[0].qn, 1080);
  assert.equal(variants[0].fps, 60);
  assert.equal(variants[0].itag, 0);
  assert.equal(
    variants[0].url,
    "https://example.com/master/1080p60.m3u8"
  );
  assert.equal(variants[3].itag, 94);
});

test("YouTube plugin qn preference keeps higher fps first within the same resolution", () => {
  const variants = [
    {
      qn: 1080,
      fps: 30,
      bandwidth: 4200000,
      itag: 96,
      title: "1080p",
      url: "https://example.com/1080p.m3u8"
    },
    {
      qn: 1080,
      fps: 60,
      bandwidth: 5100000,
      itag: 301,
      title: "1080p60",
      url: "https://example.com/1080p60.m3u8"
    },
    {
      qn: 720,
      fps: 60,
      bandwidth: 3200000,
      itag: 95,
      title: "720p60",
      url: "https://example.com/720p60.m3u8"
    }
  ];

  variants.sort(function (a, b) {
    return _yt_compareVariantForPreferQn(a, b, 1080);
  });

  assert.equal(variants[0].title, "1080p60");
  assert.equal(variants[1].title, "1080p");
  assert.equal(variants[2].title, "720p60");
});

test("YouTube plugin prefers the manifest candidate with the strongest real variant ladder", () => {
  const probeResults = [
    {
      candidate: {
        source: "youtubei_ios",
        url: "https://example.com/ios/master.m3u8"
      },
      variants: [
        {
          qn: 720,
          fps: 60,
          bandwidth: 3200000,
          itag: 95,
          title: "720p60",
          url: "https://example.com/ios/720p60.m3u8"
        }
      ],
      preferredVariant: {
        qn: 720,
        fps: 60,
        bandwidth: 3200000,
        itag: 95,
        title: "720p60",
        url: "https://example.com/ios/720p60.m3u8"
      }
    },
    {
      candidate: {
        source: "youtubei_web",
        url: "https://example.com/web/master.m3u8"
      },
      variants: [
        {
          qn: 1080,
          fps: 60,
          bandwidth: 5100000,
          itag: 301,
          title: "1080p60",
          url: "https://example.com/web/1080p60.m3u8"
        },
        {
          qn: 720,
          fps: 60,
          bandwidth: 3200000,
          itag: 95,
          title: "720p60",
          url: "https://example.com/web/720p60.m3u8"
        }
      ],
      preferredVariant: {
        qn: 1080,
        fps: 60,
        bandwidth: 5100000,
        itag: 301,
        title: "1080p60",
        url: "https://example.com/web/1080p60.m3u8"
      }
    }
  ];

  probeResults.sort(function (a, b) {
    return _yt_compareManifestProbeResult(a, b, 0, "video1234567");
  });

  assert.equal(probeResults[0].candidate.source, "youtubei_web");
  assert.equal(probeResults[0].preferredVariant.title, "1080p60");
});

test("YouTube plugin follows research ordering: candidate score outranks variant count", () => {
  const probeResults = [
    {
      candidate: {
        source: "youtubei_ios",
        url: "https://example.com/ios/master.m3u8"
      },
      variants: [
        { qn: 1080, fps: 60, bandwidth: 5100000, itag: 312, title: "1080p60", url: "https://example.com/ios/1080p60.m3u8" },
        { qn: 720, fps: 60, bandwidth: 3200000, itag: 311, title: "720p60", url: "https://example.com/ios/720p60.m3u8" },
        { qn: 480, fps: 30, bandwidth: 1200000, itag: 231, title: "480p", url: "https://example.com/ios/480p.m3u8" }
      ],
      preferredVariant: {
        qn: 1080,
        fps: 60,
        bandwidth: 5100000,
        itag: 312,
        title: "1080p60",
        url: "https://example.com/ios/1080p60.m3u8"
      }
    },
    {
      candidate: {
        source: "watch_player_response_strip_n",
        url: "https://example.com/watch/master.m3u8"
      },
      variants: [
        { qn: 1080, fps: 60, bandwidth: 5000000, itag: 301, title: "1080p60", url: "https://example.com/watch/1080p60.m3u8" },
        { qn: 720, fps: 60, bandwidth: 3000000, itag: 300, title: "720p60", url: "https://example.com/watch/720p60.m3u8" }
      ],
      preferredVariant: {
        qn: 1080,
        fps: 60,
        bandwidth: 5000000,
        itag: 301,
        title: "1080p60",
        url: "https://example.com/watch/1080p60.m3u8"
      }
    }
  ];

  probeResults.sort(function (a, b) {
    return _yt_compareManifestProbeResult(a, b, 0, "video1234567");
  });

  assert.equal(probeResults[0].candidate.source, "watch_player_response_strip_n");
});

test("YouTube plugin penalizes demuxed preview manifests below real masters", () => {
  const videoId = "video1234567";
  const demuxed = {
    source: "youtubei_ios",
    url: `https://manifest.googlevideo.com/api/manifest/hls_variant/id/${videoId}.1/source/yt_live_broadcast/demuxed/1/ip/0.0.0.0/playlist_type/DVR/itag/96/index.m3u8`
  };
  const realMaster = {
    source: "watch_player_response",
    url: `https://manifest.googlevideo.com/api/manifest/hls_variant/id/${videoId}.1/source/yt_live_broadcast/ip/0.0.0.0/playlist_type/DVR/index.m3u8`
  };

  assert.ok(
    _yt_manifestCandidateScore(realMaster, videoId) >
      _yt_manifestCandidateScore(demuxed, videoId)
  );
});

test("YouTube plugin returns only real quality entries when variant ladder exists", () => {
  const playback = _yt_buildPlayback(
    "room123",
    "https://example.com/master.m3u8",
    [
      {
        qn: 1080,
        fps: 60,
        bandwidth: 5100000,
        itag: 301,
        title: "1080p60",
        url: "https://example.com/1080p60.m3u8"
      },
      {
        qn: 720,
        fps: 30,
        bandwidth: 2800000,
        itag: 95,
        title: "720p",
        url: "https://example.com/720p.m3u8"
      },
      {
        qn: 0,
        fps: 0,
        bandwidth: 64000,
        itag: 140,
        title: "",
        url: "https://example.com/audio-only.m3u8"
      }
    ],
    {
      sourceTag: "youtubei_web"
    }
  );

  assert.deepEqual(
    playback[0].qualitys.map(function (item) {
      return item.title;
    }),
    ["1080p60", "720p"]
  );
  assert.equal(
    playback[0].qualitys[0].url,
    "https://example.com/1080p60.m3u8"
  );
});

test("YouTube plugin playback headers use watch-page referer for the selected room", () => {
  const playback = _yt_buildPlayback(
    "abc123def45",
    "https://example.com/master.m3u8",
    [
      {
        qn: 1080,
        fps: 60,
        bandwidth: 5100000,
        itag: 301,
        title: "1080p60",
        url: "https://example.com/1080p60.m3u8"
      }
    ],
    {
      sourceTag: "youtubei_ios"
    }
  );

  assert.equal(
    playback[0].qualitys[0].userAgent,
    "com.google.ios.youtube/20.03.02 (iPhone16,2; U; CPU iOS 17_7_2 like Mac OS X;)"
  );
  assert.equal(
    playback[0].qualitys[0].headers.Referer,
    "https://www.youtube.com/watch?v=abc123def45"
  );
  assert.equal(
    playback[0].qualitys[0].headers.Origin,
    "https://www.youtube.com"
  );
  assert.equal(
    playback[0].qualitys[0].headers["Accept-Language"],
    "en-US,en;q=0.9"
  );
  assert.equal(
    Object.prototype.hasOwnProperty.call(playback[0].qualitys[0].headers, "user-agent"),
    false
  );
});
