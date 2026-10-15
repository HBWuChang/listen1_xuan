import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart' hide Response;
import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../../controllers/routeController.dart';
import '../../global_settings_animations.dart';
import '../../services/feedback/feedback_api.dart';
import 'feedback_binding.dart';
import 'feedback_route_args.dart';
import 'feedback_route_observer.dart';
import 'feedback_controller.dart';
import '../../services/feedback/feedback_models.dart';
import '../../widgets/page_scroll_to_top.dart';

part 'feedback_issue_view.dart';
part 'feedback_participant_picker.dart';

String _time(DateTime? value) => value == null
    ? '暂无记录'
    : '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

Future<bool> _confirm(
  BuildContext context,
  String title,
  String message,
) async =>
    await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认'),
          ),
        ],
      ),
    ) ??
    false;

Widget _proBadge(BuildContext context) => TextButton(
  style: TextButton.styleFrom(
    minimumSize: const Size(28, 28),
    padding: const EdgeInsets.all(0),
  ),
  onPressed: () => showDialog<void>(
    context: context,
    useRootNavigator: false,
    builder: (context) => AlertDialog(
      title: const Text('P 标记'),
      content: const Text(
        'P 表示此用户已获授 Pro 资格，可使用部分受限的 Supabase 功能。此资格不包含在线反馈的管理权限。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('知道了'),
        ),
      ],
    ),
  ),
  child: const Text('P', style: TextStyle(fontWeight: FontWeight.bold)),
);

class FeedbackPage extends GetView<FeedbackController> {
  const FeedbackPage({super.key, required this.args});
  final FeedbackPageArgs args;
  @override
  String get tag => args.controllerTag;
  @override
  Widget build(BuildContext context) => _FeedbackRoutePage(args: args);
}

class FeedbackIssuePage extends GetView<FeedbackController> {
  const FeedbackIssuePage({super.key, required this.args});
  final FeedbackPageArgs args;
  @override
  String get tag => args.controllerTag;
  @override
  Widget build(BuildContext context) => _FeedbackRoutePage(args: args);
}

class FeedbackProfilePage extends GetView<FeedbackProfileController> {
  const FeedbackProfilePage({super.key, required this.args});
  final FeedbackPageArgs args;
  @override
  String get tag => args.controllerTag;
  @override
  Widget build(BuildContext context) => _FeedbackRoutePage(args: args);
}

class _FeedbackRoutePage extends StatefulWidget {
  const _FeedbackRoutePage({required this.args});
  final FeedbackPageArgs args;
  String get controllerTag => args.sourceControllerTag ?? args.controllerTag;
  @override
  State<_FeedbackRoutePage> createState() => _FeedbackRoutePageState();
}

class _FeedbackRoutePageState extends State<_FeedbackRoutePage>
    with RouteAware {
  FeedbackController get controller =>
      Get.find<FeedbackController>(tag: widget.controllerTag);
  final search = TextEditingController();
  final searchFocus = FocusNode();
  Timer? _searchTimer;
  bool get _working => controller.working;
  PageRoute<dynamic>? _route;

  @override
  void initState() {
    super.initState();
    searchFocus.addListener(_searchFocusChanged);
    if (widget.args.proApplication) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_openProApplication());
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic> && !identical(route, _route)) {
      feedbackRouteObserver.unsubscribe(this);
      _route = route;
      feedbackRouteObserver.subscribe(this, route);
    }
  }

  void _becameVisible() {
    if (controller.isClosed) return;
    controller.setRouteCovered(widget.args.kind == FeedbackPageKind.profile);
    controller.resume();
  }

  @override
  void didPush() => _becameVisible();
  @override
  void didPopNext() => _becameVisible();
  @override
  void didPushNext() {
    searchFocus.unfocus();
    controller.setRouteCovered(true);
    final next = top_routeWithName.isEmpty
        ? null
        : top_routeWithName.last.route.settings.arguments;
    final ownProfile =
        next is FeedbackPageArgs &&
        next.kind == FeedbackPageKind.profile &&
        next.sourceControllerTag == widget.controllerTag;
    if (!ownProfile) controller.suspend();
  }

  @override
  void didPop() {
    if (widget.args.kind == FeedbackPageKind.profile) {
      if (!controller.isClosed && controller.profileId == widget.args.userId)
        controller.closeProfile();
    } else {
      controller.suspend();
    }
  }

  void _searchFocusChanged() => setInAppHotKeyEnable(!searchFocus.hasFocus);
  @override
  void dispose() {
    _searchTimer?.cancel();
    searchFocus.dispose();
    setInAppHotKeyEnable(true);
    search.dispose();
    feedbackRouteObserver.unsubscribe(this);
    super.dispose();
  }

  void _back() => routerPop();

  Future<void> _openProApplication() => _run(() async {
    // This project's existing application issue and its administrator contact.
    const issueId = '0488a52a-db8f-4679-a8df-625d25fed7e7';
    const administratorId = '29588c6c-4d4e-4e94-a78f-1064ed9d4697';
    final api = controller.api;
    final issue = await api.issue(issueId);
    final profiles = await api.profiles([administratorId]);
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    final args = FeedbackPageArgs.messages(
      issue: issue,
      api: api,
      enableRealtime: controller.enableRealtime,
      initialText: '申请成为Pro用户',
      initialMentions: profiles,
    );
    // The issue owns its draft; returning to the list must not reopen it.
    unawaited(Get.toNamed(args.path, arguments: args, id: 1));
  });

  Future<void> _openIssueRoute(FeedbackIssue issue) async {
    final args = FeedbackPageArgs.messages(
      issue: issue,
      api: controller.api,
      enableRealtime: controller.enableRealtime,
    );
    await Get.toNamed(args.path, arguments: args, id: 1);
  }

  Future<void> _openProfileRoute(String userId) async {
    final args = FeedbackPageArgs.profile(
      sourceControllerTag: widget.controllerTag,
      userId: userId,
    );
    await Get.toNamed(args.path, arguments: args, id: 1);
  }

  Future<void> _run(Future<void> Function() work) async {
    final owner = controller;
    if (owner.working) return;
    owner.setWorking(true);
    try {
      await work();
    } catch (e) {
      if (mounted && !owner.isClosed) owner.report(e);
    } finally {
      if (!owner.isClosed) owner.setWorking(false);
    }
  }

  Future<void> _login() async {
    controller.suspend();
    await Get.toNamed(RouteName.supabaseLoginPage, id: 1);
    if (mounted) controller.resume();
  }

  Future<void> _pageSize() async {
    final text = TextEditingController(text: '${controller.pageSize}');
    final inputFocus = FocusNode();
    inputFocus.addListener(() => setInAppHotKeyEnable(!inputFocus.hasFocus));
    final value = await showDialog<int>(
      context: context,
      useRootNavigator: false,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('消息分页大小'),
          content: TextField(
            controller: text,
            focusNode: inputFocus,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => update(() {}),
            decoration: const InputDecoration(helperText: '1～114，默认 30，下次加载生效'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed:
                  (int.tryParse(text.text) ?? 0) >= 1 &&
                      (int.tryParse(text.text) ?? 115) <= 114
                  ? () => Navigator.pop(context, int.parse(text.text))
                  : null,
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    // A dialog's reverse transition may still be reading its controller.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    text.dispose();
    inputFocus.dispose();
    if (value != null && mounted) await controller.setPageSize(value);
  }

  Future<void> _edit({FeedbackIssue? issue}) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      useRootNavigator: false,
      builder: (context) => _IssueEditor(issue: issue),
    );
    if (!mounted || result == null) return;
    await _run(() async {
      final row = await controller.api.action(
        issue == null ? 'create' : 'edit',
        {if (issue != null) 'issue_id': issue.id, ...result},
      );
      if (!mounted) return;
      if (issue == null) {
        await _openIssueRoute(FeedbackIssue.fromJson(row));
      } else if (controller.issue?.id == issue.id) {
        controller.issue = FeedbackIssue.fromJson(row);
        await controller.refreshContext();
      }
    });
  }

  Widget _issues() => Column(
    children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Text('这里的反馈、讨论和个人页面资料对所有人公开，请勿发送隐私信息。'),
      ),
      Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          controller: search,
          focusNode: searchFocus,
          decoration: const InputDecoration(
            labelText: '搜索标题或问题描述',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (value) {
            _searchTimer?.cancel();
            _searchTimer = Timer(const Duration(milliseconds: 350), () {
              if (!mounted) return;
              controller.search = value;
              unawaited(controller.reloadIssues());
            });
          },
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Wrap(
          spacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilterChip(
              label: const Text('自己创建'),
              selected: controller.mine,
              onSelected: controller.permissions.userId == null
                  ? null
                  : (value) {
                      controller.mine = value;
                      unawaited(controller.reloadIssues());
                    },
            ),
            DropdownButton<String>(
              value: controller.sort,
              items: const [
                DropdownMenuItem(value: 'activity', child: Text('最近发言时间')),
                DropdownMenuItem(value: 'created', child: Text('创建时间')),
              ],
              onChanged: (value) {
                if (value != null) {
                  controller.sort = value;
                  unawaited(controller.reloadIssues());
                }
              },
            ),
            IconButton(
              tooltip: controller.ascending ? '升序' : '降序',
              onPressed: () {
                controller.ascending = !controller.ascending;
                unawaited(controller.reloadIssues());
              },
              icon: Icon(
                controller.ascending
                    ? Icons.arrow_upward
                    : Icons.arrow_downward,
              ),
            ),
          ],
        ),
      ),
      if (controller.listDirty)
        TextButton.icon(
          onPressed: () => controller.reloadIssues(),
          icon: const Icon(Icons.refresh),
          label: const Text('列表有更新，点击刷新'),
        ),
      if (controller.permissions.globalBanned)
        const Text('你已被全局禁言，仍可查看及管理已有问题。'),
      Expanded(
        child: controller.loading
            ? Center(child: globalLoadingAnime)
            : PageScrollToTop(
                superList: true,
                builder: (context, scroll, list) => RefreshIndicator.noSpinner(
                  onRefresh: () => controller.reloadIssues(),
                  child: SuperListView.builder(
                    controller: scroll,
                    listController: list,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: controller.issues.length + 1,
                    itemBuilder: (context, index) {
                      if (index == controller.issues.length) {
                        if (controller.issues.isEmpty)
                          return const Padding(
                            padding: EdgeInsets.all(36),
                            child: Center(child: Text('暂无问题')),
                          );
                        return _moreButton(
                          controller.hasMore,
                          controller.loadingMore,
                          () => controller.reloadIssues(more: true),
                        );
                      }
                      final issue = controller.issues[index];
                      return ListTile(
                        key: ValueKey(issue.id),
                        title: Text(issue.title),
                        subtitle: Text(
                          '${issue.statusLabel}${issue.locked ? ' · 讨论已锁定' : ''}\n${controller.name(issue.creatorId)} · 最近发言 ${_time(issue.lastMessageAt)}',
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          _searchTimer?.cancel();
                          searchFocus.unfocus();
                          unawaited(_openIssueRoute(issue));
                        },
                      );
                    },
                  ),
                ),
              ),
      ),
    ],
  );

  Widget _profile() {
    final id = widget.args.userId!;
    final profile = controller.profiles[id];
    final access = controller.profilePermissions;
    final issue = controller.issue;
    return SuperListView(
      children: [
        ListTile(
          title: Text(controller.name(id)),
          subtitle: SelectableText(id),
          trailing: profile?.isPro == true ? _proBadge(context) : null,
        ),
        ListTile(
          title: const Text('最后登录'),
          subtitle: Text(_time(profile?.lastLogin)),
        ),
        if (issue != null)
          ListTile(title: const Text('当前问题'), subtitle: Text(issue.title)),
        if (access.canManage && issue != null && !access.targetProtected)
          ListTile(
            title: Text(access.targetIssueBanned ? '解除当前问题内禁言' : '在当前问题内禁言'),
            trailing: const Icon(Icons.voice_over_off),
            enabled: !_working,
            onTap: () => _manage(
              'ban',
              {
                'issue_id': issue.id,
                'user_id': id,
                'banned': !access.targetIssueBanned,
              },
              '${access.targetIssueBanned ? '解除' : '设置'} ${controller.name(id)} 在“${issue.title}”内的禁言？',
            ),
          ),
        if (access.isAdmin && id != access.userId) ...[
          if (access.canGlobalBan)
            ListTile(
              title: Text(access.targetGlobalBanned ? '解除全局禁言' : '全局禁言'),
              enabled: !_working,
              subtitle: const Text('全局禁言会禁止创建问题和在所有问题中发言'),
              onTap: () => _manage(
                'ban',
                {'user_id': id, 'banned': !access.targetGlobalBanned},
                '${access.targetGlobalBanned ? '解除' : '设置'} ${controller.name(id)} 的全局禁言？',
              ),
            ),
          if (profile != null)
            ListTile(
              title: Text(profile.isPro ? '取消 Pro' : '授予 Pro'),
              enabled: !_working,
              subtitle: const Text('不会改变聊天管理权限'),
              onTap: () => _manage(
                'pro',
                {'user_id': id, 'is_pro': !profile.isPro},
                '${controller.name(id)}\nPro：${profile.isPro ? '开启 → 关闭' : '关闭 → 开启'}',
              ),
            ),
        ],
      ],
    );
  }

  Future<void> _manage(
    String action,
    Map<String, dynamic> data,
    String message,
  ) async {
    if (!await _confirm(context, '确认操作', message) || !mounted) return;
    await _run(() async {
      await controller.api.action(action, data);
      if (!mounted || controller.profileId == null) return;
      await controller.openProfile(controller.profileId!);
    });
  }

  @override
  Widget build(BuildContext context) => GetBuilder<FeedbackController>(
    tag: widget.controllerTag,
    autoRemove: false,
    builder: (controller) {
      final inDetail = widget.args.kind == FeedbackPageKind.messages;
      final inProfile = widget.args.kind == FeedbackPageKind.profile;
      return Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: _back),
          title: Text(
            inProfile
                ? '个人页面'
                : inDetail
                ? '问题讨论'
                : '在线反馈',
          ),
          actions: [
            Icon(
              controller.connected
                  ? Icons.cloud_done_outlined
                  : Icons.cloud_off_outlined,
              size: 20,
            ),
            IconButton(
              tooltip: '刷新 / 重试连接',
              onPressed: () => controller.reconnect(),
              icon: const Icon(Icons.refresh),
            ),
            if (inDetail && !inProfile && controller.permissions.canManage)
              IconButton(
                tooltip: '管理问题',
                onPressed: _working
                    ? null
                    : () => _edit(issue: controller.issue),
                icon: const Icon(Icons.edit_outlined),
              ),
          ],
        ),
        body: Column(
          children: [
            if (controller.error != null)
              Material(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Expanded(child: Text(controller.error!)),
                      TextButton(
                        onPressed: () => controller.reload(),
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                ),
              ),
            if (_working)
              Center(
                child: SizedBox.square(
                  dimension: 24,
                  child: FittedBox(child: globalLoadingAnime),
                ),
              ),
            Expanded(
              child: inProfile
                  ? _profile()
                  : inDetail
                  ? _FeedbackIssueView(
                      key: ValueKey(controller.issue!.id),
                      controller: controller,
                      initialText: widget.args.initialText,
                      initialMentions: widget.args.initialMentions,
                      onLogin: _login,
                      onOpenProfile: _openProfileRoute,
                    )
                  : _issues(),
            ),
          ],
        ),
      );
    },
  );
}

Widget _moreButton(bool hasMore, bool loading, VoidCallback load) => Padding(
  padding: const EdgeInsets.all(12),
  child: Center(
    child: loading
        ? globalLoadingAnime
        : hasMore
        ? TextButton(onPressed: load, child: const Text('加载更多'))
        : const Text('已全部加载'),
  ),
);

class _IssueEditor extends StatefulWidget {
  const _IssueEditor({this.issue});
  final FeedbackIssue? issue;
  @override
  State<_IssueEditor> createState() => _IssueEditorState();
}

class _IssueEditorState extends State<_IssueEditor> {
  final form = GlobalKey<FormState>();
  late final TextEditingController title, description;
  late String status;
  late bool locked;
  @override
  void initState() {
    super.initState();
    title = TextEditingController(text: widget.issue?.title);
    description = TextEditingController(text: widget.issue?.description);
    status = widget.issue?.status ?? 'open';
    locked = widget.issue?.locked ?? false;
    setInAppHotKeyEnable(false);
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    setInAppHotKeyEnable(true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.issue == null ? '创建问题' : '管理问题'),
    content: SizedBox(
      width: 520,
      child: Form(
        key: form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: title,
                maxLength: 100,
                decoration: const InputDecoration(labelText: '标题'),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? '请填写标题' : null,
              ),
              TextFormField(
                controller: description,
                maxLength: 1000,
                minLines: 3,
                maxLines: 8,
                decoration: const InputDecoration(labelText: '问题描述'),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? '请填写问题描述' : null,
              ),
              if (widget.issue != null) ...[
                DropdownButtonFormField<String>(
                  initialValue: status,
                  items: const [
                    DropdownMenuItem(value: 'open', child: Text('开启')),
                    DropdownMenuItem(value: 'declined', child: Text('不予处理')),
                    DropdownMenuItem(value: 'completed', child: Text('已完成')),
                  ],
                  onChanged: (value) {
                    if (value != null) status = value;
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('锁定讨论'),
                  subtitle: const Text('仅创建者可发言'),
                  value: locked,
                  onChanged: (value) => setState(() => locked = value),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () {
          if (form.currentState!.validate()) {
            Navigator.pop(context, {
              'title': title.text,
              'description': description.text,
              'status': status,
              'locked': locked,
            });
          }
        },
        child: const Text('保存'),
      ),
    ],
  );
}
