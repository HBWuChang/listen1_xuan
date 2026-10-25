import 'dart:io';

import 'package:path/path.dart' as p;

/// macOS bundles require their framework symlinks, permissions and signatures.
class MacosUpdater {
  static Future<void> _run(String executable, List<String> args) async {
    final result = await Process.run(executable, args);
    if (result.exitCode != 0) {
      throw StateError('$executable 失败 (${result.exitCode}): ${result.stderr}');
    }
  }

  /// Accept a release ZIP or an Actions artifact wrapping one release ZIP.
  static Future<String> extract(String zipPath, String outputPath) async {
    final output = Directory(outputPath);
    if (await output.exists()) await output.delete(recursive: true);
    await output.create(recursive: true);
    await _run('/usr/bin/ditto', ['-x', '-k', zipPath, outputPath]);
    var appPath = p.join(outputPath, 'listen1_xuan.app');
    if (!await Directory(appPath).exists()) {
      final innerZips = await output
          .list(recursive: true, followLinks: false)
          .where(
            (entry) =>
                entry is File &&
                p.extension(entry.path) == '.zip' &&
                !p
                    .split(p.relative(entry.path, from: outputPath))
                    .contains('__MACOSX'),
          )
          .toList();
      if (innerZips.length != 1) {
        throw StateError('安装包中未找到应用或唯一的 macOS ZIP');
      }
      final innerPath = p.join(outputPath, 'release');
      await Directory(innerPath).create();
      await _run('/usr/bin/ditto', [
        '-x',
        '-k',
        innerZips.single.path,
        innerPath,
      ]);
      appPath = p.join(innerPath, 'listen1_xuan.app');
    }
    await validate(appPath);
    return appPath;
  }

  static Future<void> validate(String appPath) async {
    for (final relative in [
      'Contents/Info.plist',
      'Contents/MacOS/listen1_xuan',
      'Contents/Frameworks/App.framework/App',
      'Contents/Frameworks/App.framework/Resources/Info.plist',
    ]) {
      if (!await File(p.join(appPath, relative)).exists()) {
        throw StateError('应用包不完整，缺少 $relative，请重新下载');
      }
    }
    if (!await Directory(
      p.join(
        appPath,
        'Contents/Frameworks/App.framework/Resources/flutter_assets',
      ),
    ).exists()) {
      throw StateError('应用包缺少 Flutter 启动资源，请重新下载');
    }
    await _run('/bin/test', [
      '-x',
      p.join(appPath, 'Contents/MacOS/listen1_xuan'),
    ]);
    await _run('/usr/bin/codesign', [
      '--verify',
      '--deep',
      '--strict',
      appPath,
    ]);
    final identifier = await Process.run('/usr/libexec/PlistBuddy', [
      '-c',
      'Print :CFBundleIdentifier',
      p.join(appPath, 'Contents/Info.plist'),
    ]);
    if (identifier.exitCode != 0 ||
        identifier.stdout.toString().trim() != 'com.xiebian.listen1Xuan') {
      throw StateError('安装包的应用标识不匹配');
    }
  }

  static String _quote(String value) => "'${value.replaceAll("'", "'\\''")}'";

  /// Stage on the target volume, then swap only after the running app exits.
  static String script({
    required String newAppPath,
    required String appPath,
    required int currentPid,
    required String readyPath,
  }) =>
      '''#!/bin/bash
set -euo pipefail
app_path=${_quote(appPath)}
new_app_path=${_quote(newAppPath)}
ready_path=${_quote(readyPath)}
current_pid=$currentPid
'''
      r'''
work_dir=''
installed=0
committed=0
cleanup() {
  status=$?
  trap - EXIT
  if [ "$committed" -eq 0 ] && [ -n "$work_dir" ] && [ -d "$work_dir/previous.app" ]; then
    if [ "$installed" -eq 1 ]; then /bin/rm -rf "$app_path"; fi
    /bin/mv "$work_dir/previous.app" "$app_path" || exit 1
  fi
  if [ -n "$work_dir" ]; then /bin/rm -rf "$work_dir"; fi
  /bin/rm -f "$ready_path"
  if [ "$status" -ne 0 ]; then
    echo "更新失败，旧版本已保留。请查看此日志。"
    /usr/bin/touch "${ready_path}.failed"
  fi
  exit "$status"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM
[ -d "$app_path/Contents" ]
[ -w "$(/usr/bin/dirname "$app_path")" ]
work_dir=$(/usr/bin/mktemp -d "${app_path}.update.XXXXXX")
/usr/bin/ditto "$new_app_path" "$work_dir/new.app"
[ -x "$work_dir/new.app/Contents/MacOS/listen1_xuan" ]
[ -f "$work_dir/new.app/Contents/Frameworks/App.framework/App" ]
[ -d "$work_dir/new.app/Contents/Frameworks/App.framework/Resources/flutter_assets" ]
/usr/bin/codesign --verify --deep --strict "$work_dir/new.app"
/usr/bin/touch "$ready_path"
echo "等待应用退出…"
count=0
while kill -0 "$current_pid" 2>/dev/null; do
  count=$((count + 1))
  [ "$count" -le 120 ] || exit 1
  /bin/sleep 1
done
/bin/mv "$app_path" "$work_dir/previous.app"
/bin/mv "$work_dir/new.app" "$app_path"
installed=1
/usr/bin/open "$app_path"
committed=1
echo "更新完成。"
''';

  static Future<void> start({
    required String tempPath,
    required String appPath,
    required String newAppPath,
  }) async {
    if (!p.isAbsolute(appPath) || !appPath.endsWith('.app')) {
      throw StateError('无法确定当前应用的安装位置');
    }
    await validate(newAppPath);
    final scriptPath = p.join(tempPath, 'update_macos.command');
    final logPath = p.join(tempPath, 'update_macos.log');
    final readyPath = p.join(
      tempPath,
      'update_macos_${DateTime.now().microsecondsSinceEpoch}.ready',
    );
    await File(scriptPath).writeAsString(
      script(
        newAppPath: newAppPath,
        appPath: appPath,
        currentPid: pid,
        readyPath: readyPath,
      ),
      flush: true,
    );
    await _run('/bin/chmod', ['+x', scriptPath]);
    // A detached shell survives app exit and does not ask Terminal to open a
    // document. All paths are positional arguments, never interpolated code.
    await Process.start('/bin/bash', [
      '-c',
      r'exec /bin/bash "$1" >"$2" 2>&1',
      'listen1-updater',
      scriptPath,
      logPath,
    ], mode: ProcessStartMode.detached);
    final ready = File(readyPath);
    for (var attempt = 0; attempt < 1200; attempt++) {
      if (await File('$readyPath.failed').exists()) {
        throw StateError('更新准备失败，应用保持运行。请查看 $logPath');
      }
      if (await ready.exists()) return;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    throw StateError(
      '更新程序未就绪，应用保持运行。请查看 $logPath；'
      '若安装位置不可写，请手动安装下载包。',
    );
  }
}
