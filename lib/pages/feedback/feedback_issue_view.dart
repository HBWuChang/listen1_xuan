part of 'feedback_page.dart';

class _FeedbackIssueView extends StatefulWidget {
  const _FeedbackIssueView({
    super.key,
    required this.controller,
    this.initialText = '',
    this.initialMentions = const [],
    required this.onLogin,
    required this.onOpenProfile,
  });
  final FeedbackController controller;
  final String initialText;
  final List<FeedbackProfile> initialMentions;
  final Future<void> Function() onLogin;
  final Future<void> Function(String) onOpenProfile;
  @override
  State<_FeedbackIssueView> createState() => _FeedbackIssueViewState();
}

class _FeedbackIssueViewState extends State<_FeedbackIssueView> {
  FeedbackController get c => widget.controller;
  final scroll = ScrollController();
  final list = ListController();
  final text = TextEditingController();
  final focus = FocusNode();
  final mentions = <String>{};
  bool mentionAll = false, sending = false;
  int? replyTo, _latestId;
  final _messageKeys = <int, GlobalKey>{};
  List<int> _renderedIds = [];
  bool _anchorPending = false;
  String? _clientId, _retryFingerprint;

  @override
  void initState() {
    super.initState();
    text.text = widget.initialText;
    text.selection = TextSelection.collapsed(offset: text.text.length);
    for (final profile in widget.initialMentions) {
      mentions.add(profile.id);
      c.profiles[profile.id] = profile;
    }
    c.addListener(_changed);
    scroll.addListener(_scroll);
    focus.addListener(_focusChanged);
  }

  void _focusChanged() => setInAppHotKeyEnable(!focus.hasFocus);
  @override
  void dispose() {
    c.removeListener(_changed);
    scroll.removeListener(_scroll);
    scroll.dispose();
    list.dispose();
    text.dispose();
    focus.dispose();
    setInAppHotKeyEnable(true);
    super.dispose();
  }

  void _changed() {
    if (c.routeCovered && focus.hasFocus) focus.unfocus();
    if (!c.atLatest && !c.jumping) _preserveAnchor();
    final latest = c.messages.firstOrNull?.id;
    if (latest != null && latest != _latestId) {
      final follow = c.atLatest;
      _latestId = latest;
      if (follow && !c.routeCovered && !c.jumping) _latest();
    }
  }

  void _preserveAnchor() {
    if (_anchorPending || !list.isAttached || !scroll.hasClients) return;
    final range = list.visibleRange;
    if (range == null || _renderedIds.isEmpty) return;
    final index = ((range.$1 + range.$2) ~/ 2).clamp(
      0,
      _renderedIds.length - 1,
    );
    final key = _messageKeys[_renderedIds[index]];
    final box = key?.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached) return;
    final previousY = box.localToGlobal(Offset.zero).dy;
    _anchorPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _anchorPending = false;
      if (!mounted || !scroll.hasClients || c.jumping) return;
      final current = key?.currentContext?.findRenderObject();
      if (current is! RenderBox || !current.attached) return;
      // The viewport is reversed: increasing pixels moves an item downward.
      final delta = previousY - current.localToGlobal(Offset.zero).dy;
      if (delta.abs() > 0.5) {
        scroll.jumpTo(
          (scroll.offset + delta).clamp(
            scroll.position.minScrollExtent,
            scroll.position.maxScrollExtent,
          ),
        );
      }
    });
  }

  void _scroll() {
    if (!scroll.hasClients || c.routeCovered) return;
    c.markLatest(scroll.offset <= 60);
    if (scroll.position.maxScrollExtent - scroll.offset < 180 && !c.jumping)
      unawaited(c.older());
  }

  void _latest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !scroll.hasClients || c.routeCovered) return;
      unawaited(
        scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        ),
      );
      c.markLatest(true);
    });
  }

  Future<void> _send() async {
    if (sending ||
        text.text.trim().isEmpty ||
        text.text.characters.length > 1000 ||
        !c.permissions.canSend(c.issue!))
      return;
    final body = text.text;
    final selected = mentions.toList()..sort();
    final fingerprint =
        '$body\u0000${selected.join(',')}\u0000$mentionAll\u0000$replyTo';
    if (_retryFingerprint != fingerprint) {
      _clientId = const Uuid().v4();
      _retryFingerprint = fingerprint;
    }
    setState(() => sending = true);
    try {
      await c.sendMessage({
        'body': body,
        'mentions': selected,
        'mention_all': mentionAll,
        'reply_to': replyTo,
        'client_id': _clientId,
      });
      if (!mounted) return;
      text.clear();
      mentions.clear();
      mentionAll = false;
      replyTo = null;
      _clientId = null;
      _retryFingerprint = null;
      _latest();
    } catch (error) {
      if (mounted) c.report(error);
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _chooseMentions() async {
    final result = await showDialog<_MentionSelection>(
      context: context,
      useRootNavigator: false,
      builder: (context) => _FeedbackParticipantPicker(
        api: c.api,
        issueId: c.issue!.id,
        selected: mentions,
        all: mentionAll,
      ),
    );
    if (!mounted || result == null) return;
    for (final profile in result.profiles) {
      c.profiles[profile.id] = profile;
    }
    setState(() {
      mentions.clear();
      mentions.addAll(result.ids);
      mentionAll = result.all;
    });
  }

  Future<void> _jump(int id) async {
    final ready = await c.loadToReply(id);
    if (!mounted || !ready || !list.isAttached || !scroll.hasClients) return;
    c.markLatest(false);
    await list.animateToItem(
      index: () {
        if (!mounted || !list.isAttached) return null;
        final index = c.messages.indexWhere((message) => message.id == id);
        return index < 0 ? null : index;
      },
      scrollController: scroll,
      alignment: 0.5,
      duration: (_) => const Duration(milliseconds: 500),
      curve: (_) => Curves.easeInOut,
      precalculateTargetItemCount: true,
    );
  }

  Future<void> _messageActions(FeedbackMessage message) async {
    var canWithdraw = false;
    try {
      canWithdraw = await c.api.canWithdraw(message.id);
    } catch (error) {
      if (mounted) c.report(error);
    }
    if (!mounted) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: false,
      builder: (context) => SafeArea(
        child: SuperListView(
          shrinkWrap: true,
          children: [
            if (!message.withdrawn && c.permissions.canSend(c.issue!))
              ListTile(
                leading: const Icon(Icons.reply),
                title: const Text('回复'),
                onTap: () => Navigator.pop(context, 'reply'),
              ),
            if (!message.withdrawn)
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('复制'),
                onTap: () => Navigator.pop(context, 'copy'),
              ),
            if (!message.withdrawn && canWithdraw)
              ListTile(
                leading: const Icon(Icons.undo),
                title: const Text('撤回'),
                onTap: () => Navigator.pop(context, 'withdraw'),
              ),
            if (message.withdrawn && c.permissions.isAdmin)
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('查看撤回记录'),
                onTap: () => Navigator.pop(context, 'audit'),
              ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('查看个人页面'),
              onTap: () => Navigator.pop(context, 'profile'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'reply') {
      setState(() => replyTo = message.id);
      focus.requestFocus();
    }
    if (action == 'copy')
      await Clipboard.setData(ClipboardData(text: message.text));
    if (action == 'profile') await widget.onOpenProfile(message.senderId);
    if (!mounted) return;
    if (action == 'withdraw' &&
        await _confirm(context, '撤回消息', '撤回后正文将被清除，是否继续？') &&
        mounted) {
      try {
        await c.withdraw(message.id);
      } catch (error) {
        if (mounted) c.report(error);
      }
    }
    if (action == 'audit' && mounted) {
      try {
        final rows = await c.api.withdrawalAudit(message.id);
        final people = await c.api.profiles(
          rows.map((row) => row['actor_id'] as String),
        );
        if (!mounted) return;
        for (final profile in people) {
          c.profiles[profile.id] = profile;
        }
        await showDialog<void>(
          context: context,
          useRootNavigator: false,
          builder: (context) => AlertDialog(
            title: const Text('撤回记录'),
            content: Text(
              rows.isEmpty
                  ? '暂无记录'
                  : rows
                        .map(
                          (row) =>
                              '${c.name(row['actor_id'] as String)}\n${_time(feedbackDate(row['created_at']))}',
                        )
                        .join('\n\n'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('关闭'),
              ),
            ],
          ),
        );
      } catch (error) {
        if (mounted) c.report(error);
      }
    }
  }

  Widget _message(FeedbackMessage message) {
    final profile = c.profiles[message.senderId];
    final reference = message.replyTo == null
        ? null
        : c.reference(message.replyTo!);
    final mine = message.senderId == c.permissions.userId;
    return Align(
      key: ValueKey(message.id),
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        key: _messageKeys.putIfAbsent(message.id, () => GlobalKey()),
        constraints: const BoxConstraints(maxWidth: 680),
        child: Card(
          color: mine ? Theme.of(context).colorScheme.primaryContainer : null,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          child: InkWell(
            onLongPress: () => _messageActions(message),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.only(
                top: 0,
                bottom: 12,
                left: 12,
                right: 12,
              ),
              child: Column(
                crossAxisAlignment: mine
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: InkWell(
                          onTap: () {
                            focus.unfocus();
                            unawaited(widget.onOpenProfile(message.senderId));
                          },
                          child: Text(
                            c.name(message.senderId),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      if (profile?.isPro == true) _proBadge(context),
                      const SizedBox(width: 8),
                      Text(
                        _time(message.createdAt),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      IconButton(
                        tooltip: '消息操作',
                        visualDensity: VisualDensity.compact,
                        iconSize: 18,
                        onPressed: () => _messageActions(message),
                        icon: const Icon(Icons.more_horiz),
                      ),
                    ],
                  ),
                  if (!message.withdrawn && message.replyTo != null)
                    InkWell(
                      onTap: c.jumping ? null : () => _jump(message.replyTo!),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 3,
                            ),
                          ),
                        ),
                        child: Text(
                          reference == null
                              ? '引用消息暂不可用，点击加载'
                              : '${c.name(reference.senderId)}：${reference.text}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  if (!message.withdrawn &&
                      (message.mentionAll || message.mentions.isNotEmpty))
                    Wrap(
                      spacing: 6,
                      children: [
                        if (message.mentionAll) const Text('@ALL'),
                        for (final id in message.mentions)
                          InkWell(
                            onTap: () => widget.onOpenProfile(id),
                            child: Text('@${c.name(id)}'),
                          ),
                      ],
                    ),
                  _FeedbackBody(message.text),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _renderedIds = c.messages.map((message) => message.id).toList();
    final issue = c.issue!;
    final allowed = c.permissions.canSend(issue);
    final reply = replyTo == null ? null : c.reference(replyTo!);
    return Column(
      children: [
        ExpansionTile(
          title: Text(issue.title),
          subtitle: Text(
            '${issue.statusLabel}${issue.locked ? ' · 讨论已锁定' : ''}',
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: SelectableText(issue.description),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('创建者：${c.name(issue.creatorId)}'),
              subtitle: Text('创建于 ${_time(issue.createdAt)}'),
              onTap: () => widget.onOpenProfile(issue.creatorId),
            ),
          ],
        ),
        if (c.recovering && c.messages.isNotEmpty)
          Center(
            child: SizedBox.square(
              dimension: 24,
              child: FittedBox(child: globalLoadingAnime),
            ),
          ),
        if (c.jumping)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: FittedBox(child: globalLoadingAnime),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text('正在加载引用消息，已补齐 ${c.jumpLoaded} 条')),
                TextButton(onPressed: c.cancelJump, child: const Text('取消')),
              ],
            ),
          ),
        Expanded(
          child: c.loading && c.messages.isEmpty
              ? Center(child: globalLoadingAnime)
              : SuperListView.builder(
                  controller: scroll,
                  listController: list,
                  reverse: true,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  findChildIndexCallback: (key) {
                    if (key is! ValueKey<int>) return null;
                    final index = c.messages.indexWhere(
                      (message) => message.id == key.value,
                    );
                    return index < 0 ? null : index;
                  },
                  itemCount: c.messages.length + 1,
                  itemBuilder: (context, index) => index == c.messages.length
                      ? Column(
                          children: [
                            if (c.messages.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(24),
                                child: Text('暂无消息'),
                              ),
                            _moreButton(
                              c.hasMore,
                              c.loadingMore,
                              () => c.older(),
                            ),
                          ],
                        )
                      : _message(c.messages[index]),
                ),
        ),
        if (c.unseen > 0)
          TextButton.icon(
            onPressed: _latest,
            icon: const Icon(Icons.arrow_downward),
            label: Text('有 ${c.unseen} 条新消息'),
          ),
        if (replyTo != null)
          ListTile(
            dense: true,
            title: Text(
              '回复：${reply?.text ?? '引用消息'}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              tooltip: '取消回复',
              onPressed: sending ? null : () => setState(() => replyTo = null),
              icon: const Icon(Icons.close),
            ),
          ),
        if (mentions.isNotEmpty || mentionAll)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 6,
              children: [
                if (mentionAll)
                  InputChip(
                    label: const Text('@ALL'),
                    onDeleted: sending
                        ? null
                        : () => setState(() => mentionAll = false),
                  ),
                for (final id in mentions)
                  InputChip(
                    label: Text('@${c.name(id)}'),
                    onDeleted: sending
                        ? null
                        : () => setState(() => mentions.remove(id)),
                  ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
          child: c.permissions.userId == null
              ? TextButton(
                  onPressed: widget.onLogin,
                  child: const Text('登录后参与讨论'),
                )
              : !allowed
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    c.permissions.globalBanned || c.permissions.issueBanned
                        ? '你已被禁言，暂时无法发言'
                        : '讨论已锁定，仅创建者和超级管理员可发言',
                  ),
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: '提及用户或所有人',
                      onPressed: sending ? null : _chooseMentions,
                      icon: const Icon(Icons.alternate_email),
                    ),
                    Expanded(
                      child: TextField(
                        controller: text,
                        focusNode: focus,
                        readOnly: sending,
                        minLines: 1,
                        maxLines: 5,
                        maxLength: 1000,
                        decoration: const InputDecoration(
                          hintText: '发送公开消息',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    IconButton(
                      tooltip: '发送',
                      onPressed: sending || text.text.trim().isEmpty
                          ? null
                          : _send,
                      icon: sending
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: FittedBox(child: globalLoadingAnime),
                            )
                          : const Icon(Icons.send),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// Text is never interpreted as Markdown/HTML. Recognizers are disposed on rebuild.
class _FeedbackBody extends StatefulWidget {
  const _FeedbackBody(this.text);
  final String text;
  @override
  State<_FeedbackBody> createState() => _FeedbackBodyState();
}

class _FeedbackBodyState extends State<_FeedbackBody> {
  final recognizers = <TapGestureRecognizer>[];
  @override
  void dispose() {
    for (final recognizer in recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final recognizer in recognizers) {
      recognizer.dispose();
    }
    recognizers.clear();
    final spans = <TextSpan>[];
    var cursor = 0;
    for (final match in RegExp(r'https?://[^\s<>]+').allMatches(widget.text)) {
      if (match.start > cursor)
        spans.add(TextSpan(text: widget.text.substring(cursor, match.start)));
      final url = match.group(0)!;
      final recognizer = TapGestureRecognizer()
        ..onTap = () async {
          final uri = Uri.tryParse(url);
          if (uri != null)
            await launchUrl(uri, mode: LaunchMode.externalApplication);
        };
      recognizers.add(recognizer);
      spans.add(
        TextSpan(
          text: url,
          recognizer: recognizer,
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            decoration: TextDecoration.underline,
          ),
        ),
      );
      cursor = match.end;
    }
    spans.add(TextSpan(text: widget.text.substring(cursor)));
    return Text.rich(TextSpan(children: spans));
  }
}
