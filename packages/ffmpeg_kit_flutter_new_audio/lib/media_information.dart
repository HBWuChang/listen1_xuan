/// Stub: no-op implementation used when building without FFmpeg support.
/// Mirrors the API of ffmpeg_kit_flutter_new_audio 2.5.2
/// (lib/media_information.dart).
library;

import 'stream_information.dart';

class MediaInformation {
  const MediaInformation();

  String? getDuration() => null;

  List<StreamInformation> getStreams() => const <StreamInformation>[];

  String? getFormat() => null;
}
