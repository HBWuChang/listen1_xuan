/// Stub: no-op implementation used when building without FFmpeg support.
/// Mirrors the API of ffmpeg_kit_flutter_new_audio 2.5.2 (lib/ffmpeg_kit.dart).
library;

import 'ffmpeg_session.dart';
import 'ffmpeg_session_complete_callback.dart';
import 'log_callback.dart';
import 'statistics_callback.dart';

/// Stub FFmpegKit. In the no-FFmpeg build this is never exercised, because the
/// app short-circuits FFmpeg paths via [isFfmpegEnabled] before calling it.
class FFmpegKit {
  FFmpegKit._();

  /// Creates a session that immediately fails, then invokes
  /// [completeCallback] with it (matching the real plugin's async contract).
  static Future<FFmpegSession> executeWithArgumentsAsync(
    List<String> commandArguments, [
    FFmpegSessionCompleteCallback? completeCallback,
    LogCallback? logCallback,
    StatisticsCallback? statisticsCallback,
  ]) async {
    final session = FFmpegSession(commandArguments);
    completeCallback?.call(session);
    return session;
  }
}
