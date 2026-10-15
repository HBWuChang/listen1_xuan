part of 'feedback_page.dart';

class _MentionSelection {
  _MentionSelection(this.ids, this.all, this.profiles);
  final Set<String> ids;
  final bool all;
  final List<FeedbackProfile> profiles;
}

class _FeedbackParticipantPicker extends StatefulWidget {
  const _FeedbackParticipantPicker({required this.api, required this.issueId, required this.selected, required this.all});
  final FeedbackApi api;
  final String issueId;
  final Set<String> selected;
  final bool all;
  @override
  State<_FeedbackParticipantPicker> createState() => _FeedbackParticipantPickerState();
}
class _FeedbackParticipantPickerState extends State<_FeedbackParticipantPicker> {
  late final Set<String> selected;
  late bool all;
  final rows = <FeedbackProfile>[];
  final known = <String, FeedbackProfile>{};
  final search = TextEditingController();
  final searchFocus = FocusNode();
  Timer? debounce;
  bool loading = false, more = true;
  String? error;
  int request = 0;
  @override
  void initState() {
    super.initState();
    searchFocus.addListener(() => setInAppHotKeyEnable(!searchFocus.hasFocus));
    selected = {...widget.selected}; all = widget.all;
    unawaited(_load());
  }
  @override
  void dispose() { debounce?.cancel(); search.dispose(); searchFocus.dispose(); setInAppHotKeyEnable(true); super.dispose(); }
  Future<void> _load({bool reset = false}) async {
    if (loading && !reset) return;
    final token = ++request;
    setState(() { loading = true; error = null; if (reset) rows.clear(); });
    try {
      final result = await widget.api.participants(widget.issueId, search: search.text, after: rows.isEmpty ? null : rows.last.id);
      if (!mounted || token != request) return;
      setState(() {
        rows.addAll(result); more = result.length == 30;
        for (final row in result) { known[row.id] = row; }
      });
    } catch (e) { if (mounted && token == request) setState(() => error = FeedbackController.friendlyError(e)); }
    finally { if (mounted && token == request) setState(() => loading = false); }
  }
  @override
  Widget build(BuildContext context) => AlertDialog(title: const Text('提及用户'),
    content: SizedBox(width: 480, height: 420, child: Column(children: [
      TextField(controller: search, focusNode: searchFocus, decoration: const InputDecoration(labelText: '搜索发言者'), onChanged: (_) {
        debounce?.cancel(); debounce = Timer(const Duration(milliseconds: 300), () => _load(reset: true));
      }),
      CheckboxListTile(title: const Text('@ALL（所有人）'), value: all, onChanged: (value) => setState(() => all = value == true)),
      if (error != null) TextButton(onPressed: () => _load(reset: true), child: Text('$error，点击重试')),
      Expanded(child: SuperListView.builder(itemCount: rows.length + 1, itemBuilder: (context, index) {
        if (index == rows.length) return _moreButton(more, loading, () => _load());
        final row = rows[index];
        return CheckboxListTile(title: Text(row.name), subtitle: Text(row.id.substring(0, 8)),
          value: selected.contains(row.id), onChanged: (value) => setState(() {
            if (value == true) { selected.add(row.id); } else { selected.remove(row.id); }
          }));
      })),
    ])), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
      FilledButton(onPressed: () => Navigator.pop(context, _MentionSelection(selected, all, known.values.toList())), child: const Text('确定'))],
  );
}
