import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Shared, short-lived cache for a Markdown document from the main branch.
class RepositoryDocument extends ChangeNotifier {
  RepositoryDocument({required this.dio, required this.filename});

  final Dio dio;
  final String filename;
  static const _repository = 'HBWuChang/listen1_xuan';
  static const cacheDuration = Duration(minutes: 10);

  Uri get sourceUri =>
      Uri.parse('https://github.com/$_repository/blob/main/$filename');
  String get imageDirectory =>
      'https://raw.githubusercontent.com/$_repository/main/';

  String? content;
  String? error;
  bool loading = false;
  DateTime? _loadedAt;
  Future<void>? _pending;

  Future<void> load({bool force = false}) {
    if (_pending != null) return _pending!;
    if (!force &&
        content != null &&
        _loadedAt != null &&
        DateTime.now().difference(_loadedAt!) < cacheDuration) {
      return Future.value();
    }
    loading = true;
    error = null;
    // Assign before notifying, so listeners also share the pending request.
    _pending = _fetch();
    notifyListeners();
    return _pending!;
  }

  Future<void> _fetch() async {
    try {
      content = await _download();
      _loadedAt = DateTime.now();
    } catch (_) {
      error = content == null ? '加载失败，请检查网络后重试' : '刷新失败，当前显示上次加载的内容';
    } finally {
      loading = false;
      _pending = null;
      notifyListeners();
    }
  }

  Future<String> _download() async {
    final urls = [
      '$imageDirectory$filename',
      'https://api.github.com/repos/$_repository/contents/$filename?ref=main',
    ];
    for (final url in urls) {
      final cancelToken = CancelToken();
      try {
        final response = await dio
            .get<String>(
              url,
              cancelToken: cancelToken,
              options: Options(
                responseType: ResponseType.plain,
                sendTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 10),
                headers: {'Accept': 'application/vnd.github.raw+json'},
              ),
            )
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                cancelToken.cancel('Document request timed out');
                throw StateError('Document request timed out');
              },
            );
        final text = response.data;
        if (response.statusCode == 200 &&
            text != null &&
            text.trim().isNotEmpty &&
            !RegExp(
              r'^\s*(<!doctype html|<html)',
              caseSensitive: false,
            ).hasMatch(text)) {
          return text;
        }
      } catch (_) {
        // Try the alternate GitHub endpoint before reporting failure.
      }
    }
    throw StateError('Unable to load $filename');
  }
}
