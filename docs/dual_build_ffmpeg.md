# 双版本构建（带 / 不带 FFmpeg）

## 背景

「缓存保留元数据」和「Bilibili 转码为 MP3」功能依赖 FFmpeg，会显著增大安装包。
因此项目支持两种构建变体：

| 变体 | FFmpeg | 功能 | 安装包 |
|---|---|---|---|
| `with`（默认） | 线上包 `ffmpeg_kit_flutter_new_audio ^2.5.2` | bilibili 转 mp3、缓存元数据写入、缓存路径 | 较大 |
| `without`（精简版） | 无（本地 stub 包） | 仅缓存路径；bilibili 直接下载原始格式；不写入元数据 | 明显更小 |

## 用法

`scripts/build.sh` 是**纯配置切换脚本**（不执行平台构建），只负责切换
pubspec 依赖并执行 `flutter pub get`：

```bash
# 切到带 FFmpeg 配置（线上包，默认）
scripts/build.sh with

# 切到无 FFmpeg 配置（stub 包 override）
scripts/build.sh without

# 查看当前模式与 ENABLE_FFMPEG 值
scripts/build.sh check

# CI 中 workflow 已有 pub get 步骤时，可跳过：
scripts/build.sh without --no-pub-get
```

切换配置后，用各平台原有命令构建，并同步注入开关：

```bash
# 精简版 APK 示例
scripts/build.sh without
flutter build apk --release --dart-define=ENABLE_FFMPEG=false

# 带 FFmpeg 的 iOS 示例（CI 用法一致）
scripts/build.sh with
cd ios && pod install
flutter build ios --release --no-codesign --dart-define=gitHash=xxxx \
  --dart-define=ENABLE_FFMPEG=true

# macOS 使用 fastforge 发布链路：
scripts/build.sh without   # 或 with
fastforge release --name prod   # 需在 fastforge 配置中注入 ENABLE_FFMPEG
```

脚本行为：
1. 按变体切换 `pubspec.yaml`（`without` 时注入 `dependency_overrides`
   指向本地 stub 包；`with` 时移除残留 override，幂等）
2. 执行 `flutter pub get`（可 `--no-pub-get` 跳过）
3. **切换成功后配置保持生效**，直到下次切换；命令中途失败（pub get
   报错 / Ctrl-C / CI 取消）会自动回滚到进入前状态

> ⚠️ 切换后请勿再执行 `flutter pub get`，否则会按当前 pubspec 重新解析
> 依赖（`without` 状态会被还原成线上包）。构建直接用 `flutter build`。

## 工作原理

- **功能开关**：`lib/services/ffmpeg_config.dart` 读取编译期常量
  `ENABLE_FFMPEG`（默认 true）。构建时必须与配置切换同步注入
  `--dart-define=ENABLE_FFMPEG=true|false`，保证两变体一致（用
  `scripts/build.sh check` 查看当前应注入的值）。
- **stub 包**：`packages/ffmpeg_kit_flutter_new_audio/` 是与线上包同名的
  纯 Dart 包（无任何原生平台代码），API 签名对齐线上 2.5.2，实现全部为
  no-op。仅当 `dependency_overrides` 指向它时才会被解析，因此精简版
  **不会打包任何 FFmpeg 原生库**。
- **运行时短路**：`CacheController` 在 `isFfmpegEnabled == false` 时跳过
  转码与元数据写入（直接落盘）；设置页隐藏「缓存保留元数据」开关。

## CI（GitHub Actions）

- **正式版（with）**：现有 workflow **零改动**——`pubspec.yaml` 默认就是
  带 FFmpeg 的线上包，`flutter pub get` + `flutter build` 直接产出完整版。
- **精简版（without）**（可选）：在 workflow 的 `flutter pub get` 之前插入
  一行 `scripts/build.sh without`，构建命令追加
  `--dart-define=ENABLE_FFMPEG=false`；可用 `workflow_dispatch` 的 input
  控制 `with|without`。

## 注意事项

1. 脚本切换会改写本地 `pubspec.yaml` 与 `pubspec.lock`；切换成功后配置
   保持生效，请勿中途手动改回或再次 `flutter pub get`。
2. 精简版 bilibili 缓存文件使用 URL 实际扩展名（非 `.mp3`）。
3. 若线上包 `ffmpeg_kit_flutter_new_audio` 升级，需同步检查 stub 包 API
   签名（stub 文件头部已标注对应版本）。
4. CI 默认构建带 FFmpeg 版本（提交信息含 `apk`/`ios`/`macos`/`win`
   关键字触发）；精简版请在本机或用 `workflow_dispatch` 手动构建。
