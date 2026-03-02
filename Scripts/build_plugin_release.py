#!/usr/bin/env python3
"""
Package LiveParse JS plugins for remote distribution and generate plugins.json.

Default behavior packages the 9 production platforms:
  bilibili, huya, douyin, douyu, cc, ks, yy, youtube, soop
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import pathlib
import sys
import zipfile
from typing import Any


OFFICIAL_PLUGIN_IDS = [
    "bilibili",
    "huya",
    "douyin",
    "douyu",
    "cc",
    "ks",
    "yy",
    "youtube",
    "soop",
]
PLUGIN_ASSETS_DIRNAME = "plugin_assets"
REQUIRED_PLUGIN_ICON_FILES = [
    "live_card_{pluginId}.png",
    "pad_live_card_{pluginId}.png",
    "mini_live_card_{pluginId}.png",
    "tv_{pluginId}_big.png",
    "tv_{pluginId}_small.png",
    "tv_{pluginId}_big_dark.png",
    "tv_{pluginId}_small_dark.png",
]

PLATFORM_DISPLAY_NAMES = {
    "bilibili": "哔哩哔哩",
    "huya": "虎牙",
    "douyin": "抖音",
    "douyu": "斗鱼",
    "cc": "网易CC",
    "ks": "快手",
    "yy": "YY直播",
    "youtube": "YouTube",
    "soop": "SOOP",
}

ASSET_ICON_TOKENS = {
    "bilibili": "bili",
    "douyu": "douyu",
    "huya": "huya",
    "douyin": "douyin",
    "yy": "yy",
    "cc": "cc",
    "ks": "ks",
    "soop": "soop",
    # AngelLive currently falls back to YY card icon for YouTube.
    "youtube": "yy",
}

TVOS_PLATFORM_BIG_SMALL_NAMES = {
    "bilibili": ("tv_bilibili_big", "tv_bilibili_small"),
    "douyu": ("tv_douyu_big", "tv_douyu_small"),
    "huya": ("tv_huya_big", "tv_huya_small"),
    "douyin": ("tv_douyin_big", "tv_douyin_small"),
    "yy": ("tv_yy_big", "tv_yy_small"),
    "cc": ("tv_cc_big", "tv_cc_small"),
    "ks": ("tv_ks_big", "tv_ks_small"),
    "soop": ("tv_soop_big", "tv_soop_small"),
    "youtube": ("tv_youtube_big", "tv_youtube_small"),
}


def parse_args() -> argparse.Namespace:
    repo_root = pathlib.Path(__file__).resolve().parents[1]
    default_resources = repo_root / "Sources" / "LiveParse" / "Resources"
    default_output = repo_root / "Dist" / "PluginRelease"

    parser = argparse.ArgumentParser(
        description="Build plugin zip artifacts and plugins.json for LiveParse dynamic plugin updates."
    )
    parser.add_argument(
        "--resources-dir",
        type=pathlib.Path,
        default=default_resources,
        help="Directory containing lp_plugin_*_manifest.json and JS files.",
    )
    parser.add_argument(
        "--output-dir",
        type=pathlib.Path,
        default=default_output,
        help="Output directory for zips/checksums/plugins.json.",
    )
    parser.add_argument(
        "--plugins",
        type=str,
        default=",".join(OFFICIAL_PLUGIN_IDS),
        help="Comma-separated plugin IDs to include. Default is the 9 production platforms.",
    )
    parser.add_argument(
        "--url-prefix",
        action="append",
        default=[],
        help=(
            "Download base URL prefix for zip links. Repeat multiple times for mirror fallback order. "
            "Example: --url-prefix https://cdn-cn.example.com/plugins "
            "--url-prefix https://github.com/org/repo/releases/download/latest"
        ),
    )
    parser.add_argument(
        "--api-version",
        type=int,
        default=1,
        help="apiVersion to write into generated plugins.json.",
    )
    parser.add_argument(
        "--icon-prefix",
        type=str,
        default="",
        help=(
            "Optional icon URL prefix. "
            "If omitted, icon field falls back to '<pluginId>.png'."
        ),
    )
    parser.add_argument(
        "--icon-ext",
        type=str,
        default="png",
        help="Icon file extension (default: png).",
    )
    parser.add_argument(
        "--keep-entry-name",
        action="store_true",
        help="Keep manifest entry filename as-is (default rewrites to index.js inside zip).",
    )
    parser.add_argument(
        "--allow-missing-icons",
        action="store_true",
        help=(
            "Do not enforce required plugin icon files for official platforms. "
            "By default, official platforms must include 7 icon files in plugin_assets/<pluginId>/."
        ),
    )
    return parser.parse_args()


def ensure_file_exists(path: pathlib.Path, label: str) -> None:
    if not path.is_file():
        raise FileNotFoundError(f"{label} not found: {path}")


def load_manifest(path: pathlib.Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def normalized_prefix(prefix: str) -> str:
    return prefix.rstrip("/")


def build_zip(
    resources_dir: pathlib.Path,
    manifest: dict[str, Any],
    output_zip_path: pathlib.Path,
    keep_entry_name: bool,
) -> tuple[str, list[str]]:
    plugin_id = str(manifest["pluginId"])
    version = str(manifest["version"])
    original_entry = str(manifest["entry"])
    entry_src_path = resources_dir / original_entry
    ensure_file_exists(entry_src_path, f"{plugin_id}@{version} entry")

    packaged_manifest = dict(manifest)
    packaged_entry = original_entry if keep_entry_name else "index.js"
    packaged_manifest["entry"] = packaged_entry
    preload_scripts = [str(item) for item in packaged_manifest.get("preloadScripts", [])]
    plugin_assets = collect_plugin_assets(resources_dir=resources_dir, plugin_id=plugin_id)
    packaged_asset_paths: list[str] = []

    output_zip_path.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output_zip_path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        zf.writestr("manifest.json", json.dumps(packaged_manifest, ensure_ascii=False, indent=2) + "\n")
        zf.write(entry_src_path, packaged_entry)
        for preload_name in preload_scripts:
            preload_src = resources_dir / preload_name
            ensure_file_exists(preload_src, f"{plugin_id}@{version} preload script")
            zf.write(preload_src, preload_name)
        for relative_asset_path, asset_source in plugin_assets:
            zip_asset_path = f"assets/{relative_asset_path}"
            zf.write(asset_source, zip_asset_path)
            packaged_asset_paths.append(zip_asset_path)

    digest = hashlib.sha256(output_zip_path.read_bytes()).hexdigest()
    return digest, packaged_asset_paths


def collect_plugin_assets(resources_dir: pathlib.Path, plugin_id: str) -> list[tuple[str, pathlib.Path]]:
    assets_root = resources_dir / PLUGIN_ASSETS_DIRNAME / plugin_id
    if not assets_root.is_dir():
        return []

    results: list[tuple[str, pathlib.Path]] = []
    for path in sorted(assets_root.rglob("*")):
        if not path.is_file():
            continue
        if path.name.startswith("."):
            continue
        rel = path.relative_to(assets_root).as_posix()
        results.append((rel, path))
    return results


def choose_zip_urls(zip_name: str, prefixes: list[str]) -> list[str]:
    if prefixes:
        return [f"{normalized_prefix(prefix)}/{zip_name}" for prefix in prefixes]
    # Keep output deterministic even without explicit URL configuration.
    return [f"https://example.invalid/liveparse/plugins/{zip_name}"]


def make_icon_value(plugin_id: str, icon_prefix: str, icon_ext: str) -> str:
    ext = icon_ext.lstrip(".").strip() or "png"
    file_name = f"{plugin_id}.{ext}"
    if icon_prefix.strip():
        return f"{normalized_prefix(icon_prefix)}/{file_name}"
    return file_name


def make_default_icon_names(plugin_id: str) -> dict[str, str]:
    token = ASSET_ICON_TOKENS.get(plugin_id, plugin_id)
    big_name, small_name = TVOS_PLATFORM_BIG_SMALL_NAMES.get(
        plugin_id,
        (f"{plugin_id}-big", f"{plugin_id}-small"),
    )
    return {
        "iosIcon": f"pad_live_card_{token}",
        "macosIcon": f"mini_live_card_{token}",
        "tvosIcon": f"live_card_{token}",
        "tvosBigIcon": big_name,
        "tvosSmallIcon": small_name,
    }


def pick_asset(assets: list[str], file_name: str) -> str | None:
    for path in assets:
        if pathlib.Path(path).name == file_name:
            return path
    return None


def validate_required_icons(plugin_id: str, packaged_assets: list[str]) -> None:
    expected = [name.format(pluginId=plugin_id) for name in REQUIRED_PLUGIN_ICON_FILES]
    missing = [name for name in expected if pick_asset(packaged_assets, name) is None]
    if missing:
        missing_text = ", ".join(missing)
        raise ValueError(
            f"Missing required plugin icons for {plugin_id}: {missing_text}. "
            f"Expected under Resources/{PLUGIN_ASSETS_DIRNAME}/{plugin_id}/"
        )


def build_icon_fields(
    plugin_id: str,
    packaged_assets: list[str],
    icon_prefix: str,
    icon_ext: str,
) -> dict[str, str]:
    defaults = make_default_icon_names(plugin_id=plugin_id)
    fields: dict[str, str] = {
        "icon": make_icon_value(plugin_id=plugin_id, icon_prefix=icon_prefix, icon_ext=icon_ext),
        "iosIcon": defaults["iosIcon"],
        "macosIcon": defaults["macosIcon"],
        "tvosIcon": defaults["tvosIcon"],
        "tvosBigIcon": defaults["tvosBigIcon"],
        "tvosSmallIcon": defaults["tvosSmallIcon"],
    }

    # Prefer icon paths inside plugin zip so adding a plugin doesn't require app asset updates.
    icon_path = pick_asset(packaged_assets, f"live_card_{plugin_id}.png")
    ios_path = pick_asset(packaged_assets, f"pad_live_card_{plugin_id}.png")
    macos_path = pick_asset(packaged_assets, f"mini_live_card_{plugin_id}.png")
    tv_big_path = pick_asset(packaged_assets, f"tv_{plugin_id}_big.png")
    tv_small_path = pick_asset(packaged_assets, f"tv_{plugin_id}_small.png")
    tv_big_dark_path = pick_asset(packaged_assets, f"tv_{plugin_id}_big_dark.png")
    tv_small_dark_path = pick_asset(packaged_assets, f"tv_{plugin_id}_small_dark.png")

    if icon_path:
        fields["icon"] = icon_path
        fields["tvosIcon"] = icon_path
    if ios_path:
        fields["iosIcon"] = ios_path
    if macos_path:
        fields["macosIcon"] = macos_path
    if tv_big_path:
        fields["tvosBigIcon"] = tv_big_path
    if tv_small_path:
        fields["tvosSmallIcon"] = tv_small_path
    if tv_big_dark_path:
        fields["tvosBigIconDark"] = tv_big_dark_path
    if tv_small_dark_path:
        fields["tvosSmallIconDark"] = tv_small_dark_path

    return fields


def main() -> int:
    args = parse_args()
    resources_dir: pathlib.Path = args.resources_dir.resolve()
    output_dir: pathlib.Path = args.output_dir.resolve()
    zips_dir = output_dir / "zips"

    if not resources_dir.is_dir():
        print(f"Resources directory does not exist: {resources_dir}", file=sys.stderr)
        return 1

    include_ids = {item.strip() for item in args.plugins.split(",") if item.strip()}
    if not include_ids:
        print("No plugin IDs selected; check --plugins value.", file=sys.stderr)
        return 1

    manifest_paths = sorted(resources_dir.glob("lp_plugin_*_manifest.json"))
    if not manifest_paths:
        print(f"No plugin manifests found under: {resources_dir}", file=sys.stderr)
        return 1

    selected_manifests: list[dict[str, Any]] = []
    seen_pairs: set[tuple[str, str]] = set()

    for manifest_path in manifest_paths:
        manifest = load_manifest(manifest_path)
        plugin_id = str(manifest.get("pluginId", "")).strip()
        version = str(manifest.get("version", "")).strip()
        if plugin_id not in include_ids:
            continue
        if not plugin_id or not version:
            raise ValueError(f"Invalid pluginId/version in {manifest_path}")
        key = (plugin_id, version)
        if key in seen_pairs:
            raise ValueError(f"Duplicate pluginId/version detected: {plugin_id}@{version}")
        seen_pairs.add(key)
        selected_manifests.append(manifest)

    if not selected_manifests:
        print(
            f"No manifests matched selected plugin IDs: {sorted(include_ids)}",
            file=sys.stderr,
        )
        return 1

    output_dir.mkdir(parents=True, exist_ok=True)
    zips_dir.mkdir(parents=True, exist_ok=True)

    index_plugins: list[dict[str, Any]] = []
    checksum_lines: list[str] = []

    for manifest in sorted(selected_manifests, key=lambda m: (str(m["pluginId"]), str(m["version"]))):
        plugin_id = str(manifest["pluginId"])
        version = str(manifest["version"])
        zip_name = f"liveparse_{plugin_id}_{version}.zip"
        zip_path = zips_dir / zip_name

        sha256, packaged_assets = build_zip(
            resources_dir=resources_dir,
            manifest=manifest,
            output_zip_path=zip_path,
            keep_entry_name=bool(args.keep_entry_name),
        )
        urls = choose_zip_urls(zip_name=zip_name, prefixes=args.url_prefix)
        platform_name = PLATFORM_DISPLAY_NAMES.get(plugin_id) or str(manifest.get("displayName") or plugin_id)
        icon_fields = build_icon_fields(
            plugin_id=plugin_id,
            packaged_assets=packaged_assets,
            icon_prefix=args.icon_prefix,
            icon_ext=args.icon_ext,
        )
        if plugin_id in OFFICIAL_PLUGIN_IDS and not args.allow_missing_icons:
            validate_required_icons(plugin_id=plugin_id, packaged_assets=packaged_assets)

        checksum_lines.append(f"{sha256}  {zip_name}")
        item = {
            "pluginId": plugin_id,
            "version": version,
            "platform": plugin_id,
            "platformName": platform_name,
            "zipURLs": urls,
            # Keep legacy field for backward compatibility.
            "zipURL": urls[-1],
            "sha256": sha256,
        }
        item.update(icon_fields)
        index_plugins.append(item)

    generated_at = dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    index_payload = {
        "apiVersion": int(args.api_version),
        "generatedAt": generated_at,
        "plugins": index_plugins,
    }

    plugins_json_path = output_dir / "plugins.json"
    checksums_path = output_dir / "checksums.txt"
    with plugins_json_path.open("w", encoding="utf-8") as f:
        json.dump(index_payload, f, ensure_ascii=False, indent=2)
        f.write("\n")
    with checksums_path.open("w", encoding="utf-8") as f:
        f.write("\n".join(checksum_lines) + "\n")

    print(f"Built {len(index_plugins)} plugin artifact(s).")
    print(f"Zips directory: {zips_dir}")
    print(f"Index file: {plugins_json_path}")
    print(f"Checksums: {checksums_path}")
    if not args.url_prefix:
        print(
            "WARNING: --url-prefix not provided, using placeholder https://example.invalid URLs.",
            file=sys.stderr,
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
