import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/audio_metadata.dart';

class AudioMetadataStore {
  static final instance = AudioMetadataStore();
  Box<dynamic>? _box;
  bool _closing = false;
  Future<void>? _openFuture;
  Future<void>? _closeFuture;
  final Set<Future<void>> _writes = {};

  Future<void> open() => _openFuture ??= _open();
  Future<void> _open() async {
    if (_closing) return;
    try {
      _box = await Hive.openBox<dynamic>('audio_metadata');
    } catch (e) {
      debugPrint('打开音频元数据失败: $e');
    }
  }

  AudioMetadata? get(String id, String fileName) {
    if (_closing || _box?.isOpen != true) return null;
    try {
      final metadata = AudioMetadata.fromMap(_box!.get(id));
      return metadata?.fileName == fileName ? metadata : null;
    } catch (_) { return null; }
  }

  Future<void> _write(Future<void> Function(Box<dynamic>) operation) async {
    if (_closing || _box?.isOpen != true) return;
    final future = _runWrite(operation);
    _writes.add(future);
    try { await future; } finally { _writes.remove(future); }
  }

  Future<void> _runWrite(Future<void> Function(Box<dynamic>) operation) async {
    try { await operation(_box!); }
    catch (e) { debugPrint('写入音频元数据失败: $e'); }
  }

  Future<void> put(String id, AudioMetadata metadata) =>
      _write((box) => box.put(id, metadata.toMap()));
  Future<void> delete(String id) => _write((box) => box.delete(id));
  Future<void> retain(Set<String> ids) => _write((box) =>
      box.deleteAll(box.keys.where((key) => !ids.contains(key)).toList()));

  Future<void> close() => _closeFuture ??= _close();
  Future<void> _close() async {
    _closing = true;
    if (_openFuture != null) await _openFuture;
    await Future.wait(_writes.toList());
    if (_box?.isOpen == true) {
      try {
        try { await _box!.flush(); }
        finally { await _box!.close(); }
      } catch (e) { debugPrint('关闭音频元数据失败: $e'); }
    }
  }
}
