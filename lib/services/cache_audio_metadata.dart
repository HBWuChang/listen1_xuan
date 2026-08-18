import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new_audio/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';
import 'package:path/path.dart' as p;

class CacheTrackMetadata {
  const CacheTrackMetadata({
    this.title,
    this.artist,
    this.album,
    this.albumArtist,
  });

  final String? title;
  final String? artist;
  final String? album;
  final String? albumArtist;
}

class CacheAudioMetadata {
  const CacheAudioMetadata();

  static const _maxErrorLength = 2000;

  Future<void> rewrite({
    required String inputPath,
    required String outputPath,
    required bool retainMetadata,
    CacheTrackMetadata? metadata,
    String? coverPath,
  }) async {
    final session = await _execute(
      buildArguments(
        inputPath: inputPath,
        outputPath: outputPath,
        retainMetadata: retainMetadata,
        metadata: metadata,
        coverPath: coverPath,
      ),
    );
    final returnCode = await session.getReturnCode();
    if (ReturnCode.isSuccess(returnCode)) {
      await validateAudioOutput(outputPath);
      return;
    }

    final output = await session.getOutput();
    throw CacheAudioMetadataException(_errorMessage(output));
  }

  static List<String> buildArguments({
    required String inputPath,
    required String outputPath,
    required bool retainMetadata,
    CacheTrackMetadata? metadata,
    String? coverPath,
  }) {
    final embedNewCover = shouldEmbedCover(
      retainMetadata: retainMetadata,
      outputPath: outputPath,
      coverPath: coverPath,
    );
    final preserveSourceCover =
        retainMetadata && !embedNewCover && supportsEmbeddedCover(outputPath);
    final arguments = <String>[
      '-hide_banner',
      '-nostdin',
      '-loglevel',
      'warning',
      '-i',
      inputPath,
      if (embedNewCover) ...['-i', coverPath!],
      '-map',
      '0:a:0',
      if (embedNewCover) ...['-map', '1:v:0'],
      if (preserveSourceCover) ...['-map', '0:v:0?'],
      '-c:a',
      'copy',
      if (embedNewCover) ...coverOutputArguments(),
      if (preserveSourceCover) ...['-c:v', 'copy'],
      ...outputMetadataArguments(
        retainMetadata: retainMetadata,
        metadata: metadata,
        outputPath: outputPath,
      ),
    ];

    if (p.extension(outputPath).toLowerCase() == '.mka') {
      arguments.addAll(['-f', 'matroska']);
    }
    arguments.addAll(['-y', outputPath]);
    return arguments;
  }

  static List<String> outputMetadataArguments({
    required bool retainMetadata,
    required String outputPath,
    CacheTrackMetadata? metadata,
  }) {
    final arguments = <String>[];
    if (retainMetadata) {
      arguments.addAll([
        '-map_metadata',
        '0',
        '-map_metadata:s:a:0',
        '0:s:a:0',
      ]);
      _addTrackMetadata(arguments, metadata, specifier: 'g');
      _addTrackMetadata(arguments, metadata, specifier: 's:a:0');
    } else {
      arguments.addAll([
        '-map_metadata',
        '-1',
        '-map_metadata:s:a',
        '-1',
        '-map_chapters',
        '-1',
        '-fflags',
        '+bitexact',
      ]);
    }

    if (p.extension(outputPath).toLowerCase() == '.mp3') {
      arguments.addAll(['-id3v2_version', '3']);
    }
    return arguments;
  }

  static bool supportsEmbeddedCover(String outputPath) {
    return const {
      '.mp3',
      '.m4a',
      '.mp4',
      '.mov',
      '.flac',
      '.mka',
      '.mkv',
    }.contains(p.extension(outputPath).toLowerCase());
  }

  static bool shouldEmbedCover({
    required bool retainMetadata,
    required String outputPath,
    String? coverPath,
  }) {
    return retainMetadata &&
        coverPath != null &&
        coverPath.trim().isNotEmpty &&
        supportsEmbeddedCover(outputPath);
  }

  static List<String> coverOutputArguments() {
    return const [
      '-c:v',
      'mjpeg',
      '-q:v',
      '2',
      '-disposition:v:0',
      'attached_pic',
      '-metadata:s:v:0',
      'title=Album cover',
      '-metadata:s:v:0',
      'comment=Cover (front)',
    ];
  }

  static Future<void> validateAudioOutput(String outputPath) async {
    final outputFile = File(outputPath);
    if (!await outputFile.exists() || await outputFile.length() == 0) {
      throw const CacheAudioMetadataException('缓存音频校验失败：输出文件为空');
    }

    final session = await FFprobeKit.getMediaInformation(outputPath);
    final information = session.getMediaInformation();
    final hasAudio =
        information?.getStreams().any(
          (stream) => stream.getType() == 'audio',
        ) ??
        false;
    final duration = double.tryParse(information?.getDuration() ?? '');
    if (hasAudio && (duration == null || duration > 0)) return;

    final output = await session.getOutput();
    final details = output?.trim() ?? '';
    throw CacheAudioMetadataException(
      details.isEmpty
          ? '缓存音频校验失败：未检测到有效音频流'
          : '缓存音频校验失败：未检测到有效音频流\n${_errorMessage(details)}',
    );
  }

  static String temporaryOutputPath(String targetPath) {
    final extension = p.extension(targetPath);
    if (extension.isEmpty) return '$targetPath.listen1-metadata.mka';
    return '${p.withoutExtension(targetPath)}.listen1-metadata$extension';
  }

  static String temporaryDownloadPath(String targetPath) {
    final extension = p.extension(targetPath);
    if (extension.isEmpty) return '$targetPath.listen1-download';
    return '${p.withoutExtension(targetPath)}.listen1-download$extension';
  }

  static String temporaryCoverPath(String targetPath) {
    final extension = p.extension(targetPath);
    if (extension.isEmpty) return '$targetPath.listen1-cover.image';
    return '${p.withoutExtension(targetPath)}.listen1-cover.image';
  }

  static Future<FFmpegSession> _execute(List<String> arguments) async {
    final completedSession = Completer<FFmpegSession>();
    await FFmpegKit.executeWithArgumentsAsync(arguments, (session) {
      if (!completedSession.isCompleted) completedSession.complete(session);
    });
    return completedSession.future;
  }

  static void _addTrackMetadata(
    List<String> arguments,
    CacheTrackMetadata? metadata, {
    required String specifier,
  }) {
    _addMetadata(arguments, 'title', metadata?.title, specifier: specifier);
    _addMetadata(arguments, 'artist', metadata?.artist, specifier: specifier);
    _addMetadata(arguments, 'album', metadata?.album, specifier: specifier);
    _addMetadata(
      arguments,
      'album_artist',
      metadata?.albumArtist,
      specifier: specifier,
    );
  }

  static void _addMetadata(
    List<String> arguments,
    String key,
    String? value, {
    required String specifier,
  }) {
    final normalized = value?.replaceAll('\u0000', '').trim() ?? '';
    if (normalized.isEmpty) return;
    arguments.addAll(['-metadata:$specifier', '$key=$normalized']);
  }

  static String _errorMessage(String? output) {
    final message = output?.trim() ?? '';
    if (message.isEmpty) return '缓存元数据处理失败';
    if (message.length <= _maxErrorLength) return message;
    return 'FFmpeg 输出过长，仅显示末尾：\n'
        '${message.substring(message.length - _maxErrorLength)}';
  }
}

class CacheAudioMetadataException implements Exception {
  const CacheAudioMetadataException(this.message);

  final String message;

  @override
  String toString() => message;
}
