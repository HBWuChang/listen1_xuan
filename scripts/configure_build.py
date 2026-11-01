#!/usr/bin/env python3
"""Manage FFmpeg and Firebase overrides together; does not resolve or build."""
import argparse
from pathlib import Path
import re

BEGIN = "# BEGIN: build dependency overrides"
END = "# END: build dependency overrides"


def configure(root, feature, mode):
    pubspec = root / "pubspec.yaml"
    text = pubspec.read_text(encoding="utf-8")
    config = root / "lib/services/ffmpeg_config.dart"
    ffmpeg = "without" if "isFfmpegEnabled = false" in config.read_text(encoding="utf-8") else "with"
    firebase = "stub" if "path: packages/firebase_core_stub" in text else "real"
    if mode == "check":
        return ffmpeg if feature == "ffmpeg" else firebase
    if feature == "ffmpeg":
        ffmpeg = mode
    else:
        firebase = mode
    # Migrate the old FFmpeg-only block, and leave all unrelated YAML intact.
    for start, end in [("# BEGIN: no-ffmpeg override", "# END: no-ffmpeg override"), (BEGIN, END)]:
        pattern = re.escape(start) + r".*?" + re.escape(end)
        text = re.sub(pattern, "", text, flags=re.S)
    if re.search(r"^dependency_overrides:", text, flags=re.M):
        raise ValueError("Unmanaged dependency_overrides found; refusing to overwrite them")
    entries = []
    if ffmpeg == "without":
        entries.append("  ffmpeg_kit_flutter_new_audio:\n    path: packages/ffmpeg_kit_flutter_new_audio")
    if firebase == "stub":
        entries.extend([f"  {name}:\n    path: packages/{name}_stub" for name in ("firebase_core", "firebase_messaging")])
    text = text.rstrip() + "\n"
    if entries:
        text += "\n" + BEGIN + "\ndependency_overrides:\n" + "\n".join(entries) + "\n" + END + "\n"
    pubspec.write_text(text, encoding="utf-8")
    if feature == "ffmpeg":
        old = config.read_text(encoding="utf-8")
        config.write_text(re.sub(r"isFfmpegEnabled = (true|false)", "isFfmpegEnabled = " + str(ffmpeg == "with").lower(), old), encoding="utf-8")
    return ffmpeg if feature == "ffmpeg" else firebase


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("feature", choices=["ffmpeg", "firebase"])
    parser.add_argument("mode")
    args = parser.parse_args()
    allowed = ["with", "without", "check"] if args.feature == "ffmpeg" else ["real", "stub", "check"]
    if args.mode not in allowed:
        parser.error("mode must be one of " + ", ".join(allowed))
    print("MODE=" + configure(Path(__file__).resolve().parent.parent, args.feature, args.mode))
