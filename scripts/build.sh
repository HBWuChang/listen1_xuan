#!/usr/bin/env bash
#
# Switch FFmpeg dependency config in pubspec.yaml.
# Does NOT run `flutter pub get` and does NOT build anything.
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

case "$MODE" in
  with)
    strip_override
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
    echo "MODE=without"
    ;;
  check)
    if grep -q "$BEGIN_MARK" "$PUBSPEC"; then
      echo "MODE=without"
    else
      echo "MODE=with"
    fi
    ;;
  *)
    usage ;;
esac
