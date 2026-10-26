import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;

/// Disk-backed clipboard transfers. A batch is published only after reception
/// and parsing succeed; staging files and partially published batches roll back.
class PasteFileTransfer {
  static const stagingDirectoryName = '.listen1-paste-transfers';
  static final _active = <String>{};

  /// Recover staging directories left by an app/process crash. Never touch an
  /// active transfer, user source files, or successfully published downloads.
  static Future<void> cleanStale(String saveDir, {DateTime? now}) async {
    final root = Directory(p.join(saveDir, stagingDirectoryName));
    if (!await root.exists()) return;
    final cutoff = (now ?? DateTime.now()).subtract(const Duration(days: 1));
    await for (final entity in root.list(followLinks: false)) {
      if (entity is! Directory || _active.contains(entity.path)) continue;
      try {
        if ((await entity.stat()).modified.isBefore(cutoff) &&
            !_active.contains(entity.path)) {
          await entity.delete(recursive: true);
        }
      } on FileSystemException {
        // Another cleanup may already have removed this expired directory.
      }
    }
  }

  static String? fileNameFromDisposition(String disposition) {
    final encoded = RegExp(
      r'''filename\*\s*=\s*UTF-8''([^;\s]+)''',
      caseSensitive: false,
    ).firstMatch(disposition);
    if (encoded != null) return Uri.decodeComponent(encoded.group(1)!);
    final plain = RegExp(
      r'''filename\s*=\s*(?:"([^"]*)"|([^;]+))''',
      caseSensitive: false,
    ).firstMatch(disposition);
    return plain == null ? null : (plain.group(1) ?? plain.group(2))!.trim();
  }

  static String boundaryFromContentType(String value) {
    final type = ContentType.parse(value);
    final boundary = type.parameters['boundary'];
    if (!type.mimeType.startsWith('multipart/') ||
        boundary == null ||
        boundary.isEmpty ||
        boundary.length > 70) {
      throw const FormatException('Invalid multipart boundary');
    }
    return boundary;
  }

  static String _safeName(String value) {
    // Treat separators from either platform as paths, regardless of receiver OS.
    final name = p.windows.basename(
      value.replaceAll('\\', '/').replaceFirst(RegExp(r'^[a-zA-Z]:'), ''),
    );
    if (name.isEmpty ||
        name == '.' ||
        name == '..' ||
        name.contains(RegExp(r'[\x00-\x1f\x7f]'))) {
      throw const FormatException('Invalid file name');
    }
    return name;
  }

  static Future<int> _write(
    Stream<List<int>> stream,
    File file,
    bool Function()? isCancelled,
  ) async {
    final output = await file.open(mode: FileMode.write);
    var length = 0;
    try {
      await for (final chunk in stream) {
        _checkCancelled(isCancelled);
        await output.writeFrom(chunk);
        length += chunk.length;
      }
      return length;
    } finally {
      await output.close();
    }
  }

  static void _checkCancelled(bool Function()? isCancelled) {
    if (isCancelled?.call() ?? false) {
      throw const HttpException('Transfer cancelled');
    }
  }

  /// Provide [boundary] for multipart bodies, or [fileName] for a raw image.
  static Future<List<String>> receive({
    required Stream<List<int>> stream,
    required String saveDir,
    String? boundary,
    String? fileName,
    int? expectedLength,
    bool Function()? isCancelled,
  }) async {
    await Directory(saveDir).create(recursive: true);
    await cleanStale(saveDir);
    final root = await Directory(
      p.join(saveDir, stagingDirectoryName),
    ).create(recursive: true);
    final staging = await root.createTemp('transfer-');
    _active.add(staging.path);
    final published = <String>[];
    try {
      final body = File(p.join(staging.path, 'body'));
      final length = await _write(stream, body, isCancelled);
      if (expectedLength != null &&
          expectedLength >= 0 &&
          expectedLength != length) {
        throw const FormatException('Incomplete transfer');
      }
      final files = <(File, String)>[];
      if (boundary == null) {
        if (length == 0) throw const FormatException('Empty image');
        files.add((body, _safeName(fileName!)));
      } else {
        // Own the underlying subscription explicitly: MIME cancellation can
        // be deferred while a part is unconsumed (e.g. invalid headers/names).
        final source = StreamIterator<List<int>>(body.openRead());
        try {
          await for (final part in _readIterator(
            source,
          ).transform(MimeMultipartTransformer(boundary))) {
            final name = fileNameFromDisposition(
              part.headers['content-disposition'] ?? '',
            );
            if (name == null) {
              await part.drain<void>();
              continue;
            }
            final safeName = _safeName(name);
            final file = File(p.join(staging.path, 'part-${files.length}'));
            final partLength = await _write(part, file, isCancelled);
            final declaredLength = part.headers['content-length'];
            if (declaredLength != null &&
                int.parse(declaredLength) != partLength) {
              throw const FormatException('Incomplete multipart file');
            }
            files.add((file, safeName));
          }
        } finally {
          await source.cancel();
        }
        if (files.isEmpty) throw const FormatException('No files received');
      }
      _checkCancelled(isCancelled);
      // No await between checking and rename: concurrent transfers in this
      // isolate cannot select the same destination. Staging is on the same FS.
      for (final (file, name) in files) {
        var target = p.join(saveDir, name);
        var suffix = 1;
        while (FileSystemEntity.typeSync(target, followLinks: false) !=
            FileSystemEntityType.notFound) {
          target = p.join(
            saveDir,
            '${p.basenameWithoutExtension(name)}(${suffix++})${p.extension(name)}',
          );
        }
        file.renameSync(target);
        published.add(target);
      }
      return published;
    } catch (_) {
      for (final path in published) {
        try {
          final file = File(path);
          if (file.existsSync()) file.deleteSync();
        } on FileSystemException catch (error, stack) {
          developer.log(
            'Could not roll back $path',
            name: 'PasteFileTransfer',
            error: error,
            stackTrace: stack,
          );
        }
      }
      rethrow;
    } finally {
      await _deleteStaging(staging);
    }
  }

  static Stream<List<int>> _readIterator(
    StreamIterator<List<int>> source,
  ) async* {
    while (await source.moveNext()) {
      yield source.current;
    }
  }

  static Future<void> _deleteStaging(Directory directory) async {
    try {
      if (await directory.exists()) await directory.delete(recursive: true);
    } on FileSystemException catch (error, stack) {
      // Keep successful downloads successful; recovery retries this directory.
      developer.log(
        'Could not clean staging directory ${directory.path}',
        name: 'PasteFileTransfer',
        error: error,
        stackTrace: stack,
      );
    } finally {
      _active.remove(directory.path);
    }
  }
}

/// An owned clipboard-image snapshot. Replacing/stopping retires it; ongoing
/// HTTP readers keep it alive until their response finishes (including errors).
class PasteImageSnapshot {
  final Directory _directory;
  final File file;
  final String name;
  var _readers = 0;
  var _retired = false;
  Future<void>? _cleanup;

  PasteImageSnapshot._(this._directory, this.file, this.name);

  static Future<PasteImageSnapshot> create(
    String saveDir,
    List<int> bytes,
    String name,
  ) async {
    await PasteFileTransfer.cleanStale(saveDir);
    final root = await Directory(
      p.join(saveDir, PasteFileTransfer.stagingDirectoryName),
    ).create(recursive: true);
    final directory = await root.createTemp('image-');
    PasteFileTransfer._active.add(directory.path);
    try {
      final file = File(p.join(directory.path, 'image'));
      await file.writeAsBytes(bytes);
      return PasteImageSnapshot._(directory, file, name);
    } catch (_) {
      await PasteFileTransfer._deleteStaging(directory);
      rethrow;
    }
  }

  Future<void> send(Future<void> Function(File file) sendFile) async {
    if (_retired) throw StateError('Image snapshot has expired');
    _readers++;
    try {
      await sendFile(file);
    } finally {
      _readers--;
      await _cleanIfUnused();
    }
  }

  Future<void> retire() async {
    _retired = true;
    await _cleanIfUnused();
  }

  Future<void> _cleanIfUnused() async {
    if (!_retired || _readers != 0) return;
    await (_cleanup ??= PasteFileTransfer._deleteStaging(_directory));
  }
}
