#!/usr/bin/env node

const test = require("node:test");
const assert = require("node:assert/strict");

const {
  _yt_parseM3U8VariantsFromText,
  _yt_compareVariantForPreferQn,
  _yt_compareManifestProbeResult,
} = require("../../Resources/lp_plugin_youtube_1.0.1_index.js");

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
