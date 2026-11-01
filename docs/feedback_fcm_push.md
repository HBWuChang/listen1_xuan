# Android 在线反馈 FCM 推送

## 配置与入口

Firebase Android 应用包名为 `com.xiebian.listen1_xuan`。客户端下载的 `google-services.json` 放在 `android/app/google-services.json`，Gradle 在文件存在时应用 Google Services 插件；未配置时应用仍可启动，反馈推送不能开启。该文件已加入 Git 忽略。

服务账号 JSON 仅放在 Supabase Edge Function Secret `FCM_SERVICE_ACCOUNT_JSON`，项目 ID 必须与 Android 配置一致。服务账号应具备目标 Firebase 项目的 FCM 发送权限，并开启 Firebase Cloud Messaging API V1。私钥不得放进 Dart、APK、迁移或 Git；部署脚本与文档都不包含私钥。更换 Secret 后无需修改客户端代码。

本次已配置 Firebase 项目 `listen1-xuan`，Android 配置与服务端项目一致，Secret 已通过 CLI 写入。Google OAuth 与 FCM V1 测试令牌校验已验证，Vault → pg_net → Edge Function → Google OAuth → 空任务领取也已实际返回 HTTP 200。实际收件需要应用在具备可用 Google Play 服务及相应网络连接的 Android 设备上注册。

在设置中登录 Supabase 后开启“反馈消息推送”，首次开启会申请系统通知权限。默认关闭，问题级接收规则继续使用既有“未设置／展示／不展示”。iOS、macOS、Windows 和 Web 不启用这条通知链路；Firebase Flutter 依赖固定在兼容现有 iOS 14 部署目标的版本，没有提高项目最低系统版本。

## 客户端

- `FeedbackPushController` 管理设备注册、令牌更新、账号切换及关闭推送。关闭或退出账号会撤销当前设备绑定，其他设备不受影响。
- 安装标识与撤销凭据存储在 Android `noBackupFilesDir`，避免恢复备份时把另一台设备的身份复制过来。服务器只保存撤销凭据的 SHA-256；匿名撤销接口只能凭该随机凭据停用同一设备，不能注册、读取资料或操作其他设备。
- 注册和撤销串行执行；旧账号的在途注册完成后，会按最新登录状态重新解绑或绑定。暂时失败时在前台重试，回前台时重新检查系统权限。
- 后台通知由 FCM 的 notification payload 显示，不启动 Dart 聊天订阅或加载消息。前台由原生 Android 通知接口显示，没有额外引入本地通知 Flutter 插件；正在查看相应问题时不额外弹系统通知。
- 系统通知按问题使用同一 tag，连续通知覆盖同一条；前台重复事件使用“接收者＋问题＋消息”去重。其他账号的通知不会在前台显示。
- 本设备收到已读状态更新时清除对应反馈通知。其他设备已读后，尚未发送的任务会取消；已由 FCM 接收或已显示的系统通知无法保证立即撤回，本设备回到前台同步后会清理。

## 点击路由

通知仅接受 `kind=feedback_message`、合法 UUID 的 `issue_id`、`user_id` 和正整数 `message_id`，不接受通知提供的任意页面或网址。

冷启动使用 FCM `getInitialMessage`，后台唤起使用 `onMessageOpenedApp`；前台原生通知点击也统一交给 `FeedbackPushNavigationController`。目标先暂存，等待 Supabase 会话恢复、主界面的内部 Navigator(id: 1) 就绪以及前台弹窗关闭，再执行跳转。同一通知的重复回调不会重复打开页面。

未登录时先进入现有登录页面，登录到目标账号后继续；已登录另一个账号时提示账号不匹配，不自动切换账号或清除别人的未读。点击后打开真实的在线反馈列表路由，再自动加载并进入问题，返回可回到问题列表。已经位于同一问题时保留当前页面和草稿，刷新并标记已加载消息已读。

问题加载失败保留列表中的错误及重试入口，不仅凭点击通知就清除服务端未读。通过通知进入聊天后的已读时机沿用现有逻辑。

## 数据库与发送端

`feedback_private.push_devices` 保存私有设备绑定，`feedback_private.push_jobs` 保存不含消息正文的发送任务。两表开启 RLS，普通 API 角色没有读写权限；设备注册只允许当前登录用户，任务领取、投递检查和回执只授权 service_role。

1. 现有新消息事务更新接收者的 `last_notified_id`。
2. 触发器为已开启推送的设备插入任务，`installation_id + message_id` 唯一约束防止幂等发送重复入队。注册设备不会追溯旧未读消息。
3. `pg_net` 在事务提交后唤醒 `feedback-push` Edge Function；每分钟 Cron 补偿失败或遗漏的唤醒。没有待发送任务时不调用 Edge Function。
4. Edge Function 先用 Vault 中的独立随机凭据验证请求，再用 Secret 中的服务账号生成短期 Google OAuth 令牌。Endpoint 的 JWT 校验关闭是因为它使用自己的服务间鉴权，普通客户端不能领取任务。
5. 使用 SKIP LOCKED 批量领取、五分钟租约和独立 lease token，防止多个 worker 同时领取以及旧 worker 回执覆盖新租约。最多尝试五次，临时错误指数退避。
6. 投递前再次核对账号绑定、设备启用、问题偏好、已读位置、消息撤回、Firebase 项目及任务有效期。积压任务按每个问题最新的通知消息合并；旧任务取消。
7. FCM 返回 UNREGISTERED 时只停用当时失败的 token，令牌已更新时不会误停用新 token。任务有效期 24 小时，设备超过 90 天未注册则不再投递，终态任务保留七天。

Vault 调度凭据不写入迁移文件。全新项目应调整迁移中的 Edge Function 项目 URL；在当前项目上不要重新执行已应用的迁移。

## 验证

- `supabase/tests/feedback_fcm_push.sql`：真实角色与事务回滚测试，覆盖接收者入队、幂等、已读／静音／解绑取消投递、令牌更新、账号切换、旧租约隔离、最大重试次数、任务过期与 worker 权限隔离。
- `test/feedback_push_test.dart`：点击等待与去重、账号校验、登录后继续、缺少配置、通知权限、注册更新、在途账号切换、前台显示过滤。
- `test/feedback_unread_test.dart`：既有未读状态与已读边界回归。
- `node --experimental-strip-types --test supabase/functions/feedback-push/worker_test.mjs`：发送函数鉴权、OAuth 签名、FCM 请求、取消、失效 token、临时失败和项目匹配。

官方参考：[Android 配置](https://firebase.google.com/docs/android/setup)、[服务账号](https://firebase.google.com/docs/admin/setup)、[Flutter 接收与点击事件](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages)、[Supabase 定时 Edge Function](https://supabase.com/docs/guides/functions/schedule-functions)。

安全顾问中，私有设备和任务表的“RLS 无策略”提示是预期的全拒绝设计；客户端无 schema/table 权限，只能调用窄接口。设备注册和凭随机安装凭据撤销的 SECURITY DEFINER 提示也是有意授权，角色隔离及凭据校验已在回滚测试中验证。[RLS 提示说明](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy)、[匿名函数提示说明](https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable)。既有项目的其他提示未在此次改动中调整。

本次验证结果：19 项 Flutter 测试、8 项发送端测试及两套数据库回滚测试通过；Android ARM64 调试 APK 构建并保留数据更新安装成功。已在当前连接的真机确认 FCM 后台收件、结束应用进程后的收件，以及这两类通知点击均进入指定问题；前台其他页面显示系统通知也已确认。真机测试仅发往本设备，未创建聊天室消息，未通知其他用户。用户已自行开启该设备的反馈消息推送。

前台通知点击后的原生回调也已在同一真机确认，能进入指定问题页面。

## GitHub Actions

Android 工作流 `.github/workflows/dart.yml` 使用仓库 Actions Secret `GOOGLE_SERVICES_JSON_B64`，内容为 Android 客户端 `google-services.json` 的完整 Base64 编码。它不是服务账号 JSON；`FCM_SERVICE_ACCOUNT_JSON` 继续仅放在 Supabase，不需要上传到 GitHub。

每个构建矩阵任务在 checkout 后运行 `scripts/restore_android_firebase.py`，先校验 Firebase 项目、Android 包名、应用 ID 和 API key，再还原到 `android/app/google-services.json`。缺少或错误的 Secret 会立即给出错误，避免发布一个没有 Firebase 配置的正式包。脚本不会输出配置内容。

原有签名继续使用 `KEYSTORE_BASE64`、`KEYSTORE_PASSWORD`、`KEY_ALIAS` 和 `KEY_PASSWORD`。新增 Firebase 配置不替换已有签名身份。支持手动运行 Android workflow；手动运行只生成 artifacts，既有 push 发布流程保持不变。

本地校验：`python3 -m unittest discover -s scripts/tests -p test_restore_android_firebase.py`、`actionlint .github/workflows/dart.yml`。真正的远端构建仍需把工作流及相应应用代码提交到目标分支后执行。

已向 `HBWuChang/listen1_xuan` 上传并确认 `GOOGLE_SERVICES_JSON_B64`，原有四个 Android 签名 Secrets 均存在。GitHub MCP 连接当时尚未就绪，因此实际通过本机已有 GitHub 认证和 GitHub CLI 完成上传；没有复制服务端私钥，也没有替换既有签名 Secrets。

CI 接入已通过 5 项脚本测试、真实配置还原、FFmpeg 两种模式依赖保留检查及 Actionlint。当前应用 ARM64 Release 构建通过，已确认压缩后的 APK 中保留 `google_app_id`、`gcm_defaultSenderId` 和 `google_api_key` 资源。上述结果不等同于尚未运行的远端 Actions 构建。
