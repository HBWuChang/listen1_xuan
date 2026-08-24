import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:listen1_xuan/controllers/sleep_timer_controller.dart';
import 'package:listen1_xuan/widgets/fade_box.dart';
import 'package:stop_watch_timer/stop_watch_timer.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

class SleepTimerSheet {
  static const List<int> quickMinutes = [10, 20, 30, 45, 60, 90];

  static Future<void> show(BuildContext context) {
    final controller = Get.find<SleepTimerController>();
    return WoltModalSheet.show<void>(
      context: context,
      showDragHandle: false,
      useRootNavigator: true,
      pageListBuilder: (_) => [_buildPage(controller)],
    );
  }

  static WoltModalSheetPage _buildPage(SleepTimerController controller) {
    return WoltModalSheetPage(
      hasTopBarLayer: false,
      isTopBarLayerAlwaysVisible: false,
      navBarHeight: 0,
      enableDrag: true,
      child: Builder(
        builder: (context) => SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Obx(
                        () => FadeThroughBox(
                          alignment: Alignment.centerLeft,
                          child: controller.isEnabled
                              ? _AnimatedCountdownTime(controller: controller)
                              : Text(
                                  '选择时间',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                        ),
                      ),
                    ),
                    Obx(
                      () => Switch(
                        value: controller.isEnabled,
                        onChanged: controller.setEnabled,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                LayoutBuilder(
                  builder: (context, constraints) {
                    const spacing = 12.0;
                    final columns = constraints.maxWidth >= 420 ? 6 : 3;
                    final itemWidth =
                        (constraints.maxWidth - spacing * (columns - 1)) /
                        columns;
                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: quickMinutes
                          .map(
                            (minutes) => SizedBox.square(
                              dimension: itemWidth,
                              child: Obx(() {
                                final selected =
                                    controller.isEnabled &&
                                    controller.selectedQuickMinutes.value ==
                                        minutes;
                                return Material(
                                  color: selected
                                      ? Theme.of(
                                          context,
                                        ).colorScheme.primaryContainer
                                      : Theme.of(
                                          context,
                                        ).colorScheme.surfaceContainerHighest,
                                  shape: const CircleBorder(),
                                  clipBehavior: Clip.antiAlias,
                                  child: InkWell(
                                    onTap: () => controller.startFor(
                                      Duration(minutes: minutes),
                                      quickMinutes: minutes,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '$minutes',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              color: selected
                                                  ? Theme.of(context)
                                                        .colorScheme
                                                        .onPrimaryContainer
                                                  : null,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () => _selectCustomTime(context, controller),
                  icon: const Icon(Icons.schedule_rounded),
                  label: const Text('自定义'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Future<void> _selectCustomTime(
    BuildContext context,
    SleepTimerController controller,
  ) async {
    final now = DateTime.now();
    final initialDateTime =
        controller.endsAt.value ?? now.add(controller.lastDuration.value);
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDateTime),
      helpText: '选择关闭时间',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (selected == null) return;

    final selectedAt = DateTime.now();
    var target = DateTime(
      selectedAt.year,
      selectedAt.month,
      selectedAt.day,
      selected.hour,
      selected.minute,
    );
    if (!target.isAfter(selectedAt)) {
      target = target.add(const Duration(days: 1));
    }
    controller.startUntil(target);
  }
}

class _AnimatedCountdownTime extends StatelessWidget {
  const _AnimatedCountdownTime({required this.controller});

  final SleepTimerController controller;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600);

    return StreamBuilder<int>(
      stream: controller.rawTime,
      initialData: controller.rawTimeValue,
      builder: (context, snapshot) {
        final rawTime = snapshot.data ?? 0;
        final displayRawTime = rawTime == 0
            ? 0
            : ((rawTime + 999) ~/ 1000) * 1000;
        final hours = StopWatchTimer.getDisplayTimeHours(displayRawTime);
        final minutes = StopWatchTimer.getDisplayTimeMinute(
          displayRawTime,
          hours: true,
        );
        final seconds = StopWatchTimer.getDisplayTimeSecond(displayRawTime);
        final showHours = StopWatchTimer.getRawHours(displayRawTime) > 0;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showHours) ...[
              ..._buildDigits(hours, 'hours', style),
              Text(':', key: const ValueKey('hours-separator'), style: style),
            ],
            ..._buildDigits(minutes, 'minutes', style),
            Text(':', key: const ValueKey('minutes-separator'), style: style),
            ..._buildDigits(seconds, 'seconds', style),
          ],
        );
      },
    );
  }

  List<Widget> _buildDigits(String value, String part, TextStyle? style) {
    return List.generate(
      value.length,
      (index) => _AnimatedCountdownDigit(
        key: ValueKey('$part-$index'),
        digit: value[index],
        style: style,
      ),
    );
  }
}

class _AnimatedCountdownDigit extends StatefulWidget {
  const _AnimatedCountdownDigit({
    super.key,
    required this.digit,
    required this.style,
  });

  final String digit;
  final TextStyle? style;

  @override
  State<_AnimatedCountdownDigit> createState() =>
      _AnimatedCountdownDigitState();
}

class _AnimatedCountdownDigitState extends State<_AnimatedCountdownDigit>
    with SingleTickerProviderStateMixin {
  late String _previousDigit;
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _previousDigit = widget.digit;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: 1,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void didUpdateWidget(covariant _AnimatedCountdownDigit oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.digit != oldWidget.digit) {
      _previousDigit = oldWidget.digit;
      _controller.forward(from: 0);
    }
  }

  double _textWidth(BuildContext context, String digit) {
    final painter = TextPainter(
      text: TextSpan(text: digit, style: widget.style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    return painter.width;
  }

  @override
  Widget build(BuildContext context) {
    final previousWidth = _textWidth(context, _previousDigit);
    final currentWidth = _textWidth(context, widget.digit);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final progress = _animation.value;
        final width = previousWidth + (currentWidth - previousWidth) * progress;
        return SizedBox(
          width: width,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: 1 - progress,
                child: Text(_previousDigit, style: widget.style),
              ),
              Opacity(
                opacity: progress,
                child: Text(widget.digit, style: widget.style),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
