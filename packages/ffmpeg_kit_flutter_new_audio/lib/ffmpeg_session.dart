/// Stub: no-op implementation used when building without FFmpeg support.
/// Mirrors the API of ffmpeg_kit_flutter_new_audio 2.5.2 (lib/ffmpeg_session.dart).
library;

import 'return_code.dart';

/// A stub FFmpeg session that always reports failure (non-success return code).
/// In the no-FFmpeg build this session is never exercised, because the app
/// short-circuits FFmpeg paths via [isFfmpegEnabled] before calling it.
class FFmpegSession {
  final List<String> _arguments;

  FFmpegSession(this._arguments);

  List<String>? getArguments() => _arguments;

  /// Returns a non-success return code, indicating FFmpeg is unavailable.
  Future<ReturnCode?> getReturnCode() async => ReturnCode(1);

  Future<String?> getOutput() async =>
      'FFmpeg is not available in this build (ENABLE_FFMPEG=false).';
}
