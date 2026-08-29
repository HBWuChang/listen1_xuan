import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

typedef FilesDroppedCallback = FutureOr<void> Function(List<String> paths);
typedef TextDroppedCallback = FutureOr<void> Function(String text);

/// 接收来自系统或其他应用的文件、文本和 URI 拖放。
///
/// 真实文件和目录直接返回本地路径；没有稳定路径的虚拟文件会先保存到
/// 系统临时目录，再将临时文件路径交给 [onFilesDropped]。
class NativeFileDropRegion extends StatelessWidget {
  const NativeFileDropRegion({
    super.key,
    required this.child,
    required this.onFilesDropped,
    required this.onTextDropped,
    this.enabled = true,
    this.onDropEnter,
    this.onDropLeave,
  });

  final Widget child;
  final FilesDroppedCallback onFilesDropped;
  final TextDroppedCallback onTextDropped;
  final bool enabled;
  final VoidCallback? onDropEnter;
  final VoidCallback? onDropLeave;

  static final List<FileFormat> _fileFormats = Formats.standardFormats
      .whereType<FileFormat>()
      .toList(growable: false);

  static final List<DataFormat> _acceptedFormats = <DataFormat>[
    Formats.fileUri,
    Formats.plainText,
    Formats.uri,
    ..._fileFormats,
  ];

  static const Set<PlatformFormat> _macTextFormats = {
    'public.utf8-plain-text',
    'public.utf16-external-plain-text',
    'public.plain-text',
    'public.url',
    'public.rtf',
    'public.html',
    'com.apple.notes.richtext',
  };

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    return DropRegion(
      formats: _acceptedFormats,
      hitTestBehavior: HitTestBehavior.opaque,
      onDropOver: (event) {
        final acceptsDrop = event.session.items.any(_canReadItem);
        if (acceptsDrop) {
          if (event.session.allowedOperations.contains(DropOperation.copy)) {
            return DropOperation.copy;
          }
          if (event.session.allowedOperations.contains(DropOperation.link)) {
            return DropOperation.link;
          }
        }
        return DropOperation.none;
      },
      onDropEnter: (_) => onDropEnter?.call(),
      onDropLeave: (_) => onDropLeave?.call(),
      onPerformDrop: (event) async {
        final items = event.session.items.where(_canReadItem).toList();
        if (items.isEmpty) return;

        final batch = _DropBatch(
          itemCount: items.length,
          onComplete: (result) {
            if (result.paths.isNotEmpty) {
              unawaited(Future.sync(() => onFilesDropped(result.paths)));
            }
            if (result.texts.isNotEmpty) {
              unawaited(
                Future.sync(() => onTextDropped(result.texts.join('\n'))),
              );
            }
          },
        );

        // 数据必须在 onPerformDrop 返回前发起请求。各文件可以在回调中继续
        // 异步读取，避免让原生拖放线程等待大文件写入磁盘。
        for (var index = 0; index < items.length; index++) {
          _readItem(items[index], (item) => batch.complete(index, item));
        }
      },
      child: child,
    );
  }

  static bool _canReadFile(DropItem item) {
    if (Platform.isMacOS) {
      if (item.platformFormats.contains('public.file-url')) return true;
      if (_isMacText(item)) return false;
    }
    if (item.canProvide(Formats.fileUri)) return true;
    return _fileFormats.any(item.canProvide);
  }

  static bool _canReadItem(DropItem item) {
    return (Platform.isMacOS && _isMacText(item)) ||
        _canReadFile(item) ||
        item.canProvide(Formats.plainText) ||
        item.canProvide(Formats.uri);
  }

  static bool _isMacText(DropItem item) {
    return item.platformFormats.any(_macTextFormats.contains);
  }

  static void _readItem(DropItem item, ValueChanged<_DroppedItem?> complete) {
    final reader = item.dataReader;
    if (reader == null) {
      complete(null);
      return;
    }

    var completed = false;
    var fallbackStarted = false;

    void finish(_DroppedItem? item) {
      if (completed) return;
      completed = true;
      complete(item);
    }

    void readText() {
      if (completed) return;

      void readUri() {
        if (completed) return;
        if (reader.canProvide(Formats.uri)) {
          final progress = reader.getValue<NamedUri>(
            Formats.uri,
            (value) {
              if (value != null) {
                finish(_DroppedItem(text: value.uri.toString()));
              } else {
                finish(null);
              }
            },
            onError: (error) {
              debugPrint('读取拖入的 URI 失败: $error');
              finish(null);
            },
          );
          if (progress != null) return;
        }
        finish(null);
      }

      if (reader.canProvide(Formats.plainText)) {
        final progress = reader.getValue<String>(
          Formats.plainText,
          (value) {
            if (value != null && value.isNotEmpty) {
              finish(_DroppedItem(text: value));
            } else {
              readUri();
            }
          },
          onError: (error) {
            debugPrint('读取拖入的文本失败: $error');
            readUri();
          },
        );
        if (progress != null) return;
      }
      readUri();
    }

    void readVirtualFile() {
      if (fallbackStarted || completed) return;
      fallbackStarted = true;

      FileFormat? format;
      for (final candidate in reader.getFormats(_fileFormats)) {
        if (candidate is FileFormat) {
          format = candidate;
          break;
        }
      }

      if (format == null) {
        readText();
        return;
      }

      final progress = reader.getFile(
        format,
        (file) async {
          try {
            // 必须在该回调中取得流；之后才可以异步准备临时目录。
            final stream = file.getStream();
            final tempDirectory = await Directory.systemTemp.createTemp(
              'listen1_xuan_drop_',
            );
            final suggestedName =
                file.fileName ??
                await reader.getSuggestedName() ??
                'dropped_file';
            final safeName = _safeFileName(suggestedName);
            final target = File(p.join(tempDirectory.path, safeName));
            final sink = target.openWrite();
            try {
              await for (final chunk in stream) {
                sink.add(chunk);
              }
            } finally {
              await sink.close();
            }
            finish(_DroppedItem(path: target.path));
          } catch (error, stackTrace) {
            debugPrint('保存拖入的虚拟文件失败: $error\n$stackTrace');
            finish(null);
          }
        },
        onError: (error) {
          debugPrint('读取拖入的虚拟文件失败: $error');
          finish(null);
        },
        synthesizeFilesFromURIs: false,
      );

      if (progress == null) finish(null);
    }

    void readFileUri() {
      final progress = reader.getValue<Uri>(
        Formats.fileUri,
        (uri) {
          if (uri != null && uri.scheme == 'file') {
            try {
              finish(
                _DroppedItem(path: uri.toFilePath(windows: Platform.isWindows)),
              );
            } catch (error) {
              debugPrint('解析拖入的文件路径失败: $error');
              readVirtualFile();
            }
          } else {
            // macOS 上普通网页 URL 和文件 URL 的原生格式可能重叠。
            // fileUri 解码为 null 时应按文本/URI 继续读取，不能将链接
            // 当成浏览器提供的虚拟文件写入临时目录。
            readText();
          }
        },
        onError: (error) {
          debugPrint('读取拖入的文件 URI 失败: $error');
          readText();
        },
      );
      if (progress == null) readText();
    }

    if (Platform.isMacOS) {
      if (reader.platformFormats.contains('public.file-url')) {
        readFileUri();
      } else if (_isMacText(item)) {
        readText();
      } else {
        readVirtualFile();
      }
    } else if (reader.canProvide(Formats.fileUri)) {
      readFileUri();
    } else {
      readVirtualFile();
    }
  }

  static String _safeFileName(String value) {
    final basename = p
        .basename(value)
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_');
    return basename.isEmpty ? 'dropped_file' : basename;
  }
}

class _DropBatch {
  _DropBatch({required int itemCount, required this.onComplete})
    : _remaining = itemCount,
      _items = List<_DroppedItem?>.filled(itemCount, null),
      _completed = List<bool>.filled(itemCount, false);

  final ValueChanged<_DroppedResult> onComplete;
  final List<_DroppedItem?> _items;
  final List<bool> _completed;
  int _remaining;

  void complete(int index, _DroppedItem? item) {
    if (_completed[index]) return;
    _completed[index] = true;
    _items[index] = item;
    _remaining--;

    if (_remaining == 0) {
      onComplete(
        _DroppedResult(
          paths: _items
              .map((item) => item?.path)
              .whereType<String>()
              .toList(growable: false),
          texts: _items
              .map((item) => item?.text)
              .whereType<String>()
              .toList(growable: false),
        ),
      );
    }
  }
}

class _DroppedItem {
  const _DroppedItem({this.path, this.text});

  final String? path;
  final String? text;
}

class _DroppedResult {
  const _DroppedResult({required this.paths, required this.texts});

  final List<String> paths;
  final List<String> texts;
}
