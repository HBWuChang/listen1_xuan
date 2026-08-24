import 'dart:async';

import 'package:get/get.dart';
import 'package:listen1_xuan/controllers/routeController.dart';
import 'package:stop_watch_timer/stop_watch_timer.dart';

class SleepTimerController extends GetxController {
  static const Duration defaultDuration = Duration(minutes: 30);

  final Rxn<DateTime> endsAt = Rxn<DateTime>();
  final Rx<Duration> lastDuration = defaultDuration.obs;
  final RxnInt selectedQuickMinutes = RxnInt();

  late final StopWatchTimer _stopWatchTimer;

  Stream<int> get rawTime => _stopWatchTimer.rawTime;
  int get rawTimeValue => _stopWatchTimer.rawTime.value;

  bool get isEnabled => endsAt.value != null;

  @override
  void onInit() {
    super.onInit();
    _stopWatchTimer = StopWatchTimer(
      mode: StopWatchMode.countDown,
      refreshTime: 200,
      onEnded: _handleEnded,
    );
  }

  void startFor(Duration duration, {int? quickMinutes}) {
    if (duration <= Duration.zero) return;

    endsAt.value = null;
    _stopWatchTimer.onResetTimer();
    _stopWatchTimer.setPresetTime(mSec: duration.inMilliseconds, add: false);
    lastDuration.value = duration;
    selectedQuickMinutes.value = quickMinutes;
    endsAt.value = DateTime.now().add(duration);
    _stopWatchTimer.onStartTimer();
  }

  void startUntil(DateTime dateTime) {
    final duration = dateTime.difference(DateTime.now());
    startFor(duration);
  }

  void setEnabled(bool enabled) {
    if (enabled) {
      startFor(lastDuration.value, quickMinutes: selectedQuickMinutes.value);
    } else {
      cancel();
    }
  }

  void cancel() {
    endsAt.value = null;
    _stopWatchTimer.onStopTimer();
    _stopWatchTimer.onResetTimer();
  }

  void _handleEnded() {
    if (!isEnabled) return;
    endsAt.value = null;
    unawaited(closeApp());
  }

  @override
  void onClose() {
    unawaited(_stopWatchTimer.dispose());
    super.onClose();
  }
}
