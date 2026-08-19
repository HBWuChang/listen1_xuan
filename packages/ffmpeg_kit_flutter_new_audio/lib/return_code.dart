/// Stub: no-op implementation used when building without FFmpeg support.
/// Mirrors the API of ffmpeg_kit_flutter_new_audio 2.5.2 (lib/return_code.dart).
class ReturnCode {
  static const int success = 0;
  static const int cancel = 255;

  final int _value;

  ReturnCode(this._value);

  static bool isSuccess(ReturnCode? returnCode) =>
      returnCode?.getValue() == ReturnCode.success;

  int getValue() => _value;
}
