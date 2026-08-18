# 双版本构建（带 / 不带 FFmpeg）

## 背景

「缓存保留元数据」和「Bilibili 转码为 MP3」功能依赖 FFmpeg，会显著增大安装包。
因此项目支持两种构建变体：

| 变体 | FFmpeg | 功能 | 安装包 |
|---|---|---|---|
| `with`（默认） | 线上包 `ffmpeg_kit_flutter_new_audio ^2.5.2` | bilibili 转 mp3、缓存元数据写入、缓存路径 | 较大 |
| `without`（精简版） | 无（本地 stub 包） | 仅缓存路径；bilibili 直接下载原始格式；不写入元数据 | 明显更小 |

## 用法

```bash
# 带 FFmpeg（默认）构建 release APK
scripts/build.sh with apk

# 精简版（无 FFmpeg）构建
scripts/build.sh without apk

# 其他平台
scripts/build.sh with windows
scripts/build.sh without ios
scripts/build.sh with split          # apk --split-per-abi
scripts/build.sh without apk --debug # 自定义构建参数

# macOS 使用 fastforge 发布链路，脚本仅负责切换 pubspec：
scripts/build.sh without macos-prepare   # 切换后手动执行 fastforge release --name prod
```

脚本会自动：
1. 按变体切换 `pubspec.yaml`（`without` 时注入 `dependency_overrides` 指向本地 stub 包）
2. 执行 `flutter pub get`
3. 以 `--dart-define=ENABLE_FFMPEG=true|false` 构建
4. 构建结束（含 Ctrl-C/CI 取消）后**自动还原 pubspec.yaml**

## 工作原理

- **功能开关**：`lib/services/ffmpeg_config.dart` 读取编译期常量
  `ENABLE_FFMPEG`（默认 true）。构建脚本与依赖切换同步注入，保证两变体一致。
- **stub 包**：`packages/ffmpeg_kit_flutter_new_audio/` 是与线上包同名的
  纯 Dart 包（无任何原生平台代码），API 签名对齐线上 2.5.2，实现全部为
  no-op。仅当 `dependency_overrides` 指向它时才会被解析，因此精简版
  **不会打包任何 FFmpeg 原生库**。
- **运行时短路**：`CacheController` 在 `isFfmpegEnabled == false` 时跳过
  转码与元数据写入（直接落盘）；设置页隐藏「缓存保留元数据」开关。

## 注意事项

1. `without` 变体构建会改写本地 `pubspec.yaml` 与 `pubspec.lock`，构建后
   自动还原；请勿在构建中途手动修改 pubspec。
2. 精简版 bilibili 缓存文件使用 URL 实际扩展名（非 `.mp3`）。
3. 若线上包 `ffmpeg_kit_flutter_new_audio` 升级，需同步检查 stub 包 API
   签名（stub 文件头部已标注对应版本）。
4. CI（`.github/workflows/*.yml`）默认构建带 FFmpeg 版本（提交信息含
   `apk`/`ios`/`macos`/`win` 关键字触发）；精简版请在本机或用
   `workflow_dispatch` 手动构建。
