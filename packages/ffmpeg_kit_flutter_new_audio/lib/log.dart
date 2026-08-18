/// Stub: no-op implementation used when building without FFmpeg support.
/// Mirrors the API of ffmpeg_kit_flutter_new_audio 2.5.2 (lib/log.dart).
class Log {
  final int _sessionId;
  final int _level;
  final String _message;

  Log(this._sessionId, this._level, this._message);

  int getSessionId() => _sessionId;
  int getLevel() => _level;
  String getMessage() => _message;
}
