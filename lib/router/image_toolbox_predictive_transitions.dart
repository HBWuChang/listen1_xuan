import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

const _predictiveBackLogPrefix = '[ImageToolboxPB]';
final _predictiveBackLogClock = Stopwatch()..start();

void _predictiveBackLog(String message) {
  if (kDebugMode) {
    debugPrint(
      '$_predictiveBackLogPrefix +${_predictiveBackLogClock.elapsedMilliseconds}ms $message',
    );
  }
}

String _routeDebugLabel(PageRoute<dynamic> route) {
  final name = route.settings.name ?? '<unnamed>';
  return '$name#${identityHashCode(route)}';
}

String _progressDebugLabel(double value) => value.toStringAsFixed(3);

/// Page transition theme that recreates ImageToolbox's Decompose
/// `androidPredictiveBackAnimatableV1` transition on Android.
const imageToolboxPageTransitionsTheme = PageTransitionsTheme(
  builders: <TargetPlatform, PageTransitionsBuilder>{
    TargetPlatform.android: ImageToolboxPredictiveTransitionsBuilder(),
  },
);

/// An Android predictive-back transition inspired by ImageToolbox.
///
/// Regular route changes combine fade, horizontal slide, and scale animations.
/// During predictive back, the outgoing and incoming routes share gesture state
/// and reproduce Decompose's two-stage V1 transition.
class ImageToolboxPredictiveTransitionsBuilder extends PageTransitionsBuilder {
  const ImageToolboxPredictiveTransitionsBuilder();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 500);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 500);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final navigator = route.navigator;
    if (navigator == null) return child;

    final gestureState = _gestureStateFor(navigator);
    return _ImageToolboxPredictiveBackObserver(
      route: route,
      gestureState: gestureState,
      child: _ImageToolboxPageTransition(
        route: route,
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        gestureState: gestureState,
        child: child,
      ),
    );
  }
}

/// A [GetPageRoute] that honors the app's Android [PageTransitionsTheme].
///
/// GetX 4.7.3 normally creates a new default [PageTransitionsTheme] instead of
/// reading it from [ThemeData]. This route keeps GetX bindings and middleware,
/// while delegating Android transitions to the active app theme.
class ThemedGetPageRoute<T> extends GetPageRoute<T> {
  ThemedGetPageRoute({
    super.settings,
    super.transitionDuration = const Duration(milliseconds: 500),
    super.opaque = true,
    super.transition,
    super.popGesture,
    super.customTransition,
    super.curve,
    super.alignment,
    super.binding,
    super.bindings,
    super.page,
    super.middlewares,
    super.maintainState = true,
    super.fullscreenDialog = false,
  });

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (Theme.of(context).platform == TargetPlatform.android) {
      return Theme.of(context).pageTransitionsTheme.buildTransitions<T>(
        this,
        context,
        animation,
        secondaryAnimation,
        child,
      );
    }

    return super.buildTransitions(
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}

final _gestureStates = Expando<_ImageToolboxGestureState>(
  'ImageToolbox predictive-back states',
);

_ImageToolboxGestureState _gestureStateFor(NavigatorState navigator) {
  final existing = _gestureStates[navigator];
  if (existing != null && !existing.disposed) return existing;
  return _gestureStates[navigator] = _ImageToolboxGestureState(navigator);
}

enum _ImageToolboxBackPhase { idle, drag, commit, cancel }

const _progressThreshold = 0.4;
const _settleDuration = Duration(milliseconds: 500);
const _settleCurve = Cubic(0.55, 0.55, 0, 1);

class _ImageToolboxGestureState extends ChangeNotifier {
  _ImageToolboxGestureState(this.navigator) {
    _settleController =
        AnimationController(vsync: navigator, duration: _settleDuration)
          ..addListener(_updateSettlingProgress)
          ..addStatusListener(_handleSettleStatus);
    navigator.userGestureInProgressNotifier.addListener(
      _handleNavigatorGestureChanged,
    );
  }

  final NavigatorState navigator;
  late final AnimationController _settleController;
  int _lastDragDebugBucket = -1;
  int _lastSettleDebugBucket = -1;
  int _clientCount = 0;
  bool _navigatorGestureEnded = false;
  bool disposed = false;

  double _fromExit = 0;
  double _fromEnter = 0;
  double _fromFinish = 0;
  double _toExit = 0;
  double _toEnter = 0;
  double _toFinish = 0;

  final Map<PageRoute<dynamic>, String> _lastRenderDebugState =
      <PageRoute<dynamic>, String>{};

  bool active = false;
  PageRoute<dynamic>? fromRoute;
  _ImageToolboxBackPhase phase = _ImageToolboxBackPhase.idle;
  SwipeEdge swipeEdge = SwipeEdge.left;

  double exitProgress = 0;
  double enterProgress = 0;
  double finishProgress = 0;

  double get settleValue => _settleController.value;
  bool get settleAnimating => _settleController.isAnimating;

  void attach() {
    _clientCount += 1;
  }

  void detach() {
    assert(_clientCount > 0);
    _clientCount -= 1;
    if (_clientCount == 0) dispose();
  }

  void begin(PageRoute<dynamic> route, PredictiveBackEvent event) {
    _settleController.stop();
    _lastDragDebugBucket = -1;
    _lastSettleDebugBucket = -1;
    _lastRenderDebugState.clear();
    _navigatorGestureEnded = false;
    active = true;
    fromRoute = route;
    phase = _ImageToolboxBackPhase.drag;
    swipeEdge = event.swipeEdge;
    _setDragProgress(event.progress);
    _predictiveBackLog(
      'START accepted route=${_routeDebugLabel(route)} '
      'raw=${_progressDebugLabel(event.progress)} edge=${event.swipeEdge.name}',
    );
  }

  void update(PredictiveBackEvent event) {
    swipeEdge = event.swipeEdge;
    _setDragProgress(event.progress);
  }

  void _setDragProgress(double rawProgress) {
    final progress = rawProgress.clamp(0.0, 1.0);
    exitProgress = progress < _progressThreshold ? progress : 1;
    enterProgress = progress < _progressThreshold
        ? 0
        : lerpDouble(
            0.4,
            1,
            (progress - _progressThreshold) / (1 - _progressThreshold),
          )!;
    finishProgress = 0;
    final debugBucket = (progress * 20).floor().clamp(0, 20);
    if (debugBucket != _lastDragDebugBucket) {
      _lastDragDebugBucket = debugBucket;
      _predictiveBackLog(
        'DRAG raw=${_progressDebugLabel(progress)} '
        'exit=${_progressDebugLabel(exitProgress)} '
        'enter=${_progressDebugLabel(enterProgress)}',
      );
    }
    notifyListeners();
  }

  void setPhase(_ImageToolboxBackPhase value) {
    phase = value;
    _predictiveBackLog(
      'PHASE ${value.name} from=${fromRoute == null ? '<none>' : _routeDebugLabel(fromRoute!)} '
      'exit=${_progressDebugLabel(exitProgress)} '
      'enter=${_progressDebugLabel(enterProgress)} '
      'finish=${_progressDebugLabel(finishProgress)}',
    );
    notifyListeners();
  }

  void startCommit() {
    setPhase(_ImageToolboxBackPhase.commit);
    _animateGestureState(exit: 1, enter: enterProgress, finish: 1);
  }

  void startCancel() {
    setPhase(_ImageToolboxBackPhase.cancel);
    _animateGestureState(exit: 0, enter: 0, finish: 0);
  }

  void _animateGestureState({
    required double exit,
    required double enter,
    required double finish,
  }) {
    _fromExit = exitProgress;
    _fromEnter = enterProgress;
    _fromFinish = finishProgress;
    _toExit = exit;
    _toEnter = enter;
    _toFinish = finish;
    _lastSettleDebugBucket = -1;
    _predictiveBackLog(
      'SETTLE start navigator=${identityHashCode(navigator)} '
      'duration=${_settleDuration.inMilliseconds}ms '
      'from=(${_progressDebugLabel(_fromExit)},'
      '${_progressDebugLabel(_fromEnter)},'
      '${_progressDebugLabel(_fromFinish)}) '
      'to=(${_progressDebugLabel(_toExit)},'
      '${_progressDebugLabel(_toEnter)},'
      '${_progressDebugLabel(_toFinish)})',
    );
    _settleController
      ..value = 0
      ..animateTo(1, curve: _settleCurve);
  }

  void _updateSettlingProgress() {
    final progress = _settleController.value;
    final exit = lerpDouble(_fromExit, _toExit, progress)!;
    final enter = lerpDouble(_fromEnter, _toEnter, progress)!;
    final finish = lerpDouble(_fromFinish, _toFinish, progress)!;
    final debugBucket = (progress * 10).floor().clamp(0, 10);
    if (debugBucket != _lastSettleDebugBucket) {
      _lastSettleDebugBucket = debugBucket;
      _predictiveBackLog(
        'SETTLE tick navigator=${identityHashCode(navigator)} '
        'elapsed=${_settleController.lastElapsedDuration?.inMilliseconds ?? 0}ms '
        'progress=${_progressDebugLabel(progress)} '
        'values=(${_progressDebugLabel(exit)},'
        '${_progressDebugLabel(enter)},'
        '${_progressDebugLabel(finish)}) '
        'navigatorGesture=${navigator.userGestureInProgress}',
      );
    }
    setAnimationValues(exit: exit, enter: enter, finish: finish);
  }

  void _handleSettleStatus(AnimationStatus status) {
    _predictiveBackLog(
      'SETTLE status=${status.name} navigator=${identityHashCode(navigator)} '
      'value=${_progressDebugLabel(_settleController.value)} '
      'navigatorEnded=$_navigatorGestureEnded',
    );
    if (status == AnimationStatus.completed) {
      _resetIfFinished();
    }
  }

  void _handleNavigatorGestureChanged() {
    final inProgress = navigator.userGestureInProgress;
    _predictiveBackLog(
      'NAV gesture=$inProgress navigator=${identityHashCode(navigator)} '
      'phase=${phase.name} settle=${_progressDebugLabel(settleValue)} '
      'settleAnimating=$settleAnimating',
    );
    if (inProgress) return;
    _navigatorGestureEnded = true;
    _resetIfFinished();
  }

  void _resetIfFinished() {
    if (!_navigatorGestureEnded || settleAnimating) {
      _predictiveBackLog(
        'RESET deferred navigator=${identityHashCode(navigator)} '
        'navigatorEnded=$_navigatorGestureEnded '
        'settleAnimating=$settleAnimating',
      );
      return;
    }
    if (phase == _ImageToolboxBackPhase.drag) {
      _predictiveBackLog(
        'RESET deferred navigator=${identityHashCode(navigator)} phase=drag',
      );
      return;
    }
    reset();
  }

  void setAnimationValues({
    required double exit,
    required double enter,
    required double finish,
  }) {
    exitProgress = exit.clamp(0.0, 1.0);
    enterProgress = enter.clamp(0.0, 1.0);
    finishProgress = finish.clamp(0.0, 1.0);
    notifyListeners();
  }

  void debugRender({
    required PageRoute<dynamic> route,
    required String branch,
    required double visualProgress,
    required Animation<double> primaryAnimation,
    required Animation<double> secondaryAnimation,
  }) {
    if (!kDebugMode) return;
    final bucket = (visualProgress * 10).floor().clamp(0, 10);
    final state = '$branch:$bucket';
    if (_lastRenderDebugState[route] == state) return;
    _lastRenderDebugState[route] = state;
    _predictiveBackLog(
      'RENDER $branch route=${_routeDebugLabel(route)} '
      'visual=${_progressDebugLabel(visualProgress)} '
      'primary=${_progressDebugLabel(primaryAnimation.value)} '
      'secondary=${_progressDebugLabel(secondaryAnimation.value)} '
      'active=$active phase=${phase.name}',
    );
  }

  void reset() {
    _predictiveBackLog(
      'RESET from=${fromRoute == null ? '<none>' : _routeDebugLabel(fromRoute!)} '
      'exit=${_progressDebugLabel(exitProgress)} '
      'enter=${_progressDebugLabel(enterProgress)} '
      'finish=${_progressDebugLabel(finishProgress)}',
    );
    _lastRenderDebugState.clear();
    active = false;
    fromRoute = null;
    phase = _ImageToolboxBackPhase.idle;
    exitProgress = 0;
    enterProgress = 0;
    finishProgress = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    if (disposed) return;
    disposed = true;
    navigator.userGestureInProgressNotifier.removeListener(
      _handleNavigatorGestureChanged,
    );
    _settleController
      ..removeListener(_updateSettlingProgress)
      ..removeStatusListener(_handleSettleStatus)
      ..dispose();
    super.dispose();
  }
}

class _ImageToolboxPredictiveBackObserver extends StatefulWidget {
  const _ImageToolboxPredictiveBackObserver({
    required this.route,
    required this.gestureState,
    required this.child,
  });

  final PageRoute<dynamic> route;
  final _ImageToolboxGestureState gestureState;
  final Widget child;

  @override
  State<_ImageToolboxPredictiveBackObserver> createState() =>
      _ImageToolboxPredictiveBackObserverState();
}

class _ImageToolboxPredictiveBackObserverState
    extends State<_ImageToolboxPredictiveBackObserver>
    with WidgetsBindingObserver {
  bool get _isEnabled {
    final routeNavigator = widget.route.navigator;
    if (routeNavigator == null) return false;

    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final isCoveredByRootRoute =
        !identical(routeNavigator, rootNavigator) && rootNavigator.canPop();

    return !isCoveredByRootRoute &&
        widget.route.isCurrent &&
        widget.route.popGestureEnabled;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.gestureState.attach();
  }

  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) {
    if (backEvent.isButtonEvent || !_isEnabled) {
      if (widget.route.isCurrent) {
        _predictiveBackLog(
          'START ignored route=${_routeDebugLabel(widget.route)} '
          'button=${backEvent.isButtonEvent} '
          'popEnabled=${widget.route.popGestureEnabled}',
        );
      }
      return false;
    }

    widget.gestureState.begin(widget.route, backEvent);
    widget.route.handleStartBackGesture(progress: 1 - backEvent.progress);
    return true;
  }

  @override
  void handleUpdateBackGestureProgress(PredictiveBackEvent backEvent) {
    widget.gestureState.update(backEvent);
    widget.route.handleUpdateBackGestureProgress(
      progress: 1 - backEvent.progress,
    );
  }

  @override
  void handleCancelBackGesture() {
    _predictiveBackLog(
      'CANCEL route=${_routeDebugLabel(widget.route)} '
      'routeAnimation=${_progressDebugLabel(widget.route.animation?.value ?? -1)}',
    );
    // Start the Navigator-owned settle animation first. The route is allowed
    // to finish its gesture synchronously when its animation is at an edge.
    widget.gestureState.startCancel();
    widget.route.handleCancelBackGesture();
  }

  @override
  void handleCommitBackGesture() {
    _predictiveBackLog(
      'COMMIT before route=${_routeDebugLabel(widget.route)} '
      'isCurrent=${widget.route.isCurrent} '
      'routeAnimation=${_progressDebugLabel(widget.route.animation?.value ?? -1)} '
      'navigatorGesture=${widget.route.navigator?.userGestureInProgress}',
    );
    // Start settling before Flutter pops the route. At progress 1.0 the route
    // is already dismissed and handleCommitBackGesture completes the pop
    // inline, so a controller owned by the outgoing route cannot survive.
    widget.gestureState.startCommit();
    widget.route.handleCommitBackGesture();
    _predictiveBackLog(
      'COMMIT after route=${_routeDebugLabel(widget.route)} '
      'isCurrent=${widget.route.isCurrent} '
      'routeAnimation=${_progressDebugLabel(widget.route.animation?.value ?? -1)} '
      'status=${widget.route.animation?.status.name} '
      'navigatorGesture=${widget.route.navigator?.userGestureInProgress}',
    );
  }

  @override
  void dispose() {
    if (widget.gestureState.active) {
      _predictiveBackLog(
        'OBSERVER dispose route=${_routeDebugLabel(widget.route)} '
        'phase=${widget.gestureState.phase.name} '
        'settle=${_progressDebugLabel(widget.gestureState.settleValue)}',
      );
    }
    WidgetsBinding.instance.removeObserver(this);
    widget.gestureState.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _ImageToolboxPageTransition extends StatelessWidget {
  const _ImageToolboxPageTransition({
    required this.route,
    required this.animation,
    required this.secondaryAnimation,
    required this.gestureState,
    required this.child,
  });

  final PageRoute<dynamic> route;
  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final _ImageToolboxGestureState gestureState;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        animation,
        secondaryAnimation,
        gestureState,
      ]),
      builder: (context, child) {
        if (gestureState.active) {
          return identical(route, gestureState.fromRoute)
              ? _buildOutgoingGesture(context, child!)
              : _buildIncomingGesture(context, child!);
        }

        return _buildFallbackTransition(context, child!);
      },
      child: RepaintBoundary(child: child),
    );
  }

  Widget _buildOutgoingGesture(BuildContext context, Widget child) {
    final progress = (gestureState.exitProgress / _progressThreshold).clamp(
      0.0,
      1.0,
    );
    final direction = gestureState.swipeEdge == SwipeEdge.left ? 1.0 : -1.0;
    final width = MediaQuery.widthOf(context);
    gestureState.debugRender(
      route: route,
      branch: 'outgoing',
      visualProgress: progress,
      primaryAnimation: animation,
      secondaryAnimation: secondaryAnimation,
    );

    return Transform.translate(
      offset: Offset(width * 0.5 * progress * direction, 0),
      child: Transform.scale(
        scale: 1 - progress * 0.1,
        child: Opacity(
          opacity: 1 - progress,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32 * progress),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildIncomingGesture(BuildContext context, Widget child) {
    final enterProgress = gestureState.enterProgress;
    final finishProgress = gestureState.finishProgress;
    final totalProgress = lerpDouble(enterProgress, 1, finishProgress)!;
    final baseScale = lerpDouble(0.95, 0.90, enterProgress)!;
    final scale = lerpDouble(baseScale, 1, finishProgress)!;
    final cornerProgress = lerpDouble(enterProgress, 0, finishProgress)!;
    final direction = gestureState.swipeEdge == SwipeEdge.left ? 1.0 : -1.0;
    final width = MediaQuery.widthOf(context);
    gestureState.debugRender(
      route: route,
      branch: 'incoming',
      visualProgress: totalProgress,
      primaryAnimation: animation,
      secondaryAnimation: secondaryAnimation,
    );

    return Transform.translate(
      offset: Offset(
        lerpDouble(-width * 0.15 * direction, 0, totalProgress)!,
        0,
      ),
      child: Transform.scale(
        scale: scale,
        child: Opacity(
          opacity: totalProgress,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32 * cornerProgress),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackTransition(BuildContext context, Widget child) {
    final primary = animation.value.clamp(0.0, 1.0);
    final secondary = secondaryAnimation.value.clamp(0.0, 1.0);
    gestureState.debugRender(
      route: route,
      branch: 'fallback',
      visualProgress: primary,
      primaryAnimation: animation,
      secondaryAnimation: secondaryAnimation,
    );
    final fadeProgress = Curves.easeInOut.transform(
      (primary / 0.6).clamp(0.0, 1.0),
    );
    final slideProgress = Curves.easeInOutCubicEmphasized.transform(
      (primary / 0.8).clamp(0.0, 1.0),
    );
    final scaleProgress = Curves.easeOutCubic.transform(primary);
    final coveredProgress = Curves.easeOutCubic.transform(secondary);
    final width = MediaQuery.widthOf(context);

    return Transform.translate(
      offset: Offset(
        width * 0.1 * (1 - slideProgress) - width * 0.025 * coveredProgress,
        0,
      ),
      child: Transform.scale(
        scale:
            lerpDouble(0.96, 1, scaleProgress)! *
            lerpDouble(1, 0.965, coveredProgress)!,
        child: Opacity(
          opacity: fadeProgress * lerpDouble(1, 0.92, coveredProgress)!,
          child: child,
        ),
      ),
    );
  }
}
