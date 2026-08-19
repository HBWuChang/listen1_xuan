import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

Future<Set<String>> listExistingCacheFileNames(Directory directory) async {
  final fileNames = <String>{};
  if (!await directory.exists()) return fileNames;

  await for (final entity in directory.list(followLinks: false)) {
    if (entity is File) fileNames.add(p.basename(entity.path));
  }
  return fileNames;
}

String deduplicateCacheFileName({
  required String baseName,
  required String extension,
  required Set<String> existingFileNames,
  required bool useNumberSuffix,
  required String separator,
  String Function()? createRandomSuffix,
}) {
  bool exists(String candidate) =>
      existingFileNames.any((fileName) => p.equals(fileName, candidate));

  final originalName = '$baseName$extension';
  if (!exists(originalName)) return originalName;

  if (useNumberSuffix) {
    var count = 1;
    while (exists('$baseName($count)$extension')) {
      count++;
    }
    return '$baseName($count)$extension';
  }

  final makeSuffix = createRandomSuffix ?? _randomSuffix;
  while (true) {
    final candidate = '$baseName$separator${makeSuffix()}$extension';
    if (!exists(candidate)) return candidate;
  }
}

String _randomSuffix() {
  const characters = '0123456789abcdefghijklmnopqrstuvwxyz';
  final random = Random.secure();
  return List.generate(
    6,
    (_) => characters[random.nextInt(characters.length)],
  ).join();
}
