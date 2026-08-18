#!/usr/bin/env bash
#
# 双版本构建配置切换脚本（带/不带 FFmpeg）
#
# 用法:
#   scripts/build.sh with                   # 带 FFmpeg（线上包，默认配置）
#   scripts/build.sh without                # 无 FFmpeg（stub 包 override）
#   scripts/build.sh check                  # 打印当前模式
#   scripts/build.sh <mode> --no-pub-get    # 跳过 flutter pub get（CI 已有该步骤时）
#
# 说明:
#   - 本脚本只负责切换 pubspec 依赖配置并执行 flutter pub get，
#     **不执行平台构建**。构建请沿用各平台原有命令或 workflow。
#   - with    使用 pub.dev 线上包 ffmpeg_kit_flutter_new_audio ^2.5.2。
#   - without 注入 dependency_overrides 指向本地 stub 包
#             packages/ffmpeg_kit_flutter_new_audio；构建时还需以
#             --dart-define=ENABLE_FFMPEG=false 关闭对应功能（见 check）。
#   - 切换成功后配置保持生效，直到下次切换；命令中途失败会自动回滚。
#   - 注意: 切换后请勿再执行 flutter pub get，否则会按当前 pubspec 重解析。
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
  echo "用法: scripts/build.sh <with|without|check> [--no-pub-get]"
  echo "  with     带 FFmpeg（线上包，默认配置）"
  echo "  without  无 FFmpeg（stub 包 override）"
  echo "  check    打印当前模式与 ENABLE_FFMPEG 值"
  exit 1
}

# 移除注入的 override 块（幂等：不存在也不报错）
strip_override() {
  awk -v b="$BEGIN_MARK" -v e="$END_MARK" '
    index($0, b) {inblock=1; next}
    index($0, e) {inblock=0; next}
    !inblock {print}
  ' "$PUBSPEC" > "$PUBSPEC.tmp" && mv "$PUBSPEC.tmp" "$PUBSPEC"
}

# 回滚：命令中途失败（退出码非 0）时恢复进入前的 pubspec；
# 成功完成则保持目标配置。
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
    echo "==> 配置: 带 FFmpeg（线上包 ffmpeg_kit_flutter_new_audio ^2.5.2）"
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
    echo "==> 配置: 无 FFmpeg（stub 包 packages/ffmpeg_kit_flutter_new_audio）"
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
  echo "==> 跳过 flutter pub get（--no-pub-get）"
fi

echo
echo "配置切换完成。请随后执行平台构建（勿再 flutter pub get），"
echo "构建时同步注入开关:"
echo "  flutter build ... --dart-define=ENABLE_FFMPEG=$([ "$MODE" = without ] && echo false || echo true)"
