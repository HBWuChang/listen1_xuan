#!/usr/bin/env bash
#
# 双版本构建脚本（带/不带 FFmpeg）
#
# 用法:
#   scripts/build.sh <with|without> <platform> [flutter build 参数...]
#
# 平台:
#   apk      flutter build apk --release
#   split    flutter build apk --release --split-per-abi
#   windows  flutter build windows --release
#   ios      flutter build ios --release --no-codesign
#   macos    fastforge release --name prod   (见下方说明)
#
# 说明:
#   - with    带 FFmpeg（默认）: 使用 pub.dev 线上包 ffmpeg_kit_flutter_new_audio ^2.5.2
#   - without 精简版: 注入 dependency_overrides 指向本地 stub 包
#             packages/ffmpeg_kit_flutter_new_audio，并以
#             --dart-define=ENABLE_FFMPEG=false 构建，功能开关同步关闭。
#   - 构建结束后 pubspec.yaml 自动还原；stub 包仅影响本次构建。
#   - macos 平台使用 fastforge（项目现有发布链路），暂未接入本脚本，
#     请手动在无 FFmpeg 场景调整 pubspec 后再执行 fastforge。
#
set -euo pipefail

cd "$(dirname "$0")/.."

MODE="${1:-with}"
PLATFORM="${2:-apk}"
shift 2 || true

case "$MODE" in
  with)    ENABLE_FFMPEG=true ;;
  without) ENABLE_FFMPEG=false ;;
  *) echo "用法: $0 <with|without> <platform>"; exit 1 ;;
esac

PUBSPEC="pubspec.yaml"
BACKUP="$(mktemp)"
cp "$PUBSPEC" "$BACKUP"

restore() {
  cp "$BACKUP" "$PUBSPEC"
  rm -f "$BACKUP"
}
trap restore EXIT

if [ "$MODE" = "without" ]; then
  echo "==> 切换到精简版(无 FFmpeg)配置"
  cat >> "$PUBSPEC" << 'EOF'

# BEGIN: no-ffmpeg override (injected by scripts/build.sh)
dependency_overrides:
  ffmpeg_kit_flutter_new_audio:
    path: packages/ffmpeg_kit_flutter_new_audio
# END: no-ffmpeg override
EOF
else
  echo "==> 使用带 FFmpeg 配置（线上包 ffmpeg_kit_flutter_new_audio ^2.5.2）"
fi

echo "==> flutter pub get"
flutter pub get

SUFFIX=""
[ "$MODE" = "without" ] && SUFFIX="-lite"

case "$PLATFORM" in
  apk)
    flutter build apk --release --dart-define=ENABLE_FFMPEG=$ENABLE_FFMPEG "$@"
    ;;
  split)
    flutter build apk --release --split-per-abi --dart-define=ENABLE_FFMPEG=$ENABLE_FFMPEG "$@"
    ;;
  windows)
    flutter build windows --release --dart-define=ENABLE_FFMPEG=$ENABLE_FFMPEG "$@"
    ;;
  ios)
    flutter build ios --release --no-codesign --dart-define=ENABLE_FFMPEG=$ENABLE_FFMPEG "$@"
    ;;
  macos)
    echo "警告: macOS 走 fastforge 发布链路，本脚本不直接构建。"
    echo "      如需精简版，请先执行:  scripts/build.sh without macos-prepare"
    ;;
  macos-prepare)
    # 仅切换 pubspec（供后续手动 fastforge 使用），构建完成后自动还原。
    echo "==> pubspec 已切换为 ${MODE}，退出时自动还原"
    exit 0
    ;;
  *)
    echo "未知平台: $PLATFORM"; exit 1 ;;
esac

if [ -n "$SUFFIX" ]; then
  echo
  echo "=================================================="
  echo " 精简版构建完成（无 FFmpeg）。"
  echo " 产物请手动重命名（例如追加 $SUFFIX 后缀）以与完整版区分。"
  echo "=================================================="
fi
