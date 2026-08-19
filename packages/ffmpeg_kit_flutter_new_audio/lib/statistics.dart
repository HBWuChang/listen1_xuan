/// Stub: no-op implementation used when building without FFmpeg support.
/// Mirrors the API of ffmpeg_kit_flutter_new_audio 2.5.2 (lib/statistics.dart).
class Statistics {
  final int _size;
  final double _speed;

  Statistics(this._size, this._speed);

  int getSize() => _size;
  double getSpeed() => _speed;
}
