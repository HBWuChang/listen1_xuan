/// Stub: no-op implementation used when building without FFmpeg support.
/// Mirrors the API of ffmpeg_kit_flutter_new_audio 2.5.2
/// (lib/ffmpeg_session_complete_callback.dart).
library;

import 'ffmpeg_session.dart';

typedef FFmpegSessionCompleteCallback = void Function(FFmpegSession session);
