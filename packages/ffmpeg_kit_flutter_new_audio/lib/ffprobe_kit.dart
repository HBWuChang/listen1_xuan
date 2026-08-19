/// Stub: no-op implementation used when building without FFmpeg support.
/// Mirrors the API of ffmpeg_kit_flutter_new_audio 2.5.2 (lib/ffprobe_kit.dart).
library;

import 'media_information_session.dart';

/// Stub FFprobeKit. In the no-FFmpeg build this is never exercised, because the
/// app short-circuits FFmpeg paths via [isFfmpegEnabled] before calling it.
class FFprobeKit {
  FFprobeKit._();

  static Future<MediaInformationSession> getMediaInformation(
    String path, [
    int? waitTimeout,
  ]) async {
    return const MediaInformationSession(null);
  }
}
