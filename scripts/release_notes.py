#!/usr/bin/env python3
"""Generate an installation guide from uploaded assets, preserving other notes."""

import argparse
import base64
import json
import re
import subprocess
from pathlib import Path

START = "<!-- install-guide:start -->"
END = "<!-- install-guide:end -->"
ARCHES = ("arm64-v8a", "armeabi-v7a", "x86_64", "universal")
ARCH_LABELS = {
    "arm64-v8a": "ARM64 · 推荐",
    "armeabi-v7a": "ARM32 · 仅适用 32 位设备",
    "x86_64": "x86_64 · 仅适用对应设备/模拟器",
    "universal": "通用包 · 不推荐",
}


def gh_api(endpoint, payload=None, paginate=False):
    command = ["gh", "api", endpoint]
    if paginate:
        command += ["--paginate", "--slurp"]
    if payload is not None:
        command += ["--method", "PATCH", "--input", "-"]
    result = subprocess.run(
        command,
        input=json.dumps(payload) if payload is not None else None,
        text=True,
        capture_output=True,
        check=True,
    )
    return json.loads(result.stdout)


def source_version(repo, sha):
    if not re.fullmatch(r"[0-9a-fA-F]{40}", sha):
        raise ValueError("Expected the triggering workflow's full commit SHA")
    content = gh_api(f"repos/{repo}/contents/pubspec.yaml?ref={sha}")
    pubspec = base64.b64decode(content["content"]).decode("utf-8")
    match = re.search(r"^version:\s*([^\s#]+)", pubspec, re.MULTILINE)
    if not match:
        raise ValueError("No version in source pubspec.yaml")
    return match[1].strip("\"'")


def classify(name):
    # Uploaded names use dots; local build names use spaces. Never rewrite URLs.
    normalized = name.replace(" ", ".")
    match = re.search(r"-([0-9a-fA-F]{7,40})(?:\.app)?\.(?:apk|zip)$", normalized)
    if not match:
        return None
    if normalized.startswith("app-") and normalized.endswith(".apk"):
        platform = "Android"
        arch = next((a for a in ARCHES[:-1] if normalized.startswith(f"app-{a}-release-")), "universal")
    elif normalized.startswith("windows-build-artifact-") and normalized.endswith(".zip"):
        platform, arch = "Windows", "x64"
    elif normalized.startswith("listen1_xuan-ios-") and normalized.endswith(".app.zip"):
        platform, arch = "iOS", ""
    elif normalized.startswith("listen1_xuan-") and "-macos-" in normalized and normalized.endswith(".zip"):
        platform, arch = "macOS", ""
    else:
        return None
    return {
        "platform": platform,
        "arch": arch,
        "ffmpeg": "-ffmpeg-" in normalized,
        "embedded": "without.embedded.Cronet" not in normalized,
        "hash": match[1],
    }


def size_label(size):
    return f"{size / (1024 * 1024):.2f} MiB"


def download(asset, recommended=False):
    info = classify(asset["name"])
    label = "推荐下载" if recommended else "下载"
    value = f"[{label}]({asset['browser_download_url']}) · {size_label(asset['size'])} · `{info['hash']}`"
    return f"**{value}**" if recommended else value


def generate_guide(assets):
    packages = [a for a in assets if a.get("state", "uploaded") == "uploaded" and classify(a["name"])]
    # Do not require a single release-wide hash: platforms may be built separately.
    packages.sort(key=lambda a: (a.get("updated_at", ""), a["name"]), reverse=True)
    lines = [
        "## 安装包选择",
        "",
        "> **优先推荐：无 FFmpeg 精简版。Android 的 ARM64 设备优先选择 ARM64 + 不内置 Cronet 版（需要可用的 Google Play 服务）。**",
        "> **GitHub 相关功能可能出现问题；推荐的不内置 Cronet 版在 Google Play 服务缺失或不可用时可能请求失败，任何版本均不保证 GitHub 在当前网络环境下可访问。**",
        "",
        "- **精简版（推荐）**：体积更小，仍可缓存；Bilibili 缓存保留原始格式，不转 MP3、不写入歌曲元数据。",
        "- **含 FFmpeg**：适合需要 Bilibili 缓存转 MP3、缓存写入歌曲元数据的用户，体积较大。",
        "- **内置 Cronet**：无需 Google Play 服务，适合服务缺失或不可用的设备；文件名不含 `without.embedded.Cronet`。",
        "- **不内置 Cronet（Android 推荐）**：需要可用的 Google Play 服务；文件名含 `without.embedded.Cronet`（本地构建名可能使用空格）。",
        "- ARM64 适用于大多数近年 ARM 手机；32 位 ARM 设备请选择 ARM32；x86_64 仅适用于对应设备或模拟器。",
        "- **不推荐通用包**：包含多种架构、体积较大。请优先确认设备架构并选择对应的单架构包。",
        "",
        "每个下载链接旁均列出文件体积和该安装包自己的提交 hash；不同平台的 hash 可能不同。体积为下载文件大小（MiB），不是安装后的占用。",
        "",
        "### Android",
        "",
        "| 设备架构 | 不内置 Cronet · 精简版（推荐） | 不内置 Cronet · 含 FFmpeg | 内置 Cronet · 精简版 | 内置 Cronet · 含 FFmpeg |",
        "|---|---|---|---|---|",
    ]
    for arch in ARCHES:
        cells = []
        for embedded, ffmpeg in ((False, False), (False, True), (True, False), (True, True)):
            matches = [a for a in packages if (i := classify(a["name"]))["platform"] == "Android" and i["arch"] == arch and i["embedded"] == embedded and i["ffmpeg"] == ffmpeg]
            cells.append("<br>".join(download(a, arch == "arm64-v8a" and not embedded and not ffmpeg) for a in matches) or "暂未发布")
        lines.append(f"| {ARCH_LABELS[arch]} | " + " | ".join(cells) + " |")
    lines += [
        "",
        "### Windows / macOS / iOS",
        "",
        "| 平台 | 精简版（推荐） | 含 FFmpeg | 安装说明 |",
        "|---|---|---|---|",
    ]
    instructions = {
        "Windows": "x64 包；完整解压后运行 `listen1_xuan.exe`，保留同目录依赖文件。",
        "macOS": "解压后将应用放入“应用程序”。",
        "iOS": "未签名 `.app.zip`；需要自行签名或适用的侧载流程，不能直接点击安装。",
    }
    for platform in instructions:
        cells = []
        for ffmpeg in (False, True):
            matches = [a for a in packages if (i := classify(a["name"]))["platform"] == platform and i["ffmpeg"] == ffmpeg]
            cells.append("<br>".join(download(a, not ffmpeg) for a in matches) or "暂未发布")
        lines.append(f"| {platform} | {' | '.join(cells)} | {instructions[platform]} |")
    return "\n".join(lines)


def merge_body(body, guide):
    body = body or ""
    block = f"{START}\n{guide}\n{END}"
    if START not in body and END not in body:
        return block + ("\n\n" + body if body else "\n")
    if body.count(START) != 1 or body.count(END) != 1 or body.index(END) < body.index(START):
        raise ValueError("Installation guide markers are malformed; refusing to overwrite notes")
    start, end = body.index(START), body.index(END) + len(END)
    return body[:start] + block + body[end:]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo")
    parser.add_argument("--tag")
    parser.add_argument("--source-sha", help="Print the version from this commit, without editing a release")
    parser.add_argument("--release-json", type=Path, help="Offline preview using a REST release response")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--publish", action="store_true")
    args = parser.parse_args()
    if args.source_sha:
        if not args.repo:
            parser.error("--source-sha requires --repo")
        print(source_version(args.repo, args.source_sha))
        return
    if args.release_json:
        if args.publish:
            parser.error("Offline JSON cannot be published")
        release = json.loads(args.release_json.read_text(encoding="utf-8"))
    else:
        if not args.repo or not args.tag:
            parser.error("Provide --release-json or both --repo and --tag")
        from urllib.parse import quote
        release = gh_api(f"repos/{args.repo}/releases/tags/{quote(args.tag, safe='')}")
        pages = gh_api(f"repos/{args.repo}/releases/{release['id']}/assets?per_page=100", paginate=True)
        release["assets"] = [asset for page in pages for asset in page]
    body = merge_body(release.get("body"), generate_guide(release["assets"]))
    if args.output:
        args.output.write_text(body, encoding="utf-8")
    elif not args.publish:
        print(body)
    if args.publish and body != (release.get("body") or ""):
        gh_api(f"repos/{args.repo}/releases/{release['id']}", {"body": body})
        print(f"Updated installation guide for {release['tag_name']}")


if __name__ == "__main__":
    main()
