#!/usr/bin/env node

const test = require("node:test");
const assert = require("node:assert/strict");

const {
  _yt_parseM3U8VariantsFromText,
  _yt_parseM3U8ManifestTextLatest,
  _yt_compareVariantForPreferQn,
  _yt_scoreManifestCandidateLatest,
  _yt_finalizeManifestCandidateLatest,
  _yt_pickBestManifestLatest,
  _yt_buildPlayback,
} = require("../../Resources/lp_plugin_youtube_1.1.0_index.js");

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

test("YouTube plugin parses demuxed audio groups from manifest text", () => {
  const parsed = _yt_parseM3U8ManifestTextLatest(
    `#EXTM3U
#EXT-X-MEDIA:URI="https://example.com/audio/233.m3u8",TYPE=AUDIO,GROUP-ID="233",NAME="Default",DEFAULT=YES,AUTOSELECT=YES
#EXT-X-MEDIA:URI="https://example.com/audio/234.m3u8",TYPE=AUDIO,GROUP-ID="234",NAME="Default",DEFAULT=YES,AUTOSELECT=YES
#EXT-X-STREAM-INF:BANDWIDTH=2969452,CODECS="avc1.4D401F,mp4a.40.2",RESOLUTION=1280x720,FRAME-RATE=30,AUDIO="234"
https://example.com/video/720p.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=546239,CODECS="avc1.4D4015,mp4a.40.5",RESOLUTION=426x240,FRAME-RATE=30,AUDIO="233"
https://example.com/video/240p.m3u8
`,
    "https://example.com/master/index.m3u8"
  );

  assert.equal(parsed.audioTracks.length, 2);
  assert.equal(parsed.audioTracks[0].groupId, "233");
  assert.equal(parsed.audioTracks[0].uri, "https://example.com/audio/233.m3u8");
  assert.equal(parsed.audioTracks[1].groupId, "234");
  assert.equal(parsed.variants[0].audioGroupId, "234");
  assert.equal(parsed.variants[0].audioUri, "https://example.com/audio/234.m3u8");
  assert.equal(parsed.variants[1].audioGroupId, "233");
  assert.equal(parsed.variants[1].audioUri, "https://example.com/audio/233.m3u8");
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

test("YouTube plugin finalize step keeps demuxed uri but exposes master playUrl", () => {
  const finalized = _yt_finalizeManifestCandidateLatest(
    {
      source: "youtubei_ios",
      videoId: "video1234567",
      sourcePreference: 160,
      manifestIsDemuxed: true,
      requiresNTransform: false,
      originalUrl: "https://example.com/master/index.m3u8",
      userAgent: "ios-ua"
    },
    _yt_parseM3U8ManifestTextLatest(
      `#EXTM3U
#EXT-X-MEDIA:URI="https://example.com/audio/main.m3u8",TYPE=AUDIO,GROUP-ID="233",NAME="Default",DEFAULT=YES,AUTOSELECT=YES
#EXT-X-STREAM-INF:BANDWIDTH=2969452,CODECS="avc1.4D401F,mp4a.40.2",RESOLUTION=1280x720,FRAME-RATE=30,AUDIO="233"
https://example.com/video/720p.m3u8
`,
      "https://example.com/master/index.m3u8"
    ),
    {
      url: "https://example.com/master/index.m3u8",
      urlTransform: "none"
    }
  );

  assert.equal(finalized.qualityCount, 1);
  assert.equal(finalized.variants[0].uri, "https://example.com/video/720p.m3u8");
  assert.equal(finalized.variants[0].playUrl, "https://example.com/master/index.m3u8");
  assert.equal(finalized.preferredAudioUrl, "https://example.com/audio/main.m3u8");
  assert.equal(finalized.variants[0].hasSeparateAudio, true);
});

test("YouTube plugin manifest scoring prefers stronger real ladders over weaker candidates", () => {
  const highQualityDemuxed = {
    source: "youtubei_ios",
    videoId: "video1234567",
    sourcePreference: 160,
    manifestIsDemuxed: true,
    requiresNTransform: false,
    usedFallbackStripN: false,
    qualityCount: 3,
    maxHeight: 1440,
    maxFps: 60,
    maxBandwidth: 7600000,
    hasAudioTracks: true,
    preferredQuality: {
      height: 1440,
      fps: 60,
      bandwidth: 7600000
    }
  };
  const lowerQualityMuxed = {
    source: "youtubei_android",
    videoId: "video1234567",
    sourcePreference: 220,
    manifestIsDemuxed: false,
    requiresNTransform: false,
    usedFallbackStripN: false,
    qualityCount: 5,
    maxHeight: 720,
    maxFps: 60,
    maxBandwidth: 2922155,
    hasAudioTracks: true,
    preferredQuality: {
      height: 720,
      fps: 60,
      bandwidth: 2922155
    }
  };

  assert.ok(
    _yt_scoreManifestCandidateLatest(highQualityDemuxed, "video1234567") >
      _yt_scoreManifestCandidateLatest(lowerQualityMuxed, "video1234567")
  );
  assert.equal(
    _yt_pickBestManifestLatest([lowerQualityMuxed, highQualityDemuxed]).source,
    "youtubei_ios"
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
    "com.google.ios.youtube/21.02.3 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)"
  );
  assert.equal(
    playback[0].qualitys[0].headers["User-Agent"],
    "com.google.ios.youtube/21.02.3 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)"
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
});

test("YouTube iOS playback keeps quality labels and returns the parsed quality URLs", () => {
  const playback = _yt_buildPlayback(
    "abc123def45",
    "https://example.com/master.m3u8",
    [
      {
        qn: 1080,
        fps: 60,
        bandwidth: 5100000,
        itag: 312,
        title: "1080p60",
        url: "https://example.com/itag/312/index.m3u8",
        playUrl: "https://example.com/master/index.m3u8"
      },
      {
        qn: 720,
        fps: 60,
        bandwidth: 3200000,
        itag: 311,
        title: "720p60",
        url: "https://example.com/itag/311/index.m3u8",
        playUrl: "https://example.com/master/index.m3u8"
      }
    ],
    {
      sourceTag: "youtubei_ios"
    }
  );

  assert.deepEqual(
    playback[0].qualitys.map(function (item) {
      return item.title;
    }),
    ["1080p60", "720p60"]
  );
  assert.equal(
    playback[0].qualitys[0].url,
    "https://example.com/master/index.m3u8"
  );
  assert.equal(
    playback[0].qualitys[1].url,
    "https://example.com/master/index.m3u8"
  );
});
