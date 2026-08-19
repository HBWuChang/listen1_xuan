#!/usr/bin/env bash
#
# Switch FFmpeg dependency config in pubspec.yaml and regenerate
# lib/services/ffmpeg_config.dart. Does NOT run `flutter pub get`
# and does NOT build anything.
#
# Usage:
#   scripts/build.sh with      FFmpeg-enabled (remove override, default)
#   scripts/build.sh without   FFmpeg-free (add stub package override)
#   scripts/build.sh check     Print current mode
#
set -euo pipefail

cd "$(dirname "$0")/.."

MODE="${1:-}"
PUBSPEC="pubspec.yaml"
FFMPEG_CONFIG="lib/services/ffmpeg_config.dart"
BEGIN_MARK="BEGIN: no-ffmpeg override"
END_MARK="END: no-ffmpeg override"

usage() {
  echo "Usage: scripts/build.sh <with|without|check>"
  echo "  with     FFmpeg-enabled (pub.dev package, default config)"
  echo "  without  FFmpeg-free (stub package override)"
  echo "  check    Print current mode"
  exit 1
}

# Remove any injected override block (idempotent), then trim trailing blank
# lines so the pubspec is restored byte-identical.
strip_override() {
  awk -v b="$BEGIN_MARK" -v e="$END_MARK" '
    index($0, b) {inblock=1; next}
    index($0, e) {inblock=0; next}
    !inblock {print}
  ' "$PUBSPEC" > "$PUBSPEC.tmp"
  awk '
    { lines[NR] = $0 }
    END {
      last = NR
      while (last > 0 && lines[last] == "") last--
      for (i = 1; i <= last; i++) print lines[i]
    }
  ' "$PUBSPEC.tmp" > "$PUBSPEC.tmp2"
  mv "$PUBSPEC.tmp2" "$PUBSPEC"
  rm -f "$PUBSPEC.tmp"
}

# Regenerate lib/services/ffmpeg_config.dart (delete first, then write).
write_ffmpeg_config() {
  local enabled="$1"
  rm -f "$FFMPEG_CONFIG"
  cat > "$FFMPEG_CONFIG" << EOF
// GENERATED FILE - DO NOT EDIT MANUALLY.
// 本文件由 scripts/build.sh / scripts/build.bat 自动生成，
// 手动修改会在下次切换时被覆盖。
//
// Whether FFmpeg-dependent features are enabled
// (bilibili transcode, cache metadata writing).
//
// Switch with:  scripts/build.sh with|without
const bool isFfmpegEnabled = $enabled;
EOF
}

case "$MODE" in
  with)
    strip_override
    write_ffmpeg_config true
    echo "MODE=with"
    ;;
  without)
    strip_override
    cat >> "$PUBSPEC" << EOF

# $BEGIN_MARK
dependency_overrides:
  ffmpeg_kit_flutter_new_audio:
    path: packages/ffmpeg_kit_flutter_new_audio
# $END_MARK
EOF
    write_ffmpeg_config false
    echo "MODE=without"
    ;;
  check)
    if grep -q 'isFfmpegEnabled = false' "$FFMPEG_CONFIG" 2>/dev/null; then
      echo "MODE=without"
    else
      echo "MODE=with"
    fi
    ;;
  *)
    usage ;;
esac
