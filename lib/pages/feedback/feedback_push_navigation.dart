import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../controllers/feedback_push_controller.dart';
import '../../controllers/feedback_push_navigation_controller.dart';
import '../../controllers/feedback_unread_controller.dart';
import '../../controllers/routeController.dart';
import '../../services/feedback/feedback_api.dart';
import '../../services/feedback/feedback_push_target.dart';
import '../../funcs.dart';
import 'feedback_controller.dart';
import 'feedback_route_args.dart';

FeedbackPageArgs? get _visibleArgs {
  if (top_routeWithName.isEmpty) return null;
  final route = top_routeWithName.last.route;
  final args = route.settings.arguments;
  return route.isCurrent && args is FeedbackPageArgs ? args : null;
}

void initializeFeedbackPush() {
  final api = FeedbackApi(Supabase.instance.client);
  final unread = Get.find<FeedbackUnreadController>();
  final navigation = Get.put(FeedbackPushNavigationController(
    currentUserId: () => api.currentUserId,
    canNavigate: () => Get.nestedKey(1)?.currentState != null &&
        Get.isDialogOpen != true && Get.isBottomSheetOpen != true &&
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.paused &&
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.hidden,
    openLogin: () async {
      if (top_routeWithName.isNotEmpty && top_routeWithName.last.name == RouteName.supabaseLoginPage) return;
      await Get.toNamed(RouteName.supabaseLoginPage, id: 1);
    },
    openIssue: (FeedbackPushTarget target) async {
      final args = _visibleArgs;
      if (args?.kind == FeedbackPageKind.messages && args?.issue?.id == target.issueId &&
          Get.isRegistered<FeedbackController>(tag: args!.controllerTag)) {
        final controller = Get.find<FeedbackController>(tag: args.controllerTag);
        await controller.recover();
        if (controller.error != null) throw StateError('Unable to load discussion');
        if (api.currentUserId == target.userId) {
          await unread.markRead(target.issueId, through: controller.messages.firstOrNull?.id ?? 0);
        }
        return;
      }
      final list = FeedbackPageArgs.issues(targetIssueId: target.issueId);
      // A named list route owns the asynchronous load and its retry UI. Do not
      // await the route result, which completes only when the user leaves it.
      unawaited(Get.toNamed(list.path, arguments: list, id: 1));
      await Future<void>.delayed(Duration.zero);
    },
    report: (message) => showErrorSnackbar('在线反馈', message),
  ), permanent: true);
  Get.put(FeedbackPushController(api, unread, navigation, isIssueVisible: (id) {
    final args = _visibleArgs;
    return args?.kind == FeedbackPageKind.messages && args?.issue?.id == id;
  }), permanent: true);
}
