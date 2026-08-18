/// 是否启用 FFmpeg 相关功能（bilibili 转码、缓存元数据写入）。
///
/// 由构建脚本 `scripts/build.sh` 通过 `--dart-define=ENABLE_FFMPEG=false`
/// 关闭（无 FFmpeg 精简版）。默认开启。
const bool isFfmpegEnabled = bool.fromEnvironment(
  'ENABLE_FFMPEG',
  defaultValue: true,
);
