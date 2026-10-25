# Release 安装说明自动生成

`scripts/release_notes.py` 从 Release 已上传资产生成下载表，使用 API 返回的真实链接和文件大小；不会修改安装包名称、构建 hash 或应用内更新逻辑。

推荐无 FFmpeg 精简版。Android 的 ARM64 设备推荐 ARM64 + 不内置 Cronet（需要可用的 Google Play 服务），使用粗体高亮，不使用 emoji。说明明确提醒 GitHub 相关功能可能出现问题，并不推荐多架构通用包。所有安装包均列出下载体积（MiB）和各自的提交 hash。

macOS 安装包按芯片拆分（`apple-silicon` 对应 Apple 芯片，`intel` 对应 Intel），资产名形如 `listen1_xuan-<version>-macos-apple-silicon-<hash>.zip`，含 FFmpeg 版在 hash 前多一段 `-ffmpeg`。Actions artifact 名同理（`macos-app-artifact-apple-silicon` 等）。标记故意不使用 `arm64` / `x86_64`：Android 端 artifact 选择按这两个子串过滤架构，否则会把 macOS 包也列出来。表格按芯片分行，拆分前上传的 universal 包自动归入“通用包（旧版）”行。

Android 同时发布 `app-…-<hash>.apk` 与同名 `app-…-<hash>.zip`。ZIP 采用 Deflate 压缩，内含原始已签名 APK；下载指南分别列出两种格式的链接及大小，ZIP 需解压后安装。应用内 Release 更新及 FFmpeg 切换优先选择同一构建的 ZIP，旧版仅有 APK 时仍可更新。

Android Actions artifact 使用 `app-…-release….zip` 名称并启用压缩，归档内直接包含 APK，避免嵌套 ZIP。客户端对同一 workflow run 的同名 APK / ZIP artifact 优先显示 ZIP，保留旧构建的兼容性。安装前解压成功即删除 ZIP，APK 留给系统安装器；手动安装包清理和旧 Release 缓存清理均覆盖 APK、ZIP 与未完成的解压文件，不删除其他平台压缩包。

## 自动刷新

将脚本及 `.github/workflows/release_notes.yml` 合入默认分支后，`apk`、`win`、`macos`、`ios` 构建工作流成功完成会触发刷新。无需修改现有构建工作流。

- 从触发工作流的 `head_sha` 对应的 `pubspec.yaml` 读取版本号，定位准确的 Release tag，不使用 latest，也不使用默认分支当前版本。
- 从目标 Release 分页读取所有已上传资产。各平台可以来自不同提交，每个包显示自己的 hash；未发布的变体显示“暂未发布”。macOS 按 `apple-silicon` / `intel` 分行，缺失芯片时给出提示。
- 相同 Release 的正文编辑串行执行；每次执行重新读取完整资产列表。多个平台先后完成会逐步补齐表格。
- 安装说明位于 `<!-- install-guide:start -->` 和 `<!-- install-guide:end -->` 之间；只替换此区域，区域外的手写更新日志保持原样。缺少整个区域时加在正文顶部，标记损坏时终止更新。
- 工作流使用默认分支的可信脚本，只把构建提交中的 pubspec 作为数据读取。更新任务需要 `contents: write` 权限。
- GitHub Actions 的 `workflow_run` 工作流必须存在于默认分支；可在 Actions 的 `Release installation guide` 中手动输入 tag 刷新已有 Release。

## 本地预览

需要 Python 3.9+；在线读取需要 GitHub CLI 已登录。

```bash
python3 scripts/release_notes.py --repo HBWuChang/listen1_xuan --tag '2.7.1+51' --output /tmp/release-notes.md
```

离线预览接受 GitHub REST API 的单个 Release JSON（包含 `body` 和 `assets`）：

```bash
python3 scripts/release_notes.py --release-json /tmp/release.json --output /tmp/release-notes.md
```

上述命令只读取和生成预览；显式添加 `--publish` 才会通过 API 更新在线正文。自动工作流会使用该参数。

```bash
python3 -m unittest discover -s scripts/tests -p 'test_release_notes.py'
```

手工编辑更新日志时，请在自动区域外编辑；资产被手动增删后可手动刷新。该工作流只负责安装说明，不解决现有构建流程在不同提交同时发布同一平台时的资产竞争。
