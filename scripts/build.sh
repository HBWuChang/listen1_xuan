#!/usr/bin/env bash
#
# Dual-build config switch script (with/without FFmpeg)
#
# Usage:
#   scripts/build.sh with                   # FFmpeg-enabled (pub.dev package, default)
#   scripts/build.sh without                # FFmpeg-free (stub package override)
#   scripts/build.sh check                  # Print current mode + ENABLE_FFMPEG value
#   scripts/build.sh <mode> --no-pub-get    # Skip `flutter pub get` (CI already runs it)
#
# This script ONLY switches the pubspec dependency config (and optionally runs
# `flutter pub get`). It does NOT build any platform artifact - keep using your
# existing build commands / workflows.
#
# The switched config stays in effect until the next switch. If the command
# fails midway (pub get error / Ctrl-C / CI cancellation) it rolls back.
# Do NOT run `flutter pub get` again after switching - it would re-resolve
# against the current pubspec (i.e. drop the "without" override).
#
set -euo pipefail

cd "$(dirname "$0")/.."

MODE="${1:-}"
SKIP_PUB_GET=0
[ "${2:-}" = "--no-pub-get" ] && SKIP_PUB_GET=1

PUBSPEC="pubspec.yaml"
BEGIN_MARK="BEGIN: no-ffmpeg override"
END_MARK="END: no-ffmpeg override"
BACKUP="$(mktemp)"
cp "$PUBSPEC" "$BACKUP"

usage() {
  echo "Usage: scripts/build.sh <with|without|check> [--no-pub-get]"
  echo "  with     FFmpeg-enabled (pub.dev package, default config)"
  echo "  without  FFmpeg-free (stub package override)"
  echo "  check    Print current mode and ENABLE_FFMPEG value"
  exit 1
}

# Remove any previously injected override block (idempotent), then trim any
# trailing blank lines left behind so the pubspec is restored byte-identical.
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

# Roll back to the pre-invocation pubspec on failure; keep target config on success
rollback() {
  if [ "${1:-0}" -ne 0 ]; then
    cp "$BACKUP" "$PUBSPEC" 2>/dev/null || true
  fi
  rm -f "$BACKUP"
}
trap 'rollback $?' EXIT INT TERM

case "$MODE" in
  with)
    strip_override
    echo "==> Config: FFmpeg-enabled (pub.dev ffmpeg_kit_flutter_new_audio ^2.5.2)"
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
    echo "==> Config: FFmpeg-free (stub package packages/ffmpeg_kit_flutter_new_audio)"
    ;;
  check)
    if grep -q "$BEGIN_MARK" "$PUBSPEC"; then
      echo "MODE=without"
      echo "ENABLE_FFMPEG=false"
    else
      echo "MODE=with"
      echo "ENABLE_FFMPEG=true"
    fi
    rm -f "$BACKUP"
    exit 0
    ;;
  *)
    usage ;;
esac

if [ "$SKIP_PUB_GET" -eq 0 ]; then
  echo "==> flutter pub get"
  flutter pub get
else
  echo "==> Skipping flutter pub get (--no-pub-get)"
fi

echo
echo "Config switch done. Run your platform build now (do NOT run flutter pub get again),"
echo "and pass the matching switch:"
echo "  flutter build ... --dart-define=ENABLE_FFMPEG=$([ "$MODE" = without ] && echo false || echo true)"
