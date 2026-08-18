/// Stub: no-op implementation used when building without FFmpeg support.
/// Mirrors the API of ffmpeg_kit_flutter_new_audio 2.5.2
/// (lib/media_information_session.dart).
library;

import 'media_information.dart';

class MediaInformationSession {
  final MediaInformation? _mediaInformation;

  const MediaInformationSession(this._mediaInformation);

  MediaInformation? getMediaInformation() => _mediaInformation;

  Future<String?> getOutput() async =>
      'FFmpeg is not available in this build (ENABLE_FFMPEG=false).';
}
