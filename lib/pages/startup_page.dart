import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/startup_tips_service.dart';

class StartupFailure {
  const StartupFailure(this.reason, this.diagnostics);

  final String reason;
  final String diagnostics;

  static StartupFailure fromError(Object error, StackTrace stackTrace) {
    String clean(String value) {
      final withoutBearer = value.replaceAll(
        RegExp(r'Bearer\s+[^\s,;]+', caseSensitive: false),
        'Bearer [已隐藏]',
      );
      return withoutBearer.replaceAllMapped(
        RegExp(
          r'\b(authorization|api[_-]?key|anon[_-]?key|access[_-]?token|refresh[_-]?token|token|password|cookie|secret)\b\s*[:=]\s*[^\s,;]+',
          caseSensitive: false,
        ),
        (match) => '${match.group(1)}=[已隐藏]',
      );
    }

    final reason = clean(error.toString());
    final trace = clean(stackTrace.toString().split('\n').take(12).join('\n'));
    return StartupFailure(
      reason.isEmpty ? '未知启动错误' : reason,
      '$reason\n$trace',
    );
  }
}

class StartupPage extends StatefulWidget {
  const StartupPage({
    super.key,
    required this.tipsService,
    required this.failure,
    required this.logoColor,
  });

  final StartupTipsService tipsService;
  final ValueNotifier<StartupFailure?> failure;
  final ValueNotifier<Color?> logoColor;

  @override
  State<StartupPage> createState() => _StartupPageState();
}

class _StartupPageState extends State<StartupPage> {
  String? _tip;
  Timer? _exitTimer;

  @override
  void initState() {
    super.initState();
    _tip = widget.tipsService.randomTip();
    widget.tipsService.tips.addListener(_onTipsChanged);
    widget.failure.addListener(_onFailureChanged);
    _onFailureChanged();
  }

  void _onTipsChanged() {
    if (_tip != null) return;
    final selected = widget.tipsService.randomTip();
    if (selected != null && mounted) setState(() => _tip = selected);
  }

  void _onFailureChanged() {
    final failure = widget.failure.value;
    if (failure == null || _exitTimer != null) return;
    if (mounted) setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _exitTimer != null) return;
      _exitTimer = Timer(const Duration(seconds: 3), () => exit(0));
      unawaited(Clipboard.setData(ClipboardData(text: failure.diagnostics))
          .catchError((Object error) {
        debugPrint('复制启动错误失败: $error');
      }));
    });
  }

  @override
  void dispose() {
    _exitTimer?.cancel();
    widget.tipsService.tips.removeListener(_onTipsChanged);
    widget.failure.removeListener(_onFailureChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final failure = widget.failure.value;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ValueListenableBuilder<Color?>(
                      valueListenable: widget.logoColor,
                      builder: (context, color, _) => Container(
                        key: const Key('startup-logo'),
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          color: color ?? Theme.of(context).colorScheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Image.asset('assets/images/force.png'),
                      ),
                    ),
                    if (failure != null || _tip != null) const SizedBox(height: 28),
                    if (failure != null || _tip != null) Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            if (failure != null) ...[
                              Text('启动失败', style: Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 10),
                              SelectableText(failure.reason, textAlign: TextAlign.center),
                              const SizedBox(height: 10),
                              const Text('错误信息已复制，应用将在 3 秒后关闭'),
                            ] else if (_tip != null) ...[
                              Text('Tip', style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 10),
                              Text(_tip!, textAlign: TextAlign.center),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
